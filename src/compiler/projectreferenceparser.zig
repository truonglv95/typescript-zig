const std = @import("std");
const collections = @import("../collections/collections.zig");
const core = @import("../core/core.zig");
const tracing = @import("../tracing/tracing.zig");
const tsoptions = @import("../tsoptions/tsoptions.zig");
const tspath = @import("../tspath/tspath.zig");
const fileloader = @import("fileloader.zig");

pub const ProjectReferenceParseTask = struct {
    configName: []const u8,
    resolved: ?*tsoptions.ParsedCommandLine = null,
    subTasks: []*ProjectReferenceParseTask = &[_]*ProjectReferenceParseTask{},

    pub fn parse(self: *ProjectReferenceParseTask, parser: *ProjectReferenceParser) void {
        var loader = parser.loader;
        if (loader.opts.tracing) |tr| {
            // Placeholder: tr.Push(tracing.PhaseParse, "parseJsonSourceFileConfigFileContent", map[string]any{"path": self.configName}, false)
            _ = tr;
        }
        
        self.resolved = loader.opts.host.getResolvedProjectReference(self.configName, loader.toPath(self.configName));
        if (self.resolved == null) {
            return;
        }
        
        self.resolved.?.parseInputOutputNames();
        const subReferences = self.resolved.?.resolvedProjectReferencePaths();
        if (subReferences.len > 0) {
            self.subTasks = createProjectReferenceParseTasks(parser.allocator, subReferences);
        }
    }
};

pub fn createProjectReferenceParseTasks(allocator: std.mem.Allocator, projectReferences: [][]const u8) []*ProjectReferenceParseTask {
    var tasks = allocator.alloc(*ProjectReferenceParseTask, projectReferences.len) catch unreachable;
    for (projectReferences, 0..) |ref, i| {
        var task = allocator.create(ProjectReferenceParseTask) catch unreachable;
        task.* = ProjectReferenceParseTask{
            .configName = ref,
        };
        tasks[i] = task;
    }
    return tasks;
}

pub const ProjectReferenceParser = struct {
    allocator: std.mem.Allocator,
    loader: *fileloader.FileLoader,
    wg: core.WorkGroup,
    tasksByFileName: collections.SyncMap(tspath.Path, *ProjectReferenceParseTask),

    pub fn init(allocator: std.mem.Allocator, loader: *fileloader.FileLoader) ProjectReferenceParser {
        return .{
            .allocator = allocator,
            .loader = loader,
            .wg = core.WorkGroup.init(allocator),
            .tasksByFileName = collections.SyncMap(tspath.Path, *ProjectReferenceParseTask).init(),
        };
    }

    pub fn deinit(self: *ProjectReferenceParser) void {
        self.wg.deinit();
    }

    pub fn parse(self: *ProjectReferenceParser, tasks: []*ProjectReferenceParseTask) void {
        self.loader.projectReferenceFileMapper.loader = self.loader;
        self.start(tasks);
        self.wg.runAndWait();
        self.initMapper(tasks);
    }

    pub fn start(self: *ProjectReferenceParser, tasks: []*ProjectReferenceParseTask) void {
        for (tasks, 0..) |task, i| {
            const path = self.loader.toPath(task.configName);
            const loadOrStoreResult = self.tasksByFileName.loadOrStore(path, task);
            if (loadOrStoreResult.loaded) {
                // dedup tasks to ensure correct file order, regardless of which task would be started first
                tasks[i] = loadOrStoreResult.value_or_loaded;
            } else {
                // For Zig equivalent we can queue a closure/struct
                // Here we just use a helper method to represent it.
                self.wg.queue(.{
                    .parser = self,
                    .task = task,
                });
            }
        }
    }

    pub fn initMapper(self: *ProjectReferenceParser, tasks: []*ProjectReferenceParseTask) void {
        const totalReferences = self.tasksByFileName.size() + 1;
        
        self.loader.projectReferenceFileMapper.configToProjectReference = std.AutoHashMap(tspath.Path, *tsoptions.ParsedCommandLine).init(self.allocator);
        self.loader.projectReferenceFileMapper.configToProjectReference.ensureTotalCapacity(totalReferences) catch unreachable;

        self.loader.projectReferenceFileMapper.referencesInConfigFile = std.AutoHashMap(tspath.Path, []tspath.Path).init(self.allocator);
        self.loader.projectReferenceFileMapper.referencesInConfigFile.ensureTotalCapacity(totalReferences) catch unreachable;

        self.loader.projectReferenceFileMapper.sourceToProjectReference = std.AutoHashMap(tspath.Path, *tsoptions.SourceOutputAndProjectReference).init(self.allocator);
        self.loader.projectReferenceFileMapper.outputDtsToProjectReference = std.AutoHashMap(tspath.Path, *tsoptions.SourceOutputAndProjectReference).init(self.allocator);

        var seen = collections.Set(*ProjectReferenceParseTask).init(self.allocator);
        defer seen.deinit();

        const configPath = self.loader.opts.config.configFile.sourceFile.path();
        self.loader.projectReferenceFileMapper.referencesInConfigFile.put(configPath, self.initMapperWorker(tasks, &seen)) catch unreachable;

        if (self.loader.projectReferenceFileMapper.opts.canUseProjectReferenceSource() and self.loader.projectReferenceFileMapper.outputDtsToProjectReference.count() != 0) {
            self.loader.projectReferenceFileMapper.host = fileloader.newProjectReferenceDtsFakingHost(self.loader);
        }
    }

    pub fn initMapperWorker(self: *ProjectReferenceParser, tasks: []*ProjectReferenceParseTask, seen: *collections.Set(*ProjectReferenceParseTask)) []tspath.Path {
        if (tasks.len == 0) {
            return &[_]tspath.Path{};
        }
        
        var results = std.ArrayList(tspath.Path).init(self.allocator);
        for (tasks) |task| {
            const path = self.loader.toPath(task.configName);
            results.append(path) catch unreachable;
            
            // ensure we only walk each task once
            if (!seen.addIfAbsent(task)) {
                continue;
            }
            
            self.loader.projectReferenceFileMapper.configToProjectReference.put(path, task.resolved) catch unreachable;
            
            if (task.resolved != null and self.loader.projectReferenceFileMapper.opts.config.configFile != task.resolved.?.configFile) {
                // Copy maps
                var it = task.resolved.?.sourceToProjectReference().iterator();
                while (it.next()) |entry| {
                    self.loader.projectReferenceFileMapper.sourceToProjectReference.put(entry.key_ptr.*, entry.value_ptr.*) catch unreachable;
                }

                var it2 = task.resolved.?.outputDtsToProjectReference().iterator();
                while (it2.next()) |entry| {
                    self.loader.projectReferenceFileMapper.outputDtsToProjectReference.put(entry.key_ptr.*, entry.value_ptr.*) catch unreachable;
                }
                
                if (self.loader.projectReferenceFileMapper.opts.canUseProjectReferenceSource()) {
                    var declDir = task.resolved.?.compilerOptions().declarationDir;
                    if (declDir.len == 0) {
                        declDir = task.resolved.?.compilerOptions().outDir;
                    }
                    if (declDir.len != 0) {
                        self.loader.dtsDirectories.add(self.loader.toPath(declDir)) catch unreachable;
                    }
                }
            }
            
            const referencesInConfig = self.initMapperWorker(task.subTasks, seen);
            self.loader.projectReferenceFileMapper.referencesInConfigFile.put(path, referencesInConfig) catch unreachable;
        }
        return results.toOwnedSlice() catch unreachable;
    }
};
