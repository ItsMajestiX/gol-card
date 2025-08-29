const config = @import("config");
const RTCCounterControlRegister = packed struct(u16) {
    const PredividerValue = enum(u3) {
        @"1" = 0,
        @"10" = 1,
        @"100" = 2,
        @"1000" = 3,
        @"16" = 4,
        @"64" = 5,
        @"256" = 6,
        @"1024" = 7,
    };
    const ClockSource = enum(u2) {
        Stop = 0,
        DeviceSpecific = 1,
        XT1CLK = 2,
        VLOCLK = 3,
    };
    /// RTC interrupt flag.
    RTCIFG: bool,
    /// Enables the RTC interrupt.
    RTCIE: bool,
    _unused1: u4,
    /// When true, resets the RTC and copies the new timer value to the shadow register.
    RTCSR: bool,
    _unused2: u1,
    /// RTC clock predivider.
    RTCPS: PredividerValue,
    _unused3: u1,
    /// RTC clock source.
    RTCSS: ClockSource,
    _unused4: u2,
};

const RTCCTL: *volatile RTCCounterControlRegister = @extern(*volatile RTCCounterControlRegister, .{
    .name = "RTCCTL",
});

const RTCMOD: *volatile u16 = @extern(*volatile u16, .{
    .name = "RTCMOD",
});

const RTCIV: *volatile u16 = @extern(*volatile u16, .{
    .name = "RTCIV",
});

pub fn startRTC() void {
    // Reset the interrupt
    _ = RTCIV.*;
    // Set values in the control registers
    RTCCTL.RTCPS = .@"256";
    RTCMOD.* = 38400; // 128 * 60 * 5, xtal should be much more accurate than VLO
    RTCCTL.RTCSS = .XT1CLK;
    RTCCTL.RTCSR = true;
}

pub fn resetRTC() void {
    RTCCTL.RTCSR = true;
}

pub inline fn enableRTCInt() void {
    RTCCTL.RTCIE = true;
}
