const std = @import("std");

pub const EventKind = enum(u8) {
    update = 1,
    delete = 2,

    pub fn format(self: EventKind, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .update => try writer.writeAll("update"),
            .delete => try writer.writeAll("delete"),
        }
    }
};

pub const Event = struct {
    kind: EventKind,
    path: []const u8,
};

pub const EventEntry = struct {
    isCreated: bool = false,
    isDeleted: bool = false,
};

pub const EventList = struct {
    mu: std.Thread.Mutex = .{},
    entries: std.StringHashMap(*EventEntry),
    err: ?anyerror = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) EventList {
        return .{
            .entries = std.StringHashMap(*EventEntry).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EventList) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.entries.deinit();
    }

    pub fn create(self: *EventList, path: []const u8) !void {
        self.mu.lock();
        defer self.mu.unlock();
        var entry = try self.getOrCreate(path);
        if (entry.isDeleted) {
            entry.isDeleted = false;
            entry.isCreated = false;
        } else {
            entry.isCreated = true;
        }
    }

    pub fn update(self: *EventList, path: []const u8) !void {
        self.mu.lock();
        defer self.mu.unlock();
        _ = try self.getOrCreate(path);
    }

    pub fn remove(self: *EventList, path: []const u8) !void {
        self.mu.lock();
        defer self.mu.unlock();
        var entry = try self.getOrCreate(path);
        entry.isDeleted = true;
    }

    pub fn size(self: *EventList) usize {
        self.mu.lock();
        defer self.mu.unlock();
        return self.entries.count();
    }

    fn snapshotLocked(self: *EventList) ![]Event {
        var out = std.ArrayList(Event).init(self.allocator);
        errdefer out.deinit();

        var it = self.entries.iterator();
        while (it.next()) |kv| {
            const path = kv.key_ptr.*;
            const e = kv.value_ptr.*;

            if (e.isCreated and e.isDeleted) continue;

            const kind: EventKind = if (e.isDeleted) .delete else .update;
            try out.append(.{ .kind = kind, .path = try self.allocator.dupe(u8, path) });
        }
        return out.toOwnedSlice();
    }

    pub fn getEvents(self: *EventList) ![]Event {
        self.mu.lock();
        defer self.mu.unlock();
        return self.snapshotLocked();
    }

    pub const DrainResult = struct {
        events: []Event,
        err: ?anyerror,
    };

    pub fn drain(self: *EventList) !DrainResult {
        self.mu.lock();
        defer self.mu.unlock();
        const out = try self.snapshotLocked();
        const err = self.err;

        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.entries.clearAndFree();
        self.err = null;

        return .{ .events = out, .err = err };
    }

    pub fn setError(self: *EventList, err: anyerror) void {
        self.mu.lock();
        defer self.mu.unlock();
        if (self.err == null) {
            self.err = err;
        }
    }

    pub fn hasError(self: *EventList) bool {
        self.mu.lock();
        defer self.mu.unlock();
        return self.err != null;
    }

    pub fn getError(self: *EventList) ?anyerror {
        self.mu.lock();
        defer self.mu.unlock();
        return self.err;
    }

    fn getOrCreate(self: *EventList, path: []const u8) !*EventEntry {
        if (self.entries.get(path)) |e| {
            return e;
        }
        const e = try self.allocator.create(EventEntry);
        e.* = .{};
        const duped_path = try self.allocator.dupe(u8, path);
        errdefer {
            self.allocator.free(duped_path);
            self.allocator.destroy(e);
        }
        try self.entries.put(duped_path, e);
        return e;
    }
};
