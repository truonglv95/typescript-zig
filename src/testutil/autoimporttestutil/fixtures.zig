const std = @import("std");
const lsconv = @import("../../ls/lsconv.zig");
const lsproto = @import("../../lsp/lsproto.zig");
const project = @import("../../project/project.zig");
const projecttestutil = @import("../projecttestutil/projecttestutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const vfstest = @import("../../vfs/vfstest.zig");
const session = @import("../../project/session.zig");

pub const FileHandle = struct {
    fileName: []const u8,
    content: []const u8,

    pub fn uri(self: FileHandle, allocator: std.mem.Allocator) !lsproto.DocumentUri {
        return lsconv.fileNameToDocumentURI(allocator, self.fileName);
    }
};

pub const ProjectFileHandle = struct {
    file: FileHandle,
    exportIdentifier: []const u8,
};

pub const NodeModulesPackageHandle = struct {
    name: []const u8,
    directory: []const u8,
    packageJSON: FileHandle,
    declaration: FileHandle,
};

pub const ProjectHandle = struct {
    root: []const u8,
    files: []ProjectFileHandle,
    tsconfig: FileHandle,
    packageJSON: FileHandle,
    nodeModules: []NodeModulesPackageHandle,
    dependencies: [][]const u8,

    pub fn nodeModuleByName(self: ProjectHandle, name: []const u8) ?*const NodeModulesPackageHandle {
        for (self.nodeModules) |*mod| {
            if (std.mem.eql(u8, mod.name, name)) {
                return mod;
            }
        }
        return null;
    }
};

pub const MonorepoHandle = struct {
    root: []const u8,
    rootNodeModules: []NodeModulesPackageHandle,
    rootDependencies: [][]const u8,
    packages: []ProjectHandle,
    rootTSConfig: FileHandle,
    rootPackageJSON: FileHandle,

    pub fn getPackage(self: MonorepoHandle, index: usize) ProjectHandle {
        if (index >= self.packages.len) {
            @panic("package index out of range");
        }
        return self.packages[index];
    }
};

pub const Fixture = struct {
    session: *session.Session,
    utils: *projecttestutil.SessionUtils,
    projects: []ProjectHandle,

    pub fn projectAt(self: Fixture, index: usize) ProjectHandle {
        if (index >= self.projects.len) {
            @panic("project index out of range");
        }
        return self.projects[index];
    }

    pub fn singleProject(self: Fixture) ProjectHandle {
        return self.projectAt(0);
    }
};

pub const MonorepoFixture = struct {
    session: *session.Session,
    utils: *projecttestutil.SessionUtils,
    monorepo: MonorepoHandle,
    extra: []FileHandle,

    pub fn extraFile(self: MonorepoFixture, allocator: std.mem.Allocator, path: []const u8) !FileHandle {
        const normalized = try normalizeAbsolutePath(allocator, path);
        defer allocator.free(normalized);

        for (self.extra) |handle| {
            if (std.mem.eql(u8, handle.fileName, normalized)) {
                return handle;
            }
        }
        return error.ExtraFileNotFound;
    }
};

pub const MonorepoPackageTemplate = struct {
    name: []const u8 = "",
    nodeModuleNames: []const []const u8 = &[_][]const u8{},
    dependencyNames: []const []const u8 = &[_][]const u8{},
};

pub const MonorepoPackageConfig = struct {
    fileCount: usize,
    template: MonorepoPackageTemplate,
};

pub const TextFileSpec = struct {
    path: []const u8,
    content: []const u8,
};

pub const SymlinkSpec = struct {
    link: []const u8,
    target: []const u8,
};

pub const MonorepoSetupConfig = struct {
    root: []const u8,
    template: MonorepoPackageTemplate,
    packages: []MonorepoPackageConfig = &[_]MonorepoPackageConfig{},
    extraFiles: []TextFileSpec = &[_]TextFileSpec{},
    symlinks: []SymlinkSpec = &[_]SymlinkSpec{},
};

pub fn setupMonorepoLifecycleSession(allocator: std.mem.Allocator, config: MonorepoSetupConfig) !*MonorepoFixture {
    var builder = try FileMapBuilder.init(allocator, null);
    defer builder.deinit();

    const monorepoRoot = try normalizeAbsolutePath(allocator, config.root);
    var monorepoName = config.template.name;
    if (monorepoName.len == 0) {
        monorepoName = "monorepo";
    }

    const rootTSConfigPath = try std.fs.path.join(allocator, &[_][]const u8{ monorepoRoot, "tsconfig.json" });
    const rootTSConfigContent = "{\n  \"compilerOptions\": {\n    \"module\": \"esnext\",\n    \"target\": \"esnext\",\n    \"strict\": true,\n    \"baseUrl\": \".\",\n    \"allowJs\": true,\n    \"checkJs\": true\n  }\n}\n";
    try builder.addTextFile(rootTSConfigPath, rootTSConfigContent);
    const rootTSConfig = FileHandle{ .fileName = rootTSConfigPath, .content = rootTSConfigContent };

    const rootNodeModulesDir = try std.fs.path.join(allocator, &[_][]const u8{ monorepoRoot, "node_modules" });
    const rootNodeModules = try builder.addNodeModulesPackagesWithNames(rootNodeModulesDir, config.template.nodeModuleNames);

    const rootDependencies = try selectPackagesByName(allocator, rootNodeModules, config.template.dependencyNames);
    const rootPackageJSON = try builder.addRootPackageJSON(monorepoRoot, monorepoName, rootDependencies);
    const rootDependencyNames = try packageNames(allocator, rootDependencies);

    const packagesDir = try std.fs.path.join(allocator, &[_][]const u8{ monorepoRoot, "packages" });
    var packageHandles = std.ArrayList(ProjectHandle).empty;

    for (config.packages) |pkg| {
        const pkgDir = try std.fs.path.join(allocator, &[_][]const u8{ packagesDir, pkg.template.name });
        try builder.addLocalProject(pkgDir, pkg.fileCount);

        var pkgNodeModules: []NodeModulesPackageHandle = @constCast(&[_]NodeModulesPackageHandle{});
        if (pkg.template.nodeModuleNames.len > 0) {
            const pkgNodeModulesDir = try std.fs.path.join(allocator, &[_][]const u8{ pkgDir, "node_modules" });
            pkgNodeModules = try builder.addNodeModulesPackagesWithNames(pkgNodeModulesDir, pkg.template.nodeModuleNames);
        }

        var availableDeps = std.ArrayList(NodeModulesPackageHandle).empty;
        try availableDeps.appendSlice(allocator, rootNodeModules);
        try availableDeps.appendSlice(allocator, pkgNodeModules);

        const selectedDeps = try selectPackagesByName(allocator, availableDeps.items, pkg.template.dependencyNames);
        if (selectedDeps.len > 0) {
            _ = try builder.addPackageJSONWithDependenciesNamed(pkgDir, pkg.template.name, selectedDeps);
        }
    }

    var extraHandles = std.ArrayList(FileHandle).empty;
    for (config.extraFiles) |extra| {
        try builder.addTextFile(extra.path, extra.content);
        extraHandles.append(allocator, .{
            .fileName = try normalizeAbsolutePath(allocator, extra.path),
            .content = extra.content,
        }) catch {};
    }

    for (config.symlinks) |symlink| {
        try builder.addSymlink(symlink.link, symlink.target);
    }

    for (config.packages) |pkg| {
        const pkgDir = try std.fs.path.join(allocator, &[_][]const u8{ packagesDir, pkg.template.name });
        if (builder.projects.get(pkgDir)) |record| {
            try packageHandles.append(allocator, try record.toHandles(allocator));
        }
    }

    const res = try projecttestutil.setup(allocator, builder.files);
    const session_ptr = res.session;
    const utils = res.utils;

    var rootNodeModulesHandles: []NodeModulesPackageHandle = @constCast(&[_]NodeModulesPackageHandle{});
    if (builder.projects.get(monorepoRoot)) |rootRecord| {
        rootNodeModulesHandles = rootRecord.nodeModules.items;
    }

    const fix = try allocator.create(MonorepoFixture);
    fix.* = .{
        .session = session_ptr,
        .utils = utils,
        .monorepo = .{
            .root = monorepoRoot,
            .rootNodeModules = rootNodeModulesHandles,
            .rootDependencies = rootDependencyNames,
            .packages = try packageHandles.toOwnedSlice(allocator),
            .rootTSConfig = rootTSConfig,
            .rootPackageJSON = rootPackageJSON,
        },
        .extra = try extraHandles.toOwnedSlice(allocator),
    };
    return fix;
}

pub fn setupLifecycleSession(allocator: std.mem.Allocator, projectRoot: []const u8, fileCount: usize) !*Fixture {
    var builder = try FileMapBuilder.init(allocator, null);
    defer builder.deinit();

    try builder.addLocalProject(projectRoot, fileCount);
    const nodeModulesDir = try std.fs.path.join(allocator, &[_][]const u8{ projectRoot, "node_modules" });
    const deps = try builder.addNodeModulesPackages(nodeModulesDir, 1);
    _ = try builder.addPackageJSONWithDependencies(projectRoot, deps);

    const res = try projecttestutil.setup(allocator, builder.files);
    const fix = try allocator.create(Fixture);
    fix.* = .{
        .session = res.session,
        .utils = res.utils,
        .projects = try builder.projectHandles(),
    };
    return fix;
}

const ProjectFile = struct {
    fileName: []const u8,
    exportIdentifier: []const u8,
    content: []const u8,
};

const ProjectRecord = struct {
    root: []const u8,
    sourceFiles: std.ArrayList(ProjectFile),
    tsconfig: FileHandle,
    packageJSON: ?FileHandle = null,
    nodeModules: std.ArrayList(NodeModulesPackageHandle),
    dependencies: std.ArrayList([]const u8),

    pub fn init(root: []const u8) ProjectRecord {
        return .{
            .root = root,
            .sourceFiles = .empty,
            .tsconfig = undefined,
            .nodeModules = .empty,
            .dependencies = .empty,
        };
    }

    pub fn toHandles(self: *ProjectRecord, allocator: std.mem.Allocator) !ProjectHandle {
        var files = std.ArrayList(ProjectFileHandle).empty;
        for (self.sourceFiles.items) |file| {
            try files.append(allocator, .{
                .file = .{ .fileName = file.fileName, .content = file.content },
                .exportIdentifier = file.exportIdentifier,
            });
        }
        var pkgJSON = FileHandle{ .fileName = "", .content = "" };
        if (self.packageJSON) |pj| {
            pkgJSON = pj;
        }

        return ProjectHandle{
            .root = self.root,
            .files = try files.toOwnedSlice(allocator),
            .tsconfig = self.tsconfig,
            .packageJSON = pkgJSON,
            .nodeModules = try allocator.dupe(NodeModulesPackageHandle, self.nodeModules.items),
            .dependencies = try allocator.dupe([]const u8, self.dependencies.items),
        };
    }
};

const FileMapBuilder = struct {
    allocator: std.mem.Allocator,
    files: std.StringHashMap([]const u8),
    nextPackageID: usize = 0,
    nextProjectID: usize = 0,
    projects: std.StringHashMap(*ProjectRecord),

    pub fn init(allocator: std.mem.Allocator, initial: ?std.StringHashMap([]const u8)) !FileMapBuilder {
        var b = FileMapBuilder{
            .allocator = allocator,
            .files = std.StringHashMap([]const u8).init(allocator),
            .projects = std.StringHashMap(*ProjectRecord).init(allocator),
        };
        if (initial) |m| {
            var it = m.iterator();
            while (it.next()) |entry| {
                const norm = try normalizeAbsolutePath(allocator, entry.key_ptr.*);
                try b.files.put(norm, entry.value_ptr.*);
            }
        }
        return b;
    }

    pub fn deinit(self: *FileMapBuilder) void {
        self.files.deinit();
        self.projects.deinit();
    }

    fn ensureProjectRecord(self: *FileMapBuilder, root: []const u8) !*ProjectRecord {
        if (self.projects.get(root)) |record| {
            return record;
        }
        const record = try self.allocator.create(ProjectRecord);
        record.* = ProjectRecord.init(root);
        try self.projects.put(root, record);
        return record;
    }

    pub fn projectHandles(self: *FileMapBuilder) ![]ProjectHandle {
        var handles = std.ArrayList(ProjectHandle).empty;
        var it = self.projects.iterator();
        while (it.next()) |entry| {
            try handles.append(self.allocator, try entry.value_ptr.*.toHandles(self.allocator));
        }
        return handles.toOwnedSlice(self.allocator);
    }

    pub fn addTextFile(self: *FileMapBuilder, path: []const u8, content: []const u8) !void {
        const norm = try normalizeAbsolutePath(self.allocator, path);
        try self.files.put(norm, content);
    }

    pub fn addSymlink(self: *FileMapBuilder, linkPath: []const u8, targetPath: []const u8) !void {
        const normLink = try normalizeAbsolutePath(self.allocator, linkPath);
        const normTarget = try normalizeAbsolutePath(self.allocator, targetPath);
        const symlinkContent = try vfstest.symlink(self.allocator, normTarget);
        try self.files.put(normLink, symlinkContent);
    }

    pub fn addNodeModulesPackages(self: *FileMapBuilder, nodeModulesDir: []const u8, count: usize) ![]NodeModulesPackageHandle {
        var packages = std.ArrayList(NodeModulesPackageHandle).empty;
        for (0..count) |_| {
            try packages.append(self.allocator, try self.addNodeModulesPackage(nodeModulesDir));
        }
        return packages.toOwnedSlice(self.allocator);
    }

    pub fn addNodeModulesPackagesWithNames(self: *FileMapBuilder, nodeModulesDir: []const u8, names: []const []const u8) ![]NodeModulesPackageHandle {
        if (names.len == 0) return &[_]NodeModulesPackageHandle{};
        var packages = std.ArrayList(NodeModulesPackageHandle).empty;
        for (names) |name| {
            try packages.append(self.allocator, try self.addNamedNodeModulesPackage(nodeModulesDir, name));
        }
        return packages.toOwnedSlice(self.allocator);
    }

    pub fn addNodeModulesPackage(self: *FileMapBuilder, nodeModulesDir: []const u8) !NodeModulesPackageHandle {
        return self.addNamedNodeModulesPackage(nodeModulesDir, "");
    }

    pub fn addNamedNodeModulesPackage(self: *FileMapBuilder, nodeModulesDir: []const u8, name: []const u8) !NodeModulesPackageHandle {
        const normDir = try normalizeAbsolutePath(self.allocator, nodeModulesDir);
        if (!std.mem.eql(u8, tspath.getBaseFileName(normDir), "node_modules")) {
            return error.NotNodeModulesDirectory;
        }

        self.nextPackageID += 1;
        var resolvedName = name;
        if (resolvedName.len == 0) {
            resolvedName = try std.fmt.allocPrint(self.allocator, "pkg{d}", .{self.nextPackageID});
        }

        const sanitized = try sanitizeIdentifier(self.allocator, resolvedName);
        const exportName = try std.fmt.allocPrint(self.allocator, "{s}_value", .{sanitized});

        const pkgDir = try std.fs.path.join(self.allocator, &[_][]const u8{ normDir, resolvedName });
        const packageJSONPath = try std.fs.path.join(self.allocator, &[_][]const u8{ pkgDir, "package.json" });
        const packageJSONContent = try std.fmt.allocPrint(self.allocator, "{{\"name\":\"{s}\",\"types\":\"index.d.ts\"}}", .{resolvedName});
        try self.files.put(packageJSONPath, packageJSONContent);

        const declarationPath = try std.fs.path.join(self.allocator, &[_][]const u8{ pkgDir, "index.d.ts" });
        const declarationContent = try std.fmt.allocPrint(self.allocator, "export declare const {s}: number;\n", .{exportName});
        try self.files.put(declarationPath, declarationContent);

        const handle = NodeModulesPackageHandle{
            .name = resolvedName,
            .directory = pkgDir,
            .packageJSON = .{ .fileName = packageJSONPath, .content = packageJSONContent },
            .declaration = .{ .fileName = declarationPath, .content = declarationContent },
        };

        const projectRoot = tspath.getDirectoryPath(self.allocator, normDir) catch normDir;
        var record = try self.ensureProjectRecord(projectRoot);
        try record.nodeModules.append(self.allocator, handle);
        return handle;
    }

    pub fn addLocalProject(self: *FileMapBuilder, projectDir: []const u8, fileCount: usize) !void {
        const dir = try normalizeAbsolutePath(self.allocator, projectDir);
        var record = try self.ensureProjectRecord(dir);
        self.nextProjectID += 1;

        const tsConfigPath = try std.fs.path.join(self.allocator, &[_][]const u8{ dir, "tsconfig.json" });
        const tsConfigContent = "{\n  \"compilerOptions\": {\n    \"module\": \"esnext\",\n    \"target\": \"esnext\",\n    \"strict\": true,\n    \"allowJs\": true,\n    \"checkJs\": true\n  }\n}\n";
        try self.files.put(tsConfigPath, tsConfigContent);
        record.tsconfig = .{ .fileName = tsConfigPath, .content = tsConfigContent };

        for (1..fileCount + 1) |i| {
            const fileName = try std.fmt.allocPrint(self.allocator, "file{d}.ts", .{i});
            const path = try std.fs.path.join(self.allocator, &[_][]const u8{ dir, fileName });
            const exportName = try std.fmt.allocPrint(self.allocator, "localExport{d}_{d}", .{ self.nextProjectID, i });
            const content = try std.fmt.allocPrint(self.allocator, "export const {s} = {d};\n", .{ exportName, i });

            try self.files.put(path, content);
            try record.sourceFiles.append(self.allocator, .{
                .fileName = path,
                .exportIdentifier = exportName,
                .content = content,
            });
        }
    }

    pub fn addPackageJSONWithDependencies(self: *FileMapBuilder, projectDir: []const u8, deps: []NodeModulesPackageHandle) !FileHandle {
        self.nextProjectID += 1;
        const name = try std.fmt.allocPrint(self.allocator, "local-project-{d}", .{self.nextProjectID});
        return try self.addPackageJSONWithDependenciesNamed(projectDir, name, deps);
    }

    pub fn addPackageJSONWithDependenciesNamed(self: *FileMapBuilder, projectDir: []const u8, packageName: []const u8, deps: []NodeModulesPackageHandle) !FileHandle {
        const dir = try normalizeAbsolutePath(self.allocator, projectDir);
        const packageJSONPath = try std.fs.path.join(self.allocator, &[_][]const u8{ dir, "package.json" });

        var builder = std.ArrayList(u8).empty;
        var name = packageName;
        if (name.len == 0) {
            self.nextProjectID += 1;
            name = try std.fmt.allocPrint(self.allocator, "local-project-{d}", .{self.nextProjectID});
        }

        const part1 = try std.fmt.allocPrint(self.allocator, "{{\n  \"name\": \"{s}\"", .{name});
        try builder.appendSlice(self.allocator, part1);

        if (deps.len > 0) {
            try builder.appendSlice(self.allocator, ",\n  \"dependencies\": {\n    ");
            for (deps, 0..) |dep, i| {
                if (i > 0) try builder.appendSlice(self.allocator, ",\n    ");
                const dep_str = try std.fmt.allocPrint(self.allocator, "\"{s}\": \"*\"", .{dep.name});
                try builder.appendSlice(self.allocator, dep_str);
            }
            try builder.appendSlice(self.allocator, "\n  }\n");
        } else {
            try builder.appendSlice(self.allocator, "\n");
        }
        try builder.appendSlice(self.allocator, "}\n");

        const content = try builder.toOwnedSlice(self.allocator);
        try self.files.put(packageJSONPath, content);

        var record = try self.ensureProjectRecord(dir);
        const handle = FileHandle{ .fileName = packageJSONPath, .content = content };
        record.packageJSON = handle;
        record.dependencies = std.ArrayList([]const u8).empty;
        try record.dependencies.appendSlice(self.allocator, try packageNames(self.allocator, deps));
        return handle;
    }

    pub fn addRootPackageJSON(self: *FileMapBuilder, rootDir: []const u8, packageName: []const u8, deps: []NodeModulesPackageHandle) !FileHandle {
        const dir = try normalizeAbsolutePath(self.allocator, rootDir);
        const packageJSONPath = try std.fs.path.join(self.allocator, &[_][]const u8{ dir, "package.json" });

        var builder = std.ArrayList(u8).empty;
        var pkgName = packageName;
        if (pkgName.len == 0) {
            pkgName = "monorepo-root";
        }

        const p = try std.fmt.allocPrint(self.allocator, "{{\n  \"name\": \"{s}\",\n  \"private\": true", .{pkgName});
        try builder.appendSlice(self.allocator, p);

        if (deps.len > 0) {
            try builder.appendSlice(self.allocator, ",\n  \"dependencies\": {\n    ");
            for (deps, 0..) |dep, i| {
                if (i > 0) try builder.appendSlice(self.allocator, ",\n    ");
                const dep_str = try std.fmt.allocPrint(self.allocator, "\"{s}\": \"*\"", .{dep.name});
                try builder.appendSlice(self.allocator, dep_str);
            }
            try builder.appendSlice(self.allocator, "\n  }\n");
        } else {
            try builder.appendSlice(self.allocator, "\n");
        }
        try builder.appendSlice(self.allocator, "}\n");

        const content = try builder.toOwnedSlice(self.allocator);
        try self.files.put(packageJSONPath, content);
        return FileHandle{ .fileName = packageJSONPath, .content = content };
    }
};

fn selectPackagesByName(allocator: std.mem.Allocator, available: []NodeModulesPackageHandle, names: []const []const u8) ![]NodeModulesPackageHandle {
    if (names.len == 0) return try allocator.dupe(NodeModulesPackageHandle, available);
    var result = std.ArrayList(NodeModulesPackageHandle).empty;
    for (names) |name| {
        var found = false;
        for (available) |candidate| {
            if (std.mem.eql(u8, candidate.name, name)) {
                try result.append(allocator, candidate);
                found = true;
                break;
            }
        }
        if (!found) {
            return error.DependencyNotFound;
        }
    }
    return result.toOwnedSlice(allocator);
}

fn packageNames(allocator: std.mem.Allocator, deps: []NodeModulesPackageHandle) ![][]const u8 {
    if (deps.len == 0) return &[_][]const u8{};
    var names = std.ArrayList([]const u8).empty;
    for (deps) |dep| {
        try names.append(allocator, dep.name);
    }
    return names.toOwnedSlice(allocator);
}

fn sanitizeIdentifier(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    var sanitized = std.ArrayList(u8).empty;
    for (name) |c| {
        if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9')) {
            try sanitized.append(allocator, c);
        } else if (c == '_' or c == '-') {
            try sanitized.append(allocator, '_');
        }
    }
    if (sanitized.items.len == 0) {
        return "pkg";
    }
    return sanitized.toOwnedSlice(allocator);
}

fn normalizeAbsolutePath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const normalized = try tspath.normalizePath(allocator, path);
    if (!tspath.pathIsAbsolute(normalized)) {
        return error.PathNotAbsolute;
    }
    return normalized;
}
