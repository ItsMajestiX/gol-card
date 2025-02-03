const msp = @import("../msp430.zig");

pub const PinMode = enum {
    GPIO,
    Primary,
    Secondary,
    Tertiary,
};

pub const PinTransition = enum {
    LowToHigh,
    HighToLow,
};

pub const DigitalIOBase = enum {
    port1,
    port2,
    port3,

    fn toPtr(self: DigitalIOBase) [*]u8 {
        switch (self) {
            .port1 => return @extern([*]u8, .{ .name = "PAIN_L" }),
            .port2 => return @extern([*]u8, .{ .name = "PAIN_H" }),
            .port3 => return @extern([*]u8, .{ .name = "PBIN_L" }),
        }
    }
};

fn DigitalIO(comptime base: DigitalIOBase) type {
    return struct {
        const base_ptr = base.toPtr();
        const input: *volatile u8 = @ptrCast(base_ptr);
        const output: *volatile u8 = @ptrCast(base_ptr + 2);
        const direction: *volatile u8 = @ptrCast(base_ptr + 4);
        const resistor_enable: *volatile u8 = @ptrCast(base_ptr + 6);
        const select_0: *volatile u8 = @ptrCast(base_ptr + 0xA);
        const select_1: *volatile u8 = @ptrCast(base_ptr + 0xC);
        const complement: *volatile u8 = @ptrCast(base_ptr + 0x16);
        const interrupt_edge: *volatile u8 = @ptrCast(base_ptr + 0x18);
        const interrupt_enable: *volatile u8 = @ptrCast(base_ptr + 0x1A);
        const interrupt_flag: *volatile u8 = @ptrCast(base_ptr + 0x1C);

        // only export irq for ports that support it
        comptime {
            switch (base) {
                .port1, .port2 => {
                    const irq_ptr = &pinIRQ;
                    @export(
                        &irq_ptr,
                        .{
                            .section = "__interrupt_vector_" ++ @tagName(base),
                            .name = "pinIRQ_" ++ @tagName(base),
                        },
                    );
                },
                else => {},
            }
        }
        fn pinIRQ() callconv(.C) noreturn {
            // exit LPM and return to code, with GIE enabled
            // adding these lines forces LLVM to generate separate interrupts
            // this prevents it from trying to call another copy of this function and
            // messing up the stack.
            interrupt_enable.* = 0;
            interrupt_flag.* = 0;
            asm volatile (
                \\bic #240, 0(r1)
                \\reti
            );
            unreachable;
        }

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

        /// Places the CPU in LPM4 until the specified pin transition happens.
        /// Make sure to disable anything that would keep the CPU from entering the desired LPM.
        pub fn waitForChange(pin: u8, mode: PinTransition) void {
            switch (base) {
                .port1, .port2 => {},
                else => @compileError("Attempted to wait on a pin in a port that doesn't support interrupts."),
            }
            if (mode == .HighToLow) {
                interrupt_edge.* |= (@as(u8, 1) << @as(u3, @truncate(pin)));
            } else {
                interrupt_edge.* &= ~(@as(u8, 1) << @as(u3, @truncate(pin)));
            }

            // avoid getting interrupted before going to sleep
            msp.disableInterrupts();
            msp.nop();

            interrupt_enable.* |= (@as(u8, 1) << @as(u3, @truncate(pin)));

            // setting a breakpoint here causes this to work?????
            asm volatile ("bis #248, r2"); // enter LPM4

            // now the event should have passed, isr cleared flags and left GIE enabled
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

        pub fn waitForChange(mode: PinTransition) void {
            dio.waitForChange(pin, mode);
        }
    };
}

pub const Port1 = DigitalIO(.port1);
pub const Port2 = DigitalIO(.port2);
pub const Port3 = DigitalIO(.port3);

pub fn resetAll() void {
    Port1.reset();
    Port2.reset();
    Port3.reset();
    msp.pmm.setLOCKLPM5(false);
}
