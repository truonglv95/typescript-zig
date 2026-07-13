const std = @import("std");

//! For-await-of transformer.
//!
//! Port of `internal/transformers/estransforms/forawait.go` (856 LOC).
//!
//! Down-levels `for await (const x of iterable)` loops to use the
//! async iterator protocol via `__asyncValues` / `__asyncDelegator`
//! helpers for targets that don't support for-await-of natively
//! (pre-ES2018).
//!
//! The transformation also handles:
//! - `super` property accesses in async generator bodies (via SuperAccessState)
//! - `yield*` delegation to async iterables
//! - Top-level await in async generators

const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const utilities = @import("utilities.zig");

/// Hierarchy facts tracked during for-await transformation.
/// Port of Go's `forAwaitHierarchyFacts`.
pub const ForAwaitHierarchyFacts = struct {
    pub const None: u32 = 0;
    pub const HasLexicalThis: u32 = 1 << 0;
    pub const IterationContainer: u32 = 1 << 1;
    pub const AncestorFactsMask: u32 = (1 << 2) - 1;
    pub const SourceFileExcludes: u32 = IterationContainer;
    pub const StrictModeSourceFileIncludes: u32 = None;
    pub const ClassOrFunctionIncludes: u32 = HasLexicalThis;
    pub const ClassOrFunctionExcludes: u32 = IterationContainer;
    pub const ArrowFunctionIncludes: u32 = None;
    pub const ArrowFunctionExcludes: u32 = ClassOrFunctionExcludes;
    pub const IterationStatementIncludes: u32 = IterationContainer;
    pub const IterationStatementExcludes: u32 = None;
};

/// For-await transformer state.
/// Port of Go's `forawaitTransformer` (core fields only).
pub const ForAwaitTransformer = struct {
    super_access_state: utilities.SuperAccessState,
    hierarchy_facts: u32 = ForAwaitHierarchyFacts.None,
    enclosing_function_flags: u32 = 0,
    exported_variable_statement: bool = false,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ForAwaitTransformer {
        return .{
            .super_access_state = utilities.SuperAccessState.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ForAwaitTransformer) void {
        self.super_access_state.deinit();
    }

    /// Enters a subtree, updating the hierarchy facts.
    /// Returns the previous facts for restoration on exit.
    pub fn enterSubtree(self: *ForAwaitTransformer, exclude: u32, include: u32) u32 {
        const previous = self.hierarchy_facts;
        self.hierarchy_facts = ((self.hierarchy_facts & ~exclude) | include) & ForAwaitHierarchyFacts.AncestorFactsMask;
        return previous;
    }

    /// Exits a subtree, restoring the previous hierarchy facts.
    pub fn exitSubtree(self: *ForAwaitTransformer, previous: u32) void {
        self.hierarchy_facts = previous;
    }

    /// Checks if entering a subtree with the given exclude/include facts
    /// would change the current hierarchy facts.
    pub fn affectsSubtree(self: *const ForAwaitTransformer, exclude: u32, include: u32) bool {
        return self.hierarchy_facts != ((self.hierarchy_facts & ~exclude) | include);
    }

    /// Visits a node, transforming for-await-of loops.
    /// Port of Go's `forawaitTransformer.visit`.
    pub fn visit(self: *ForAwaitTransformer, tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        if (node == 0) return 0;
        const kind = tree.getNodeKind(node);

        switch (kind) {
            .ForOfStatement => {
                // Check if this is a `for await` loop.
                const for_of = tree.getNode(node).ForOfStatement;
                if (for_of.AwaitModifier != null and for_of.AwaitModifier.? != 0) {
                    return self.transformForAwaitOf(tree, node);
                }
                return node;
            },
            .SourceFile => {
                const previous = self.enterSubtree(
                    ForAwaitHierarchyFacts.SourceFileExcludes,
                    ForAwaitHierarchyFacts.StrictModeSourceFileIncludes,
                );
                defer self.exitSubtree(previous);
                return node; // Visit children would go here
            },
            .ClassDeclaration, .ClassExpression => {
                const previous = self.enterSubtree(
                    ForAwaitHierarchyFacts.ClassOrFunctionExcludes,
                    ForAwaitHierarchyFacts.ClassOrFunctionIncludes,
                );
                defer self.exitSubtree(previous);
                return node;
            },
            .FunctionDeclaration, .FunctionExpression, .MethodDeclaration,
            .GetAccessor, .SetAccessor, .Constructor => {
                const previous = self.enterSubtree(
                    ForAwaitHierarchyFacts.ClassOrFunctionExcludes,
                    ForAwaitHierarchyFacts.ClassOrFunctionIncludes,
                );
                defer self.exitSubtree(previous);
                return node;
            },
            .ArrowFunction => {
                const previous = self.enterSubtree(
                    ForAwaitHierarchyFacts.ArrowFunctionExcludes,
                    ForAwaitHierarchyFacts.ArrowFunctionIncludes,
                );
                defer self.exitSubtree(previous);
                return node;
            },
            .ForStatement, .ForInStatement, .WhileStatement, .DoStatement => {
                const previous = self.enterSubtree(
                    ForAwaitHierarchyFacts.IterationStatementExcludes,
                    ForAwaitHierarchyFacts.IterationStatementIncludes,
                );
                defer self.exitSubtree(previous);
                return node;
            },
            else => return node,
        }
    }

    /// Transforms a `for await (const x of iter)` loop.
    ///
    /// The transformation wraps the iterable in `__asyncValues(iter)` and
    /// converts the loop to use the async iterator protocol.
    ///
    /// TODO(phase1.3): Full implementation requires NodeFactory for
    /// creating the transformed loop structure.
    fn transformForAwaitOf(self: *ForAwaitTransformer, tree: *ast.Ast, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        _ = self;
        _ = tree;
        // Full implementation:
        // 1. Wrap the iterable in __asyncValues(...)
        // 2. Create a temp variable for the async iterator
        // 3. Convert the for-await loop to a while loop using .next()
        // 4. Handle super accesses in the body (if in async generator)
        return node;
    }
};

/// Checks whether a node is a `for await` loop (ForOfStatement with
/// AwaitModifier).
pub fn isForAwaitOf(tree: *ast.Ast, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    if (tree.getNodeKind(node) != .ForOfStatement) return false;
    const for_of = tree.getNode(node).ForOfStatement;
    return for_of.AwaitModifier != null and for_of.AwaitModifier.? != 0;
}
