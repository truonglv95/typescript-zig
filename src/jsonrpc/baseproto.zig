const std = @import("std");

pub const ErrInvalidHeader = error.InvalidHeader;
pub const ErrInvalidContentLength = error.InvalidContentLength;
pub const ErrNoContentLength = error.NoContentLength;

pub const Reader = struct {
    reader: std.io.AnyReader,

    pub fn init(reader: std.io.AnyReader) Reader {
        return .{
            .reader = reader,
        };
    }

    pub fn read(self: *Reader, allocator: std.mem.Allocator) ![]u8 {
        var contentLength: i64 = -1;

        while (true) {
            var buf: [1024]u8 = undefined;
            // Read until \n
            const line = try self.reader.readUntilDelimiterOrEof(&buf, '\n');
            if (line) |l| {
                if (std.mem.eql(u8, l, "\r")) {
                    break;
                }
                const colonIdx = std.mem.indexOf(u8, l, ":");
                if (colonIdx == null) return ErrInvalidHeader;
                
                const key = l[0..colonIdx.?];
                const value = std.mem.trim(u8, l[colonIdx.? + 1 ..], " \r\t");
                
                if (std.mem.eql(u8, key, "Content-Length")) {
                    contentLength = std.fmt.parseInt(i64, value, 10) catch return ErrInvalidContentLength;
                    if (contentLength < 0) return ErrInvalidContentLength;
                }
            } else {
                return error.EndOfStream;
            }
        }

        if (contentLength <= 0) {
            return ErrNoContentLength;
        }

        const data = try allocator.alloc(u8, @as(usize, @intCast(contentLength)));
        try self.reader.readNoEof(data);
        return data;
    }
};

pub const Writer = struct {
    writer: std.io.AnyWriter,

    pub fn init(writer: std.io.AnyWriter) Writer {
        return .{
            .writer = writer,
        };
    }

    pub fn write(self: *Writer, data: []const u8) !void {
        try self.writer.print("Content-Length: {d}\r\n\r\n", .{data.len});
        try self.writer.writeAll(data);
    }
};
