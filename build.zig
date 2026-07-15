const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // Default to ReleaseFast for maximum performance; override with -Doptimize=Debug for dev
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    // Main module
    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // libtsc: C ABI dynamic library for Go CGO interop
    const libtsc = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "tsc",
        .root_module = mod,
    });
    b.installArtifact(libtsc);

    // Standalone CLI executable (src/main.zig)
    const exe = b.addExecutable(.{
        .name = "tsc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "tsc", .module = mod },
            },
        }),
    });
    b.installArtifact(exe);

    // `zig build run` step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the tsc CLI");
    run_step.dependOn(&run_cmd.step);

    // `zig build check` — fast semantic analysis without codegen
    const check_exe = b.addExecutable(.{
        .name = "tsc-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "tsc", .module = mod },
            },
        }),
    });
    const gen_fourslash_cmd = b.addSystemCommand(&[_][]const u8{
        "python3", "scripts/gen_fourslash_tests.py",
    });

    const check_step = b.step("check", "Semantic analysis only (no codegen)");
    check_step.dependOn(&gen_fourslash_cmd.step);
    check_step.dependOn(&check_exe.step);

    const lsp_exe = b.addExecutable(.{
        .name = "typescript-zig-language-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("cmd/lsp/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "tsc", .module = mod }},
        }),
    });
    b.installArtifact(lsp_exe);
    const install_libs = b.addInstallDirectory(.{
        .source_dir = b.path("src/bundled/libs"),
        .install_dir = .lib,
        .install_subdir = "typescript-zig",
    });
    b.getInstallStep().dependOn(&install_libs.step);

    // Tests
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    mod_tests.step.dependOn(&gen_fourslash_cmd.step);
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_tests.step);
}
