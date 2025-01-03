///! This file has some code from std.zip reproduced so that I can modify its internals
///! The major changes:
///! 1. Add the ability to only extract certain files from the archive.
///! 2. Ignore the directory structure of the zip file and directly extract all files to the given folder.
const std = @import("std");

fn isBadFilename(filename: []const u8) bool {
    if (filename.len == 0 or filename[0] == '/')
        return true;

    var it = std.mem.splitScalar(u8, filename, '/');
    while (it.next()) |part| {
        if (std.mem.eql(u8, part, ".."))
            return true;
    }

    return false;
}

fn isMaxInt(uint: anytype) bool {
    return uint == std.math.maxInt(@TypeOf(uint));
}

fn readZip64FileExtents(header: CentralDirectoryFileHeader, extents: *FileExtents, data: []u8) !void {
    var data_offset: usize = 0;
    if (isMaxInt(header.uncompressed_size)) {
        if (data_offset + 8 > data.len)
            return error.ZipBadCd64Size;
        extents.uncompressed_size = std.mem.readInt(u64, data[data_offset..][0..8], .little);
        data_offset += 8;
    }
    if (isMaxInt(header.compressed_size)) {
        if (data_offset + 8 > data.len)
            return error.ZipBadCd64Size;
        extents.compressed_size = std.mem.readInt(u64, data[data_offset..][0..8], .little);
        data_offset += 8;
    }
    if (isMaxInt(header.local_file_header_offset)) {
        if (data_offset + 8 > data.len)
            return error.ZipBadCd64Size;
        extents.local_file_header_offset = std.mem.readInt(u64, data[data_offset..][0..8], .little);
        data_offset += 8;
    }
    if (isMaxInt(header.disk_number)) {
        if (data_offset + 4 > data.len)
            return error.ZipInvalid;
        const disk_number = std.mem.readInt(u32, data[data_offset..][0..4], .little);
        if (disk_number != 0)
            return error.ZipMultiDiskUnsupported;
        data_offset += 4;
    }
    if (data_offset > data.len)
        return error.ZipBadCd64Size;
}

const FileExtents = struct {
    uncompressed_size: u64,
    compressed_size: u64,
    local_file_header_offset: u64,
};

const GeneralPurposeFlags = packed struct(u16) {
    encrypted: bool,
    _: u15,
};

pub const CentralDirectoryFileHeader = extern struct {
    signature: [4]u8 align(1),
    version_made_by: u16 align(1),
    version_needed_to_extract: u16 align(1),
    flags: GeneralPurposeFlags align(1),
    compression_method: std.zip.CompressionMethod align(1),
    last_modification_time: u16 align(1),
    last_modification_date: u16 align(1),
    crc32: u32 align(1),
    compressed_size: u32 align(1),
    uncompressed_size: u32 align(1),
    filename_len: u16 align(1),
    extra_len: u16 align(1),
    comment_len: u16 align(1),
    disk_number: u16 align(1),
    internal_file_attributes: u16 align(1),
    external_file_attributes: u32 align(1),
    local_file_header_offset: u32 align(1),
};

pub fn Iterator(comptime SeekableStream: type) type {
    return struct {
        stream: SeekableStream,

        cd_record_count: u64,
        cd_zip_offset: u64,
        cd_size: u64,

        cd_record_index: u64 = 0,
        cd_record_offset: u64 = 0,

        const Self = @This();

        pub fn init(stream: SeekableStream) !Self {
            const stream_len = try stream.getEndPos();
            const end_record = try std.zip.findEndRecord(stream, stream_len);

            if (!isMaxInt(end_record.record_count_disk) and end_record.record_count_disk > end_record.record_count_total)
                return error.ZipDiskRecordCountTooLarge;

            if (end_record.disk_number != 0 or end_record.central_directory_disk_number != 0)
                return error.ZipMultiDiskUnsupported;

            {
                const counts_valid = !isMaxInt(end_record.record_count_disk) and !isMaxInt(end_record.record_count_total);
                if (counts_valid and end_record.record_count_disk != end_record.record_count_total)
                    return error.ZipMultiDiskUnsupported;
            }

            var result = Self{
                .stream = stream,
                .cd_record_count = end_record.record_count_total,
                .cd_zip_offset = end_record.central_directory_offset,
                .cd_size = end_record.central_directory_size,
            };
            if (!end_record.need_zip64()) return result;

            const locator_end_offset: u64 = @as(u64, end_record.comment_len) + @sizeOf(std.zip.EndRecord) + @sizeOf(std.zip.EndLocator64);
            if (locator_end_offset > stream_len)
                return error.ZipTruncated;
            try stream.seekTo(stream_len - locator_end_offset);
            const locator = try stream.context.reader().readStructEndian(std.zip.EndLocator64, .little);
            if (!std.mem.eql(u8, &locator.signature, &std.zip.end_locator64_sig))
                return error.ZipBadLocatorSig;
            if (locator.zip64_disk_count != 0)
                return error.ZipUnsupportedZip64DiskCount;
            if (locator.total_disk_count != 1)
                return error.ZipMultiDiskUnsupported;

            try stream.seekTo(locator.record_file_offset);

            const record64 = try stream.context.reader().readStructEndian(std.zip.EndRecord64, .little);

            if (!std.mem.eql(u8, &record64.signature, &std.zip.end_record64_sig))
                return error.ZipBadEndRecord64Sig;

            if (record64.end_record_size < @sizeOf(std.zip.EndRecord64) - 12)
                return error.ZipEndRecord64SizeTooSmall;
            if (record64.end_record_size > @sizeOf(std.zip.EndRecord64) - 12)
                return error.ZipEndRecord64UnhandledExtraData;

            if (record64.version_needed_to_extract > 45)
                return error.ZipUnsupportedVersion;

            {
                const is_multidisk = record64.disk_number != 0 or
                    record64.central_directory_disk_number != 0 or
                    record64.record_count_disk != record64.record_count_total;
                if (is_multidisk)
                    return error.ZipMultiDiskUnsupported;
            }

            if (isMaxInt(end_record.record_count_total)) {
                result.cd_record_count = record64.record_count_total;
            } else if (end_record.record_count_total != record64.record_count_total)
                return error.Zip64RecordCountTotalMismatch;

            if (isMaxInt(end_record.central_directory_offset)) {
                result.cd_zip_offset = record64.central_directory_offset;
            } else if (end_record.central_directory_offset != record64.central_directory_offset)
                return error.Zip64CentralDirectoryOffsetMismatch;

            if (isMaxInt(end_record.central_directory_size)) {
                result.cd_size = record64.central_directory_size;
            } else if (end_record.central_directory_size != record64.central_directory_size)
                return error.Zip64CentralDirectorySizeMismatch;

            return result;
        }

        pub fn next(self: *Self) !?Entry {
            if (self.cd_record_index == self.cd_record_count) {
                if (self.cd_record_offset != self.cd_size)
                    return if (self.cd_size > self.cd_record_offset)
                        error.ZipCdOversized
                    else
                        error.ZipCdUndersized;

                return null;
            }

            const header_zip_offset = self.cd_zip_offset + self.cd_record_offset;
            try self.stream.seekTo(header_zip_offset);
            const header = try self.stream.context.reader().readStructEndian(CentralDirectoryFileHeader, .little);
            if (!std.mem.eql(u8, &header.signature, &std.zip.central_file_header_sig))
                return error.ZipBadCdOffset;

            self.cd_record_index += 1;
            self.cd_record_offset += @sizeOf(CentralDirectoryFileHeader) + header.filename_len + header.extra_len + header.comment_len;

            // Note: checking the version_needed_to_extract doesn't seem to be helpful, i.e. the zip file
            // at https://github.com/ninja-build/ninja/releases/download/v1.12.0/ninja-linux.zip
            // has an undocumented version 788 but extracts just fine.

            if (header.flags.encrypted)
                return error.ZipEncryptionUnsupported;
            // TODO: check/verify more flags
            if (header.disk_number != 0)
                return error.ZipMultiDiskUnsupported;

            var extents: FileExtents = .{
                .uncompressed_size = header.uncompressed_size,
                .compressed_size = header.compressed_size,
                .local_file_header_offset = header.local_file_header_offset,
            };

            if (header.extra_len > 0) {
                var extra_buf: [std.math.maxInt(u16)]u8 = undefined;
                const extra = extra_buf[0..header.extra_len];

                {
                    try self.stream.seekTo(header_zip_offset + @sizeOf(std.zip.CentralDirectoryFileHeader) + header.filename_len);
                    const len = try self.stream.context.reader().readAll(extra);
                    if (len != extra.len)
                        return error.ZipTruncated;
                }

                var extra_offset: usize = 0;
                while (extra_offset + 4 <= extra.len) {
                    const header_id = std.mem.readInt(u16, extra[extra_offset..][0..2], .little);
                    const data_size = std.mem.readInt(u16, extra[extra_offset..][2..4], .little);
                    const end = extra_offset + 4 + data_size;
                    if (end > extra.len)
                        return error.ZipBadExtraFieldSize;
                    const data = extra[extra_offset + 4 .. end];
                    switch (@as(std.zip.ExtraHeader, @enumFromInt(header_id))) {
                        .zip64_info => try readZip64FileExtents(header, &extents, data),
                        else => {}, // ignore
                    }
                    extra_offset = end;
                }
            }

            return .{
                .version_needed_to_extract = header.version_needed_to_extract,
                .flags = header.flags,
                .compression_method = header.compression_method,
                .last_modification_time = header.last_modification_time,
                .last_modification_date = header.last_modification_date,
                .header_zip_offset = header_zip_offset,
                .crc32 = header.crc32,
                .filename_len = header.filename_len,
                .compressed_size = extents.compressed_size,
                .uncompressed_size = extents.uncompressed_size,
                .file_offset = extents.local_file_header_offset,
            };
        }

        pub const Entry = struct {
            version_needed_to_extract: u16,
            flags: GeneralPurposeFlags,
            compression_method: std.zip.CompressionMethod,
            last_modification_time: u16,
            last_modification_date: u16,
            header_zip_offset: u64,
            crc32: u32,
            filename_len: u32,
            compressed_size: u64,
            uncompressed_size: u64,
            file_offset: u64,

            pub fn extract(
                self: Entry,
                stream: SeekableStream,
                options: std.zip.ExtractOptions,
                filename_buf: []u8,
                dest: std.fs.Dir,
                comptime files: anytype,
            ) !u32 {
                if (filename_buf.len < self.filename_len)
                    return error.ZipInsufficientBuffer;
                const filename = filename_buf[0..self.filename_len];

                try stream.seekTo(self.header_zip_offset + @sizeOf(std.zip.CentralDirectoryFileHeader));

                {
                    const len = try stream.context.reader().readAll(filename);
                    if (len != filename.len)
                        return error.ZipBadFileOffset;
                }

                const local_data_header_offset: u64 = local_data_header_offset: {
                    const local_header = blk: {
                        try stream.seekTo(self.file_offset);
                        break :blk try stream.context.reader().readStructEndian(std.zip.LocalFileHeader, .little);
                    };
                    if (!std.mem.eql(u8, &local_header.signature, &std.zip.local_file_header_sig))
                        return error.ZipBadFileOffset;
                    if (local_header.version_needed_to_extract != self.version_needed_to_extract)
                        return error.ZipMismatchVersionNeeded;
                    if (local_header.last_modification_time != self.last_modification_time)
                        return error.ZipMismatchModTime;
                    if (local_header.last_modification_date != self.last_modification_date)
                        return error.ZipMismatchModDate;

                    if (@as(u16, @bitCast(local_header.flags)) != @as(u16, @bitCast(self.flags)))
                        return error.ZipMismatchFlags;
                    if (local_header.crc32 != 0 and local_header.crc32 != self.crc32)
                        return error.ZipMismatchCrc32;
                    if (local_header.compressed_size != 0 and
                        local_header.compressed_size != self.compressed_size)
                        return error.ZipMismatchCompLen;
                    if (local_header.uncompressed_size != 0 and
                        local_header.uncompressed_size != self.uncompressed_size)
                        return error.ZipMismatchUncompLen;
                    if (local_header.filename_len != self.filename_len)
                        return error.ZipMismatchFilenameLen;

                    break :local_data_header_offset @as(u64, local_header.filename_len) +
                        @as(u64, local_header.extra_len);
                };

                if (isBadFilename(filename))
                    return error.ZipBadFilename;

                if (options.allow_backslashes) {
                    std.mem.replaceScalar(u8, filename, '\\', '/');
                } else {
                    if (std.mem.indexOfScalar(u8, filename, '\\')) |_|
                        return error.ZipFilenameHasBackslash;
                }

                // Only continue if the file is in the list
                blk: {
                    inline for (files) |value| {
                        if (std.mem.eql(u8, filename, value)) {
                            break :blk;
                        }
                    }
                    return error.ZipFileNotInList;
                }

                // All entries that end in '/' are directories
                if (filename[filename.len - 1] == '/') {
                    if (self.uncompressed_size != 0)
                        return error.ZipBadDirectorySize;
                    // No extra directories
                    // try dest.makePath(filename[0 .. filename.len - 1]);
                    return std.hash.Crc32.hash(&.{});
                }

                const out_file = blk: {
                    if (std.fs.path.dirname(filename) != null) {
                        // No extra directories
                        // var parent_dir = try dest.makeOpenPath(dirname, .{});
                        // defer parent_dir.close();

                        const basename = std.fs.path.basename(filename);
                        break :blk try dest.createFile(basename, .{ .exclusive = true });
                    }
                    break :blk try dest.createFile(filename, .{ .exclusive = true });
                };
                defer out_file.close();
                const local_data_file_offset: u64 =
                    @as(u64, self.file_offset) +
                    @as(u64, @sizeOf(std.zip.LocalFileHeader)) +
                    local_data_header_offset;
                try stream.seekTo(local_data_file_offset);
                var limited_reader = std.io.limitedReader(stream.context.reader(), self.compressed_size);
                const crc = try std.zip.decompress(
                    self.compression_method,
                    self.uncompressed_size,
                    limited_reader.reader(),
                    out_file.writer(),
                );
                if (limited_reader.bytes_left != 0)
                    return error.ZipDecompressTruncated;
                return crc;
            }
        };
    };
}

// returns true if `filename` starts with `root` followed by a forward slash
fn filenameInRoot(filename: []const u8, root: []const u8) bool {
    return (filename.len >= root.len + 1) and
        (filename[root.len] == '/') and
        std.mem.eql(u8, filename[0..root.len], root);
}

/// Extract the zipped files inside `seekable_stream` to the given `dest` directory.
/// Note that `seekable_stream` must be an instance of `std.io.SeekabkeStream` and
/// its context must also have a `.reader()` method that returns an instance of
/// `std.io.Reader`.
pub fn extract(dest: std.fs.Dir, seekable_stream: anytype, comptime files: anytype) !void {
    const SeekableStream = @TypeOf(seekable_stream);
    var iter = try Iterator(SeekableStream).init(seekable_stream);

    var filename_buf: [std.fs.max_path_bytes]u8 = undefined;
    while (try iter.next()) |entry| {
        const crc32 = entry.extract(seekable_stream, .{}, &filename_buf, dest, files) catch |err| switch (err) {
            error.ZipFileNotInList => continue,
            else => return err,
        };
        if (crc32 != entry.crc32)
            return error.ZipCrcMismatch;
    }
}
