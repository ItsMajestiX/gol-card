const Pins = @import("../pins.zig");
const msp = @import("../msp430.zig");
const std = @import("std");
const config = @import("config");

const eUSCIControlRegisterZero = packed struct(u16) {
    pub const STEMode = enum(u1) {
        PreventConflict = 0,
        EnableSlave = 1,
    };

    pub const eUSCIClockSource = enum(u2) {
        DeviceSpecfic = 0b01,
        SMCLK = 0b10,
    };

    pub const eUSCIType = enum(u1) {
        ASYNC = 0,
        SYNC = 1,
    };

    pub const eUSCIMode = enum(u2) {
        ThreePinSPI = 0,
        FourPinActiveHigh = 1,
        FourPinActiveLow = 2,
        I2C = 3,
    };

    pub const eUSCIClockPolarity = enum(u1) {
        InactiveLow = 0,
        InactiveHigh = 1,
    };

    pub const eUSCIClockPhase = enum(u1) {
        ChangeCapture = 0,
        CaptureChange = 1,
    };

    /// Whether or not the software reset is enabled.
    UCSWRST: bool,
    /// Selects the functionality of STE when acting as a master.
    UCSTEM: STEMode,
    _unused1: u4,
    /// Selects the clock source for the module.
    UCSSEL0: u2,
    /// Selects the mode the eUSCI module is operating in.
    UCSYNC: eUSCIType,
    /// Selects the submode the given eUSCI unit is operating in.
    UCMODE0: eUSCIMode,
    /// Whether or not to operate as a master.
    UCMST: bool,
    /// Whether or not to use 7-bit characters.
    UC7BIT: bool,
    /// Whether or not to send the MSB first (false sends LSB first).
    UCMSB: bool,
    /// The clock polarity of the module.
    UCCKPL: eUSCIClockPolarity,
    /// The clock phase of the module.
    UCCKPH: eUSCIClockPhase,
};

const UCB0CTLW0: *volatile eUSCIControlRegisterZero = @extern(*volatile eUSCIControlRegisterZero, .{
    .name = "UCB0CTLW0",
});

const UCA0CTLW0: *volatile eUSCIControlRegisterZero = @extern(*volatile eUSCIControlRegisterZero, .{
    .name = "UCA0CTLW0",
});

const UCB0BRW: *volatile u16 = @extern(*volatile u16, .{
    .name = "UCB0BRW",
});

const UCA0BRW: *volatile u16 = @extern(*volatile u16, .{
    .name = "UCA0BRW",
});

const eUSCIStatusRegister = packed struct(u16) {
    /// Whether or not the module is sending or receving data.
    UCBUSY: bool,
    _unused1: u4,
    /// Whether or not a TX or RX overrun has been deteccted.
    UCOE: bool,
    /// Whether or not a framing error has occured.
    UCFE: bool,
    /// Whether or not to enable loopback mode.
    UCLISTEN: bool,
    _unused2: u8,
};

const UCB0STATW: *volatile eUSCIStatusRegister = @extern(*volatile eUSCIStatusRegister, .{
    .name = "UCB0STATW",
});

const UCA0STATW: *volatile eUSCIStatusRegister = @extern(*volatile eUSCIStatusRegister, .{
    .name = "UCA0STATW",
});

const UCB0RXBUF: *volatile u16 = @extern(*volatile u16, .{
    .name = "UCB0RXBUF",
});

const UCA0RXBUF: *volatile u16 = @extern(*volatile u16, .{
    .name = "UCA0RXBUF",
});

const UCB0TXBUF: *volatile u16 = @extern(*volatile u16, .{
    .name = "UCB0TXBUF",
});

const UCA0TXBUF: *volatile u16 = @extern(*volatile u16, .{
    .name = "UCA0TXBUF",
});

const eUSCIInterruptEnable = packed struct(u16) {
    /// Enables or disables the recieve interrupt.
    UCRXIE: bool,
    /// Enables or disables the transmit interrupt.
    UCTXIE: bool,
    _unused1: u14,
};

const UCB0IE: *volatile eUSCIInterruptEnable = @extern(*volatile eUSCIInterruptEnable, .{
    .name = "UCB0IE",
});

const UCA0IE: *volatile eUSCIInterruptEnable = @extern(*volatile eUSCIInterruptEnable, .{
    .name = "UCA0IE",
});

const eUSCIInterruptFlags = packed struct(u16) {
    /// True if a receive interrupt is pending.
    UCRXIFG: bool,
    /// True if a transmit interrupt is pending.
    UCTXIFG: bool,
    _unused1: u14,
};

const UCB0IFG: *volatile eUSCIInterruptFlags = @extern(*volatile eUSCIInterruptFlags, .{
    .name = "UCB0IFG",
});

const UCA0IFG: *volatile eUSCIInterruptFlags = @extern(*volatile eUSCIInterruptFlags, .{
    .name = "UCA0IFG",
});

const eUSCIInterruptVector = enum(u16) {
    None = 0,
    Data_Recieved = 2,
    TXBUF_Empty = 4,
};

const UCB0IV: *volatile eUSCIInterruptVector = @extern(*volatile eUSCIInterruptVector, .{
    .name = "UCB0IV",
});

const UCA0IV: *volatile eUSCIInterruptVector = @extern(*volatile eUSCIInterruptVector, .{
    .name = "UCA0IV",
});

pub fn initSPI() void {
    // comes from the MSP430FR2xx manual
    enableSWReset(true);

    // 2. configure registers
    // set this first to prevent batching writes to the status register
    UCA0CTLW0.UCSYNC = .SYNC;
    UCA0BRW.* = 2; // Disable divider, already predivided to 2MHz
    UCA0CTLW0.UC7BIT = false;
    UCA0CTLW0.UCCKPL = .InactiveLow;
    UCA0CTLW0.UCCKPH = .CaptureChange;
    UCA0CTLW0.UCMODE0 = .FourPinActiveLow;
    UCA0CTLW0.UCMST = true;
    UCA0CTLW0.UCSSEL0 = 2; // SMCLK
    UCA0CTLW0.UCSTEM = .EnableSlave;
    setSPIBitOrder(true); // set this for now

    // 3. configure ports
    Pins.ePD_CLK.setMode(.Primary);
    Pins.ePD_CS.setMode(.Primary);
    Pins.ePD_MISO.setMode(.Primary);
    Pins.ePD_MOSI.setMode(.Primary);

    enableSWReset(false);
}

pub inline fn enableSWReset(rst: bool) void {
    UCA0CTLW0.UCSWRST = rst;
}

pub inline fn setSPIBitOrder(msb_first: bool) void {
    UCA0CTLW0.UCMSB = msb_first;
}

pub inline fn busyWaitForComplete() void {
    while (UCA0STATW.UCBUSY) {}
}

// SPI IRQ

// volatile keyword needed to prevent incorrect optimization
var to_send: []const u8 = undefined;

var fetch_data: *const fn () void = undefined;

comptime {
    const int_ptr = &__interrupt_vector_usci_a0;
    switch (config.mcu) {
        .msp430fr2433 => {
            @export(&int_ptr, .{
                .name = "spi_int",
                .section = "__interrupt_vector_usci_a0",
                .linkage = .strong,
                .visibility = .default,
            });
        },
        else => {
            @export(&int_ptr, .{
                .name = "spi_int",
                .section = "__interrupt_vector_eusci_a0",
                .linkage = .strong,
                .visibility = .default,
            });
        },
    }
}

pub noinline fn __interrupt_vector_usci_a0() callconv(.C) void {
    asm volatile (
        \\push r12
        \\push r13
        \\push r14
        \\push r15
    );
    if (to_send.len == 0) {
        @branchHint(.unlikely);
        fetch_data();
        if (to_send.len == 0) {
            @branchHint(.unlikely);
            // Make sure CPU wakes up from LPM0 if it is currently set
            asm volatile ("bic #16, 8(r1)"); // unset the CPUOFF bit, but keep GIE set
            //msp.eusci.setTXInt(false); // will need to disable or it will keep triggering
        }
    } else {
        UCA0TXBUF.* = @as(u16, to_send[0]);
        to_send = to_send[1..];
    }
    UCA0IFG.UCRXIFG = false; // disable interrupt, will be triggered once next byte is done transmitting
    asm volatile (
        \\pop r15
        \\pop r14
        \\pop r13
        \\pop r12
        \\reti
    );
}

// pub fn setTXInt(enable: bool) void {
//     UCB0IE.UCTXIE = enable;
// }

pub fn setRXInt(enable: bool) void {
    UCA0IE.UCRXIE = enable;
}

/// Begins sending a slice. Will block until no more data can be sent.
/// If data runs out, will call fetchData.
pub fn sendSlice(new_slice: []const u8) void {
    UCA0TXBUF.* = @as(u16, new_slice[0]);
    to_send = new_slice[1..];
}

/// Places data into the TX buffer and waits for it to be clear.
/// Useful when you need to switch between command and data in a byte.
pub fn sendDataSync(data: u8) void {
    UCA0TXBUF.* = @as(u16, data);
    busyWaitForComplete();
}

/// Sets the new handler for acquiring data and executes it.
pub fn setFetchData(new_fn: *const fn () void) void {
    fetch_data = new_fn;
    fetch_data();
}
