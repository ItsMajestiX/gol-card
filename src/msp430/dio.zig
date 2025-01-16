const msp = @import("../msp430.zig");

pub const PinMode = enum {
    GPIO,
    Primary,
    Secondary,
    Tertiary,
};

fn DigitalIO(comptime base: [*]u8) type {
    return struct {
        const input: *volatile u8 = @ptrCast(base);
        const output: *volatile u8 = @ptrCast(base + 2);
        const direction: *volatile u8 = @ptrCast(base + 4);
        const resistor_enable: *volatile u8 = @ptrCast(base + 6);
        const select_0: *volatile u8 = @ptrCast(base + 0xA);
        const select_1: *volatile u8 = @ptrCast(base + 0xC);
        const complement: *volatile u8 = @ptrCast(base + 0x16);
        const interrupt_edge: *volatile u8 = @ptrCast(base + 0x18);
        const interrupt_enable: *volatile u8 = @ptrCast(base + 0x1A);
        const interrupt_flag: *volatile u8 = @ptrCast(base + 0x1C);

        pub fn reset() void {
            direction.* = 0xFF; // set all pins to output, will be in GPIO mode by default
            resistor_enable.* = 0;
            output.* = 0;
            interrupt_edge.* = 0;
        }

        pub fn setDirection(pin: u8, set_output: bool) void {
            if (set_output) {
                direction.* |= (@as(u8, 1) << @as(u3, @truncate(pin)));
            } else {
                direction.* &= ~(@as(u8, 1) << @as(u3, @truncate(pin)));
            }
        }

        pub fn getPin(pin: u8) bool {
            return (input.* >> @as(u3, @truncate(pin))) & 1;
        }

        pub fn setPin(pin: u8, state: bool) void {
            if (state) {
                output.* |= (@as(u8, 1) << @as(u3, @truncate(pin)));
            } else {
                output.* &= ~(@as(u8, 1) << @as(u3, @truncate(pin)));
            }
        }

        /// This function assumes each pin starts off in GPIO mode and isn't changed once set.
        pub fn setMode(pin: u8, mode: PinMode) void {
            switch (mode) {
                .GPIO => {},
                .Primary => {
                    select_0.* |= (@as(u8, 1) << @as(u3, @truncate(pin)));
                },
                .Secondary => {
                    select_1.* |= (@as(u8, 1) << @as(u3, @truncate(pin)));
                },
                .Tertiary => {
                    complement.* |= (@as(u8, 1) << @as(u3, @truncate(pin)));
                },
            }
        }

        pub fn setResistor(pin: u8, enable: bool) void {
            if (enable) {
                resistor_enable.* |= (@as(u8, 1) << @as(u3, @truncate(pin)));
            } else {
                resistor_enable.* &= ~(@as(u8, 1) << @as(u3, @truncate(pin)));
            }
        }
    };
}

pub fn Pin(comptime dio: anytype, comptime pin: u8) type {
    return struct {
        pub fn setDirection(set_output: bool) void {
            dio.setDirection(pin, set_output);
        }

        pub fn getPin() bool {
            return dio.getPin(pin);
        }

        pub fn setPin(state: bool) void {
            dio.setPin(pin, state);
        }

        /// This function assumes each pin starts off in GPIO mode and isn't changed once set.
        pub fn setMode(mode: PinMode) void {
            dio.setMode(pin, mode);
        }

        pub fn setResistor(enable: bool) void {
            dio.setResistor(pin, enable);
        }
    };
}

const PAIN_L: [*]u8 = @extern([*]u8, .{ .name = "PAIN_L" });
pub const Port1 = DigitalIO(PAIN_L);
const PAIN_H: [*]u8 = @extern([*]u8, .{ .name = "PAIN_H" });
pub const Port2 = DigitalIO(PAIN_H);
const PBIN_L: [*]u8 = @extern([*]u8, .{ .name = "PBIN_L" });
pub const Port3 = DigitalIO(PBIN_L);

pub fn resetAll() void {
    Port1.reset();
    Port2.reset();
    Port3.reset();
    msp.pmm.setLOCKLPM5(false);
}
