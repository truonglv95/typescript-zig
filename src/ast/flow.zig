const std = @import("std");
const ast_gen = @import("ast_generated.zig");

pub const FlowFlags = struct {
    pub const Unreachable: u32 = 1 << 0;
    pub const Start: u32 = 1 << 1;
    pub const BranchLabel: u32 = 1 << 2;
    pub const LoopLabel: u32 = 1 << 3;
    pub const Assignment: u32 = 1 << 4;
    pub const TrueCondition: u32 = 1 << 5;
    pub const FalseCondition: u32 = 1 << 6;
    pub const SwitchClause: u32 = 1 << 7;
    pub const ArrayMutation: u32 = 1 << 8;
    pub const Call: u32 = 1 << 9;
    pub const ReduceLabel: u32 = 1 << 10;
    pub const Referenced: u32 = 1 << 11;
    pub const Shared: u32 = 1 << 12;
    pub const Label: u32 = BranchLabel | LoopLabel;
    pub const Condition: u32 = TrueCondition | FalseCondition;
};

pub const FlowNodeIndex = u32;
pub const FlowListIndex = u32;

pub const FlowNode = struct {
    flags: u32,
    node: ast_gen.NodeIndex = 0,
    nodeData: FlowNodeData = .None,
    antecedent: FlowNodeIndex = 0,
    antecedents: FlowListIndex = 0,
};

pub const FlowNodeData = union(enum) {
    None: void,
    SwitchClauseData: struct {
        switchStatement: ast_gen.NodeIndex,
        clauseStart: i32,
        clauseEnd: i32,
    },
    ReduceLabelData: struct {
        target: FlowNodeIndex,
        antecedents: FlowListIndex,
    },
};

pub const FlowList = struct {
    flow: FlowNodeIndex = 0,
    next: FlowListIndex = 0,
};
