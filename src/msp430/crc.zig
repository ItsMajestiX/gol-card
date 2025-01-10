const CRCDIRB_L: *volatile u8 = @extern(*volatile u8, .{ .name = "CRCDIRB_L" });

const CRCINIRES: *volatile u16 = @extern(*volatile u16, .{ .name = "CRCINIRES" });

pub inline fn initCRC() void {
    CRCINIRES.* = 0xFFFF; // should be set to this on reset anyways
}

pub inline fn addCRC(b: u8) void {
    CRCDIRB_L.* = b;
}

pub inline fn finalCRC() u16 {
    return CRCINIRES.*;
}
