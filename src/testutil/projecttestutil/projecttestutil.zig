const std = @import("std");
const bundled = @import("../../bundled/bundled.zig");
const core = @import("../../core/core.zig");
const glob = @import("../../glob/glob.zig");
const lsproto = @import("../../lsp/lsproto.zig");
const project = @import("../../project/project.zig");
const session = @import("../../project/session.zig");
const logging = @import("../../project/logging/logging.zig");
const baseline = @import("../baseline/baseline.zig");
const tspath = @import("../../tspath/tspath.zig");
const vfs = @import("../../vfs/vfs.zig");
const iovfs = @import("../../vfs/iovfs.zig");
const osvfs = @import("../../vfs/osvfs/osvfs.zig");
const vfstest = @import("../../vfs/vfstest.zig");

const ClientMock = @import("clientmock_generated.zig").ClientMock;
const NpmExecutorMock = @import("npmexecutormock_generated.zig").NpmExecutorMock;

pub const TestTypingsLocation = "/home/src/Library/Caches/typescript";

pub const TypingsInstallerOptions = struct {
    typesRegistry: []const []const u8 = &[_][]const u8{},
    packageToFile: std.StringHashMap([]const u8),
};

pub const SessionUtils = struct {
    allocator: std.mem.Allocator,
    currentDirectory: []const u8,
    fsFromFileMap: vfstest.VfsTest,
    fs: vfstest.VfsTest,
    client: *ClientMock,
    npmExecutor: *NpmExecutorMock,
    tiOptions: ?*TypingsInstallerOptions,
    logger: *logging.TestLogger,

    pub fn init(allocator: std.mem.Allocator) SessionUtils {
        return .{
            .allocator = allocator,
            .currentDirectory = "",
            .fsFromFileMap = undefined,
            .fs = undefined,
            .client = undefined,
            .npmExecutor = undefined,
            .tiOptions = null,
            .logger = undefined,
        };
    }

    pub fn setupNpmExecutorForTypingsInstaller(self: *SessionUtils) void {
        if (self.tiOptions == null) return;
        self.npmExecutor.ctx = self;
        self.npmExecutor.npmInstallFunc = npmInstallImpl;
    }

    fn npmInstallImpl(ctx: ?*anyopaque, cwd: []const u8, packageNames: []const []const u8) anyerror![]u8 {
        const self: *SessionUtils = @ptrCast(@alignCast(ctx));
        const len = packageNames.len;
        if (len < 3) {
            return error.UnexpectedNpmInstall;
        }

        if (len == 3 and std.mem.eql(u8, packageNames[2], "types-registry@latest")) {
            const registry_content = try self.createTypesRegistryFileContent();
            defer self.allocator.free(registry_content);
            const path = try std.fs.path.join(self.allocator, &[_][]const u8{ cwd, "node_modules/types-registry/index.json" });
            defer self.allocator.free(path);
            try self.fs.writeFile(path, registry_content);
            return &[_]u8{};
        }

        var packageEnd = len;
        for (packageNames[2..], 2..) |arg, i| {
            if (std.mem.startsWith(u8, arg, "--")) {
                packageEnd = i;
                break;
            }
        }

        for (packageNames[2..packageEnd]) |atTypesPackageTs| {
            var atTypesPackage = atTypesPackageTs;
            if (std.mem.lastIndexOfScalar(u8, atTypesPackage, '@')) |versionIndex| {
                if (versionIndex > 6) {
                    atTypesPackage = atTypesPackage[0..versionIndex];
                }
            }
            const packageBaseName = atTypesPackage[7..]; // Remove "@types/"
            if (self.tiOptions.?.packageToFile.get(packageBaseName)) |content| {
                const path = try std.fmt.allocPrint(self.allocator, "{s}/node_modules/@types/{s}/index.d.ts", .{ cwd, packageBaseName });
                defer self.allocator.free(path);
                try self.fs.writeFile(path, content);
            } else {
                return error.ContentNotProvided;
            }
        }
        return &[_]u8{};
    }

    pub fn toPath(self: *SessionUtils, fileName: []const u8) ![]const u8 {
        return tspath.toPath(self.allocator, fileName, self.currentDirectory, self.fs.useCaseSensitiveFileNames());
    }

    pub fn watchesFile(self: *SessionUtils, filePath: []const u8) !bool {
        for (self.client.watchFilesCalls()) |call| {
            for (call.watchers) |watcher| {
                if (watcher.globPattern.pattern) |p| {
                    var g = try glob.parse(self.allocator, p);
                    defer g.deinit();
                    if (try g.match(filePath)) {
                        return true;
                    }
                } else if (watcher.globPattern.relativePattern) |rp| {
                    const baseUri = rp.baseUri.uri;
                    const baseDir = lsproto.DocumentUri.fileName(self.allocator, baseUri) catch continue;
                    defer self.allocator.free(baseDir);
                    const baseDirTrailing = try tspath.ensureTrailingDirectorySeparator(self.allocator, baseDir);
                    defer self.allocator.free(baseDirTrailing);

                    if (std.mem.startsWith(u8, filePath, baseDirTrailing)) {
                        const relativePath = filePath[baseDirTrailing.len..];
                        var g = try glob.parse(self.allocator, rp.pattern);
                        defer g.deinit();
                        if (try g.match(relativePath)) {
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    }

    pub fn logs(self: *SessionUtils) []const u8 {
        return self.logger.string();
    }

    pub fn createTypesRegistryFileContent(self: *SessionUtils) ![]u8 {
        var builder = std.ArrayList(u8).empty;
        defer builder.deinit(self.allocator);
        try builder.appendSlice(self.allocator, "{\n  \"entries\": {");

        for (self.tiOptions.?.typesRegistry, 0..) |entry, index| {
            try self.appendTypesRegistryConfig(&builder, index, entry);
        }

        var index: usize = self.tiOptions.?.typesRegistry.len;
        var it = self.tiOptions.?.packageToFile.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            var found = false;
            for (self.tiOptions.?.typesRegistry) |reg| {
                if (std.mem.eql(u8, reg, key)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try self.appendTypesRegistryConfig(&builder, index, key);
                index += 1;
            }
        }
        try builder.appendSlice(self.allocator, "\n  }\n}");
        return builder.toOwnedSlice(self.allocator);
    }

    fn appendTypesRegistryConfig(self: *SessionUtils, builder: *std.ArrayList(u8), index: usize, entry: []const u8) !void {
        if (index > 0) {
            try builder.appendSlice(self.allocator, ",");
        }
        const text = try typesRegistryConfigText(self.allocator);
        const s = try std.fmt.allocPrint(self.allocator, "\n    \"{s}\": {{{s}\n    }}", .{ entry, text });
        try builder.appendSlice(self.allocator, s);
    }
};

var types_registry_config_text_cache: ?[]const u8 = null;
pub fn typesRegistryConfigText(allocator: std.mem.Allocator) ![]const u8 {
    if (types_registry_config_text_cache) |t| return t;
    var result = std.ArrayList(u8).empty;
    const config = try typesRegistryConfig(allocator);
    var first = true;
    var it = config.iterator();
    while (it.next()) |entry| {
        if (!first) {
            try result.appendSlice(allocator, ",");
        }
        const s = try std.fmt.allocPrint(allocator, "\n      \"{s}\": \"{s}\"", .{ entry.key_ptr.*, entry.value_ptr.* });
        try result.appendSlice(allocator, s);
        first = false;
    }
    types_registry_config_text_cache = try result.toOwnedSlice(allocator);
    return types_registry_config_text_cache.?;
}

var types_registry_config_cache: ?std.StringHashMap([]const u8) = null;
pub fn typesRegistryConfig(allocator: std.mem.Allocator) !*std.StringHashMap([]const u8) {
    if (types_registry_config_cache) |*c| return c;
    var map = std.StringHashMap([]const u8).init(allocator);
    try map.put("latest", "1.3.0");
    try map.put("ts2.0", "1.0.0");
    try map.put("ts2.1", "1.0.0");
    try map.put("ts2.2", "1.2.0");
    try map.put("ts2.3", "1.3.0");
    try map.put("ts2.4", "1.3.0");
    try map.put("ts2.5", "1.3.0");
    try map.put("ts2.6", "1.3.0");
    try map.put("ts2.7", "1.3.0");
    types_registry_config_cache = map;
    return &types_registry_config_cache.?;
}

pub const SetupResult = struct { session: *session.Session, utils: *SessionUtils };

pub fn setup(allocator: std.mem.Allocator, files: std.StringHashMap([]const u8)) !SetupResult {
    var tiOptions = TypingsInstallerOptions{
        .packageToFile = std.StringHashMap([]const u8).init(allocator),
    };
    return setupWithTypingsInstaller(allocator, files, &tiOptions);
}

pub fn setupWithTypingsInstaller(allocator: std.mem.Allocator, files: std.StringHashMap([]const u8), tiOptions: *TypingsInstallerOptions) !SetupResult {
    return setupWithOptionsAndTypingsInstaller(allocator, files, null, tiOptions);
}

pub fn setupWithOptionsAndTypingsInstaller(allocator: std.mem.Allocator, files: std.StringHashMap([]const u8), options: ?*session.SessionOptions, tiOptions: *TypingsInstallerOptions) !SetupResult {
    const res = try getSessionInitOptions(allocator, files, options, tiOptions);
    const sess = try allocator.create(session.Session);
    sess.* = session.Session.init(allocator, res.init);
    return .{ .session = sess, .utils = res.utils };
}

pub fn getSessionInitOptions(allocator: std.mem.Allocator, files: std.StringHashMap([]const u8), options: ?*session.SessionOptions, tiOptions: *TypingsInstallerOptions) !struct { init: *session.SessionInit, utils: *SessionUtils } {
    const fsFromFileMap = vfstest.fromMap(files, false);
    const fs = bundled.WrapFS(fsFromFileMap);

    const clientMock = try allocator.create(ClientMock);
    clientMock.* = ClientMock.init(allocator);

    const npmExecutorMock = try allocator.create(NpmExecutorMock);
    npmExecutorMock.* = NpmExecutorMock.init(allocator);

    const logger = try logging.TestLogger.init(allocator);

    var sessionUtils = try allocator.create(SessionUtils);
    sessionUtils.* = .{
        .allocator = allocator,
        .currentDirectory = "/",
        .fsFromFileMap = fsFromFileMap,
        .fs = fs,
        .client = clientMock,
        .npmExecutor = npmExecutorMock,
        .tiOptions = tiOptions,
        .logger = logger,
    };

    sessionUtils.setupNpmExecutorForTypingsInstaller();

    var actualOptions = options;
    if (actualOptions == null) {
        actualOptions = try allocator.create(session.SessionOptions);
        actualOptions.?.* = .{
            .currentDirectory = "/",
            .defaultLibraryPath = bundled.LibPath(),
            .typingsLocation = TestTypingsLocation,
            // .positionEncoding = lsproto.PositionEncodingKind.utf8,
            .watchEnabled = true,
            .loggingEnabled = true,
            .telemetryEnabled = false,
            .pushDiagnosticsEnabled = true,
            .debounceDelayMs = 0,
        };
    }

    const init = try allocator.create(session.SessionInit);
    init.* = .{
        .options = actualOptions.?,
    };

    return .{ .init = init, .utils = sessionUtils };
}
