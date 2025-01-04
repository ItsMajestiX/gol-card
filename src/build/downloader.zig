const std = @import("std");

pub fn main() !void {
    // Ensure we only have the program + the URL
    std.debug.assert(std.os.argv.len == 2);

    // Set up an allocator, doesn't need to be super high performance
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Set up the HTTP(S) client
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    // Parse the input as a URI
    const argv = std.mem.sliceTo(std.os.argv[1], 0);
    const uri = try std.Uri.parse(argv);

    // Set up the request
    var hBuf: [8192]u8 = undefined;
    var r = try client.open(.GET, uri, .{
        .server_header_buffer = &hBuf,
    });
    defer r.deinit();

    try r.send();
    try r.wait();

    // Find the file name, create the file and open it
    const path = switch (uri.path) {
        .percent_encoded, .raw => |value| value,
    };
    var file_iter = std.mem.splitBackwardsScalar(u8, path, '/');
    const file_name = file_iter.first();
    const file = try std.fs.cwd().createFile(file_name, std.fs.File.CreateFlags{});
    defer file.close();

    // Write data into file
    var buf: [8192]u8 = undefined;
    while (true) {
        const len = try r.read(&buf);
        if (len == 0) break;
        try file.writeAll(buf[0..len]);
    }
}
