pub fn bitmapGet(bm: []const u8, idx: usize) u8 {
    return (bm[idx / 8] >> @truncate(idx & 0x7)) & 0x1;
}

pub fn getRow(board: []u8, row: usize, width: comptime_int) []u8 {
    return board[(width * row / 8)..(width * (row + 1) / 8)];
}
