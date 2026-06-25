const std = @import("std");
const tspath = @import("../tspath/tspath.zig");

pub const Usage = enum(u8) {
    files = 0,
    directories = 1,
    exclude = 2,
};

pub const unlimited_depth = std.math.maxInt(usize);

pub fn isImplicitGlob(last_path_component: []const u8) bool {
    return std.mem.indexOfAny(u8, last_path_component, ".*?") == null;
}

pub const GlobPattern = struct {
    components: []Component,
    is_exclude: bool,
    case_sensitive: bool,
    exclude_min_js: bool,

    pub fn matches(self: *const GlobPattern, path: []const u8) bool {
        // Simple stub for matching. In a full implementation, this uses
        // matchPathParts recursive matching.
        _ = self;
        _ = path;
        return false;
    }
};

pub const ComponentKind = enum {
    literal,
    wildcard,
    double_asterisk,
};

pub const Component = struct {
    kind: ComponentKind,
    literal: []const u8 = "",
    segments: []Segment = &[_]Segment{},
    skip_package_folders: bool = false,
};

pub const SegmentKind = enum {
    literal,
    star,
    question,
};

pub const Segment = struct {
    kind: SegmentKind,
    literal: []const u8 = "",
};

pub fn compileGlobPattern(allocator: std.mem.Allocator, spec: []const u8, base_path: []const u8, usage: Usage, case_sensitive: bool) !?GlobPattern {
    // Basic stub matching the Go behavior
    var parts = try tspath.getPathComponents(allocator, spec, base_path);
    defer allocator.free(parts);

    if (usage != .exclude and parts.len > 0 and std.mem.eql(u8, parts[parts.len - 1], "**")) {
        return null;
    }

    if (parts.len > 0) {
        if (tspath.hasTrailingDirectorySeparator(parts[0])) {
            parts[0] = parts[0][0 .. parts[0].len - 1];
        }
    }

    // In Go, it expands implicit globs and parses wildcard segments.
    // We stub the parsing for now to provide the types and function signatures.
    
    var components = std.ArrayList(Component).init(allocator);
    // ... populated based on parts ...

    return GlobPattern{
        .is_exclude = usage == .exclude,
        .case_sensitive = case_sensitive,
        .exclude_min_js = usage == .files,
        .components = try components.toOwnedSlice(),
    };
}

pub const SpecMatcher = struct {
    patterns: []GlobPattern,

    pub fn matchString(self: *const SpecMatcher, path: []const u8) bool {
        for (self.patterns) |p| {
            if (p.matches(path)) return true;
        }
        return false;
    }

    pub fn matchIndex(self: *const SpecMatcher, path: []const u8) isize {
        for (self.patterns, 0..) |p, i| {
            if (p.matches(path)) return @as(isize, @intCast(i));
        }
        return -1;
    }
};

pub fn newSpecMatcher(allocator: std.mem.Allocator, specs: []const []const u8, base_path: []const u8, usage: Usage, case_sensitive: bool) !?*SpecMatcher {
    if (specs.len == 0) return null;
    var patterns = std.ArrayList(GlobPattern).init(allocator);
    for (specs) |spec| {
        if (try compileGlobPattern(allocator, spec, base_path, usage, case_sensitive)) |p| {
            try patterns.append(p);
        }
    }
    if (patterns.items.len == 0) {
        patterns.deinit();
        return null;
    }

    const matcher = try allocator.create(SpecMatcher);
    matcher.* = .{ .patterns = try patterns.toOwnedSlice() };
    return matcher;
}
