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

var rand: *u256 = @ptrFromInt(0x1800); // Information memory

pub fn preUpdate() *State {
    // reset RTC to pre-sleep state
    msp.rtc.startRTC();
    // initialize IO pins
    msp.dio.resetAll();

    // start the 16MHz clock
    msp.watchdog.disableWatchdog();
    msp.fram.setFRAMWaitStateEnabled(true);
    msp.cs.setClock16MHz();

    // SPI setup
    msp.eusci.initSPI();

    // ePD_DataCommand, ePD_Reset, ePD_Power
    // do not need to set direction, reset sets all pins to outputs
    // all good

    // ePD_Busy
    pins.ePD_Busy.setDirection(false); // set busy pin to input
    pins.ePD_Busy.setPin(true); // when in input mode, true sets pullup resistor
    pins.ePD_Busy.setResistor(true); // enable the resistor

    // get bit of entropy, add to data
    msp.sys.setDataProtection(false);
    rand.* <<= 1;
    rand.* |= msp.adc.getNoise();
    msp.sys.setDataProtection(true);

    // set up the display
    display.initDisplay();

    // set global interrupt handler for display IRQ to work.
    msp.nop();
    msp.enableInterrupts();
    msp.nop();

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
        msp.disableInterrupts(); // shutdown code expects interrupts to be disabled
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

    // Go to sleep for 5 minutes
    // Procedure taken from TI manual.
    // Shut down the SPI module
    msp.eusci.enableSWReset(true);
    // Reset all GPIO
    msp.dio.resetAll();
    // Configure the RTC and enable its interrupt
    msp.rtc.startRTC();
    msp.rtc.enableRTCInt();
    // Watchdog already disabled, interrupts already disabled
    msp.pmm.prepareLPM5();
    asm volatile ("bis #240, r2"); // enter LPM3.5. GIE is not set here, but that is what TI says...
    unreachable;
}

pub fn getSeed() [4]u64 {
    return @as(*[4]u64, @ptrCast(rand)).*;
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
