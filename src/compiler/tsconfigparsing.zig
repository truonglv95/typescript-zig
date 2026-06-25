const std = @import("std");
const core = @import("../core/core.zig");

pub const ParsedTsConfig = struct {
    options: core.CompilerOptions,
    fileNames: std.ArrayList([]const u8),
    errors: std.ArrayList([]const u8),

    pub fn deinit(self: *ParsedTsConfig, allocator: std.mem.Allocator) void {
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

pub fn parseTsConfigFile(allocator: std.mem.Allocator, io: std.Io, filePath: []const u8) !ParsedTsConfig {
    var result = ParsedTsConfig{
        .options = core.CompilerOptions{},
        .fileNames = std.ArrayList([]const u8).empty,
        .errors = std.ArrayList([]const u8).empty,
    };

    const file = std.Io.Dir.cwd().openFile(io, filePath, .{}) catch |err| {
        try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "Cannot read file '{s}': {any}", .{filePath, err}));
        return result;
    };
    defer file.close(io);

    const fileContent = try file.readToEndAlloc(io, allocator, 1024 * 1024 * 10);
    defer allocator.free(fileContent);

    return parseTsConfigSlice(allocator, fileContent);
}

pub fn parseTsConfigSlice(allocator: std.mem.Allocator, fileContent: []const u8) !ParsedTsConfig {
    var result = ParsedTsConfig{
        .options = core.CompilerOptions{},
        .fileNames = std.ArrayList([]const u8).empty,
        .errors = std.ArrayList([]const u8).empty,
    };

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, fileContent, .{ .ignore_unknown_fields = true }) catch |err| {
        try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "JSON parse error: {any}", .{err}));
        return result;
    };
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) {
        try result.errors.append(allocator, try std.fmt.allocPrint(allocator, "Expected an object in tsconfig.json", .{}));
        return result;
    }

    if (root.object.get("compilerOptions")) |co| {
        if (co == .object) {
            // Very basic mapping for now
            // We can iterate the keys and use @hasField
            var it = co.object.iterator();
            while (it.next()) |entry| {
                const key = entry.key_ptr.*;
                const val = entry.value_ptr.*;
                
                inline for (std.meta.fields(core.CompilerOptions)) |field| {
                    if (std.mem.eql(u8, key, field.name)) {
                        switch (val) {
                            .bool => |b| {
                                if (field.type == ?bool) {
                                    @field(result.options, field.name) = b;
                                }
                            },
                            .string => |s| {
                                if (field.type == ?[]const u8) {
                                    // Allocate a copy of the string to avoid lifetime issues
                                    @field(result.options, field.name) = try allocator.dupe(u8, s);
                                }
                            },
                            else => {}
                        }
                    }
                }
            }
        }
    }

    if (root.object.get("files")) |files| {
        if (files == .array) {
            for (files.array.items) |f| {
                if (f == .string) {
                    try result.fileNames.append(allocator, try allocator.dupe(u8, f.string));
                }
            }
        }
    }

    // Include / Exclude could be added here (requires glob implementation or basic string matching)

    return result;
}
