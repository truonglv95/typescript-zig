const std = @import("std");
const ast = @import("../ast/ast.zig");
const scanner = @import("../scanner/scanner.zig");
const tspath = @import("../tspath/tspath.zig");
const vfs = @import("../vfs/vfs.zig");

pub const Tracer = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        recordType: *const fn (ptr: *anyopaque, t: TracedType) void,
        dumpTypes: *const fn (ptr: *anyopaque) anyerror!void,
    };

    pub inline fn recordType(self: Tracer, t: TracedType) void {
        self.vtable.recordType(self.ptr, t);
    }
    pub inline fn dumpTypes(self: Tracer) !void {
        return self.vtable.dumpTypes(self.ptr);
    }
};

pub const TracedType = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        id: *const fn (ptr: *anyopaque) u32,
        formatFlags: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) [][]const u8,
        isConditional: *const fn (ptr: *anyopaque) bool,
        symbolName: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) []const u8,
        aliasSymbolName: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) []const u8,
        firstDeclaration: *const fn (ptr: *anyopaque) ?Location,
        aliasTypeArguments: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) []TracedType,

        intrinsicName: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) []const u8,
        unionTypes: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) []TracedType,
        intersectionTypes: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) []TracedType,
        indexType: *const fn (ptr: *anyopaque) ?TracedType,
        indexedAccessObjectType: *const fn (ptr: *anyopaque) ?TracedType,
        indexedAccessIndexType: *const fn (ptr: *anyopaque) ?TracedType,
        conditionalCheckType: *const fn (ptr: *anyopaque) ?TracedType,
        conditionalExtendsType: *const fn (ptr: *anyopaque) ?TracedType,
        conditionalTrueType: *const fn (ptr: *anyopaque) ?TracedType,
        conditionalFalseType: *const fn (ptr: *anyopaque) ?TracedType,
        substitutionBaseType: *const fn (ptr: *anyopaque) ?TracedType,
        substitutionConstraintType: *const fn (ptr: *anyopaque) ?TracedType,
        referenceTarget: *const fn (ptr: *anyopaque) ?TracedType,
        referenceTypeArguments: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) []TracedType,
        referenceLocation: *const fn (ptr: *anyopaque) ?Location,
        reverseMappedSourceType: *const fn (ptr: *anyopaque) ?TracedType,
        reverseMappedMappedType: *const fn (ptr: *anyopaque) ?TracedType,
        reverseMappedConstraintType: *const fn (ptr: *anyopaque) ?TracedType,
        evolvingArrayElementType: *const fn (ptr: *anyopaque) ?TracedType,
        evolvingArrayFinalType: *const fn (ptr: *anyopaque) ?TracedType,
        isTuple: *const fn (ptr: *anyopaque) bool,
        destructuringPattern: *const fn (ptr: *anyopaque) ?Location,
        recursionIdentity: *const fn (ptr: *anyopaque) ?usize,

        display: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) []const u8,
    };

    pub inline fn id(self: TracedType) u32 { return self.vtable.id(self.ptr); }
    pub inline fn formatFlags(self: TracedType, allocator: std.mem.Allocator) [][]const u8 { return self.vtable.formatFlags(self.ptr, allocator); }
    pub inline fn isConditional(self: TracedType) bool { return self.vtable.isConditional(self.ptr); }
    pub inline fn symbolName(self: TracedType, allocator: std.mem.Allocator) []const u8 { return self.vtable.symbolName(self.ptr, allocator); }
    pub inline fn aliasSymbolName(self: TracedType, allocator: std.mem.Allocator) []const u8 { return self.vtable.aliasSymbolName(self.ptr, allocator); }
    pub inline fn firstDeclaration(self: TracedType) ?Location { return self.vtable.firstDeclaration(self.ptr); }
    pub inline fn aliasTypeArguments(self: TracedType, allocator: std.mem.Allocator) []TracedType { return self.vtable.aliasTypeArguments(self.ptr, allocator); }
    pub inline fn intrinsicName(self: TracedType, allocator: std.mem.Allocator) []const u8 { return self.vtable.intrinsicName(self.ptr, allocator); }
    pub inline fn unionTypes(self: TracedType, allocator: std.mem.Allocator) []TracedType { return self.vtable.unionTypes(self.ptr, allocator); }
    pub inline fn intersectionTypes(self: TracedType, allocator: std.mem.Allocator) []TracedType { return self.vtable.intersectionTypes(self.ptr, allocator); }
    pub inline fn indexType(self: TracedType) ?TracedType { return self.vtable.indexType(self.ptr); }
    pub inline fn indexedAccessObjectType(self: TracedType) ?TracedType { return self.vtable.indexedAccessObjectType(self.ptr); }
    pub inline fn indexedAccessIndexType(self: TracedType) ?TracedType { return self.vtable.indexedAccessIndexType(self.ptr); }
    pub inline fn conditionalCheckType(self: TracedType) ?TracedType { return self.vtable.conditionalCheckType(self.ptr); }
    pub inline fn conditionalExtendsType(self: TracedType) ?TracedType { return self.vtable.conditionalExtendsType(self.ptr); }
    pub inline fn conditionalTrueType(self: TracedType) ?TracedType { return self.vtable.conditionalTrueType(self.ptr); }
    pub inline fn conditionalFalseType(self: TracedType) ?TracedType { return self.vtable.conditionalFalseType(self.ptr); }
    pub inline fn substitutionBaseType(self: TracedType) ?TracedType { return self.vtable.substitutionBaseType(self.ptr); }
    pub inline fn substitutionConstraintType(self: TracedType) ?TracedType { return self.vtable.substitutionConstraintType(self.ptr); }
    pub inline fn referenceTarget(self: TracedType) ?TracedType { return self.vtable.referenceTarget(self.ptr); }
    pub inline fn referenceTypeArguments(self: TracedType, allocator: std.mem.Allocator) []TracedType { return self.vtable.referenceTypeArguments(self.ptr, allocator); }
    pub inline fn referenceLocation(self: TracedType) ?Location { return self.vtable.referenceLocation(self.ptr); }
    pub inline fn reverseMappedSourceType(self: TracedType) ?TracedType { return self.vtable.reverseMappedSourceType(self.ptr); }
    pub inline fn reverseMappedMappedType(self: TracedType) ?TracedType { return self.vtable.reverseMappedMappedType(self.ptr); }
    pub inline fn reverseMappedConstraintType(self: TracedType) ?TracedType { return self.vtable.reverseMappedConstraintType(self.ptr); }
    pub inline fn evolvingArrayElementType(self: TracedType) ?TracedType { return self.vtable.evolvingArrayElementType(self.ptr); }
    pub inline fn evolvingArrayFinalType(self: TracedType) ?TracedType { return self.vtable.evolvingArrayFinalType(self.ptr); }
    pub inline fn isTuple(self: TracedType) bool { return self.vtable.isTuple(self.ptr); }
    pub inline fn destructuringPattern(self: TracedType) ?Location { return self.vtable.destructuringPattern(self.ptr); }
    pub inline fn recursionIdentity(self: TracedType) ?usize { return self.vtable.recursionIdentity(self.ptr); }
    pub inline fn display(self: TracedType, allocator: std.mem.Allocator) []const u8 { return self.vtable.display(self.ptr, allocator); }
};

pub const TraceRecord = struct {
    configFilePath: ?[]const u8 = null,
    tracePath: ?[]const u8 = null,
    typesPath: ?[]const u8 = null,
    checkerId: i32,
};

pub const TraceArgs = struct {
    name: ?[]const u8 = null,
    path: ?[]const u8 = null,
    fileName: ?[]const u8 = null,
    containingFileName: ?[]const u8 = null,
    jsFilePath: ?[]const u8 = null,
    declarationFilePath: ?[]const u8 = null,
    checkerId: ?i32 = null,
};

pub const TraceEvent = struct {
    pid: i32,
    tid: i32,
    ph: []const u8,
    cat: []const u8,
    ts: f64,
    name: ?[]const u8 = null,
    s: ?[]const u8 = null,
    dur: ?f64 = null,
    args: ?TraceArgs = null,
};

const sampleIntervalNs: i64 = 10 * std.time.ns_per_ms;
const traceFileName = "trace.json";

const mainThreadID = 1;
const firstSyntheticThreadID = 2;
const firstFileThreadID = 1_000_000;
const fileThreadIDHashRange = 1_000_000_000;

const flushThreshold = 256 * 1024;

pub const Phase = enum {
    parse,
    program,
    bind,
    check,
    checkTypes,
    emit,
    session,

    pub fn asString(self: Phase) []const u8 {
        return @tagName(self);
    }
};

const TraceThreadKind = enum {
    checker,
    file,
};

const TraceThreadKey = struct {
    kind: TraceThreadKind,
    text: []const u8 = "",
    index: i32 = 0,
    hasIndex: bool = false,

    pub fn defaultThreadID(self: TraceThreadKey) i32 {
        if (self.kind == .checker and self.hasIndex and self.index >= 0) {
            return firstSyntheticThreadID + self.index;
        }
        return stableTraceThreadID(self);
    }

    pub fn displayName(self: TraceThreadKey, allocator: std.mem.Allocator) ![]const u8 {
        if (self.hasIndex) {
            return std.fmt.allocPrint(allocator, "{s}:{d}", .{ @tagName(self.kind), self.index });
        }
        return std.fmt.allocPrint(allocator, "{s}:{s}", .{ @tagName(self.kind), self.text });
    }
    
    pub fn eql(a: TraceThreadKey, b: TraceThreadKey) bool {
        if (a.kind != b.kind) return false;
        if (a.hasIndex != b.hasIndex) return false;
        if (a.hasIndex and a.index != b.index) return false;
        if (!a.hasIndex and !std.mem.eql(u8, a.text, b.text)) return false;
        return true;
    }
};

fn stableTraceThreadID(key: TraceThreadKey) i32 {
    var hash = std.hash.Wyhash.init(0);
    hash.update(@tagName(key.kind));
    hash.update(":");
    if (key.hasIndex) {
        var buf: [32]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, "{d}", .{key.index}) catch "";
        hash.update(s);
    } else {
        hash.update(key.text);
    }
    return firstFileThreadID + @as(i32, @intCast(hash.final() % fileThreadIDHashRange));
}

fn traceThreadKeyFromArgs(args: ?TraceArgs) ?TraceThreadKey {
    if (args == null) return null;
    const a = args.?;
    
    if (a.checkerId) |id| {
        return TraceThreadKey{ .kind = .checker, .index = id, .hasIndex = true };
    }

    if (a.path) |p| return TraceThreadKey{ .kind = .file, .text = p };
    if (a.fileName) |p| return TraceThreadKey{ .kind = .file, .text = p };
    if (a.containingFileName) |p| return TraceThreadKey{ .kind = .file, .text = p };
    if (a.jsFilePath) |p| return TraceThreadKey{ .kind = .file, .text = p };
    if (a.declarationFilePath) |p| return TraceThreadKey{ .kind = .file, .text = p };

    return null;
}

const TraceThreadKeyContext = struct {
    pub fn hash(self: TraceThreadKeyContext, key: TraceThreadKey) u64 {
        _ = self;
        var h = std.hash.Wyhash.init(0);
        h.update(@tagName(key.kind));
        if (key.hasIndex) {
            h.update(std.mem.asBytes(&key.index));
        } else {
            h.update(key.text);
        }
        return h.final();
    }
    pub fn eql(self: TraceThreadKeyContext, a: TraceThreadKey, b: TraceThreadKey) bool {
        _ = self;
        return a.eql(b);
    }
};

pub const Tracing = struct {
    allocator: std.mem.Allocator,
    fs: *anyopaque, // placeholder for vfs.FS
    traceDir: []const u8,
    tracePath: []const u8,
    configFilePath: []const u8,
    legend: std.ArrayList(TraceRecord),
    tracers: std.ArrayList(*TypeTracer),
    traceContent: std.ArrayList(u8),
    traceStarted: std.atomic.Value(bool),
    threadIDs: std.HashMap(TraceThreadKey, i32, TraceThreadKeyContext, std.hash_map.default_max_load_percentage),
    threadKeys: std.AutoHashMap(i32, TraceThreadKey),
    metadataTS: f64,
    deterministic: bool,
    timestampCounter: u64,
    startTime: std.time.Instant,
    mu: std.Thread.Mutex,
    flushErr: ?anyerror,

    pub fn startTracing(allocator: std.mem.Allocator, fs: *anyopaque, traceDir: []const u8, configFilePath: []const u8, deterministic: bool) !*Tracing {
        var tr = try allocator.create(Tracing);
        
        const tracePathBuf = try std.fmt.allocPrint(allocator, "{s}/{s}", .{traceDir, traceFileName}); // basic combine for now
        
        tr.* = .{
            .allocator = allocator,
            .fs = fs,
            .traceDir = try allocator.dupe(u8, traceDir),
            .tracePath = tracePathBuf,
            .configFilePath = try allocator.dupe(u8, configFilePath),
            .legend = std.ArrayList(TraceRecord).init(allocator),
            .tracers = std.ArrayList(*TypeTracer).init(allocator),
            .traceContent = std.ArrayList(u8).init(allocator),
            .traceStarted = std.atomic.Value(bool).init(true),
            .threadIDs = std.HashMap(TraceThreadKey, i32, TraceThreadKeyContext, std.hash_map.default_max_load_percentage).init(allocator),
            .threadKeys = std.AutoHashMap(i32, TraceThreadKey).init(allocator),
            .metadataTS = 0,
            .deterministic = deterministic,
            .timestampCounter = 0,
            .startTime = std.time.Instant.now() catch unreachable,
            .mu = std.Thread.Mutex{},
            .flushErr = null,
        };

        try tr.traceContent.appendSlice("[\n");
        
        const metaTs = tr.timestamp();
        tr.metadataTS = metaTs;
        
        try tr.writeEvent(TraceEvent{
            .pid = 1, .tid = mainThreadID, .ph = "M", .cat = "__metadata", .ts = metaTs, .name = "process_name", 
            .args = TraceArgs{ .name = "tsgo" }
        });
        try tr.traceContent.appendSlice(",\n");
        
        try tr.writeEvent(TraceEvent{
            .pid = 1, .tid = mainThreadID, .ph = "M", .cat = "__metadata", .ts = metaTs, .name = "thread_name", 
            .args = TraceArgs{ .name = "Main" }
        });
        try tr.traceContent.appendSlice(",\n");
        
        try tr.writeEvent(TraceEvent{
            .pid = 1, .tid = mainThreadID, .ph = "M", .cat = "disabled-by-default-devtools.timeline", .ts = metaTs, .name = "TracingStartedInBrowser", 
        });

        // FS WriteFile placeholder: write tr.traceContent.items to tr.tracePath
        tr.traceContent.clearRetainingCapacity();

        return tr;
    }

    pub fn timestamp(self: *Tracing) f64 {
        if (self.deterministic) {
            self.timestampCounter += 1;
            return @floatFromInt(self.timestampCounter);
        }
        const now = std.time.Instant.now() catch unreachable;
        const dur = now.since(self.startTime);
        return @as(f64, @floatFromInt(dur)) / 1000.0;
    }

    fn writeEvent(self: *Tracing, event: TraceEvent) !void {
        try std.json.stringify(event, .{ .emit_null_optional_fields = false }, self.traceContent.writer());
    }

    fn maybeFlushLocked(self: *Tracing) void {
        if (self.flushErr != null) {
            self.traceContent.clearRetainingCapacity();
            return;
        }
        if (self.traceContent.items.len < flushThreshold) {
            return;
        }
        
        // FS AppendFile placeholder: append self.traceContent.items to self.tracePath
        // ... if error, self.flushErr = err;
        
        self.traceContent.clearRetainingCapacity();
    }

    pub fn instant(self: *Tracing, phase: Phase, name: []const u8, args: ?TraceArgs) void {
        if (!self.traceStarted.load(.seq_cst)) return;

        self.mu.lock();
        defer self.mu.unlock();

        if (!self.traceStarted.load(.seq_cst)) return;

        const ts = self.timestamp();
        const tid = self.threadIDLocked(args);
        
        self.traceContent.appendSlice(",\n") catch return;
        self.writeEvent(TraceEvent{
            .pid = 1, .tid = tid, .ph = "I", .cat = phase.asString(), .ts = ts, .name = name, .s = "g", .args = args
        }) catch return;
        self.maybeFlushLocked();
    }

    pub fn push(self: *Tracing, phase: Phase, name: []const u8, args: ?TraceArgs, separateBeginAndEnd: bool) PushHandle {
        if (!self.traceStarted.load(.seq_cst)) {
            return PushHandle{ .tr = null, .phase = phase, .name = name, .args = args, .startTime = 0, .tid = 0, .startMicros = 0, .separateBeginAndEnd = separateBeginAndEnd };
        }

        if (separateBeginAndEnd) {
            self.mu.lock();
            if (!self.traceStarted.load(.seq_cst)) {
                self.mu.unlock();
                return PushHandle{ .tr = null, .phase = phase, .name = name, .args = args, .startTime = 0, .tid = 0, .startMicros = 0, .separateBeginAndEnd = separateBeginAndEnd };
            }
            const ts = self.timestamp();
            const tid = self.threadIDLocked(args);
            self.traceContent.appendSlice(",\n") catch {};
            self.writeEvent(TraceEvent{
                .pid = 1, .tid = tid, .ph = "B", .cat = phase.asString(), .ts = ts, .name = name, .args = args
            }) catch {};
            self.maybeFlushLocked();
            self.mu.unlock();

            return PushHandle{ .tr = self, .phase = phase, .name = name, .args = args, .startTime = 0, .tid = tid, .startMicros = 0, .separateBeginAndEnd = separateBeginAndEnd };
        }

        if (self.deterministic) {
            return PushHandle{ .tr = null, .phase = phase, .name = name, .args = args, .startTime = 0, .tid = 0, .startMicros = 0, .separateBeginAndEnd = separateBeginAndEnd };
        }

        const startTime = std.time.Instant.now() catch unreachable;
        const startMicros = @as(f64, @floatFromInt(startTime.since(self.startTime))) / 1000.0;
        return PushHandle{ .tr = self, .phase = phase, .name = name, .args = args, .startTime = startTime.timestamp, .tid = 0, .startMicros = startMicros, .separateBeginAndEnd = separateBeginAndEnd };
    }

    fn threadIDLocked(self: *Tracing, args: ?TraceArgs) i32 {
        const key_opt = traceThreadKeyFromArgs(args);
        if (key_opt == null) return mainThreadID;
        const key = key_opt.?;

        if (self.threadIDs.get(key)) |tid| {
            return tid;
        }

        var tid = key.defaultThreadID();
        while (true) {
            if (self.threadKeys.get(tid)) |existingKey| {
                if (existingKey.eql(key)) break;
            } else {
                break;
            }
            tid += 1;
        }
        
        self.threadIDs.put(key, tid) catch unreachable;
        self.threadKeys.put(tid, key) catch unreachable;
        
        const dispName = key.displayName(self.allocator) catch "unknown";
        defer self.allocator.free(dispName);
        self.writeThreadNameEventLocked(tid, dispName);
        return tid;
    }

    fn writeThreadNameEventLocked(self: *Tracing, tid: i32, name: []const u8) void {
        self.traceContent.appendSlice(",\n") catch return;
        self.writeEvent(TraceEvent{
            .pid = 1, .tid = tid, .ph = "M", .cat = "__metadata", .ts = self.metadataTS, .name = "thread_name", 
            .args = TraceArgs{ .name = name }
        }) catch return;
    }

    pub fn newTypeTracer(self: *Tracing, checkerIndex: i32) !Tracer {
        self.mu.lock();
        defer self.mu.unlock();

        const typesPath = try std.fmt.allocPrint(self.allocator, "{s}/types_{d}.json", .{self.traceDir, checkerIndex});
        
        var typeTracer = try self.allocator.create(TypeTracer);
        typeTracer.* = .{
            .tr = self,
            .fs = self.fs,
            .checkerIndex = checkerIndex,
            .typesPath = typesPath,
            .types = std.ArrayList(TracedType).init(self.allocator),
            .mu = std.Thread.Mutex{},
        };
        
        try self.tracers.append(typeTracer);
        try self.legend.append(TraceRecord{
            .configFilePath = self.configFilePath,
            .tracePath = self.tracePath,
            .typesPath = typesPath,
            .checkerId = checkerIndex,
        });
        
        return typeTracer.tracer();
    }

    pub fn stopTracing(self: *Tracing) !void {
        for (self.tracers.items) |tracer| {
            tracer.dumpTypes() catch |err| {
                return err;
            };
        }

        self.mu.lock();
        defer self.mu.unlock();

        if (self.traceStarted.load(.seq_cst)) {
            if (self.flushErr) |err| {
                self.traceContent.clearRetainingCapacity();
                self.traceStarted.store(false, .seq_cst);
                return err;
            }
            
            self.traceContent.appendSlice("\n]\n") catch {};
            // FS AppendFile placeholder: append self.traceContent.items to self.tracePath
            
            self.traceContent.clearRetainingCapacity();
            self.traceStarted.store(false, .seq_cst);
        }

        // Write legend file
        const legendPath = try std.fmt.allocPrint(self.allocator, "{s}/legend.json", .{self.traceDir});
        defer self.allocator.free(legendPath);
        
        var legendData = std.ArrayList(u8).init(self.allocator);
        defer legendData.deinit();
        
        try std.json.stringify(self.legend.items, .{ .emit_null_optional_fields = false }, legendData.writer());
        // FS WriteFile placeholder: write legendData.items to legendPath
    }
};

pub const PushHandle = struct {
    tr: ?*Tracing,
    phase: Phase,
    name: []const u8,
    args: ?TraceArgs,
    startTime: i64,
    startMicros: f64,
    tid: i32,
    separateBeginAndEnd: bool,

    pub fn end(self: *PushHandle) void {
        const tr = self.tr orelse return;
        
        if (self.separateBeginAndEnd) {
            tr.mu.lock();
            defer tr.mu.unlock();
            if (!tr.traceStarted.load(.seq_cst)) return;
            const endTs = tr.timestamp();
            tr.traceContent.appendSlice(",\n") catch {};
            tr.writeEvent(TraceEvent{
                .pid = 1, .tid = self.tid, .ph = "E", .cat = self.phase.asString(), .ts = endTs, .name = self.name, .args = self.args
            }) catch {};
            tr.maybeFlushLocked();
            return;
        }

        const now = std.time.Instant.now() catch unreachable;
        const durNs = now.timestamp - self.startTime;
        const durMicros = @as(f64, @floatFromInt(durNs)) / 1000.0;
        
        const intervalMicros = @as(f64, @floatFromInt(sampleIntervalNs)) / 1000.0;
        if (intervalMicros - @mod(self.startMicros, intervalMicros) > durMicros) {
            return;
        }
        
        tr.mu.lock();
        defer tr.mu.unlock();
        if (!tr.traceStarted.load(.seq_cst)) return;
        
        const tid = tr.threadIDLocked(self.args);
        tr.traceContent.appendSlice(",\n") catch {};
        tr.writeEvent(TraceEvent{
            .pid = 1, .tid = tid, .ph = "X", .cat = self.phase.asString(), .ts = self.startMicros, .name = self.name, .dur = durMicros, .args = self.args
        }) catch {};
        tr.maybeFlushLocked();
    }
};

pub const TypeTracer = struct {
    tr: *Tracing,
    fs: *anyopaque,
    checkerIndex: i32,
    typesPath: []const u8,
    types: std.ArrayList(TracedType),
    mu: std.Thread.Mutex,

    pub fn tracer(self: *TypeTracer) Tracer {
        return Tracer{
            .ptr = self,
            .vtable = &.{
                .recordType = recordType,
                .dumpTypes = dumpTypes,
            },
        };
    }

    fn recordType(ptr: *anyopaque, t: TracedType) void {
        const self: *TypeTracer = @ptrCast(@alignCast(ptr));
        self.mu.lock();
        defer self.mu.unlock();
        self.types.append(t) catch unreachable;
    }

    fn dumpTypes(ptr: *anyopaque) !void {
        const self: *TypeTracer = @ptrCast(@alignCast(ptr));
        
        self.mu.lock();
        const types = try self.tr.allocator.dupe(TracedType, self.types.items);
        self.mu.unlock();

        if (types.len == 0) return;

        var sb = std.ArrayList(u8).init(self.tr.allocator);
        defer sb.deinit();
        
        try sb.appendSlice("[\n");

        var recursionIdentityMap = std.AutoHashMap(usize, i32).init(self.tr.allocator);
        defer recursionIdentityMap.deinit();

        for (types, 0..) |typ, i| {
            const descriptor = try self.buildTypeDescriptor(typ, &recursionIdentityMap);
            try std.json.stringify(descriptor, .{ .emit_null_optional_fields = false }, sb.writer());
            
            if (i < types.len - 1) {
                try sb.appendSlice(",\n");
            } else {
                try sb.appendSlice("\n");
            }
        }

        try sb.appendSlice("]\n");

        // FS WriteFile placeholder: write sb.items to self.typesPath
    }

    fn buildTypeDescriptor(self: *TypeTracer, typ: TracedType, recursionIdentityMap: *std.AutoHashMap(usize, i32)) !TypeDescriptor {
        var desc = TypeDescriptor{
            .id = typ.id(),
            .flags = typ.formatFlags(self.tr.allocator),
        };

        if (typ.recursionIdentity()) |identity| {
            var token: i32 = undefined;
            if (recursionIdentityMap.get(identity)) |t| {
                token = t;
            } else {
                token = @intCast(recursionIdentityMap.count());
                try recursionIdentityMap.put(identity, token);
            }
            desc.recursionId = token;
        }

        const intrinsicName = typ.intrinsicName(self.tr.allocator);
        if (intrinsicName.len > 0) {
            desc.intrinsicName = intrinsicName;
        }

        const aliasName = typ.aliasSymbolName(self.tr.allocator);
        if (aliasName.len > 0) {
            desc.symbolName = aliasName;
        } else {
            const symName = typ.symbolName(self.tr.allocator);
            if (symName.len > 0) {
                desc.symbolName = symName;
            }
        }

        if (typ.isTuple()) {
            desc.isTuple = true;
        }

        const uTypes = typ.unionTypes(self.tr.allocator);
        if (uTypes.len > 0) {
            desc.unionTypes = try self.mapTypeIds(uTypes);
        }
        
        const iTypes = typ.intersectionTypes(self.tr.allocator);
        if (iTypes.len > 0) {
            desc.intersectionTypes = try self.mapTypeIds(iTypes);
        }
        
        const aTypes = typ.aliasTypeArguments(self.tr.allocator);
        if (aTypes.len > 0) {
            desc.aliasTypeArguments = try self.mapTypeIds(aTypes);
        }

        if (typ.indexType()) |t| desc.keyofType = t.id();
        if (typ.indexedAccessObjectType()) |t| desc.indexedAccessObjectType = t.id();
        if (typ.indexedAccessIndexType()) |t| desc.indexedAccessIndexType = t.id();

        if (typ.isConditional()) {
            if (typ.conditionalCheckType()) |t| desc.conditionalCheckType = t.id();
            if (typ.conditionalExtendsType()) |t| desc.conditionalExtendsType = t.id();
            if (typ.conditionalTrueType()) |t| {
                desc.conditionalTrueType = @intCast(t.id());
            } else {
                desc.conditionalTrueType = -1;
            }
            if (typ.conditionalFalseType()) |t| {
                desc.conditionalFalseType = @intCast(t.id());
            } else {
                desc.conditionalFalseType = -1;
            }
        }

        if (typ.substitutionBaseType()) |t| desc.substitutionBaseType = t.id();
        if (typ.substitutionConstraintType()) |t| desc.constraintType = t.id();

        if (typ.referenceTarget()) |t| desc.instantiatedType = t.id();
        
        const rArgs = typ.referenceTypeArguments(self.tr.allocator);
        if (rArgs.len > 0) {
            desc.typeArguments = try self.mapTypeIds(rArgs);
        }
        
        desc.referenceLocation = typ.referenceLocation();

        if (typ.reverseMappedSourceType()) |t| desc.reverseMappedSourceType = t.id();
        if (typ.reverseMappedMappedType()) |t| desc.reverseMappedMappedType = t.id();
        if (typ.reverseMappedConstraintType()) |t| desc.reverseMappedConstraintType = t.id();

        if (typ.evolvingArrayElementType()) |t| desc.evolvingArrayElementType = t.id();
        if (typ.evolvingArrayFinalType()) |t| desc.evolvingArrayFinalType = t.id();

        desc.destructuringPattern = typ.destructuringPattern();
        desc.firstDeclaration = typ.firstDeclaration();

        const displayStr = typ.display(self.tr.allocator);
        if (displayStr.len > 0) {
            desc.display = displayStr;
        }

        return desc;
    }

    fn mapTypeIds(self: *TypeTracer, types: []TracedType) ![]u32 {
        var ids = try self.tr.allocator.alloc(u32, types.len);
        for (types, 0..) |t, i| {
            ids[i] = t.id();
        }
        return ids;
    }
};

pub const TypeDescriptor = struct {
    id: u32,
    intrinsicName: ?[]const u8 = null,
    symbolName: ?[]const u8 = null,
    recursionId: ?i32 = null,
    isTuple: ?bool = null,
    unionTypes: ?[]u32 = null,
    intersectionTypes: ?[]u32 = null,
    aliasTypeArguments: ?[]u32 = null,
    keyofType: ?u32 = null,
    indexedAccessObjectType: ?u32 = null,
    indexedAccessIndexType: ?u32 = null,
    conditionalCheckType: ?u32 = null,
    conditionalExtendsType: ?u32 = null,
    conditionalTrueType: ?i32 = null,
    conditionalFalseType: ?i32 = null,
    substitutionBaseType: ?u32 = null,
    constraintType: ?u32 = null,
    instantiatedType: ?u32 = null,
    typeArguments: ?[]u32 = null,
    referenceLocation: ?Location = null,
    reverseMappedSourceType: ?u32 = null,
    reverseMappedMappedType: ?u32 = null,
    reverseMappedConstraintType: ?u32 = null,
    evolvingArrayElementType: ?u32 = null,
    evolvingArrayFinalType: ?u32 = null,
    destructuringPattern: ?Location = null,
    firstDeclaration: ?Location = null,
    flags: [][]const u8,
    display: ?[]const u8 = null,
};

pub const Location = struct {
    path: []const u8,
    start: ?LineAndChar = null,
    end: ?LineAndChar = null,
};

pub const LineAndChar = struct {
    line: i32,
    character: i32,
};
