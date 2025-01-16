const builtin = @import("builtin");
const hal = if (builtin.cpu.arch == .msp430) @import("./hal-embedded.zig") else @import("./hal-desktop.zig");
const bitmapGet = @import("./bmutil.zig").bitmapGet;
const getRow = @import("./bmutil.zig").getRow;
const width = @import("./state.zig").State.width;
const height = @import("./state.zig").State.height;
const std = @import("std");

const stateTable = table: {
    var table: [64]u8 = undefined;
    @memset(&table, 0);
    for (0..512) |i| {
        const neighborhood = (i & 1) + ((i >> 1) & 1) + ((i >> 2) & 1) + ((i >> 3) & 1) + ((i >> 5) & 1) + ((i >> 6) & 1) + ((i >> 7) & 1) + ((i >> 8) & 1);
        if (((i >> 4) & 1) > 0) {
            table[i / 8] |= @as(u8, @intFromBool((neighborhood >= 2) and (neighborhood <= 3))) << @as(u3, i & 0x7);
        } else {
            table[i / 8] |= @as(u8, @intFromBool(neighborhood == 3)) << @as(u3, i & 0x7);
        }
    }
    break :table table;
};

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

fn shiftInRight(lookup: u16, row: []const u8, top: []const u8, bottom: []const u8, col: usize) u16 {
    var newLookup = lookup;
    newLookup <<= 3;
    newLookup &= 0x1FF;
    newLookup |= (bitmapGet(top, col) << 2);
    newLookup |= (bitmapGet(row, col) << 1);
    newLookup |= (bitmapGet(bottom, col));
    return newLookup;
}

test "shiftInRight" {
    const top: [1]u8 = .{0xAA}; // 01010101, because lsb is on left
    const mid: [1]u8 = .{0xBB}; // 11011101
    const bot: [1]u8 = .{0x33}; // 11001100

    var currentLookup: u9 = 0;
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 0);
    try std.testing.expect(currentLookup == 0x03); // 000 000 011
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 1);
    try std.testing.expect(currentLookup == 0x1F); // 000 011 111
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 2);
    try std.testing.expect(currentLookup == 0xF8); // 011 111 000
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 3);
    try std.testing.expect(currentLookup == 0x1C6); // 111 000 110
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 4);
    try std.testing.expect(currentLookup == 0x33); // 000 110 011
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 5);
    try std.testing.expect(currentLookup == 0x19F); // 110 011 111
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 6);
    try std.testing.expect(currentLookup == 0xF8); // 011 111 000
    currentLookup = shiftInRight(currentLookup, &mid, &top, &bot, 7);
    try std.testing.expect(currentLookup == 0x1C6); // 111 000 110
}

fn stepRow(row: []const u8, top: []const u8, bottom: []const u8) [width / 8]u8 {
    // set up variables
    var res: [width / 8]u8 = undefined;
    var currentByte: u8 = 0;
    var lookupByte: u16 = 0;

    // shift in the column on the other side of the board
    lookupByte = shiftInRight(lookupByte, row, top, bottom, width - 1);
    // shift in the column at index 0
    lookupByte = shiftInRight(lookupByte, row, top, bottom, 0);
    // shift in the column at index 1
    lookupByte = shiftInRight(lookupByte, row, top, bottom, 1);
    for (0..(width - 2)) |i| {
        // compute the new state of the cell at i
        currentByte |= bitmapGet(&stateTable, lookupByte) << @truncate(i & 0x7);
        // when we are full, add to the array and reset the storage
        if (i & 0x7 == 7) {
            hal.newByte(currentByte);
            res[i / 8] = currentByte;
            currentByte = 0;
        }
        // shift in the column at index i+2 before looping around
        lookupByte = shiftInRight(lookupByte, row, top, bottom, i + 2);
    }
    // compute the cell with the data currently in the lookup byte
    currentByte |= bitmapGet(&stateTable, lookupByte) << 6;
    // last cell in the row, so loop around to the beginning
    lookupByte = shiftInRight(lookupByte, row, top, bottom, 0);
    currentByte |= bitmapGet(&stateTable, lookupByte) << 7;
    // since the width must be divisible by 8, we know that the last byte is ready
    res[res.len - 1] = currentByte;
    return res;
}

test "stepRow" {
    const top: [1]u8 = .{0xAA}; // 01010101, because lsb is on left
    const mid: [1]u8 = .{0xBB}; // 11011101
    const bot: [1]u8 = .{0x33}; // 11001100

    const test1 = stepRow(&mid, &top, &bot, 8);
    const expected1: [1]u8 = .{0b10001000};
    try std.testing.expect(std.mem.eql(u8, &test1, &expected1));
}

fn updateBoard(board: []u8) void {
    var row0: [width / 8]u8 = undefined;
    @memcpy(&row0, getRow(board, 0, width));

    var topRow: [width / 8]u8 = undefined; // not a slice, the middle row will be overwritten
    @memcpy(&topRow, getRow(board, height - 1, width));
    var middleRow: []u8 = row0[0..];
    var bottomRow: []u8 = getRow(board, 1, width);

    for (0..(height - 2)) |i| {
        const newRow = stepRow(middleRow, &topRow, bottomRow);
        @memcpy(&topRow, middleRow);
        @memcpy(getRow(board, i, width), &newRow);
        hal.markComplete();
        middleRow = bottomRow;
        bottomRow = getRow(board, (i + 2), width);
    }
    var newRow = stepRow(middleRow, &topRow, bottomRow); // remove from loop to avoid branch
    @memcpy(&topRow, middleRow);
    @memcpy(getRow(board, height - 2, width), &newRow);
    hal.markComplete();
    middleRow = bottomRow;
    bottomRow = &row0; // wrap around
    newRow = stepRow(middleRow, &topRow, bottomRow);
    @memcpy(getRow(board, height - 1, width), &newRow); // do not need to save
    hal.markComplete();
}

test "updateBoard" {
    var board1_t0: [8]u8 = .{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }; // every cell should die due to overpopulation
    const board1_t1: [8]u8 = .{ 0, 0, 0, 0, 0, 0, 0, 0 };
    updateBoard(&board1_t0, 8, 8);
    try std.testing.expect(std.mem.eql(u8, &board1_t0, &board1_t1));

    var board2_t0: [8]u8 = .{ 0x70, 0x43, 0xAD, 0xAA, 0xF5, 0x8A, 0x74, 0x66 }; // we assume stepRow is reliable
    const board2_t1: [8]u8 = .{
        stepRow(board2_t0[0..1], board2_t0[7..8], board2_t0[1..2], 8)[0],
        stepRow(board2_t0[1..2], board2_t0[0..1], board2_t0[2..3], 8)[0],
        stepRow(board2_t0[2..3], board2_t0[1..2], board2_t0[3..4], 8)[0],
        stepRow(board2_t0[3..4], board2_t0[2..3], board2_t0[4..5], 8)[0],
        stepRow(board2_t0[4..5], board2_t0[3..4], board2_t0[5..6], 8)[0],
        stepRow(board2_t0[5..6], board2_t0[4..5], board2_t0[6..7], 8)[0],
        stepRow(board2_t0[6..7], board2_t0[5..6], board2_t0[7..8], 8)[0],
        stepRow(board2_t0[7..8], board2_t0[6..7], board2_t0[0..1], 8)[0],
    };
    updateBoard(&board2_t0, 8, 8);
    try std.testing.expect(std.mem.eql(u8, &board2_t0, &board2_t1));
}

fn randomizeBoard(board: []u8) void {
    const seed: [4]u64 = hal.getSeed();
    var rng = std.Random.Xoshiro256{ .s = seed };
    rng.fill(board);
    hal.markAllComplete();
}

pub fn step() void {
    const state = hal.preUpdate();
    // hal.initDisplay();
    // defer hal.closeDisplay();
    //const board: []u8 = hal.loadBoard();
    //defer hal.saveBoard(board);
    if (state.reset_next) {
        randomizeBoard(&state.board);
        state.reset_next = false;
        state.step_count = 0;
    } else {
        state.step_count += 1;
        const max_steps = 4032; // two weeks
        updateBoard(&state.board);
        state.reset_next = (state.step_count >= max_steps) or blk: {
            const current_crc = hal.getCRC();
            for (state.past_crc) |past_crc| {
                if (past_crc == current_crc) {
                    break :blk true;
                }
            }
            state.past_crc[state.crc_idx] = current_crc;
            state.crc_idx += 1;
            if (state.crc_idx >= state.past_crc.len) {
                state.crc_idx = 0;
            }
            break :blk false;
        };
    }
    hal.postUpdate();
}
