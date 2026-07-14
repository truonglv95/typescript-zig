const std = @import("std");
const api = @import("api");
const collections = @import("collections");
const core = @import("core");
const diagnostics = @import("diagnostics");
const fswatch = @import("fswatch");
const json = @import("json");
const jsonrpc = @import("jsonrpc");
const locale = @import("locale");
const ls = @import("ls");
const lsconv = @import("lsconv");
const lsutil = @import("lsutil");
const lsproto = @import("lsproto");
const lspwatcher = @import("lspwatcher");

pub fn DynamicQueue(comptime T: type) type {
    return struct {
        list: std.ArrayList(T),
        pub fn init(alloc: std.mem.Allocator) !*@This() {
            const q = try alloc.create(@This());
            q.list = std.ArrayList(T).init(alloc);
            return q;
        }
        pub fn put(self: *@This(), ctx: anytype, item: T) !void {
            _ = ctx;
            try self.list.append(item);
        }
        pub fn get(self: *@This(), ctx: anytype) !T {
            _ = ctx;
            return self.list.pop();
        }
    };
}

const ServerRequestChan = struct {
    result: ?json.Value = null,
    @"error": ?anyerror = null,
    
    pub fn init() ServerRequestChan {
        return .{};
    }
    pub fn deinit(self: *ServerRequestChan) void {
        _ = self;
    }
    pub fn recv(self: *ServerRequestChan, ctx: anytype) !*lsproto.ResponseMessage {
        _ = self; _ = ctx;
        return undefined;
    }
    pub fn send(self: *ServerRequestChan, resp: *lsproto.ResponseMessage) void {
        _ = self; _ = resp;
    }
};

const ProjectLoadingProgress = struct {
    pub fn start(self: *@This(), message: *diagnostics.Message, args: anytype) void {
        _ = self; _ = message; _ = args;
    }
    pub fn finish(self: *@This(), message: *diagnostics.Message, args: anytype) void {
        _ = self; _ = message; _ = args;
    }
};
pub fn newProjectLoadingProgress(s: *Server, delay: u64) !*ProjectLoadingProgress {
    _ = s; _ = delay;
    return undefined;
}

const WaitGroup = struct {
    pub fn init() !WaitGroup { return .{}; }
};

const Logger = struct {
    pub fn logf(self: *Logger, comptime fmt: []const u8, args: anytype) void { _ = self; _ = fmt; _ = args; }
    pub fn errorf(self: *Logger, comptime fmt: []const u8, args: anytype) void { _ = self; _ = fmt; _ = args; }
    pub fn warnf(self: *Logger, comptime fmt: []const u8, args: anytype) void { _ = self; _ = fmt; _ = args; }
    pub fn info(self: *Logger, comptime fmt: []const u8, args: anytype) void { _ = self; _ = fmt; _ = args; }
    pub fn setVerbosity(self: *Logger, v: anytype) void { _ = self; _ = v; }
};
pub fn newLogger(s: *Server, alloc: std.mem.Allocator) !*Logger {
    _ = s; _ = alloc; return undefined;
}

const pprof = @import("pprof");
const project = @import("project");
const ata = @import("ata");
const tspath = @import("tspath");
const vfs = @import("vfs");

pub const ServerOptions = struct {
    in: Reader,
    out: Writer,
    err: std.fs.File.Writer,

    cwd: []const u8,
    fs: *vfs.FS,
    default_library_path: []const u8,
    typings_location: []const u8,
    parse_cache: ?*project.ParseCache,
    npm_install: ?*const fn (cwd: []const u8, args: [][]const u8) anyerror![]const u8,
    progress_delay: u64, // delay before showing progress UI; 0 means no delay
    set_parent_process_id: ?*const fn (parent_pid: i32) void,
};

pub fn newServer(opts: *const ServerOptions, allocator: std.mem.Allocator) !*Server {
    if (opts.cwd.len == 0) {
        @panic("Cwd is required");
    }

    const s = try allocator.create(Server);
    s.* = Server{
        .r = opts.in,
        .w = opts.out,
        .stderr = opts.err,
        .request_queue = try DynamicQueue(*lsproto.RequestMessage).init(allocator),
        .outgoing_queue = try DynamicQueue(*lsproto.Message).init(allocator),
        .pending_client_requests = std.AutoHashMap(jsonrpc.ID, PendingClientRequest).init(allocator),
        .pending_server_requests = std.AutoHashMap(jsonrpc.ID, *ServerRequestChan).init(allocator),
        .cwd = try allocator.dupe(u8, opts.cwd),
        .fs = opts.fs,
        .default_library_path = try allocator.dupe(u8, opts.default_library_path),
        .typings_location = try allocator.dupe(u8, opts.typings_location),
        .parse_cache = opts.parse_cache,
        .npm_install = opts.npm_install,
        .start_watchdog = opts.set_parent_process_id,
        .init_complete = try WaitGroup.init(),
        .progress_delay = opts.progress_delay,
        .allocator = allocator,
    };
    s.logger = try newLogger(s, allocator);

    return s;
}

pub const file_rename_filters = [_]lsproto.FileOperationFilter{
    .{
        .scheme = "file",
        .pattern = .{
            .glob = "**/*.{ts,tsx,js,jsx,cts,cjs,mts,mjs,json}",
        },
    },
};

pub const PendingClientRequest = struct {
    req: *lsproto.RequestMessage,
    cancel: *const fn () void,
};

pub const Reader = struct {
    ptr: *anyopaque,
    readFn: *const fn (ptr: *anyopaque) anyerror!*lsproto.Message,

    pub fn read(self: Reader) !*lsproto.Message {
        return self.readFn(self.ptr);
    }
};

pub const Writer = struct {
    ptr: *anyopaque,
    writeFn: *const fn (ptr: *anyopaque, msg: *lsproto.Message) anyerror!void,

    pub fn write(self: Writer, msg: *lsproto.Message) !void {
        return self.writeFn(self.ptr, msg);
    }
};

pub const LspReader = struct {
    r: *lsproto.BaseReader,

    pub fn read(self: *LspReader) !*lsproto.Message {
        const data = try self.r.read();
        const req = try json.unmarshal(lsproto.Message, data);
        return req;
    }

    pub fn reader(self: *LspReader) Reader {
        return .{
            .ptr = self,
            .readFn = struct {
                fn wrapper(ptr: *anyopaque) !*lsproto.Message {
                    const self_ptr: *LspReader = @ptrCast(@alignCast(ptr));
                    return self_ptr.read();
                }
            }.wrapper,
        };
    }
};

pub fn toReader(r: anytype) Reader {
    _ = r;
    unreachable;
}

pub const LspWriter = struct {
    w: *lsproto.BaseWriter,

    pub fn write(self: *LspWriter, msg: *lsproto.Message) !void {
        const data = try json.marshal(msg);
        try self.w.write(data);
    }

    pub fn writer(self: *LspWriter) Writer {
        return .{
            .ptr = self,
            .writeFn = struct {
                fn wrapper(ptr: *anyopaque, msg: *lsproto.Message) !void {
                    const self_ptr: *LspWriter = @ptrCast(@alignCast(ptr));
                    return self_ptr.write(msg);
                }
            }.wrapper,
        };
    }
};

pub fn toWriter(w: anytype) Writer {
    _ = w;
    unreachable;
}

pub const Server = struct {
    r: Reader,
    w: Writer,
    background_ctx: ?*anyopaque,

    stderr: std.fs.File.Writer,

    logger: *Logger,
    init_started: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    client_seq: std.atomic.Value(i32) = std.atomic.Value(i32).init(0),
    request_queue: *DynamicQueue(*lsproto.RequestMessage),
    outgoing_queue: *DynamicQueue(*lsproto.Message),
    pending_client_requests: std.AutoHashMap(jsonrpc.ID, PendingClientRequest),
    pending_client_requests_mu: std.Thread.Mutex = .{},
    pending_server_requests: std.AutoHashMap(jsonrpc.ID, *ServerRequestChan),
    pending_server_requests_mu: std.Thread.Mutex = .{},

    cwd: []const u8,
    fs: *vfs.FS,
    default_library_path: []const u8,
    typings_location: []const u8,

    initialize_params: ?*lsproto.InitializeParams = null,
    initialization_options: ?*lsproto.InitializationOptions = null,
    client_capabilities: lsproto.ResolvedClientCapabilities = undefined,
    position_encoding: lsproto.PositionEncodingKind = undefined,
    locale: ?locale.Locale = null,

    watch_enabled: bool = false,
    telemetry_enabled: bool = false,
    watcher_id: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    watchers: collections.SyncSet(project.WatcherID),

    builtin_watcher: ?*lspwatcher.Watcher = null,

    last_request_time_ms: std.atomic.Value(i64) = std.atomic.Value(i64).init(0),

    session_: ?*project.Session = null,

    api_sessions: std.StringHashMap(*api.Session),
    api_sessions_mu: std.Thread.Mutex = .{},

    client: ?*project.Client = null,

    init_complete: WaitGroup,

    compiler_options_for_inferred_projects: ?*core.CompilerOptions = null,
    parse_cache: ?*project.ParseCache = null,

    npm_install: ?*const fn (cwd: []const u8, args: [][]const u8) anyerror![]const u8 = null,

    cpu_profiler: ?*pprof.CPUProfiler = null,

    progress_delay: u64 = 0,
    project_progress: ?*ProjectLoadingProgress = null,

    start_watchdog: ?*const fn (parent_pid: i32) void = null,

    allocator: std.mem.Allocator,

    pub fn session(self: *Server) ?*project.Session {
        return self.session_;
    }

    pub fn initComplete(self: *Server) *WaitGroup {
        return &self.init_complete;
    }

    pub fn watchFiles(self: *Server, ctx: anytype, id: project.WatcherID, watchers_list: []const *lsproto.FileSystemWatcher) !void {
        if (self.builtin_watcher) |bw| {
            try bw.watchFiles(id, watchers_list);
            try self.watchers.add(id);
            return;
        }

        const registration = lsproto.Registration{
            .id = id,
            .registerOptions = .{
                .workspaceDidChangeWatchedFiles = .{
                    .watchers = watchers_list,
                },
            },
        };
        const params = lsproto.RegistrationParams{
            .registrations = &[_]lsproto.Registration{registration},
        };

        _ = try sendClientRequest(ctx, self, lsproto.ClientRegisterCapabilityInfo, &params);
        try self.watchers.add(id);
    }

    pub fn unwatchFiles(self: *Server, ctx: anytype, id: project.WatcherID) !void {
        if (self.builtin_watcher) |bw| {
            if (!self.watchers.has(id)) {
                return error.NoFileWatcherExists;
            }
            try bw.unwatchFiles(id);
            self.watchers.delete(id);
            return;
        }

        if (self.watchers.has(id)) {
            const unregistration = lsproto.Unregistration{
                .id = id,
                .method = lsproto.MethodWorkspaceDidChangeWatchedFiles,
            };
            const params = lsproto.UnregistrationParams{
                .unregisterations = &[_]lsproto.Unregistration{unregistration},
            };

            _ = try sendClientRequest(ctx, self, lsproto.ClientUnregisterCapabilityInfo, &params);
            self.watchers.delete(id);
            return;
        }

        return error.NoFileWatcherExists;
    }

    pub fn refreshDiagnostics(self: *Server, ctx: anytype) !void {
        _ = ctx;
        if (!self.client_capabilities.workspace.diagnostics.refreshSupport) {
            return;
        }

        try sendClientRequestFireAndForget(self, lsproto.WorkspaceDiagnosticRefreshInfo, lsproto.NoParams{});
    }

    pub fn publishDiagnostics(self: *Server, ctx: anytype, params: *lsproto.PublishDiagnosticsParams) !void {
        _ = ctx;
        return sendNotification(self, lsproto.TextDocumentPublishDiagnosticsInfo, params);
    }

    pub fn sendTelemetry(self: *Server, ctx: anytype, telemetry: lsproto.TelemetryEvent) !void {
        _ = ctx;
        if (!self.telemetry_enabled) {
            @panic("SendTelemetry called with telemetry disabled");
        }
        return sendNotification(self, lsproto.TelemetryEventInfo, telemetry);
    }

    pub fn isActive(self: *Server) bool {
        const last = self.last_request_time_ms.load(.monotonic);
        if (last == 0) return true;
        return (std.time.milliTimestamp() - last) <= std.time.ns_per_min / std.time.ns_per_ms;
    }

    pub fn refreshInlayHints(self: *Server, ctx: anytype) !void {
        _ = ctx;
        if (!self.client_capabilities.workspace.inlayHint.refreshSupport) {
            return;
        }

        try sendClientRequestFireAndForget(self, lsproto.WorkspaceInlayHintRefreshInfo, lsproto.NoParams{});
    }

    pub fn refreshCodeLens(self: *Server, ctx: anytype) !void {
        _ = ctx;
        if (!self.client_capabilities.workspace.codeLens.refreshSupport) {
            return;
        }

        try sendClientRequestFireAndForget(self, lsproto.WorkspaceCodeLensRefreshInfo, lsproto.NoParams{});
    }

    pub fn progressStart(self: *Server, message: *diagnostics.Message, args: anytype) void {
        if (self.project_progress) |pp| {
            pp.start(message, args);
        }
    }

    pub fn progressFinish(self: *Server, message: *diagnostics.Message, args: anytype) void {
        if (self.project_progress) |pp| {
            pp.finish(message, args);
        }
    }

    pub fn requestConfiguration(self: *Server, ctx: anytype) !lsutil.UserPreferences {
        const caps = lsproto.getClientCapabilities(ctx);
        if (!caps.workspace.configuration) {
            if (self.initialization_options) |opts| {
                if (opts.userPreferences) |user_prefs| {
                    self.logger.logf("received formatting options from initialization: \n{any}", .{user_prefs});
                    // Simplified since type checking in Zig differs
                    return lsutil.parseUserPreferences(user_prefs);
                }
            }
            return lsutil.UserPreferences.initDefault();
        }

        const items = [_]lsproto.ConfigurationItem{
            .{ .section = "js/ts" },
            .{ .section = "typescript" },
            .{ .section = "javascript" },
            .{ .section = "editor" },
        };
        const params = lsproto.ConfigurationParams{ .items = &items };

        const configs = try sendClientRequest(ctx, self, lsproto.WorkspaceConfigurationInfo, &params);
        var config_map = std.StringHashMap(json.Value).init(self.allocator);
        for (configs, 0..) |config, i| {
            const key = switch (i) {
                0 => "js/ts",
                1 => "typescript",
                2 => "javascript",
                3 => "editor",
                else => unreachable,
            };
            try config_map.put(key, config);
        }
        self.logger.logf("received options from workspace/configuration request:\njs/ts: {any}\n\ntypescript: {any}\n\njavascript: {any}\n\neditor: {any}\n", .{
            config_map.get("js/ts"),
            config_map.get("typescript"),
            config_map.get("javascript"),
            config_map.get("editor"),
        });

        return lsutil.parseUserPreferencesMap(config_map);
    }

    pub fn run(self: *Server, ctx: anytype) !void {
        self.background_ctx = ctx;
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        var pool = std.Thread.Pool{};
        try pool.init(.{ .allocator = self.allocator });
        defer pool.deinit();

        // Very simplified goroutine equivalent logic
        // This is a placeholder since errgroup semantics in Zig require more setup.
    }

    pub fn readLoop(self: *Server, ctx: anytype) !void {
        while (true) {
            // Check context cancellation in Zig usually requires checking atomic bools or channels.
            const msg = try self.read();
            // Handle parsing msg kind, initialize handling, request queueing, etc.
            if (msg.kind == .request) {
                if (self.initialize_params == null) {
                    if (std.mem.eql(u8, msg.asRequest().method, lsproto.MethodInitialize)) {
                        const params = msg.asRequest().params.?;
                        const resp = try self.handleInitialize(ctx, params, msg.asRequest());
                        try self.sendResult(msg.asRequest().id, resp);
                    } else {
                        try self.sendError(msg.asRequest().id, lsproto.ErrorCodeServerNotInitialized);
                    }
                    continue;
                }
            } else if (msg.kind == .response) {
                const resp = msg.asResponse();
                self.pending_server_requests_mu.lock();
                defer self.pending_server_requests_mu.unlock();
                if (self.pending_server_requests.get(resp.id.*)) |resp_chan| {
                    resp_chan.send(resp);
                    _ = self.pending_server_requests.remove(resp.id.*);
                }
            } else {
                const req = msg.asRequest();
                if (std.mem.eql(u8, req.method, lsproto.MethodCancelRequest)) {
                    self.cancelRequest(req.params.?.id);
                } else {
                    try self.request_queue.put(ctx, req);
                }
            }
        }
    }

    pub fn cancelRequest(self: *Server, raw_id: lsproto.IntegerOrString) void {
        const id = lsproto.newID(raw_id);
        self.pending_client_requests_mu.lock();
        defer self.pending_client_requests_mu.unlock();
        if (self.pending_client_requests.get(id)) |pending_req| {
            pending_req.cancel();
            _ = self.pending_client_requests.remove(id);
        }
    }

    pub fn read(self: *Server) !*lsproto.Message {
        return self.r.read();
    }

    pub fn dispatchLoop(self: *Server, ctx: anytype) !void {
        while (true) {
            const req = try self.request_queue.get(ctx);
            self.last_request_time_ms.store(std.time.milliTimestamp(), .monotonic);

            const do_async_work = try self.handleRequestOrNotification(ctx, req);
            if (do_async_work) |workFn| {
                // Should run asynchronously
                try workFn();
            }
        }
    }

    pub fn writeLoop(self: *Server, ctx: anytype) !void {
        while (true) {
            const msg = try self.outgoing_queue.get(ctx);
            try self.w.write(msg);
        }
    }
};

pub fn sendClientRequest(comptime InfoType: type, ctx: anytype, s: *Server, info: InfoType, params: anytype) anyerror!InfoType.ResponseType {
    const id = jsonrpc.NewIDString(std.fmt.allocPrint(s.allocator, "ts{d}", .{s.client_seq.fetchAdd(1, .monotonic) + 1}) catch unreachable);
    const req = info.newRequestMessage(id, params);
    
    var response_chan = ServerRequestChan.init();
    
    s.pending_server_requests_mu.lock();
    try s.pending_server_requests.put(id, &response_chan);
    s.pending_server_requests_mu.unlock();

    defer {
        s.pending_server_requests_mu.lock();
        if (s.pending_server_requests.get(id)) |ch| {
            ch.deinit();
            _ = s.pending_server_requests.remove(id);
        }
        s.pending_server_requests_mu.unlock();
    }

    try s.send(req.message());

    const resp = try response_chan.recv(ctx);
    if (resp.@"error") |_| {
        return error.RequestFailed;
    }
    return info.unmarshalResult(resp.result);
}

pub fn sendClientRequestFireAndForget(s: *Server, info: anytype, params: anytype) !void {
    const id = jsonrpc.NewIDString(std.fmt.allocPrint(s.allocator, "ts{d}", .{s.client_seq.fetchAdd(1, .monotonic) + 1}) catch unreachable);
    const req = info.newRequestMessage(id, params);
    return s.send(req.message());
}

pub fn sendResult(s: *Server, id: ?jsonrpc.ID, result: anytype) !void {
    const resp = lsproto.ResponseMessage{
        .id = id,
        .result = result,
    };
    return s.sendResponse(&resp);
}

const UserFacingRequestFailedError = error{UserFacingRequestFailedError};

pub fn sendError(s: *Server, id: ?jsonrpc.ID, err: anyerror) !void {
    if (id == null and err != error.ErrorCodeInvalidRequest) {
        s.logger.errorf("error handling notification: {s}", .{@errorName(err)});
        return;
    }
    const code: i32 = -32603; // InternalError
    // Handle error codes ...
    
    const resp = lsproto.ResponseMessage{
        .id = id,
        .@"error" = .{
            .code = code,
            .message = @errorName(err),
        },
    };
    return s.sendResponse(&resp);
}

pub fn sendNotification(s: *Server, info: anytype, params: anytype) !void {
    return s.send(info.newNotificationMessage(params).message());
}

pub fn sendResponse(s: *Server, resp: *const lsproto.ResponseMessage) !void {
    // In Zig, we usually marshal the message
    return s.send(resp.message());
}

pub fn send(s: *Server, msg: *lsproto.Message) !void {
    return s.outgoing_queue.put(s.background_ctx, msg);
}

pub fn handleRequestOrNotification(s: *Server, ctx: anytype, req: *lsproto.RequestMessage) !?*const fn () anyerror!void {
    if (handlers.get(req.method)) |handler| {
        const start = std.time.milliTimestamp();
        _ = start;
        const do_async_work_or_err = handler(s, ctx, req);
        if (do_async_work_or_err) |do_async_work| {
            return struct {
                fn wrapper() !void {
                    const async_err = do_async_work();
                    // logging ...
                    return async_err;
                }
            }.wrapper;
        } else |err| {
            s.logger.errorf("error handling method '{s}': {s}", .{req.method, @errorName(err)});
            return err;
        }
    }
    s.logger.warnf("unknown method '{s}'", .{req.method});
    if (req.id != null) {
        return s.sendError(req.id, error.ErrorCodeInvalidRequest);
    }
    return null;
}

const HandlerFn = *const fn (*Server, anytype, *lsproto.RequestMessage) anyerror!?*const fn () anyerror!void;
const HandlerMap = std.StringHashMap(HandlerFn);

var handlers_init_once = std.once(initHandlers);
var handlers: HandlerMap = undefined;

fn initHandlers() void {
    handlers = HandlerMap.init(std.heap.page_allocator); // use global allocator for simplicity in this port
    // Simplified registration...
    // registerRequestHandler(&handlers, lsproto.InitializeInfo, Server.handleInitialize);
    // ...
}

pub fn registerNotificationHandler(handlers_map: *HandlerMap, info: anytype, fn_ptr: anytype) void {
    _ = fn_ptr;
    const handler = struct {
        fn wrapper(s: *Server, ctx: anytype, req: *lsproto.RequestMessage) anyerror!?*const fn () anyerror!void {
            _ = ctx;
            if (s.session == null and !std.mem.eql(u8, req.method, lsproto.MethodInitialized)) {
                return error.ErrorCodeServerNotInitialized;
            }
            // ...
            return null;
        }
    }.wrapper;
    handlers_map.put(info.method, handler) catch unreachable;
}

pub fn registerLanguageServiceDocumentRequestHandler(handlers_map: *HandlerMap, info: anytype, fn_ptr: anytype) void {
    _ = fn_ptr;
    // simplified registration for language service document
    const handler = struct {
        fn wrapper(s: *Server, ctx: anytype, req: *lsproto.RequestMessage) anyerror!?*const fn () anyerror!void {
            _ = s; _ = ctx; _ = req;
            const params: ?*anyopaque = null; // simulate reflection/typing
            _ = params;
            // ...
            return null;
        }
    }.wrapper;
    handlers_map.put(info.method, handler) catch unreachable;
}

pub fn registerLanguageServiceWithAutoImportsRequestHandler(handlers_map: *HandlerMap, info: anytype, fn_ptr: anytype) void {
    _ = fn_ptr;
    const handler = struct {
        fn wrapper(s: *Server, ctx: anytype, req: *lsproto.RequestMessage) anyerror!?*const fn () anyerror!void {
            _ = s; _ = ctx; _ = req;
            return null;
        }
    }.wrapper;
    handlers_map.put(info.method, handler) catch unreachable;
}

pub fn registerMultiProjectReferenceRequestHandler(handlers_map: *HandlerMap, info: anytype, fn_ptr: anytype) void {
    _ = fn_ptr;
    const handler = struct {
        fn wrapper(s: *Server, ctx: anytype, req: *lsproto.RequestMessage) anyerror!?*const fn () anyerror!void {
            _ = s; _ = ctx; _ = req;
            return null;
        }
    }.wrapper;
    handlers_map.put(info.method, handler) catch unreachable;
}

pub const CrossProjectOrchestrator = struct {
    server: *Server,
    req: *lsproto.RequestMessage,
    default_project: *project.Project,
    all_projects: []ls.Project,

    pub fn getDefaultProject(self: *CrossProjectOrchestrator) ls.Project {
        return self.default_project;
    }

    pub fn getAllProjectsForInitialRequest(self: *CrossProjectOrchestrator) []ls.Project {
        return self.all_projects;
    }

    pub fn getLanguageServiceForProjectWithFile(self: *CrossProjectOrchestrator, ctx: anytype, p: ls.Project, uri: lsproto.DocumentUri) *ls.LanguageService {
        return self.server.session.?.getLanguageServiceForProjectWithFile(ctx, p, uri);
    }

    pub fn getProjectsForFile(self: *CrossProjectOrchestrator, ctx: anytype, uri: lsproto.DocumentUri) ![]ls.Project {
        return self.server.session.?.getProjectsForFile(ctx, uri);
    }
};

pub fn getLanguageServiceAndCrossProjectOrchestrator(self: *Server, ctx: anytype, uri: lsproto.DocumentUri, req: *lsproto.RequestMessage) !struct { *ls.LanguageService, *CrossProjectOrchestrator } {
    const res = try self.session.?.getLanguageServiceAndProjectsForFile(ctx, uri);
    const orchestrator = try self.allocator.create(CrossProjectOrchestrator);
    orchestrator.* = .{
        .server = self,
        .req = req,
        .default_project = res.defaultProject,
        .all_projects = res.allProjects,
    };
    return .{ res.defaultLs, orchestrator };
}

pub fn recoverPanic(self: *Server, req: *lsproto.RequestMessage) void {
    _ = self; _ = req;
    // Zig panic handling is different, typically done via panic handler.
    // This function can serve as an explicit recover if using a custom panic mechanism.
}

pub fn handleInitialize(self: *Server, ctx: anytype, params: *lsproto.InitializeParams, _: *lsproto.RequestMessage) !*lsproto.InitializeResult {
    _ = ctx;
    if (self.initialize_params != null) {
        return error.ErrorCodeInvalidRequest;
    }

    self.init_started.store(true, .monotonic);
    self.initialize_params = params;

    if (params.initializationOptions) |opts| {
        if (opts.initializationOptions) |io| {
            self.initialization_options = io;
        } else {
            self.initialization_options = &lsproto.InitializationOptions{};
        }
    } else {
        self.initialization_options = &lsproto.InitializationOptions{};
    }

    if (self.initialization_options.?.logVerbosity) |v| {
        // Assume isValidLogVerbosity is defined elsewhere
        self.logger.setVerbosity(v);
    }

    self.client_capabilities = params.capabilities.resolve();
    if (self.client_capabilities.window.workDoneProgress) {
        self.project_progress = try newProjectLoadingProgress(self, self.progress_delay);
    }

    const capabilitiesJSON = try json.marshalIndent(self.client_capabilities, "", "\t");
    self.logger.info("Resolved client capabilities: {s}", .{capabilitiesJSON});

    self.position_encoding = lsproto.PositionEncodingKindUTF16;
    for (self.client_capabilities.general.positionEncodings) |enc| {
        if (enc == lsproto.PositionEncodingKindUTF8) {
            self.position_encoding = lsproto.PositionEncodingKindUTF8;
            break;
        }
    }

    if (self.initialize_params.?.locale) |loc| {
        self.locale = locale.parse(loc) catch null;
    }

    if (self.start_watchdog) |wd| {
        if (params.processId.integer) |pid| {
            wd(@intCast(pid));
        }
    }

    const response = try self.allocator.create(lsproto.InitializeResult);
    // Setting up capabilities... (Simplified to avoid too many lines)
    response.* = .{
        .serverInfo = .{
            .name = "typescript-go",
            .version = try core.Version.init(self.allocator),
        },
        .capabilities = .{
            .positionEncoding = &self.position_encoding,
            .textDocumentSync = .{
                .options = .{
                    .openClose = true,
                    .change = lsproto.TextDocumentSyncKindIncremental,
                    .save = .{ .boolean = true },
                },
            },
            // Add other capabilities as needed...
        },
    };

    return response;
}

pub fn handleInitialized(self: *Server, ctx: anytype, params: *lsproto.InitializedParams) !void {
    _ = ctx; _ = params;
    var disable_push_diagnostics = false;
    var enable_telemetry = false;
    if (self.initialization_options.?.disablePushDiagnostics) |d| {
        disable_push_diagnostics = d;
    }
    if (self.initialization_options.?.enableTelemetry) |t| {
        enable_telemetry = t;
    }
    const has_dynamic_watch_registration = self.client_capabilities.workspace.didChangeWatchedFiles.dynamicRegistration;

    if (has_dynamic_watch_registration) {
        self.logger.logf("file watching: using LSP client-side watching (client supports dynamic registration)", .{});
        self.watch_enabled = true;
    } else if (fswatch.default().hasFastRecursiveBackend()) {
        self.logger.logf("file watching: using builtin in-process watcher (client lacks dynamic watch registration)", .{});
        self.watch_enabled = true;
        self.builtin_watcher = lspwatcher.new(self.fs, struct {
            fn callback(s: *Server, changes: []*lsproto.FileEvent) void {
                if (s.session) |sess| {
                    sess.didChangeWatchedFiles(s.background_ctx, changes);
                }
            }
        }.callback, self.logger);
    } else {
        self.logger.logf("file watching: disabled (client lacks dynamic watch registration and builtin watcher backend is not fast-recursive)", .{});
    }

    // Omitted CWD logic and other session initializations for brevity...

    self.telemetry_enabled = enable_telemetry;
    
    // Note: Session and configuration init are omitted for brevity in porting
    // self.session = ...
    // self.session.?.initializeWithUserConfig(user_preferences);
}

pub fn handleShutdown(self: *Server, ctx: anytype, _: lsproto.NoParams, _: *lsproto.RequestMessage) !lsproto.ShutdownResponse {
    _ = ctx;
    if (self.builtin_watcher) |bw| {
        bw.close();
    }
    if (self.session) |sess| {
        sess.close();
    }
    return lsproto.ShutdownResponse{};
}

pub fn handleExit(self: *Server, ctx: anytype, _: lsproto.NoParams) !void {
    _ = self; _ = ctx;
    return error.EOF;
}

pub fn handleDidChangeWorkspaceConfiguration(self: *Server, ctx: anytype, params: *lsproto.DidChangeConfigurationParams) !void {
    _ = ctx;
    if (params.settings) |settings_val| {
        // Simplified parse logic
        self.session.?.configure(lsutil.parseUserPreferences(settings_val));
    }
}

pub fn handleDidOpen(self: *Server, ctx: anytype, params: *lsproto.DidOpenTextDocumentParams) !void {
    self.session.?.didOpenFile(ctx, params.textDocument.uri, params.textDocument.version, params.textDocument.text, params.textDocument.languageId);
}

pub fn handleDidChange(self: *Server, ctx: anytype, params: *lsproto.DidChangeTextDocumentParams) !void {
    self.session.?.didChangeFile(ctx, params.textDocument.uri, params.textDocument.version, params.contentChanges);
}

pub fn handleDidSave(self: *Server, ctx: anytype, params: *lsproto.DidSaveTextDocumentParams) !void {
    self.session.?.didSaveFile(ctx, params.textDocument.uri);
}

pub fn handleDidClose(self: *Server, ctx: anytype, params: *lsproto.DidCloseTextDocumentParams) !void {
    self.session.?.didCloseFile(ctx, params.textDocument.uri);
}

pub fn handleDidChangeWatchedFiles(self: *Server, ctx: anytype, params: *lsproto.DidChangeWatchedFilesParams) !void {
    self.session.?.didChangeWatchedFiles(ctx, params.changes);
}

pub fn handleSetTrace(self: *Server, ctx: anytype, params: *lsproto.SetTraceParams) !void {
    _ = self; _ = ctx; _ = params;
}

pub fn handleSetLogVerbosity(self: *Server, ctx: anytype, params: *lsproto.SetLogVerbosityParams) !void {
    _ = ctx;
    // Check if params.verbosity is valid
    self.logger.setVerbosity(params.verbosity);
}

pub fn handleDocumentDiagnostic(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.DocumentDiagnosticParams) !lsproto.DocumentDiagnosticResponse {
    _ = self;
    return language_service.provideDiagnostics(ctx, params.textDocument.uri);
}

pub fn handleHover(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.HoverParams) !lsproto.HoverResponse {
    _ = self;
    return language_service.provideHover(ctx, params);
}

pub fn handlePrepareRename(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.PrepareRenameParams) !lsproto.PrepareRenameResponse {
    _ = self;
    const info = language_service.getRenameInfo(ctx, "", params.textDocument.uri, params.position);
    if (!info.canRename) {
        return error.UserFacingRequestFailedError;
    }
    return lsproto.PrepareRenameResponse{
        .prepareRenamePlaceholder = .{
            .range = info.triggerSpan,
            .placeholder = info.displayName,
        },
    };
}

pub fn handleRename(self: *Server, ctx: anytype, params: *lsproto.RenameParams, req: *lsproto.RequestMessage) !lsproto.RenameResponse {
    const res = try self.getLanguageServiceAndCrossProjectOrchestrator(ctx, params.textDocument.uri, req);
    const default_ls = res[0];
    const orchestrator = res[1];

    const info = default_ls.getRenameInfo(ctx, params.newName, params.textDocument.uri, params.position);
    if (info.canRename and info.fileToRename.len > 0) {
        // Simple logic block ...
        return lsproto.RenameResponse{};
    }

    return default_ls.provideRename(ctx, params, orchestrator);
}

pub fn handleWillRenameFiles(self: *Server, ctx: anytype, params: *lsproto.RenameFilesParams, msg: *lsproto.RequestMessage) !lsproto.WillRenameFilesResponse {
    return self.handleWillRenameFilesWorker(ctx, params, msg, false);
}

pub fn handleWillRenameFilesWorker(self: *Server, ctx: anytype, params: *lsproto.RenameFilesParams, msg: *lsproto.RequestMessage, send_rename_file: bool) !lsproto.WillRenameFilesResponse {
    _ = msg; _ = send_rename_file;
    if (params.files.len == 0) {
        return lsproto.WillRenameFilesResponse{};
    }

    var uris = std.ArrayList(lsproto.DocumentUri).init(self.allocator);
    defer uris.deinit();
    for (params.files) |file| {
        try uris.append(file.oldUri);
    }

    const services = self.session.?.getLanguageServicesForDocuments(ctx, uris.items);
    _ = services;

    const document_changes = std.ArrayList(lsproto.TextDocumentEditOrCreateFileOrRenameFileOrDeleteFile).init(self.allocator);
    // omitted full rename file logic for brevity in port

    if (document_changes.items.len == 0) {
        return lsproto.WillRenameFilesResponse{};
    }

    var changes = std.AutoHashMap(lsproto.DocumentUri, []*lsproto.TextEdit).init(self.allocator);
    for (document_changes.items) |change| {
        if (change.textDocumentEdit) |tde| {
            const uri = tde.textDocument.uri;
            var uri_changes = std.ArrayList(*lsproto.TextEdit).init(self.allocator);
            for (tde.edits) |edit| {
                if (edit.textEdit) |te| {
                    try uri_changes.append(te);
                }
            }
            try changes.put(uri, uri_changes.items);
        }
    }

    return lsproto.WillRenameFilesResponse{
        .workspaceEdit = .{
            .changes = changes,
        },
    };
}

pub fn handleSignatureHelp(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.SignatureHelpParams) !lsproto.SignatureHelpResponse {
    _ = self;
    return language_service.provideSignatureHelp(ctx, params.textDocument.uri, params.position, params.context);
}

pub fn handleFoldingRange(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.FoldingRangeParams) !lsproto.FoldingRangeResponse {
    _ = self;
    return language_service.provideFoldingRange(ctx, params.textDocument.uri);
}

pub fn handleVSOnAutoInsert(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.VSOnAutoInsertParams) !lsproto.VSOnAutoInsertResponse {
    _ = self;
    return language_service.provideOnAutoInsert(ctx, params);
}

pub fn handleLinkedEditingRange(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.LinkedEditingRangeParams) !lsproto.LinkedEditingRangeResponse {
    _ = self;
    return language_service.provideLinkedEditingRange(ctx, params);
}

pub fn handleDefinition(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.DefinitionParams) !lsproto.DefinitionResponse {
    _ = self;
    return language_service.provideDefinition(ctx, params.textDocument.uri, params.position);
}

pub fn handleSourceDefinition(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.TextDocumentPositionParams) !lsproto.CustomTextDocumentSourceDefinitionResponse {
    _ = self;
    return language_service.provideSourceDefinition(ctx, params.textDocument.uri, params.position);
}

pub fn handleTypeDefinition(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.TypeDefinitionParams) !lsproto.TypeDefinitionResponse {
    _ = self;
    return language_service.provideTypeDefinition(ctx, params.textDocument.uri, params.position);
}

pub fn handleCompletion(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.CompletionParams) !lsproto.CompletionResponse {
    _ = self;
    return language_service.provideCompletion(ctx, params.textDocument.uri, params.position, params.context);
}

pub fn handleCompletionItemResolve(self: *Server, ctx: anytype, params: *lsproto.CompletionItem, req_msg: *lsproto.RequestMessage) !lsproto.CompletionResolveResponse {
    _ = req_msg;
    const data = params.data;
    const language_service = try self.session.?.getLanguageService(ctx, lsconv.fileNameToDocumentURI(data.fileName));
    return language_service.resolveCompletionItem(ctx, params, data);
}

pub fn handleDocumentFormat(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.DocumentFormattingParams) !lsproto.DocumentFormattingResponse {
    _ = self;
    return language_service.provideFormatDocument(ctx, params.textDocument.uri, params.options);
}

pub fn handleDocumentRangeFormat(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.DocumentRangeFormattingParams) !lsproto.DocumentRangeFormattingResponse {
    _ = self;
    return language_service.provideFormatDocumentRange(ctx, params.textDocument.uri, params.options, params.range);
}

pub fn handleDocumentOnTypeFormat(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.DocumentOnTypeFormattingParams) !lsproto.DocumentOnTypeFormattingResponse {
    _ = self;
    return language_service.provideFormatDocumentOnType(ctx, params.textDocument.uri, params.options, params.position, params.ch);
}

pub fn handleWorkspaceSymbol(self: *Server, ctx: anytype, params: *lsproto.WorkspaceSymbolParams, req_msg: *lsproto.RequestMessage) !lsproto.WorkspaceSymbolResponse {
    _ = req_msg;
    var resp: lsproto.WorkspaceSymbolResponse = undefined;
    try self.session.?.withSnapshotLoadingProjectTree(ctx, null, struct {
        fn callback(s: *Server, snapshot: *project.Snapshot, ctx_: anytype, params_: *lsproto.WorkspaceSymbolParams, ls_: *ls.LanguageService, resp_out: *lsproto.WorkspaceSymbolResponse) void {
            _ = s;
            // Simplified handling for zig
            resp_out.* = ls_.provideWorkspaceSymbols(ctx_, null, snapshot.converters(), snapshot.userPreferences(), params_.query) catch unreachable;
        }
    }.callback, self, ctx, params, &resp);
    return resp;
}

pub fn handleDocumentSymbol(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.DocumentSymbolParams) !lsproto.DocumentSymbolResponse {
    _ = self;
    return language_service.provideDocumentSymbols(ctx, params.textDocument.uri);
}

pub fn handleDocumentHighlight(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.DocumentHighlightParams) !lsproto.DocumentHighlightResponse {
    _ = self;
    return language_service.provideDocumentHighlights(ctx, params.textDocument.uri, params.position);
}

pub fn handleMultiDocumentHighlight(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.MultiDocumentHighlightParams) !lsproto.CustomMultiDocumentHighlightResponse {
    _ = self;
    return language_service.provideMultiDocumentHighlights(ctx, params.textDocument.uri, params.position, params.filesToSearch);
}

pub fn handleSelectionRange(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.SelectionRangeParams) !lsproto.SelectionRangeResponse {
    _ = self;
    return language_service.provideSelectionRanges(ctx, params);
}

pub fn handleCodeAction(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.CodeActionParams) !lsproto.CodeActionResponse {
    _ = self;
    return language_service.provideCodeActions(ctx, params);
}

pub fn handleInlayHint(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.InlayHintParams) !lsproto.InlayHintResponse {
    _ = self;
    return language_service.provideInlayHint(ctx, params);
}

pub fn handleCodeLens(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.CodeLensParams) !lsproto.CodeLensResponse {
    _ = self;
    return language_service.provideCodeLenses(ctx, params.textDocument.uri);
}

pub fn handleCodeLensResolve(self: *Server, ctx: anytype, code_lens: *lsproto.CodeLens, req_msg: *lsproto.RequestMessage) !*lsproto.CodeLens {
    const res = try self.getLanguageServiceAndCrossProjectOrchestrator(ctx, code_lens.data.uri, req_msg);
    const default_ls = res[0];
    const orchestrator = res[1];
    return default_ls.resolveCodeLens(ctx, code_lens, self.initialization_options.?.codeLensShowLocationsCommandName, orchestrator);
}

pub fn handlePrepareCallHierarchy(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.CallHierarchyPrepareParams) !lsproto.CallHierarchyPrepareResponse {
    _ = self;
    return language_service.providePrepareCallHierarchy(ctx, params.textDocument.uri, params.position);
}

pub fn handleCallHierarchyIncomingCalls(self: *Server, ctx: anytype, params: *lsproto.CallHierarchyIncomingCallsParams, req_msg: *lsproto.RequestMessage) !lsproto.CallHierarchyIncomingCallsResponse {
    const res = try self.getLanguageServiceAndCrossProjectOrchestrator(ctx, params.item.uri, req_msg);
    return res[0].provideCallHierarchyIncomingCalls(ctx, params.item, res[1]);
}

pub fn handleCallHierarchyOutgoingCalls(self: *Server, ctx: anytype, params: *lsproto.CallHierarchyOutgoingCallsParams, req_msg: *lsproto.RequestMessage) !lsproto.CallHierarchyOutgoingCallsResponse {
    _ = req_msg;
    const language_service = try self.session.?.getLanguageService(ctx, params.item.uri);
    return language_service.provideCallHierarchyOutgoingCalls(ctx, params.item);
}

pub fn handleSemanticTokensFull(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.SemanticTokensParams) !lsproto.SemanticTokensResponse {
    _ = self;
    return language_service.provideSemanticTokens(ctx, params.textDocument.uri);
}

pub fn handleSemanticTokensRange(self: *Server, ctx: anytype, language_service: *ls.LanguageService, params: *lsproto.SemanticTokensRangeParams) !lsproto.SemanticTokensRangeResponse {
    _ = self;
    return language_service.provideSemanticTokensRange(ctx, params.textDocument.uri, params.range);
}

pub fn handleInitializeAPISession(self: *Server, ctx: anytype, params: *lsproto.InitializeAPISessionParams, _: *lsproto.RequestMessage) !lsproto.CustomInitializeAPISessionResponse {
    _ = ctx;
    self.api_sessions_mu.lock();
    defer self.api_sessions_mu.unlock();

    var api_session = api.newSession(self.session, null);

    var pipe_path: []const u8 = "";
    if (params.pipe) |p| {
        if (p.len > 0) pipe_path = p;
    }
    if (pipe_path.len == 0) {
        pipe_path = self.generateAPIPipePath();
    }

    const transport = try api.newPipeTransport(pipe_path);

    // Background thread for API session
    _ = std.Thread.spawn(.{}, struct {
        fn runner(s: *Server, ts: *api.PipeTransport, as: *api.Session, p_ctx: anytype) void {
            _ = s; _ = ts; _ = as; _ = p_ctx;
            // Simplified handling logic
        }
    }.runner, .{ self, transport, api_session, self.background_ctx }) catch {};

    try self.api_sessions.put(api_session.id(), api_session);

    const result = try self.allocator.create(lsproto.InitializeAPISessionResult);
    result.* = .{
        .sessionId = api_session.id(),
        .pipe = pipe_path,
    };
    return result;
}

pub fn generateAPIPipePath(self: *Server) []const u8 {
    const now = std.time.nanoTimestamp();
    var prng = std.rand.DefaultPrng.init(@bitCast(now));
    const rnd = prng.random().int(u64);
    const id_str = std.fmt.allocPrint(self.allocator, "tsgo-api-{x}-{x}", .{now, rnd}) catch unreachable;
    return api.generatePipePath(id_str);
}

pub fn removeAPISession(self: *Server, id: []const u8) void {
    self.api_sessions_mu.lock();
    defer self.api_sessions_mu.unlock();
    _ = self.api_sessions.remove(id);
}

pub fn setCompilerOptionsForInferredProjects(self: *Server, ctx: anytype, options: *core.CompilerOptions) void {
    self.compiler_options_for_inferred_projects = options;
    if (self.session) |sess| {
        sess.didChangeCompilerOptionsForInferredProjects(ctx, options);
    }
}

pub fn npmInstallImpl(self: *Server, cwd: []const u8, args: [][]const u8) ![]const u8 {
    if (self.npm_install) |install| {
        return install(cwd, args);
    }
    return error.NpmInstallNotImplemented;
}

pub fn handleRunGC(self: *Server, ctx: anytype, _: lsproto.NoParams, _: *lsproto.RequestMessage) !lsproto.RunGCResponse {
    _ = ctx;
    pprof.runGC();
    self.logger.info("GC triggered", .{});
    return lsproto.Null{};
}

pub fn handleSaveHeapProfile(self: *Server, ctx: anytype, params: *lsproto.ProfileParams, _: *lsproto.RequestMessage) !*lsproto.ProfileResult {
    _ = ctx;
    const file_path = try pprof.saveHeapProfile(params.dir);
    self.logger.info("Heap profile saved to: {s}", .{file_path});
    const result = try self.allocator.create(lsproto.ProfileResult);
    result.file = file_path;
    return result;
}

pub fn handleSaveAllocProfile(self: *Server, ctx: anytype, params: *lsproto.ProfileParams, _: *lsproto.RequestMessage) !*lsproto.ProfileResult {
    _ = ctx;
    const file_path = try pprof.saveAllocProfile(params.dir);
    self.logger.info("Allocation profile saved to: {s}", .{file_path});
    const result = try self.allocator.create(lsproto.ProfileResult);
    result.file = file_path;
    return result;
}

pub fn handleStartCPUProfile(self: *Server, ctx: anytype, params: *lsproto.ProfileParams, _: *lsproto.RequestMessage) !lsproto.StartCPUProfileResponse {
    _ = ctx;
    if (self.cpu_profiler) |cp| {
        try cp.startCPUProfile(params.dir);
        self.logger.info("CPU profiling started, will save to: {s}", .{params.dir});
        return lsproto.Null{};
    }
    return error.NoProfiler;
}

pub fn handleStopCPUProfile(self: *Server, ctx: anytype, _: lsproto.NoParams, _: *lsproto.RequestMessage) !*lsproto.ProfileResult {
    _ = ctx;
    if (self.cpu_profiler) |cp| {
        const file_path = try cp.stopCPUProfile();
        self.logger.info("CPU profile saved to: {s}", .{file_path});
        const result = try self.allocator.create(lsproto.ProfileResult);
        result.file = file_path;
        return result;
    }
    return error.NoProfiler;
}

pub fn handleProjectInfo(self: *Server, ctx: anytype, params: *lsproto.ProjectInfoParams, _: *lsproto.RequestMessage) !lsproto.CustomProjectInfoResponse {
    const uri = params.textDocument.uri;
    const res = try self.session.?.getLanguageServiceAndProjectsForFile(ctx, uri);
    const default_project = res.defaultProject;
    
    var config_file_path: []const u8 = "";
    if (default_project) |p| {
        if (p.kind == project.KindConfigured) {
            config_file_path = p.name();
        }
    }
    
    const result = try self.allocator.create(lsproto.ProjectInfoResult);
    result.configFilePath = config_file_path;
    return result;
}
