const std = @import("std");
const State = @import("./state.zig").State;
const msp = @import("./msp430/msp430.zig");

// If board is just set to var, the linker will place it in RAM and fail. If board is marked const, Zig will optimize away
// memcpy calls to it. This should tell the linker to place the object in FRAM but tell Zig that it can be mutated.
comptime {
    @export(&state, .{
        .name = "hal-embedded.state",
        .section = ".persistent",
    });
}
var state: State = State{};

pub fn preUpdate() *State {
    // TODO: get bit of entropy, add to data
    msp.watchdog.disableWatchdog();
    msp.fram.setFRAMWaitStateEnabled(true);
    msp.cs.setClock16MHz();
    msp.crc.initCRC();
    msp.sys.setProgramProtection(false);
    return &state;
}

pub fn markComplete(row: usize) void {
    // TODO: integrate with SPI interrupt
    _ = row;
}

pub fn newByte(b: u8) void {
    msp.crc.addCRC(b);
}

pub fn getCRC() u16 {
    return msp.crc.finalCRC();
}

pub fn postUpdate() void {
    // TODO: lots of stuff, will go into a lesser sleep while SPI finishes
    msp.sys.setProgramProtection(true);
}

pub fn getSeed() [4]u64 {
    // TODO: get randomness from buffer
    // these numbers are just from random.org
    return [_]u64{ 0xc2451be228028070, 0x31ce18a61da15b31, 0x5277280f86c833b5, 0xe698297d615233c9 };
}

pub fn markAllComplete() void {
    // TODO: integrate with SPI handler.
}
