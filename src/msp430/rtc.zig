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

    RTCIFG: bool,
    RTCIE: bool,
    _unused1: u4,
    RTCSR: bool,
    _unused2: u1,
    RTCPS: PredividerValue,
    _unused3: u1,
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
    RTCCTL.RTCPS = .@"100";
    RTCMOD.* = 21429; // 5 minutes? (Setting it to 30000 waits *exactly* seven minutes for some reason)
    RTCCTL.RTCSS = .VLOCLK;
    RTCCTL.RTCSR = true;
}

pub inline fn enableRTCInt() void {
    RTCCTL.RTCIE = true;
}
