const std = @import("std");
const builtin = @import("builtin");

const MCUType = enum {
    msp430fr2433,
    msp430fr2475,
    msp430fr2476,
};

/// Converts a single ASCII character in a hexadecimal string into its value.
fn hexCharToValue(c: u8) u8 {
    return switch (c) {
        '0'...'9' => c - 0x30, // ASCII '0'
        'a', 'A' => 0xA,
        'b', 'B' => 0xB,
        'c', 'C' => 0xC,
        'd', 'D' => 0xD,
        'e', 'E' => 0xE,
        'f', 'F' => 0xF,
        else => @panic("Invalid hex character."),
    };
}

/// Converts a hexadecimal string into an array of u8.
/// `hexToArray("ff0510") = [255, 5, 16]`
fn hexToArray(comptime s: []const u8) [s.len / 2]u8 {
    comptime {
        std.debug.assert(s.len != 0);
        std.debug.assert(s.len & 1 == 0);
        var out: [s.len / 2]u8 = undefined;
        for (out, 0..) |_, i| {
            out[i] = ((hexCharToValue(s[i * 2]) << 4) | hexCharToValue(s[i * 2 + 1]));
        }
        return out;
    }
}

/// Given a file path, checks if the file matches a provided MD5 hash.
fn checkFileHash(path: []const u8, out: *[std.crypto.hash.Md5.digest_length]u8) !void {
    var buf: [8192]u8 = undefined;
    const file = try std.fs.cwd().openFile(path, .{});
    var hash = std.crypto.hash.Md5.init(.{});
    while (true) {
        const len = try file.read(&buf);
        if (len == 0) break;
        hash.update(buf[0..len]);
    }
    hash.final(out);
}

/// Returns a step that will download and install TI's tools for MSP430 if available for the current platform.
fn createInstallBuildToolchain(b: *std.Build, target: *const std.Build.ResolvedTarget, optimize: *const std.builtin.OptimizeMode) !?*std.Build.Step {
    // Build the appropriate package name based on builtin (works at comptime)
    const os_str = comptime switch (builtin.os.tag) {
        .windows => "win",
        .macos, .linux => |value| @tagName(value),
        else => |value| {
            std.log.warn("Unsupported OS {s} for TI toolchain.", .{@tagName(value)});
            return null;
        },
    };
    const arch_str = comptime if (builtin.os.tag == .macos) "" else switch (builtin.cpu.arch) {
        .x86_64,
        => "64",
        .x86,
        => "32",
        else => |value| blk: {
            std.log.warn("Non x86/x86_64 system {s} detected. Assuming 64 bit, but this script will likely result in failure.", .{@tagName(value)});
            break :blk 64;
        },
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
    const chips = [_][]const u8{ "msp430fr2433", "msp430fr2475", "msp430fr2476" };

    const link_exists = bin_exists and blk: {
        inline for (chips) |chip| {
            const path_main_ld = std.fmt.comptimePrint("./{s}/include/{s}.ld", .{ root_name, chip });
            std.fs.cwd().access(path_main_ld, .{}) catch break :blk false;
            const path_symbol_ld = std.fmt.comptimePrint("./{s}/include/{s}_symbols.ld", .{ root_name, chip });
            std.fs.cwd().access(path_symbol_ld, .{}) catch break :blk false;
        }
        break :blk true;
    };

    // If we are missing things, check if we have a reliable archive to pull from
    const need_download_bin: bool = if (bin_exists) false else blk: {
        // Compare checksums
        var chk_buf: [std.crypto.hash.Md5.digest_length]u8 = undefined;
        const bin_path = std.fmt.comptimePrint("./{s}.{s}", .{ root_name, archive_str });
        // Target will be set to the appropriate hash at comptime
        const target_hash = comptime switch (builtin.os.tag) {
            .windows => switch (builtin.cpu.arch) {
                .x86 => hexToArray("b8cebdeeced0299f741c9008f604c625"),
                else => hexToArray("88e052336145c0feda62f9dd09ccfeb0"),
            },
            .macos => hexToArray("c6a76c00ee31cd320dd97b7c2adc6664"),
            .linux => switch (builtin.cpu.arch) {
                .x86 => hexToArray("d9e1cfb60f959f333172b5a87102d53a"),
                else => hexToArray("b8745afb7a173120e83591cef2ac0427"),
            },
            else => unreachable,
        };
        // If the file isn't found, download it.
        checkFileHash(bin_path, &chk_buf) catch |err| switch (err) {
            std.fs.File.OpenError.FileNotFound => break :blk true,
            else => return err,
        };
        if (std.mem.eql(u8, &target_hash, &chk_buf)) {
            // If the hashes match, don't redownload.
            break :blk false;
        } else {
            // If not, the file is corrupt. Delete it and redownload.
            try std.fs.cwd().deleteFile(bin_path);
            break :blk true;
        }
    };
    const need_download_link: bool = if (link_exists) false else blk: {
        // Mostly the same as above.
        var chk_buf: [std.crypto.hash.Md5.digest_length]u8 = undefined;
        const target_hash = comptime hexToArray("1f316453879c0cdea3a83e152eac69c1");
        checkFileHash("./msp430-gcc-support-files-1.212.zip", &chk_buf) catch |err| switch (err) {
            std.fs.File.OpenError.FileNotFound => break :blk true,
            else => return err,
        };
        if (std.mem.eql(u8, &target_hash, &chk_buf)) {
            break :blk false;
        } else {
            try std.fs.cwd().deleteFile("./msp430-gcc-support-files-1.212.zip");
            break :blk true;
        }
    };

    // Start building the step we will return to be attached to the rest of the tree.
    var last_step: ?*std.Build.Step = null;

    // If we need to download something, build the downloader
    if (need_download_bin or need_download_link) {
        const dl = b.addExecutable(.{
            .name = "downloader",
            .optimize = optimize.*,
            .root_source_file = b.path("./src/build/downloader.zig"),
            .target = target.*,
        });
        if (need_download_bin) {
            const dl_bin = b.addRunArtifact(dl);
            dl_bin.addArg(std.fmt.comptimePrint("https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-LlCjWuAbzH/9.3.1.2/{s}.{s}", .{ root_name, archive_str }));
            if (last_step) |ls| {
                dl_bin.step.dependOn(ls);
            }
            last_step = &dl_bin.step;
        }
        if (need_download_link) {
            const dl_link = b.addRunArtifact(dl);
            dl_link.addArg("https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-LlCjWuAbzH/9.3.1.2/msp430-gcc-support-files-1.212.zip");
            if (last_step) |ls| {
                dl_link.step.dependOn(ls);
            }
            last_step = &dl_link.step;
        }
    }

    if (!bin_exists) {
        switch (builtin.os.tag) {
            .macos, .linux => {
                // Set up the run step
                const untar = b.addSystemCommand(&[_][]const u8{ "tar", "-xf" });
                untar.has_side_effects = false;

                const archive = std.fmt.allocPrint(b.allocator, "./{s}.tar.bz2", .{root_name}) catch @panic("OOM");
                //TODO: This may be able to take advantage of the caching system
                untar.addArg(archive);

                if (last_step) |ls| {
                    untar.step.dependOn(ls);
                }
                last_step = &untar.step;
            },
            .windows => {
                const UnzipStep = @import("./src/build/UnzipStep.zig");
                const unzip = UnzipStep.createAll(b, std.fmt.comptimePrint("./{s}.zip", .{root_name}));
                if (last_step) |ls| {
                    unzip.step.dependOn(ls);
                }
                last_step = &unzip.step;
            },
            else => unreachable,
        }
    }

    if (!link_exists) {
        // If the bin directory doesn't exist yet, checking for files would result in an error.
        // A lazy path must be used to work around this.
        const dir_str = std.fmt.comptimePrint("./{s}/include", .{root_name});
        const lazy_dir = b.path(dir_str);

        const neededFiles: [][]const u8 = blk: {
            const list = b.allocator.create([6][]const u8) catch @panic("OOM");
            if (bin_exists) {
                // The directory exists, so we can open it and tes
                var idx: usize = 0;
                var dir = try std.fs.cwd().openDir(std.fmt.comptimePrint("./{s}/include", .{root_name}), .{});
                defer dir.close();
                inline for (chips) |chip| {
                    dir.access(std.fmt.comptimePrint("./{s}.ld", .{chip}), .{}) catch |err| switch (err) {
                        error.FileNotFound => {
                            list[idx] = std.fmt.comptimePrint("msp430-gcc-support-files/include/{s}.ld", .{chip});
                            idx += 1;
                        },
                        else => return err,
                    };
                    dir.access(std.fmt.comptimePrint("./{s}_symbols.ld", .{chip}), .{}) catch |err| switch (err) {
                        error.FileNotFound => {
                            list[idx] = std.fmt.comptimePrint("msp430-gcc-support-files/include/{s}_symbols.ld", .{chip});
                            idx += 1;
                        },
                        else => return err,
                    };
                }
                break :blk list[0..idx];
            } else {
                // The directory does not exist, extract everything
                inline for (chips, 0..) |chip, i| {
                    list[i * 2] = std.fmt.comptimePrint("msp430-gcc-support-files/include/{s}.ld", .{chip});
                    list[i * 2 + 1] = std.fmt.comptimePrint("msp430-gcc-support-files/include/{s}_symbols.ld", .{chip});
                }
                break :blk list;
            }
        };
        const UnzipStep = @import("./src/build/UnzipStep.zig");
        const unzip = UnzipStep.createFiles(b, "./msp430-gcc-support-files-1.212.zip", lazy_dir, neededFiles);
        if (last_step) |ls| {
            unzip.step.dependOn(ls);
        }
        last_step = &unzip.step;
    }
    return last_step;
}

/// Returns a step that compiles MSPDebug for the current platform (ideally).
fn createInstallDeployToolchain(b: *std.Build, target: *const std.Build.ResolvedTarget, optimize: *const std.builtin.OptimizeMode) *std.Build.Step.Compile {
    //const libusb_dep = b.dependency("libusb", .{});

    const mspdebug_dep = b.dependency("mspdebug", .{});

    const mspdebug = b.addExecutable(.{
        .name = "mspdebug",
        .target = target.*,
        .optimize = optimize.*,
    });

    mspdebug.addCSourceFiles(.{
        .root = mspdebug_dep.path("."),
        .files = &.{
            "util/btree.c",
            "util/expr.c",
            "util/list.c",
            "util/sockets.c",
            "util/sport.c",
            "util/usbutil.c",
            "util/util.c",
            "util/vector.c",
            "util/output.c",
            "util/output_util.c",
            "util/opdb.c",
            "util/prog.c",
            "util/stab.c",
            "util/dis.c",
            "util/gdb_proto.c",
            "util/dynload.c",
            "util/demangle.c",
            "util/powerbuf.c",
            "util/ctrlc.c",
            "util/chipinfo.c",
            "util/gpio.c",
            "transport/cp210x.c",
            "transport/cdc_acm.c",
            "transport/ftdi.c",
            "transport/mehfet_xport.c",
            "transport/ti3410.c",
            "transport/comport.c",
            "transport/bslhid.c", // TODO: has a macos variant
            "transport/rf2500.c", // TODO: has a macos variant
            "drivers/device.c",
            "drivers/bsl.c",
            "drivers/fet.c",
            "drivers/fet_core.c",
            "drivers/fet_proto.c",
            "drivers/fet_error.c",
            "drivers/fet_db.c",
            "drivers/flash_bsl.c",
            "drivers/gdbc.c",
            "drivers/sim.c",
            "drivers/tilib.c",
            "drivers/goodfet.c",
            "drivers/obl.c",
            "drivers/devicelist.c",
            "drivers/fet_olimex_db.c",
            "drivers/jtdev.c",
            "drivers/jtdev_bus_pirate.c",
            "drivers/jtdev_gpio.c",
            "drivers/jtaglib.c",
            "drivers/mehfet_proto.c",
            "drivers/mehfet.c",
            "drivers/pif.c",
            "drivers/loadbsl.c",
            "drivers/loadbsl_fw.c",
            "drivers/hal_proto.c",
            "drivers/v3hil.c",
            "drivers/fet3.c",
            "drivers/bsllib.c",
            "drivers/rom_bsl.c",
            "drivers/tilib_api.c",
            "formats/binfile.c",
            "formats/coff.c",
            "formats/elf32.c",
            "formats/ihex.c",
            "formats/symmap.c",
            "formats/srec.c",
            "formats/titext.c",
            "simio/simio.c",
            "simio/simio_tracer.c",
            "simio/simio_timer.c",
            "simio/simio_wdt.c",
            "simio/simio_hwmult.c",
            "simio/simio_gpio.c",
            "simio/simio_console.c",
            "ui/gdb.c",
            "ui/rtools.c",
            "ui/sym.c",
            "ui/devcmd.c",
            "ui/flatfile.c",
            "ui/reader.c",
            "ui/cmddb.c",
            "ui/stdcmd.c",
            "ui/aliasdb.c",
            "ui/power.c",
            "ui/input.c",
            "ui/input_async.c",
            "ui/input_console.c",
            "ui/main.c",
        },
        .flags = &.{"-DLIB_DIR=\"/dev/null\""},
    });

    mspdebug.addIncludePath(mspdebug_dep.path("."));
    mspdebug.addIncludePath(mspdebug_dep.path("simio"));
    mspdebug.addIncludePath(mspdebug_dep.path("formats"));
    mspdebug.addIncludePath(mspdebug_dep.path("transport"));
    mspdebug.addIncludePath(mspdebug_dep.path("drivers"));
    mspdebug.addIncludePath(mspdebug_dep.path("util"));
    mspdebug.addIncludePath(mspdebug_dep.path("ui"));

    mspdebug.linkLibC();
    mspdebug.linkSystemLibrary("usb");

    return mspdebug;
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
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

    // Remove CFI directives
    // Note: If you are changing this file, you will probably need to delete your .zig-cache.
    // This does not play nice with the caching system, but once it works it works.
    const RemoveCFIStep = @import("./src/build/RemoveCFIStep.zig");
    const remove = RemoveCFIStep.create(b, build_object.getEmittedAsm());
    remove.step.dependOn(&build_object.step);

    const install_asm = b.addInstallFile(remove.getOutput(), "gol_card.s");
    install_asm.step.dependOn(&remove.step);

    const build_asm = b.step("msp430-asm", "Build the assembly for the MSP430.");
    build_asm.dependOn(&install_asm.step);

    // Toolchain management
    // Build toolchainxedFileArg("", lp: std.Build.LazyPath)
    const maybe_toolchain = try createInstallBuildToolchain(b, &target_desktop, &optimize_desktop);
    const mcu = b.option(MCUType, "mmcu", "The MCU to build for. This adjust the linker scripts. Default ???") orelse MCUType.msp430fr2433;

    const gcc_args = [_][]const u8{ "./msp430-gcc-9.3.1.11_linux64/bin/msp430-elf-gcc", "-L=./msp430-gcc-9.3.1.11_linux64/include", "-g", "-ogol_card.elf" };
    const gcc_embedded = b.addSystemCommand(&gcc_args);
    gcc_embedded.has_side_effects = false;
    gcc_embedded.addArg(std.fmt.allocPrint(b.allocator, "-mmcu={s}", .{@tagName(mcu)}) catch @panic("OOM"));
    gcc_embedded.addFileArg(remove.getOutput());
    //gcc_embedded.addArg("-lmul_32");
    if (maybe_toolchain) |tc| {
        gcc_embedded.step.dependOn(tc);
    }
    gcc_embedded.step.dependOn(&install_asm.step);

    const build_embedded = b.step("msp430", "Builds the binary for the MSP430.");
    build_embedded.dependOn(&gcc_embedded.step);

    // Deploy toolchain
    const msp = createInstallDeployToolchain(b, &target_desktop, &optimize_desktop);

    const msp_install = b.addInstallArtifact(msp, .{});
    const msp_run = b.addRunArtifact(msp);
    const msp_step = b.step("mspdebug", "Run mspdebug.");
    msp_step.dependOn(&msp_run.step);
    msp_step.dependOn(&msp_install.step);

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
        msp_run.addArgs(args);
    }
}
