const std = @import("std");
const rlz = @import("raylib-zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "konkurs1",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    //const rl_target = b.standardTargetOptions(.{});
    //const
    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = .ReleaseFast,
        .linux_display_backend = .Both,
        .shared = .true,
    });

    // const foo = 0;

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    // if (target.query.os_tag == .emscripten) {
    //     const exe_lib = try rlz.emcc.compileForEmscripten(b, "konkurs1", "src/main.zig", target, optimize);
    //
    //     exe_lib.linkLibrary(raylib_artifact);
    //     exe_lib.root_module.addImport("raylib", raylib);
    //
    //     // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
    //     const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });
    //     //this lets your program access files like "resources/my-image.png":
    //     link_step.addArg("--embed-file");
    //     link_step.addArg("resources/");
    //
    //     b.getInstallStep().dependOn(&link_step.step);
    //     const run_step = try rlz.emcc.emscriptenRunStep(b);
    //     run_step.step.dependOn(&link_step.step);
    //     const run_option = b.step("run", "Run konkurs1");
    //     run_option.dependOn(&run_step.step);
    //     return;
    // }

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    b.installArtifact(exe);
    b.installArtifact(raylib_artifact);

    const docs_step = b.step("docs", "Copy documentation to prefix path");
    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/konkurs1",
    });
    // const install_docs_raylib = b.addInstallDirectory(.{
    //     .source_dir = raylib_artifact.getEmittedDocs(),
    //     .install_dir = .prefix,
    //     .install_subdir = "docs/raylib",
    // });
    docs_step.dependOn(&install_docs.step);
    // docs_step.dependOn(&install_docs_raylib.step);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
