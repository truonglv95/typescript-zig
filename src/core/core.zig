const std = @import("std");
pub fn unorderedEqual(comptime T: type, a: []const T, b: []const T) bool {
    _ = a;
    _ = b;
    return true;
}

pub const LanguageVariant = enum(u32) {
    Standard = 0,
    JSX = 1,
};

pub fn Concatenate(allocator: std.mem.Allocator, array1: anytype, array2: anytype) !@TypeOf(array1) {
    const T = @typeInfo(@TypeOf(array1)).pointer.child;
    var list = std.ArrayList(T).empty;
    try list.appendSlice(allocator, array1);
    try list.appendSlice(allocator, array2);
    return try list.toOwnedSlice(allocator);
}

pub const TextPos = usize;

pub const UTF16Offset = i32;

pub const Tristate = enum(u8) {
    Unknown = 0,
    True = 1,
    False = 2,

    pub fn isTrue(self: Tristate) bool {
        return self == .True;
    }

    pub fn isFalse(self: Tristate) bool {
        return self == .False;
    }

    pub fn isUnknown(self: Tristate) bool {
        return self == .Unknown;
    }

    pub fn isTrueOrUnknown(self: Tristate) bool {
        return self == .True or self == .Unknown;
    }

    pub fn isFalseOrUnknown(self: Tristate) bool {
        return self == .False or self == .Unknown;
    }
};

pub const ScriptTarget = enum(u32) {
    None = 0,
    ES5 = 1,
    ES2015 = 2,
    ES2016 = 3,
    ES2017 = 4,
    ES2018 = 5,
    ES2019 = 6,
    ES2020 = 7,
    ES2021 = 8,
    ES2022 = 9,
    ES2023 = 10,
    ES2024 = 11,
    ES2025 = 12,
    ESNext = 99,
    JSON = 100,

    pub const Latest = ScriptTarget.ESNext;
};

pub const CompilerOptions = @import("compiler_options_generated.zig").CompilerOptions;

pub const ModuleKind = enum(u32) {
    None = 0,
    CommonJS = 1,
    AMD = 2,
    UMD = 3,
    System = 4,
    ES2015 = 5,
    ES2020 = 6,
    ES2022 = 7,
    ESNext = 99,
    Node16 = 100,
    NodeNext = 199,
    Preserve = 200,
};

pub const ResolutionMode = ModuleKind;

pub const ModuleResolutionKind = enum(u32) {
    Classic = 1,
    NodeJs = 2,
    Node16 = 3,
    NodeNext = 99,
    Bundler = 100,
};

pub const ModuleDetectionKind = enum(u32) {
    Legacy = 1,
    Auto = 2,
    Force = 3,
};

pub const JsxEmit = enum(u32) {
    None = 0,
    Preserve = 1,
    ReactNative = 2,
    React = 3,
    ReactJSX = 4,
    ReactJSXDev = 5,
};

pub const NewLineKind = enum(u32) {
    CarriageReturnLineFeed = 0,
    LineFeed = 1,
};

pub const ImportsNotUsedAsValues = enum(u32) {
    Remove = 0,
    Preserve = 1,
    Error = 2,
};

pub const PollingWatchKind = enum(u32) {
    FixedInterval = 0,
    PriorityInterval = 1,
    DynamicPriority = 2,
    FixedChunkSize = 3,
};

pub const WatchFileKind = enum(u32) {
    FixedPollingInterval = 0,
    PriorityPollingInterval = 1,
    DynamicPriorityPolling = 2,
    UseFsEvents = 3,
    UseFsEventsOnParentDirectory = 4,
};

pub const WatchDirectoryKind = enum(u32) {
    UseFsEvents = 0,
    FixedPollingInterval = 1,
    DynamicPriorityPolling = 2,
    FixedChunkSizePolling = 3,
};

pub const TokenFlags = enum(u32) {
    None = 0,
};

pub const ScriptKind = enum(u32) {
    Unknown = 0,
    JS = 1,
    JSX = 2,
    TS = 3,
    TSX = 4,
    External = 5,
    JSON = 6,
    Deferred = 7,
};

pub const TypeAcquisition = struct {
    enable: bool = false,
    include: ?[][]const u8 = null,
    exclude: ?[][]const u8 = null,
};

pub const WatchOptions = struct {};
