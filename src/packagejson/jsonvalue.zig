const std = @import("std");

pub const JSONValueType = enum(u8) {
    NotPresent = 0,
    Null,
    String,
    Number,
    Boolean,
    Array,
    Object,

    pub fn toString(self: JSONValueType) []const u8 {
        return switch (self) {
            .Null => "null",
            .String => "string",
            .Number => "number",
            .Boolean => "boolean",
            .Array => "array",
            .Object => "object",
            else => "unknown",
        };
    }
};

pub const JSONValue = union(JSONValueType) {
    NotPresent: void,
    Null: void,
    String: []const u8,
    Number: f64, // simplified
    Boolean: bool,
    Array: []JSONValue,
    Object: std.StringArrayHashMap(JSONValue),

    pub fn isPresent(self: *const JSONValue) bool {
        return self.* != .NotPresent;
    }

    pub fn isFalsy(self: *const JSONValue) bool {
        return switch (self.*) {
            .NotPresent, .Null => true,
            .String => |s| s.len == 0,
            .Number => |n| n == 0,
            .Boolean => |b| !b,
            else => false,
        };
    }

    pub fn asObject(self: *const JSONValue) *const std.StringArrayHashMap(JSONValue) {
        if (self.* != .Object) @panic("expected object");
        return &self.Object;
    }

    pub fn asArray(self: *const JSONValue) []const JSONValue {
        if (self.* != .Array) @panic("expected array");
        return self.Array;
    }

    pub fn asString(self: *const JSONValue) []const u8 {
        if (self.* != .String) @panic("expected string");
        return self.String;
    }

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!JSONValue {
        const value = try std.json.Value.jsonParse(allocator, source, options);
        return fromJsonValue(allocator, value) catch return error.UnexpectedToken;
    }

    fn fromJsonValue(allocator: std.mem.Allocator, value: std.json.Value) !JSONValue {
        return switch (value) {
            .null => .{ .Null = {} },
            .bool => |b| .{ .Boolean = b },
            .integer => |i| .{ .Number = @floatFromInt(i) },
            .float => |f| .{ .Number = f },
            .number_string => |s| .{ .Number = try std.fmt.parseFloat(f64, s) },
            .string => |s| .{ .String = try allocator.dupe(u8, s) },
            .array => |arr| {
                const new_arr = try allocator.alloc(JSONValue, arr.items.len);
                for (arr.items, 0..) |item, i| {
                    new_arr[i] = try fromJsonValue(allocator, item);
                }
                return .{ .Array = new_arr };
            },
            .object => |obj| {
                var new_obj = std.StringArrayHashMap(JSONValue).init(allocator);
                var it = obj.iterator();
                while (it.next()) |entry| {
                    try new_obj.put(try allocator.dupe(u8, entry.key_ptr.*), try fromJsonValue(allocator, entry.value_ptr.*));
                }
                return .{ .Object = new_obj };
            },
        };
    }
};
