const std = @import("std");
const ast = @import("../ast/ast.zig");
const parser = @import("../parser/parser.zig");
const binder = @import("../binder/binder.zig");
const core = @import("../core/core.zig");
const emitresolver = @import("../printer/emitresolver.zig");
const emitter = @import("emitter.zig");

pub const ProgramOptions = struct {
    options: core.CompilerOptions,
    rootNames: [][]const u8,
    useSourceOfProjectReference: bool = false,
    singleThreaded: ?bool = null,
    typingsLocation: []const u8 = "",
    projectName: []const u8 = "",
};

pub const EmitOptions = struct {
    targetSourceFile: u32 = 0, // Single file to emit (NodeIndex). If 0, emits all files
    emitOnly: emitter.EmitOnly = .EmitAll,
    writeFile: ?*const fn (fileName: []const u8, text: []const u8, data: ?*emitter.WriteFileData) anyerror!void = null,
};

pub const Program = struct {
    allocator: std.mem.Allocator,
    opts: ProgramOptions,

    // DoD: Store file node indices rather than pointers.
    sourceFiles: std.ArrayList(u32),

    parserInstance: *parser.Parser,
    binderInstance: *binder.Binder,
    emitResolverInstance: emitresolver.EmitResolver,

    pub fn deinit(self: *Program) void {
        self.binderInstance.deinit();
        self.allocator.destroy(self.binderInstance);
        self.parserInstance.deinit();
        self.allocator.destroy(self.parserInstance);
        self.sourceFiles.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn bindSourceFile(self: *Program, fileIndex: u32) !void {
        // In Go: binder.BindSourceFile(file)
        try self.binderInstance.bindSourceFile(fileIndex);
    }

    pub fn bindSourceFiles(self: *Program) !void {
        // In Go: runs in WorkGroup queue
        for (self.sourceFiles.items) |fileIndex| {
            // Ideally we check if file is already bound using ast flags
            try self.bindSourceFile(fileIndex);
        }
    }

    pub fn emit(self: *Program, options: EmitOptions) !emitter.EmitResult {
        // Emulate the Go Emit loop over sourceFiles
        var e = emitter.Emitter.init(self.allocator, &self.opts.options, &self.emitResolverInstance, &self.parserInstance.ast);
        e.emitOnly = options.emitOnly;

        const result = emitter.EmitResult{};

        if (options.targetSourceFile != 0) {
            const outPath = "out.js";
            const jsStr = try e.emitJSFile(options.targetSourceFile, outPath);
            self.allocator.free(jsStr);
        } else {
            for (self.sourceFiles.items) |fileIndex| {
                const outPath = "out.js";
                const jsStr = try e.emitJSFile(fileIndex, outPath);
                self.allocator.free(jsStr);
            }
        }
        return result;
    }

    pub fn getSourceFiles(self: *Program) []const u32 {
        return self.sourceFiles.items;
    }
};

pub fn createProgram(allocator: std.mem.Allocator, opts: ProgramOptions) !*Program {
    var p = try allocator.create(Program);
    p.* = Program{
        .allocator = allocator,
        .opts = opts,
        .sourceFiles = .empty,
        .parserInstance = try allocator.create(parser.Parser),
        .binderInstance = try allocator.create(binder.Binder),
        .emitResolverInstance = emitresolver.EmitResolver{},
    };

    // Init parser with dummy text; actual file parsing is done per file elsewhere
    p.parserInstance.* = parser.Parser.init(allocator, "");

    // DoD: The AST arena is owned by parserInstance (or a shared structure)
    p.binderInstance.* = try binder.Binder.init(allocator, &p.parserInstance.ast);

    return p;
}
