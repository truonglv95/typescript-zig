const std = @import("std");
const ast = @import("../ast/ast.zig");
const kind = @import("../ast/kind.zig");
const rule = @import("rule.zig");
const rules = @import("rules.zig");
const lsutil = @import("../ls/lsutil/lsutil.zig");
const context = @import("context.zig");
const assert = std.debug.assert;

pub const ruleActionNone = rule.ruleActionNone;
pub const ruleActionModifySpaceAction = rule.ruleActionModifySpaceAction;
pub const ruleActionModifyTokenAction = rule.ruleActionModifyTokenAction;
pub const ruleActionStopProcessingSpaceActions = rule.ruleActionStopProcessingSpaceActions;
pub const ruleActionStopProcessingTokenActions = rule.ruleActionStopProcessingTokenActions;
pub const ruleActionStopAction = rule.ruleActionStopAction;

pub fn getRuleActionExclusion(action: u32) u32 {
    var resultMask: u32 = ruleActionNone;
    if (action & ruleActionStopProcessingSpaceActions != 0) {
        resultMask |= ruleActionModifySpaceAction;
    }
    if (action & ruleActionStopProcessingTokenActions != 0) {
        resultMask |= ruleActionModifyTokenAction;
    }
    if (action & ruleActionModifySpaceAction != 0) {
        resultMask |= ruleActionModifySpaceAction;
    }
    if (action & ruleActionModifyTokenAction != 0) {
        resultMask |= ruleActionModifyTokenAction;
    }
    return resultMask;
}

const mapRowLength: usize = @intFromEnum(kind.Kind.LastToken) + 1;
const maskBitSize: u5 = 5;
const mask: u32 = 0b11111;

pub fn getRuleBucketIndex(row: kind.Kind, column: kind.Kind) usize {
    assert(@intFromEnum(row) <= @intFromEnum(kind.Kind.LastKeyword) and @intFromEnum(column) <= @intFromEnum(kind.Kind.LastKeyword));
    return (@intFromEnum(row) * mapRowLength) + @intFromEnum(column);
}

const RulesPosition = enum(u5) {
    StopRulesSpecific = 0,
    StopRulesAny = maskBitSize * 1,
    ContextRulesSpecific = maskBitSize * 2,
    ContextRulesAny = maskBitSize * 3,
    NoContextRulesSpecific = maskBitSize * 4,
    NoContextRulesAny = maskBitSize * 5,
};

fn getRuleInsertionIndex(indexBitmap: u32, maskPosition: RulesPosition) usize {
    var index: usize = 0;
    var bitmap = indexBitmap;
    var pos: u5 = 0;
    while (pos <= @intFromEnum(maskPosition)) : (pos += maskBitSize) {
        index += bitmap & mask;
        bitmap >>= maskBitSize;
    }
    return index;
}

fn increaseInsertionIndex(indexBitmap: u32, maskPosition: RulesPosition) u32 {
    const value = ((indexBitmap >> @intFromEnum(maskPosition)) & mask) + 1;
    assert((value & mask) == value); // Max 32 rules
    return (indexBitmap & ~(@as(u32, mask) << @intFromEnum(maskPosition))) | (value << @intFromEnum(maskPosition));
}

fn addRule(rulesList: *std.ArrayList(*const rule.RuleImpl), r: *const rule.RuleImpl, specificTokens: bool, constructionState: []u32, rulesBucketIndex: usize) !void {
    var position: RulesPosition = undefined;
    if (r.Action() & ruleActionStopAction != 0) {
        position = if (specificTokens) .StopRulesSpecific else .StopRulesAny;
    } else if (r.Context().len != 0) {
        position = if (specificTokens) .ContextRulesSpecific else .ContextRulesAny;
    } else {
        position = if (specificTokens) .NoContextRulesSpecific else .NoContextRulesAny;
    }

    const state = constructionState[rulesBucketIndex];
    const insertionIndex = getRuleInsertionIndex(state, position);
    
    try rulesList.insert(insertionIndex, r);
    constructionState[rulesBucketIndex] = increaseInsertionIndex(state, position);
}

pub const RulesMap = struct {
    buckets: [][]const *const rule.RuleImpl,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !RulesMap {
        const allRules = rules.getAllRules();
        var m = try allocator.alloc([]const *const rule.RuleImpl, mapRowLength * mapRowLength);
        @memset(m, &[_]*const rule.RuleImpl{});

        const rulesBucketConstructionStateList = try allocator.alloc(u32, m.len);
        defer allocator.free(rulesBucketConstructionStateList);
        @memset(rulesBucketConstructionStateList, 0);

        var tempBuckets = try allocator.alloc(std.ArrayList(*const rule.RuleImpl), m.len);
        defer {
            for (tempBuckets) |b| {
                b.deinit();
            }
            allocator.free(tempBuckets);
        }
        for (tempBuckets) |*b| {
            b.* = std.ArrayList(*const rule.RuleImpl).init(allocator);
        }

        for (allRules) |*ruleSpec| {
            const specificRule = ruleSpec.leftTokenRange.isSpecific and ruleSpec.rightTokenRange.isSpecific;

            for (ruleSpec.leftTokenRange.tokens) |left| {
                for (ruleSpec.rightTokenRange.tokens) |right| {
                    const index = getRuleBucketIndex(left, right);
                    try addRule(&tempBuckets[index], &ruleSpec.rule, specificRule, rulesBucketConstructionStateList, index);
                }
            }
        }

        for (tempBuckets, 0..) |b, i| {
            m[i] = try b.toOwnedSlice();
        }

        return RulesMap{
            .buckets = m,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RulesMap) void {
        for (self.buckets) |b| {
            self.allocator.free(b);
        }
        self.allocator.free(self.buckets);
    }

    pub fn getRules(self: *const RulesMap, allocator: std.mem.Allocator, formattingContext: *context.FormattingContext) ![]const *const rule.RuleImpl {
        const bucket = self.buckets[getRuleBucketIndex(formattingContext.currentTokenSpan.kind, formattingContext.nextTokenSpan.kind)];
        if (bucket.len > 0) {
            var ruleActionMask: u32 = ruleActionNone;
            var matchedRules = std.ArrayList(*const rule.RuleImpl).init(allocator);
            
            outer: for (bucket) |r| {
                const acceptRuleActions = ~getRuleActionExclusion(ruleActionMask);
                if (r.Action() & acceptRuleActions != 0) {
                    for (r.Context()) |p| {
                        if (!p(formattingContext)) {
                            continue :outer;
                        }
                    }
                    try matchedRules.append(r);
                    ruleActionMask |= r.Action();
                }
            }
            return matchedRules.toOwnedSlice();
        }
        return &[_]*const rule.RuleImpl{};
    }
};
