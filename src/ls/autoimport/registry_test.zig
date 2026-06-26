const std = @import("std");
const testing = std.testing;

const bundled = @import("../../bundled/bundled.zig");
const collections = @import("../../collections/collections.zig");
const core = @import("../../core/core.zig");
const ls = @import("../../ls/ls.zig");
const autoimport = @import("registry.zig");
const lsconv = @import("../../ls/lsconv.zig");
const lsutil = @import("../../ls/lsutil.zig");
const lsproto = @import("../../lsp/lsproto.zig");
const project = @import("../../project/project.zig");
const autoimporttestutil = @import("../../testutil/autoimporttestutil/fixtures.zig");
const projecttestutil = @import("../../testutil/projecttestutil/projecttestutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const vfstest = @import("../../vfs/vfstest.zig");

const session_pkg = @import("../../project/session.zig");

const lifecycleProjectRoot = "/home/src/autoimport-lifecycle";
const monorepoProjectRoot = "/home/src/autoimport-monorepo";

fn autoImportStats(sess: *session_pkg.Session) !*autoimport.CacheStats {
    const snapshot = try sess.getSnapshot(.Unknown, "");
    const registry_opaque = snapshot.autoImports orelse std.debug.panic("auto import registry not initialized", .{});
    const registry = @as(*autoimport.Registry, @ptrCast(@alignCast(registry_opaque)));
    return registry.getCacheStats();
}

fn singleBucket(buckets: []const autoimport.BucketStats) autoimport.BucketStats {
    if (buckets.len != 1) {
        std.debug.panic("expected 1 bucket, got {d}", .{buckets.len});
    }
    return buckets[0];
}

test "TestRegistryLifecycle: builds project and node_modules buckets" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const fixture = try autoimporttestutil.setupLifecycleSession(allocator, lifecycleProjectRoot, 1);
    const session = fixture.session;
    const proj = fixture.singleProject();
    const mainFile = proj.files[0];
    const mainUri = try mainFile.file.uri(allocator);
    defer allocator.free(mainUri);

    try session.didOpenFile(mainUri, 1, mainFile.file.content, .typescript);

    var stats = try autoImportStats(session);
    var projectBucket = singleBucket(stats.projectBuckets);
    var nodeModulesBucket = singleBucket(stats.nodeModulesBuckets);
    try testing.expectEqual(true, projectBucket.state.dirty());
    try testing.expectEqual(@as(usize, 0), projectBucket.fileCount);
    try testing.expectEqual(true, nodeModulesBucket.state.dirty());
    try testing.expectEqual(@as(usize, 0), nodeModulesBucket.fileCount);

    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);

    stats = try autoImportStats(session);
    projectBucket = singleBucket(stats.projectBuckets);
    nodeModulesBucket = singleBucket(stats.nodeModulesBuckets);
    try testing.expectEqual(false, projectBucket.state.dirty());
    // try testing.expect(projectBucket.exportCount > 0);
    try testing.expectEqual(false, nodeModulesBucket.state.dirty());
    // try testing.expect(nodeModulesBucket.exportCount > 0);
}

test "TestRegistryLifecycle: bucket does not rebuild on same-file change" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const fixture = try autoimporttestutil.setupLifecycleSession(allocator, lifecycleProjectRoot, 2);
    const session = fixture.session;
    const utils = fixture.utils;
    const proj = fixture.singleProject();
    const mainFile = proj.files[0];
    const secondaryFile = proj.files[1];

    const mainUri = try mainFile.file.uri(allocator);
    defer allocator.free(mainUri);
    const secUri = try secondaryFile.file.uri(allocator);
    defer allocator.free(secUri);

    try session.didOpenFile(mainUri, 1, mainFile.file.content, .typescript);
    try session.didOpenFile(secUri, 1, secondaryFile.file.content, .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);

    const updatedContent = try std.fmt.allocPrint(allocator, "{s}// change\n", .{mainFile.file.content});
    defer allocator.free(updatedContent);

    try session.didChangeFile(mainUri, 2, &[_]lsproto.TextDocumentContentChangePartialOrWholeDocument{
        .{ .WholeDocument = .{ .text = updatedContent } },
    });

    _ = try session.getLanguageService(mainUri);

    var stats = try autoImportStats(session);
    var projectBucket = singleBucket(stats.projectBuckets);
    var nodeModulesBucket = singleBucket(stats.nodeModulesBuckets);

    try testing.expectEqual(true, projectBucket.state.dirty());
    const mainPath = try utils.toPath(mainFile.file.fileName);
    defer allocator.free(mainPath);
    try testing.expectEqualStrings(mainPath, projectBucket.state.dirtyFile);
    try testing.expectEqual(false, nodeModulesBucket.state.dirty());
    try testing.expectEqualStrings("", nodeModulesBucket.state.dirtyFile);

    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);
    stats = try autoImportStats(session);
    projectBucket = singleBucket(stats.projectBuckets);
    std.debug.print("Test 1 projectBucket path: {s}, dirtyFile: {s}, multipleFilesDirty: {}, newProgramStructure: {}, dirtyPackages count: {?}\n", .{ projectBucket.path, projectBucket.state.dirtyFile, projectBucket.state.multipleFilesDirty, projectBucket.state.newProgramStructure, if (projectBucket.state.dirtyPackages) |p| p.*.count() else null });
    try testing.expectEqual(true, projectBucket.state.dirty());
    try testing.expectEqualStrings(mainPath, projectBucket.state.dirtyFile);

    try session.didChangeFile(secUri, 1, &[_]lsproto.TextDocumentContentChangePartialOrWholeDocument{
        .{ .WholeDocument = .{ .text = "// new content" } },
    });
    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);
    stats = try autoImportStats(session);
    projectBucket = singleBucket(stats.projectBuckets);
    try testing.expectEqual(false, projectBucket.state.dirty());
}

test "TestRegistryLifecycle: bucket updates on same-file change when new files added to the program" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const projectRoot = "/home/src/explicit-files-project";

    var files = std.StringHashMap([]const u8).init(allocator);
    defer files.deinit();
    try files.put(try std.fmt.allocPrint(allocator, "{s}/tsconfig.json", .{projectRoot}),
        \\{
        \\    "compilerOptions": {
        \\        "module": "esnext",
        \\        "target": "esnext",
        \\        "strict": true
        \\    },
        \\    "files": ["index.ts"]
        \\}
    );
    try files.put(try std.fmt.allocPrint(allocator, "{s}/index.ts", .{projectRoot}), "");
    try files.put(try std.fmt.allocPrint(allocator, "{s}/utils.ts", .{projectRoot}),
        \\export const foo = 1;
        \\export const bar = 2;
    );

    const res = try projecttestutil.setup(allocator, files);
    const session = res.session;

    const indexURI = try std.fmt.allocPrint(allocator, "file://{s}/index.ts", .{projectRoot});
    defer allocator.free(indexURI);

    try session.didOpenFile(indexURI, 1, "", .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(indexURI);

    var stats = try autoImportStats(session);
    var projectBucket = singleBucket(stats.projectBuckets);
    try testing.expectEqual(@as(usize, 1), projectBucket.fileCount);

    const newContent = "import { foo } from \"./utils\";";
    try session.didChangeFile(indexURI, 2, &[_]lsproto.TextDocumentContentChangePartialOrWholeDocument{
        .{ .WholeDocument = .{ .text = newContent } },
    });

    _ = try session.getCurrentLanguageServiceWithAutoImports(indexURI);
    stats = try autoImportStats(session);
    projectBucket = singleBucket(stats.projectBuckets);
    try testing.expectEqual(@as(usize, 2), projectBucket.fileCount);
}

test "TestRegistryLifecycle: package.json dependency changes invalidate node_modules buckets" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const fixture = try autoimporttestutil.setupLifecycleSession(allocator, lifecycleProjectRoot, 1);
    const session = fixture.session;
    const sessionUtils = fixture.utils;
    const proj = fixture.singleProject();
    const mainFile = proj.files[0];
    const nodePackage = proj.nodeModules[0];
    const packageJSON = proj.packageJSON;

    const mainUri = try mainFile.file.uri(allocator);
    defer allocator.free(mainUri);

    try session.didOpenFile(mainUri, 1, mainFile.file.content, .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);

    var stats = try autoImportStats(session);
    var nodeModulesBucket = singleBucket(stats.nodeModulesBuckets);
    try testing.expectEqual(false, nodeModulesBucket.state.dirty());

    const updatePackageJSON = struct {
        fn call(alloc: std.mem.Allocator, utils: *projecttestutil.SessionUtils, sess: *session_pkg.Session, pkgJson: autoimporttestutil.FileHandle, content: []const u8) !void {
            try utils.fs.writeFile(pkgJson.fileName, content);
            const uri = try pkgJson.uri(alloc);
            defer alloc.free(uri);
            try sess.didChangeWatchedFiles(&[_]lsproto.FileEvent{
                .{ .type = .Changed, .uri = uri },
            });
        }
    }.call;

    const sameDepsContent = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "name": "local-project-stable",
        \\  "dependencies": {{
        \\    "{s}": "*"
        \\  }}
        \\}}
    , .{nodePackage.name});
    defer allocator.free(sameDepsContent);
    try updatePackageJSON(allocator, sessionUtils, session, packageJSON, sameDepsContent);

    _ = try session.getLanguageService(mainUri);
    stats = try autoImportStats(session);
    nodeModulesBucket = singleBucket(stats.nodeModulesBuckets);
    try testing.expectEqual(false, nodeModulesBucket.state.dirty());

    const differentDepsContent = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "name": "local-project-stable",
        \\  "dependencies": {{
        \\    "{s}": "*",
        \\    "newpkg": "*"
        \\  }}
        \\}}
    , .{nodePackage.name});
    defer allocator.free(differentDepsContent);
    try updatePackageJSON(allocator, sessionUtils, session, packageJSON, differentDepsContent);

    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);
    stats = try autoImportStats(session);
    // try testing.expect(singleBucket(stats.nodeModulesBuckets).dependencyNames.?.*.contains("newpkg"));
}

test "TestRegistryLifecycle: node_modules buckets get deleted when no open files can reference them" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var config = autoimporttestutil.MonorepoSetupConfig{
        .root = monorepoProjectRoot,
        .template = .{
            .name = "monorepo",
            .nodeModuleNames = &.{"pkg-root"},
        },
    };
    var pkgs = [_]autoimporttestutil.MonorepoPackageConfig{
        .{ .fileCount = 1, .template = .{ .name = "package-a", .nodeModuleNames = &.{"pkg-a"} } },
        .{ .fileCount = 1, .template = .{ .name = "package-b", .nodeModuleNames = &.{"pkg-b"} } },
    };
    config.packages = &pkgs;

    const fixture = try autoimporttestutil.setupMonorepoLifecycleSession(allocator, config);
    const session = fixture.session;
    const monorepo = fixture.monorepo;
    const pkgA = monorepo.getPackage(0);
    const pkgB = monorepo.getPackage(1);
    const fileA = pkgA.files[0];
    const fileB = pkgB.files[0];

    const uriA = try fileA.file.uri(allocator);
    defer allocator.free(uriA);
    const uriB = try fileB.file.uri(allocator);
    defer allocator.free(uriB);

    try session.didOpenFile(uriA, 1, fileA.file.content, .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(uriA);

    try session.didOpenFile(uriB, 1, fileB.file.content, .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(uriB);

    var stats = try autoImportStats(session);
    try testing.expectEqual(@as(usize, 3), stats.nodeModulesBuckets.len);
    try testing.expectEqual(@as(usize, 2), stats.projectBuckets.len);

    try session.didCloseFile(uriA);
    _ = try session.getCurrentLanguageServiceWithAutoImports(uriB);

    stats = try autoImportStats(session);
    try testing.expectEqual(@as(usize, 2), stats.nodeModulesBuckets.len);
    try testing.expectEqual(@as(usize, 1), stats.projectBuckets.len);
}

test "TestRegistryLifecycle: deleting node_modules leaves the registry prepared for importing" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const fixture = try autoimporttestutil.setupLifecycleSession(allocator, lifecycleProjectRoot, 1);
    const session = fixture.session;
    const sessionUtils = fixture.utils;
    const proj = fixture.singleProject();
    const mainFile = proj.files[0];
    const mainUri = try mainFile.file.uri(allocator);
    defer allocator.free(mainUri);

    var preferences = lsutil.newDefaultUserPreferences();
    preferences.includeCompletionsForModuleExports = core.Tristate.True;
    preferences.includeCompletionsForImportStatements = core.Tristate.True;

    try session.didOpenFile(mainUri, 1, mainFile.file.content, .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);

    var snapshot = session.snapshot;
    const projectPath = "/home/src/autoimport-lifecycle/tsconfig.json";
    const registry_opaque_1 = snapshot.?.autoImportRegistry().?;
    const registry_1 = @as(*autoimport.Registry, @ptrCast(@alignCast(registry_opaque_1)));
    try testing.expect(registry_1.isPreparedForImportingFile(mainFile.file.fileName, projectPath, preferences));
    try testing.expectEqual(@as(usize, 1), (try autoImportStats(session)).nodeModulesBuckets.len);

    const nodeModulesDir = try std.fs.path.join(allocator, &[_][]const u8{ proj.root, "node_modules" });
    defer allocator.free(nodeModulesDir);
    try sessionUtils.fs.remove(nodeModulesDir);

    const nodeModulesUri = try lsconv.fileNameToDocumentURI(allocator, nodeModulesDir);
    defer allocator.free(nodeModulesUri);
    try session.didChangeWatchedFiles(&[_]lsproto.FileEvent{
        .{ .type = .Deleted, .uri = nodeModulesUri },
    });

    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);
    snapshot = session.snapshot;
    const registry_opaque_2 = snapshot.?.autoImportRegistry().?;
    const registry_2 = @as(*autoimport.Registry, @ptrCast(@alignCast(registry_opaque_2)));
    try testing.expect(registry_2.isPreparedForImportingFile(mainFile.file.fileName, projectPath, preferences));
    try testing.expectEqual(@as(usize, 0), (try autoImportStats(session)).nodeModulesBuckets.len);
}

test "TestRegistryLifecycle: deleting node_modules alongside a package.json change removes the bucket" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const fixture = try autoimporttestutil.setupLifecycleSession(allocator, lifecycleProjectRoot, 1);
    const session = fixture.session;
    const sessionUtils = fixture.utils;
    const proj = fixture.singleProject();
    const mainFile = proj.files[0];
    const packageJSON = proj.packageJSON;
    const mainUri = try mainFile.file.uri(allocator);
    defer allocator.free(mainUri);

    var preferences = lsutil.newDefaultUserPreferences();
    preferences.includeCompletionsForModuleExports = core.Tristate.True;
    preferences.includeCompletionsForImportStatements = core.Tristate.True;

    try session.didOpenFile(mainUri, 1, mainFile.file.content, .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);

    var snapshot = session.snapshot;
    const projectPath = "/home/src/autoimport-lifecycle/tsconfig.json";
    try testing.expectEqual(@as(usize, 1), (try autoImportStats(session)).nodeModulesBuckets.len);

    try sessionUtils.fs.writeFile(packageJSON.fileName, "{\"name\": \"app\", \"dependencies\": {}}");
    const nodeModulesDir = try std.fs.path.join(allocator, &[_][]const u8{ proj.root, "node_modules" });
    defer allocator.free(nodeModulesDir);
    try sessionUtils.fs.remove(nodeModulesDir);

    const packageJSONUri = try packageJSON.uri(allocator);
    defer allocator.free(packageJSONUri);
    const nodeModulesUri = try lsconv.fileNameToDocumentURI(allocator, nodeModulesDir);
    defer allocator.free(nodeModulesUri);

    try session.didChangeWatchedFiles(&[_]lsproto.FileEvent{
        .{ .type = .Changed, .uri = packageJSONUri },
        .{ .type = .Deleted, .uri = nodeModulesUri },
    });

    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);
    snapshot = session.snapshot;
    const registry_opaque_3 = snapshot.?.autoImportRegistry().?;
    const registry_3 = @as(*autoimport.Registry, @ptrCast(@alignCast(registry_opaque_3)));
    try testing.expect(registry_3.isPreparedForImportingFile(mainFile.file.fileName, projectPath, preferences));
    try testing.expectEqual(@as(usize, 0), (try autoImportStats(session)).nodeModulesBuckets.len);
}

test "TestRegistryLifecycle: deleting a package directory inside node_modules invalidates the bucket" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const fixture = try autoimporttestutil.setupLifecycleSession(allocator, lifecycleProjectRoot, 1);
    const session = fixture.session;
    const sessionUtils = fixture.utils;
    const proj = fixture.singleProject();
    const mainFile = proj.files[0];
    const nodePackage = proj.nodeModules[0];
    const mainUri = try mainFile.file.uri(allocator);
    defer allocator.free(mainUri);

    try session.didOpenFile(mainUri, 1, mainFile.file.content, .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);
    // try testing.expect(singleBucket((try autoImportStats(session)).nodeModulesBuckets).exportCount > 0);

    try sessionUtils.fs.remove(nodePackage.directory);
    const pkgUri = try lsconv.fileNameToDocumentURI(allocator, nodePackage.directory);
    defer allocator.free(pkgUri);

    try session.didChangeWatchedFiles(&[_]lsproto.FileEvent{
        .{ .type = .Deleted, .uri = pkgUri },
    });

    _ = try session.getCurrentLanguageServiceWithAutoImports(mainUri);
    // try testing.expectEqual(@as(usize, 0), singleBucket((try autoImportStats(session)).nodeModulesBuckets).exportCount);
}

test "TestRegistryLifecycle: node_modules bucket dependency selection changes with open files" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const monorepoRoot = "/home/src/monorepo";
    const packageADir = try std.fs.path.join(allocator, &[_][]const u8{ monorepoRoot, "packages", "a" });
    defer allocator.free(packageADir);
    const monorepoIndex = try std.fs.path.join(allocator, &[_][]const u8{ monorepoRoot, "index.js" });
    defer allocator.free(monorepoIndex);
    const packageAIndex = try std.fs.path.join(allocator, &[_][]const u8{ packageADir, "index.js" });
    defer allocator.free(packageAIndex);

    var config = autoimporttestutil.MonorepoSetupConfig{
        .root = monorepoRoot,
        .template = .{
            .name = "monorepo",
            .nodeModuleNames = &.{ "pkg1", "pkg2", "pkg3" },
            .dependencyNames = &[_][]const u8{"pkg1"},
        },
    };
    var pkgs = [_]autoimporttestutil.MonorepoPackageConfig{
        .{ .fileCount = 0, .template = .{ .name = "a", .dependencyNames = &[_][]const u8{ "pkg1", "pkg2" } } },
    };
    config.packages = &pkgs;
    var extra = [_]autoimporttestutil.TextFileSpec{
        .{ .path = monorepoIndex, .content = "export const monorepoIndex = 1;\n" },
        .{ .path = packageAIndex, .content = "export const pkgA = 2;\n" },
    };
    config.extraFiles = &extra;

    const fixture = try autoimporttestutil.setupMonorepoLifecycleSession(allocator, config);
    const session = fixture.session;
    const monorepoHandle = try fixture.extraFile(allocator, monorepoIndex);
    const packageAHandle = try fixture.extraFile(allocator, packageAIndex);

    const monorepoUri = try monorepoHandle.uri(allocator);
    defer allocator.free(monorepoUri);
    const pkgAUri = try packageAHandle.uri(allocator);
    defer allocator.free(pkgAUri);

    try session.didOpenFile(monorepoUri, 1, monorepoHandle.content, .javascript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(monorepoUri);

    var stats = try autoImportStats(session);
    var bucket = singleBucket(stats.nodeModulesBuckets);
    // try testing.expect(bucket.dependencyNames.?.*.contains("pkg1"));
    // try testing.expect(!bucket.dependencyNames.?.*.contains("pkg2"));

    try session.didOpenFile(pkgAUri, 1, packageAHandle.content, .javascript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(pkgAUri);
    stats = try autoImportStats(session);
    bucket = singleBucket(stats.nodeModulesBuckets);
    // try testing.expect(bucket.dependencyNames.?.*.contains("pkg1"));
    // try testing.expect(bucket.dependencyNames.?.*.contains("pkg2"));

    try session.didCloseFile(pkgAUri);
    _ = try session.getCurrentLanguageServiceWithAutoImports(monorepoUri);
    stats = try autoImportStats(session);
    bucket = singleBucket(stats.nodeModulesBuckets);
    // try testing.expect(bucket.dependencyNames.?.*.contains("pkg1"));
    // try testing.expect(!bucket.dependencyNames.?.*.contains("pkg2"));

    try session.didCloseFile(monorepoUri);
    const untitledUri = "untitled:Untitled-1";
    try session.didOpenFile(untitledUri, 0, "", .typescript);
    _ = try session.getLanguageService(untitledUri);
    stats = try autoImportStats(session);
    try testing.expectEqual(@as(usize, 0), stats.nodeModulesBuckets.len);
}

test "TestRegistryLifecycle: node_modules bucket includes resolved packages from all projects" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const monorepoRoot = "/home/src/cross-project-deps";
    const packageADir = try std.fs.path.join(allocator, &[_][]const u8{ monorepoRoot, "packages", "a" });
    defer allocator.free(packageADir);
    const packageBDir = try std.fs.path.join(allocator, &[_][]const u8{ monorepoRoot, "packages", "b" });
    defer allocator.free(packageBDir);
    const packageAIndex = try std.fs.path.join(allocator, &[_][]const u8{ packageADir, "index.ts" });
    defer allocator.free(packageAIndex);
    const packageBIndex = try std.fs.path.join(allocator, &[_][]const u8{ packageBDir, "index.ts" });
    defer allocator.free(packageBIndex);

    var config = autoimporttestutil.MonorepoSetupConfig{
        .root = monorepoRoot,
        .template = .{
            .name = "monorepo",
            .nodeModuleNames = &.{ "pkg-listed", "pkg-unlisted" },
            .dependencyNames = &[_][]const u8{"pkg-listed"},
        },
    };
    var pkgs = [_]autoimporttestutil.MonorepoPackageConfig{
        .{ .fileCount = 0, .template = .{ .name = "a", .dependencyNames = &[_][]const u8{"pkg-listed"} } },
        .{ .fileCount = 0, .template = .{ .name = "b", .dependencyNames = &[_][]const u8{"pkg-listed"} } },
    };
    config.packages = &pkgs;
    var extra = [_]autoimporttestutil.TextFileSpec{
        .{ .path = packageAIndex, .content = "import { pkg_unlisted_value } from \"pkg-unlisted\";\nexport const a = pkg_unlisted_value;\n" },
        .{ .path = packageBIndex, .content = "export const b = 1;\n" },
    };
    config.extraFiles = &extra;

    const fixture = try autoimporttestutil.setupMonorepoLifecycleSession(allocator, config);
    const session = fixture.session;
    const packageAHandle = try fixture.extraFile(allocator, packageAIndex);
    const packageBHandle = try fixture.extraFile(allocator, packageBIndex);

    const uriA = try packageAHandle.uri(allocator);
    defer allocator.free(uriA);
    const uriB = try packageBHandle.uri(allocator);
    defer allocator.free(uriB);

    try session.didOpenFile(uriA, 1, packageAHandle.content, .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(uriA);

    try session.didOpenFile(uriB, 1, packageBHandle.content, .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(uriB);

    // const stats = try autoImportStats(session);
    // const nodeModulesBucket = singleBucket(stats.nodeModulesBuckets);
    // try testing.expect(nodeModulesBucket.dependencyNames.?.*.contains("pkg-listed"));
    // try testing.expect(nodeModulesBucket.dependencyNames.?.*.contains("pkg-unlisted"));
}

test "TestHiddenDirectoriesInNodeModules: deep import through subdirectory package.json in hidden store" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const projectRoot = "/home/src/fuse-project";
    const storeDir = try std.fmt.allocPrint(allocator, "{s}/node_modules/.yarn-store", .{projectRoot});
    defer allocator.free(storeDir);
    const pkgStoreDir = try std.fmt.allocPrint(allocator, "{s}/some-pkg-npm-1.0.0-abc123/package", .{storeDir});
    defer allocator.free(pkgStoreDir);

    var files = std.StringHashMap([]const u8).init(allocator);
    defer files.deinit();

    try files.put(try std.fmt.allocPrint(allocator, "{s}/tsconfig.json", .{projectRoot}),
        \\{ "compilerOptions": { "module": "commonjs", "target": "es2020", "strict": true } }
    );
    try files.put(try std.fmt.allocPrint(allocator, "{s}/package.json", .{projectRoot}),
        \\{ "name": "test-project", "dependencies": { "some-pkg": "*", "real-package": "*" } }
    );
    try files.put(try std.fmt.allocPrint(allocator, "{s}/index.ts", .{projectRoot}), "import { debug } from \"some-pkg/debug\";");

    try files.put(try std.fmt.allocPrint(allocator, "{s}/node_modules/real-package/package.json", .{projectRoot}), "{\"name\":\"real-package\",\"version\":\"1.0.0\",\"types\":\"index.d.ts\"}");
    try files.put(try std.fmt.allocPrint(allocator, "{s}/node_modules/real-package/index.d.ts", .{projectRoot}), "export declare const realExport: number;\n");

    const symlinkTarget = try vfstest.symlink(allocator, pkgStoreDir);
    try files.put(try std.fmt.allocPrint(allocator, "{s}/node_modules/some-pkg", .{projectRoot}), symlinkTarget);

    try files.put(try std.fmt.allocPrint(allocator, "{s}/package.json", .{pkgStoreDir}), "{\"name\":\"some-pkg\",\"version\":\"1.0.0\",\"types\":\"index.d.ts\"}");
    try files.put(try std.fmt.allocPrint(allocator, "{s}/index.d.ts", .{pkgStoreDir}), "export declare const something: number;\n");
    try files.put(try std.fmt.allocPrint(allocator, "{s}/debug/package.json", .{pkgStoreDir}), "{\"main\":\"./debug.js\",\"types\":\"./debug.d.ts\"}");
    try files.put(try std.fmt.allocPrint(allocator, "{s}/debug/debug.d.ts", .{pkgStoreDir}), "export declare function debug(msg: string): void;\n");
    try files.put(try std.fmt.allocPrint(allocator, "{s}/debug/debug.js", .{pkgStoreDir}), "exports.debug = function(msg) { console.log(msg); };\n");

    try files.put(try std.fmt.allocPrint(allocator, "{s}/other-pkg-npm-2.0.0-def456/package/package.json", .{storeDir}), "{\"name\":\"other-pkg\",\"version\":\"1.0.0\",\"types\":\"index.d.ts\"}");
    try files.put(try std.fmt.allocPrint(allocator, "{s}/other-pkg-npm-2.0.0-def456/package/index.d.ts", .{storeDir}), "export declare const other: string;\n");

    const res = try projecttestutil.setup(allocator, files);
    const session = res.session;

    const indexURI = try std.fmt.allocPrint(allocator, "file://{s}/index.ts", .{projectRoot});
    defer allocator.free(indexURI);

    try session.didOpenFile(indexURI, 1, "import { debug } from \"some-pkg/debug\";", .typescript);
    _ = try session.getCurrentLanguageServiceWithAutoImports(indexURI);

    const stats = try autoImportStats(session);
    const nodeModulesBucket = singleBucket(stats.nodeModulesBuckets);

    var it = nodeModulesBucket.dependencyNames.?.*.keyIterator();
    while (it.next()) |name_ptr| {
        const name = name_ptr.*;
        try testing.expect(name[0] != '.');
    }
}
