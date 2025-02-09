const PowerMode5ControlRegister0 = packed struct(u8) {
    LOCKLPM5: bool,
    _unused1: u3,
    LPM5SW: bool,
    // There is another flag available for the MSP430FR2433.
    // It shoudn't need to be changed, so it is marked as unused.
    _unused2: u3,
};

const PM5CTL0_L: *volatile PowerMode5ControlRegister0 = @extern(*volatile PowerMode5ControlRegister0, .{
    .name = "PM5CTL0_L",
});

const PMMCTL0_H: *volatile u8 = @extern(*volatile u8, .{
    .name = "PMMCTL0_H",
});

const PowerManagementModuleControlRegister0 = packed struct(u8) {
    _unused1: u2,
    /// Causes a software brownout reset when set to true.
    PMMSWBOR: bool,
    /// Causes a software power on reset when set to true.
    PMMSWPOR: bool,
    /// When set to true, will cause the CPU to ender LPMx.5 if all other conditons are met.
    PMMREGOFF: bool,
    _unused2: u1,
    /// Controls the high side of the SVS.
    SVSHE: bool,
    _unused3: bool,
};

const PMMCTL0_L: *volatile PowerManagementModuleControlRegister0 = @extern(*volatile PowerManagementModuleControlRegister0, .{
    .name = "PMMCTL0_L",
});

pub fn setLOCKLPM5(lock: bool) void {
    PM5CTL0_L.LOCKLPM5 = lock;
}

pub fn prepareLPM5() void {
    // unlock registers
    PMMCTL0_H.* = 0xA5;
    PMMCTL0_L.PMMREGOFF = true;
    PMMCTL0_L.SVSHE = false;
    // lock registers
    PMMCTL0_H.* = 0x00;
}
