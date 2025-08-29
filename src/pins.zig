const msp = @import("./msp430.zig");

// manually controlled DIO
pub const ePD_Reset = msp.dio.Pin(msp.dio.Port1, 2);
pub const ePD_DataCommand = msp.dio.Pin(msp.dio.Port1, 0);
pub const ePD_Busy = msp.dio.Pin(msp.dio.Port1, 3);

// manually controlled analog
pub const ADC_Random: u3 = 1; // Pin 1

// controlled by eUSCI module
// eUSCI A0
pub const ePD_CS = msp.dio.Pin(msp.dio.Port1, 7);
pub const ePD_CLK = msp.dio.Pin(msp.dio.Port1, 6);
pub const ePD_MOSI = msp.dio.Pin(msp.dio.Port1, 4);
pub const ePD_MISO = msp.dio.Pin(msp.dio.Port1, 5);

// crystal oscilator pins
pub const XIN = msp.dio.Pin(msp.dio.Port2, 1);
pub const XOUT = msp.dio.Pin(msp.dio.Port2, 0);

// regulator pin
pub const EN_BYP = msp.dio.Pin(msp.dio.Port3, 0);
