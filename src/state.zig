///! The platform independent state for the board. Marked extern to ensure consistent memory layout.
const std = @import("std");

pub const State = extern struct {
    // size of board and window
    pub const width = 360;
    comptime {
        std.debug.assert(width % 8 == 0); // this makes copying rows much easier
    }
    pub const height = 240;

    reset_next: bool = false,
    crc_idx: u8 = 0,
    step_count: u16 = 0,
    past_crc: [4]u16 = undefined,
    board: [(width * height) / 8]u8 = undefined,
};
