const std = @import("std");
const collections = @import("../collections/collections.zig");
const core = @import("../core/core.zig");
const tspath = @import("../tspath/tspath.zig");
const project = @import("project.zig");

pub const ConfigFileRegistry = opaque {};

pub const ProjectCollection = struct {
    configFileRegistry: ?*ConfigFileRegistry = null,

    fileDefaultProjects: std.StringArrayHashMap(tspath.Path),
    configuredProjects: std.StringArrayHashMap(*project.Project),
    openFiles: std.StringArrayHashMap(void),
    
    inferredProject: ?*project.Project = null,
    apiOpenedProjects: std.StringArrayHashMap(void),

    openConfiguredProjectsOnce: std.once_cell.Once = .{},
    openConfiguredProjects: ?*std.StringArrayHashMap(void) = null,

    pub fn init(allocator: std.mem.Allocator) ProjectCollection {
        return .{
            .fileDefaultProjects = std.StringArrayHashMap(tspath.Path).init(allocator),
            .configuredProjects = std.StringArrayHashMap(*project.Project).init(allocator),
            .openFiles = std.StringArrayHashMap(void).init(allocator),
            .apiOpenedProjects = std.StringArrayHashMap(void).init(allocator),
        };
    }

    pub fn getConfigFileRegistry(self: *ProjectCollection) ?*ConfigFileRegistry {
        return self.configFileRegistry;
    }

    pub fn configuredProject(self: *ProjectCollection, path: tspath.Path) ?*project.Project {
        return self.configuredProjects.get(path);
    }

    pub fn getProjectByPath(self: *ProjectCollection, projectPath: tspath.Path) ?*project.Project {
        if (self.configuredProjects.get(projectPath)) |p| return p;
        if (std.mem.eql(u8, projectPath, project.inferredProjectName)) return self.inferredProject;
        return null;
    }

    pub fn configuredProjectsList(self: *ProjectCollection, allocator: std.mem.Allocator) ![]*project.Project {
        var projectsList = std.ArrayList(*project.Project).init(allocator);
        var it = self.configuredProjects.iterator();
        while (it.next()) |entry| {
            try projectsList.append(entry.value_ptr.*);
        }
        const slice = try projectsList.toOwnedSlice();
        // Sort by name
        std.sort.pdq(*project.Project, slice, {}, struct {
            fn lessThan(_: void, a: *project.Project, b: *project.Project) bool {
                return std.mem.lessThan(u8, a.name(), b.name());
            }
        }.lessThan);
        return slice;
    }

    pub fn projects(self: *ProjectCollection, allocator: std.mem.Allocator) ![]*project.Project {
        if (self.inferredProject == null) return try self.configuredProjectsList(allocator);
        var list = std.ArrayList(*project.Project).init(allocator);
        const configured = try self.configuredProjectsList(allocator);
        try list.appendSlice(configured);
        try list.append(self.inferredProject.?);
        return try list.toOwnedSlice();
    }

    pub fn getInferredProject(self: *ProjectCollection) ?*project.Project {
        return self.inferredProject;
    }

    pub fn getProjectsContainingFile(self: *ProjectCollection, allocator: std.mem.Allocator, path: tspath.Path) ![]*project.Project {
        var result = std.ArrayList(*project.Project).init(allocator);
        for (try self.configuredProjectsList(allocator)) |p| {
            if (p.containsFile(path)) {
                try result.append(p);
            }
        }
        if (self.inferredProject) |inf| {
            if (inf.containsFile(path)) {
                try result.append(inf);
            }
        }
        return try result.toOwnedSlice();
    }

    pub fn getOpenConfiguredProjects(self: *ProjectCollection, allocator: std.mem.Allocator) !*std.StringArrayHashMap(void) {
        // Since we don't have Once block with captures, we just check manually
        if (self.openConfiguredProjects) |open| return open;

        var open_projects = try allocator.create(std.StringArrayHashMap(void));
        open_projects.* = std.StringArrayHashMap(void).init(allocator);

        var it = self.openFiles.keyIterator();
        while (it.next()) |path_ptr| {
            const path = path_ptr.*;
            if (self.fileDefaultProjects.get(path)) |projectPath| {
                if (!std.mem.eql(u8, projectPath, project.inferredProjectName)) {
                    if (self.configuredProjects.contains(projectPath)) {
                        try open_projects.put(projectPath, {});
                        continue;
                    }
                }
            }

            var p_it = self.configuredProjects.iterator();
            while (p_it.next()) |entry| {
                if (entry.value_ptr.*.containsFile(path)) {
                    try open_projects.put(entry.value_ptr.*.configFilePath, {});
                }
            }
        }

        self.openConfiguredProjects = open_projects;
        return open_projects;
    }

    pub fn getDefaultProject(self: *ProjectCollection, allocator: std.mem.Allocator, path: tspath.Path) !?*project.Project {
        if (self.fileDefaultProjects.get(path)) |result| {
            if (std.mem.eql(u8, result, project.inferredProjectName)) return self.inferredProject;
            return self.configuredProjects.get(result);
        }

        var containingProjects = std.ArrayList(*project.Project).init(allocator);
        var firstConfiguredProject: ?*project.Project = null;
        var firstNonSourceOfProjectReferenceRedirect: ?*project.Project = null;
        var multipleDirectInclusions = false;

        const configured = try self.configuredProjectsList(allocator);
        for (configured) |p| {
            if (p.containsFile(path)) {
                try containingProjects.append(p);
                if (!multipleDirectInclusions and !p.isSourceFromProjectReference(path)) {
                    if (firstNonSourceOfProjectReferenceRedirect == null) {
                        firstNonSourceOfProjectReferenceRedirect = p;
                    } else {
                        multipleDirectInclusions = true;
                    }
                }
                if (firstConfiguredProject == null) {
                    firstConfiguredProject = p;
                }
            }
        }

        if (containingProjects.items.len == 1) return containingProjects.items[0];
        if (containingProjects.items.len == 0) {
            if (self.inferredProject != null and self.inferredProject.?.containsFile(path)) {
                return self.inferredProject;
            }
            return null;
        }

        if (!multipleDirectInclusions) {
            if (firstNonSourceOfProjectReferenceRedirect != null) return firstNonSourceOfProjectReferenceRedirect;
            return firstConfiguredProject;
        }

        // Multiple projects directly include the file.
        // We'd ideally call findDefaultConfiguredProject(path) here but need to mock it.
        return firstConfiguredProject;
    }
};
