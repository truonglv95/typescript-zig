//! Argument arity error reporting.
//!
//! Port of `internal/checker/checker.go::getArgumentArityError` and its
//! helpers (`getSpreadArgumentIndex`, `isSpreadArgument`, `isPromiseResolveArityError`,
//! `getErrorNodeForCallNode`).
//!
//! These functions report "Expected N arguments but got M" style diagnostics
//! when a call expression's argument count does not match any candidate
//! signature's parameter count.

const std = @import("std");

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");
const relater = @import("relater.zig");
const scanner = @import("../scanner/scanner.zig");
const types = @import("types.zig");

const Checker = @import("checker.zig").Checker;
const Diagnostic = diagnostics.Diagnostic;

/// Returns the index of the first spread element (or synthetic spread) in
/// `args`, or -1 if there is none.
///
/// Port of `checker.go::getSpreadArgumentIndex`.
pub fn getSpreadArgumentIndex(c: *Checker, args: []const ast_gen.NodeIndex) i32 {
    for (args, 0..) |arg, i| {
        if (isSpreadArgument(c, arg)) return @intCast(i);
    }
    return -1;
}

/// Returns true if `arg` is a `...spread` element or a synthetic expression
/// marked as spread.
///
/// Port of `checker.go::isSpreadArgument`.
pub fn isSpreadArgument(c: *Checker, arg: ast_gen.NodeIndex) bool {
    if (arg == 0) return false;
    const node = c.binder.ast.getNode(arg);
    return node == .SpreadElement;
}

/// Returns the node that an arity-error span should attach to for a call.
/// For most call forms this is the call node itself; for a decorator it is
/// the decorator's call expression (so the error points at `@dec(...)` not
/// at the decorated class/method).
///
/// Port of `checker.go::getErrorNodeForCallNode`.
pub fn getErrorNodeForCallNode(c: *Checker, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (node == 0) return 0;
    if (ast_utils.isDecorator(c.binder.ast, node)) {
        return ast_utils.expression(c.binder.ast, node);
    }
    return node;
}

/// Detects the specific shape `new Promise(resolve => ...)` where `resolve`
/// is invoked with zero arguments but the resolve signature expects at
/// least one. Used to produce a more actionable "Did you forget to include
/// `void` in your Promise type argument?" diagnostic.
///
/// Port of `checker.go::isPromiseResolveArityError`. Currently a conservative
/// stub that returns false because full name resolution is needed; the
/// fallback message is still emitted correctly.
pub fn isPromiseResolveArityError(c: *Checker, node: ast_gen.NodeIndex) bool {
    if (node == 0) return false;
    const tree = c.binder.ast;
    const node_data = tree.getNode(node);
    if (node_data != .CallExpression) return false;
    const callee = node_data.CallExpression.Expression;
    if (!ast_utils.isIdentifier(tree, callee)) return false;

    // TODO(phase1.1): wire `resolveName` to look up `Promise` global symbol,
    // then walk `symbol.ValueDeclaration` chain to confirm the shape:
    //   - `decl` is a Parameter
    //   - `decl.Parent` is FunctionExpression/ArrowFunction
    //   - `decl.Parent.Parent` is NewExpression
    //   - `decl.Parent.Parent.Expression` is Identifier "Promise"
    // For now, conservatively return false so callers fall back to the
    // generic "Expected 0 arguments but got 1" message.
    return false;
}

/// Builds the "Expected N arguments but got M" / "No overload expects N
/// arguments..." diagnostic for a call expression whose argument count
/// does not match any candidate signature.
///
/// Returns a freshly-allocated `Diagnostic` (owned by the caller via
/// `c.allocator`). The caller is responsible for invoking `c.addDiagnostic`
/// (or chaining with `ast.NewDiagnosticChain`).
///
/// Port of `checker.go::getArgumentArityError`.
///
/// Notes on divergence from the Go implementation:
/// - Go returns `*ast.Diagnostic` (heap-allocated, GC'd). Zig returns a
///   value `Diagnostic` whose `args` slice is allocator-owned.
/// - Go chains `headMessage` via `ast.NewDiagnosticChain`. The Zig
///   `Diagnostic` struct stores a `messageChain: []const Diagnostic` —
///   caller can append the head message there if needed; here we just
///   attach the primary message (matching the common case).
/// - "Related info" for missing parameters is attached via
///   `diagnostic.relatedInformation`, allocated on `c.allocator`.
pub fn getArgumentArityError(
    c: *Checker,
    node: ast_gen.NodeIndex,
    signatures: []const types.SignatureIndex,
    args: []const ast_gen.NodeIndex,
    head_message: ?*const diagnostics.Message,
) ?Diagnostic {
    const allocator = c.allocator;
    const tree = c.binder.ast;

    // Skip argument arity errors in JS files. In JavaScript, functions
    // accept any number of arguments (extra args go into `arguments`).
    if (ast_utils.isInJSFile(tree, node)) return null;

    // 1. Spread element check — produces a dedicated diagnostic.
    const spread_index = getSpreadArgumentIndex(c, args);
    if (spread_index > -1) {
        const arg_node = args[@intCast(spread_index)];
        return makeDiagnostic(allocator, arg_node, &diagnostics_gen.A_spread_argument_must_either_have_a_tuple_type_or_be_passed_to_a_rest_parameter, &.{}, null);
    }

    // 2. Walk candidate signatures to compute:
    //    - min_count: smallest min-argument count across signatures
    //    - max_count: largest max-argument count across signatures
    //    - max_below: largest param count that is *below* len(args)
    //    - min_above: smallest param count that is *above* len(args)
    //    - closest_signature: signature with min_count (for missing-param hint)
    var min_count: i32 = std.math.maxInt(i32);
    var max_count: i32 = std.math.minInt(i32);
    var max_below: i32 = std.math.minInt(i32);
    var min_above: i32 = std.math.maxInt(i32);
    var closest_signature: ?types.SignatureIndex = null;
    var has_rest_parameter = false;
    const args_len: i32 = @intCast(args.len);

    for (signatures) |sig| {
        const min_parameter: i32 = @intCast(relater.getMinArgumentCount(c, sig));
        const max_parameter: i32 = @intCast(relater.getParameterCount(c, sig));
        if (min_parameter < min_count) {
            min_count = min_parameter;
            closest_signature = sig;
        }
        if (max_parameter > max_count) max_count = max_parameter;
        if (min_parameter < args_len and min_parameter > max_below) max_below = min_parameter;
        if (args_len < max_parameter and max_parameter < min_above) min_above = max_parameter;
        if (relater.hasEffectiveRestParameter(c, sig)) has_rest_parameter = true;
    }

    // 3. Build the "parameter range" string ("N" or "N-M").
    var range_buf: [32]u8 = undefined;
    const parameter_range = if (has_rest_parameter)
        std.fmt.bufPrint(&range_buf, "{d}", .{min_count}) catch "0"
    else if (min_count < max_count)
        std.fmt.bufPrint(&range_buf, "{d}-{d}", .{ min_count, max_count }) catch "0"
    else
        std.fmt.bufPrint(&range_buf, "{d}", .{min_count}) catch "0";

    const is_void_promise_error = !has_rest_parameter and
        std.mem.eql(u8, parameter_range, "1") and
        args_len == 0 and
        isPromiseResolveArityError(c, node);

    const error_node = getErrorNodeForCallNode(c, node);
    if (is_void_promise_error and ast_utils.isInJSFile(tree, node)) {
        return makeDiagnostic(allocator, error_node, &diagnostics_gen.Expected_1_argument_but_got_0_new_Promise_needs_a_JSDoc_hint_to_produce_a_resolve_that_can_be_called_without_arguments, &.{}, null);
    }

    // 4. Select the primary message based on call form.
    const message: *const diagnostics.Message = blk: {
        if (ast_utils.isDecorator(tree, node)) {
            if (has_rest_parameter) {
                break :blk &diagnostics_gen.The_runtime_will_invoke_the_decorator_with_1_arguments_but_the_decorator_expects_at_least_0;
            } else {
                break :blk &diagnostics_gen.The_runtime_will_invoke_the_decorator_with_1_arguments_but_the_decorator_expects_0;
            }
        }
        if (has_rest_parameter) break :blk &diagnostics_gen.Expected_at_least_0_arguments_but_got_1;
        if (is_void_promise_error) break :blk &diagnostics_gen.Expected_0_arguments_but_got_1_Did_you_forget_to_include_void_in_your_type_argument_to_Promise;
        break :blk &diagnostics_gen.Expected_0_arguments_but_got_1;
    };

    // 5. Emit the appropriate branch of the error.
    const args_len_str = std.fmt.allocPrint(allocator, "{d}", .{args.len}) catch return null;
    var primary_args = allocator.alloc([]const u8, 2) catch return null;
    primary_args[0] = parameter_range;
    primary_args[1] = args_len_str;

    if (min_count < args_len and args_len < max_count) {
        // Between min and max — no matching overload.
        const max_below_str = std.fmt.allocPrint(allocator, "{d}", .{max_below}) catch return null;
        const min_above_str = std.fmt.allocPrint(allocator, "{d}", .{min_above}) catch return null;
        var no_overload_args = allocator.alloc([]const u8, 3) catch return null;
        no_overload_args[0] = args_len_str;
        no_overload_args[1] = max_below_str;
        no_overload_args[2] = min_above_str;
        return makeDiagnostic(
            allocator,
            error_node,
            &diagnostics_gen.No_overload_expects_0_arguments_but_overloads_do_exist_that_expect_either_1_or_2_arguments,
            no_overload_args,
            head_message,
        );
    } else if (args_len < min_count) {
        // Too few arguments — also attach a "parameter was not provided" related info.
        var diag = makeDiagnostic(allocator, error_node, message, primary_args, head_message) orelse return null;

        if (closest_signature) |sig| {
            const sig_decl = c.signatures.items[sig].declaration;
            if (sig_decl != 0) {
                const sig_params = ast_utils.getParametersOfNode(tree, sig_decl);
                const this_offset: usize = if (c.signatures.items[sig].thisParameter != null) 1 else 0;
                const target_idx: usize = @intCast(@as(usize, @intCast(args_len)) + this_offset);
                if (target_idx < sig_params.len) {
                    const param = sig_params[target_idx];
                    if (param != 0) {
                        const related = buildMissingParameterRelated(c, param) catch null;
                        if (related) |r| {
                            var related_slice = allocator.alloc(Diagnostic, 1) catch return diag;
                            related_slice[0] = r;
                            diag.relatedInformation = related_slice;
                        }
                    }
                }
            }
        }
        return diag;
    } else {
        // Too many arguments — span covers the excess args.
        if (max_count >= args_len) {
            // Arg count matches or is within range — no error.
            return null;
        }
        const source_file = ast_utils.getSourceFileOfNode(tree, node);
        const max_count_usize: usize = @intCast(max_count);
        var pos: u32 = tree.getNodePos(args[max_count_usize]);
        var end: u32 = tree.getNodeEnd(args[args.len - 1]);
        if (end == pos) end += 1;
        pos = @intCast(scanner.skipTrivia(getSourceFileText(c, source_file), pos));
        if (end < pos) end = pos;

        var diag = Diagnostic{
            .message = message,
            .nodeIndex = source_file,
            .args = primary_args,
            .pos = pos,
            .relatedInformation = &.{},
            .messageChain = &.{},
        };
        if (head_message) |hm| {
            var chain = allocator.alloc(Diagnostic, 1) catch return diag;
            chain[0] = .{
                .message = hm,
                .nodeIndex = source_file,
                .args = &.{},
                .pos = pos,
            };
            diag.messageChain = chain;
        }
        return diag;
    }
}

// ----------------------------------------------------------------------------
// Internal helpers
// ----------------------------------------------------------------------------

/// Convenience: build a `Diagnostic` value with optional head-message chain.
fn makeDiagnostic(
    allocator: std.mem.Allocator,
    node: ast_gen.NodeIndex,
    message: *const diagnostics.Message,
    args: []const []const u8,
    head_message: ?*const diagnostics.Message,
) ?Diagnostic {
    var diag = Diagnostic{
        .message = message,
        .nodeIndex = node,
        .args = args,
        .pos = 0,
        .relatedInformation = &.{},
        .messageChain = &.{},
    };
    if (head_message) |hm| {
        var chain = allocator.alloc(Diagnostic, 1) catch return diag;
        chain[0] = .{
            .message = hm,
            .nodeIndex = node,
            .args = &.{},
        };
        diag.messageChain = chain;
    }
    return diag;
}

/// Builds the "An argument for X was not provided" / "Arguments for the
/// rest parameter X were not provided" / "An argument matching this
/// binding pattern was not provided" related-info diagnostic.
fn buildMissingParameterRelated(c: *Checker, param: ast_gen.NodeIndex) !Diagnostic {
    const tree = c.binder.ast;
    if (ast_utils.isBindingPattern(tree, param)) {
        return Diagnostic{
            .message = &diagnostics_gen.An_argument_matching_this_binding_pattern_was_not_provided,
            .nodeIndex = param,
            .args = &.{},
        };
    }
    if (isRestParameter(tree, param)) {
        const name_node = ast_utils.name(tree, param);
        const name_text = ast_utils.getText(tree, name_node);
        const args = try c.allocator.alloc([]const u8, 1);
        args[0] = name_text;
        return Diagnostic{
            .message = &diagnostics_gen.Arguments_for_the_rest_parameter_0_were_not_provided,
            .nodeIndex = param,
            .args = args,
        };
    }
    const name_node = ast_utils.name(tree, param);
    const name_text = ast_utils.getText(tree, name_node);
    const args = try c.allocator.alloc([]const u8, 1);
    args[0] = name_text;
    return Diagnostic{
        .message = &diagnostics_gen.An_argument_for_0_was_not_provided,
        .nodeIndex = param,
        .args = args,
    };
}

/// Returns true if `param` is a rest parameter (`...x`).
/// Port of `checker.go::isRestParameter`.
fn isRestParameter(tree: *ast.Ast, param: ast_gen.NodeIndex) bool {
    if (param == 0) return false;
    const node = tree.getNode(param);
    switch (node) {
        .Parameter => |p| return p.DotDotDotToken != null,
        else => return false,
    }
}

/// Returns the source text of the file containing `source_file`.
///
/// In typescript-zig the source text is stored once on the `Ast` struct
/// (`Ast.sourceText`), not on each `SourceFile` node. We accept the
/// `source_file` parameter for parity with the Go API but ignore it —
/// the AST already knows its own text.
fn getSourceFileText(c: *Checker, source_file: ast_gen.NodeIndex) []const u8 {
    _ = source_file;
    return c.binder.ast.sourceText;
}
