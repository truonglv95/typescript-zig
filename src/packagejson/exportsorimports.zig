const std = @import("std");
const jsonvalue = @import("jsonvalue.zig");

pub const ObjectKind = enum(i8) {
    Unknown = 0,
    Subpaths,
    Conditions,
    Imports,
    Invalid,
};

pub const ExportsOrImports = struct {
    json_value: jsonvalue.JSONValue,
    object_kind: ObjectKind = .Unknown,

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!ExportsOrImports {
        const val = try jsonvalue.JSONValue.jsonParse(allocator, source, options);
        return ExportsOrImports{ .json_value = val };
    }

    // In Zig, we'll return the base JSONValue and let callers map it to ExportsOrImports,
    // or we create a new map. For DoD and memory safety, we'll just return the map of JSONValues.
    // Callers will wrap the JSONValue into ExportsOrImports when iterating.
    pub fn asObject(self: *const ExportsOrImports) *const std.StringArrayHashMap(jsonvalue.JSONValue) {
        return self.json_value.asObject();
    }

    pub fn asArray(self: *const ExportsOrImports) []const jsonvalue.JSONValue {
        return self.json_value.asArray();
    }

    pub fn isSubpaths(self: *ExportsOrImports) bool {
        self.initObjectKind();
        return self.object_kind == .Subpaths;
    }

    pub fn isImports(self: *ExportsOrImports) bool {
        self.initObjectKind();
        return self.object_kind == .Imports;
    }

    pub fn isConditions(self: *ExportsOrImports) bool {
        self.initObjectKind();
        return self.object_kind == .Conditions;
    }

    fn initObjectKind(self: *ExportsOrImports) void {
        if (self.object_kind == .Unknown and self.json_value == .Object) {
            const obj = self.asObject();
            if (obj.count() > 0) {
                var seenDot = false;
                var seenHash = false;
                var seenOther = false;
                
                var it = obj.iterator();
                while (it.next()) |entry| {
                    const k = entry.key_ptr.*;
                    if (k.len > 0) {
                        seenDot = seenDot or k[0] == '.';
                        seenHash = seenHash or k[0] == '#';
                        seenOther = seenOther or (k[0] != '.' and k[0] != '#');
                        if (seenOther and (seenDot or seenHash)) {
                            self.object_kind = .Invalid;
                            return;
                        }
                    }
                }
                if (seenDot) {
                    self.object_kind = .Subpaths;
                    return;
                }
                if (seenHash) {
                    self.object_kind = .Imports;
                    return;
                }
            }
            self.object_kind = .Conditions;
        }
    }
};
