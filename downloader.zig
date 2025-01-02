const std = @import("std");

pub fn main() !void {
    std.debug.assert(std.os.argv.len == 2);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var hBuf: [8192]u8 = undefined;
    const argv = std.mem.sliceTo(std.os.argv[1], 0);

    const uri = try std.Uri.parse(argv);
    const path = switch (uri.path) {
        .percent_encoded, .raw => |value| value,
    };

    var file_iter = std.mem.splitBackwardsScalar(u8, path, '/');
    const file_name = file_iter.first();

    var r = try client.open(.GET, uri, .{
        .server_header_buffer = &hBuf,
    });
    defer r.deinit();

    try r.send();
    try r.wait();

    const file = try std.fs.cwd().createFile(file_name, std.fs.File.CreateFlags{});
    defer file.close();

    var buf: [8192]u8 = undefined;
    while (true) {
        const len = try r.read(&buf);
        if (len == 0) break;
        try file.writeAll(buf[0..len]);
    }
}
