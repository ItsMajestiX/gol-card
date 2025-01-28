const msp = @import("./msp430.zig");

// manually controlled
pub const ePD_Reset = msp.dio.Pin(msp.dio.Port3, 1);
pub const ePD_DataCommand = msp.dio.Pin(msp.dio.Port2, 2);
pub const ePD_Busy = msp.dio.Pin(msp.dio.Port2, 7);

// controlled by eUSCI module
pub const ePD_CS = msp.dio.Pin(msp.dio.Port1, 0);
pub const ePD_CLK = msp.dio.Pin(msp.dio.Port1, 1);
pub const ePD_MOSI = msp.dio.Pin(msp.dio.Port1, 2);
pub const ePD_MISO = msp.dio.Pin(msp.dio.Port1, 3);
