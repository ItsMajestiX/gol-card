const rl = @import("raylib");
const std = @import("std");

const aliveTable = table: {
    var table: [32]u8 = undefined;
    @memset(&table, 0);
    for (0..256) |i| {
        const neighborhood = (i & 1) + ((i >> 1) & 1) + ((i >> 2) & 1) + ((i >> 3) & 1) + ((i >> 4) & 1) + ((i >> 5) & 1) + ((i >> 6) & 1) + ((i >> 7) & 1);
        table[i / 8] = table[i / 8] | (@as(u8, @intFromBool((neighborhood >= 2) and (neighborhood <= 3))) << @as(u3, i & 0x7));
    }
    break :table table;
};
const deadTable = table: {
    var table: [32]u8 = undefined;
    @memset(&table, 0);
    for (0..256) |i| {
        const neighborhood = (i & 1) + ((i >> 1) & 1) + ((i >> 2) & 1) + ((i >> 3) & 1) + ((i >> 4) & 1) + ((i >> 5) & 1) + ((i >> 6) & 1) + ((i >> 7) & 1);
        table[i / 8] = table[i / 8] | (@as(u8, @intFromBool(neighborhood == 3)) << @as(u3, i & 0x7));
    }
    break :table table;
};

pub fn bitmapGet(bm: []const u8, idx: usize) u8 {
    return (bm[idx / 8] >> @truncate(idx & 0x7)) & 0x1;
}

test "bitmapGet" {
    const bm: [2]u8 = .{ 0x11, 0x22 };
    try std.testing.expect(bitmapGet(&bm, 0) == 1); // 0x11 = 0b00010001
    try std.testing.expect(bitmapGet(&bm, 1) == 0);
    try std.testing.expect(bitmapGet(&bm, 4) == 1);

    try std.testing.expect(bitmapGet(&bm, 8) == 0); // 0x22 = 0b00100010
    try std.testing.expect(bitmapGet(&bm, 9) == 1);
    try std.testing.expect(bitmapGet(&bm, 13) == 1);
    try std.testing.expect(bitmapGet(&bm, 15) == 0);
}

pub fn getRow(board: []u8, row: usize, width: comptime_int) []u8 {
    return board[(width * row / 8)..(width * (row + 1) / 8)];
}

fn sliceCompare(a: []u8, b: []u8) bool {
    if (a.len != b.len) {
        std.debug.print("a len: {d} != b len: {d}\n", .{ a.len, b.len });
        return false;
    }
    if (@intFromPtr(a.ptr) != @intFromPtr(b.ptr)) {
        std.debug.print("a ptr: {X} != b ptr: {X}\n", .{ @intFromPtr(a.ptr), @intFromPtr(b.ptr) });
        return false;
    }
    return true;
}

test "getRow" {
    const board: [8]u8 = .{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 };
    try std.testing.expect(sliceCompare(getRow(@constCast(&board), 0, 8), @constCast(board[0..1])));
    try std.testing.expect(sliceCompare(getRow(@constCast(&board), 1, 8), @constCast(board[1..2])));
    try std.testing.expect(sliceCompare(getRow(@constCast(&board), 7, 8), @constCast(board[7..8])));
    try std.testing.expect(sliceCompare(getRow(@constCast(&board), 0, 16), @constCast(board[0..2])));
    try std.testing.expect(sliceCompare(getRow(@constCast(&board), 3, 16), @constCast(board[6..8])));
    try std.testing.expect(sliceCompare(getRow(@constCast(&board), 0, 64), @constCast(board[0..])));
}

pub fn shiftInRight(lookup: u8, row: []const u8, top: []const u8, bottom: []const u8, col: usize) u8 {
    var newLookup = lookup;
    newLookup = @shlWithOverflow(newLookup, 3)[0];
    newLookup = std.math.rotl(u8, newLookup, 1);
    newLookup &= 0xF0;
    newLookup |= (bitmapGet(row, col - 1) << 3);
    newLookup |= (bitmapGet(row, col) << 2);
    newLookup |= (bitmapGet(top, col) << 1);
    newLookup |= (bitmapGet(bottom, col));
    newLookup = std.math.rotl(u8, newLookup, 2);
    return newLookup;
}

test "shiftInRight" {
    const top: [1]u8 = .{0xAA}; // 01010101, because lsb is on left
    const mid: [1]u8 = .{0xBB}; // 11011101
    const bot: [1]u8 = .{0x33}; // 11001100

    var currentLookup: u8 = 0;
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 1); // not 0, that causes an out of bounds
    try std.testing.expect(currentLookup == 0x3C); // 00111100
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 2);
    try std.testing.expect(currentLookup == 0x23); // 00100011
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 3);
    try std.testing.expect(currentLookup == 0xD8); // 11011000
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 4);
    try std.testing.expect(currentLookup == 0x36); // 00110110
}

pub fn shiftInRightOverflow(lookup: u8, row: []const u8, top: []const u8, bottom: []const u8) u8 {
    var newLookup = lookup;
    newLookup = @shlWithOverflow(newLookup, 3)[0];
    newLookup = std.math.rotl(u8, newLookup, 1);
    newLookup &= 0xF0;
    newLookup |= (bitmapGet(row, row.len * 8 - 1) << 3);
    newLookup |= (bitmapGet(row, 0) << 2);
    newLookup |= (bitmapGet(top, 0) << 1);
    newLookup |= (bitmapGet(bottom, 0));
    newLookup = std.math.rotl(u8, newLookup, 2);
    return newLookup;
}

test "shiftInRightOverflow" {
    const top: [1]u8 = .{0xAA}; // 01010101, because lsb is on left
    const mid: [1]u8 = .{0xBB}; // 11011101
    const bot: [1]u8 = .{0x33}; // 11001100

    var currentLookup: u8 = 0;
    currentLookup = shiftInRightOverflow(currentLookup, &mid, &top, &bot); // this function is designed to get index 0
    try std.testing.expect(currentLookup == 0x34); // 00110100
}

pub fn stepRow(row: []u8, top: []u8, bottom: []u8, width: comptime_int) [width / 8]u8 {
    var res: [width / 8]u8 = undefined;
    var currentByte: u8 = 0;
    var lookupByte: u8 = 0;

    lookupByte = shiftInRight(lookupByte, row, top, bottom, width - 1);
    lookupByte = shiftInRightOverflow(lookupByte, row, top, bottom);
    for (0..(width - 1)) |i| {
        lookupByte = shiftInRight(lookupByte, row, top, bottom, i + 1);
        currentByte |= (if (bitmapGet(row, i) > 0) bitmapGet(&aliveTable, lookupByte) else bitmapGet(&deadTable, lookupByte)) << 7;
        if (i & 0x7 == 7) {
            res[i / 8] = currentByte;
            currentByte = 0;
        } else {
            currentByte >>= 1;
        }
    }
    lookupByte = shiftInRightOverflow(lookupByte, row, top, bottom); // duplicate to avoid branch
    currentByte |= (if (bitmapGet(row, width - 1) > 0) bitmapGet(&aliveTable, lookupByte) else bitmapGet(&deadTable, lookupByte)) << 7;
    res[res.len - 1] = currentByte;
    return res;
}

pub fn updateBoard(board: []u8, width: comptime_int, height: comptime_int) void {
    var row0: [width / 8]u8 = undefined;
    @memcpy(&row0, getRow(board, 0, width));

    var topRow: [width / 8]u8 = undefined; // not a slice, the middle row will be overwritten
    @memcpy(&topRow, getRow(board, height - 1, width));
    var middleRow: []u8 = row0[0..];
    var bottomRow: []u8 = getRow(board, 1, width);

    for (0..(height - 2)) |i| {
        const newRow = stepRow(middleRow, &topRow, bottomRow, width);
        @memcpy(&topRow, middleRow);
        @memcpy(board[(width / 8 * i)..(width / 8 * (i + 1))], &newRow);
        middleRow = bottomRow;
        bottomRow = getRow(board, (i + 2), width);
    }
    var newRow = stepRow(middleRow, &topRow, bottomRow, width); // remove from loop to avoid branch
    @memcpy(&topRow, middleRow);
    @memcpy(board[(width / 8 * (height - 2))..(width / 8 * (height - 1))], &newRow);
    middleRow = bottomRow;
    bottomRow = &row0; // wrap around
    newRow = stepRow(middleRow, &topRow, bottomRow, width);
    @memcpy(board[(width / 8 * (height - 1))..(width / 8 * height)], &newRow); // do not need to save
}

pub fn main() anyerror!void {
    // size of board and window
    const width = 360;
    comptime {
        std.debug.assert(width % 8 == 0); // this makes copying rows much easier
    }
    const height = 240;

    rl.initWindow(width * 3, height * 3, "Game of Life Card Simulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    std.debug.print("{any}\n{any}\n", .{ aliveTable, deadTable });

    var field: [(width * height + 7) / 8]u8 = undefined;
    var rng = std.rand.DefaultPrng.init(std.crypto.random.int(u64));
    rng.fill(&field);

    var framebuffer: [width * height]u8 = undefined;
    @memset(&framebuffer, 0);
    const img = rl.Image{ .data = &framebuffer, .format = rl.PixelFormat.pixelformat_uncompressed_grayscale, .height = height, .width = width, .mipmaps = 1 };
    const texture = rl.loadTextureFromImage(img);
    for (0..(width * height)) |i| {
        framebuffer[i] = (~bitmapGet(&field, i)) +% 1;
    }
    rl.updateTexture(texture, &framebuffer);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        //rl.drawTexture(texture, 0, 0, rl.Color.white);
        rl.drawTextureEx(texture, rl.Vector2.zero(), 0.0, 3.0, rl.Color.white);
        rl.endDrawing();
        if (rl.isKeyPressed(rl.KeyboardKey.key_e)) {
            updateBoard(&field, width, height);
            for (0..(width * height)) |i| {
                framebuffer[i] = (~bitmapGet(&field, i)) +% 1;
            }
            rl.updateTexture(texture, &framebuffer);
        }
    }
}
