const std = @import("std");
const ast = @import("../ast/ast.zig");
const compiler = @import("../compiler/program.zig");
const lsconv = @import("lsconv.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const lsutil = @import("lsutil/lsutil.zig");
const languageservice = @import("languageservice.zig");

/// getAllDiagnostics collects all diagnostics for a file: syntactic, semantic,
/// suggestion, and (when declarations are emitted) declaration diagnostics.
pub fn getAllDiagnostics(allocator: std.mem.Allocator, program: *compiler.Program, file: ast.NodeIndex) std.mem.Allocator.Error![]const *ast.Diagnostic {
    var diags = std.ArrayList(*ast.Diagnostic).init(allocator);
    errdefer diags.deinit();

    try diags.appendSlice(program.getSyntacticDiagnostics(file));
    try diags.appendSlice(program.getSemanticDiagnostics(file));
    try diags.appendSlice(program.getSuggestionDiagnostics(file));

    if (program.options().getEmitDeclarations()) {
        try diags.appendSlice(program.getDeclarationDiagnostics(file));
    }

    return diags.toOwnedSlice();
}

pub fn provideDiagnostics(
    self: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    uri: lsproto.DocumentUri,
) !lsproto.DocumentDiagnosticResponse {
    const program_and_file = self.getProgramAndFile(uri);
    const program = program_and_file.program;
    const file = program_and_file.file;

    const diagnostics = try getAllDiagnostics(allocator, program, file);

    const lsp_diagnostics = try self.toLSPDiagnostics(allocator, &[_][]const *ast.Diagnostic{diagnostics});

    return lsproto.DocumentDiagnosticResponse{
        .RelatedFullDocumentDiagnosticReportOrUnchangedDocumentDiagnosticReport = .{
            .FullDocumentDiagnosticReport = .{
                .items = lsp_diagnostics,
            },
        },
    };
}

pub fn toLSPDiagnostics(
    self: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    diagnostics_slices: []const []const *ast.Diagnostic,
) ![]const *lsproto.Diagnostic {
    var size: usize = 0;
    for (diagnostics_slices) |diag_slice| {
        size += diag_slice.len;
    }

    var lsp_diagnostics = try std.ArrayList(*lsproto.Diagnostic).initCapacity(allocator, size);
    errdefer lsp_diagnostics.deinit();

    const report_style_checks_as_warnings = self.userPreferences().reportStyleChecksAsWarnings.isTrue();

    for (diagnostics_slices) |diag_slice| {
        for (diag_slice) |diag| {
            const lsp_diag = try lsconv.diagnosticToLSPPull(
                allocator,
                self.converters,
                diag,
                report_style_checks_as_warnings,
            );
            lsp_diagnostics.appendAssumeCapacity(lsp_diag);
        }
    }

    return lsp_diagnostics.toOwnedSlice();
}
