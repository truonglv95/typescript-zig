const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const astnav_tokens = @import("../astnav/tokens.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const ast_gen = @import("../ast/ast_generated.zig");

pub const InvocationKind = enum {
    call,
    type_args,
    contextual,
};

pub const CallInvocation = struct {
    node: ast_gen.NodeIndex,
};

pub const TypeArgsInvocation = struct {
    called: ast_gen.NodeIndex,
};

pub const ContextualInvocation = struct {
    signature: checker.types.SignatureIndex,
    node: ast_gen.NodeIndex,
    symbol: ast_gen.SymbolIndex,
};

pub const Invocation = union(InvocationKind) {
    call: CallInvocation,
    type_args: TypeArgsInvocation,
    contextual: ContextualInvocation,
};

pub const ArgumentListInfo = struct {
    isTypeParameterList: bool,
    invocation: Invocation,
    argumentsSpan: ast.TextRange,
    argumentIndex: usize,
    argumentCount: usize,
};

pub fn provideSignatureHelp(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: []const u8,
    position: lsproto.Position,
    context: ?lsproto.SignatureHelpContext,
) !?lsproto.SignatureHelp {
    _ = ls;
    _ = allocator;
    _ = documentURI;
    _ = position;
    _ = context;
    // stub
    return null;
}

pub fn getSignatureHelpItems(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    ctx: *anyopaque, // context for cancellation
    position: u32,
    program: *compiler.Program,
    sourceFile: ast_gen.NodeIndex,
    context: ?lsproto.SignatureHelpContext,
) !?lsproto.SignatureHelp {
    _ = allocator;
    _ = ctx;

    const typeChecker, const done = try program.getTypeCheckerForFile(sourceFile);
    defer done();

    const tree = program.getAst(sourceFile);

    const startingToken = astnav_tokens.findPrecedingToken(sourceFile, tree, position);
    if (startingToken == 0) {
        return null;
    }

    // Emulate VS Code's trigger reason.
    const signatureHelpTriggerReasonKindNone: u32 = 0;
    const signatureHelpTriggerReasonKindInvoked: u32 = 1;
    const signatureHelpTriggerReasonKindCharacterTyped: u32 = 2;
    const signatureHelpTriggerReasonKindRetriggered: u32 = 3;
    _ = signatureHelpTriggerReasonKindNone;

    var triggerReasonKind = signatureHelpTriggerReasonKindInvoked;
    if (context) |c_ctx| {
        if (std.mem.eql(u8, c_ctx.triggerKind, "TriggerCharacter")) {
            if (c_ctx.isRetrigger) {
                triggerReasonKind = signatureHelpTriggerReasonKindRetriggered;
            } else {
                triggerReasonKind = signatureHelpTriggerReasonKindCharacterTyped;
            }
        } else if (std.mem.eql(u8, c_ctx.triggerKind, "ContentChange")) {
            if (c_ctx.isRetrigger) {
                triggerReasonKind = signatureHelpTriggerReasonKindRetriggered;
            } else {
                triggerReasonKind = signatureHelpTriggerReasonKindCharacterTyped;
            }
        }
    }

    const onlyUseSyntacticOwners = triggerReasonKind == signatureHelpTriggerReasonKindCharacterTyped;

    // TODO: skip strings or comments

    const isManuallyInvoked = triggerReasonKind == signatureHelpTriggerReasonKindInvoked;
    var argumentInfo = getContainingArgumentInfo(tree, startingToken, sourceFile, typeChecker, isManuallyInvoked, position) orelse return null;

    const candidateInfo = getCandidateOrTypeInfo(tree, &argumentInfo, typeChecker, sourceFile, startingToken, onlyUseSyntacticOwners) orelse return null;

    if (candidateInfo.candidateInfo) |c_info| {
        return createSignatureHelpItems(ls, c_info.candidates, c_info.resolvedSignature, &argumentInfo, sourceFile, typeChecker, onlyUseSyntacticOwners);
    }

    // TODO: handle typeInfo for types
    return null;
}

fn createSignatureHelpItems(
    ls: *languageservice.LanguageService,
    candidates: []checker.types.SignatureIndex,
    resolvedSignature: checker.types.SignatureIndex,
    argumentInfo: *ArgumentListInfo,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
    onlyUseSyntacticOwners: bool,
) ?lsproto.SignatureHelp {
    _ = ls;
    _ = candidates;
    _ = resolvedSignature;
    _ = argumentInfo;
    _ = sourceFile;
    _ = c;
    _ = onlyUseSyntacticOwners;
    return null;
}

pub const CandidateOrTypeInfo = struct {
    candidateInfo: ?CandidateInfo,
    typeInfo: ?ast_gen.SymbolIndex,
};

pub const CandidateInfo = struct {
    candidates: []checker.types.SignatureIndex,
    resolvedSignature: checker.types.SignatureIndex,
};

pub fn getContainingArgumentInfo(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
    isManuallyInvoked: bool,
    position: u32,
) ?ArgumentListInfo {
    var firstArgumentInfo: ?ArgumentListInfo = null;
    var n = node;
    while (n != sourceFile) : (n = tree.parents.items[n]) {
        if (!isManuallyInvoked) {
            const kind = std.meta.activeTag(tree.getNode(n));
            if (kind == .Block) break;
        }

        const argumentInfo = getImmediatelyContainingArgumentOrContextualParameterInfo(tree, n, position, sourceFile, c);
        if (argumentInfo) |info| {
            if (info.invocation == .contextual) {
                return info;
            }

            if (firstArgumentInfo == null) {
                firstArgumentInfo = info;
            }

            if (info.argumentsSpan.end == position) {
                return info;
            }

            if (info.argumentsSpan.pos <= position and position < info.argumentsSpan.end) {
                return info;
            }
        }
    }

    return firstArgumentInfo;
}

fn getImmediatelyContainingArgumentOrContextualParameterInfo(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    position: u32,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?ArgumentListInfo {
    if (tryGetParameterInfo(tree, node, sourceFile, c)) |result| {
        return result;
    }
    return getImmediatelyContainingArgumentInfo(tree, node, position, sourceFile, c);
}

fn tryGetParameterInfo(
    tree: *ast.Ast,
    startingToken: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?ArgumentListInfo {
    _ = tree;
    _ = startingToken;
    _ = sourceFile;
    _ = c;
    return null;
}

fn getImmediatelyContainingArgumentInfo(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    position: u32,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?ArgumentListInfo {
    const node_kind = std.meta.activeTag(tree.getNode(node));
    const parent = tree.parents.items[node];
    const parent_kind = std.meta.activeTag(tree.getNode(parent));

    if (parent_kind == .CallExpression or parent_kind == .NewExpression) {
        if (getArgumentOrParameterListInfo(tree, node, sourceFile, c)) |info| {
            const isTypeParameterList = false; // TODO: properly check TypeArgumentList
            return ArgumentListInfo{
                .isTypeParameterList = isTypeParameterList,
                .invocation = .{ .call = .{ .node = parent } },
                .argumentsSpan = info.argumentsSpan,
                .argumentIndex = info.argumentIndex,
                .argumentCount = info.argumentCount,
            };
        }
    } else if (node_kind == .NoSubstitutionTemplateLiteral and parent_kind == .TaggedTemplateExpression) {
        if (isInsideTemplateLiteral(tree, node, position, sourceFile)) {
            return getArgumentListInfoForTemplate(tree, parent, 0, sourceFile);
        }
    } else if (node_kind == .TemplateHead and parent_kind == .TemplateExpression) {
        const grandparent = tree.parents.items[parent];
        if (std.meta.activeTag(tree.getNode(grandparent)) == .TaggedTemplateExpression) {
            return getArgumentListInfoForTemplate(tree, grandparent, 1, sourceFile);
        }
    } else if (parent_kind == .TemplateSpan) {
        const grandparent = tree.parents.items[parent];
        if (std.meta.activeTag(tree.getNode(grandparent)) == .TemplateExpression) {
            const greatgrandparent = tree.parents.items[grandparent];
            if (std.meta.activeTag(tree.getNode(greatgrandparent)) == .TaggedTemplateExpression) {
                // TODO: calculate index
                const argumentIndex: usize = 1;
                return getArgumentListInfoForTemplate(tree, greatgrandparent, argumentIndex, sourceFile);
            }
        }
    }

    return null;
}

fn isInsideTemplateLiteral(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    position: u32,
    sourceFile: ast_gen.NodeIndex,
) bool {
    _ = tree;
    _ = node;
    _ = position;
    _ = sourceFile;
    return false;
}

fn getArgumentListInfoForTemplate(
    tree: *ast.Ast,
    tagExpression: ast_gen.NodeIndex,
    argumentIndex: usize,
    sourceFile: ast_gen.NodeIndex,
) ?ArgumentListInfo {
    _ = tree;
    _ = tagExpression;
    _ = argumentIndex;
    _ = sourceFile;
    return null;
}

const ArgumentOrParameterListAndIndex = struct {
    list: ast_gen.NodeIndex,
    argumentIndex: usize,
};

fn getArgumentOrParameterListInfo(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?ArgumentListInfo {
    if (getArgumentOrParameterListAndIndex(tree, node, sourceFile, c)) |info| {
        const argumentCount = getArgumentCount(tree, node, info.list, sourceFile, c);
        const argumentsSpan = getApplicableSpanForArguments(tree, info.list, node, sourceFile);
        return ArgumentListInfo{
            .isTypeParameterList = false, // handled in caller
            .invocation = .{ .call = .{ .node = 0 } }, // dummy
            .argumentsSpan = argumentsSpan,
            .argumentIndex = info.argumentIndex,
            .argumentCount = argumentCount,
        };
    }
    return null;
}

fn getArgumentOrParameterListAndIndex(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?ArgumentOrParameterListAndIndex {
    const node_kind = std.meta.activeTag(tree.getNode(node));
    if (node_kind == .LessThanToken or node_kind == .OpenParenToken) {
        const parent = tree.parents.items[node];
        if (getChildListThatStartsWithOpenerToken(tree, parent, node)) |list| {
            return ArgumentOrParameterListAndIndex{
                .list = list,
                .argumentIndex = 0,
            };
        }
    } else {
        if (findContainingList(tree, node, sourceFile)) |list| {
            return ArgumentOrParameterListAndIndex{
                .list = list,
                .argumentIndex = getArgumentIndex(tree, node, list, sourceFile, c),
            };
        }
    }
    return null;
}

fn getChildListThatStartsWithOpenerToken(
    tree: *ast.Ast,
    parent: ast_gen.NodeIndex,
    openerToken: ast_gen.NodeIndex,
) ?ast_gen.NodeIndex {
    const parent_node = tree.getNode(parent);
    const opener_kind = std.meta.activeTag(tree.getNode(openerToken));

    switch (parent_node) {
        .CallExpression => |call_expr| {
            if (opener_kind == .LessThanToken) {
                if (call_expr.TypeArguments) |v| if (v != 0) return v;
                return null;
            }
            if (call_expr.Arguments) |v| if (v != 0) return v;
            return null;
        },
        .NewExpression => |new_expr| {
            if (opener_kind == .LessThanToken) {
                if (new_expr.TypeArguments) |v| if (v != 0) return v;
                return null;
            }
            if (new_expr.Arguments) |v| if (v != 0) return v;
            return null;
        },
        else => return null,
    }
}

fn findContainingList(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
) ?ast_gen.NodeIndex {
    _ = sourceFile;
    const parent = tree.parents.items[node];
    const parent_node = tree.getNode(parent);

    // Naive implementation: just return Arguments list if it's a Call/New expression.
    // TODO: support TypeArguments when cursor is inside them.
    switch (parent_node) {
        .CallExpression => |call_expr| {
            if (call_expr.Arguments) |args| {
                if (args != 0) return args;
            }
        },
        .NewExpression => |new_expr| {
            if (new_expr.Arguments) |args| {
                if (args != 0) return args;
            }
        },
        else => {},
    }
    return null;
}

fn getArgumentIndex(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    list: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) usize {
    _ = sourceFile;
    _ = c;
    const items = tree.getNodeList(list);
    if (items.len == 0) return 0;

    // If node is exactly in the list:
    for (items, 0..) |item, i| {
        if (item == node) return i;
    }

    // If node is a token (like comma), check its pos
    const node_pos = tree.getNodePos(node);
    for (items, 0..) |item, i| {
        if (node_pos < tree.getNodeEnd(item)) {
            return i;
        }
    }

    return items.len;
}

fn getArgumentCount(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    list: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) usize {
    _ = node;
    _ = sourceFile;
    _ = c;
    const items = tree.getNodeList(list);
    // TODO: adjust if there is a trailing comma or incomplete code
    return items.len;
}

fn getApplicableSpanForArguments(
    tree: *ast.Ast,
    argumentList: ast_gen.NodeIndex,
    node: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
) ast.TextRange {
    _ = node;
    _ = sourceFile;
    const items = tree.getNodeList(argumentList);
    if (items.len == 0) return .{ .pos = 0, .end = 0 };
    return .{
        .pos = tree.getNodePos(items[0]),
        .end = tree.getNodeEnd(items[items.len - 1]),
    };
}

pub fn getCandidateOrTypeInfo(
    tree: *ast.Ast,
    info: *ArgumentListInfo,
    c: *checker.Checker,
    sourceFile: ast_gen.NodeIndex,
    startingToken: ast_gen.NodeIndex,
    onlyUseSyntacticOwners: bool,
) ?CandidateOrTypeInfo {
    _ = sourceFile;
    switch (info.invocation) {
        .call => |call| {
            if (onlyUseSyntacticOwners and !isSyntacticOwner(tree, startingToken, call.node)) {
                return null;
            }

            // TODO: implement checker.getResolvedSignatureForSignatureHelp
            return null;
        },
        .type_args => |type_args| {
            _ = type_args;
            return null;
        },
        .contextual => |contextual| {
            var candidates = c.arena.alloc(checker.types.SignatureIndex, 1) catch unreachable;
            candidates[0] = contextual.signature;
            return CandidateOrTypeInfo{
                .candidateInfo = .{
                    .candidates = candidates,
                    .resolvedSignature = contextual.signature,
                },
                .typeInfo = null,
            };
        },
    }
}

fn isSyntacticOwner(
    tree: *ast.Ast,
    startingToken: ast_gen.NodeIndex,
    node: ast_gen.NodeIndex,
) bool {
    _ = tree;
    _ = startingToken;
    _ = node;
    return false;
}
