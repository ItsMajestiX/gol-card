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

pub fn coordinateToIndex(x: usize, y: usize, width: usize) usize {
    return (width * y + x) / 8;
}

pub fn getRow(board: []u8, row: usize, width: comptime_int) []u8 {
    return board[coordinateToIndex(0, row, width)..coordinateToIndex(0, row + 1, width)];
}

pub fn shiftInRight(lookup: u8, row: []u8, top: []u8, bottom: []u8, col: usize) u8 {
    var newLookup = lookup;
    newLookup <<= 3;
    newLookup = std.math.rotl(u8, newLookup, 1);
    newLookup |= (bitmapGet(row, col - 1) << 3);
    newLookup |= (bitmapGet(row, col) << 2);
    newLookup |= (bitmapGet(top, col) << 1);
    newLookup |= (bitmapGet(bottom, col));
    newLookup = std.math.rotl(u8, newLookup, 2);
    return newLookup;
}

pub fn shiftInRightOverflow(lookup: u8, row: []u8, top: []u8, bottom: []u8) u8 {
    var newLookup = lookup;
    newLookup <<= 3;
    newLookup = std.math.rotl(u8, newLookup, 1);
    newLookup |= (bitmapGet(row, row.len - 1) << 3);
    newLookup |= (bitmapGet(row, 0) << 2);
    newLookup |= (bitmapGet(top, 0) << 1);
    newLookup |= (bitmapGet(bottom, 0));
    newLookup = std.math.rotl(u8, newLookup, 2);
    return newLookup;
}

pub fn stepRow(row: []u8, top: []u8, bottom: []u8, width: comptime_int) [width / 8]u8 {
    var res: [width / 8]u8 = undefined;
    var currentByte: u8 = 0;
    var lookupByte: u8 = 0;

    lookupByte = shiftInRight(lookupByte, row, top, bottom, row.len - 1);
    lookupByte = shiftInRightOverflow(lookupByte, row, top, bottom);
    for (0..(row.len - 1)) |i| {
        lookupByte = shiftInRight(lookupByte, row, top, bottom, i + 1);
        currentByte |= (if (bitmapGet(row, i) > 0) bitmapGet(&aliveTable, lookupByte) else bitmapGet(&deadTable, lookupByte)) << 7;
        if (currentByte & 0x7 == 7) {
            res[i / 8] = currentByte;
            currentByte = 0;
        } else {
            currentByte >>= 1;
        }
    }
    lookupByte = shiftInRightOverflow(lookupByte, row, top, bottom); // duplicate to avoid branch
    currentByte |= (if (bitmapGet(row, row.len - 1) > 0) bitmapGet(&aliveTable, lookupByte) else bitmapGet(&deadTable, lookupByte)) << 7;
    res[(row.len - 1) / 8] = currentByte;
    return res;
}

pub fn updateBoard(board: []u8, width: comptime_int, height: comptime_int) void {
    var row0: [width / 8]u8 = undefined;
    const row0slice = getRow(board, 0, width);
    std.debug.print("{d} {d}\n", .{ row0.len, row0slice.len });
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

    rl.initWindow(width, height, "Game of Life Card Simulator");
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
        rl.drawTexture(texture, 0, 0, rl.Color.white);
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
