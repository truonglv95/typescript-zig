const std = @import("std");
const transport = @import("tsc").lsp_transport;
const protocol = @import("tsc").lsp_protocol;

pub fn main(init: std.process.Init) !void {
    var decoder = transport.Decoder.init(init.gpa);
    defer decoder.deinit();
    var session = protocol.Session.init(init.gpa);
    defer session.deinit();

    const stdin = std.Io.File.stdin();
    const stdout = std.Io.File.stdout();
    var output_buffer: [16 * 1024]u8 = undefined;
    var output = stdout.writerStreaming(init.io, &output_buffer);
    var input_buffer: [16 * 1024]u8 = undefined;

    while (!session.exit_requested) {
        const read = try std.Io.File.readStreaming(stdin, init.io, &.{&input_buffer});
        if (read == 0) break;
        try decoder.feed(input_buffer[0..read]);
        while (try decoder.next()) |payload| {
            defer init.gpa.free(payload);
            const response = session.handle(payload) catch |err| {
                const error_payload = try std.fmt.allocPrint(init.gpa, "{{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{{\"code\":-32603,\"message\":\"{t}\"}}}}", .{err});
                defer init.gpa.free(error_payload);
                const frame = try transport.encode(init.gpa, error_payload);
                defer init.gpa.free(frame);
                try output.interface.writeAll(frame);
                try output.flush();
                continue;
            };
            if (response) |response_payload| {
                defer init.gpa.free(response_payload);
                const frame = try transport.encode(init.gpa, response_payload);
                defer init.gpa.free(frame);
                try output.interface.writeAll(frame);
                try output.flush();
            }
        }
    }
}
