//! "use strict" directive transformer.
//! Port of `internal/transformers/estransforms/usestrict.go` (50 LOC).
//!
//! Prepends a `"use strict";` directive to source files that need it
//! (non-ESM files when emitting strict mode).

const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");

/// Determines whether a source file needs a "use strict" directive.
/// Returns false for ESM files (already strict) and JSON files.
pub fn needsUseStrict(tree: *ast.Ast, source_file: ast_gen.NodeIndex, is_external_module: bool, module_kind: u32, emit_format: u32) bool {
    _ = tree;
    _ = source_file;
    // JSON files never need use strict.
    // TODO(phase1.3): check ScriptKind == JSON.
    // ESM is always strict. If the file is ESM and CJS emit has not been
    // requested, skip adding "use strict".
    if (is_external_module and module_kind >= 5) { // ModuleKindES2015 = 5
        if (module_kind == 13 or emit_format >= 5) { // ModuleKindPreserve = 13
            return false;
        }
    }
    return true;
}
