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

pub fn setLOCKLPM5(lock: bool) void {
    PM5CTL0_L.LOCKLPM5 = lock;
}
