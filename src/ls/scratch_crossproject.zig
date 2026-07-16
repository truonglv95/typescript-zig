const std = @import("std");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const ls = @import("languageservice.zig");
const compiler = @import("../compiler/program.zig");
const far = @import("findallreferences.zig");
const tspath = @import("../tspath/tspath.zig");

pub const Project = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        id: *const fn (ptr: *anyopaque) tspath.Path,
        getProgram: *const fn (ptr: *anyopaque) ?*compiler.Program,
        hasFile: *const fn (ptr: *anyopaque, file_name: []const u8) bool,
    };

    pub fn id(self: Project) tspath.Path {
        return self.vtable.id(self.ptr);
    }

    pub fn getProgram(self: Project) ?*compiler.Program {
        return self.vtable.getProgram(self.ptr);
    }

    pub fn hasFile(self: Project, file_name: []const u8) bool {
        return self.vtable.hasFile(self.ptr, file_name);
    }
};

pub const CrossProjectOrchestrator = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        getDefaultProject: *const fn (ptr: *anyopaque) Project,
        getAllProjectsForInitialRequest: *const fn (ptr: *anyopaque) []const Project,
        getLanguageServiceForProjectWithFile: *const fn (ptr: *anyopaque, project: Project, uri: []const u8) ?*ls.LanguageService,
        getProjectsForFile: *const fn (ptr: *anyopaque, uri: []const u8) []const Project,
        getProjectsLoadingProjectTree: *const fn (ptr: *anyopaque, requested_project_trees: *std.StringHashMap(void)) []const Project,
    };

    pub fn getDefaultProject(self: CrossProjectOrchestrator) Project {
        return self.vtable.getDefaultProject(self.ptr);
    }

    pub fn getAllProjectsForInitialRequest(self: CrossProjectOrchestrator) []const Project {
        return self.vtable.getAllProjectsForInitialRequest(self.ptr);
    }

    pub fn getLanguageServiceForProjectWithFile(self: CrossProjectOrchestrator, project: Project, uri: []const u8) ?*ls.LanguageService {
        return self.vtable.getLanguageServiceForProjectWithFile(self.ptr, project, uri);
    }

    pub fn getProjectsForFile(self: CrossProjectOrchestrator, uri: []const u8) []const Project {
        return self.vtable.getProjectsForFile(self.ptr, uri);
    }

    pub fn getProjectsLoadingProjectTree(self: CrossProjectOrchestrator, requested_project_trees: *std.StringHashMap(void)) []const Project {
        return self.vtable.getProjectsLoadingProjectTree(self.ptr, requested_project_trees);
    }
};

pub const ProjectAndTextDocumentPosition = struct {
    project: Project,
    ls: ?*ls.LanguageService = null,
    uri: []const u8,
    position: lsproto.Position,
    for_original_location: bool = false,
};

pub fn Response(comptime Resp: type) type {
    return struct {
        complete: bool,
        result: Resp,
        for_original_location: bool,
    };
}
