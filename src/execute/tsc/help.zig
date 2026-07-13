const std = @import("std");

//! TSC `--help` command: print usage information.
//!
//! Port of `internal/execute/tsc/help.go` (426 LOC).
//!
//! Generates and prints the help text for all tsc command-line options.

/// Prints the tsc help text to the given writer.
/// Port of Go's `printHelp` / `printVersion`.
pub fn printHelp(writer: anytype, version: []const u8) !void {
    try writer.print("Version {s}\n", .{version});
    try writer.print("Syntax:   tsc [options] [file...]\n\n", .{});
    try writer.print("Examples: tsc hello.ts\n", .{});
    try writer.print("          tsc --resolveJsonModule --moduleResolution node src/index.ts\n\n", .{});
    try writer.print("Options:\n", .{});
    try writer.print(" -h, --help                                         Print this message.\n", .{});
    try writer.print(" -w, --watch                                        Watch input files.\n", .{});
    try writer.print(" -p, --project                                      Compile the project given the path to its configuration file, or to a folder with a 'tsconfig.json'.\n", .{});
    try writer.print(" -b, --build                                        Build one or more projects and their dependencies, if out of date.\n", .{});
    try writer.print(" -v, --version                                      Print the compiler's version.\n", .{});
    try writer.print(" --init                                             Initializes a TypeScript project and creates a tsconfig.json file.\n", .{});
    try writer.print(" --all                                              Show all of the compiler options.\n", .{});
    try writer.print(" --pretty                                           Stylize errors and messages using color and context (experimental).\n", .{});
    try writer.print(" --listFiles                                        Print all files read during the compilation.\n", .{});
    try writer.print(" --listFilesOnly                                    Print all files read during the compilation.\n", .{});
    try writer.print(" --noEmit                                           Do not emit compiler output files like JavaScript source code, declarations or sourcemaps.\n", .{});
    try writer.print(" --declaration                                      Generate .d.ts files from TypeScript and JavaScript files in your project.\n", .{});
    try writer.print(" --declarationMap                                   Create sourcemaps for d.ts files.\n", .{});
    try writer.print(" --emitDeclarationOnly                              Only output d.ts files and not JavaScript files.\n", .{});
    try writer.print(" --sourceMap                                        Create source map files for emitted JavaScript files.\n", .{});
    try writer.print(" --outDir                                           Specify an output folder for all emitted files.\n", .{});
    try writer.print(" --outFile                                          Specify a file that bundles all outputs into one JavaScript file.\n", .{});
    try writer.print(" --removeComments                                   Disable emitting comments.\n", .{});
    try writer.print(" --strict                                           Enable all strict type checking options.\n", .{});
    try writer.print(" --target                                           Set the JavaScript language version for emitted JavaScript and include compatible library declarations.\n", .{});
    try writer.print(" --module                                           Specify what module code is generated.\n", .{});
    try writer.print(" --jsx                                              Specify what JSX code is generated.\n", .{});
    try writer.print(" --esModuleInterop                                  Emit additional JavaScript to ease support for importing CommonJS modules.\n", .{});
    try writer.print(" --forceConsistentCasingInFileNames                 Ensure that casing is correct in imports.\n", .{});
    try writer.print(" --skipLibCheck                                     Skip type checking all .d.ts files.\n", .{});
    try writer.print(" --incremental                                      Save .tsbuildinfo files to allow for incremental compilation of projects.\n", .{});
    try writer.print(" --diagnostics                                      Output compiler performance information after building.\n", .{});
    try writer.print(" --extendedDiagnostics                              Output more detailed compiler performance information after building.\n", .{});
    try writer.print(" --listFiles                                        Print all files read during the compilation.\n", .{});
}

/// Prints the version string.
pub fn printVersion(writer: anytype, version: []const u8) !void {
    try writer.print("Version {s}\n", .{version});
}
