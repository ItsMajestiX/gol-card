const SYSCFG0: *volatile u16 = @extern(*volatile u16, .{
    .name = "SYSCFG0",
});

const SYSCFG2: *volatile u8 = @extern(*volatile u8, .{
    .name = "SYSCFG2",
});

pub fn setProgramProtection(enable: bool) void {
    SYSCFG0.* = (0xA50 << 4) | (SYSCFG0.* & 0x0002) | @intFromBool(enable);
}

pub fn setDataProtection(enable: bool) void {
    SYSCFG0.* = (0xA50 << 4) | (@intFromBool(enable) << 1) | (SYSCFG0.* & 0x0001);
}

pub fn setAnalogEnabled(pin: u3, enable: bool) void {
    if (enable) {
        SYSCFG2.* |= (1 << pin);
    } else {
        SYSCFG2.* &= ~(1 << pin);
    }
}
