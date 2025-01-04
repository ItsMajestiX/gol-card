const std = @import("std");

const UnzipStep = @This();

const UnzipMode = union(enum) {
    All,
    Files: struct { files: []const []const u8 = undefined, dir: std.Build.LazyPath },
};

fn make(step: *std.Build.Step, opt: std.Build.Step.MakeOptions) anyerror!void {
    var progress = opt.progress_node.start("Unzipping File", 1);
    const self: *UnzipStep = @fieldParentPtr("step", step);
    const file = try std.fs.cwd().openFile(self.path, .{});
    switch (self.mode) {
        .All => {
            try std.zip.extract(std.fs.cwd(), file.seekableStream(), .{});
        },
        .Files => |file_struct| {
            var dir_actual = try std.fs.openDirAbsolute(file_struct.dir.getPath(step.owner), .{});
            defer dir_actual.close();
            const custom_zip = @import("./custom-zip.zig");
            try custom_zip.extract(dir_actual, file.seekableStream(), file_struct.files);
        },
    }
    progress.end();
}

step: std.Build.Step,
mode: UnzipMode,

path: []const u8,

pub fn createAll(owner: *std.Build, comptime path: []const u8) *UnzipStep {
    const unzip = owner.allocator.create(UnzipStep) catch @panic("OOM");
    unzip.* = .{
        .mode = .All,
        .path = path,
        .step = std.Build.Step.init(.{
            .id = std.Build.Step.Id.custom,
            .makeFn = make,
            .name = std.fmt.comptimePrint("unzip {s}", .{path}),
            .owner = owner,
        }),
    };
    return unzip;
}

pub fn createFiles(owner: *std.Build, comptime path: []const u8, dir: std.Build.LazyPath, files: []const []const u8) *UnzipStep {
    const unzip = owner.allocator.create(UnzipStep) catch @panic("OOM");
    unzip.* = .{
        .mode = .{ .Files = .{
            .dir = dir,
            .files = files,
        } },
        .path = path,
        .step = std.Build.Step.init(.{
            .id = std.Build.Step.Id.custom,
            .makeFn = make,
            .name = std.fmt.comptimePrint("unzip {s}", .{path}),
            .owner = owner,
        }),
    };
    return unzip;
}
