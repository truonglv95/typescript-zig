const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const commandlineoption = @import("commandlineoption.zig");
const CommandLineOption = commandlineoption.CommandLineOption;
const AlternateModeDiagnostics = commandlineoption.AlternateModeDiagnostics;

pub const NameMap = struct {
    alternateMode: ?*AlternateModeDiagnostics = null,
    OptionDeclarations: []const CommandLineOption = &[_]CommandLineOption{},
    UnknownOptionDiagnostic: ?*const diagnostics.Message = null,
    UnknownDidYouMeanDiagnostic: ?*const diagnostics.Message = null,

    pub fn GetOptionDeclarationFromName(self: *const NameMap, name: []const u8, allowShort: bool) ?*const CommandLineOption {
        _ = self;
        _ = name;
        _ = allowShort;
        return null;
    }

    pub fn Get(self: *const NameMap, name: []const u8) ?*const CommandLineOption {
        _ = self;
        _ = name;
        return null;
    }
};

pub const ParseCommandLineWorkerDiagnostics = struct {
    didYouMean: *NameMap,
    OptionTypeMismatchDiagnostic: *const diagnostics.Message,
};

pub const OptionValue = union(enum) {
    String: []const u8,
    Number: i32,
    Boolean: bool,
    List: []OptionValue,
    Null: void,
};

pub const ParseConfigHost = struct {
    pub fn FS(self: *const ParseConfigHost) void {
        _ = self;
    }
    pub fn GetCurrentDirectory(self: *const ParseConfigHost) []const u8 {
        _ = self;
        return ".";
    }
};

pub const ParsedCommandLine = struct {
    ParsedConfig: struct {
        WatchOptions: *core.WatchOptions,
    },
    Errors: std.ArrayList(*diagnostics.Diagnostic),
    Raw: *std.StringHashMap(OptionValue),
    extraFileExtensions: []const @import("tsconfigparsing.zig").FileExtensionInfo = &[_]@import("tsconfigparsing.zig").FileExtensionInfo{},

    pub fn FileNames(self: *@This()) [][]const u8 {
        _ = self;
        return &[_][]const u8{};
    }
};

pub const ParsedBuildCommandLine = struct {
    BuildOptions: *core.BuildOptions,
    CompilerOptions: *core.CompilerOptions,
    WatchOptions: *core.WatchOptions,
    Projects: std.ArrayList([]const u8),
    Errors: std.ArrayList(*diagnostics.Diagnostic),
    Raw: *std.StringHashMap(OptionValue),
};

pub const CommandLineParser = struct {
    allocator: std.mem.Allocator,
    workerDiagnostics: *ParseCommandLineWorkerDiagnostics,
    optionsMap: *const NameMap,
    // fs: vfs.FS,
    currentDirectory: []const u8,
    options: *std.StringHashMap(OptionValue),
    fileNames: std.ArrayList([]const u8),
    errors: std.ArrayList(*diagnostics.Diagnostic),

    pub fn AlternateMode(self: *CommandLineParser) ?*AlternateModeDiagnostics {
        return self.workerDiagnostics.didYouMean.alternateMode;
    }

    pub fn OptionsDeclarations(self: *CommandLineParser) []const CommandLineOption {
        return self.workerDiagnostics.didYouMean.OptionDeclarations;
    }

    pub fn UnknownOptionDiagnostic(self: *CommandLineParser) ?*const diagnostics.Message {
        return self.workerDiagnostics.didYouMean.UnknownOptionDiagnostic;
    }

    pub fn UnknownDidYouMeanDiagnostic(self: *CommandLineParser) ?*const diagnostics.Message {
        return self.workerDiagnostics.didYouMean.UnknownDidYouMeanDiagnostic;
    }

    pub fn parseStrings(self: *CommandLineParser, args: []const []const u8) !void {
        var i: usize = 0;
        while (i < args.len) {
            const s = args[i];
            i += 1;
            if (s.len == 0) {
                continue;
            }
            switch (s[0]) {
                '@' => {
                    try self.parseResponseFile(s[1..]);
                },
                '-' => {
                    const inputOptionName = getInputOptionName(s);
                    const opt = self.optionsMap.GetOptionDeclarationFromName(inputOptionName, true);
                    if (opt) |o| {
                        i = try self.parseOptionValue(args, i, o, self.workerDiagnostics.OptionTypeMismatchDiagnostic);
                    } else {
                        // var watchOpt = WatchNameMap.GetOptionDeclarationFromName(inputOptionName, true);
                        // if (watchOpt) |wo| {
                        //     i = try self.parseOptionValue(args, i, wo, watchOptionsDidYouMeanDiagnostics.OptionTypeMismatchDiagnostic);
                        // } else {
                        //     self.errors.append(self.createUnknownOptionError(inputOptionName, s, null, null));
                        // }
                    }
                },
                else => {
                    try self.fileNames.append(s);
                },
            }
        }
    }

    pub fn parseResponseFile(self: *CommandLineParser, fileName: []const u8) !void {
        // In full Zig we'd read file contents. For now, assuming empty to match structure.
        _ = fileName;
        const args = std.ArrayList([]const u8).init(self.allocator);
        // text parsing logic...
        try self.parseStrings(args.items);
    }

    pub fn parseListTypeOption(self: *CommandLineParser, opt: *const CommandLineOption, value: []const u8) ![]OptionValue {
        return try ParseListTypeOption(self.allocator, opt, value);
    }

    pub fn parseOptionValue(
        self: *CommandLineParser,
        args: []const []const u8,
        i_ref: usize,
        opt: *const CommandLineOption,
        diag: *const diagnostics.Message,
    ) !usize {
        var i = i_ref;
        if (opt.isTSConfigOnly and i <= args.len) {
            var optValue: []const u8 = "";
            if (i < args.len) {
                optValue = args[i];
            }
            if (std.mem.eql(u8, optValue, "null")) {
                try self.options.put(opt.name, .Null);
                i += 1;
            } else if (opt.kind == .Boolean) {
                if (std.mem.eql(u8, optValue, "false")) {
                    try self.options.put(opt.name, .{ .Boolean = false });
                    i += 1;
                } else {
                    if (std.mem.eql(u8, optValue, "true")) {
                        i += 1;
                    }
                    try self.errors.append(&diagnostics.generated.Option_0_can_only_be_specified_in_tsconfig_json_file_or_set_to_false_or_null_on_command_line);
                }
            } else {
                try self.errors.append(&diagnostics.generated.Option_0_can_only_be_specified_in_tsconfig_json_file_or_set_to_null_on_command_line);
                if (optValue.len != 0 and !std.mem.startsWith(u8, optValue, "-")) {
                    i += 1;
                }
            }
        } else {
            if (i >= args.len) {
                if (opt.kind != .Boolean) {
                    try self.errors.append(diag);
                    if (opt.kind == .List) {
                        try self.options.put(opt.name, .{ .List = &[_]OptionValue{} });
                    } else if (opt.kind == .Enum) {
                        try self.errors.append(&diagnostics.generated.Argument_for_0_option_must_be_Colon_1);
                    }
                } else {
                    try self.options.put(opt.name, .{ .Boolean = true });
                }
                return i;
            }
            if (!std.mem.eql(u8, args[i], "null")) {
                switch (opt.kind) {
                    .Number => {
                        const num = std.fmt.parseInt(i32, args[i], 10) catch null;
                        if (num) |n| {
                            // opt.minValue check omitted temporarily as we don't have it in CommandLineOption struct
                            try self.options.put(opt.name, .{ .Number = n });
                        } else {
                            try self.errors.append(diag);
                        }
                        i += 1;
                    },
                    .Boolean => {
                        const optValue = args[i];
                        const normalized = std.mem.trimEnd(u8, optValue, ";");
                        if (std.mem.eql(u8, normalized, "false")) {
                            try self.options.put(opt.name, .{ .Boolean = false });
                        } else {
                            try self.options.put(opt.name, .{ .Boolean = true });
                        }
                        if (std.mem.eql(u8, normalized, "false") or std.mem.eql(u8, normalized, "true")) {
                            i += 1;
                        }
                    },
                    .String => {
                        // val, err := validateJsonOptionValue(...)
                        try self.options.put(opt.name, .{ .String = args[i] });
                        i += 1;
                    },
                    .List => {
                        const result = try ParseListTypeOption(self.allocator, opt, args[i]);
                        try self.options.put(opt.name, .{ .List = result });
                        if (result.len > 0) {
                            i += 1;
                        }
                    },
                    .ListOrElement => {
                        @panic("listOrElement not supported here");
                    },
                    else => {
                        const val = try convertJsonOptionOfEnumType(opt, std.mem.trim(u8, args[i], " \t\r\n"));
                        try self.options.put(opt.name, val);
                        i += 1;
                    },
                }
            } else {
                try self.options.put(opt.name, .Null);
                i += 1;
            }
        }
        return i;
    }
};

pub fn getInputOptionName(input: []const u8) []const u8 {
    var result = input;
    if (std.mem.startsWith(u8, result, "-")) {
        result = result[1..];
    }
    if (std.mem.startsWith(u8, result, "-")) {
        result = result[1..];
    }
    return result;
}

pub fn tryReadFile(
    fileName: []const u8,
    // readFile: fn(string) (string, bool)
    errors: *std.ArrayList(*diagnostics.Diagnostic),
) ![]const u8 {
    _ = fileName;
    // this function adds a compiler diagnostic if the file cannot be read
    // text, e := readFile(fileName)
    // text = ""
    try errors.append(&diagnostics.generated.Cannot_read_file_0);
    return "";
}

pub fn parseCommandLineWorker(
    allocator: std.mem.Allocator,
    parseCommandLineWithDiagnostics: *ParseCommandLineWorkerDiagnostics,
    commandLine: []const []const u8,
    // fs: vfs.FS,
    currentDirectory: []const u8,
) !*CommandLineParser {
    var parser = try allocator.create(CommandLineParser);
    parser.* = .{
        .allocator = allocator,
        .workerDiagnostics = parseCommandLineWithDiagnostics,
        .optionsMap = parseCommandLineWithDiagnostics.didYouMean,
        .currentDirectory = currentDirectory,
        .options = try allocator.create(std.StringHashMap(OptionValue)),
        .fileNames = std.ArrayList([]const u8).init(allocator),
        .errors = std.ArrayList(*diagnostics.Diagnostic).init(allocator),
    };
    parser.options.* = std.StringHashMap(OptionValue).init(allocator);

    try parser.parseStrings(commandLine);
    return parser;
}

pub fn ParseCommandLine(
    allocator: std.mem.Allocator,
    commandLine: []const []const u8,
    host: *const ParseConfigHost,
) !*ParsedCommandLine {
    // parser := parseCommandLineWorker(CompilerOptionsDidYouMeanDiagnostics, commandLine, host.FS(), host.GetCurrentDirectory())
    // For now stub
    _ = commandLine;
    _ = host;

    const result = try allocator.create(ParsedCommandLine);
    result.* = .{
        .ParsedConfig = .{ .WatchOptions = undefined },
        .Errors = std.ArrayList(*diagnostics.Diagnostic).init(allocator),
        .Raw = try allocator.create(std.StringHashMap(OptionValue)),
    };
    result.Raw.* = std.StringHashMap(OptionValue).init(allocator);
    return result;
}

pub fn ParseBuildCommandLine(
    allocator: std.mem.Allocator,
    commandLine: []const []const u8,
    host: *const ParseConfigHost,
) !*ParsedBuildCommandLine {
    _ = commandLine;
    _ = host;

    const result = try allocator.create(ParsedBuildCommandLine);
    result.* = .{
        .BuildOptions = undefined,
        .CompilerOptions = undefined,
        .WatchOptions = undefined,
        .Projects = std.ArrayList([]const u8).init(allocator),
        .Errors = std.ArrayList(*diagnostics.Diagnostic).init(allocator),
        .Raw = try allocator.create(std.StringHashMap(OptionValue)),
    };
    result.Raw.* = std.StringHashMap(OptionValue).init(allocator);
    return result;
}

pub fn ParseListTypeOption(
    allocator: std.mem.Allocator,
    opt: *const CommandLineOption,
    value: []const u8,
) ![]OptionValue {
    const val = std.mem.trim(u8, value, " \t\r\n");
    if (std.mem.startsWith(u8, val, "-")) {
        return &[_]OptionValue{};
    }
    if (opt.kind == .ListOrElement and !std.mem.containsAtLeast(u8, val, 1, ",")) {
        var arr = try allocator.alloc(OptionValue, 1);
        arr[0] = .{ .String = val };
        return arr;
    }
    if (val.len == 0) {
        return &[_]OptionValue{};
    }

    var list = std.ArrayList(OptionValue).init(allocator);
    var iter = std.mem.splitScalar(u8, val, ',');
    const elementsOpt = opt.Elements();

    while (iter.next()) |v| {
        if (elementsOpt) |el| {
            if (el.kind == .String) {
                try list.append(.{ .String = v });
            } else if (el.kind == .Boolean or el.kind == .Object or el.kind == .Number) {
                @panic("List of primitive not yet supported.");
            } else {
                const enumVal = try convertJsonOptionOfEnumType(el, std.mem.trim(u8, v, " \t\r\n"));
                try list.append(enumVal);
            }
        }
    }

    return try list.toOwnedSlice();
}

pub fn convertJsonOptionOfEnumType(
    opt: *const CommandLineOption,
    value: []const u8,
) !OptionValue {
    if (value.len == 0) return .Null;

    const typeMap = opt.EnumMap();
    if (typeMap == null) return .Null;

    // For now we don't have lower casing, we'll assume it matches
    const val = typeMap.?.get(value);
    if (val) |v| {
        return .{ .String = v };
    }
    return .Null;
}
