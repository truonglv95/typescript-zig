const std = @import("std");

pub fn fail(reason: []const u8) noreturn {
    if (reason.len == 0) {
        std.debug.panic("Debug failure.", .{});
    } else {
        std.debug.panic("Debug failure. {s}", .{reason});
    }
}

pub fn failBadSyntaxKind(node: anytype, message: []const u8) noreturn {
    const msg = if (message.len == 0) "Unexpected node." else message;
    std.debug.panic("{s}\nNode {s} was unexpected.", .{ msg, node.kindString() });
}

pub fn assertNever(member: anytype, message: []const u8) noreturn {
    const msg = if (message.len == 0) "Illegal value:" else message;
    if (@hasDecl(@TypeOf(member), "kindString")) {
        std.debug.panic("{s} {s}", .{ msg, member.kindString() });
    } else {
        std.debug.panic("{s} {any}", .{ msg, member });
    }
}

pub fn assert(value: bool, message: []const u8) void {
    if (!value) {
        assertSlow(message);
    }
}

fn assertSlow(message: []const u8) noreturn {
    if (message.len > 0) {
        std.debug.panic("False expression: {s}", .{message});
    } else {
        std.debug.panic("False expression.", .{});
    }
}
