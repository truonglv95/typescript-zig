const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Module chính
    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // libtsc: C ABI library cho Go
    const libtsc = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "tsc",
        .root_module = mod,
    });
    b.installArtifact(libtsc);

    // Tests
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
