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
        inline for (decls.optionsDeclarations) |decl| {
            if (std.mem.eql(u8, optName, decl.name) or std.mem.eql(u8, optName, decl.shortName)) {
                found = true;
                switch (decl.kind) {
                    .Boolean => {
                        // TODO: Handle --no-xyz
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
                    else => {
                        // Skip unhandled for now
                        if (i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-")) {
                            i += 1;
                        }
                    }
                }
            }
        }
        
        if (!found) {
            try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "Unknown compiler option '{s}'", .{arg}));
        }
    }

    return result;
}
