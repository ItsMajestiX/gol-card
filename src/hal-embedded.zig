const std = @import("std");
// size of board and window
pub const width = 360;
comptime {
    std.debug.assert(width % 8 == 0); // this makes copying rows much easier
}
pub const height = 240;

// If board is just set to var, the linker will place it in RAM and fail. If board is marked const, Zig will optimize away
// memcpy calls to it. This should tell the linker to place the object in FRAM but tell Zig that it can be mutated.
comptime {
    @export(&board, .{
        .name = "hal-embedded.board",
        .section = ".persistent",
    });
}
var board: [(width * height) / 8]u8 = undefined;

pub fn initDisplay() void {}
pub fn closeDisplay() void {}
pub fn sendRow(row: []const u8) void {
    _ = row;
}
pub fn loadBoard() []u8 {
    // Volatile makes sure that writes to this are not optimized away.
    const vol_board: []const volatile u8 = &board;
    return @volatileCast(@constCast(vol_board));
}
pub fn saveBoard(b: []const u8) void {
    _ = b;
}
