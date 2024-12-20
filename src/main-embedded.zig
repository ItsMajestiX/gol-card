pub export fn main() void {
    const a: *volatile u16 = @ptrFromInt(0x1234);
    a.* = 5;
    a.* *= 2;
    a.* -= 3;
}
