pub const crc = @import("./crc.zig");
pub const cs = @import("./cs.zig");
pub const fram = @import("./fram.zig");
pub const sys = @import("./sys.zig");
pub const watchdog = @import("./watchdog.zig");

pub inline fn nop() void {
    return asm volatile ("nop");
}
