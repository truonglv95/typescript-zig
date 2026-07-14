const std = @import("std");

//! Implied module transformer.
//!
//! Port of `internal/transformers/moduletransforms/impliedmodule.go` (53 LOC).
//!
//! A transformer that delegates to either the ES module transformer or
//! the CommonJS module transformer based on the emit module format of
//! each source file. Used when the module kind is not explicitly set
//! (e.g. `--module preserve` or auto-detection).

const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const transformer_pkg = @import("../transformer.zig");

/// Implied module transformer — lazily creates ESM and CJS sub-transformers
/// and delegates based on the file's module format.
pub const ImpliedModuleTransformer = struct {
    opts: *transformer_pkg.TransformOptions,
    esm_transformer: ?*transformer_pkg.Transformer = null,
    cjs_transformer: ?*transformer_pkg.Transformer = null,

    /// Creates a new implied module transformer.
    pub fn init(opts: *transformer_pkg.TransformOptions) ImpliedModuleTransformer {
        return .{ .opts = opts };
    }

    /// Visits a node, delegating SourceFile nodes to the appropriate
    /// sub-transformer based on the file's module format.
    pub fn visit(self: *ImpliedModuleTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        const tree = self.opts.context.tree;
        const kind = tree.getNodeKind(node);
        if (kind == .SourceFile) {
            return self.visitSourceFile(node);
        }
        return node;
    }

    /// Transforms a source file by delegating to ESM or CJS transformer.
    pub fn visitSourceFile(self: *ImpliedModuleTransformer, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
        // Skip declaration files.
        const sf = self.opts.context.tree.getNode(node);
        if (sf == .SourceFile) {
            // TODO(phase1.3): check IsDeclarationFile flag on SourceFile node.
            // For now, proceed with transformation.
        }

        // Get the emit module format for this file.
        // TODO(phase1.3): wire getEmitModuleFormatOfFile.
        // For now, default to ES2015 (ESM).
        const format: u32 = 5; // ModuleKindES2015 = 5

        // Delegate to the appropriate sub-transformer.
        if (format >= 5) { // ModuleKindES2015
            if (self.esm_transformer == null) {
                // TODO(phase1.3): wire NewESModuleTransformer
            }
            // TODO(phase1.3): delegate to esm_transformer.TransformSourceFile
        } else {
            if (self.cjs_transformer == null) {
                // TODO(phase1.3): wire NewCommonJSModuleTransformer
            }
            // TODO(phase1.3): delegate to cjs_transformer.TransformSourceFile
        }

        return node;
    }
};
