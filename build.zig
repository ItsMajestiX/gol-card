const std = @import("std");
const builtin = @import("builtin");

fn checkFileHash(path: []const u8, out: *[std.crypto.hash.Md5.digest_length]u8) !void {
    const buf: [8192]u8 = undefined;
    const file = try std.fs.cwd().openFile(path, .{});
    var hash = std.crypto.hash.Md5.init(.{});
    while (true) {
        const len = try file.read(buf);
        if (len == 0) break;
        hash.update(buf[0..len]);
    }
    hash.final(out);
}
// Create a step that will download and install TI's tools for MSP430 if available for the current platform.
fn createInstallToolchain(b: *std.Build) !std.Build.Step {

    // Build the appropriate package name based on builtin (works at comptime)
    const os_str = comptime switch (builtin.os.tag) {
        .windows => "win",
        .macos, .linux => |value| @tagName(value),
        else => {
            @panic("Unsupported operating system for TI toolchain.");
        },
    };
    const arch_str = comptime if (builtin.os.tag == .macos) "" else switch (builtin.cpu.arch) {
        .x86_64, .aarch64 => "64",
        .x86, .arm => "32",
        else => @panic("Unsupported architecture for TI toolchain."),
    };
    const archive_str = comptime switch (builtin.os.tag) {
        .windows => "zip",
        .macos, .linux => "tar.bz2",
        else => unreachable,
    };
    const root_name = std.fmt.comptimePrint("msp430-gcc-9.3.1.11_{s}{s}", .{ os_str, arch_str });

    // Now in runtime, while building tree, check if paths exist
    const bin_exists = blk: {
        const root_path = std.fmt.comptimePrint("./{s}", .{root_name});
        std.fs.cwd().access(root_path, .{}) catch break :blk false;
        break :blk true;
    };
    const link_exists = bin_exists and blk: {
        const chips = [_][]const u8{ "msp430fr2433", "msp430fr2475", "msp430fr2476" };
        inline for (chips) |chip| {
            const path_main_ld = std.fmt.comptimePrint("./{s}/include/{s}.ld", .{ root_name, chip });
            std.fs.cwd().access(path_main_ld, .{}) catch break :blk false;
            const path_symbol_ld = std.fmt.comptimePrint("./{s}/include/{s}_symbols.ld", .{ root_name, chip });
            std.fs.cwd().access(path_symbol_ld, .{}) catch break :blk false;
        }
        break :blk true;
    };

    // If we are missing things, check if we have an archive to pull from

}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // options for desktop build

    const target_desktop = b.standardTargetOptions(.{});
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

    b.installArtifact(exe);

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

    // Toolchain management
}
