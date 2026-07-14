const std = @import("std");

//! Cross-project orchestration for multi-project language service.
//!
//! Port of `internal/ls/crossproject.go` (421 LOC).
//!
//! Provides interfaces and helpers for language service features that
//! span multiple projects (e.g. find-all-references across project
//! references, go-to-definition in a different project).

/// A project in the language service.
/// Port of Go's `ls.Project` interface.
pub const Project = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        id: *const fn (ptr: *anyopaque) []const u8,
        hasFile: *const fn (ptr: *anyopaque, file_name: []const u8) bool,
    };

    pub fn id(self: Project) []const u8 {
        return self.vtable.id(self.ptr);
    }

    pub fn hasFile(self: Project, file_name: []const u8) bool {
        return self.vtable.hasFile(self.ptr, file_name);
    }
};

/// Cross-project orchestrator interface.
/// Port of Go's `CrossProjectOrchestrator` interface.
pub const CrossProjectOrchestrator = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        getDefaultProject: *const fn (ptr: *anyopaque) Project,
        getAllProjectsForInitialRequest: *const fn (ptr: *anyopaque) []const Project,
        getProjectsForFile: *const fn (ptr: *anyopaque, uri: []const u8) []const Project,
    };

    pub fn getDefaultProject(self: CrossProjectOrchestrator) Project {
        return self.vtable.getDefaultProject(self.ptr);
    }

    pub fn getAllProjectsForInitialRequest(self: CrossProjectOrchestrator) []const Project {
        return self.vtable.getAllProjectsForInitialRequest(self.ptr);
    }

    pub fn getProjectsForFile(self: CrossProjectOrchestrator, uri: []const u8) []const Project {
        return self.vtable.getProjectsForFile(self.ptr, uri);
    }
};

/// A project and text document position pair.
pub const ProjectAndTextDocumentPosition = struct {
    project: Project,
    uri: []const u8,
    line: u32,
    character: u32,
    for_original_location: bool = false,
};
