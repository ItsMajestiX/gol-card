const msp = @import("./msp430.zig");

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

const ClockSystemControlRegister7 = packed struct(u16) {
    DCOFFG: bool,
    XT1OFFG: bool,
    REFOREADY: bool,
    _unused1: u1,
    FLLULIFG: bool,
    _unused2: u1,
    ENSTFCNT1: bool,
    _unused3: u1,
    FLLUNLOCK: u2,
    FLLUNLOCKHIS: u2,
    FLLULPUC: bool,
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
}
