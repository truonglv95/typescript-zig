const std = @import("std");
const core = @import("../core/core.zig");
const decls = @import("../tsoptions/commandlineoption.zig");

pub const ParsedCommandLine = struct {
    options: core.CompilerOptions,
    fileNames: std.ArrayList([]const u8),
    errors: std.ArrayList([]const u8),

    pub fn deinit(self: *ParsedCommandLine, allocator: std.mem.Allocator) void {
        for (self.fileNames.items) |name| {
            allocator.free(name);
        }
        self.fileNames.deinit(allocator);

        for (self.errors.items) |err| {
            allocator.free(err);
        }
        self.errors.deinit(allocator);

        inline for (std.meta.fields(core.CompilerOptions)) |field| {
            if (field.type == ?[]const u8) {
                if (@field(self.options, field.name)) |s| {
                    allocator.free(s);
                }
            } else if (field.type == ?[]const []const u8) {
                if (@field(self.options, field.name)) |arr| {
                    for (arr) |s| allocator.free(s);
                    allocator.free(arr);
                }
            }
        }
    }
};

pub fn parseCommandLine(allocator: std.mem.Allocator, args: [][]const u8) !ParsedCommandLine {
    var result = ParsedCommandLine{
        .options = core.CompilerOptions{},
        .fileNames = std.ArrayList([]const u8).empty,
        .errors = std.ArrayList([]const u8).empty,
    };

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (!std.mem.startsWith(u8, arg, "-")) {
            try result.fileNames.append(allocator, try allocator.dupe(u8, arg));
            continue;
        }

        var optName = arg;
        if (std.mem.startsWith(u8, optName, "--")) {
            optName = optName[2..];
        } else if (std.mem.startsWith(u8, optName, "-")) {
            optName = optName[1..];
        }

        var found = false;
        if (std.ascii.startsWithIgnoreCase(optName, "no") and optName.len > 2) {
            const positive_name = optName[2..];
            inline for (decls.optionsDeclarations) |decl| {
                if (decl.kind == .Boolean and std.ascii.eqlIgnoreCase(positive_name, decl.name)) {
                    if (@hasField(core.CompilerOptions, decl.name)) @field(result.options, decl.name) = false;
                    found = true;
                }
            }
            if (found) continue;
        }
        inline for (decls.optionsDeclarations) |decl| {
            if (std.ascii.eqlIgnoreCase(optName, decl.name) or std.ascii.eqlIgnoreCase(optName, decl.shortName)) {
                found = true;
                switch (decl.kind) {
                    .Boolean => {
                        if (@hasField(core.CompilerOptions, decl.name)) {
                            @field(result.options, decl.name) = true;
                        }
                    },
                    .String => {
                        if (i + 1 < args.len) {
                            i += 1;
                            if (@hasField(core.CompilerOptions, decl.name)) {
                                @field(result.options, decl.name) = try allocator.dupe(u8, args[i]);
                            }
                        } else {
                            try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "Option '{s}' expects an argument", .{optName}));
                        }
                    },
                    .Enum => {
                        if (i + 1 >= args.len) {
                            try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "Option '{s}' expects an argument", .{optName}));
                        } else {
                            i += 1;
                            const value = args[i];
                            if (!setEnumOption(&result.options, decl.name, value)) {
                                try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "Unknown value '{s}' for option '{s}'", .{ value, optName }));
                            }
                        }
                    },
                    .List, .ListOrElement => {
                        if (i + 1 >= args.len) {
                            try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "Option '{s}' expects an argument", .{optName}));
                        } else {
                            i += 1;
                            if (@hasField(core.CompilerOptions, decl.name)) {
                                const FieldType = @TypeOf(@field(result.options, decl.name));
                                if (FieldType == ?[]const []const u8) {
                                    var values = std.ArrayList([]const u8).empty;
                                    var parts = std.mem.splitScalar(u8, args[i], ',');
                                    while (parts.next()) |part| if (part.len != 0) try values.append(allocator, try allocator.dupe(u8, part));
                                    @field(result.options, decl.name) = try values.toOwnedSlice(allocator);
                                }
                            }
                        }
                    },
                    else => {
                        // Skip unhandled for now
                        if (i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-")) {
                            i += 1;
                        }
                    },
                }
            }
        }

        if (!found) {
            try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "Unknown compiler option '{s}'", .{arg}));
        }
    }

    return result;
}

fn setEnumOption(options: *core.CompilerOptions, name: []const u8, value: []const u8) bool {
    if (std.mem.eql(u8, name, "target")) {
        options.target = parseTarget(value) orelse return false;
    } else if (std.mem.eql(u8, name, "module")) {
        options.module = parseModule(value) orelse return false;
    } else if (std.mem.eql(u8, name, "jsx")) {
        options.jsx = parseJsx(value) orelse return false;
    } else if (std.mem.eql(u8, name, "moduleResolution")) {
        options.moduleResolution = parseModuleResolution(value) orelse return false;
    } else if (std.mem.eql(u8, name, "moduleDetection")) {
        options.moduleDetection = parseModuleDetection(value) orelse return false;
    } else if (std.mem.eql(u8, name, "newLine")) {
        options.newLine = parseNewLine(value) orelse return false;
    }
    return true;
}

fn parseModuleResolution(value: []const u8) ?core.ModuleResolutionKind {
    if (std.ascii.eqlIgnoreCase(value, "classic")) return .Classic;
    if (std.ascii.eqlIgnoreCase(value, "node") or std.ascii.eqlIgnoreCase(value, "node10") or std.ascii.eqlIgnoreCase(value, "nodejs")) return .NodeJs;
    if (std.ascii.eqlIgnoreCase(value, "node16")) return .Node16;
    if (std.ascii.eqlIgnoreCase(value, "nodenext")) return .NodeNext;
    if (std.ascii.eqlIgnoreCase(value, "bundler")) return .Bundler;
    return null;
}

fn parseModuleDetection(value: []const u8) ?core.ModuleDetectionKind {
    if (std.ascii.eqlIgnoreCase(value, "legacy")) return .Legacy;
    if (std.ascii.eqlIgnoreCase(value, "auto")) return .Auto;
    if (std.ascii.eqlIgnoreCase(value, "force")) return .Force;
    return null;
}

fn parseNewLine(value: []const u8) ?core.NewLineKind {
    if (std.ascii.eqlIgnoreCase(value, "crlf")) return .CarriageReturnLineFeed;
    if (std.ascii.eqlIgnoreCase(value, "lf")) return .LineFeed;
    return null;
}

fn parseTarget(value: []const u8) ?core.ScriptTarget {
    if (std.ascii.eqlIgnoreCase(value, "es5")) return .ES5;
    if (std.ascii.eqlIgnoreCase(value, "es6") or std.ascii.eqlIgnoreCase(value, "es2015")) return .ES2015;
    inline for (2016..2026) |year| {
        const name = std.fmt.comptimePrint("es{d}", .{year});
        if (std.ascii.eqlIgnoreCase(value, name)) return @enumFromInt(year - 2013);
    }
    if (std.ascii.eqlIgnoreCase(value, "esnext") or std.ascii.eqlIgnoreCase(value, "latest")) return .ESNext;
    return null;
}

fn parseModule(value: []const u8) ?core.ModuleKind {
    if (std.ascii.eqlIgnoreCase(value, "none")) return .None;
    if (std.ascii.eqlIgnoreCase(value, "commonjs")) return .CommonJS;
    if (std.ascii.eqlIgnoreCase(value, "preserve")) return .Preserve;
    if (std.ascii.eqlIgnoreCase(value, "es6") or std.ascii.eqlIgnoreCase(value, "es2015")) return .ES2015;
    if (std.ascii.eqlIgnoreCase(value, "es2020")) return .ES2020;
    if (std.ascii.eqlIgnoreCase(value, "es2022")) return .ES2022;
    if (std.ascii.eqlIgnoreCase(value, "esnext")) return .ESNext;
    if (std.ascii.eqlIgnoreCase(value, "node16")) return .Node16;
    if (std.ascii.eqlIgnoreCase(value, "nodenext")) return .NodeNext;
    return null;
}

fn parseJsx(value: []const u8) ?core.JsxEmit {
    if (std.ascii.eqlIgnoreCase(value, "preserve")) return .Preserve;
    if (std.ascii.eqlIgnoreCase(value, "react")) return .React;
    if (std.ascii.eqlIgnoreCase(value, "react-jsx")) return .ReactJSX;
    if (std.ascii.eqlIgnoreCase(value, "react-jsxdev")) return .ReactJSXDev;
    if (std.ascii.eqlIgnoreCase(value, "react-native")) return .ReactNative;
    return null;
}
