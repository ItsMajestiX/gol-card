const rl = @import("raylib");
const std = @import("std");
const bitmapGet = @import("./bmutil.zig").bitmapGet;
const getRow = @import("./bmutil.zig").getRow;
const State = @import("./state.zig").State;
const width = @import("./state.zig").State.width;
const height = @import("./state.zig").State.height;

var framebuffer: [width * height]u8 = undefined;
const img = rl.Image{ .data = &framebuffer, .format = rl.PixelFormat.pixelformat_uncompressed_grayscale, .height = height, .width = width, .mipmaps = 1 };
var texture: ?rl.Texture = null;

var fileHandle: ?std.fs.File = null;

var crc: std.hash.crc.Crc16Ibm3740 = undefined;

var state: State = State{};

pub fn preUpdate() *State {
    current_row = 0;
    if (texture == null) {
        texture = rl.loadTextureFromImage(img);
    }
    // This CRC matches the one on the MCU
    crc = std.hash.crc.Crc16Ibm3740.init();
    // Open/create file.
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
        if (len != @sizeOf(State)) {
            std.log.warn("File size {d} not equal to state size, regenerating\n", .{len});
            fileHandle.?.setEndPos(0) catch unreachable;
            var rng = std.Random.DefaultPrng.init(std.crypto.random.int(u64));
            rng.fill(&state.board);
        } else {
            const stateSlice = @as([*]u8, @ptrCast(&state))[0..@sizeOf(State)];
            _ = fileHandle.?.readAll(stateSlice) catch unreachable;
        }
    }
    return &state;
}

var current_row: usize = 0;
pub fn markComplete() void {
    for (0..width) |i| {
        framebuffer[width * current_row + i] = ~bitmapGet(getRow(&state.board, current_row, width), i) +% 1;
    }
    current_row += 1;
}

pub fn newByte(b: u8) void {
    crc.update(&[1]u8{b});
}

pub fn getCRC() u16 {
    return crc.final();
}

pub fn postUpdate() void {
    rl.updateTexture(texture.?, &framebuffer);
    rl.drawTextureEx(texture.?, rl.Vector2.zero(), 0.0, 3.0, rl.Color.white);
    if (fileHandle) |fh| {
        fh.seekTo(0) catch unreachable;
        const stateSlice = @as([*]u8, @ptrCast(&state))[0..@sizeOf(State)];
        fh.writeAll(stateSlice) catch unreachable;
        fh.close();
        fileHandle = null;
    }
}

pub fn getSeed() [4]u64 {
    var temp: [4]u64 = undefined;
    for (&temp) |*i| {
        i.* = std.crypto.random.int(u64);
    }
    return temp;
}

pub fn markAllComplete() void {
    for (0..height) |_| {
        markComplete();
    }
}
