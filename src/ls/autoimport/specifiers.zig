const std = @import("std");
const modulespecifiers = @import("../../modulespecifiers/modulespecifiers.zig");
const types = @import("../../modulespecifiers/types.zig");
const util = @import("../../modulespecifiers/util.zig");
const specifiers_mod = @import("../../modulespecifiers/specifiers.zig");

const view_mod = @import("view.zig");
const export_mod = @import("export.zig");

const View = view_mod.View;
const Export = export_mod.Export;

pub fn getModuleSpecifier(
    v: *View,
    export_data: *const Export,
    userPreferences: types.UserPreferences,
) !struct { []const u8, types.ResultKind } {
    // Ambient module
    if (util.pathIsBareSpecifier(export_data.ModuleID)) {
        const specifier = export_data.ModuleID;
        if (util.isExcludedByRegex(specifier, userPreferences.AutoImportSpecifierExcludeRegexes)) {
            return .{ "", .None };
        }
        return .{ specifier, .Ambient };
    }

    if (export_data.PackageName.len > 0) {
        if (v.registry.entrypoints.get(export_data.Path)) |entrypoints| {
            for (entrypoints) |entrypoint| {
                if (entrypoint.IncludeConditions.isSubsetOf(v.conditions) and !v.conditions.intersects(entrypoint.ExcludeConditions)) {
                    const specifier = try util.processEntrypointEnding(
                        v.allocator,
                        entrypoint,
                        userPreferences,
                        v.host,
                        v.program.options(),
                        v.tree,
                        v.importingFile,
                        v.getAllowedEndings(),
                    );

                    if (!util.isExcludedByRegex(specifier, userPreferences.AutoImportSpecifierExcludeRegexes)) {
                        return .{ specifier, .NodeModules };
                    }
                }
            }
            return .{ "", .None };
        }
    }

    var cache = v.registry.specifierCache.getPtr(v.importingFileName);
    if (export_data.PackageName.len == 0) {
        if (cache) |c| {
            if (c.load(export_data.Path)) |specifier| {
                if (specifier.len == 0) {
                    return .{ "", .None };
                }
                return .{ specifier, .Relative };
            }
        }
    }

    const specifiers_result = try specifiers_mod.getModuleSpecifiersForFileWithInfo(
        v.allocator,
        v.tree,
        v.importingFile,
        export_data.ModuleFileName,
        v.program.options(),
        v.host,
        userPreferences,
        std.mem.zeroes(types.ModuleSpecifierOptions),
        true,
    );
    const specifiers_list = specifiers_result[0];
    const kind = specifiers_result[1];

    // !!! unsure when this could return multiple specifiers combined with the
    //     new node_modules code. Possibly with local symlinks, which should be
    //     very rare.
    for (specifiers_list) |specifier| {
        if (std.mem.indexOf(u8, specifier, "/node_modules/") != null) {
            continue;
        }
        if (cache) |c| {
            try c.store(v.allocator, export_data.Path, specifier);
        }
        return .{ specifier, kind };
    }
    if (cache) |c| {
        try c.store(v.allocator, export_data.Path, "");
    }
    return .{ "", .None };
}
