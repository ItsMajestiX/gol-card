const Pins = @import("../pins.zig");
const msp = @import("../msp430.zig");
const std = @import("std");

const eUSCIBxControlRegisterZero = packed struct(u16) {
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

const UCB0CTLW0: *volatile eUSCIBxControlRegisterZero = @extern(*volatile eUSCIBxControlRegisterZero, .{
    .name = "UCB0CTLW0",
});

const UCB0BRW: *volatile u16 = @extern(*volatile u16, .{
    .name = "UCB0BRW",
});

const eUSCIBxStatusRegister = packed struct(u16) {
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

const UCB0STATW: *volatile eUSCIBxStatusRegister = @extern(*volatile eUSCIBxStatusRegister, .{
    .name = "UCB0STATW",
});

const UCB0RXBUF: *volatile u16 = @extern(*volatile u16, .{
    .name = "UCB0RXBUF",
});

const UCB0TXBUF: *volatile u16 = @extern(*volatile u16, .{
    .name = "UCB0TXBUF",
});

const eUSCIBxInterruptEnable = packed struct(u16) {
    /// Enables or disables the recieve interrupt.
    UCRXIE: bool,
    /// Enables or disables the transmit interrupt.
    UCTXIE: bool,
    _unused1: u14,
};

const UCB0IE: *volatile eUSCIBxInterruptEnable = @extern(*volatile eUSCIBxInterruptEnable, .{
    .name = "UCB0IE",
});

const eUSCIBxInterruptFlags = packed struct(u16) {
    /// True if a receive interrupt is pending.
    UCRXIFG: bool,
    /// True if a transmit interrupt is pending.
    UCTXIFG: bool,
    _unused1: u14,
};

const UCB0IFG: *volatile eUSCIBxInterruptFlags = @extern(*volatile eUSCIBxInterruptFlags, .{
    .name = "UCB0IFG",
});

const eUSCIBxInterruptVector = enum(u16) {
    None = 0,
    Data_Recieved = 2,
    TXBUF_Empty = 4,
};

const UCB0IV: *volatile eUSCIBxInterruptVector = @extern(*volatile eUSCIBxInterruptVector, .{
    .name = "UCB0IV",
});

pub fn initSPI() void {
    // comes from the MSP430FR2xx manual
    enableSWReset(true);

    // 2. configure registers
    // set this first to prevent batching writes to the status register
    UCB0CTLW0.UCSYNC = .SYNC;
    UCB0BRW.* = 0; // Disable divider, already predivided to 2MHz
    UCB0CTLW0.UC7BIT = false;
    UCB0CTLW0.UCCKPL = .InactiveLow;
    UCB0CTLW0.UCCKPH = .CaptureChange;
    UCB0CTLW0.UCMODE0 = .FourPinActiveLow;
    UCB0CTLW0.UCMST = true;
    UCB0CTLW0.UCSSEL0 = 2; // SMCLK
    UCB0CTLW0.UCSTEM = .EnableSlave;
    setSPIBitOrder(true); // set this for now

    // 3. configure ports
    Pins.ePD_CLK.setMode(.Primary);
    Pins.ePD_CS.setMode(.Primary);
    Pins.ePD_MISO.setMode(.Primary);
    Pins.ePD_MOSI.setMode(.Primary);

    enableSWReset(false);
}

pub inline fn enableSWReset(rst: bool) void {
    UCB0CTLW0.UCSWRST = rst;
}

pub inline fn setSPIBitOrder(msb_first: bool) void {
    UCB0CTLW0.UCMSB = msb_first;
}

pub inline fn busyWaitForComplete() void {
    while (UCB0STATW.UCBUSY) {}
}

// SPI IRQ

// volatile keyword needed to prevent incorrect optimization
var to_send: []const u8 = undefined;

var fetch_data: *const fn () void = undefined;

comptime {
    const int_ptr = &__interrupt_vector_usci_b0;
    @export(&int_ptr, .{
        .name = "spi_int",
        .section = "__interrupt_vector_usci_b0",
        .linkage = .strong,
        .visibility = .default,
    });
}

pub noinline fn __interrupt_vector_usci_b0() callconv(.C) void {
    // LLVM can run the entire interrupt with just these three registers. Impressive.
    asm volatile (
        \\push r12
        \\push r13
        \\push r14
    );
    UCB0TXBUF.* = @as(u16, to_send[0]);
    to_send = to_send[1..];
    if (to_send.len == 0) {
        @branchHint(.unlikely);
        fetch_data();
        if (to_send.len == 0) {
            @branchHint(.unlikely);
            // Make sure CPU wakes up from LPM0 if it is currently set
            asm volatile ("bic #16, 6(r1)"); // unset the CPUOFF bit, but keep GIE set
            msp.eusci.setTXInt(false); // will need to disable or it will keep triggering
        }
    }
    asm volatile (
        \\pop r14
        \\pop r13
        \\pop r12
        \\reti
    );
}

pub fn setTXInt(enable: bool) void {
    UCB0IE.UCTXIE = enable;
}

/// Begins sending a slice. Will block until no more data can be sent.
/// If data runs out, will call fetchData.
pub fn sendSlice(new_slice: []const u8) void {
    var temp_slice = new_slice;
    while (UCB0IFG.UCTXIFG) {
        UCB0TXBUF.* = @as(u16, temp_slice[0]);
        temp_slice = temp_slice[1..];
        if (temp_slice.len == 0) {
            @branchHint(.unlikely);
            fetch_data();
            return;
        }
    }
    to_send = temp_slice;
}

/// Places data into the TX buffer and waits for it to be clear.
/// Useful when you need to switch between command and data in a byte.
pub fn sendDataSync(data: u8) void {
    UCB0TXBUF.* = @as(u16, data);
    busyWaitForComplete();
}

/// Sets the new handler for acquiring data and executes it.
pub fn setFetchData(new_fn: *const fn () void) void {
    fetch_data = new_fn;
    fetch_data();
}
