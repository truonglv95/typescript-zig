const std = @import("std");

pub const KnownDirectoryLink = struct {
    // Matches the casing returned by `realpath`. Used to compute the `realpath` of children.
    // Always has trailing directory separator
    real: []const u8,
    // toPath(real). Stored to avoid repeated recomputation.
    // Always has trailing directory separator
    real_path: []const u8,
};

pub const KnownSymlinks = struct {
    allocator: std.mem.Allocator,
    directories: std.StringHashMap(KnownDirectoryLink),
    directories_by_realpath: std.StringHashMap(std.StringHashMap(void)),
    files: std.StringHashMap([]const u8),
    files_by_realpath: std.StringHashMap(std.StringHashMap(void)),
    cwd: []const u8,
    use_case_sensitive_file_names: bool,

    pub fn init(allocator: std.mem.Allocator, current_directory: []const u8, use_case_sensitive_file_names: bool) KnownSymlinks {
        return KnownSymlinks{
            .allocator = allocator,
            .directories = std.StringHashMap(KnownDirectoryLink).init(allocator),
            .directories_by_realpath = std.StringHashMap(std.StringHashMap(void)).init(allocator),
            .files = std.StringHashMap([]const u8).init(allocator),
            .files_by_realpath = std.StringHashMap(std.StringHashMap(void)).init(allocator),
            .cwd = current_directory,
            .use_case_sensitive_file_names = use_case_sensitive_file_names,
        };
    }

    pub fn hasDirectory(self: *KnownSymlinks, symlink_path: []const u8) bool {
        return self.directories.contains(symlink_path); // assume trailing separator is handled externally
    }

    pub fn setDirectory(self: *KnownSymlinks, symlink: []const u8, symlink_path: []const u8, real_directory: ?KnownDirectoryLink) !void {
        if (real_directory) |real_dir| {
            if (!self.directories.contains(symlink_path)) {
                var set = self.directories_by_realpath.getPtr(real_dir.real_path);
                if (set == null) {
                    try self.directories_by_realpath.put(real_dir.real_path, std.StringHashMap(void).init(self.allocator));
                    set = self.directories_by_realpath.getPtr(real_dir.real_path);
                }
                try set.?.put(symlink, {});
            }
            try self.directories.put(symlink_path, real_dir);
        } else {
            // How to store nil? We cannot if it's not optional.
            // But real_directory is optional here. If null, maybe we shouldn't add it or remove it?
            // Go code: cache.directories.Store(symlinkPath, realDirectory) 
            // where realDirectory could be nil. We might need std.StringHashMap(?KnownDirectoryLink)
        }
    }

    pub fn setFile(self: *KnownSymlinks, symlink: []const u8, symlink_path: []const u8, realpath: []const u8) !void {
        if (!self.files.contains(symlink_path)) {
            const realpath_path = try self.toPath(realpath);
            var set = self.files_by_realpath.getPtr(realpath_path);
            if (set == null) {
                try self.files_by_realpath.put(realpath_path, std.StringHashMap(void).init(self.allocator));
                set = self.files_by_realpath.getPtr(realpath_path);
            }
            try set.?.put(symlink, {});
        }
        try self.files.put(symlink_path, realpath);
    }

    pub fn processResolution(self: *KnownSymlinks, original_path: []const u8, resolved_file_name: []const u8) !void {
        if (original_path.len == 0 or resolved_file_name.len == 0) {
            return;
        }

        const symlink_path = try self.toPath(original_path);
        try self.setFile(original_path, symlink_path, resolved_file_name);

        const common_resolved, const common_original = try self.guessDirectorySymlink(resolved_file_name, original_path, self.cwd);
        if (common_resolved.len != 0 and common_original.len != 0) {
            const common_symlink_path = try self.toPath(common_original);
            if (!try self.containsIgnoredPath(common_symlink_path)) {
                try self.setDirectory(
                    common_original,
                    try self.ensureTrailingDirectorySeparator(common_symlink_path),
                    KnownDirectoryLink{
                        .real = try self.ensureTrailingDirectorySeparator(common_resolved),
                        .real_path = try self.ensureTrailingDirectorySeparator(try self.toPath(common_resolved)),
                    },
                );
            }
        }
    }

    fn guessDirectorySymlink(self: *KnownSymlinks, a: []const u8, b: []const u8, cwd: []const u8) !struct { []const u8, []const u8 } {
        const a_normalized = try self.getNormalizedAbsolutePath(a, cwd);
        const b_normalized = try self.getNormalizedAbsolutePath(b, cwd);
        var a_parts = try self.getPathComponents(a_normalized);
        var b_parts = try self.getPathComponents(b_normalized);
        var is_directory = false;

        while (a_parts.len >= 2 and b_parts.len >= 2 and
            !self.isNodeModulesOrScopedPackageDirectory(a_parts[a_parts.len - 2]) and
            !self.isNodeModulesOrScopedPackageDirectory(b_parts[b_parts.len - 2]) and
            std.mem.eql(u8, try self.getCanonicalFileName(a_parts[a_parts.len - 1]), try self.getCanonicalFileName(b_parts[b_parts.len - 1])))
        {
            a_parts = a_parts[0 .. a_parts.len - 1];
            b_parts = b_parts[0 .. b_parts.len - 1];
            is_directory = true;
        }

        if (is_directory) {
            return .{ try self.getPathFromPathComponents(a_parts), try self.getPathFromPathComponents(b_parts) };
        }
        return .{ "", "" };
    }

    fn isNodeModulesOrScopedPackageDirectory(self: *KnownSymlinks, s: []const u8) bool {
        if (s.len == 0) return false;
        const canonical = self.getCanonicalFileName(s) catch s;
        return std.mem.eql(u8, canonical, "node_modules") or std.mem.startsWith(u8, s, "@");
    }

    // --- Mock tspath functions. In reality these should call tspath.xxx ---
    fn toPath(self: *KnownSymlinks, s: []const u8) ![]const u8 {
        _ = self;
        return s; // mock
    }

    fn getNormalizedAbsolutePath(self: *KnownSymlinks, path: []const u8, cwd: []const u8) ![]const u8 {
        _ = self;
        _ = cwd;
        return path; // mock
    }

    fn getPathComponents(self: *KnownSymlinks, path: []const u8) ![][]const u8 {
        var list = std.ArrayList([]const u8).init(self.allocator);
        var it = std.mem.splitScalar(u8, path, '/');
        while (it.next()) |part| {
            try list.append(part);
        }
        return try list.toOwnedSlice();
    }

    fn getCanonicalFileName(self: *KnownSymlinks, file_name: []const u8) ![]const u8 {
        if (self.use_case_sensitive_file_names) return file_name;
        const lower = try self.allocator.alloc(u8, file_name.len);
        _ = std.ascii.lowerString(lower, file_name);
        return lower;
    }

    fn getPathFromPathComponents(self: *KnownSymlinks, parts: [][]const u8) ![]const u8 {
        return try std.mem.join(self.allocator, "/", parts);
    }

    fn containsIgnoredPath(self: *KnownSymlinks, path: []const u8) !bool {
        _ = self;
        return std.mem.indexOf(u8, path, "node_modules") != null; // simplified mock
    }

    fn ensureTrailingDirectorySeparator(self: *KnownSymlinks, path: []const u8) ![]const u8 {
        if (path.len == 0 or path[path.len - 1] == '/') return path;
        return try std.fmt.allocPrint(self.allocator, "{s}/", .{path});
    }
};

pub fn setSymlinksFromResolutions(
    cache: *KnownSymlinks,
    for_each_resolved_module: anytype,
    for_each_resolved_type_reference_directive: anytype,
) !void {
    const ResolvedModuleHandler = struct {
        c: *KnownSymlinks,
        pub fn call(self: @This(), resolution: anytype, moduleName: []const u8, mode: anytype, filePath: []const u8) void {
            _ = moduleName;
            _ = mode;
            _ = filePath;
            self.c.processResolution(resolution.original_path, resolution.resolved_file_name) catch {};
        }
    };
    
    const ResolvedTypeReferenceDirectiveHandler = struct {
        c: *KnownSymlinks,
        pub fn call(self: @This(), resolution: anytype, moduleName: []const u8, mode: anytype, filePath: []const u8) void {
            _ = moduleName;
            _ = mode;
            _ = filePath;
            self.c.processResolution(resolution.original_path, resolution.resolved_file_name) catch {};
        }
    };

    try for_each_resolved_module(ResolvedModuleHandler{ .c = cache }, null);
    try for_each_resolved_type_reference_directive(ResolvedTypeReferenceDirectiveHandler{ .c = cache }, null);
}
