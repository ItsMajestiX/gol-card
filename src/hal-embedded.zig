const std = @import("std");

const display = @import("./display.zig");
const bmutil = @import("./bmutil.zig");
const msp = @import("./msp430.zig");
const pins = @import("./pins.zig");
const State = @import("./state.zig").State;

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
    // start the 16MHz clock
    msp.watchdog.disableWatchdog();
    msp.fram.setFRAMWaitStateEnabled(true);
    msp.cs.setClock16MHz();

    // initialize IO pins
    msp.dio.resetAll();

    // SPI setup
    msp.eusci.initSPI();

    // ePD_DataCommand, ePD_Reset, ePD_Power
    // do not need to set direction, reset sets all pins to outputs
    // all good

    // ePD_Busy
    pins.ePD_Busy.setDirection(false); // set busy pin to input
    pins.ePD_Busy.setPin(true); // when in input mode, true sets pullup resistor
    pins.ePD_Busy.setResistor(true); // enable the resistor

    // set up the display
    display.initDisplay();

    // set global interrupt handler for display IRQ to work.
    msp.nop();
    msp.enableInterrupts();
    msp.nop();

    // TODO: get bit of entropy, add to data
    msp.crc.initCRC();
    msp.sys.setProgramProtection(false);

    return &state;
}

pub fn markComplete() void {
    pending += State.width / 8;
    if (stall) {
        stall = false;
        //msp.eusci.setTXInt(true); // this should immidiately trigger an interrupt
        imageFetchData();
    }
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

    // If an interrupt happens that sets complete to true after we check it, we will softlock
    msp.disableInterrupts();
    msp.nop();

    if (!complete) {
        asm volatile ("bis #24, sr"); // from TI manual, similtaneously enable interrupts and shut off CPU
        msp.nop();
    }

    // when we reach this point the tx interrupt will be off so we don't need to worry about interrupts
    msp.eusci.busyWaitForComplete();

    msp.eusci.enableSWReset(true);
    // switch the byte order back to MSB for the last few commands
    msp.eusci.setSPIBitOrder(true);
    msp.eusci.enableSWReset(false);

    display.refresh();
    display.powerOff();
}

pub fn getSeed() [4]u64 {
    // TODO: get randomness from buffer
    // these numbers are just from random.org
    return [_]u64{ 0xc2451be228028070, 0x31ce18a61da15b31, 0x5277280f86c833b5, 0xe698297d615233c9 };
}

pub fn markAllComplete() void {
    pending = state.board.len;
    // If interrupted here, would take the new data (cannot be stalled, as that would disable interrupts).
    if (stall) {
        stall = false;
        //msp.eusci.setTXInt(true); // this should immidiately trigger an interrupt
        imageFetchData();
    }
}

var lowest_sent: u16 = 0;
var pending: u16 = 0;
var stall: bool = false;
var complete: bool = false;
/// Called by the SPI IRQ after setup is complete to get new data.
pub fn imageFetchData() void {
    if (lowest_sent == pending) {
        // no more data to send
        // disabling will be done by SPI handler, will be reenabled by markComplete.
        stall = true;
        if (lowest_sent == state.board.len) {
            // everything is sent, set complete
            complete = true;
        }
        return;
    }
    const new_slice = state.board[lowest_sent..pending];
    lowest_sent = pending;
    msp.eusci.sendSlice(new_slice);
}
