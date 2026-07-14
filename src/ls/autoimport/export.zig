const std = @import("std");
const ast = @import("../../ast/ast.zig");
const ast_gen = @import("../../ast/ast_generated.zig");
const ast_utils = @import("../../ast/ast_utils.zig");
const checker = @import("../../checker/checker.zig");
const tspath = @import("../../tspath/tspath.zig");
const symbol = @import("../../ast/symbol.zig");

// Note: util and extract will be implemented in their respective files.
const util = @import("util.zig");
const extract = @import("extract.zig");

// lsutil constants
pub const ScriptElementKind = u32;
pub const ScriptElementKindModifier = u32;

/// ModuleID uniquely identifies a module across multiple declarations.
/// If the export is from an ambient module declaration, this is the module name.
/// If the export is from a module augmentation, this is the Path() of the resolved module file.
/// Otherwise this is the Path() of the exporting source file.
pub const ModuleID = []const u8;

pub const ExportID = struct {
    ModuleID: ModuleID,
    ExportName: []const u8,
};

pub const ExportSyntax = enum(u32) {
    None = 0,
    /// export const x = {}
    Modifier,
    /// export { x }
    Named,
    /// export default function f() {}
    DefaultModifier,
    /// export default f
    DefaultDeclaration,
    /// export = x
    Equals,
    /// export as namespace x
    UMD,
    /// export * from "module"
    Star,
    /// module.exports = {}
    CommonJSModuleExports,
    /// exports.x = {}
    CommonJSExportsProperty,

    pub fn string(self: ExportSyntax) []const u8 {
        return @tagName(self);
    }
};

pub const Export = struct {
    ID: ExportID,
    ModuleFileName: []const u8,
    Syntax: ExportSyntax,
    Flags: u32,
    localName: []const u8,
    /// through is the name of the module symbol's export that this export was found on,
    /// either 'export=', InternalSymbolNameExportStar, or empty string.
    through: []const u8,

    // Checker-set fields

    Target: ExportID,
    IsTypeOnly: bool,
    ScriptElementKind: ScriptElementKind,
    ScriptElementKindModifiers: ScriptElementKindModifier,

    /// The file where the export was found.
    Path: []const u8,

    PackageName: []const u8,

    pub fn name(self: *const Export) []const u8 {
        if (self.localName.len > 0) {
            return self.localName;
        }
        if (std.mem.eql(u8, self.ID.ExportName, symbol.InternalSymbolNameExportEquals)) {
            return self.Target.ExportName;
        }
        return self.ID.ExportName;
    }

    pub fn isRenameable(self: *const Export) bool {
        return std.mem.eql(u8, self.ID.ExportName, symbol.InternalSymbolNameExportEquals) or
            std.mem.eql(u8, self.ID.ExportName, symbol.InternalSymbolNameDefault);
    }

    pub fn ambientModuleName(self: *const Export) []const u8 {
        if (!tspath.isExternalModuleNameRelative(self.ID.ModuleID)) {
            return self.ID.ModuleID;
        }
        return "";
    }

    pub fn isUnresolvedAlias(self: *const Export) bool {
        return self.Flags == symbol.SymbolFlags.Alias;
    }
};

pub fn symbolToExport(sym: ast_gen.SymbolIndex, ch: *checker.Checker) ?Export {
    const tree = ch.binder.ast;
    const parentSymbolOpt = tree.symbols.items[sym].Parent;

    if (parentSymbolOpt) |parentSymbol| {
        if (checker.isExternalModuleSymbol(parentSymbol)) { // Assumes isExternalModuleSymbol is ported to checker.zig
            if (util.tryGetModuleIDAndFileNameOfModuleSymbol(parentSymbol, tree)) |res| {
                const moduleID = res.moduleID;
                const moduleFileName = res.fileName;
                const sourceFile = ast_utils.getSourceFileOfModule(tree, parentSymbol);
                return extractFirstExport(sym, ch, moduleID, moduleFileName, sourceFile);
            }
            return null;
        }
    }

    const symData = &tree.symbols.items[sym];
    if (symData.Declarations.items.len == 0) {
        return null;
    }
    const declaration = symData.Declarations.items[0];

    const file = ast_utils.getSourceFileOfNode(tree, declaration);
    const fileSymbolOpt = tree.localSymbols.get(file);
    if (fileSymbolOpt == null) {
        return null;
    }
    const fileSymbol = fileSymbolOpt.?;

    const moduleSymbol = ch.getMergedSymbol(fileSymbol);
    const fileData = tree.getNodeKind(file).SourceFile;
    const moduleID = fileData.Path;
    const moduleFileName = fileData.FileName;
    const target = ch.getMergedSymbol(ch.skipAlias(sym));

    if (tryGetModuleExport(symbol.InternalSymbolNameDefault, target, moduleSymbol, ch, moduleID, moduleFileName, file)) |exportResult| {
        return exportResult;
    }
    if (tryGetModuleExport(symbol.InternalSymbolNameExportEquals, target, moduleSymbol, ch, moduleID, moduleFileName, file)) |exportResult| {
        return exportResult;
    }
    return tryGetModuleExport(symData.Name, target, moduleSymbol, ch, moduleID, moduleFileName, file);
}

pub fn tryGetModuleExport(exportName: []const u8, target: ast_gen.SymbolIndex, moduleSymbol: ast_gen.SymbolIndex, ch: *checker.Checker, moduleID: ModuleID, moduleFileName: []const u8, file: ast_gen.NodeIndex) ?Export {
    const exportedOpt = ch.tryGetMemberInModuleExportsAndProperties(exportName, moduleSymbol);
    if (exportedOpt) |exported| {
        if (ch.getMergedSymbol(ch.skipAlias(exported)) == target) {
            return extractFirstExport(exported, ch, moduleID, moduleFileName, file);
        }
    }
    return null;
}

pub fn extractFirstExport(sym: ast_gen.SymbolIndex, ch: *checker.Checker, moduleID: ModuleID, moduleFileName: []const u8, file: ast_gen.NodeIndex) ?Export {
    var exports = std.ArrayList(Export).init(ch.allocator);
    defer exports.deinit();

    const tree = ch.binder.ast;
    const symData = &tree.symbols.items[sym];

    var extractor = extract.SymbolExtractor.init("", ch, null, null);
    extractor.extractFromSymbol(symData.Name, sym, moduleID, moduleFileName, file, &exports);

    if (exports.items.len > 0) {
        return exports.items[0];
    }
    return null;
}
