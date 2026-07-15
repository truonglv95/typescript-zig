const std = @import("std");
const ast = @import("../../ast/ast.zig");
const astnav = @import("../../ast/ast_utils.zig");
const core = @import("../../core/core.zig");
const scanner = @import("../../scanner/scanner.zig");
const lsutil = @import("lsutil.zig");
const NodeIndex = ast.NodeIndex;

pub fn positionBelongsToNode(tree: *ast.Ast, candidate: NodeIndex, position: u32) bool {
    const candidatePos = tree.positions.items[candidate].pos;
    if (candidatePos > position) {
        @panic("Expected candidate.pos <= position");
    }
    const candidateEnd = tree.positions.items[candidate].end;
    return position < candidateEnd or !isCompletedNode(tree, candidate);
}

pub fn isCompletedNode(tree: *ast.Ast, n: NodeIndex) bool {
    if (n == ast.nullNode or astnav.nodeIsMissing(tree, n)) {
        return false;
    }
    
    const kind = tree.getNodeKind(n);
    switch (kind) {
        .ClassDeclaration,
        .InterfaceDeclaration,
        .EnumDeclaration,
        .ObjectLiteralExpression,
        .ObjectBindingPattern,
        .TypeLiteral,
        .Block,
        .ModuleBlock,
        .CaseBlock,
        .NamedImports,
        .NamedExports => return nodeEndsWith(tree, n, .CloseBraceToken),
        
        .CatchClause => {
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "CatchClause")) {
                const block = nodeData.CatchClause.Block;
                return isCompletedNode(tree, block);
            }
            return true;
        },
        
        .NewExpression => {
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "NewExpression")) {
                if (nodeData.NewExpression.arguments == 0) {
                    return true;
                }
            }
            return nodeEndsWith(tree, n, .CloseParenToken);
        },
        .CallExpression,
        .ParenthesizedExpression,
        .ParenthesizedType => return nodeEndsWith(tree, n, .CloseParenToken),
        
        .FunctionType,
        .ConstructorType => {
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "FunctionType")) return isCompletedNode(tree, nodeData.FunctionType.type);
            if (@hasField(@TypeOf(nodeData), "ConstructorType")) return isCompletedNode(tree, nodeData.ConstructorType.type);
            return true;
        },
        
        .Constructor,
        .GetAccessor,
        .SetAccessor,
        .FunctionDeclaration,
        .FunctionExpression,
        .MethodDeclaration,
        .MethodSignature,
        .ConstructSignature,
        .CallSignature,
        .ArrowFunction => {
            const nodeData = tree.getNode(n);
            inline for (std.meta.fields(@TypeOf(nodeData))) |f| {
                if (f.value == @intFromEnum(kind)) {
                    if (@hasField(@TypeOf(@field(nodeData, f.name)), "body")) {
                        const body = @field(nodeData, f.name).body;
                        if (body != 0) return isCompletedNode(tree, body);
                    }
                    if (@hasField(@TypeOf(@field(nodeData, f.name)), "type")) {
                        const typ = @field(nodeData, f.name).type;
                        if (typ != 0) return isCompletedNode(tree, typ);
                    }
                }
            }
            return hasChildOfKind(tree, n, .CloseParenToken);
        },
        
        .IfStatement => {
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "IfStatement")) {
                if (nodeData.IfStatement.ElseStatement != 0) {
                    return isCompletedNode(tree, nodeData.IfStatement.ElseStatement);
                }
                return isCompletedNode(tree, nodeData.IfStatement.ThenStatement);
            }
            return true;
        },
        
        .ExpressionStatement => {
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "ExpressionStatement")) {
                return isCompletedNode(tree, nodeData.ExpressionStatement.Expression) or hasChildOfKind(tree, n, .SemicolonToken);
            }
            return true;
        },
        
        .ArrayLiteralExpression,
        .ArrayBindingPattern,
        .ElementAccessExpression,
        .ComputedPropertyName,
        .TupleType => return nodeEndsWith(tree, n, .CloseBracketToken),
        
        .IndexSignature => {
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "IndexSignature")) {
                if (nodeData.IndexSignature.type != 0) {
                    return isCompletedNode(tree, nodeData.IndexSignature.type);
                }
            }
            return hasChildOfKind(tree, n, .CloseBracketToken);
        },
        
        .CaseClause,
        .DefaultClause => return false,
        
        .ForStatement,
        .ForInStatement,
        .ForOfStatement,
        .WhileStatement => {
            const nodeData = tree.getNode(n);
            inline for (std.meta.fields(@TypeOf(nodeData))) |f| {
                if (f.value == @intFromEnum(kind)) {
                    if (@hasField(@TypeOf(@field(nodeData, f.name)), "Statement")) {
                        return isCompletedNode(tree, @field(nodeData, f.name).Statement);
                    }
                }
            }
            return true;
        },
        
        .DoStatement => {
            if (hasChildOfKind(tree, n, .WhileKeyword)) {
                return nodeEndsWith(tree, n, .CloseParenToken);
            }
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "DoStatement")) {
                return isCompletedNode(tree, nodeData.DoStatement.Statement);
            }
            return true;
        },
        
        .TypeQuery => {
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "TypeQuery")) {
                return isCompletedNode(tree, nodeData.TypeQuery.ExprName);
            }
            return true;
        },
        
        .TypeOfExpression,
        .DeleteExpression,
        .VoidExpression,
        .YieldExpression,
        .SpreadElement => {
            const nodeData = tree.getNode(n);
            inline for (std.meta.fields(@TypeOf(nodeData))) |f| {
                if (f.value == @intFromEnum(kind)) {
                    if (@hasField(@TypeOf(@field(nodeData, f.name)), "Expression")) {
                        return isCompletedNode(tree, @field(nodeData, f.name).Expression);
                    }
                }
            }
            return true;
        },
        
        .PrefixUnaryExpression => {
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "PrefixUnaryExpression")) {
                return isCompletedNode(tree, nodeData.PrefixUnaryExpression.Operand);
            }
            return true;
        },
        
        .BinaryExpression => {
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "BinaryExpression")) {
                return isCompletedNode(tree, nodeData.BinaryExpression.Right);
            }
            return true;
        },
        
        .ConditionalExpression => {
            const nodeData = tree.getNode(n);
            if (@hasField(@TypeOf(nodeData), "ConditionalExpression")) {
                return isCompletedNode(tree, nodeData.ConditionalExpression.WhenFalse);
            }
            return true;
        },
        
        else => return true,
    }
}

pub fn nodeEndsWith(tree: *ast.Ast, n: NodeIndex, expectedLastToken: std.meta.Tag(ast.NodeData)) bool {
    const children_m = @import("children.zig");
    const lastChildNode = children_m.getLastVisitedChild(tree, n);
    var tokenStartPos: u32 = 0;
    
    var lastKinds = std.ArrayList(std.meta.Tag(ast.NodeData)).init(tree.allocator);
    defer lastKinds.deinit();
    
    if (lastChildNode) |child| {
        tokenStartPos = tree.positions.items[child].end;
        lastKinds.append(tree.getNodeKind(child)) catch {};
    } else {
        tokenStartPos = tree.positions.items[n].pos;
    }
    
    var scan = scanner.getScannerForSourceFile(tree, tokenStartPos);
    var startPos = tokenStartPos;
    const nodeEnd = tree.positions.items[n].end;
    while (startPos < nodeEnd) {
        const tokenKind = scan.token();
        lastKinds.append(tokenKind) catch {};
        startPos = scan.tokenEnd();
        scan.scan();
    }
    
    if (lastKinds.items.len == 0) return false;
    const last = lastKinds.items[lastKinds.items.len - 1];
    if (last == expectedLastToken) return true;
    if (last == .SemicolonToken and lastKinds.items.len > 1) {
        return lastKinds.items[lastKinds.items.len - 2] == expectedLastToken;
    }
    return false;
}

pub fn hasChildOfKind(tree: *ast.Ast, containingNode: NodeIndex, kind: std.meta.Tag(ast.NodeData)) bool {
    var found = false;
    const VisitCtx = struct {
        tree: *ast.Ast,
        kind: std.meta.Tag(ast.NodeData),
        found: *bool,
        fn visit(ctx: *@This(), n: NodeIndex) bool {
            if (n != 0 and ctx.tree.getNodeKind(n) == ctx.kind) {
                ctx.found.* = true;
                return true;
            }
            return false;
        }
    };
    var ctx = VisitCtx{ .tree = tree, .kind = kind, .found = &found };
    _ = ast.forEachChild(tree, containingNode, &ctx, VisitCtx.visit);
    
    if (!found and @intFromEnum(kind) < @intFromEnum(@import("../../ast/kind.zig").Kind.FirstNode)) {
        var scan = scanner.getScannerForSourceFile(tree, tree.positions.items[containingNode].pos);
        const nodeEnd = tree.positions.items[containingNode].end;
        var startPos = tree.positions.items[containingNode].pos;
        while (startPos < nodeEnd) {
            const tokenKind = scan.token();
            if (tokenKind == kind) {
                return true;
            }
            startPos = scan.tokenEnd();
            scan.scan();
        }
    }
    return found;
}
