const std = @import("std");
const ast = @import("../ast/ast.zig");
const core = @import("../core/core.zig");
const diagnostics = @import("../diagnostics/diagnostics.zig");
const locale = @import("../locale/locale.zig");
const scanner = @import("../scanner/scanner.zig");
const tspath = @import("../tspath/tspath.zig");

pub const FileLike = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        fileName: *const fn (ptr: *anyopaque) []const u8,
        text: *const fn (ptr: *anyopaque) []const u8,
        ecmaLineMap: *const fn (ptr: *anyopaque) []usize,
    };

    pub fn fileName(self: FileLike) []const u8 {
        return self.vtable.fileName(self.ptr);
    }
    pub fn text(self: FileLike) []const u8 {
        return self.vtable.text(self.ptr);
    }
    pub fn ecmaLineMap(self: FileLike) []usize {
        return self.vtable.ecmaLineMap(self.ptr);
    }
};

pub const Diagnostic = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        file: *const fn (ptr: *anyopaque) ?FileLike,
        pos: *const fn (ptr: *anyopaque) usize,
        end: *const fn (ptr: *anyopaque) usize,
        len: *const fn (ptr: *anyopaque) usize,
        code: *const fn (ptr: *anyopaque) i32,
        category: *const fn (ptr: *anyopaque) diagnostics.Category,
        localize: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, loc: locale.Locale) []const u8,
        messageChain: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) []Diagnostic,
        relatedInformation: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) []Diagnostic,
    };

    pub fn file(self: Diagnostic) ?FileLike {
        return self.vtable.file(self.ptr);
    }
    pub fn pos(self: Diagnostic) usize {
        return self.vtable.pos(self.ptr);
    }
    pub fn end(self: Diagnostic) usize {
        return self.vtable.end(self.ptr);
    }
    pub fn len(self: Diagnostic) usize {
        return self.vtable.len(self.ptr);
    }
    pub fn code(self: Diagnostic) i32 {
        return self.vtable.code(self.ptr);
    }
    pub fn category(self: Diagnostic) diagnostics.Category {
        return self.vtable.category(self.ptr);
    }
    pub fn localize(self: Diagnostic, allocator: std.mem.Allocator, loc: locale.Locale) []const u8 {
        return self.vtable.localize(self.ptr, allocator, loc);
    }
    pub fn messageChain(self: Diagnostic, allocator: std.mem.Allocator) []Diagnostic {
        return self.vtable.messageChain(self.ptr, allocator);
    }
    pub fn relatedInformation(self: Diagnostic, allocator: std.mem.Allocator) []Diagnostic {
        return self.vtable.relatedInformation(self.ptr, allocator);
    }
};

// ASTDiagnostic wrappers stubbed for 1:1 parity with Go until ast.Diagnostic is ported.
pub fn wrapASTDiagnostic(d: anytype) Diagnostic {
    _ = d;
    unreachable;
}

pub fn wrapASTDiagnostics(allocator: std.mem.Allocator, diags: anytype) []Diagnostic {
    _ = allocator;
    _ = diags;
    unreachable;
}

pub fn fromASTDiagnostics(allocator: std.mem.Allocator, diags: anytype) []Diagnostic {
    _ = allocator;
    _ = diags;
    unreachable;
}

pub fn toDiagnostics(allocator: std.mem.Allocator, diags: anytype) []Diagnostic {
    _ = allocator;
    _ = diags;
    unreachable;
}

pub fn compareASTDiagnostics(a: anytype, b: anytype) i32 {
    _ = a;
    _ = b;
    unreachable;
}

pub const ComparePathsOptions = struct {
    currentDirectory: []const u8 = "",
    getCanonicalFileName: ?*const fn (path: []const u8) []const u8 = null,
};

pub const FormattingOptions = struct {
    locale: locale.Locale,
    comparePathsOptions: ComparePathsOptions = .{},
    newLine: []const u8 = "\n",
};

const foregroundColorEscapeGrey = "\x1b[90m";
const foregroundColorEscapeRed = "\x1b[91m";
const foregroundColorEscapeYellow = "\x1b[93m";
const foregroundColorEscapeBlue = "\x1b[94m";
const foregroundColorEscapeCyan = "\x1b[96m";

const gutterStyleSequence = "\x1b[7m";
const gutterSeparator = " ";
const resetEscapeSequence = "\x1b[0m";
const ellipsis = "...";

pub fn formatDiagnosticsWithColorAndContext(allocator: std.mem.Allocator, output: std.io.AnyWriter, diags: []Diagnostic, formatOpts: FormattingOptions) !void {
    if (diags.len == 0) return;
    for (diags, 0..) |diagnostic, i| {
        if (i > 0) {
            try output.writeAll(formatOpts.newLine);
        }
        try formatDiagnosticWithColorAndContext(allocator, output, diagnostic, formatOpts);
    }
}

pub fn formatDiagnosticWithColorAndContext(allocator: std.mem.Allocator, output: std.io.AnyWriter, diagnostic: Diagnostic, formatOpts: FormattingOptions) !void {
    if (diagnostic.file()) |f| {
        const pos = diagnostic.pos();
        try writeLocation(output, f, pos, formatOpts, writeWithStyleAndReset);
        try output.writeAll(" - ");
    }

    try writeWithStyleAndReset(output, @tagName(diagnostic.category()), getCategoryFormat(diagnostic.category()));
    try output.print("{s} TS{d}: {s}", .{ foregroundColorEscapeGrey, diagnostic.code(), resetEscapeSequence });
    try writeFlattenedDiagnosticMessage(allocator, output, diagnostic, formatOpts.newLine, formatOpts.locale);

    if (diagnostic.file()) |f| {
        if (diagnostic.code() != diagnostics.generated.File_appears_to_be_binary.code) {
            try output.writeAll(formatOpts.newLine);
            try writeCodeSnippet(output, f, diagnostic.pos(), diagnostic.len(), getCategoryFormat(diagnostic.category()), "", formatOpts);
            try output.writeAll(formatOpts.newLine);
        }
    }

    const relatedInfo = diagnostic.relatedInformation(allocator);
    if (relatedInfo.len > 0) {
        for (relatedInfo) |relatedInformation| {
            if (relatedInformation.file()) |f| {
                try output.writeAll(formatOpts.newLine);
                try output.writeAll("  ");
                const pos = relatedInformation.pos();
                try writeLocation(output, f, pos, formatOpts, writeWithStyleAndReset);
                try output.writeAll(" - ");
                try writeFlattenedDiagnosticMessage(allocator, output, relatedInformation, formatOpts.newLine, formatOpts.locale);
                try writeCodeSnippet(output, f, pos, relatedInformation.len(), foregroundColorEscapeCyan, "    ", formatOpts);
            }
            try output.writeAll(formatOpts.newLine);
        }
    }
}

fn writeCodeSnippet(output: std.io.AnyWriter, sourceFile: FileLike, start: usize, length: usize, squiggleColor: []const u8, indent: []const u8, formatOpts: FormattingOptions) !void {
    _ = start;
    // scanner missing getECMALineAndUTF16CharacterOfPosition, getECMALineOfPosition, getECMAPositionOfLineAndByteOffset
    // Dummy values are used below until scanner.zig implements them
    const firstLine: usize = 0;
    const firstLineChar: usize = 0;
    const lastLine: usize = 0;
    var lastLineChar: usize = 0;
    if (length == 0) {
        lastLineChar += 1;
    }

    const lastLineOfFile: usize = 0;

    const hasMoreThanFiveLines = lastLine > firstLine and lastLine - firstLine >= 4;
    var gutterWidth: usize = 1;
    if (hasMoreThanFiveLines) {
        gutterWidth = @max(ellipsis.len, gutterWidth);
    }

    var i = firstLine;
    while (i <= lastLine) : (i += 1) {
        try output.writeAll(formatOpts.newLine);

        if (hasMoreThanFiveLines and firstLine + 1 < i and i < lastLine - 1) {
            try output.writeAll(indent);
            try output.writeAll(gutterStyleSequence);
            try output.print("{s:>[1]}", .{ ellipsis, gutterWidth }); // approximated format width
            try output.writeAll(resetEscapeSequence);
            try output.writeAll(gutterSeparator);
            try output.writeAll(formatOpts.newLine);
            i = lastLine - 1;
        }

        const lineStart: usize = 0;
        var lineEnd: usize = 0;
        if (i < lastLineOfFile) {
            lineEnd = 0;
        } else {
            lineEnd = sourceFile.text().len;
        }

        const rawLine = if (lineEnd > lineStart and lineEnd <= sourceFile.text().len) sourceFile.text()[lineStart..lineEnd] else "";
        const lineContent = std.mem.trimRight(u8, rawLine, " \t\r\n");

        try output.writeAll(indent);
        try output.writeAll(gutterStyleSequence);
        try output.print("{d:>[1]}", .{ i + 1, gutterWidth });
        try output.writeAll(resetEscapeSequence);
        try output.writeAll(gutterSeparator);
        // ideally replace \t with space here
        try output.writeAll(lineContent);
        try output.writeAll(formatOpts.newLine);

        try output.writeAll(indent);
        try output.writeAll(gutterStyleSequence);
        try output.print("{s:>[1]}", .{ "", gutterWidth });
        try output.writeAll(resetEscapeSequence);
        try output.writeAll(gutterSeparator);
        try output.writeAll(squiggleColor);

        switch (i) {
            firstLine => {
                var lastCharForLine: usize = 0;
                if (i == lastLine) {
                    lastCharForLine = lastLineChar;
                } else {
                    lastCharForLine = lineContent.len;
                }
                for (0..firstLineChar) |_| try output.writeAll(" ");
                if (lastCharForLine > firstLineChar) {
                    for (0..(lastCharForLine - firstLineChar)) |_| try output.writeAll("~");
                }
            },
            lastLine => {
                for (0..lastLineChar) |_| try output.writeAll("~");
            },
            else => {
                for (0..lineContent.len) |_| try output.writeAll("~");
            },
        }
        try output.writeAll(resetEscapeSequence);
    }
}

pub fn flattenDiagnosticMessage(allocator: std.mem.Allocator, d: Diagnostic, newLine: []const u8, loc: locale.Locale) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();
    try writeFlattenedDiagnosticMessage(allocator, output.writer().any(), d, newLine, loc);
    return allocator.dupe(u8, output.items);
}

pub fn writeFlattenedASTDiagnosticMessage(allocator: std.mem.Allocator, writer: std.io.AnyWriter, diagnostic: anytype, newline: []const u8, loc: locale.Locale) !void {
    try writeFlattenedDiagnosticMessage(allocator, writer, wrapASTDiagnostic(diagnostic), newline, loc);
}

pub fn writeFlattenedDiagnosticMessage(allocator: std.mem.Allocator, writer: std.io.AnyWriter, diagnostic: Diagnostic, newline: []const u8, loc: locale.Locale) !void {
    try writer.writeAll(diagnostic.localize(allocator, loc));

    for (diagnostic.messageChain(allocator)) |chain| {
        try flattenDiagnosticMessageChain(allocator, writer, chain, newline, loc, 1);
    }
}

fn flattenDiagnosticMessageChain(allocator: std.mem.Allocator, writer: std.io.AnyWriter, chain: Diagnostic, newLine: []const u8, loc: locale.Locale, level: usize) !void {
    try writer.writeAll(newLine);
    for (0..level) |_| {
        try writer.writeAll("  ");
    }

    try writer.writeAll(chain.localize(allocator, loc));
    for (chain.messageChain(allocator)) |child| {
        try flattenDiagnosticMessageChain(allocator, writer, child, newLine, loc, level + 1);
    }
}

fn getCategoryFormat(category: diagnostics.Category) []const u8 {
    switch (category) {
        .Error => return foregroundColorEscapeRed,
        .Warning => return foregroundColorEscapeYellow,
        .Suggestion => return foregroundColorEscapeGrey,
        .Message => return foregroundColorEscapeBlue,
    }
}

pub const FormattedWriter = *const fn (output: std.io.AnyWriter, text: []const u8, formatStyle: []const u8) anyerror!void;

pub fn writeWithStyleAndReset(output: std.io.AnyWriter, text: []const u8, formatStyle: []const u8) !void {
    try output.writeAll(formatStyle);
    try output.writeAll(text);
    try output.writeAll(resetEscapeSequence);
}

pub fn writeLocation(output: std.io.AnyWriter, file: FileLike, pos: usize, formatOpts: FormattingOptions, formattedWriter: FormattedWriter) !void {
    _ = pos;
    _ = formatOpts;
    const firstLine: usize = 0; // dummy until scanner ported
    const firstChar: usize = 0; // dummy until scanner ported

    // tspath.ConvertToRelativePath is not implemented yet in tspath.zig.
    const relativeFileName = file.fileName();

    try formattedWriter(output, relativeFileName, foregroundColorEscapeCyan);
    try output.writeAll(":");
    var buf1: [32]u8 = undefined;
    try formattedWriter(output, try std.fmt.bufPrint(&buf1, "{d}", .{firstLine + 1}), foregroundColorEscapeYellow);
    try output.writeAll(":");
    var buf2: [32]u8 = undefined;
    try formattedWriter(output, try std.fmt.bufPrint(&buf2, "{d}", .{firstChar + 1}), foregroundColorEscapeYellow);
}

pub const ErrorSummary = struct {
    totalErrorCount: usize,
    globalErrors: []Diagnostic,
    errorsByFile: std.AutoHashMap(FileLike, []Diagnostic),
    sortedFiles: []FileLike,
};

// Wrapper to hold dynamic allocations
const ErrorSummaryInternal = struct {
    totalErrorCount: usize,
    globalErrors: std.ArrayList(Diagnostic),
    errorsByFile: std.AutoHashMap(FileLike, std.ArrayList(Diagnostic)),
    sortedFiles: std.ArrayList(FileLike),
};

pub fn writeErrorSummaryText(allocator: std.mem.Allocator, output: std.io.AnyWriter, allDiagnostics: []Diagnostic, formatOpts: FormattingOptions) !void {
    var errorSummary = try getErrorSummary(allocator, allDiagnostics);
    defer {
        errorSummary.globalErrors.deinit();
        var it = errorSummary.errorsByFile.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        errorSummary.errorsByFile.deinit();
        errorSummary.sortedFiles.deinit();
    }

    const totalErrorCount = errorSummary.totalErrorCount;
    if (totalErrorCount == 0) {
        return;
    }

    var firstFile: ?FileLike = null;
    if (errorSummary.sortedFiles.items.len > 0) {
        firstFile = errorSummary.sortedFiles.items[0];
    }
    const firstFileName = try prettyPathForFileError(allocator, firstFile, if (firstFile != null) errorSummary.errorsByFile.get(firstFile.?) orelse std.ArrayList(Diagnostic).init(allocator) else std.ArrayList(Diagnostic).init(allocator), formatOpts);
    defer if (firstFileName.len > 0) allocator.free(firstFileName);

    const numErroringFiles = errorSummary.errorsByFile.count();

    var message = std.ArrayList(u8).init(allocator);
    defer message.deinit();

    if (totalErrorCount == 1) {
        if (errorSummary.globalErrors.items.len > 0 or firstFileName.len == 0) {
            try message.appendSlice("Found 1 error");
        } else {
            try message.writer().print("Found 1 error in {s}", .{firstFileName});
        }
    } else {
        switch (numErroringFiles) {
            0 => try message.writer().print("Found {d} errors", .{totalErrorCount}),
            1 => try message.writer().print("Found {d} errors in the same file, starting at: {s}", .{ totalErrorCount, firstFileName }),
            else => try message.writer().print("Found {d} errors in {d} files", .{ totalErrorCount, numErroringFiles }),
        }
    }

    try output.writeAll(formatOpts.newLine);
    try output.writeAll(message.items);
    try output.writeAll(formatOpts.newLine);
    try output.writeAll(formatOpts.newLine);

    if (numErroringFiles > 1) {
        try writeTabularErrorsDisplay(allocator, output, &errorSummary, formatOpts);
        try output.writeAll(formatOpts.newLine);
    }
}

fn fileLikeSortFn(context: void, a: FileLike, b: FileLike) bool {
    _ = context;
    return std.mem.lessThan(u8, a.fileName(), b.fileName());
}

fn getErrorSummary(allocator: std.mem.Allocator, diags: []Diagnostic) !ErrorSummaryInternal {
    var totalErrorCount: usize = 0;
    var globalErrors = std.ArrayList(Diagnostic).init(allocator);
    var errorsByFile = std.AutoHashMap(FileLike, std.ArrayList(Diagnostic)).init(allocator);

    for (diags) |diagnostic| {
        if (diagnostic.category() != .Error) {
            continue;
        }

        totalErrorCount += 1;
        if (diagnostic.file() == null) {
            try globalErrors.append(diagnostic);
        } else {
            const f = diagnostic.file().?;
            var gop = try errorsByFile.getOrPut(f);
            if (!gop.found_existing) {
                gop.value_ptr.* = std.ArrayList(Diagnostic).init(allocator);
            }
            try gop.value_ptr.append(diagnostic);
        }
    }

    var sortedFiles = std.ArrayList(FileLike).init(allocator);
    var it = errorsByFile.keyIterator();
    while (it.next()) |k| {
        try sortedFiles.append(k.*);
    }

    std.mem.sort(FileLike, sortedFiles.items, {}, fileLikeSortFn);

    return ErrorSummaryInternal{
        .totalErrorCount = totalErrorCount,
        .globalErrors = globalErrors,
        .errorsByFile = errorsByFile,
        .sortedFiles = sortedFiles,
    };
}

fn writeTabularErrorsDisplay(allocator: std.mem.Allocator, output: std.io.AnyWriter, errorSummary: *ErrorSummaryInternal, formatOpts: FormattingOptions) !void {
    const sortedFiles = errorSummary.sortedFiles.items;

    var maxErrors: usize = 0;
    var it = errorSummary.errorsByFile.valueIterator();
    while (it.next()) |errorsForFile| {
        maxErrors = @max(maxErrors, errorsForFile.items.len);
    }

    const headerRow = "Errors  Files";
    const leftColumnHeadingLength = 6;

    var buf: [32]u8 = undefined;
    const lengthOfBiggestErrorCount = (try std.fmt.bufPrint(&buf, "{d}", .{maxErrors})).len;

    const leftPaddingGoal = @max(leftColumnHeadingLength, lengthOfBiggestErrorCount);
    const headerPadding = if (lengthOfBiggestErrorCount > leftColumnHeadingLength) lengthOfBiggestErrorCount - leftColumnHeadingLength else 0;

    for (0..headerPadding) |_| try output.writeAll(" ");
    try output.writeAll(headerRow);
    try output.writeAll(formatOpts.newLine);

    for (sortedFiles) |file| {
        const fileErrors = errorSummary.errorsByFile.get(file).?.items;
        const errorCount = fileErrors.len;

        try output.print("{d:>[1]}  ", .{ errorCount, leftPaddingGoal });
        const prettyPath = try prettyPathForFileError(allocator, file, std.ArrayList(Diagnostic).fromOwnedSlice(allocator, fileErrors), formatOpts);
        try output.writeAll(prettyPath);
        allocator.free(prettyPath);
        try output.writeAll(formatOpts.newLine);
    }
}

fn prettyPathForFileError(allocator: std.mem.Allocator, file: ?FileLike, fileErrors: std.ArrayList(Diagnostic), formatOpts: FormattingOptions) ![]const u8 {
    _ = formatOpts;
    if (file == null or fileErrors.items.len == 0) {
        return "";
    }
    const f = file.?;
    const line: usize = 0; // dummy line
    const fileName = f.fileName();
    return std.fmt.allocPrint(allocator, "{s}{s}:{d}{s}", .{
        fileName,
        foregroundColorEscapeGrey,
        line + 1,
        resetEscapeSequence,
    });
}

pub fn writeFormatDiagnostics(allocator: std.mem.Allocator, output: std.io.AnyWriter, diags: []Diagnostic, formatOpts: FormattingOptions) !void {
    for (diags) |diagnostic| {
        try writeFormatDiagnostic(allocator, output, diagnostic, formatOpts);
    }
}

pub fn writeFormatDiagnostic(allocator: std.mem.Allocator, output: std.io.AnyWriter, diagnostic: Diagnostic, formatOpts: FormattingOptions) !void {
    if (diagnostic.file()) |f| {
        const line: usize = 0;
        const character: usize = 0;
        const fileName = f.fileName();
        try output.print("{s}({d},{d}): ", .{ fileName, line + 1, character + 1 });
    }

    try output.print("{s} TS{d}: ", .{ @tagName(diagnostic.category()), diagnostic.code() });
    try writeFlattenedDiagnosticMessage(allocator, output, diagnostic, formatOpts.newLine, formatOpts.locale);
    try output.writeAll(formatOpts.newLine);
}

pub fn formatDiagnosticsStatusWithColorAndTime(allocator: std.mem.Allocator, output: std.io.AnyWriter, timeStr: []const u8, diag: Diagnostic, formatOpts: FormattingOptions) !void {
    try output.writeAll("[");
    try writeWithStyleAndReset(output, timeStr, foregroundColorEscapeGrey);
    try output.writeAll("] ");
    try writeFlattenedDiagnosticMessage(allocator, output, diag, formatOpts.newLine, formatOpts.locale);
}

pub fn formatDiagnosticsStatusAndTime(allocator: std.mem.Allocator, output: std.io.AnyWriter, timeStr: []const u8, diag: Diagnostic, formatOpts: FormattingOptions) !void {
    try output.print("{s} - ", .{timeStr});
    try writeFlattenedDiagnosticMessage(allocator, output, diag, formatOpts.newLine, formatOpts.locale);
}

pub const screenStartingCodes = [_]i32{
    diagnostics.generated.Starting_compilation_in_watch_mode.code,
    diagnostics.generated.File_change_detected_Starting_incremental_compilation.code,
};

pub fn tryClearScreen(output: std.io.AnyWriter, diag: Diagnostic, options: *core.CompilerOptions) !bool {
    const preserveWatch = if (@hasField(core.CompilerOptions, "preserveWatchOutput")) options.preserveWatchOutput else false;
    const extDiagnostics = if (@hasField(core.CompilerOptions, "extendedDiagnostics")) options.extendedDiagnostics else false;
    const isDiagnostics = if (@hasField(core.CompilerOptions, "diagnostics")) options.diagnostics else false;

    // Convert bool? to bool safely
    const pw = if (@TypeOf(preserveWatch) == bool) preserveWatch else (preserveWatch orelse false);
    const ed = if (@TypeOf(extDiagnostics) == bool) extDiagnostics else (extDiagnostics orelse false);
    const id = if (@TypeOf(isDiagnostics) == bool) isDiagnostics else (isDiagnostics orelse false);

    if (!pw and !ed and !id) {
        var found = false;
        for (screenStartingCodes) |code| {
            if (diag.code() == code) {
                found = true;
                break;
            }
        }
        if (found) {
            try output.writeAll("\x1B[2J\x1B[3J\x1B[H");
            return true;
        }
    }
    return false;
}
