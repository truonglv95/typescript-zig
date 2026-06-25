const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const collections = @import("../collections/collections.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const tsoptions = @import("../tsoptions/tsoptions.zig");
const tspath = @import("../tspath/tspath.zig");
const program_module = @import("program.zig");

pub const FileIncludeReason = struct {
    // Placeholder for actual fields
    pub fn isReferencedFile(self: *FileIncludeReason) bool {
        _ = self;
        return false;
    }
    
    pub fn getReferencedLocation(self: *FileIncludeReason, program: *program_module.Program) *ReferenceFileLocation {
        _ = self;
        _ = program;
        return undefined;
    }
    
    pub fn toRelatedInfo(self: *FileIncludeReason, program: *program_module.Program) *ast.Diagnostic {
        _ = self;
        _ = program;
        return undefined;
    }
};

pub const ReferenceFileLocation = struct {};

pub const ProcessingDiagnosticKind = enum {
    ExplainingFileInclude,
};

pub const IncludeExplainingDiagnostic = struct {
    file: tspath.Path,
    diagnosticReason: *FileIncludeReason,
    message: diagnostics.DiagnosticMessage,
    args: [][]const u8,
};

pub const ProcessingDiagnostic = struct {
    kind: ProcessingDiagnosticKind,
    data: IncludeExplainingDiagnostic,
    
    pub fn toDiagnostic(self: *ProcessingDiagnostic, program: *program_module.Program) ast.Diagnostic {
        _ = self;
        _ = program;
        return undefined;
    }
};

pub const IncludeProcessor = struct {
    fileIncludeReasons: std.AutoHashMap(tspath.Path, std.ArrayList(*FileIncludeReason)),
    processingDiagnostics: std.ArrayList(*ProcessingDiagnostic),

    reasonToReferenceLocation: collections.SyncMap(*FileIncludeReason, *ReferenceFileLocation),
    includeReasonToRelatedInfo: collections.SyncMap(*FileIncludeReason, *ast.Diagnostic),
    redirectAndFileFormat: collections.SyncMap(tspath.Path, []*ast.Diagnostic),
    computedDiagnostics: ?*ast.DiagnosticsCollection = null,
    
    computedDiagnosticsOnce: std.once,
    compilerOptionsSyntax: ?ast_gen.NodeIndex = null,
    compilerOptionsSyntaxOnce: std.once,
    
    pub fn updateFileIncludeProcessor(p: *program_module.Program) void {
        p.includeProcessor = IncludeProcessor{
            .fileIncludeReasons = p.includeProcessor.fileIncludeReasons,
            .processingDiagnostics = p.includeProcessor.processingDiagnostics,
            .reasonToReferenceLocation = collections.SyncMap(*FileIncludeReason, *ReferenceFileLocation).init(),
            .includeReasonToRelatedInfo = collections.SyncMap(*FileIncludeReason, *ast.Diagnostic).init(),
            .redirectAndFileFormat = collections.SyncMap(tspath.Path, []*ast.Diagnostic).init(),
            .computedDiagnosticsOnce = std.once.init(),
            .compilerOptionsSyntaxOnce = std.once.init(),
        };
    }

    pub fn getDiagnostics(self: *IncludeProcessor, p: *program_module.Program) *ast.DiagnosticsCollection {
        self.computedDiagnosticsOnce.call(struct {
            fn doOnce(i: *IncludeProcessor, prog: *program_module.Program) void {
                i.computedDiagnostics = &ast.DiagnosticsCollection{}; // Requires proper allocation in practice
                for (i.processingDiagnostics.items) |d| {
                    i.computedDiagnostics.?.add(d.toDiagnostic(prog));
                }
                for (prog.resolvedModules.items) |resolutions| {
                    for (resolutions) |resolvedModule| {
                        for (resolvedModule.resolutionDiagnostics) |diag| {
                            i.computedDiagnostics.?.add(diag);
                        }
                    }
                }
                for (prog.typeResolutionsInFile.items) |typeResolutions| {
                    for (typeResolutions) |resolvedTypeRef| {
                        for (resolvedTypeRef.resolutionDiagnostics) |diag| {
                            i.computedDiagnostics.?.add(diag);
                        }
                    }
                }
            }
        }.doOnce, .{self, p});
        return self.computedDiagnostics.?;
    }

    pub fn addProcessingDiagnostic(self: *IncludeProcessor, d: []const *ProcessingDiagnostic) void {
        self.processingDiagnostics.appendSlice(d) catch unreachable;
    }

    pub fn addProcessingDiagnosticsForFileCasing(self: *IncludeProcessor, file: tspath.Path, existingCasing: []const u8, currentCasing: []const u8, reason: *FileIncludeReason) void {
        var hasReferencedFile = false;
        if (self.fileIncludeReasons.get(file)) |reasons| {
            for (reasons.items) |r| {
                if (r.isReferencedFile()) {
                    hasReferencedFile = true;
                    break;
                }
            }
        }
        
        // Memory allocation for args omitted for simplicity, a real implementation needs an allocator.
        var args: [][]const u8 = undefined;

        if (!reason.isReferencedFile() and hasReferencedFile) {
            args = &[_][]const u8{existingCasing, currentCasing};
            var pd = ProcessingDiagnostic{
                .kind = .ExplainingFileInclude,
                .data = .{
                    .file = file,
                    .diagnosticReason = reason,
                    .message = diagnostics.Already_included_file_name_0_differs_from_file_name_1_only_in_casing,
                    .args = args,
                },
            };
            self.processingDiagnostics.append(&pd) catch unreachable;
        } else {
            args = &[_][]const u8{currentCasing, existingCasing};
            var pd = ProcessingDiagnostic{
                .kind = .ExplainingFileInclude,
                .data = .{
                    .file = file,
                    .diagnosticReason = reason,
                    .message = diagnostics.File_name_0_differs_from_already_included_file_name_1_only_in_casing,
                    .args = args,
                },
            };
            self.processingDiagnostics.append(&pd) catch unreachable;
        }
    }

    pub fn getReferenceLocation(self: *IncludeProcessor, r: *FileIncludeReason, program: *program_module.Program) *ReferenceFileLocation {
        if (self.reasonToReferenceLocation.load(r)) |existing| {
            return existing;
        }
        const loc = self.reasonToReferenceLocation.loadOrStore(r, r.getReferencedLocation(program)).value_or_loaded;
        return loc;
    }

    pub fn getCompilerOptionsObjectLiteralSyntax(self: *IncludeProcessor, program: *program_module.Program) ?ast_gen.NodeIndex {
        self.compilerOptionsSyntaxOnce.call(struct {
            fn doOnce(i: *IncludeProcessor, prog: *program_module.Program) void {
                if (prog.opts.config.configFile) |configFile| {
                    if (tsoptions.forEachTsConfigPropArray(configFile.sourceFile, "compilerOptions", core.identity)) |compilerOptionsProperty| {
                        if (compilerOptionsProperty.initializer) |init| {
                            if (ast.isObjectLiteralExpression(prog.astState, init)) {
                                i.compilerOptionsSyntax = init;
                            }
                        }
                    }
                } else {
                    i.compilerOptionsSyntax = null;
                }
            }
        }.doOnce, .{self, program});
        return self.compilerOptionsSyntax;
    }

    pub fn getRelatedInfo(self: *IncludeProcessor, r: *FileIncludeReason, program: *program_module.Program) *ast.Diagnostic {
        if (self.includeReasonToRelatedInfo.load(r)) |existing| {
            return existing;
        }
        const relatedInfo = self.includeReasonToRelatedInfo.loadOrStore(r, r.toRelatedInfo(program)).value_or_loaded;
        return relatedInfo;
    }

    pub fn explainRedirectAndImpliedFormat(
        self: *IncludeProcessor,
        program: *program_module.Program,
        filePath: tspath.Path,
        toFileName: *const fn(fileName: []const u8) []const u8,
    ) []*ast.Diagnostic {
        if (self.redirectAndFileFormat.load(filePath)) |existing| {
            return existing;
        }
        
        var file: ast_gen.NodeIndex = 0;
        var sourceFile: ast_gen.NodeIndex = 0;
        
        const redirectsFile = program.redirectFilesByPath.get(filePath);
        if (redirectsFile) |rf| {
            file = rf;
        } else {
            const sf = program.getSourceFileByPath(filePath);
            if (sf == 0) {
                return &[_]*ast.Diagnostic{};
            }
            sourceFile = sf;
            file = sourceFile;
        }
        
        var result = std.ArrayList(*ast.Diagnostic).init(program.allocator);
        const source = program.getSourceOfProjectReferenceIfOutputIncluded(file);
        const fileName = ast.getFileName(program.astState, file) catch "";
        
        if (!std.mem.eql(u8, source, fileName)) {
            result.append(ast.newCompilerDiagnostic(
                diagnostics.File_is_output_of_project_reference_source_0,
                toFileName(source),
            )) catch unreachable;
        }

        if (redirectsFile) |rf| {
            const targetFile = program.getSourceFileByPath(rf.target);
            const targetFileName = ast.getFileName(program.astState, targetFile) catch "";
            result.append(ast.newCompilerDiagnostic(
                diagnostics.File_redirects_to_file_0,
                toFileName(targetFileName),
            )) catch unreachable;
        }

        if (sourceFile != 0 and ast.isExternalOrCommonJSModule(program.astState, sourceFile)) {
            const metaData = program.getSourceFileMetaData(ast.getPath(program.astState, file) catch "");
            const format = program.getImpliedNodeFormatForEmit(file);
            if (format == core.ModuleKind.ESNext) {
                if (std.mem.eql(u8, metaData.packageJsonType, "module")) {
                    const packageJsonPath = std.fmt.allocPrint(program.allocator, "{s}/package.json", .{metaData.packageJsonDirectory}) catch unreachable;
                    result.append(ast.newCompilerDiagnostic(
                        diagnostics.File_is_ECMAScript_module_because_0_has_field_type_with_value_module,
                        toFileName(packageJsonPath),
                    )) catch unreachable;
                }
            } else if (format == core.ModuleKind.CommonJS) {
                if (metaData.packageJsonType.len != 0) {
                    const packageJsonPath = std.fmt.allocPrint(program.allocator, "{s}/package.json", .{metaData.packageJsonDirectory}) catch unreachable;
                    result.append(ast.newCompilerDiagnostic(
                        diagnostics.File_is_CommonJS_module_because_0_has_field_type_whose_value_is_not_module,
                        toFileName(packageJsonPath),
                    )) catch unreachable;
                } else if (metaData.packageJsonDirectory.len != 0) {
                    if (metaData.packageJsonType.len == 0) {
                        const packageJsonPath = std.fmt.allocPrint(program.allocator, "{s}/package.json", .{metaData.packageJsonDirectory}) catch unreachable;
                        result.append(ast.newCompilerDiagnostic(
                            diagnostics.File_is_CommonJS_module_because_0_does_not_have_field_type,
                            toFileName(packageJsonPath),
                        )) catch unreachable;
                    }
                } else {
                    result.append(ast.newCompilerDiagnostic(
                        diagnostics.File_is_CommonJS_module_because_package_json_was_not_found,
                        "",
                    )) catch unreachable;
                }
            }
        }

        const outResult = result.toOwnedSlice() catch unreachable;
        const loaded = self.redirectAndFileFormat.loadOrStore(filePath, outResult).value_or_loaded;
        return loaded;
    }
};
