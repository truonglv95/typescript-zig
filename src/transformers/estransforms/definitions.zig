const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");

//! ES transform chain definitions.
//! Port of `internal/transformers/estransforms/definitions.go` (43 LOC).
//!
//! Defines the transformer chain for each ES target version.
//! Each chain composes smaller transformers (using, decorators, class
//! fields, async, exponentiation, etc.) to down-level the input.

/// Returns the appropriate ES transformer chain for the given target.
/// Port of Go's `GetESTransformer`.
pub fn getESTransformer(target: []const u8) []const u8 {
    // Returns the transformer chain name for the given target.
    // Full implementation requires transformer composition; for now,
    // returns the chain name as a string identifier.
    if (std.ascii.eqlIgnoreCase(target, "esnext")) return "esDecoratorAndClassFields";
    if (std.ascii.eqlIgnoreCase(target, "es2025")) return "esNext";
    if (std.ascii.eqlIgnoreCase(target, "es2024")) return "esNext";
    if (std.ascii.eqlIgnoreCase(target, "es2023")) return "esNext";
    if (std.ascii.eqlIgnoreCase(target, "es2022")) return "esNext";
    if (std.ascii.eqlIgnoreCase(target, "es2021")) return "esNext+logicalAssignment";
    if (std.ascii.eqlIgnoreCase(target, "es2020")) return "es2021+nullishCoalescing+optionalChain";
    if (std.ascii.eqlIgnoreCase(target, "es2019")) return "es2020+optionalCatch";
    if (std.ascii.eqlIgnoreCase(target, "es2018")) return "es2019+objectRestSpread+forawait+taggedTemplate";
    if (std.ascii.eqlIgnoreCase(target, "es2017")) return "es2018+async";
    if (std.ascii.eqlIgnoreCase(target, "es2016")) return "es2017+exponentiation";
    return "es2016"; // default: transform maximally
}
