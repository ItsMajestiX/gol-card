const rl = @import("raylib");
const std = @import("std");
const bitmapGet = @import("./bitmapget.zig").bitmapGet;

// size of board and window
pub const width = 360;
comptime {
    std.debug.assert(width % 8 == 0); // this makes copying rows much easier
}
pub const height = 240;

var framebuffer: [width * height]u8 = undefined;
const img = rl.Image{ .data = &framebuffer, .format = rl.PixelFormat.pixelformat_uncompressed_grayscale, .height = height, .width = width, .mipmaps = 1 };
var texture: ?rl.Texture = null;
pub fn initDisplay() void {
    if (texture == null) {
        texture = rl.loadTextureFromImage(img);
    }
}
pub fn closeDisplay() void {
    rl.updateTexture(texture.?, &framebuffer);
    rl.drawTextureEx(texture.?, rl.Vector2.zero(), 0.0, 3.0, rl.Color.white);
}
var row_idx: u32 = 0;
comptime {
    std.debug.assert((1 << @typeInfo(@TypeOf(row_idx)).Int.bits) >= height);
}
pub fn sendRow(row: []const u8) void {
    for (0..(row.len * 8)) |i| {
        framebuffer[width * row_idx + i] = ~bitmapGet(row, i) +% 1;
    }
    row_idx += 1;
    if (row_idx == height) {
        row_idx = 0;
    }
}

var board_arr: [(width * height + 7) / 8]u8 = undefined;
var fileHandle: ?std.fs.File = null;
pub fn loadBoard() []u8 {
    if (fileHandle == null) {
        fileHandle = std.fs.cwd().openFile("state.bin", std.fs.File.OpenFlags{ .mode = .read_write }) catch |err| handleErr: {
            switch (err) {
                error.FileNotFound => {
                    break :handleErr std.fs.cwd().createFile("state.bin", std.fs.File.CreateFlags{ .read = true }) catch unreachable;
                },
                else => {
                    unreachable;
                },
            }
        };
        const len = fileHandle.?.getEndPos() catch unreachable;
        if (len != board_arr.len) {
            std.debug.print("file size {d} not equal to buffer, regenerating\n", .{len});
            fileHandle.?.setEndPos(0) catch unreachable;
            var rng = std.rand.DefaultPrng.init(std.crypto.random.int(u64));
            rng.fill(&board_arr);
        } else {
            _ = fileHandle.?.readAll(&board_arr) catch unreachable;
        }
    }
    return &board_arr;
}
pub fn saveBoard(board: []const u8) void {
    fileHandle.?.seekTo(0) catch unreachable;
    fileHandle.?.writeAll(board) catch unreachable;
    fileHandle.?.close();
    fileHandle = null;
}
