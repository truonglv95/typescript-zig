const std = @import("std");
const commandlineoption = @import("commandlineoption.zig");

//! Name map for command-line options.
//!
//! Port of `internal/tsoptions/namemap.go` (58 LOC).
//!
//! Provides case-insensitive lookup of CommandLineOption by name or
//! short name. Used by the command-line parser to resolve `--foo` and
//! `-f` style options.

const CommandLineOption = commandlineoption.CommandLineOption;

/// A case-insensitive map from option names (and short names) to
/// CommandLineOption declarations.
pub const NameMap = struct {
    options_names: std.StringHashMapUnmanaged(*const CommandLineOption),
    short_option_names: std.StringHashMapUnmanaged([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, opt_decls: []const CommandLineOption) NameMap {
        var nm = NameMap{
            .options_names = .empty,
            .short_option_names = .empty,
            .allocator = allocator,
        };
        for (opt_decls) |*opt| {
            // Store lowercased name -> pointer to option.
            const lower = std.ascii.allocLowerString(allocator, opt.name) catch continue;
            nm.options_names.put(allocator, lower, opt) catch {};
            if (opt.shortName.len > 0) {
                nm.short_option_names.put(allocator, opt.shortName, opt.name) catch {};
            }
        }
        return nm;
    }

    pub fn deinit(self: *NameMap) void {
        // Free lowercased keys.
        var iter = self.options_names.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.options_names.deinit(self.allocator);
        self.short_option_names.deinit(self.allocator);
    }

    /// Looks up an option by its (case-insensitive) full name.
    pub fn get(self: *const NameMap, name: []const u8) ?*const CommandLineOption {
        // Allocate lowercased name on stack for lookup.
        var buf: [256]u8 = undefined;
        if (name.len > buf.len) return null;
        const lower = std.ascii.lowerString(&buf, name);
        return self.options_names.get(lower);
    }

    /// Looks up an option by its short name (e.g. "b" -> --build).
    pub fn getFromShort(self: *const NameMap, short_name: []const u8) ?*const CommandLineOption {
        const full_name = self.short_option_names.get(short_name) orelse return null;
        return self.get(full_name);
    }

    /// Looks up an option by name, optionally resolving short names first.
    pub fn getOptionDeclarationFromName(self: *const NameMap, option_name: []const u8, allow_short: bool) ?*const CommandLineOption {
        // Try short name first if allowed.
        if (allow_short) {
            if (self.short_option_names.get(option_name)) |full_name| {
                return self.get(full_name);
            }
        }
        return self.get(option_name);
    }
};

/// Builds a NameMap from a slice of CommandLineOption declarations.
/// The caller owns the returned NameMap and must call `deinit`.
pub fn getNameMapFromList(allocator: std.mem.Allocator, opt_decls: []const CommandLineOption) NameMap {
    return NameMap.init(allocator, opt_decls);
}
