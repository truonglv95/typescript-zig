const std = @import("std");

pub fn Expected(comptime T: type) type {
    return struct {
        actualJSONType: []const u8 = "",
        Null: bool = false,
        Valid: bool = false,
        Value: T = undefined,

        pub fn isPresent(self: *const @This()) bool {
            return self.actualJSONType.len > 0;
        }

        pub fn getValue(self: *const @This()) ?T {
            if (self.Valid) return self.Value;
            return null;
        }

        pub fn isValid(self: *const @This()) bool {
            return self.Valid;
        }

        pub fn expectedJSONType(self: *const @This()) []const u8 {
            _ = self;
            const info = @typeInfo(T);
            switch (info) {
                .Pointer => |p| {
                    if (p.child == u8) return "string"; // simplistic string
                    return "unknown"; // ... mapping for other types
                },
                .Array => return "array",
                .Struct => return "object",
                .Bool => return "boolean",
                .Int, .Float => return "number",
                else => return "unknown",
            }
        }

        pub fn actualJSONTypeStr(self: *const @This()) []const u8 {
            return self.actualJSONType;
        }

        pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!@This() {
            var res = @This(){};
            const value = try std.json.Value.jsonParse(allocator, source, options);
            switch (value) {
                .null => {
                    res.actualJSONType = "null";
                    res.Null = true;
                },
                .string => {
                    res.actualJSONType = "string";
                    if (std.json.parseFromValue(T, allocator, value, options)) |parsed| {
                        res.Value = parsed.value;
                        res.Valid = true;
                    } else |_| {}
                },
                .bool => {
                    res.actualJSONType = "boolean";
                    if (std.json.parseFromValue(T, allocator, value, options)) |parsed| {
                        res.Value = parsed.value;
                        res.Valid = true;
                    } else |_| {}
                },
                .array => {
                    res.actualJSONType = "array";
                    if (std.json.parseFromValue(T, allocator, value, options)) |parsed| {
                        res.Value = parsed.value;
                        res.Valid = true;
                    } else |_| {}
                },
                .object => {
                    res.actualJSONType = "object";
                    if (std.json.parseFromValue(T, allocator, value, options)) |parsed| {
                        res.Value = parsed.value;
                        res.Valid = true;
                    } else |_| {}
                },
                .integer, .float, .number_string => {
                    res.actualJSONType = "number";
                    if (std.json.parseFromValue(T, allocator, value, options)) |parsed| {
                        res.Value = parsed.value;
                        res.Valid = true;
                    } else |_| {}
                },
            }
            return res;
        }
    };
}

pub fn ExpectedOf(comptime T: type, value: T) Expected(T) {
    var res = Expected(T){
        .Value = value,
        .Valid = true,
    };
    res.actualJSONType = res.expectedJSONType();
    return res;
}
