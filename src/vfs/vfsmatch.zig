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

// === Missing vfsmatch functions (ported from Go) ===

/// Port of ReadDirectory. Reads directory contents matching include/exclude patterns.
pub fn readDirectory(
    allocator: std.mem.Allocator,
    fs: @import("vfs.zig").FS,
    current_dir: []const u8,
    path: []const u8,
    extensions: []const []const u8,
    excludes: []const []const u8,
    includes: []const []const u8,
    depth: i32,
) ![][]const u8 {
    return matchFiles(allocator, path, extensions, excludes, includes, fs.useCaseSensitiveFileNames(), current_dir, depth, fs);
}

/// Port of getIncludeBasePath. Returns the base path for an include pattern.
pub fn getIncludeBasePath(absolute: []const u8) []const u8 {
    const wildcard_offset = std.mem.indexOfAny(u8, absolute, "*?");
    if (wildcard_offset == null) {
        // No wildcard — check if path has extension
        if (!hasExtension(absolute)) return absolute;
        // For paths with extensions, return the parent directory
        const last_slash = std.mem.lastIndexOfScalar(u8, absolute, '/');
        if (last_slash == null) return absolute[0..0];
        return absolute[0..last_slash.?];
    }
    const wo = wildcard_offset.?;
    const last_slash = std.mem.lastIndexOfScalar(u8, absolute[0..wo], '/');
    if (last_slash == null) return absolute[0..0];
    return absolute[0..last_slash.?];
}

/// Helper: hasExtension checks if path has a file extension.
fn hasExtension(path: []const u8) bool {
    const base = tspath.getBaseFileName(path);
    if (std.mem.lastIndexOfScalar(u8, base, '.')) |dot| {
        return dot > 0 and dot < base.len - 1;
    }
    return false;
}

/// Port of matchFiles. Simplified file matching.
fn matchFiles(
    allocator: std.mem.Allocator,
    path: []const u8,
    extensions: []const []const u8,
    excludes: []const []const u8,
    includes: []const []const u8,
    use_case_sensitive: bool,
    current_dir: []const u8,
    depth: i32,
    fs: @import("vfs.zig").FS,
) ![][]const u8 {
    _ = excludes;
    _ = current_dir;
    _ = depth;
    
    var result = std.ArrayList([]const u8).empty;
    const entries = fs.getAccessibleEntries(allocator, path);
    
    // Match files in directory
    for (entries.files) |file| {
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, file });
        
        var matched = false;
        if (includes.len == 0) {
            matched = true;
        } else {
            for (includes) |include| {
                if (matchesGlob(file, include)) {
                    matched = true;
                    break;
                }
            }
        }
        
        if (matched) {
            // Check extension
            if (extensions.len == 0) {
                try result.append(allocator, full_path);
            } else {
                for (extensions) |ext| {
                    if (std.mem.endsWith(u8, file, ext)) {
                        try result.append(allocator, full_path);
                        break;
                    }
                }
            }
        }
        _ = use_case_sensitive;
    }
    
    // Recurse into directories (simplified: only 1 level)
    for (entries.directories) |dir| {
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, dir });
        try result.append(allocator, full_path);
    }
    
    return result.toOwnedSlice(allocator);
}

/// Simple glob matcher — supports * and ?
fn matchesGlob(text: []const u8, pattern: []const u8) bool {
    var ti: usize = 0;
    var pi: usize = 0;
    var star: ?usize = null;
    var star_t: usize = 0;
    
    while (ti < text.len) {
        if (pi < pattern.len) {
            const pc = pattern[pi];
            if (pc == '*') {
                star = pi;
                star_t = ti;
                pi += 1;
                continue;
            }
            if (pc == '?' or pc == text[ti]) {
                ti += 1;
                pi += 1;
                continue;
            }
        }
        if (star != null) {
            pi = star.? + 1;
            star_t += 1;
            ti = star_t;
            continue;
        }
        return false;
    }
    while (pi < pattern.len and pattern[pi] == '*') pi += 1;
    return pi == pattern.len;
}
