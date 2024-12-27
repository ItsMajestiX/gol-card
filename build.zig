const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // options for desktop build

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target_desktop = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize_desktop = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target_desktop,
        .optimize = optimize_desktop,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const exe = b.addExecutable(.{
        .name = "sim_desktop",
        .root_source_file = b.path("src/main-desktop.zig"),
        .target = target_desktop,
        .optimize = optimize_desktop,
    });
    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // options for MSP430 build
    const target_msp430_query = std.Target.Query.parse(std.Target.Query.ParseOptions{
        .arch_os_abi = "msp430-freestanding",
        .cpu_features = "msp430+hwmult32",
    }) catch unreachable;
    const target_msp430 = b.resolveTargetQuery(target_msp430_query);
    const optimize_msp430 = std.builtin.OptimizeMode.ReleaseSmall;
    const build_object = b.addObject(std.Build.ObjectOptions{
        .name = "gol_card",
        .root_source_file = b.path("src/main-embedded.zig"),
        .target = target_msp430,
        .optimize = optimize_msp430,
    });
    // var genFile = std.Build.GeneratedFile{ .step = &build_object.step };
    // build_object.generated_asm = &genFile;

    const install_asm = b.addInstallFile(build_object.getEmittedAsm(), "gol_card.s");
    install_asm.step.dependOn(&build_object.step);

    const build_embedded = b.step("build-embedded", "aaaa");
    build_embedded.dependOn(&install_asm.step);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/common.zig"),
        .target = target_desktop,
        .optimize = optimize_desktop,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
