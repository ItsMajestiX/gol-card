const FRCTL0: *volatile u16 = @extern(*volatile u16, .{
    .name = "FRCTL0",
});

pub fn setFRAMWaitStateEnabled(enabled: bool) void {
    FRCTL0.* = (0xA5 << 8) | (@as(u16, @intFromBool(enabled)) << @as(u8, 4));
}
