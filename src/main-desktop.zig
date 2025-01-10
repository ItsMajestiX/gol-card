const rl = @import("raylib");
const std = @import("std");
const common = @import("./common.zig");
const hal = @import("./hal-desktop.zig");
const width = @import("./state.zig").State.width;
const height = @import("./state.zig").State.height;

pub fn main() anyerror!void {
    rl.initWindow(width * 3, height * 3, "Game of Life Card Simulator");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    const times = [_]u16{ 1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 60, 2 * 60, 3 * 60, 5 * 60, 10 * 60, 15 * 60, 20 * 60, 30 * 60, 60 * 60, 120 * 60, 180 * 60, 300 * 60 };
    var selectedTime: usize = 0;
    var frameCount: u16 = 0;
    var step = true;
    _ = hal.preUpdate();
    for (0..height) |i| {
        hal.markComplete(i);
    }
    hal.postUpdate();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        if (step) {
            if (rl.isKeyPressed(rl.KeyboardKey.key_e)) {
                common.step();
            }
        } else {
            if (times[selectedTime] <= frameCount) {
                frameCount = 0;
                common.step();
            }
        }
        hal.postUpdate(); // again, this makes much more sense when running on an eInk
        if (rl.isKeyPressed(rl.KeyboardKey.key_w)) {
            if (selectedTime < (times.len - 1)) {
                selectedTime += 1;
                std.log.info("Time changed to {d} frames, {d} seconds", .{ times[selectedTime], times[selectedTime] / 60 });
            }
        } else if (rl.isKeyPressed(rl.KeyboardKey.key_q)) {
            if (selectedTime > 0) {
                selectedTime -= 1;
                std.log.info("Time changed to {d} frames, {d} seconds", .{ times[selectedTime], times[selectedTime] / 60 });
            }
        }
        if (!step) {
            frameCount += 1;
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_p)) {
            step = !step;
        } else {}
    }
}
