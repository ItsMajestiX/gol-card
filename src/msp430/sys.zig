const SFRInterruptFlagOne = packed struct(u8) {
    /// Watchdog timer interrupt flag
    WDTIFG: bool,
    /// Oscilator fault interrupt flag
    OFIFG: bool,
    _unused1: u1,
    /// Vacant memory access interrupt flag
    VMAIFG: bool,
    /// NMI pin interrupt flag
    NMIIFG: bool,
    _unused2: u1,
    /// JTAG mailbox in interrupt flag
    JMBINIFG: bool,
    /// JTAG mailbox out interrupt flag
    JMBOUTIFG: bool,
};

const SFRIFG1_L: *volatile SFRInterruptFlagOne = @extern(*volatile SFRInterruptFlagOne, .{
    .name = "SFRIFG1_L",
});

const SYSCFG0: *volatile u16 = @extern(*volatile u16, .{
    .name = "SYSCFG0",
});

const SYSCFG2: *volatile u8 = @extern(*volatile u8, .{
    .name = "SYSCFG2",
});

pub fn getOscillatorFaultFlag() bool {
    return SFRIFG1_L.OFIFG;
}

pub fn clearOscillatorFaultFlag() void {
    SFRIFG1_L.OFIFG = false;
}

pub fn setProgramProtection(enable: bool) void {
    SYSCFG0.* = (0xA50 << 4) | (SYSCFG0.* & 0x0002) | @intFromBool(enable);
}

pub fn setDataProtection(enable: bool) void {
    SYSCFG0.* = (0xA50 << 4) | (@as(u16, @intFromBool(enable)) << 1) | (SYSCFG0.* & 0x0001);
}

pub fn setAnalogEnabled(pin: u3, enable: bool) void {
    if (enable) {
        SYSCFG2.* |= (@as(u8, 1) << pin);
    } else {
        SYSCFG2.* &= ~(@as(u8, 1) << pin);
    }
}
