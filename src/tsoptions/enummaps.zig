const std = @import("std");

//! Enum maps for tsoptions.
//!
//! Port of `internal/tsoptions/enummaps.go` (255 LOC).
//!
//! Provides lookup maps for:
//! - `lib` option values -> lib .d.ts file names (LibMap / GetLibFileName)
//! - `moduleResolution` string -> enum (moduleResolutionOptionMap)
//! - `target` string -> enum (targetOptionMap)
//! - `module` string -> enum (moduleOptionMap)
//! - `moduleDetection` string -> enum (moduleDetectionOptionMap)
//! - `jsx` string -> enum (jsxOptionMap)
//! - `newLine` string -> enum (newLineOptionMap)
//! - `target` -> default lib file name (targetToLibMap / GetDefaultLibFileName)
//! - Watch file/directory/fallback polling enum maps

/// Entry in a lib name -> lib file name map.
pub const LibEntry = struct { key: []const u8, value: []const u8 };

/// Maps `lib` option values (e.g. "es2022", "dom") to their .d.ts file names.
/// Port of Go's `LibMap`.
pub const lib_map = [_]LibEntry{
    // JavaScript only
    .{ .key = "es5", .value = "lib.es5.d.ts" },
    .{ .key = "es6", .value = "lib.es2015.d.ts" },
    .{ .key = "es2015", .value = "lib.es2015.d.ts" },
    .{ .key = "es7", .value = "lib.es2016.d.ts" },
    .{ .key = "es2016", .value = "lib.es2016.d.ts" },
    .{ .key = "es2017", .value = "lib.es2017.d.ts" },
    .{ .key = "es2018", .value = "lib.es2018.d.ts" },
    .{ .key = "es2019", .value = "lib.es2019.d.ts" },
    .{ .key = "es2020", .value = "lib.es2020.d.ts" },
    .{ .key = "es2021", .value = "lib.es2021.d.ts" },
    .{ .key = "es2022", .value = "lib.es2022.d.ts" },
    .{ .key = "es2023", .value = "lib.es2023.d.ts" },
    .{ .key = "es2024", .value = "lib.es2024.d.ts" },
    .{ .key = "es2025", .value = "lib.es2025.d.ts" },
    .{ .key = "esnext", .value = "lib.esnext.d.ts" },
    // Host only
    .{ .key = "dom", .value = "lib.dom.d.ts" },
    .{ .key = "dom.iterable", .value = "lib.dom.iterable.d.ts" },
    .{ .key = "dom.asynciterable", .value = "lib.dom.asynciterable.d.ts" },
    .{ .key = "webworker", .value = "lib.webworker.d.ts" },
    .{ .key = "webworker.importscripts", .value = "lib.webworker.importscripts.d.ts" },
    .{ .key = "webworker.iterable", .value = "lib.webworker.iterable.d.ts" },
    .{ .key = "webworker.asynciterable", .value = "lib.webworker.asynciterable.d.ts" },
    .{ .key = "scripthost", .value = "lib.scripthost.d.ts" },
    // ES2015+ By-feature
    .{ .key = "es2015.core", .value = "lib.es2015.core.d.ts" },
    .{ .key = "es2015.collection", .value = "lib.es2015.collection.d.ts" },
    .{ .key = "es2015.generator", .value = "lib.es2015.generator.d.ts" },
    .{ .key = "es2015.iterable", .value = "lib.es2015.iterable.d.ts" },
    .{ .key = "es2015.promise", .value = "lib.es2015.promise.d.ts" },
    .{ .key = "es2015.proxy", .value = "lib.es2015.proxy.d.ts" },
    .{ .key = "es2015.reflect", .value = "lib.es2015.reflect.d.ts" },
    .{ .key = "es2015.symbol", .value = "lib.es2015.symbol.d.ts" },
    .{ .key = "es2015.symbol.wellknown", .value = "lib.es2015.symbol.wellknown.d.ts" },
    .{ .key = "es2016.array.include", .value = "lib.es2016.array.include.d.ts" },
    .{ .key = "es2016.intl", .value = "lib.es2016.intl.d.ts" },
    .{ .key = "es2017.arraybuffer", .value = "lib.es2017.arraybuffer.d.ts" },
    .{ .key = "es2017.date", .value = "lib.es2017.date.d.ts" },
    .{ .key = "es2017.object", .value = "lib.es2017.object.d.ts" },
    .{ .key = "es2017.sharedmemory", .value = "lib.es2017.sharedmemory.d.ts" },
    .{ .key = "es2017.string", .value = "lib.es2017.string.d.ts" },
    .{ .key = "es2017.intl", .value = "lib.es2017.intl.d.ts" },
    .{ .key = "es2017.typedarrays", .value = "lib.es2017.typedarrays.d.ts" },
    .{ .key = "es2018.asyncgenerator", .value = "lib.es2018.asyncgenerator.d.ts" },
    .{ .key = "es2018.asynciterable", .value = "lib.es2018.asynciterable.d.ts" },
    .{ .key = "es2018.intl", .value = "lib.es2018.intl.d.ts" },
    .{ .key = "es2018.promise", .value = "lib.es2018.promise.d.ts" },
    .{ .key = "es2018.regexp", .value = "lib.es2018.regexp.d.ts" },
    .{ .key = "es2019.array", .value = "lib.es2019.array.d.ts" },
    .{ .key = "es2019.object", .value = "lib.es2019.object.d.ts" },
    .{ .key = "es2019.string", .value = "lib.es2019.string.d.ts" },
    .{ .key = "es2019.symbol", .value = "lib.es2019.symbol.d.ts" },
    .{ .key = "es2019.intl", .value = "lib.es2019.intl.d.ts" },
    .{ .key = "es2020.bigint", .value = "lib.es2020.bigint.d.ts" },
    .{ .key = "es2020.date", .value = "lib.es2020.date.d.ts" },
    .{ .key = "es2020.promise", .value = "lib.es2020.promise.d.ts" },
    .{ .key = "es2020.sharedmemory", .value = "lib.es2020.sharedmemory.d.ts" },
    .{ .key = "es2020.string", .value = "lib.es2020.string.d.ts" },
    .{ .key = "es2020.symbol.wellknown", .value = "lib.es2020.symbol.wellknown.d.ts" },
    .{ .key = "es2020.intl", .value = "lib.es2020.intl.d.ts" },
    .{ .key = "es2020.number", .value = "lib.es2020.number.d.ts" },
    .{ .key = "es2021.promise", .value = "lib.es2021.promise.d.ts" },
    .{ .key = "es2021.string", .value = "lib.es2021.string.d.ts" },
    .{ .key = "es2021.weakref", .value = "lib.es2021.weakref.d.ts" },
    .{ .key = "es2021.intl", .value = "lib.es2021.intl.d.ts" },
    .{ .key = "es2022.array", .value = "lib.es2022.array.d.ts" },
    .{ .key = "es2022.error", .value = "lib.es2022.error.d.ts" },
    .{ .key = "es2022.intl", .value = "lib.es2022.intl.d.ts" },
    .{ .key = "es2022.object", .value = "lib.es2022.object.d.ts" },
    .{ .key = "es2022.string", .value = "lib.es2022.string.d.ts" },
    .{ .key = "es2022.regexp", .value = "lib.es2022.regexp.d.ts" },
    .{ .key = "es2023.array", .value = "lib.es2023.array.d.ts" },
    .{ .key = "es2023.collection", .value = "lib.es2023.collection.d.ts" },
    .{ .key = "es2023.intl", .value = "lib.es2023.intl.d.ts" },
    .{ .key = "es2024.arraybuffer", .value = "lib.es2024.arraybuffer.d.ts" },
    .{ .key = "es2024.collection", .value = "lib.es2024.collection.d.ts" },
    .{ .key = "es2024.object", .value = "lib.es2024.object.d.ts" },
    .{ .key = "es2024.promise", .value = "lib.es2024.promise.d.ts" },
    .{ .key = "es2024.regexp", .value = "lib.es2024.regexp.d.ts" },
    .{ .key = "es2024.sharedmemory", .value = "lib.es2024.sharedmemory.d.ts" },
    .{ .key = "es2024.string", .value = "lib.es2024.string.d.ts" },
    .{ .key = "es2025.collection", .value = "lib.es2025.collection.d.ts" },
    .{ .key = "es2025.float16", .value = "lib.es2025.float16.d.ts" },
    .{ .key = "es2025.intl", .value = "lib.es2025.intl.d.ts" },
    .{ .key = "es2025.iterator", .value = "lib.es2025.iterator.d.ts" },
    .{ .key = "es2025.promise", .value = "lib.es2025.promise.d.ts" },
    .{ .key = "es2025.regexp", .value = "lib.es2025.regexp.d.ts" },
    // Backward-compat fallbacks
    .{ .key = "esnext.asynciterable", .value = "lib.es2018.asynciterable.d.ts" },
    .{ .key = "esnext.symbol", .value = "lib.es2019.symbol.d.ts" },
    .{ .key = "esnext.bigint", .value = "lib.es2020.bigint.d.ts" },
    .{ .key = "esnext.weakref", .value = "lib.es2021.weakref.d.ts" },
    .{ .key = "esnext.object", .value = "lib.es2024.object.d.ts" },
    .{ .key = "esnext.regexp", .value = "lib.es2024.regexp.d.ts" },
    .{ .key = "esnext.string", .value = "lib.es2024.string.d.ts" },
    .{ .key = "esnext.float16", .value = "lib.es2025.float16.d.ts" },
    .{ .key = "esnext.iterator", .value = "lib.es2025.iterator.d.ts" },
    .{ .key = "esnext.promise", .value = "lib.es2025.promise.d.ts" },
    // ESNext By-feature
    .{ .key = "esnext.array", .value = "lib.esnext.array.d.ts" },
    .{ .key = "esnext.collection", .value = "lib.esnext.collection.d.ts" },
    .{ .key = "esnext.date", .value = "lib.esnext.date.d.ts" },
    .{ .key = "esnext.decorators", .value = "lib.esnext.decorators.d.ts" },
    .{ .key = "esnext.disposable", .value = "lib.esnext.disposable.d.ts" },
    .{ .key = "esnext.error", .value = "lib.esnext.error.d.ts" },
    .{ .key = "esnext.intl", .value = "lib.esnext.intl.d.ts" },
    .{ .key = "esnext.sharedmemory", .value = "lib.esnext.sharedmemory.d.ts" },
    .{ .key = "esnext.temporal", .value = "lib.esnext.temporal.d.ts" },
    .{ .key = "esnext.typedarrays", .value = "lib.esnext.typedarrays.d.ts" },
    // Decorators
    .{ .key = "decorators", .value = "lib.decorators.d.ts" },
    .{ .key = "decorators.legacy", .value = "lib.decorators.legacy.d.ts" },
};

/// Looks up a lib file name by lib name (case-insensitive). Returns null
/// if not found. Port of Go's `GetLibFileName`.
pub fn getLibFileName(lib_name: []const u8) ?[]const u8 {
    // Lowercase the input for case-insensitive comparison.
    for (lib_map) |entry| {
        if (std.ascii.eqlIgnoreCase(lib_name, entry.key)) return entry.value;
    }
    // Also check if the name is already a .d.ts filename.
    if (std.mem.endsWith(u8, lib_name, ".d.ts")) {
        return lib_name;
    }
    return null;
}

/// Maps `target` string values to their default lib .d.ts filename.
/// Port of Go's `targetToLibMap`.
pub fn getDefaultLibFileName(target: []const u8) []const u8 {
    const TargetEntry = struct { key: []const u8, value: []const u8 };
    const target_map = [_]TargetEntry{
        .{ .key = "esnext", .value = "lib.esnext.full.d.ts" },
        .{ .key = "es2025", .value = "lib.es2025.full.d.ts" },
        .{ .key = "es2024", .value = "lib.es2024.full.d.ts" },
        .{ .key = "es2023", .value = "lib.es2023.full.d.ts" },
        .{ .key = "es2022", .value = "lib.es2022.full.d.ts" },
        .{ .key = "es2021", .value = "lib.es2021.full.d.ts" },
        .{ .key = "es2020", .value = "lib.es2020.full.d.ts" },
        .{ .key = "es2019", .value = "lib.es2019.full.d.ts" },
        .{ .key = "es2018", .value = "lib.es2018.full.d.ts" },
        .{ .key = "es2017", .value = "lib.es2017.full.d.ts" },
        .{ .key = "es2016", .value = "lib.es2016.full.d.ts" },
        .{ .key = "es2015", .value = "lib.es6.d.ts" },
        .{ .key = "es6", .value = "lib.es6.d.ts" },
        .{ .key = "es5", .value = "lib.d.ts" },
    };
    for (target_map) |entry| {
        if (std.ascii.eqlIgnoreCase(target, entry.key)) return entry.value;
    }
    return "lib.d.ts";
}

/// Maps `moduleResolution` string to its normalized name.
pub fn getModuleResolutionKind(name: []const u8) ?[]const u8 {
    const entries = [_]struct { key: []const u8, value: []const u8 }{
        .{ .key = "node16", .value = "node16" },
        .{ .key = "nodenext", .value = "nodenext" },
        .{ .key = "bundler", .value = "bundler" },
        .{ .key = "classic", .value = "classic" },
        .{ .key = "node", .value = "node10" },
        .{ .key = "node10", .value = "node10" },
    };
    for (entries) |e| {
        if (std.ascii.eqlIgnoreCase(name, e.key)) return e.value;
    }
    return null;
}

/// Maps `module` string to its normalized name.
pub fn getModuleKind(name: []const u8) ?[]const u8 {
    const entries = [_]struct { key: []const u8, value: []const u8 }{
        .{ .key = "commonjs", .value = "commonjs" },
        .{ .key = "amd", .value = "amd" },
        .{ .key = "system", .value = "system" },
        .{ .key = "umd", .value = "umd" },
        .{ .key = "es6", .value = "es2015" },
        .{ .key = "es2015", .value = "es2015" },
        .{ .key = "es2020", .value = "es2020" },
        .{ .key = "es2022", .value = "es2022" },
        .{ .key = "esnext", .value = "esnext" },
        .{ .key = "node16", .value = "node16" },
        .{ .key = "node18", .value = "node18" },
        .{ .key = "node20", .value = "node20" },
        .{ .key = "nodenext", .value = "nodenext" },
        .{ .key = "preserve", .value = "preserve" },
    };
    for (entries) |e| {
        if (std.ascii.eqlIgnoreCase(name, e.key)) return e.value;
    }
    return null;
}

/// Maps `jsx` string to its normalized name.
pub fn getJsxEmit(name: []const u8) ?[]const u8 {
    const entries = [_]struct { key: []const u8, value: []const u8 }{
        .{ .key = "preserve", .value = "preserve" },
        .{ .key = "react-native", .value = "react-native" },
        .{ .key = "react-jsx", .value = "react-jsx" },
        .{ .key = "react-jsxdev", .value = "react-jsxdev" },
        .{ .key = "react", .value = "react" },
    };
    for (entries) |e| {
        if (std.ascii.eqlIgnoreCase(name, e.key)) return e.value;
    }
    return null;
}

/// Maps `newLine` string to its normalized name.
pub fn getNewLineKind(name: []const u8) ?[]const u8 {
    if (std.ascii.eqlIgnoreCase(name, "crlf")) return "crlf";
    if (std.ascii.eqlIgnoreCase(name, "lf")) return "lf";
    return null;
}
