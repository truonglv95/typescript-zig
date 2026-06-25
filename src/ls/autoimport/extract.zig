const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const binder = @import("../../binder/binder.zig");
const checker = @import("../../checker/checker.zig");
const core = @import("../../core/core.zig");
const lsutil = @import("../lsutil/lsutil.zig");
const module = @import("../../module/module.zig");
const tspath = @import("../../tspath/tspath.zig");
const export_mod = @import("export.zig");
const util = @import("util.zig");
const registry = @import("registry.zig");

pub const ExtractorStats = struct {
    exports: u32,
    usedChecker: u32,
};

pub const SymbolExtractor = struct {
    packageName: []const u8,
    stats: *ExtractorStats,

    localNameResolver: binder.NameResolver,
    chk: *checker.Checker,
    toPath: ?*const fn (fileName: []const u8) tspath.Path,
    realpath: ?*const fn (fileName: []const u8) []const u8,
    astCtx: *ast.Ast,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        astCtx: *ast.Ast,
        packageName: []const u8,
        chk: *checker.Checker,
        toPath: ?*const fn (fileName: []const u8) tspath.Path,
        realpath: ?*const fn (fileName: []const u8) []const u8,
    ) *SymbolExtractor {
        var e = allocator.create(SymbolExtractor) catch unreachable;
        var stats = allocator.create(ExtractorStats) catch unreachable;
        stats.* = .{ .exports = 0, .usedChecker = 0 };

        e.* = .{
            .packageName = packageName,
            .stats = stats,
            .localNameResolver = binder.NameResolver.init(astCtx, chk.binder, null),
            .chk = chk,
            .toPath = toPath,
            .realpath = realpath,
            .astCtx = astCtx,
            .allocator = allocator,
        };
        return e;
    }

    pub fn getModuleID(self: *SymbolExtractor, fileIdx: ast.NodeIndex) export_mod.ModuleID {
        // Assume AST or symbol system provides file name and path
        const fileName = util.getFileName(self.astCtx, fileIdx);
        if (self.realpath != null and self.toPath != null) {
            const real = self.realpath.?(fileName);
            return @as(export_mod.ModuleID, @ptrCast(self.toPath.?(real).path));
        }
        return @as(export_mod.ModuleID, @ptrCast(util.getFilePath(self.astCtx, fileIdx)));
    }

    pub fn getModuleIDForSymbol(self: *SymbolExtractor, symIdx: ast_gen.SymbolIndex) ?export_mod.ModuleID {
        const id_and_name = util.tryGetModuleIDAndFileNameOfModuleSymbol(self.astCtx, symIdx);
        if (id_and_name == null) return null;
        
        const moduleID = id_and_name.?.moduleID;
        const fileName = id_and_name.?.fileName;

        if (fileName.len > 0 and self.realpath != null) {
            const decl = util.getNonAugmentationDeclaration(self.astCtx, symIdx);
            if (decl != 0) {
                // if decl is SourceFile
                // We simplify the kind check here
                return self.getModuleID(decl);
            }
        }
        return moduleID;
    }

    pub fn extractFromSymbol(
        self: *SymbolExtractor,
        name: []const u8,
        symIdx: ast_gen.SymbolIndex,
        moduleID: export_mod.ModuleID,
        moduleFileName: []const u8,
        fileIdx: ast.NodeIndex,
        exports: *std.ArrayListUnmanaged(*export_mod.Export),
    ) void {
        if (shouldIgnoreSymbol(self.astCtx, symIdx)) {
            return;
        }

        if (std.mem.eql(u8, name, "__export")) { // ast.InternalSymbolNameExportStar
            var chkLease = CheckerLease{ .used = false, .checker_instance = self.chk };
            
            // This needs an implementation of GetExportsOfModule
            const allExports = util.getExportsOfModule(self.astCtx, self.chk, util.getSymbolParent(self.astCtx, symIdx));
            
            // ... omitting complex export star logic for DoD parity structure ...
            for (allExports) |reexportedSymbol| {
                const result = self.createExport(reexportedSymbol, moduleID, moduleFileName, export_mod.ExportSyntax.Star, fileIdx, &chkLease);
                if (result.export_ptr) |exp| {
                    // find target module ID
                    exp.through = "__export";
                    exports.append(self.allocator, exp) catch unreachable;
                }
            }
            return;
        }

        const syntax = getSyntax(self.astCtx, symIdx);
        var chkLease = CheckerLease{ .used = false, .checker_instance = self.chk };
        const result = self.createExport(symIdx, moduleID, moduleFileName, syntax, fileIdx, &chkLease);
        
        if (result.export_ptr == null) {
            return;
        }

        exports.append(self.allocator, result.export_ptr.?) catch unreachable;

        if (result.targetSymbol != 0) {
            if (syntax == .Equals) { // ExportSyntaxEquals
                // ... handle namespace exports ...
            }
        } else if (syntax == .CommonJSModuleExports) {
            // ... handle CommonJSModuleExports ...
        }
    }

    pub const CreateExportResult = struct {
        export_ptr: ?*export_mod.Export,
        targetSymbol: ast_gen.SymbolIndex,
    };

    pub fn createExport(
        self: *SymbolExtractor,
        symIdx: ast_gen.SymbolIndex,
        moduleID: export_mod.ModuleID,
        moduleFileName: []const u8,
        syntax: export_mod.ExportSyntax,
        fileIdx: ast.NodeIndex,
        chkLease: *CheckerLease,
    ) CreateExportResult {
        if (shouldIgnoreSymbol(self.astCtx, symIdx)) {
            return .{ .export_ptr = null, .targetSymbol = 0 };
        }

        var export_ptr = self.allocator.create(export_mod.Export) catch unreachable;
        export_ptr.* = .{
            .ExportID = .{
                .ModuleID = moduleID,
                .ExportName = util.getSymbolName(self.astCtx, symIdx),
            },
            .ModuleFileName = moduleFileName,
            .Syntax = syntax,
            .Flags = util.getCombinedLocalAndExportSymbolFlags(self.astCtx, symIdx),
            .Path = util.getFilePath(self.astCtx, fileIdx),
            .PackageName = self.packageName,
            .localName = "",
            .through = "",
            .Target = undefined,
            .IsTypeOnly = false,
            .ScriptElementKind = .unknown,
            .ScriptElementKindModifiers = .none,
        };

        if (syntax == .UMD) {
            export_ptr.ExportID.ExportName = "export=";
            export_ptr.localName = util.getSymbolName(self.astCtx, symIdx);
        }

        var targetSymbol: ast_gen.SymbolIndex = 0;
        const symFlags = util.getSymbolFlags(self.astCtx, symIdx);
        
        if ((symFlags & 0x200000) != 0) { // ast.SymbolFlagsAlias
            targetSymbol = self.tryResolveSymbol(symIdx, syntax, chkLease);
            if (targetSymbol != 0) {
                // Populate export_ptr.Flags, ScriptElementKind, Target...
            }
        }

        if (isUnusableName(export_ptr.Name())) {
            return .{ .export_ptr = null, .targetSymbol = 0 };
        }

        self.stats.exports += 1;
        if (chkLease.tryChecker() != null) {
            self.stats.usedChecker += 1;
        }

        return .{ .export_ptr = export_ptr, .targetSymbol = targetSymbol };
    }

    pub fn tryResolveSymbol(self: *SymbolExtractor, symIdx: ast_gen.SymbolIndex, syntax: export_mod.ExportSyntax, chkLease: *CheckerLease) ast_gen.SymbolIndex {
        // ... DoD specific implementation
        _ = syntax;
        const chk = chkLease.getChecker();
        // Return resolved alias
        return util.getAliasedSymbol(self.astCtx, chk, symIdx);
    }
};

pub const ExportExtractor = struct {
    symbolExtractor: *SymbolExtractor,
    moduleResolver: *module.Resolver,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        symbolExtractor: *SymbolExtractor,
        moduleResolver: *module.Resolver,
    ) *ExportExtractor {
        var e = allocator.create(ExportExtractor) catch unreachable;
        e.* = .{
            .symbolExtractor = symbolExtractor,
            .moduleResolver = moduleResolver,
            .allocator = allocator,
        };
        return e;
    }

    pub fn stats(self: *ExportExtractor) *ExtractorStats {
        return self.symbolExtractor.stats;
    }

    pub fn extractFromFile(self: *ExportExtractor, fileIdx: ast.NodeIndex) []*export_mod.Export {
        const astCtx = self.symbolExtractor.astCtx;
        
        if (astCtx.getNodeSymbol(fileIdx) != null) {
            return self.extractFromModule(fileIdx);
        }
        
        // Check AmbientModuleNames
        if (util.hasAmbientModuleNames(astCtx, fileIdx)) {
            // ... Extract from module declarations
        }
        
        return &[_]*export_mod.Export{};
    }

    pub fn extractFromModule(self: *ExportExtractor, fileIdx: ast.NodeIndex) []*export_mod.Export {
        const astCtx = self.symbolExtractor.astCtx;
        var exports = std.ArrayListUnmanaged(*export_mod.Export).empty;
        
        const moduleID = self.symbolExtractor.getModuleID(fileIdx);
        const symIdx = astCtx.getNodeSymbol(fileIdx).?;
        const moduleFileName = util.getFileName(astCtx, fileIdx);

        // Iterate over exports of the file symbol
        const fileExports = util.getSymbolExports(astCtx, symIdx);
        for (fileExports) |expSymIdx| {
            const name = util.getSymbolName(astCtx, expSymIdx);
            self.symbolExtractor.extractFromSymbol(name, expSymIdx, moduleID, moduleFileName, fileIdx, &exports);
        }

        return exports.items;
    }

    pub fn extractFromModuleDeclaration(
        self: *ExportExtractor,
        declIdx: ast.NodeIndex,
        fileIdx: ast.NodeIndex,
        moduleID: export_mod.ModuleID,
        moduleFileName: []const u8,
        exports: *std.ArrayListUnmanaged(*export_mod.Export),
    ) void {
        const astCtx = self.symbolExtractor.astCtx;
        const symIdx = astCtx.getNodeSymbol(declIdx).?;
        const declExports = util.getSymbolExports(astCtx, symIdx);

        for (declExports) |expSymIdx| {
            const name = util.getSymbolName(astCtx, expSymIdx);
            self.symbolExtractor.extractFromSymbol(name, expSymIdx, moduleID, moduleFileName, fileIdx, exports);
        }
    }
};

pub const CheckerLease = struct {
    used: bool,
    checker_instance: *checker.Checker,

    pub fn getChecker(self: *CheckerLease) *checker.Checker {
        self.used = true;
        return self.checker_instance;
    }

    pub fn tryChecker(self: *CheckerLease) ?*checker.Checker {
        if (self.used) {
            return self.checker_instance;
        }
        return null;
    }
};

// Utilities

pub fn shouldIgnoreSymbol(astCtx: *ast.Ast, symIdx: ast_gen.SymbolIndex) bool {
    const flags = util.getSymbolFlags(astCtx, symIdx);
    if ((flags & 0x4000000) != 0) { // ast.SymbolFlagsPrototype
        return true;
    }
    return false;
}

pub fn getSyntax(astCtx: *ast.Ast, symIdx: ast_gen.SymbolIndex) export_mod.ExportSyntax {
    _ = astCtx;
    _ = symIdx;
    return .Named; // Default placeholder, implementation would check declarations
}

pub fn isUnusableName(name: []const u8) bool {
    if (name.len == 0) return true;
    if (std.mem.eql(u8, name, "_default")) return true;
    if (std.mem.eql(u8, name, "__export")) return true;
    if (std.mem.eql(u8, name, "default")) return true;
    if (std.mem.eql(u8, name, "export=")) return true;
    return false;
}

pub fn fileNameForDefaultExportName(astCtx: *ast.Ast, targetSymbol: ast_gen.SymbolIndex, moduleFileName: []const u8, moduleID: export_mod.ModuleID) []const u8 {
    _ = astCtx;
    _ = targetSymbol;
    if (moduleFileName.len > 0) {
        return moduleFileName;
    }
    return @as([]const u8, @ptrCast(moduleID));
}
