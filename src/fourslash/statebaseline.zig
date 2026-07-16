const std = @import("std");

pub const ProjectInfo = *anyopaque;

pub const StateBaseline = struct {
    baseline: std.ArrayList(u8),
    fsDiffer: *anyopaque, // pointer to fsbaselineutil.FSDiffer
    isInitialized: bool,

    serializedProjects: std.StringHashMap(ProjectInfo),
    serializedOpenFiles: std.StringHashMap(*OpenFileInfo),
    serializedConfigFileRegistry: ?*anyopaque,

    pub fn deinit(self: *StateBaseline, allocator: std.mem.Allocator) void {
        self.baseline.deinit();
        self.serializedProjects.deinit();
        
        var it = self.serializedOpenFiles.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.allProjects.deinit();
            allocator.destroy(entry.value_ptr.*);
        }
        self.serializedOpenFiles.deinit();
    }
};

pub fn newStateBaseline(allocator: std.mem.Allocator, fsFromMap: anytype) !*StateBaseline {
    const self = try allocator.create(StateBaseline);
    errdefer allocator.destroy(self);

    self.baseline = std.ArrayList(u8).init(allocator);
    const FSDiffer = @import("../testutil/fsbaselineutil/differ.zig").FSDiffer;
    self.fsDiffer = FSDiffer.init(allocator, fsFromMap);
    self.isInitialized = false;
    self.serializedProjects = std.StringHashMap(ProjectInfo).init(allocator);
    self.serializedOpenFiles = std.StringHashMap(*OpenFileInfo).init(allocator);
    self.serializedConfigFileRegistry = null;

    try std.fmt.format(self.baseline.writer(), "UseCaseSensitiveFileNames: {}\n", .{fsFromMap.useCaseSensitiveFileNames()});
    // try self.fsDiffer.baselineFsWithDiff(self.baseline.writer());
    
    return self;
}

pub const OpenFileInfo = struct {
    defaultProjectName: []const u8,
    allProjects: std.ArrayList([]const u8),
};

pub const RequestOrMessage = struct {
    method: []const u8,
    params: std.json.Value,
};

pub const DiffTableOptions = struct {
    indent: []const u8,
    sortKeys: bool,
};

pub const DiffTable = struct {
    diff: std.StringHashMap([]const u8),
    options: DiffTableOptions,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, options: DiffTableOptions) DiffTable {
        return .{
            .diff = std.StringHashMap([]const u8).init(allocator),
            .options = options,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DiffTable) void {
        self.diff.deinit();
    }

    pub fn add(self: *DiffTable, key: []const u8, value: []const u8) !void {
        try self.diff.put(key, value);
    }

    pub fn print(self: *DiffTable, writer: anytype, header: []const u8) !void {
        const count = self.diff.count();
        if (count == 0) return;

        if (header.len > 0) {
            try std.fmt.format(writer, "{s}{s}\n", .{ self.options.indent, header });
        }

        var diffKeys = try std.ArrayList([]const u8).initCapacity(self.allocator, count);
        defer diffKeys.deinit();

        var keyWidth: usize = 0;
        var it = self.diff.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            if (key.len > keyWidth) {
                keyWidth = key.len;
            }
            try diffKeys.append(key);
        }

        if (self.options.sortKeys) {
            std.mem.sort([]const u8, diffKeys.items, {}, stringLessThan);
        }

        for (diffKeys.items) |key| {
            const value = self.diff.get(key) orelse "";
            try std.fmt.format(writer, "{s}{s}", .{ self.options.indent, key });
            var spaces = keyWidth + 1 - key.len;
            while (spaces > 0) : (spaces -= 1) {
                try writer.writeByte(' ');
            }
            try std.fmt.format(writer, " {s}\n", .{value});
        }
    }
};

pub const DiffTableWriter = struct {
    hasChange: bool,
    header: []const u8,
    diffs: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, header: []const u8) DiffTableWriter {
        return .{
            .hasChange = false,
            .header = header,
            .diffs = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DiffTableWriter) void {
        var it = self.diffs.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.diffs.deinit();
    }

    pub fn setHasChange(self: *DiffTableWriter) void {
        self.hasChange = true;
    }

    pub fn add(self: *DiffTableWriter, key: []const u8, output: []const u8) !void {
        try self.diffs.put(key, output);
    }

    pub fn print(self: *DiffTableWriter, writer: anytype) !void {
        if (self.hasChange) {
            try std.fmt.format(writer, "{s}::\n", .{self.header});
            var keys = try std.ArrayList([]const u8).initCapacity(self.allocator, self.diffs.count());
            defer keys.deinit();

            var it = self.diffs.iterator();
            while (it.next()) |entry| {
                try keys.append(entry.key_ptr.*);
            }

            std.mem.sort([]const u8, keys.items, {}, stringLessThan);

            for (keys.items) |key| {
                const out = self.diffs.get(key).?;
                try writer.writeAll(out);
            }
        }
    }
};

fn stringLessThan(context: void, a: []const u8, b: []const u8) bool {
    _ = context;
    return std.mem.order(u8, a, b) == .lt;
}

pub fn isLibFile(fileName: []const u8) bool {
    return std.mem.startsWith(u8, std.fs.path.basename(fileName), "lib.");
}

pub fn sliceFromIterSeqPath(allocator: std.mem.Allocator, seq: anytype) ![][]const u8 {
    var result = std.ArrayList([]const u8).init(allocator);
    var it = seq;
    while (it.next()) |path| {
        try result.append(path);
    }
    std.mem.sort([]const u8, result.items, {}, stringLessThan);
    return result.toOwnedSlice();
}

pub fn areIterSeqEqual(allocator: std.mem.Allocator, a: anytype, b: anytype) !bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;

    var aSlice = try sliceFromIterSeqPath(allocator, a);
    defer allocator.free(aSlice);
    var bSlice = try sliceFromIterSeqPath(allocator, b);
    defer allocator.free(bSlice);

    if (aSlice.len != bSlice.len) return false;
    for (aSlice, 0..) |item, i| {
        if (!std.mem.eql(u8, item, bSlice[i])) return false;
    }
    return true;
}

pub fn printSlicesWithDiffTable(
    allocator: std.mem.Allocator,
    writer: anytype,
    header: []const u8,
    newSlice: []const []const u8,
    oldSlice: ?[]const []const u8,
    options: DiffTableOptions,
    topChange: []const u8,
    isDefaultCtx: ?*const anyopaque,
    isDefaultFn: ?*const fn (ctx: ?*const anyopaque, entry: []const u8) bool,
) !void {
    var table = DiffTable.init(allocator, options);
    defer table.deinit();

    for (newSlice) |entry| {
        var entryChange: []const u8 = "";
        if (isDefaultFn) |f| {
            if (f(isDefaultCtx, entry)) {
                entryChange = "(default) ";
            }
        }
        if (std.mem.eql(u8, topChange, "*modified*")) {
            if (oldSlice) |old| {
                if (!containsString(old, entry)) {
                    entryChange = "*new*";
                }
            }
        }
        try table.add(entry, entryChange);
    }

    if (std.mem.eql(u8, topChange, "*modified*")) {
        if (oldSlice) |old| {
            for (old) |entry| {
                if (!containsString(newSlice, entry)) {
                    try table.add(entry, "*deleted*");
                }
            }
        }
    }
    try table.print(writer, header);
}

fn containsString(slice: []const []const u8, str: []const u8) bool {
    for (slice) |item| {
        if (std.mem.eql(u8, item, str)) return true;
    }
    return false;
}

pub fn printPathIterSeqWithDiffTable(
    allocator: std.mem.Allocator,
    writer: anytype,
    header: []const u8,
    newIterSeq: anytype,
    oldIterSeq: anytype,
    options: DiffTableOptions,
    topChange: []const u8,
) !void {
    var newSlice: [][]const u8 = &[_][]const u8{};
    if (newIterSeq != null) {
        newSlice = try sliceFromIterSeqPath(allocator, newIterSeq);
    }
    defer if (newIterSeq != null) allocator.free(newSlice);

    var oldSlice: ?[][]const u8 = null;
    if (std.mem.eql(u8, topChange, "*modified*") and oldIterSeq != null) {
        oldSlice = try sliceFromIterSeqPath(allocator, oldIterSeq);
    }
    defer if (oldSlice) |old| allocator.free(old);

    try printSlicesWithDiffTable(allocator, writer, header, newSlice, if (oldSlice) |old| old else null, options, topChange, null, null);
}

pub fn baselineRequestOrNotification(f: anytype, method: []const u8, params: std.json.Value) !void {
    if (!f.testData.isStateBaseliningEnabled()) return;

    const req = RequestOrMessage{
        .method = method,
        .params = params,
    };

    var res = std.ArrayList(u8).init(f.allocator);
    defer res.deinit();
    try std.json.stringify(req, .{ .whitespace = .indent_2 }, res.writer());

    try f.stateBaseline.baseline.append('\n');
    try f.stateBaseline.baseline.appendSlice(res.items);
    try f.stateBaseline.baseline.append('\n');
    f.stateBaseline.isInitialized = true;
}

pub fn baselineProjectsAfterNotification(f: anytype, fileName: []const u8) !void {
    if (!f.testData.isStateBaseliningEnabled()) return;
    _ = fileName;
    
    // Simulate lsptestutil.SendRequest
    try f.baselineState();
}

pub fn baselineState(f: anytype) !void {
    if (!f.testData.isStateBaseliningEnabled()) return;

    const serialized = try f.serializedState(f.allocator);
    defer f.allocator.free(serialized);

    if (serialized.len > 0) {
        try f.stateBaseline.baseline.append('\n');
        try f.stateBaseline.baseline.appendSlice(serialized);
    }
}

pub fn serializedState(f: anytype, allocator: std.mem.Allocator) ![]const u8 {
    var builder = std.ArrayList(u8).init(allocator);
    
    // f.stateBaseline.fsDiffer.baselineFsWithDiff(builder.writer())
    
    if (std.mem.trim(u8, builder.items, " \t\r\n").len == 0) {
        builder.clearRetainingCapacity();
    }

    try f.printStateDiff(builder.writer());
    return builder.toOwnedSlice();
}

pub fn printStateDiff(f: anytype, writer: anytype) !void {
    if (!f.stateBaseline.isInitialized) return;
    
    const session = f.client.server.session();
    const snapshot = session.snapshot();

    try printProjectsDiff(f, snapshot, writer);
    try printOpenFilesDiff(f, snapshot, writer);
    try printConfigFileRegistryDiff(f, snapshot, writer);
}

pub fn printProjectsDiff(f: anytype, snapshot: anytype, writer: anytype) !void {
    var currentProjects = std.StringHashMap(ProjectInfo).init(f.allocator);
    const options = DiffTableOptions{ .indent = "  ", .sortKeys = false };
    var projectsDiffTable = DiffTableWriter.init(f.allocator, "Projects");
    defer projectsDiffTable.deinit();

    var projectIter = snapshot.projectCollection.projects();
    while (projectIter.next()) |proj| {
        const program = proj.getProgram();
        var oldProgram: ?ProjectInfo = null;
        try currentProjects.put(proj.name(), program);
        
        var projectChange: []const u8 = "";
        if (f.stateBaseline.serializedProjects.get(proj.name())) |existing| {
            oldProgram = existing;
            if (oldProgram != program) {
                projectChange = "*modified*";
                projectsDiffTable.setHasChange();
            } else {
                projectChange = "";
            }
        } else {
            projectChange = "*new*";
            projectsDiffTable.setHasChange();
        }

        var buf = std.ArrayList(u8).init(f.allocator);
        const bufWriter = buf.writer();

        try std.fmt.format(bufWriter, "  [{s}] {s}\n", .{ proj.name(), projectChange });
        var subDiff = DiffTable.init(f.allocator, options);
        defer subDiff.deinit();

        if (program != null) {
            var fileIter = proj.getSourceFiles(); 
            while (fileIter.next()) |file| {
                var fileDiff: []const u8 = "";
                const fileName = file.fileName();
                if (std.mem.eql(u8, projectChange, "*modified*")) {
                    if (oldProgram == null) {
                        if (!isLibFile(fileName)) {
                            fileDiff = "*new*";
                        }
                    } else if (f.getSourceFileByPath(oldProgram.?, file.path()) == null) {
                        fileDiff = "*new*";
                    } else if (f.getSourceFileByPath(oldProgram.?, file.path()) != file) { 
                        fileDiff = "*modified*";
                    }
                }
                if (fileDiff.len > 0 or !isLibFile(fileName)) {
                    try subDiff.add(fileName, fileDiff);
                }
            }
        }

        if (oldProgram != program and oldProgram != null) {
            var fileIter = f.getSourceFiles(oldProgram.?);
            while (fileIter.next()) |file| {
                if (program == null or f.getSourceFileByPath(program, file.path()) == null) {
                    try subDiff.add(file.fileName(), "*deleted*");
                }
            }
        }
        try subDiff.print(bufWriter, "");
        try projectsDiffTable.add(proj.name(), try buf.toOwnedSlice());
    }

    var oldProjIter = f.stateBaseline.serializedProjects.iterator();
    while (oldProjIter.next()) |entry| {
        const projectName = entry.key_ptr.*;
        const info = entry.value_ptr.*;
        if (!currentProjects.contains(projectName)) {
            projectsDiffTable.setHasChange();
            
            var buf = std.ArrayList(u8).init(f.allocator);
            const bufWriter = buf.writer();

            try std.fmt.format(bufWriter, "  [{s}] *deleted*\n", .{projectName});
            var subDiff = DiffTable.init(f.allocator, options);
            defer subDiff.deinit();

            if (info != null) {
                var fileIter = f.getSourceFiles(info);
                while (fileIter.next()) |file| {
                    if (!isLibFile(file.fileName())) {
                        try subDiff.add(file.fileName(), "");
                    }
                }
            }
            try subDiff.print(bufWriter, "");
            try projectsDiffTable.add(projectName, try buf.toOwnedSlice());
        }
    }

    f.stateBaseline.serializedProjects.deinit();
    f.stateBaseline.serializedProjects = currentProjects;

    try projectsDiffTable.print(writer);
}

pub fn printOpenFilesDiff(f: anytype, snapshot: anytype, writer: anytype) !void {
    var currentOpenFiles = std.StringHashMap(*OpenFileInfo).init(f.allocator);
    var filesDiffTable = DiffTableWriter.init(f.allocator, "Open Files");
    defer filesDiffTable.deinit();
    
    const options = DiffTableOptions{ .indent = "  ", .sortKeys = true };

    var openFilesIter = f.openFiles.iterator();
    while (openFilesIter.next()) |entry| {
        const fileName = entry.key_ptr.*;
        const path = f.toPath(fileName);
        const defaultProject = snapshot.projectCollection.getDefaultProject(path);
        
        var newFileInfo = try f.allocator.create(OpenFileInfo);
        newFileInfo.defaultProjectName = if (defaultProject != null) defaultProject.?.name() else "";
        newFileInfo.allProjects = std.ArrayList([]const u8).init(f.allocator);
        
        var projectIter = snapshot.projectCollection.projects();
        while (projectIter.next()) |proj| {
            if (proj.getProgram()) |prog| {
                if (f.getSourceFileByPath(prog, path) != null) {
                    try newFileInfo.allProjects.append(proj.name());
                }
            }
        }
        
        std.mem.sort([]const u8, newFileInfo.allProjects.items, {}, stringLessThan);
        try currentOpenFiles.put(fileName, newFileInfo);

        var openFileChange: []const u8 = "";
        var oldFileInfo: ?*OpenFileInfo = null;
        
        if (f.stateBaseline.serializedOpenFiles.get(fileName)) |existing| {
            oldFileInfo = existing;
            if (!std.mem.eql(u8, existing.defaultProjectName, newFileInfo.defaultProjectName) or
                !stringSliceEql(existing.allProjects.items, newFileInfo.allProjects.items)) {
                openFileChange = "*modified*";
                filesDiffTable.setHasChange();
            } else {
                openFileChange = "";
            }
        } else {
            openFileChange = "*new*";
            filesDiffTable.setHasChange();
        }

        var buf = std.ArrayList(u8).init(f.allocator);
        const bufWriter = buf.writer();

        try std.fmt.format(bufWriter, "  [{s}] {s}\n", .{ fileName, openFileChange });
        
        const IsDefCtx = struct {
            defName: []const u8,
            pub fn check(ctx: ?*const anyopaque, entryStr: []const u8) bool {
                const c = @as(*const @This(), @ptrCast(@alignCast(ctx.?)));
                return std.mem.eql(u8, c.defName, entryStr);
            }
        };
        const ctx_obj = IsDefCtx{ .defName = newFileInfo.defaultProjectName };
        
        try printSlicesWithDiffTable(
            f.allocator,
            bufWriter,
            "",
            newFileInfo.allProjects.items,
            if (oldFileInfo) |old| old.allProjects.items else null,
            options,
            openFileChange,
            &ctx_obj,
            IsDefCtx.check,
        );

        try filesDiffTable.add(fileName, try buf.toOwnedSlice());
    }

    var oldFilesIter = f.stateBaseline.serializedOpenFiles.iterator();
    while (oldFilesIter.next()) |entry| {
        const fileName = entry.key_ptr.*;
        if (!currentOpenFiles.contains(fileName)) {
            filesDiffTable.setHasChange();
            
            var buf = std.ArrayList(u8).init(f.allocator);
            try std.fmt.format(buf.writer(), "  [{s}] *closed*\n", .{fileName});
            
            try filesDiffTable.add(fileName, try buf.toOwnedSlice());
        }
    }

    f.stateBaseline.serializedOpenFiles.deinit();
    f.stateBaseline.serializedOpenFiles = currentOpenFiles;

    try filesDiffTable.print(writer);
}

fn stringSliceEql(a: []const []const u8, b: []const []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |item, i| {
        if (!std.mem.eql(u8, item, b[i])) return false;
    }
    return true;
}

pub fn printConfigFileRegistryDiff(f: anytype, snapshot: anytype, writer: anytype) !void {
    const configFileRegistry = snapshot.projectCollection.configFileRegistry();

    var configDiffsTable = DiffTableWriter.init(f.allocator, "Config");
    defer configDiffsTable.deinit();
    
    var configFileNamesDiffsTable = DiffTableWriter.init(f.allocator, "Config File Names");
    defer configFileNamesDiffsTable.deinit();

    if (f.stateBaseline.serializedConfigFileRegistry == configFileRegistry) {
        return;
    }

    const options = DiffTableOptions{ .indent = "    ", .sortKeys = true };

    if (configFileRegistry != null) {
        var configEntriesIter = configFileRegistry.?.forEachTestConfigEntry();
        while (configEntriesIter.next()) |entryPair| {
            const path = entryPair.key;
            const entry = entryPair.value;
            
            var configChange: []const u8 = "";
            const oldEntry = if (f.stateBaseline.serializedConfigFileRegistry != null) 
                f.stateBaseline.serializedConfigFileRegistry.?.getTestConfigEntry(path) 
                else null;
            
            if (oldEntry == null) {
                configChange = "*new*";
                configDiffsTable.setHasChange();
            } else if (oldEntry.? != entry) {
                if (!try areIterSeqEqual(f.allocator, oldEntry.?.retainingProjects(), entry.retainingProjects()) or
                    !try areIterSeqEqual(f.allocator, oldEntry.?.retainingOpenFiles(), entry.retainingOpenFiles()) or
                    !try areIterSeqEqual(f.allocator, oldEntry.?.retainingConfigs(), entry.retainingConfigs())) {
                    configChange = "*modified*";
                    configDiffsTable.setHasChange();
                }
            }

            var buf = std.ArrayList(u8).init(f.allocator);
            const bufWriter = buf.writer();

            try std.fmt.format(bufWriter, "  [{s}] {s}\n", .{ entry.fileName(), configChange });
            
            var retainingProjectsModified: []const u8 = "";
            var retainingOpenFilesModified: []const u8 = "";
            var retainingConfigsModified: []const u8 = "";
            
            if (std.mem.eql(u8, configChange, "*modified*")) {
                if (!try areIterSeqEqual(f.allocator, entry.retainingProjects(), oldEntry.?.retainingProjects())) {
                    retainingProjectsModified = " *modified*";
                }
                if (!try areIterSeqEqual(f.allocator, entry.retainingOpenFiles(), oldEntry.?.retainingOpenFiles())) {
                    retainingOpenFilesModified = " *modified*";
                }
                if (!try areIterSeqEqual(f.allocator, entry.retainingConfigs(), oldEntry.?.retainingConfigs())) {
                    retainingConfigsModified = " *modified*";
                }
            }

            var headerBuf = std.ArrayList(u8).init(f.allocator);
            defer headerBuf.deinit();

            try headerBuf.writer().print("RetainingProjects:{s}", .{retainingProjectsModified});
            try printPathIterSeqWithDiffTable(f.allocator, bufWriter, headerBuf.items, entry.retainingProjects(), if (oldEntry != null) oldEntry.?.retainingProjects() else null, options, configChange);
            headerBuf.clearRetainingCapacity();

            try headerBuf.writer().print("RetainingOpenFiles:{s}", .{retainingOpenFilesModified});
            try printPathIterSeqWithDiffTable(f.allocator, bufWriter, headerBuf.items, entry.retainingOpenFiles(), if (oldEntry != null) oldEntry.?.retainingOpenFiles() else null, options, configChange);
            headerBuf.clearRetainingCapacity();

            try headerBuf.writer().print("RetainingConfigs:{s}", .{retainingConfigsModified});
            try printPathIterSeqWithDiffTable(f.allocator, bufWriter, headerBuf.items, entry.retainingConfigs(), if (oldEntry != null) oldEntry.?.retainingConfigs() else null, options, configChange);
            
            try configDiffsTable.add(path, try buf.toOwnedSlice());
        }

        var configFileNameEntriesIter = configFileRegistry.?.forEachTestConfigFileNamesEntry();
        while (configFileNameEntriesIter.next()) |entryPair| {
            const path = entryPair.key;
            const entry = entryPair.value;

            var configFileNamesChange: []const u8 = "";
            const oldEntry = if (f.stateBaseline.serializedConfigFileRegistry != null) 
                f.stateBaseline.serializedConfigFileRegistry.?.getTestConfigFileNamesEntry(path) 
                else null;
            
            if (oldEntry == null) {
                configFileNamesChange = "*new*";
                configFileNamesDiffsTable.setHasChange();
            } else if (!std.mem.eql(u8, oldEntry.?.nearestConfigFileName(), entry.nearestConfigFileName()) or
                !stringMapEql(oldEntry.?.ancestors(), entry.ancestors())) {
                configFileNamesChange = "*modified*";
                configFileNamesDiffsTable.setHasChange();
            }

            var buf = std.ArrayList(u8).init(f.allocator);
            const bufWriter = buf.writer();

            try std.fmt.format(bufWriter, "  [{s}] {s}\n", .{ path, configFileNamesChange });

            var nearestConfigFileNameModified: []const u8 = "";
            var ancestorDiffModified: []const u8 = "";
            if (std.mem.eql(u8, configFileNamesChange, "*modified*")) {
                if (!std.mem.eql(u8, oldEntry.?.nearestConfigFileName(), entry.nearestConfigFileName())) {
                    nearestConfigFileNameModified = " *modified*";
                }
                if (!stringMapEql(oldEntry.?.ancestors(), entry.ancestors())) {
                    ancestorDiffModified = " *modified*";
                }
            }

            try std.fmt.format(bufWriter, "    NearestConfigFileName: {s}{s}\n", .{ entry.nearestConfigFileName(), nearestConfigFileNameModified });

            var ancestorDiff = DiffTable.init(f.allocator, options);
            defer ancestorDiff.deinit();

            var ancestorsIter = entry.ancestors().iterator();
            while (ancestorsIter.next()) |anc| {
                const config = anc.key_ptr.*;
                const ancestorOfConfig = anc.value_ptr.*;
                var ancestorChange: []const u8 = "";
                
                if (std.mem.eql(u8, configFileNamesChange, "*modified*")) {
                    if (oldEntry.?.ancestors().get(config)) |oldConfigFileName| {
                        if (!std.mem.eql(u8, oldConfigFileName, ancestorOfConfig)) {
                            ancestorChange = "*modified*";
                        }
                    } else {
                        ancestorChange = "*new*";
                    }
                }
                
                const valStr = try std.fmt.allocPrint(f.allocator, "{s} {s}", .{ ancestorOfConfig, ancestorChange });
                try ancestorDiff.add(config, valStr);
            }

            if (std.mem.eql(u8, configFileNamesChange, "*modified*")) {
                var oldAncestorsIter = oldEntry.?.ancestors().iterator();
                while (oldAncestorsIter.next()) |anc| {
                    const ancestorPath = anc.key_ptr.*;
                    const oldConfigFileName = anc.value_ptr.*;
                    if (!entry.ancestors().contains(ancestorPath)) {
                        const valStr = try std.fmt.allocPrint(f.allocator, "{s} *deleted*", .{oldConfigFileName});
                        try ancestorDiff.add(ancestorPath, valStr);
                    }
                }
            }

            var headerBuf = std.ArrayList(u8).init(f.allocator);
            defer headerBuf.deinit();
            try headerBuf.writer().print("Ancestors:{s}", .{ancestorDiffModified});
            try ancestorDiff.print(bufWriter, headerBuf.items);

            var it = ancestorDiff.diff.iterator();
            while (it.next()) |item| {
                f.allocator.free(item.value_ptr.*);
            }

            try configFileNamesDiffsTable.add(path, try buf.toOwnedSlice());
        }
    }

    if (f.stateBaseline.serializedConfigFileRegistry != null) {
        var oldConfigEntriesIter = f.stateBaseline.serializedConfigFileRegistry.?.forEachTestConfigEntry();
        while (oldConfigEntriesIter.next()) |entryPair| {
            const path = entryPair.key;
            const entry = entryPair.value;
            if (configFileRegistry == null or configFileRegistry.?.getTestConfigEntry(path) == null) {
                configDiffsTable.setHasChange();
                
                var buf = std.ArrayList(u8).init(f.allocator);
                try std.fmt.format(buf.writer(), "  [{s}] *deleted*\n", .{entry.fileName()});
                try configDiffsTable.add(path, try buf.toOwnedSlice());
            }
        }

        var oldConfigFileNameEntriesIter = f.stateBaseline.serializedConfigFileRegistry.?.forEachTestConfigFileNamesEntry();
        while (oldConfigFileNameEntriesIter.next()) |entryPair| {
            const path = entryPair.key;
            if (configFileRegistry == null or configFileRegistry.?.getTestConfigFileNamesEntry(path) == null) {
                configFileNamesDiffsTable.setHasChange();
                
                var buf = std.ArrayList(u8).init(f.allocator);
                try std.fmt.format(buf.writer(), "  [{s}] *deleted*\n", .{path});
                try configFileNamesDiffsTable.add(path, try buf.toOwnedSlice());
            }
        }
    }

    f.stateBaseline.serializedConfigFileRegistry = configFileRegistry;

    try configDiffsTable.print(writer);
    try configFileNamesDiffsTable.print(writer);
}

fn stringMapEql(a: anytype, b: anytype) bool {
    if (a.count() != b.count()) return false;
    var it = a.iterator();
    while (it.next()) |entry| {
        if (b.get(entry.key_ptr.*)) |b_val| {
            if (!std.mem.eql(u8, entry.value_ptr.*, b_val)) return false;
        } else {
            return false;
        }
    }
    return true;
}
