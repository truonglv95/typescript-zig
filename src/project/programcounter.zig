const std = @import("std");
const compiler = @import("../compiler/program.zig");

pub const ProgramCounter = struct {
    mu: std.Thread.Mutex = .{},
    refs: std.AutoHashMap(*compiler.Program, i32),

    pub fn init(allocator: std.mem.Allocator) ProgramCounter {
        return .{
            .refs = std.AutoHashMap(*compiler.Program, i32).init(allocator),
        };
    }

    pub fn ref(self: *ProgramCounter, program: *compiler.Program) void {
        self.mu.lock();
        defer self.mu.unlock();
        const res = self.refs.getOrPut(program) catch @panic("OOM");
        if (!res.found_existing) {
            res.value_ptr.* = 1;
        } else {
            res.value_ptr.* += 1;
        }
    }

    pub fn deref(self: *ProgramCounter, program: *compiler.Program) bool {
        self.mu.lock();
        defer self.mu.unlock();
        if (self.refs.getPtr(program)) |count| {
            count.* -= 1;
            if (count.* < 0) @panic("program reference count went below zero");
            if (count.* == 0) {
                _ = self.refs.remove(program);
                return true;
            }
            return false;
        }
        return false;
    }

    pub fn len(self: *ProgramCounter) usize {
        self.mu.lock();
        defer self.mu.unlock();
        return self.refs.count();
    }
};
