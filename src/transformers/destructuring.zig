const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const factory = @import("../printer/factory.zig");
const kind = @import("../ast/kind.zig");
const transformers = @import("transformer.zig");
const ast_utils = @import("../ast/ast_utils.zig");

pub const FlattenLevel = enum {
    All,
    ObjectRest,
};

pub const CreateAssignmentCallback = struct {
    ctx: *anyopaque,
    func: *const fn (ctx: *anyopaque, name: ast_gen.NodeIndex, value: ast_gen.NodeIndex, location: ?*const ast.TextRange) ast_gen.NodeIndex,
};

const pendingDecl = struct {
    pendingExpressions: std.ArrayListUnmanaged(ast_gen.NodeIndex) = .empty,
    name: ast_gen.NodeIndex,
    value: ast_gen.NodeIndex,
    location: ast.TextRange,
    original: ast_gen.NodeIndex,
};

const Flattener = struct {
    allocator: std.mem.Allocator,
    tx: *transformers.Transformer,
    level: FlattenLevel,
    createAssignmentCallback: ?CreateAssignmentCallback = null,

    // State
    expressions: std.array_list.Managed(ast_gen.NodeIndex),
    declarations: std.array_list.Managed(pendingDecl),
    hasTransformedPriorElement: bool = false,
    hoistTempVariables: bool = false,
    isBindingMode: bool,

    fn init(allocator: std.mem.Allocator, tx: *transformers.Transformer, level: FlattenLevel, isBindingMode: bool) Flattener {
        return .{
            .allocator = allocator,
            .tx = tx,
            .level = level,
            .expressions = std.array_list.Managed(ast_gen.NodeIndex).init(allocator),
            .declarations = std.array_list.Managed(pendingDecl).init(allocator),
            .isBindingMode = isBindingMode,
        };
    }

    fn deinit(self: *Flattener) void {
        self.expressions.deinit();
        for (self.declarations.items) |*decl| {
            decl.pendingExpressions.deinit(self.allocator);
        }
        self.declarations.deinit();
    }

    fn emitBindingOrAssignment(self: *Flattener, target: ast_gen.NodeIndex, value: ast_gen.NodeIndex, location: ast.TextRange, original: ast_gen.NodeIndex) !void {
        if (self.isBindingMode) {
            var val = value;
            if (self.expressions.items.len > 0) {
                try self.expressions.append(value);
                val = self.tx.factory.inlineExpressions(self.expressions.items);
                self.expressions.clearRetainingCapacity();
            }
            try self.declarations.append(.{
                .name = target,
                .value = val,
                .location = location,
                .original = original,
            });
        } else {
            var expression: ast_gen.NodeIndex = 0;
            if (self.createAssignmentCallback) |cb| {
                if (self.tx.visitor.tree.getNodeKind(target) == .Identifier) {
                    expression = cb.func(cb.ctx, target, value, &location);
                }
            }
            if (expression == 0) {
                const visitedTarget = self.tx.visitor.visitNode(target);
                expression = self.tx.factory.newAssignmentExpression(visitedTarget, value);
                ast_utils.setLoc(self.tx.visitor.tree, expression, location);
            }
            self.tx.emitContext.setOriginal(expression, original) catch unreachable;
            try self.emitExpression(expression);
        }
    }

    fn createArrayBindingOrAssignmentPattern(self: *Flattener, elements: []const ast_gen.NodeIndex) !ast_gen.NodeIndex {
        if (self.isBindingMode) {
            const list = self.tx.factory.newNodeList(elements);
            return self.tx.factory.newBindingPattern(.ArrayBindingPattern, list);
        } else {
            const list = self.tx.factory.newNodeList(elements);
            return self.tx.factory.newArrayLiteralExpression(list, false);
        }
    }

    fn createObjectBindingOrAssignmentPattern(self: *Flattener, elements: []const ast_gen.NodeIndex) !ast_gen.NodeIndex {
        if (self.isBindingMode) {
            const list = self.tx.factory.newNodeList(elements);
            return self.tx.factory.newBindingPattern(.ObjectBindingPattern, list);
        } else {
            const list = self.tx.factory.newNodeList(elements);
            return self.tx.factory.newObjectLiteralExpression(list, false);
        }
    }

    fn createArrayBindingOrAssignmentElement(self: *Flattener, expr: ast_gen.NodeIndex) !ast_gen.NodeIndex {
        if (self.isBindingMode) {
            return self.tx.factory.newBindingElement(0, 0, expr, 0);
        } else {
            return expr;
        }
    }

    fn emitExpression(self: *Flattener, expr: ast_gen.NodeIndex) !void {
        try self.expressions.append(expr);
    }

    fn ensureIdentifier(self: *Flattener, value: ast_gen.NodeIndex, reuseIdentifierExpressions: bool, location: ast.TextRange) !ast_gen.NodeIndex {
        const tree = self.tx.visitor.tree;
        if (reuseIdentifierExpressions and tree.getNodeKind(value) == .Identifier) {
            return value;
        }
        const temp = try self.tx.factory.createTempVariable();
        if (self.hoistTempVariables) {
            self.tx.emitContext.addVariableDeclaration(temp);
            const assign = self.tx.factory.newAssignmentExpression(temp, value);
            ast_utils.setLoc(tree, assign, location);
            try self.emitExpression(assign);
        } else {
            try self.emitBindingOrAssignment(temp, value, location, 0);
        }
        return temp;
    }

    fn createDefaultValueCheck(self: *Flattener, value: ast_gen.NodeIndex, defaultValue: ast_gen.NodeIndex, location: ast.TextRange) !ast_gen.NodeIndex {
        const val = try self.ensureIdentifier(value, true, location);
        const typeCheck = self.tx.factory.newTypeCheck(val, "undefined");
        const qToken = self.tx.factory.newToken(.{ .QuestionToken = {} });
        const cToken = self.tx.factory.newToken(.{ .ColonToken = {} });
        return self.tx.factory.newConditionalExpression(typeCheck, qToken, defaultValue, cToken, val);
    }

    fn createDestructuringPropertyAccess(self: *Flattener, value: ast_gen.NodeIndex, propertyName: ast_gen.NodeIndex) !ast_gen.NodeIndex {
        const tree = self.tx.visitor.tree;
        const k = tree.getNodeKind(propertyName);
        if (k == .ComputedPropertyName) {
            const expr = tree.getNode(propertyName).ComputedPropertyName.Expression;
            const visited = self.tx.visitor.visitNode(expr);
            const range = tree.positions.items[propertyName];
            const argumentExpression = try self.ensureIdentifier(visited, false, range);
            return self.tx.factory.newElementAccessExpression(value, 0, argumentExpression, 0);
        } else if (k == .StringLiteral or k == .NumericLiteral or k == .BigIntLiteral) {
            const range = tree.positions.items[propertyName];
            const argumentExpression = propertyName;
            const res = self.tx.factory.newElementAccessExpression(value, 0, argumentExpression, 0);
            ast_utils.setLoc(tree, res, range);
            return res;
        } else {
            const text = switch (tree.getNode(propertyName)) {
                .Identifier => |n| n.Text,
                .PrivateIdentifier => |n| n.Text,
                else => unreachable,
            };
            const name = self.tx.factory.newIdentifier(text);
            return self.tx.factory.newPropertyAccessExpression(value, 0, name, 0);
        }
    }

    fn flattenDestructuringAssignment(self: *Flattener, node: ast_gen.NodeIndex, needsValue: bool) !ast_gen.NodeIndex {
        const tree = self.tx.visitor.tree;
        var location = tree.positions.items[node];
        var value: ast_gen.NodeIndex = 0;
        var currNode = node;

        if (isDestructuringAssignment(tree, currNode)) {
            const bin = tree.getNode(currNode).BinaryExpression;
            value = bin.Right;
            while (isEmptyArrayLiteral(tree, bin.Left) or isEmptyObjectLiteral(tree, bin.Left)) {
                if (isDestructuringAssignment(tree, value)) {
                    currNode = value;
                    location = tree.positions.items[currNode];
                    value = tree.getNode(currNode).BinaryExpression.Right;
                } else {
                    return self.tx.visitor.visitNode(value);
                }
            }
        }

        if (value != 0) {
            value = self.tx.visitor.visitNode(value);
            if (tree.getNodeKind(value) == .Identifier and bindingOrAssignmentElementAssignsToName(tree, currNode, tree.getNode(value).Identifier.Text)) {
                value = try self.ensureIdentifier(value, false, location);
            } else if (bindingOrAssignmentElementContainsNonLiteralComputedName(tree, currNode)) {
                value = try self.ensureIdentifier(value, false, location);
            } else if (needsValue) {
                value = try self.ensureIdentifier(value, true, location);
            } else if (ast_utils.isSynthesized(tree, currNode)) {
                location = tree.positions.items[value];
            }
        }

        try self.flattenBindingOrAssignmentElement(currNode, value, location, isDestructuringAssignment(tree, currNode));

        if (value != 0 and needsValue) {
            if (self.expressions.items.len == 0) {
                return value;
            }
            try self.expressions.append(value);
        }

        const res = self.tx.factory.inlineExpressions(self.expressions.items);
        if (res != 0) {
            return res;
        }
        return self.tx.factory.newOmittedExpression();
    }

    fn flattenDestructuringBinding(self: *Flattener, node: ast_gen.NodeIndex, rval: ast_gen.NodeIndex, skipInitializer: bool) !ast_gen.NodeIndex {
        const tree = self.tx.visitor.tree;
        var currNode = node;
        if (tree.getNodeKind(currNode) == .VariableDeclaration) {
            const initializer = getInitializerOfBindingOrAssignmentElement(tree, currNode);
            if (initializer != 0) {
                if (tree.getNodeKind(initializer) == .Identifier and bindingOrAssignmentElementAssignsToName(tree, currNode, tree.getNode(initializer).Identifier.Text)) {
                    const visited = self.tx.visitor.visitNode(initializer);
                    const range = tree.positions.items[initializer];
                    const ensured = try self.ensureIdentifier(visited, false, range);
                    const nodeData = tree.getNode(currNode).VariableDeclaration;
                    currNode = self.tx.factory.updateVariableDeclaration(currNode, nodeData, nodeData.name, 0, 0, ensured);
                } else if (bindingOrAssignmentElementContainsNonLiteralComputedName(tree, currNode)) {
                    const visited = self.tx.visitor.visitNode(initializer);
                    const range = tree.positions.items[initializer];
                    const ensured = try self.ensureIdentifier(visited, false, range);
                    const nodeData = tree.getNode(currNode).VariableDeclaration;
                    currNode = self.tx.factory.updateVariableDeclaration(currNode, nodeData, nodeData.name, 0, 0, ensured);
                }
            }
        }

        const range = tree.positions.items[currNode];
        try self.flattenBindingOrAssignmentElement(currNode, rval, range, skipInitializer);

        if (self.expressions.items.len > 0) {
            const temp = try self.tx.factory.createTempVariable();
            if (self.hoistTempVariables) {
                const value = self.tx.factory.inlineExpressions(self.expressions.items);
                self.expressions.clearRetainingCapacity();
                try self.emitBindingOrAssignment(temp, value, .{ .pos = 0, .end = 0 }, 0);
            } else {
                self.tx.emitContext.addVariableDeclaration(temp);
                var last = &self.declarations.items[self.declarations.items.len - 1];
                const assign = self.tx.factory.newAssignmentExpression(temp, last.value);
                try last.pendingExpressions.append(self.allocator, assign);
                try last.pendingExpressions.appendSlice(self.allocator, self.expressions.items);
                self.expressions.clearRetainingCapacity();
                last.value = temp;
            }
        }

        var decls = std.array_list.Managed(ast_gen.NodeIndex).init(self.allocator);
        defer decls.deinit();

        for (self.declarations.items) |pending| {
            var expr = pending.value;
            if (pending.pendingExpressions.items.len > 0) {
                var list = std.array_list.Managed(ast_gen.NodeIndex).init(self.allocator);
                defer list.deinit();
                try list.appendSlice(pending.pendingExpressions.items);
                try list.append(pending.value);
                expr = self.tx.factory.inlineExpressions(list.items);
            }
            const decl = self.tx.factory.newVariableDeclaration(pending.name, 0, 0, expr);
            ast_utils.setLoc(tree, decl, pending.location);
            if (pending.original != 0) {
                self.tx.emitContext.setOriginal(decl, pending.original) catch unreachable;
            }
            try decls.append(decl);
        }

        if (decls.items.len == 1) {
            return decls.items[0];
        }
        if (decls.items.len == 0) {
            return 0;
        }
        return self.tx.factory.newSyntaxList(decls.items);
    }

    fn flattenBindingOrAssignmentElement(self: *Flattener, element: ast_gen.NodeIndex, value: ast_gen.NodeIndex, location: ast.TextRange, skipInitializer: bool) anyerror!void {
        const tree = self.tx.visitor.tree;
        const bindingTarget = getTargetOfBindingOrAssignmentElement(tree, element);
        if (bindingTarget == 0) return;

        var val = value;
        if (!skipInitializer) {
            const initializer_node = getInitializerOfBindingOrAssignmentElement(tree, element);
            const initializer = self.tx.visitor.visitNode(initializer_node);
            if (initializer != 0) {
                if (val != 0) {
                    val = try self.createDefaultValueCheck(val, initializer, location);
                    if (!isSimpleCopiableExpression(tree, initializer)) {
                        const tk = tree.getNodeKind(bindingTarget);
                        if (tk == .ArrayBindingPattern or tk == .ObjectBindingPattern or tk == .ArrayLiteralExpression or tk == .ObjectLiteralExpression) {
                            val = try self.ensureIdentifier(val, true, location);
                        }
                    }
                } else {
                    val = initializer;
                }
            } else if (val == 0) {
                val = self.tx.factory.newVoidZeroExpression();
            }
        }

        const tk = tree.getNodeKind(bindingTarget);
        if (tk == .ObjectBindingPattern or tk == .ObjectLiteralExpression) {
            try self.flattenObjectBindingOrAssignmentPattern(element, bindingTarget, val, location);
        } else if (tk == .ArrayBindingPattern or tk == .ArrayLiteralExpression) {
            try self.flattenArrayBindingOrAssignmentPattern(element, bindingTarget, val, location);
        } else {
            try self.emitBindingOrAssignment(bindingTarget, val, location, element);
        }
    }

    fn flattenObjectBindingOrAssignmentPattern(self: *Flattener, parent: ast_gen.NodeIndex, pattern: ast_gen.NodeIndex, value: ast_gen.NodeIndex, location: ast.TextRange) anyerror!void {
        const tree = self.tx.visitor.tree;
        const elements = getElementsOfBindingOrAssignmentPattern(tree, pattern);
        const numElements = elements.len;

        var val = value;
        if (numElements != 1) {
            const reuse = !isDeclarationBindingElement(tree, parent) or numElements != 0;
            val = try self.ensureIdentifier(val, reuse, location);
        }

        var bindingElements = std.array_list.Managed(ast_gen.NodeIndex).init(self.allocator);
        defer bindingElements.deinit();

        var computedTempVariables = std.array_list.Managed(ast_gen.NodeIndex).init(self.allocator);
        defer computedTempVariables.deinit();

        for (elements, 0..) |element, i| {
            if (getRestIndicatorOfBindingOrAssignmentElement(tree, element) == 0) {
                const propertyName = tryGetPropertyNameOfBindingOrAssignmentElement(tree, element);
                const isRestSpread = self.level == .ObjectRest;
                const hasRestOrSpread = containsObjectRestOrSpread(tree, element) or containsObjectRestOrSpread(tree, getTargetOfBindingOrAssignmentElement(tree, element));
                const isComputed = tree.getNodeKind(propertyName) == .ComputedPropertyName;

                if (isRestSpread and !hasRestOrSpread and !isComputed) {
                    try bindingElements.append(self.tx.visitor.visitNode(element));
                } else {
                    if (bindingElements.items.len > 0) {
                        const patternNode = try self.createObjectBindingOrAssignmentPattern(bindingElements.items);
                        try self.emitBindingOrAssignment(patternNode, val, location, pattern);
                        bindingElements.clearRetainingCapacity();
                    }
                    const rhsValue = try self.createDestructuringPropertyAccess(val, propertyName);
                    if (isComputed) {
                        try computedTempVariables.append(tree.getNode(rhsValue).ElementAccessExpression.ArgumentExpression);
                    }
                    const elemRange = tree.positions.items[element];
                    try self.flattenBindingOrAssignmentElement(element, rhsValue, elemRange, false);
                }
            } else if (i == numElements - 1) {
                if (bindingElements.items.len > 0) {
                    const patternNode = try self.createObjectBindingOrAssignmentPattern(bindingElements.items);
                    try self.emitBindingOrAssignment(patternNode, val, location, pattern);
                    bindingElements.clearRetainingCapacity();
                }
                const range = tree.positions.items[pattern];
                self.tx.emitContext.requestEmitHelper(&@import("../printer/helpers.zig").restHelper);
                const rhsValue = try self.tx.factory.newRestHelper(val, elements, computedTempVariables.items, range);
                const elemRange = tree.positions.items[element];
                try self.flattenBindingOrAssignmentElement(element, rhsValue, elemRange, false);
            }
        }

        if (bindingElements.items.len > 0) {
            const patternNode = try self.createObjectBindingOrAssignmentPattern(bindingElements.items);
            try self.emitBindingOrAssignment(patternNode, val, location, pattern);
        }
    }

    const restIdElemPair = struct {
        id: ast_gen.NodeIndex,
        element: ast_gen.NodeIndex,
    };

    fn flattenArrayBindingOrAssignmentPattern(self: *Flattener, parent: ast_gen.NodeIndex, pattern: ast_gen.NodeIndex, value: ast_gen.NodeIndex, location: ast.TextRange) anyerror!void {
        const tree = self.tx.visitor.tree;
        const elements = getElementsOfBindingOrAssignmentPattern(tree, pattern);
        const numElements = elements.len;

        var val = value;
        var everyOmitted = true;
        for (elements) |el| {
            if (tree.getNodeKind(el) != .OmittedExpression) {
                everyOmitted = false;
                break;
            }
        }

        if ((numElements != 1 and (self.level == .All or numElements == 0)) or everyOmitted) {
            const reuse = !isDeclarationBindingElement(tree, parent) or numElements != 0;
            val = try self.ensureIdentifier(val, reuse, location);
        }

        var bindingElements = std.array_list.Managed(ast_gen.NodeIndex).init(self.allocator);
        defer bindingElements.deinit();

        var restContainingElements = std.array_list.Managed(restIdElemPair).init(self.allocator);
        defer restContainingElements.deinit();

        for (elements, 0..) |element, i| {
            if (self.level == .ObjectRest) {
                if (containsObjectRestOrSpread(tree, element) or (self.hasTransformedPriorElement and !isSimpleBindingOrAssignmentElement(tree, element))) {
                    self.hasTransformedPriorElement = true;
                    const temp = try self.tx.factory.createTempVariable();
                    if (self.hoistTempVariables) {
                        self.tx.emitContext.addVariableDeclaration(temp);
                    }
                    try restContainingElements.append(.{ .id = temp, .element = element });
                    const elem = try self.createArrayBindingOrAssignmentElement(temp);
                    try bindingElements.append(elem);
                } else {
                    try bindingElements.append(element);
                }
            } else if (tree.getNodeKind(element) == .OmittedExpression) {
                continue;
            } else if (getRestIndicatorOfBindingOrAssignmentElement(tree, element) == 0) {
                var buf: [16]u8 = undefined;
                const idxStr = try std.fmt.bufPrint(&buf, "{d}", .{i});
                const idxDup = try self.tx.factory.allocator.dupe(u8, idxStr);
                const numLit = self.tx.factory.newNumericLiteral(idxDup, 0);
                const rhsValue = self.tx.factory.newElementAccessExpression(val, 0, numLit, 0);
                const elemRange = tree.positions.items[element];
                try self.flattenBindingOrAssignmentElement(element, rhsValue, elemRange, false);
            } else if (i == numElements - 1) {
                const rhsValue = self.tx.factory.newArraySliceCall(val, i);
                const elemRange = tree.positions.items[element];
                try self.flattenBindingOrAssignmentElement(element, rhsValue, elemRange, false);
            }
        }

        if (bindingElements.items.len > 0) {
            const patternNode = try self.createArrayBindingOrAssignmentPattern(bindingElements.items);
            try self.emitBindingOrAssignment(patternNode, val, location, pattern);
        }
        if (restContainingElements.items.len > 0) {
            for (restContainingElements.items) |pair| {
                const elemRange = tree.positions.items[pair.element];
                try self.flattenBindingOrAssignmentElement(pair.element, pair.id, elemRange, false);
            }
        }
    }
};

// --- Entry points ---

pub fn flattenDestructuringAssignment(
    tx: *transformers.Transformer,
    node: ast_gen.NodeIndex,
    needsValue: bool,
    level: FlattenLevel,
    createAssignmentCallback: ?CreateAssignmentCallback,
) !ast_gen.NodeIndex {
    var f = Flattener.init(tx.factory.allocator, tx, level, false);
    defer f.deinit();
    f.createAssignmentCallback = createAssignmentCallback;
    f.hoistTempVariables = true;
    return try f.flattenDestructuringAssignment(node, needsValue);
}

pub fn flattenDestructuringBinding(
    tx: *transformers.Transformer,
    node: ast_gen.NodeIndex,
    rval: ast_gen.NodeIndex,
    level: FlattenLevel,
    hoistTempVariables: bool,
    skipInitializer: bool,
) !ast_gen.NodeIndex {
    var f = Flattener.init(tx.factory.allocator, tx, level, true);
    defer f.deinit();
    f.hoistTempVariables = hoistTempVariables;
    return try f.flattenDestructuringBinding(node, rval, skipInitializer);
}

// --- Shared Helpers ---

fn isDeclarationBindingElement(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const k = tree.getNodeKind(node);
    return k == .VariableDeclaration or k == .Parameter or k == .BindingElement;
}

fn isObjectLiteralElement(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const k = tree.getNodeKind(node);
    return k == .PropertyAssignment or k == .ShorthandPropertyAssignment or k == .SpreadAssignment or k == .MethodDeclaration or k == .GetAccessor or k == .SetAccessor;
}

fn isAssignmentExpression(tree: *ast.Ast, node: ast_gen.NodeIndex, excludeCompound: bool) bool {
    const k = tree.getNodeKind(node);
    if (k != .BinaryExpression) return false;
    const bin = tree.getNode(node).BinaryExpression;
    const op = tree.getNodeKind(bin.OperatorToken);
    if (excludeCompound) {
        return op == .EqualsToken;
    }
    return op == .EqualsToken;
}

fn isPropertyName(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const k = tree.getNodeKind(node);
    return k == .Identifier or k == .StringLiteral or k == .NumericLiteral or k == .ComputedPropertyName or k == .PrivateIdentifier;
}

pub fn getElementsOfBindingOrAssignmentPattern(tree: *ast.Ast, pattern: ast_gen.NodeIndex) []const ast_gen.NodeIndex {
    const node = tree.getNode(pattern);
    return switch (node) {
        .ObjectBindingPattern => |n| tree.getNodeList(n.Elements),
        .ArrayBindingPattern => |n| tree.getNodeList(n.Elements),
        .ObjectLiteralExpression => |n| tree.getNodeList(n.Properties),
        .ArrayLiteralExpression => |n| tree.getNodeList(n.Elements),
        else => &[_]ast_gen.NodeIndex{},
    };
}

pub fn getTargetOfBindingOrAssignmentElement(tree: *ast.Ast, bindingElement: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (bindingElement == 0) return 0;
    const k = tree.getNodeKind(bindingElement);
    if (isDeclarationBindingElement(tree, bindingElement)) {
        return switch (tree.getNode(bindingElement)) {
            .VariableDeclaration => |n| n.name,
            .Parameter => |n| n.name,
            .BindingElement => |n| n.name orelse 0,
            else => unreachable,
        };
    }

    if (isObjectLiteralElement(tree, bindingElement)) {
        switch (k) {
            .PropertyAssignment => {
                const init = tree.getNode(bindingElement).PropertyAssignment.Initializer;
                return getTargetOfBindingOrAssignmentElement(tree, init);
            },
            .ShorthandPropertyAssignment => {
                return tree.getNode(bindingElement).ShorthandPropertyAssignment.name;
            },
            .SpreadAssignment => {
                const expr = tree.getNode(bindingElement).SpreadAssignment.Expression;
                return getTargetOfBindingOrAssignmentElement(tree, expr);
            },
            else => return 0,
        }
    }

    if (isAssignmentExpression(tree, bindingElement, true)) {
        const left = tree.getNode(bindingElement).BinaryExpression.Left;
        return getTargetOfBindingOrAssignmentElement(tree, left);
    }

    if (k == .SpreadElement) {
        const expr = tree.getNode(bindingElement).SpreadElement.Expression;
        return getTargetOfBindingOrAssignmentElement(tree, expr);
    }

    return bindingElement;
}

pub fn tryGetPropertyNameOfBindingOrAssignmentElement(tree: *ast.Ast, bindingElement: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (bindingElement == 0) return 0;
    const k = tree.getNodeKind(bindingElement);
    switch (k) {
        .BindingElement => {
            const propName = tree.getNode(bindingElement).BindingElement.PropertyName orelse 0;
            if (propName != 0) {
                if (tree.getNodeKind(propName) == .ComputedPropertyName) {
                    const expr = tree.getNode(propName).ComputedPropertyName.Expression;
                    const ek = tree.getNodeKind(expr);
                    if (ek == .StringLiteral or ek == .NumericLiteral) {
                        return expr;
                    }
                }
                return propName;
            }
        },
        .PropertyAssignment => {
            const nameNode = tree.getNode(bindingElement).PropertyAssignment.name;
            if (nameNode != 0) {
                if (tree.getNodeKind(nameNode) == .ComputedPropertyName) {
                    const expr = tree.getNode(nameNode).ComputedPropertyName.Expression;
                    const ek = tree.getNodeKind(expr);
                    if (ek == .StringLiteral or ek == .NumericLiteral) {
                        return expr;
                    }
                }
                return nameNode;
            }
        },
        .SpreadAssignment => {
            return tree.getNode(bindingElement).SpreadAssignment.Expression;
        },
        else => {},
    }

    const target = getTargetOfBindingOrAssignmentElement(tree, bindingElement);
    if (target != 0 and isPropertyName(tree, target)) {
        return target;
    }
    return 0;
}

pub fn getInitializerOfBindingOrAssignmentElement(tree: *ast.Ast, bindingElement: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (bindingElement == 0) return 0;
    const k = tree.getNodeKind(bindingElement);
    if (isDeclarationBindingElement(tree, bindingElement)) {
        return switch (tree.getNode(bindingElement)) {
            .VariableDeclaration => |n| n.Initializer orelse 0,
            .Parameter => |n| n.Initializer orelse 0,
            .BindingElement => |n| n.Initializer orelse 0,
            else => unreachable,
        };
    }
    if (k == .PropertyAssignment) {
        const init = tree.getNode(bindingElement).PropertyAssignment.Initializer;
        if (isAssignmentExpression(tree, init, true)) {
            return tree.getNode(init).BinaryExpression.Right;
        }
        return 0;
    }
    if (k == .ShorthandPropertyAssignment) {
        return tree.getNode(bindingElement).ShorthandPropertyAssignment.ObjectAssignmentInitializer orelse 0;
    }
    if (isAssignmentExpression(tree, bindingElement, true)) {
        return tree.getNode(bindingElement).BinaryExpression.Right;
    }
    if (k == .SpreadElement) {
        const expr = tree.getNode(bindingElement).SpreadElement.Expression;
        return getInitializerOfBindingOrAssignmentElement(tree, expr);
    }
    return 0;
}

pub fn bindingOrAssignmentElementAssignsToName(tree: *ast.Ast, element: ast_gen.NodeIndex, targetName: []const u8) bool {
    const target = getTargetOfBindingOrAssignmentElement(tree, element);
    if (target == 0) return false;
    const k = tree.getNodeKind(target);
    if (k == .ArrayBindingPattern or k == .ObjectBindingPattern or k == .ArrayLiteralExpression or k == .ObjectLiteralExpression) {
        return bindingOrAssignmentPatternAssignsToName(tree, target, targetName);
    } else if (k == .Identifier) {
        const text = tree.getNode(target).Identifier.Text;
        return std.mem.eql(u8, text, targetName);
    }
    return false;
}

fn bindingOrAssignmentPatternAssignsToName(tree: *ast.Ast, pattern: ast_gen.NodeIndex, targetName: []const u8) bool {
    const elements = getElementsOfBindingOrAssignmentPattern(tree, pattern);
    for (elements) |element| {
        if (bindingOrAssignmentElementAssignsToName(tree, element, targetName)) {
            return true;
        }
    }
    return false;
}

pub fn bindingOrAssignmentElementContainsNonLiteralComputedName(tree: *ast.Ast, element: ast_gen.NodeIndex) bool {
    const propName = tryGetPropertyNameOfBindingOrAssignmentElement(tree, element);
    if (propName != 0 and tree.getNodeKind(propName) == .ComputedPropertyName) {
        const expr = tree.getNode(propName).ComputedPropertyName.Expression;
        const ek = tree.getNodeKind(expr);
        if (ek != .StringLiteral and ek != .NumericLiteral) {
            return true;
        }
    }
    const target = getTargetOfBindingOrAssignmentElement(tree, element);
    if (target != 0) {
        const tk = tree.getNodeKind(target);
        if (tk == .ArrayBindingPattern or tk == .ObjectBindingPattern or tk == .ArrayLiteralExpression or tk == .ObjectLiteralExpression) {
            return bindingOrAssignmentPatternContainsNonLiteralComputedName(tree, target);
        }
    }
    return false;
}

fn bindingOrAssignmentPatternContainsNonLiteralComputedName(tree: *ast.Ast, pattern: ast_gen.NodeIndex) bool {
    const elements = getElementsOfBindingOrAssignmentPattern(tree, pattern);
    for (elements) |element| {
        if (bindingOrAssignmentElementContainsNonLiteralComputedName(tree, element)) {
            return true;
        }
    }
    return false;
}

fn isPropertyNameLiteral(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    const k = tree.getNodeKind(node);
    return k == .Identifier or k == .StringLiteral or k == .NumericLiteral;
}

fn isSimpleCopiableExpression(tree: *ast.Ast, expr: ast_gen.NodeIndex) bool {
    const k = tree.getNodeKind(expr);
    return k == .StringLiteral or k == .NumericLiteral or kind.isKeyword(k) or k == .Identifier;
}

fn isSimpleInlineableExpression(tree: *ast.Ast, expr: ast_gen.NodeIndex) bool {
    const k = tree.getNodeKind(expr);
    return k != .Identifier and isSimpleCopiableExpression(tree, expr);
}

fn isSimpleBindingOrAssignmentElement(tree: *ast.Ast, element: ast_gen.NodeIndex) bool {
    const target = getTargetOfBindingOrAssignmentElement(tree, element);
    if (target == 0 or tree.getNodeKind(target) == .OmittedExpression) {
        return true;
    }
    const propName = tryGetPropertyNameOfBindingOrAssignmentElement(tree, element);
    if (propName != 0 and !isPropertyNameLiteral(tree, propName)) {
        return false;
    }
    const init = getInitializerOfBindingOrAssignmentElement(tree, element);
    if (init != 0 and !isSimpleInlineableExpression(tree, init)) {
        return false;
    }
    const tk = tree.getNodeKind(target);
    if (tk == .ArrayBindingPattern or tk == .ObjectBindingPattern or tk == .ArrayLiteralExpression or tk == .ObjectLiteralExpression) {
        const elems = getElementsOfBindingOrAssignmentPattern(tree, target);
        for (elems) |el| {
            if (!isSimpleBindingOrAssignmentElement(tree, el)) return false;
        }
        return true;
    }
    return tk == .Identifier;
}

fn isDestructuringAssignment(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    if (tree.getNodeKind(node) != .BinaryExpression) return false;
    const bin = tree.getNode(node).BinaryExpression;
    if (tree.getNodeKind(bin.OperatorToken) != .EqualsToken) return false;
    const leftKind = tree.getNodeKind(bin.Left);
    return leftKind == .ObjectLiteralExpression or leftKind == .ArrayLiteralExpression;
}

fn isEmptyObjectLiteral(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (tree.getNodeKind(node) != .ObjectLiteralExpression) return false;
    return getElementsOfBindingOrAssignmentPattern(tree, node).len == 0;
}

fn isEmptyArrayLiteral(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (tree.getNodeKind(node) != .ArrayLiteralExpression) return false;
    return getElementsOfBindingOrAssignmentPattern(tree, node).len == 0;
}

pub fn containsObjectRestOrSpread(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const k = tree.getNodeKind(node);
    if (k == .SpreadAssignment) return true;
    if (k == .BindingElement) {
        const bind = tree.getNode(node).BindingElement;
        if (bind.DotDotDotToken != null and bind.DotDotDotToken.? != 0) {
            return true;
        }
    }

    switch (k) {
        .ObjectBindingPattern, .ArrayBindingPattern, .ObjectLiteralExpression, .ArrayLiteralExpression => {
            const elements = getElementsOfBindingOrAssignmentPattern(tree, node);
            for (elements) |el| {
                if (containsObjectRestOrSpread(tree, el)) return true;
            }
        },
        .VariableDeclaration => {
            const decl = tree.getNode(node).VariableDeclaration;
            if (containsObjectRestOrSpread(tree, decl.name)) return true;
            if (decl.Initializer) |init| {
                if (containsObjectRestOrSpread(tree, init)) return true;
            }
        },
        .Parameter => {
            const decl = tree.getNode(node).Parameter;
            if (containsObjectRestOrSpread(tree, decl.name)) return true;
            if (decl.Initializer) |init| {
                if (containsObjectRestOrSpread(tree, init)) return true;
            }
        },
        .BindingElement => {
            const bind = tree.getNode(node).BindingElement;
            if (bind.name) |name| {
                if (containsObjectRestOrSpread(tree, name)) return true;
            }
            if (bind.Initializer) |init| {
                if (containsObjectRestOrSpread(tree, init)) return true;
            }
        },
        .BinaryExpression => {
            const bin = tree.getNode(node).BinaryExpression;
            if (containsObjectRestOrSpread(tree, bin.Left)) return true;
            if (containsObjectRestOrSpread(tree, bin.Right)) return true;
        },
        .PropertyAssignment => {
            const prop = tree.getNode(node).PropertyAssignment;
            if (containsObjectRestOrSpread(tree, prop.Initializer)) return true;
        },
        else => {},
    }
    return false;
}

fn getRestIndicatorOfBindingOrAssignmentElement(tree: *ast.Ast, element: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (element == 0) return 0;
    const k = tree.getNodeKind(element);
    return switch (k) {
        .BindingElement => tree.getNode(element).BindingElement.DotDotDotToken orelse 0,
        .SpreadAssignment => element,
        .SpreadElement => element,
        else => 0,
    };
}
