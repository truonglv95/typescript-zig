const std = @import("std");
const lineinfo = @import("lineinfo.zig");
const stringutil = @import("../stringutil/stringutil.zig");

// Tries to find the sourceMappingURL comment at the end of a file.
pub fn tryGetSourceMappingURL(line_info: ?*const lineinfo.ECMALineInfo) []const u8 {
    if (line_info) |li| {
        if (li.lineCount() == 0) return "";
        var index: isize = @as(isize, @intCast(li.lineCount())) - 1;
        while (index >= 0) : (index -= 1) {
            var line = li.lineText(@as(u32, @intCast(index)));
            line = std.mem.trimLeft(u8, line, " \t\r\n\x0B\x0C");

            // Trim right using stringutil.isLineBreak
            var end: usize = line.len;
            while (end > 0) {
                if (end >= 1 and line[end - 1] < 0x80) {
                    if (stringutil.isLineBreak(line[end - 1])) {
                        end -= 1;
                        continue;
                    }
                } else if (end >= 3 and line[end-3] == 0xE2 and line[end-2] == 0x80 and (line[end-1] == 0xA8 or line[end-1] == 0xA9)) {
                    end -= 3;
                    continue;
                }
                break;
            }
            line = line[0..end];
            
            if (line.len == 0) {
                continue;
            }
            if (line.len < 4 or !std.mem.startsWith(u8, line, "//") or (line[2] != '#' and line[2] != '@') or line[3] != ' ') {
                break;
            }
            
            const url_prefix = "sourceMappingURL=";
            const content = line[4..];
            if (std.mem.startsWith(u8, content, url_prefix)) {
                const url = content[url_prefix.len..];
                var url_end: usize = url.len;
                while (url_end > 0 and (url[url_end - 1] == ' ' or url[url_end - 1] == '\t' or url[url_end - 1] == '\r' or url[url_end - 1] == '\n' or url[url_end - 1] == '\x0B' or url[url_end - 1] == '\x0C')) {
                    url_end -= 1;
                }
                return url[0..url_end];
            }
        }
    }
    return "";
}
