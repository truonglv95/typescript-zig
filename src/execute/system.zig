const std = @import("std");

pub const System = struct {
    context: *anyopaque,
    
    writerFn: *const fn(context: *anyopaque) *anyopaque,
    // fsFn: *const fn(context: *anyopaque) *vfs.FS,
    defaultLibraryPathFn: *const fn(context: *anyopaque) []const u8,
    getCurrentDirectoryFn: *const fn(context: *anyopaque) []const u8,
    writeOutputIsTTYFn: *const fn(context: *anyopaque) bool,
    getWidthOfTerminalFn: *const fn(context: *anyopaque) usize,
    getEnvironmentVariableFn: *const fn(context: *anyopaque, name: []const u8) ?[]const u8,
    nowFn: *const fn(context: *anyopaque) i64,
    sinceStartFn: *const fn(context: *anyopaque) i64,

    pub fn writer(self: *const System) *anyopaque {
        return self.writerFn(self.context);
    }
    
    pub fn defaultLibraryPath(self: *const System) []const u8 {
        return self.defaultLibraryPathFn(self.context);
    }
    
    pub fn getCurrentDirectory(self: *const System) []const u8 {
        return self.getCurrentDirectoryFn(self.context);
    }
    
    pub fn writeOutputIsTTY(self: *const System) bool {
        return self.writeOutputIsTTYFn(self.context);
    }
    
    pub fn getWidthOfTerminal(self: *const System) usize {
        return self.getWidthOfTerminalFn(self.context);
    }
    
    pub fn getEnvironmentVariable(self: *const System, name: []const u8) ?[]const u8 {
        return self.getEnvironmentVariableFn(self.context, name);
    }
    
    pub fn now(self: *const System) i64 {
        return self.nowFn(self.context);
    }
    
    pub fn sinceStart(self: *const System) i64 {
        return self.sinceStartFn(self.context);
    }
};
