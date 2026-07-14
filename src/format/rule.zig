const std = @import("std");
const ast = @import("../ast/ast.zig");
const kind = @import("../ast/kind.zig");
const context = @import("context.zig");

pub const RuleAction = enum(u32) {
    None = 0,
    StopProcessingSpaceActions = 1 << 0,
    StopProcessingTokenActions = 1 << 1,
    InsertSpace = 1 << 2,
    InsertNewLine = 1 << 3,
    DeleteSpace = 1 << 4,
    DeleteToken = 1 << 5,
    InsertTrailingSemicolon = 1 << 6,
    
    // masks
    // StopAction = StopProcessingSpaceActions | StopProcessingTokenActions
    // ModifySpaceAction = InsertSpace | InsertNewLine | DeleteSpace
    // ModifyTokenAction = DeleteToken | InsertTrailingSemicolon
};

pub const StopAction: u32 = @intFromEnum(RuleAction.StopProcessingSpaceActions) | @intFromEnum(RuleAction.StopProcessingTokenActions);
pub const ModifySpaceAction: u32 = @intFromEnum(RuleAction.InsertSpace) | @intFromEnum(RuleAction.InsertNewLine) | @intFromEnum(RuleAction.DeleteSpace);
pub const ModifyTokenAction: u32 = @intFromEnum(RuleAction.DeleteToken) | @intFromEnum(RuleAction.InsertTrailingSemicolon);

pub const RuleFlags = enum(u32) {
    None = 0,
    CanDeleteNewLines = 1,
};

pub const ContextPredicate = *const fn (ctx: *context.FormattingContext) bool;

pub const TokenRange = struct {
    tokens: []const kind.Kind,
    isSpecific: bool,
};

pub const RuleImpl = struct {
    debugName: []const u8,
    context: []const ContextPredicate,
    action: u32,
    flags: RuleFlags,

    pub fn getAction(self: *const RuleImpl) u32 {
        return self.action;
    }
    
    pub fn getContext(self: *const RuleImpl) []const ContextPredicate {
        return self.context;
    }
    
    pub fn getFlags(self: *const RuleImpl) RuleFlags {
        return self.flags;
    }
};

pub const RuleSpec = struct {
    leftTokenRange: TokenRange,
    rightTokenRange: TokenRange,
    rule: RuleImpl,
};

pub fn createRule(debugName: []const u8, left: TokenRange, right: TokenRange, predicates: []const ContextPredicate, action: u32, flags: RuleFlags) RuleSpec {
    return RuleSpec{
        .leftTokenRange = left,
        .rightTokenRange = right,
        .rule = RuleImpl{
            .debugName = debugName,
            .context = predicates,
            .action = action,
            .flags = flags,
        },
    };
}

pub const anyContext: []const ContextPredicate = &[_]ContextPredicate{};

pub fn toTokenRange(tokens: []const kind.Kind) TokenRange {
    return TokenRange{ .tokens = tokens, .isSpecific = true };
}

pub fn toTokenRangeAny(tokens: []const kind.Kind) TokenRange {
    return TokenRange{ .tokens = tokens, .isSpecific = false };
}

