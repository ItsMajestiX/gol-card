const std = @import("std");
// size of board and window
pub const width = 360;
comptime {
    std.debug.assert(width % 8 == 0); // this makes copying rows much easier
}
pub const height = 240;

pub fn initDisplay() void {}
pub fn closeDisplay() void {}
pub fn sendRow(row: []const u8) void {
    _ = row;
}
pub fn loadBoard() []u8 {
    const arr: *volatile [10800]u8 = @ptrFromInt(0x1);
    return @volatileCast(arr);
}
pub fn saveBoard(board: []const u8) void {
    _ = board;
}
