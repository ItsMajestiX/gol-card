///! When building MSP430 assembly, Zig/LLVM adds Call Frame Information directives to the assembly.
///! The problem is that the assembler will error out if it encounters any of these directives.
///! From what I've seen, there no easy way to either tell Zig to tell LLVM to stop producing the directives, or
///! tell GCC and its assembler to ignore them. That means I need to manually remove them in the build process.
const std = @import("std");

const RemoveCFIStep = @This();

step: std.Build.Step,
file: std.Build.LazyPath,

fn make(step: *std.Build.Step, opt: std.Build.Step.MakeOptions) anyerror!void {
    const self: *RemoveCFIStep = @fieldParentPtr("step", step);

    var file = try std.fs.openFileAbsolute(self.file.getPath2(step.owner, step), .{ .mode = .read_write });
    defer file.close();

    const filesize = (try file.metadata()).size();
    var progress: std.Progress.Node = opt.progress_node.start("Removing CFI Directives", 100);
    defer progress.end();

    // Separately keep track of where reading and writing is going on.
    var read_idx: u64 = 0;
    var write_idx: u64 = 0;
    // Write buffer
    var buf: [8192]u8 = undefined;
    // Have we started on a CFI directive?
    var cfi_found: bool = false;
    var offset: usize = 0;
    while (true) {
        // Read into buffer
        try file.seekTo(read_idx);
        const idx = try file.read(buf[offset..]);
        if (write_idx > 10000000) @panic("Runaway CFI code.");
        if (idx == 0) break;
        read_idx += idx;
        progress.setCompletedItems((read_idx * 100) / (filesize));
        const haystack = buf[0..idx];

        // Deal with all of the data in the buffer
        var start_idx: usize = 0;
        while (true) {
            if (cfi_found) {
                // Find the end of the line (LF line endings)
                start_idx = std.mem.indexOfScalarPos(u8, haystack, start_idx, '\n') orelse {
                    // Nothing has been found, get new data.
                    offset = 0;
                    break;
                };
                // Found the end of the line, start writing to file again.
                cfi_found = false;
                // Skip the newline too, and avoid edge case at end of buffer
                start_idx += 1;
                if (start_idx == haystack.len) {
                    offset = 0;
                    break;
                }
                continue;
            } else {
                // Check for the start of a CFI directive
                const next_idx = std.mem.indexOfPos(u8, haystack, start_idx, "\t.cfi") orelse {
                    // No whole needle exists. However, there could be one that got cut off.
                    // If there are any tabs in the last four characters (minimum that would not be detected), save them and any proceding characters
                    // This is a tradeoff from having to check for multiple combinations of characters
                    const tab_idx = std.mem.indexOfScalarPos(u8, haystack, haystack.len - 4, '\t') orelse haystack.len;
                    // Write safe data back to file
                    try file.seekTo(write_idx);
                    const safe = haystack[start_idx..tab_idx];
                    try file.writeAll(safe);
                    write_idx += safe.len;
                    // Put unsafe data at front of buffer
                    const unsafe = haystack[tab_idx..];
                    std.mem.copyForwards(u8, &buf, unsafe);
                    // Tell the code to not overwrite this data
                    offset = unsafe.len;
                    break;
                };
                // Found one, write everything before it
                try file.seekTo(write_idx);
                const safe = haystack[start_idx..next_idx];
                try file.writeAll(safe);
                // Start writing at the correct spot next time
                write_idx += safe.len;
                // Switch to CFI found mode
                cfi_found = true;
                start_idx = next_idx;
                continue;
            }
        }
    }
    // Chop off the unsued part of the file
    try file.setEndPos(write_idx);
}

pub fn create(owner: *std.Build, file: std.Build.LazyPath) *RemoveCFIStep {
    const remove = owner.allocator.create(RemoveCFIStep) catch @panic("OOM");
    remove.* = .{
        .file = file,
        .step = std.Build.Step.init(.{
            .id = std.Build.Step.Id.custom,
            .makeFn = make,
            .name = "remove CFI",
            .owner = owner,
        }),
    };
    return remove;
}
