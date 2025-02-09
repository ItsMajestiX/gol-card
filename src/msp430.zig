pub const adc = @import("./msp430//adc.zig");
pub const crc = @import("./msp430/crc.zig");
pub const cs = @import("./msp430/cs.zig");
pub const dio = @import("./msp430/dio.zig");
pub const eusci = @import("./msp430/eusci.zig");
pub const fram = @import("./msp430/fram.zig");
pub const pmm = @import("./msp430/pmm.zig");
pub const rtc = @import("./msp430/rtc.zig");
pub const sys = @import("./msp430/sys.zig");
pub const watchdog = @import("./msp430/watchdog.zig");

pub inline fn nop() void {
    return asm volatile ("nop");
}

pub inline fn disableInterrupts() void {
    return asm volatile ("dint");
}

pub inline fn enableInterrupts() void {
    return asm volatile ("eint");
}

/// Busy waits for the given amount of time
/// Switches the CPU to use the VLFO (10kHz) temporarily
///
pub fn busyWait(halfMS: u16) void {
    const prevSource = cs.getMCLKSource();
    cs.setMCLKSource(.VLOCLK);
    // asm explantion
    // tst compares the value to 0, should take less than 1 cycle according to TI
    // jump instructions always take two cycles
    // branch instructions exist, but LLVM doesn't seem to use them so I'm not either
    // since -1 can be made from the constant generator, it is a register/register operation,
    // meaning it only takes one cycle
    asm volatile (
        \\.BW_LOOP:
        \\tst %[halfMS]
        \\jz .BW_END 
        \\add #-1, %[halfMS]
        \\jmp .BW_LOOP
        \\.BW_END:
        :
        : [halfMS] "{r13}" (halfMS),
    );
    cs.setMCLKSource(prevSource);
}
