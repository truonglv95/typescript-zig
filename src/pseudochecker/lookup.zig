const std = @import("std");
const ast = @import("../ast/ast.zig");
const ptype = @import("type.zig");
const checker = @import("checker.zig");
const PseudoChecker = checker.PseudoChecker;

pub fn getReturnTypeOfSignature(ch: *PseudoChecker, a: *ast.Ast, signatureNode: ast.NodeIndex) !ptype.PseudoTypeIndex {
    const nodeData = a.getNode(signatureNode);
    switch (nodeData) {
        .GetAccessor => return getTypeOfAccessor(ch, a, signatureNode),
        .MethodDeclaration, .FunctionDeclaration, .Constructor, .MethodSignature, .CallSignature, .ConstructSignature, .SetAccessor, .IndexSignature, .FunctionType, .ConstructorType, .FunctionExpression, .ArrowFunction, .JSDocSignature => return createReturnFromSignature(ch, a, signatureNode),
        else => @panic("Node needs to be an inferrable node"),
    }
}

pub fn getTypeOfAccessor(ch: *PseudoChecker, a: *ast.Ast, accessor: ast.NodeIndex) !ptype.PseudoTypeIndex {
    const annotated = try typeFromAccessor(ch, a, accessor);
    const t = ch.getType(annotated);
    if (t == .NoResult) {
        return inferAccessorType(ch, a, accessor);
    }
    return annotated;
}

pub fn getTypeOfExpression(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    return typeFromExpression(ch, a, node);
}

pub fn getTypeOfDeclaration(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    const nodeData = a.getNode(node);
    switch (nodeData) {
        .Parameter => return typeFromParameter(ch, a, node),
        .VariableDeclaration => return typeFromVariable(ch, a, node),
        .PropertySignature, .PropertyDeclaration, .JSDocPropertyTag => return typeFromProperty(ch, a, node),
        .BindingElement => return ch.createType(.{ .NoResult = .{ .declaration = node } }),
        .ExportAssignment => |exp| return typeFromExpression(ch, a, exp.Expression),
        .PropertyAccessExpression, .ElementAccessExpression, .BinaryExpression => return typeFromExpandoProperty(ch, a, node),
        .PropertyAssignment, .ShorthandPropertyAssignment => return typeFromPropertyAssignment(ch, a, node),
        .CallExpression => return ch.createType(.{ .NoResult = .{ .declaration = node } }),
        else => @panic("node needs to be an inferrable node"),
    }
}

fn typeFromParameter(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    _ = a;
    return ch.createType(.{ .NoResult = .{ .declaration = node } });
}

fn typeFromVariable(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    _ = a;
    return ch.createType(.{ .NoResult = .{ .declaration = node } });
}

fn typeFromProperty(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    _ = a;
    return ch.createType(.{ .NoResult = .{ .declaration = node } });
}

fn typeFromExpandoProperty(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    _ = a;
    return ch.createType(.{ .NoResult = .{ .declaration = node } });
}

fn typeFromPropertyAssignment(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    _ = a;
    return ch.createType(.{ .NoResult = .{ .declaration = node } });
}

fn typeFromAccessor(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    _ = a;
    return ch.createType(.{ .NoResult = .{ .declaration = node } });
}

fn inferAccessorType(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    _ = a;
    return ch.createType(.{ .NoResult = .{ .declaration = node } });
}

fn createReturnFromSignature(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    _ = a;
    return ch.createType(.{ .NoResult = .{ .declaration = node } });
}

fn typeFromExpression(ch: *PseudoChecker, a: *ast.Ast, node: ast.NodeIndex) !ptype.PseudoTypeIndex {
    _ = a;
    return ch.createType(.{ .NoResult = .{ .declaration = node } });
}
