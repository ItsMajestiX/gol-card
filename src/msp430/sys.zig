const SYSCFG0: *volatile u16 = @extern(*volatile u16, .{
    .name = "SYSCFG0",
});

pub fn setProgramProtection(enable: bool) void {
    SYSCFG0.* = (0xA50 << 4) | (SYSCFG0.* & 0x0002) | @intFromBool(enable);
}

pub fn setDataProtection(enable: bool) void {
    SYSCFG0.* = (0xA50 << 4) | (@intFromBool(enable) << 1) | (SYSCFG0.* & 0x0001);
}
