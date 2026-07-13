const std = @import("std");

//! ES transform utilities.
//!
//! Port of `internal/transformers/estransforms/utilities.go` (289 LOC).
//!
//! Shared helper functions used by the async, for-await, and other ES
//! transformers. The main components are:
//!
//! - `convertClassDeclarationToClassExpression`
//! - `createNotNullCondition` — builds `left !== null && right !== void 0`
//! - `SuperAccessState` — tracks `super.x` / `super[x]` accesses in async
//!   bodies and generates the `_super` accessor variable
//! - `createAccessorPropertyBackingField`

const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");

/// Tracks super property/element accesses and super property assignments
/// within async function or async generator bodies. Shared by the async
/// and for-await transformers.
///
/// When `super` is used inside an async function, it must be replaced
/// with a synthesized `_super` variable because the async body ends up
/// inside a generator function where `super` is not valid.
pub const SuperAccessState = struct {
    /// Property names accessed on `super` (e.g. `super.x` -> "x").
    captured_super_properties: std.StringHashMapUnmanaged(void) = .empty,
    /// Whether the body contains `super[x]` (element access).
    has_super_element_access: bool = false,
    /// Whether the body contains `super.x = ...` (property assignment).
    has_super_property_assignment: bool = false,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SuperAccessState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *SuperAccessState) void {
        self.captured_super_properties.deinit(self.allocator);
    }

    /// Records a super property/element access or assignment for later
    /// substitution. Called from the visitor for each node that might
    /// reference `super`.
    pub fn trackSuperAccess(self: *SuperAccessState, tree: *ast.Ast, node: ast_gen.NodeIndex) void {
        if (node == 0) return;
        const kind = tree.getNodeKind(node);
        switch (kind) {
            .PropertyAccessExpression => {
                const pa = tree.getNode(node).PropertyAccessExpression;
                if (tree.getNodeKind(pa.Expression) == .SuperKeyword) {
                    const name_node = pa.name;
                    const name_text = ast_utils.getText(tree, name_node);
                    if (name_text.len > 0) {
                        _ = self.captured_super_properties.put(self.allocator, name_text, {}) catch {};
                    }
                }
            },
            .ElementAccessExpression => {
                const ea = tree.getNode(node).ElementAccessExpression;
                if (tree.getNodeKind(ea.Expression) == .SuperKeyword) {
                    self.has_super_element_access = true;
                }
            },
            .BinaryExpression => {
                const binary = tree.getNode(node).BinaryExpression;
                const op_kind = tree.getNodeKind(binary.OperatorToken);
                if (isAssignmentOperator(op_kind)) {
                    if (assignmentTargetContainsSuperProperty(tree, binary.Left)) {
                        self.has_super_property_assignment = true;
                    }
                }
            },
            .PrefixUnaryExpression => {
                const pu = tree.getNode(node).PrefixUnaryExpression;
                if (isUpdateExpression(tree, node)) {
                    if (assignmentTargetContainsSuperProperty(tree, pu.Operand)) {
                        self.has_super_property_assignment = true;
                    }
                }
            },
            .PostfixUnaryExpression => {
                const pu = tree.getNode(node).PostfixUnaryExpression;
                if (isUpdateExpression(tree, node)) {
                    if (assignmentTargetContainsSuperProperty(tree, pu.Operand)) {
                        self.has_super_property_assignment = true;
                    }
                }
            },
            else => {},
        }
    }

    /// Returns true if any super property access was tracked.
    pub fn hasSuperAccesses(self: *const SuperAccessState) bool {
        return self.captured_super_properties.count() > 0 or
            self.has_super_element_access or
            self.has_super_property_assignment;
    }
};

/// Returns true if `kind` is an assignment operator (`=`, `+=`, etc.).
pub fn isAssignmentOperator(kind: ast_gen.NodeData) bool {
    return switch (kind) {
        .EqualsToken,
        .PlusEqualsToken,
        .MinusEqualsToken,
        .AsteriskEqualsToken,
        .AsteriskAsteriskEqualsToken,
        .SlashEqualsToken,
        .PercentEqualsToken,
        .LessThanLessThanEqualsToken,
        .GreaterThanGreaterThanEqualsToken,
        .GreaterThanGreaterThanGreaterThanEqualsToken,
        .AmpersandEqualsToken,
        .BarEqualsToken,
        .CaretEqualsToken,
        .BarBarEqualsToken,
        .AmpersandAmpersandEqualsToken,
        .QuestionQuestionEqualsToken,
        => true,
        else => false,
    };
}

/// Returns true if `node` is a prefix or postfix update expression
/// (`++x`, `x--`).
pub fn isUpdateExpression(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const kind = tree.getNodeKind(node);
    if (kind == .PrefixUnaryExpression) {
        const pu = tree.getNode(node).PrefixUnaryExpression;
        const op = tree.getNodeKind(pu.Operator);
        return op == .PlusPlusToken or op == .MinusMinusToken;
    }
    if (kind == .PostfixUnaryExpression) {
        const pu = tree.getNode(node).PostfixUnaryExpression;
        const op = tree.getNodeKind(pu.Operator);
        return op == .PlusPlusToken or op == .MinusMinusToken;
    }
    return false;
}

/// Returns true if the assignment target contains a `super` property
/// access (e.g. `super.x = ...` or `super[x] = ...`).
pub fn assignmentTargetContainsSuperProperty(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const kind = tree.getNodeKind(node);
    switch (kind) {
        .PropertyAccessExpression => {
            const pa = tree.getNode(node).PropertyAccessExpression;
            return tree.getNodeKind(pa.Expression) == .SuperKeyword;
        },
        .ElementAccessExpression => {
            const ea = tree.getNode(node).ElementAccessExpression;
            return tree.getNodeKind(ea.Expression) == .SuperKeyword;
        },
        .ParenthesizedExpression => {
            const pe = tree.getNode(node).ParenthesizedExpression;
            return assignmentTargetContainsSuperProperty(tree, pe.Expression);
        },
        else => return false,
    }
}

/// Creates the `left !== null && right !== void 0` condition used by
/// the nullish coalescing transformer.
///
/// Port of Go's `createNotNullCondition`. Full implementation requires
/// NodeFactory; returns 0 until wired.
pub fn createNotNullCondition(left: ast_gen.NodeIndex, right: ast_gen.NodeIndex, invert: bool) ast_gen.NodeIndex {
    _ = left;
    _ = right;
    _ = invert;
    // TODO(phase1.3): wire NodeFactory.NewBinaryExpression +
    // NewKeywordExpression(NewNullKeyword) + NewVoidZeroExpression
    return 0;
}

/// Converts a ClassDeclaration to a ClassExpression.
/// Port of Go's `convertClassDeclarationToClassExpression`.
/// TODO(phase1.3): wire EmitContext.Factory.NewClassExpression
pub fn convertClassDeclarationToClassExpression(node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    return node;
}
