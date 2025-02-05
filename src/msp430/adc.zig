const pins = @import("../pins.zig");
const sys = @import("./sys.zig");

const ADCControlRegister0 = packed struct(u16) {
    /// Starts a sample-and-convert operation when true, automatically resets.
    ADCSC: bool,
    /// Enables conversion. Must be set to false to change most settings, must be true to use ADC.
    ADCENC: bool,
    _unused1: u2,
    /// Turns the ADC on or off. This should be automatically managed (?).
    ADCON: bool,
    _unused2: u2,
    /// Multiple sample-and-convert.
    ADCMSC: bool,
    /// Sample-and-hold time. Refer to datasheet for correct values, or just use the default.
    ADCSHT: u4,
    _unused3: u4,
};
const ADCCTL0: *volatile ADCControlRegister0 = @extern(*volatile ADCControlRegister0, .{
    .name = "ADCCTL0",
});

// This has a lot of registers in it, but only bit zero matters here since that is the completion bit.
const ADCCTL1: *volatile u8 = @extern(*volatile u8, .{
    .name = "ADCCTL1",
});

const ADCMEM0: *volatile u16 = @extern(*volatile u16, .{ .name = "ADCMEM0" });

const ADCMemoryControlRegister = packed struct(u8) {
    /// The ADC pin to run the conversion on.
    ADCINCH: u4,
    /// Sets the reference source for the ADC. Refer to datasheet for correct values, as the default is used here.
    ADCSREF: u3,
    _unused1: u1,
};

const ADCMCTL0: *volatile ADCMemoryControlRegister = @extern(*volatile ADCMemoryControlRegister, .{
    .name = "ADCMCTL0",
});

pub fn getNoise() u1 {
    // Set the correct ADC pin
    ADCMCTL0.ADCINCH = pins.ADC_Random;
    // Enable that pin
    sys.setAnalogEnabled(pins.ADC_Random, true);
    // Get ready to convert
    ADCCTL0.ADCENC = true;
    // Start the ADC conversion
    ADCCTL0.ADCSC = true;
    // Wait for conversion to complete
    while (ADCCTL1.* & 1) {}
    // Disable the ADC
    ADCCTL0.ADCENC = false;
    // Disable analog input on the pin
    sys.setAnalogEnabled(pins.ADC_Random, false);
    // Return the noisiest bit
    return @as(u1, @truncate(ADCMEM0.* & 1));
}
