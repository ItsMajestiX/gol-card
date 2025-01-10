const WDTCTL: *volatile u16 = @extern(*volatile u16, .{
    .name = "WDTCTL",
});

pub inline fn disableWatchdog() void {
    WDTCTL.* = 0x5A80;
}
