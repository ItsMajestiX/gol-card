pub fn bitmapGet(bm: []const u8, idx: usize) u8 {
    return (bm[idx / 8] >> @truncate(idx & 0x7)) & 0x1;
}
