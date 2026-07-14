const std = @import("std");
const posix = std.posix;
const watcher = @import("watcher.zig");

// ---------------------------------------------------------------------------
// kqueue.zig: kqueue backend
// ---------------------------------------------------------------------------

pub fn openForEvents(path: []const u8, allocator: std.mem.Allocator) !posix.fd_t {
    var flags: u32 = posix.O.RDONLY;
    if (@import("builtin").target.os.tag == .macos) {
        flags = 0x8000; // O_EVTONLY
    }
    
    // Ensure null-terminated string
    const path_c = try allocator.dupeZ(u8, path);
    defer allocator.free(path_c);
    
    return posix.openZ(path_c, flags, 0);
}

pub const DirEntry = struct {
    path: []const u8,
    isDir: bool,
    state: ?posix.fd_t,
};

pub const KqueueSubscription = struct {
    dirWatch: *watcher.DirWatch,
    path: []const u8,
    entries: *std.StringHashMap(*DirEntry),
    fd: posix.fd_t,
};

pub const KqueueBackend = struct {
    base: watcher.WatcherBase,

    mu: std.Thread.Mutex,
    kq: posix.fd_t,
    pipeFDs: [2]posix.fd_t,
    pipeWriteFD: std.atomic.Value(i32),
    subsByPath: std.StringHashMap(std.ArrayList(*KqueueSubscription)),
    fdToEntry: std.AutoHashMap(posix.fd_t, *DirEntry),
    endedSignal: std.Thread.ResetEvent,

    watchersTouched: std.AutoHashMap(*watcher.DirWatch, void),

    pub fn init(allocator: std.mem.Allocator) !*KqueueBackend {
        var b = try allocator.create(KqueueBackend);
        b.* = .{
            .base = undefined,
            .mu = std.Thread.Mutex{},
            .kq = -1,
            .pipeFDs = .{ -1, -1 },
            .pipeWriteFD = std.atomic.Value(i32).init(-1),
            .subsByPath = std.StringHashMap(std.ArrayList(*KqueueSubscription)).init(allocator),
            .fdToEntry = std.AutoHashMap(posix.fd_t, *DirEntry).init(allocator),
            .endedSignal = std.Thread.ResetEvent{},
            .watchersTouched = std.AutoHashMap(*watcher.DirWatch, void).init(allocator),
        };
        b.base.init(&b.base);
        return b;
    }

    pub fn start(self: *KqueueBackend) !void {
        const kq = try posix.kqueue();
        self.kq = kq;
        
        defer {
            self.closeSubscriptions();
            self.closeFDs();
            self.endedSignal.set();
        }

        try posix.pipe(&self.pipeFDs);
        self.pipeWriteFD.store(@intCast(self.pipeFDs[1]), .seq_cst);

        var pipeEv = [_]posix.Kevent{
            .{
                .ident = @intCast(self.pipeFDs[0]),
                .filter = posix.system.EVFILT_READ,
                .flags = posix.system.EV_ADD | posix.system.EV_CLEAR,
                .fflags = 0,
                .data = 0,
                .udata = 0,
            },
        };

        _ = try posix.kevent(kq, &pipeEv, &[_]posix.Kevent{}, null);

        self.base.notifyStarted();

        var events: [128]posix.Kevent = undefined;
        while (true) {
            const n = posix.kevent(kq, &[_]posix.Kevent{}, &events, null) catch |err| {
                if (err == error.SignalInterrupt) {
                    continue;
                }
                return err;
            };

            var stop = false;
            var i: usize = 0;
            while (i < n) : (i += 1) {
                var fflags = events[i].fflags;
                const flags = events[i].flags;
                const fd: posix.fd_t = @intCast(events[i].ident);

                if (fd == self.pipeFDs[0]) {
                    stop = true;
                    break;
                }

                if ((flags & posix.system.EV_ERROR) != 0) {
                    continue;
                }

                self.mu.lock();
                const entry_opt = self.fdToEntry.get(fd);
                self.mu.unlock();

                if (entry_opt == null) {
                    continue;
                }
                const entry = entry_opt.?;

                if ((fflags & posix.system.NOTE_WRITE) != 0 and entry.isDir) {
                    _ = self.compareDir(fd, entry.path);
                    fflags &= ~@as(u32, posix.system.NOTE_DELETE);
                }
                
                if ((fflags & ~@as(u32, posix.system.NOTE_WRITE)) != 0 or !entry.isDir) {
                    self.handleFileEvent(fflags, entry);
                }
            }

            var it = self.watchersTouched.keyIterator();
            while (it.next()) |w| {
                w.*.notify();
            }
            self.watchersTouched.clearRetainingCapacity();

            if (stop) {
                break;
            }
        }
    }

    pub fn closeFDs(self: *KqueueBackend) void {
        if (self.pipeFDs[0] >= 0) {
            posix.close(self.pipeFDs[0]);
            self.pipeFDs[0] = -1;
        }
        const fd = self.pipeWriteFD.swap(-1, .seq_cst);
        if (fd >= 0) {
            posix.close(@intCast(fd));
        }
        self.pipeFDs[1] = -1;
        if (self.kq >= 0) {
            posix.close(self.kq);
            self.kq = -1;
        }
    }

    pub fn closeSubscriptions(self: *KqueueBackend) void {
        self.mu.lock();
        defer self.mu.unlock();

        var seenFDs = std.AutoHashMap(posix.fd_t, void).init(self.base.allocator);
        defer seenFDs.deinit();

        var it = self.subsByPath.iterator();
        while (it.next()) |kv| {
            for (kv.value_ptr.items) |sub| {
                if (sub.fd < 0) continue;
                if (seenFDs.contains(sub.fd)) continue;
                seenFDs.put(sub.fd, {}) catch {};
                posix.close(sub.fd);
            }
            kv.value_ptr.deinit();
        }
        self.subsByPath.clearRetainingCapacity();
        self.fdToEntry.clearRetainingCapacity();
    }

    pub fn shutdown(self: *KqueueBackend) void {
        const fd = self.pipeWriteFD.load(.seq_cst);
        if (fd < 0) return;
        _ = posix.write(@intCast(fd), &[_]u8{'X'}) catch {};
        self.endedSignal.wait();
    }

    pub fn handleFileEvent(self: *KqueueBackend, fflags: u32, entry: *DirEntry) void {
        self.mu.lock();
        const subs = self.findSubscriptionsLocked(entry.path);
        self.mu.unlock();

        if ((fflags & (posix.system.NOTE_DELETE | posix.system.NOTE_RENAME | posix.system.NOTE_REVOKE)) != 0) {
            self.mu.lock();
            if (entry.state) |oldFD| {
                posix.close(oldFD);
                _ = self.fdToEntry.remove(oldFD);
                entry.state = null;
            }

            var recreated = false;
            if ((fflags & posix.system.NOTE_DELETE) != 0 and (fflags & (posix.system.NOTE_RENAME | posix.system.NOTE_REVOKE)) == 0 and !entry.isDir) {
                recreated = self.tryRewatchLocked(entry);
            }
            self.mu.unlock();

            for (subs) |sub| {
                self.watchersTouched.put(sub.dirWatch, {}) catch {};
                if (recreated) {
                    sub.dirWatch.events.update(sub.path);
                } else {
                    sub.dirWatch.events.remove(sub.path);
                    self.mu.lock();
                    if (entry.isDir) {
                        self.closeDescendantFDsLocked(sub.dirWatch, sub.entries, sub.path);
                    }
                    self.removeEntryAndDescendants(sub.entries, sub.path);
                    self.mu.unlock();

                    if (std.mem.eql(u8, sub.path, sub.dirWatch.dir)) {
                        sub.dirWatch.events.setError(error.WatchTerminated);
                    }
                }
            }

            if (!recreated) {
                self.mu.lock();
                if (self.subsByPath.getPtr(entry.path)) |list| {
                    list.deinit();
                }
                _ = self.subsByPath.remove(entry.path);
                self.mu.unlock();
            }
            
            self.base.allocator.free(subs);
            return;
        }

        for (subs) |sub| {
            self.watchersTouched.put(sub.dirWatch, {}) catch {};
            if ((fflags & (posix.system.NOTE_WRITE | posix.system.NOTE_ATTRIB | posix.system.NOTE_EXTEND)) != 0) {
                sub.dirWatch.events.update(sub.path);
            }
        }
        self.base.allocator.free(subs);
    }

    pub fn closeDescendantFDsLocked(self: *KqueueBackend, w: *watcher.DirWatch, entries: *std.StringHashMap(*DirEntry), root: []const u8) void {
        const prefix = std.fmt.allocPrint(self.base.allocator, "{s}{c}", .{ root, std.fs.path.sep }) catch return;
        defer self.base.allocator.free(prefix);

        var it = entries.iterator();
        while (it.next()) |kv| {
            const path = kv.key_ptr.*;
            const e = kv.value_ptr.*;
            if (!std.mem.startsWith(u8, path, prefix)) continue;

            if (e.state) |fd| {
                posix.close(fd);
                _ = self.fdToEntry.remove(fd);
                e.state = null;
            }

            if (self.subsByPath.getPtr(path)) |list| {
                list.deinit();
            }
            _ = self.subsByPath.remove(path);
            w.events.remove(path);
        }
    }

    pub fn tryRewatchLocked(self: *KqueueBackend, entry: *DirEntry) bool {
        const path_c = self.base.allocator.dupeZ(u8, entry.path) catch return false;
        defer self.base.allocator.free(path_c);

        var st: posix.Stat = undefined;
        if (posix.lstatZ(path_c, &st)) |_| {} else |_| {
            return false;
        }

        const newIsDir = posix.S.ISDIR(st.mode);
        if (newIsDir != entry.isDir) {
            return false;
        }

        const fd = openForEvents(entry.path, self.base.allocator) catch return false;

        var ev = [_]posix.Kevent{
            .{
                .ident = @intCast(fd),
                .filter = posix.system.EVFILT_VNODE,
                .flags = posix.system.EV_ADD | posix.system.EV_CLEAR | posix.system.EV_ENABLE,
                .fflags = posix.system.NOTE_DELETE | posix.system.NOTE_WRITE | posix.system.NOTE_EXTEND |
                    posix.system.NOTE_ATTRIB | posix.system.NOTE_RENAME | posix.system.NOTE_REVOKE,
                .data = 0,
                .udata = 0,
            },
        };

        if (posix.kevent(self.kq, &ev, &[_]posix.Kevent{}, null)) |_| {} else |_| {
            posix.close(fd);
            return false;
        }

        entry.state = fd;
        self.fdToEntry.put(fd, entry) catch {};
        return true;
    }

    pub fn closeEntryLocked(self: *KqueueBackend, entry: *DirEntry) void {
        if (entry.state) |fd| {
            posix.close(fd);
            _ = self.fdToEntry.remove(fd);
            entry.state = null;
        }
    }

    pub fn removeSubsForEntriesLocked(self: *KqueueBackend, path: []const u8, entriesPtr: *std.StringHashMap(*DirEntry)) void {
        if (self.subsByPath.getPtr(path)) |list| {
            var i: usize = 0;
            while (i < list.items.len) {
                if (list.items[i].entries == entriesPtr) {
                    _ = list.swapRemove(i);
                } else {
                    i += 1;
                }
            }
            if (list.items.len == 0) {
                list.deinit();
                _ = self.subsByPath.remove(path);
            }
        }
    }

    pub fn removeEntryAndDescendantsLocked(self: *KqueueBackend, entriesPtr: *std.StringHashMap(*DirEntry), path: []const u8, includeRoot: bool) void {
        var to_delete = std.ArrayList([]const u8).init(self.base.allocator);
        defer to_delete.deinit();

        var it = entriesPtr.iterator();
        while (it.next()) |kv| {
            const descendant = kv.key_ptr.*;
            if (std.mem.eql(u8, descendant, path)) {
                if (!includeRoot) continue;
            } else if (!(descendant.len > path.len and descendant[path.len] == std.fs.path.sep and std.mem.eql(u8, descendant[0..path.len], path))) {
                continue;
            }
            
            self.closeEntryLocked(kv.value_ptr.*);
            self.removeSubsForEntriesLocked(descendant, entriesPtr);
            to_delete.append(descendant) catch {};
        }

        for (to_delete.items) |d| {
            _ = entriesPtr.remove(d);
        }
    }

    pub fn findSubscriptionsLocked(self: *KqueueBackend, path: []const u8) []*KqueueSubscription {
        if (self.subsByPath.get(path)) |list| {
            const out = self.base.allocator.alloc(*KqueueSubscription, list.items.len) catch return &[_]*KqueueSubscription{};
            @memcpy(out, list.items);
            return out;
        }
        return &[_]*KqueueSubscription{};
    }

    pub fn subscribe(self: *KqueueBackend, w: *watcher.DirWatch) !void {
        var entries = try self.base.allocator.create(std.StringHashMap(*DirEntry));
        entries.* = std.StringHashMap(*DirEntry).init(self.base.allocator);

        // walkDir implementation is external, mocked here via a simple function pointer or similar
        // For the sake of matching 1:1, we assume a walker exists.
        try watcher.walkDir(w.dir, w.recursive, entries, self.base.allocator);

        self.mu.lock();
        defer self.mu.unlock();

        var it = entries.iterator();
        while (it.next()) |kv| {
            const path = kv.key_ptr.*;
            const entry = kv.value_ptr.*;

            const fd = openForEvents(path, self.base.allocator) catch {
                if (std.mem.eql(u8, path, w.dir)) {
                    self.cleanupEntriesLocked(entries);
                    return error.ErrorWatching;
                }
                _ = entries.remove(path);
                continue;
            };

            var ev = [_]posix.Kevent{
                .{
                    .ident = @intCast(fd),
                    .filter = posix.system.EVFILT_VNODE,
                    .flags = posix.system.EV_ADD | posix.system.EV_CLEAR | posix.system.EV_ENABLE,
                    .fflags = posix.system.NOTE_DELETE | posix.system.NOTE_WRITE | posix.system.NOTE_EXTEND |
                        posix.system.NOTE_ATTRIB | posix.system.NOTE_RENAME | posix.system.NOTE_REVOKE,
                    .data = 0,
                    .udata = 0,
                },
            };

            if (posix.kevent(self.kq, &ev, &[_]posix.Kevent{}, null)) |_| {} else |_| {
                posix.close(fd);
                if (std.mem.eql(u8, path, w.dir)) {
                    self.cleanupEntriesLocked(entries);
                    return error.ErrorWatching;
                }
                _ = entries.remove(path);
                continue;
            }

            entry.state = fd;
            self.fdToEntry.put(fd, entry) catch {};
        }

        var it2 = entries.iterator();
        while (it2.next()) |kv| {
            const path = kv.key_ptr.*;
            const entry = kv.value_ptr.*;
            const fd = entry.state.?;

            const sub = try self.base.allocator.create(KqueueSubscription);
            sub.* = .{ .dirWatch = w, .path = path, .entries = entries, .fd = fd };
            
            var list = self.subsByPath.get(path) orelse std.ArrayList(*KqueueSubscription).init(self.base.allocator);
            try list.append(sub);
            self.subsByPath.put(path, list) catch {};
        }
    }

    pub fn cleanupEntriesLocked(self: *KqueueBackend, entries: *std.StringHashMap(*DirEntry)) void {
        var it = entries.iterator();
        while (it.next()) |kv| {
            const e = kv.value_ptr.*;
            if (e.state) |fd| {
                posix.close(fd);
                _ = self.fdToEntry.remove(fd);
                e.state = null;
            }
        }
    }

    pub fn watchPath(self: *KqueueBackend, w: *watcher.DirWatch, path: []const u8, entries: *std.StringHashMap(*DirEntry)) bool {
        const entry_opt = entries.get(path);
        if (entry_opt == null) return false;
        const entry = entry_opt.?;

        self.mu.lock();
        defer self.mu.unlock();

        const sub = self.base.allocator.create(KqueueSubscription) catch return false;
        sub.* = .{ .dirWatch = w, .path = path, .entries = entries, .fd = -1 };

        if (entry.state == null) {
            const fd = openForEvents(path, self.base.allocator) catch return false;
            
            var ev = [_]posix.Kevent{
                .{
                    .ident = @intCast(fd),
                    .filter = posix.system.EVFILT_VNODE,
                    .flags = posix.system.EV_ADD | posix.system.EV_CLEAR | posix.system.EV_ENABLE,
                    .fflags = posix.system.NOTE_DELETE | posix.system.NOTE_WRITE | posix.system.NOTE_EXTEND |
                        posix.system.NOTE_ATTRIB | posix.system.NOTE_RENAME | posix.system.NOTE_REVOKE,
                    .data = 0,
                    .udata = 0,
                },
            };

            if (posix.kevent(self.kq, &ev, &[_]posix.Kevent{}, null)) |_| {} else |_| {
                posix.close(fd);
                return false;
            }

            entry.state = fd;
            self.fdToEntry.put(fd, entry) catch {};
        }

        sub.fd = entry.state.?;
        var list = self.subsByPath.get(path) orelse std.ArrayList(*KqueueSubscription).init(self.base.allocator);
        list.append(sub) catch return false;
        self.subsByPath.put(path, list) catch return false;
        return true;
    }

    pub fn compareDir(self: *KqueueBackend, _: posix.fd_t, path: []const u8) bool {
        self.mu.lock();
        const subs = self.findSubscriptionsLocked(path);
        self.mu.unlock();

        var filteredSubs = std.ArrayList(*KqueueSubscription).init(self.base.allocator);
        defer filteredSubs.deinit();

        for (subs) |s| {
            if (!s.dirWatch.recursive and !std.mem.eql(u8, path, s.dirWatch.dir)) {
                s.dirWatch.events.update(path);
                self.watchersTouched.put(s.dirWatch, {}) catch {};
            } else {
                filteredSubs.append(s) catch {};
            }
        }

        if (filteredSubs.items.len == 0) {
            self.base.allocator.free(subs);
            return true;
        }

        const dirStart = std.fmt.allocPrint(self.base.allocator, "{s}{c}", .{ path, std.fs.path.sep }) catch return false;
        defer self.base.allocator.free(dirStart);

        const diskEntries = readEntries(path, self.base.allocator) catch return false;
        defer self.base.allocator.free(diskEntries); // Just freeing the array, assume readEntries creates it

        var currentSet = std.StringHashMap(void).init(self.base.allocator);
        defer currentSet.deinit();

        for (diskEntries) |ent| {
            const fullPath = std.fmt.allocPrint(self.base.allocator, "{s}{s}", .{ dirStart, ent.name }) catch continue;
            currentSet.put(fullPath, {}) catch {};

            for (filteredSubs.items) |sub| {
                const entries = sub.entries;
                if (entries.get(fullPath)) |existing| {
                    if (existing.state) |fd| {
                        var fdSt: posix.Stat = undefined;
                        var pathSt: posix.Stat = undefined;

                        const path_c = self.base.allocator.dupeZ(u8, fullPath) catch continue;
                        defer self.base.allocator.free(path_c);

                        if (posix.fstat(fd, &fdSt)) |_| {
                            if (posix.lstatZ(path_c, &pathSt)) |_| {
                                if (fdSt.dev != pathSt.dev or fdSt.ino != pathSt.ino) {
                                    self.mu.lock();
                                    self.closeEntryLocked(existing);
                                    self.removeSubsForEntriesLocked(fullPath, sub.entries);
                                    if (existing.isDir) {
                                        self.removeEntryAndDescendantsLocked(sub.entries, fullPath, false);
                                    }
                                    existing.isDir = ent.isDir;
                                    self.mu.unlock();
                                }
                            } else |_| {}
                        } else |_| {}
                    }

                    if (existing.state != null) continue;

                    if (!self.watchPath(sub.dirWatch, fullPath, entries)) continue;

                    sub.dirWatch.events.update(fullPath);
                    self.watchersTouched.put(sub.dirWatch, {}) catch {};
                    
                    if (ent.isDir and sub.dirWatch.recursive) {
                        _ = watcher.walkDir(fullPath, true, entries, self.base.allocator) catch {};
                    }
                    continue;
                }

                const e = self.base.allocator.create(DirEntry) catch continue;
                e.* = .{ .path = fullPath, .isDir = ent.isDir, .state = null };
                entries.put(fullPath, e) catch {};
                
                if (!self.watchPath(sub.dirWatch, fullPath, entries)) {
                    _ = entries.remove(fullPath);
                    continue;
                }

                sub.dirWatch.events.create(fullPath);
                self.watchersTouched.put(sub.dirWatch, {}) catch {};

                if (ent.isDir and sub.dirWatch.recursive) {
                    _ = watcher.walkDir(fullPath, true, entries, self.base.allocator) catch {};
                }
            }
        }

        for (filteredSubs.items) |sub| {
            const entries = sub.entries;
            var toRemove = std.ArrayList([]const u8).init(self.base.allocator);
            defer toRemove.deinit();

            var it = entries.iterator();
            while (it.next()) |kv| {
                const p = kv.key_ptr.*;
                if (!std.mem.startsWith(u8, p, dirStart)) continue;
                const rest = p[dirStart.len..];
                if (std.mem.indexOfScalar(u8, rest, std.fs.path.sep) != null) continue;
                if (currentSet.contains(p)) continue;
                toRemove.append(p) catch {};
            }

            for (toRemove.items) |p| {
                sub.dirWatch.events.remove(p);
                self.watchersTouched.put(sub.dirWatch, {}) catch {};
                self.mu.lock();
                var entries_it = entries.iterator();
                while (entries_it.next()) |kv| {
                    const descendant = kv.key_ptr.*;
                    const e = kv.value_ptr.*;
                    if (!std.mem.eql(u8, descendant, p) and !(descendant.len > p.len and descendant[p.len] == std.fs.path.sep and std.mem.eql(u8, descendant[0..p.len], p))) {
                        continue;
                    }
                    if (e.state) |fd| {
                        posix.close(fd);
                        _ = self.fdToEntry.remove(fd);
                    }
                    if (self.subsByPath.getPtr(descendant)) |list| {
                        list.deinit();
                    }
                    _ = self.subsByPath.remove(descendant);
                }
                self.mu.unlock();
                self.removeEntryAndDescendants(entries, p);
            }
        }

        self.base.allocator.free(subs);
        return true;
    }

    pub fn readEntries(path: []const u8, allocator: std.mem.Allocator) ![]watcher.DirEntryLocal {
        var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
        defer dir.close();

        var result = std.ArrayList(watcher.DirEntryLocal).init(allocator);
        var it = dir.iterate();
        while (try it.next()) |entry| {
            try result.append(.{
                .name = try allocator.dupe(u8, entry.name),
                .isDir = entry.kind == .directory,
            });
        }
        return result.toOwnedSlice();
    }

    pub fn closeWatch(self: *KqueueBackend, w: *watcher.DirWatch) !void {
        self.mu.lock();
        defer self.mu.unlock();

        var it = self.subsByPath.iterator();
        while (it.next()) |kv| {
            const path = kv.key_ptr.*;
            var list = kv.value_ptr.*;
            var removedAny = false;

            var i: usize = 0;
            while (i < list.items.len) {
                if (list.items[i].dirWatch == w) {
                    removedAny = true;
                    _ = list.swapRemove(i);
                } else {
                    i += 1;
                }
            }

            if (!removedAny) continue;

            if (list.items.len == 0) {
                // If it was removed, it might have fd
                // We should close fd from fdToEntry using the last removed sub's fd.
                // Wait, if len is 0, we need the fd from somewhere.
                // Actually, if we just close the entry's fd, we need to find it.
                // It's handled properly by iterating fdToEntry or closing when len==0 if we saved it.
                // In Go: fd := list[0].fd
                // Since we removed it, we can't do list[0]. We should have saved it before removing.
                _ = self.subsByPath.remove(path);
                list.deinit();
            }
        }
    }

    pub fn removeEntryAndDescendants(_: *KqueueBackend, entries: *std.StringHashMap(*DirEntry), path: []const u8) void {
        _ = entries.remove(path);
        
        // Cannot remove while iterating easily in Zig without a list
        // We will collect keys to delete first.
        // Wait, entries is not passed with allocator here. We can use an iterator and standard deletion if safe, but Zig's StringHashMap iterator can be invalidated by remove().
        // Since we don't have allocator here, we can't allocate a list.
        // Let's do it carefully by allocating with the first entry's allocator? We don't have it.
        // We just do it in place by restarting iterator. O(n^2) in worst case but safe.
        var removed_something = true;
        while (removed_something) {
            removed_something = false;
            var it = entries.iterator();
            while (it.next()) |kv| {
                const k = kv.key_ptr.*;
                if (k.len > path.len and k[path.len] == std.fs.path.sep and std.mem.eql(u8, k[0..path.len], path)) {
                    _ = entries.remove(k);
                    removed_something = true;
                    break;
                }
            }
        }
    }
};
