const std = @import("std");
const ast = @import("../ast/ast.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const core = @import("../core/core.zig");

pub const checkerHeldAnonymous = "<anonymous>";

pub const CheckerPoolOptions = struct {
    maxCheckers: usize = 0,
    idleTimeoutMs: u64 = 0,
};

pub const CheckerPool = struct {
    opts: CheckerPoolOptions,
    program: *compiler.Program,
    
    mu: std.Thread.Mutex = .{},
    discarded: bool = false,
    
    checkers: []?*checker.Checker,
    heldBy: [][]const u8,
    fileAssociations: std.AutoHashMap(*ast.SourceFile, usize),
    requestAssociations: std.StringHashMap(usize),
    
    lastReleased: []i64,
    
    persistentChecker: ?*checker.Checker = null,
    persistentHeld: bool = false,

    diagSem: std.Thread.Semaphore = .{ .permits = 1 },
    querySem: std.Thread.Semaphore,
    persistentSem: std.Thread.Semaphore = .{ .permits = 1 },
    
    globalDiagAccumulated: std.ArrayList(*ast.Diagnostic),
    globalDiagChanged: bool = false,
    globalDiagCheckerCount: []usize,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, opts: CheckerPoolOptions, program: *compiler.Program) !*CheckerPool {
        var options = opts;
        if (options.maxCheckers <= 0) options.maxCheckers = 4;
        if (options.maxCheckers < 2) options.maxCheckers = 2;
        if (options.idleTimeoutMs <= 0) options.idleTimeoutMs = 30000;

        var pool = try allocator.create(CheckerPool);
        pool.* = .{
            .opts = options,
            .program = program,
            .checkers = try allocator.alloc(?*checker.Checker, options.maxCheckers),
            .heldBy = try allocator.alloc([]const u8, options.maxCheckers),
            .fileAssociations = std.AutoHashMap(*ast.SourceFile, usize).init(allocator),
            .requestAssociations = std.StringHashMap(usize).init(allocator),
            .lastReleased = try allocator.alloc(i64, options.maxCheckers),
            .querySem = .{ .permits = options.maxCheckers - 1 },
            .globalDiagAccumulated = std.ArrayList(*ast.Diagnostic).init(allocator),
            .globalDiagCheckerCount = try allocator.alloc(usize, options.maxCheckers),
            .allocator = allocator,
        };
        
        @memset(pool.checkers, null);
        @memset(pool.heldBy, "");
        @memset(pool.lastReleased, 0);
        @memset(pool.globalDiagCheckerCount, 0);
        
        return pool;
    }

    // A stub for `getChecker` to demonstrate the interface
    pub fn getChecker(self: *CheckerPool, ctx: *const anyopaque, file: ?*ast.SourceFile) ?*checker.Checker {
        _ = ctx;
        _ = file;
        // In a full implementation, this uses context lifetimes to route to:
        // getDiagnosticsChecker (index 0), getPersistentChecker (API), or getQueryChecker (1+)
        return null;
    }

    pub fn discard(self: *CheckerPool) void {
        self.mu.lock();
        defer self.mu.unlock();
        if (self.discarded) return;
        self.discarded = true;
        // stop timer logic here
    }

    pub fn getGlobalDiagnostics(self: *CheckerPool) ![]*ast.Diagnostic {
        self.mu.lock();
        defer self.mu.unlock();
        const clone = try self.allocator.alloc(*ast.Diagnostic, self.globalDiagAccumulated.items.len);
        @memcpy(clone, self.globalDiagAccumulated.items);
        return clone;
    }
};
