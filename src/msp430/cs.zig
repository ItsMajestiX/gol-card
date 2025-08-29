const msp = @import("../msp430.zig");
const pins = @import("../pins.zig");

const CSCTL0: *volatile u16 = @extern(*volatile u16, .{
    .name = "CSCTL0",
});

const ClockSystemControlRegister1 = packed struct(u16) {
    /// Enables or disables modulation.
    DISMOD: bool,
    /// Sets the range of the DCO.
    DCORSEL: u3,
    /// DCO frequency trim.
    DCOFTRIM: u3,
    /// Enables or disables DCO frequency trim.
    DCOFTRIMEN: bool,
    _unused: u8,
};

const CSCTL1: *volatile ClockSystemControlRegister1 = @extern(*volatile ClockSystemControlRegister1, .{
    .name = "CSCTL1",
});

const ClockSystemControlRegister2 = packed struct(u16) {
    /// FLL Multiplier.
    FLLN: u10,
    _unused1: u2,
    /// FLL Divider.
    FLLD: u3,
    _unused2: u1,
};

const CSCTL2: *volatile ClockSystemControlRegister2 = @extern(*volatile ClockSystemControlRegister2, .{
    .name = "CSCTL2",
});

const ClockSystemControlRegister3 = packed struct(u16) {
    _unused1: u4,
    /// Selects the reference for the FLL.
    SELREF: u2,
    _unused2: u10,
};

const CSCTL3: *volatile ClockSystemControlRegister3 = @extern(*volatile ClockSystemControlRegister3, .{
    .name = "CSCTL3",
});

const ClockSystemControlRegister4 = packed struct(u16) {
    pub const MCLKSource = enum(u3) {
        DCOCLKDIV = 0,
        REFOCLK = 1,
        XT1CLK = 2,
        VLOCLK = 3,
    };

    pub const ACLKSource = enum(u2) {
        XT1CLK = 0,
        REFO = 1,
        VLO = 2,
    };

    SELMS: MCLKSource,
    _unused1: u5,
    SELA: ACLKSource,
    _unused2: u6,
};

const CSCTL4: *volatile ClockSystemControlRegister4 = @extern(*volatile ClockSystemControlRegister4, .{
    .name = "CSCTL4",
});

const ClockSystemControlRegister5 = packed struct(u16) {
    pub const MCLKDivider = enum(u3) {
        @"1" = 0,
        @"2" = 1,
        @"4" = 2,
        @"8" = 3,
        @"16" = 4,
        @"32" = 5,
        @"64" = 6,
        @"128" = 7,
    };

    pub const SMCLKDivider = enum(u2) {
        @"1" = 0,
        @"2" = 1,
        @"4" = 2,
        @"8" = 3,
    };

    /// Predivider for MCLK
    DIVM: MCLKDivider,
    _unused1: u1,
    /// Predividers for SMCLK
    DIVS: SMCLKDivider,
    _unused2: u2,
    /// Disables SMCLK
    SMCLKOFF: bool,
    _unused3: u3,
    /// Automatically turn VLO off when not used
    VLOAUTOOFF: bool,
    _unused4: u3,
};

const CSCTL5: *volatile ClockSystemControlRegister5 = @extern(*volatile ClockSystemControlRegister5, .{
    .name = "CSCTL5",
});

const ClockSystemControlRegister7 = packed struct(u16) {
    /// DCO fault flag. Can be reset by writing false.
    DCOFFG: bool,
    /// XT1 fault flag. Can be reset by writing false.
    XT1OFFG: bool,
    /// True when REFO is ready for use.
    REFOREADY: bool,
    _unused1: u1,
    /// FLL unlock interrupt flag.
    FLLULIFG: bool,
    _unused2: u1,
    /// Enables/disables the XT1 start count.
    ENSTFCNT1: bool,
    _unused3: u1,
    /// Current status of the FLL.
    FLLUNLOCK: u2,
    /// Sticky bits indicating previous statuses of the FLL.
    FLLUNLOCKHIS: u2,
    /// If true, a PUC is generated when FLLUIFG is set.
    FLLULPUC: bool,
    // Enables the FLL history interrupt.
    FLLWARNEN: bool,
    _unused4: u2,
};

const CSCTL7: *volatile ClockSystemControlRegister7 = @extern(*volatile ClockSystemControlRegister7, .{
    .name = "CSCTL7",
});

inline fn enableFLL() void {
    return asm volatile ("bic #64,r2" ::: "r2");
}

inline fn disableFLL() void {
    return asm volatile ("bis #64,r2" ::: "r2");
}

pub fn setClock16MHz() void {
    // this process taken from a TI datasheet
    // 1. disable FLL
    disableFLL();
    // 2. set source
    CSCTL3.SELREF = 0;
    // 3. clear CSCTL 0
    CSCTL0.* = 0;
    // 4. DCO range, and FLL fraction
    CSCTL1.DCOFTRIMEN = false;
    CSCTL1.DCORSEL = 5; // 16MHz range
    CSCTL1.DISMOD = false; // disable modulation = false (enable)
    CSCTL2.FLLN = 487; // 32768 Hz * (487 + 1) is about 16MHz
    CSCTL2.FLLD = 0; // Disable divider
    // 5. nop (or wait) three instructions
    msp.nop();
    msp.nop();
    msp.nop();
    // 6. enable fll
    enableFLL();
    // wait to stabilize
    while (CSCTL7.FLLUNLOCK != 0) {}
    // set SMClock to 2MHz
    CSCTL5.DIVS = .@"8";
}

pub fn getMCLKSource() ClockSystemControlRegister4.MCLKSource {
    return CSCTL4.SELMS;
}

pub fn setMCLKSource(source: ClockSystemControlRegister4.MCLKSource) void {
    CSCTL4.SELMS = source;
}

pub fn resetXtalFlags() void {
    const CSCTL7_reg = @as(*volatile u16, @ptrCast(CSCTL7));
    CSCTL7_reg.* &= 0xFFFC;
}

pub fn setXtalPins() void {
    pins.XIN.setMode(.Primary);
    pins.XOUT.setMode(.Primary);
}
