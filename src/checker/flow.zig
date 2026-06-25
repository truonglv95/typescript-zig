const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const flow_ast = @import("../ast/flow.zig");
const binder = @import("../binder/binder.zig");
const types = @import("types.zig");
const Checker = @import("checker.zig").Checker;

pub const FlowType = struct {
    typeIndex: types.TypeIndex = 0,
    incomplete: bool = false,

    pub fn isNil(self: FlowType) bool {
        return self.typeIndex == 0;
    }
};

pub const SharedFlow = struct {
    flow: flow_ast.FlowNodeIndex,
    flowType: FlowType,
};

pub const FlowLoopKey = struct {
    flowNode: flow_ast.FlowNodeIndex,
    refKey: u64,
};

pub const FlowLoopInfo = struct {
    key: FlowLoopKey,
    typesStart: usize,
    typesEnd: usize,
};

pub const FlowState = struct {
    reference: ast_gen.NodeIndex = 0,
    declaredType: types.TypeIndex = 0,
    initialType: types.TypeIndex = 0,
    flowContainer: ast_gen.NodeIndex = 0,
    refKey: u64 = 0,
    depth: usize = 0,
    sharedFlowStart: usize = 0,
    reduceLabels: std.ArrayListUnmanaged(flow_ast.FlowNodeData) = .empty,
    next: ?*FlowState = null,
};

// =========================================================================
// Checker Extension Functions
// =========================================================================

pub fn newFlowType(c: *Checker, t: types.TypeIndex, incomplete: bool) !FlowType {
    const actual_t = t;
    if (incomplete) {
        const type_flags = if (t != 0 and t < c.typesList.items.len) c.typesList.items[t].flags else 0;
        if ((type_flags & types.TypeFlags.Never) != 0) {
            // t = c.silentNeverType -> assuming we have it, or fallback
            // actual_t = c.silentNeverTypeIndex; 
            // TODO: define silentNeverType
        }
    }
    return FlowType{ .typeIndex = actual_t, .incomplete = incomplete };
}

pub fn getFlowState(c: *Checker) *FlowState {
    if (c.freeFlowState) |f| {
        c.freeFlowState = f.next;
        f.reference = 0;
        f.declaredType = 0;
        f.initialType = 0;
        f.flowContainer = 0;
        f.refKey = 0;
        f.depth = 0;
        f.sharedFlowStart = 0;
        f.reduceLabels.clearRetainingCapacity();
        f.next = null;
        return f;
    }
    const f = c.allocator.create(FlowState) catch @panic("OOM");
    f.* = .{};
    return f;
}

pub fn putFlowState(c: *Checker, f: *FlowState) void {
    f.reduceLabels.clearRetainingCapacity();
    f.next = c.freeFlowState;
    c.freeFlowState = f;
}

pub fn getFlowNodeOfNode(c: *Checker, nodeIndex: ast_gen.NodeIndex) flow_ast.FlowNodeIndex {
    return c.nodeFlowNodes.get(nodeIndex) orelse 0;
}

pub fn getFlowTypeOfReference(c: *Checker, reference: ast_gen.NodeIndex, declaredType: types.TypeIndex) types.TypeIndex {
    return getFlowTypeOfReferenceEx(c, reference, declaredType, declaredType, 0, 0);
}

pub fn getFlowTypeOfReferenceEx(
    c: *Checker,
    reference: ast_gen.NodeIndex,
    declaredType: types.TypeIndex,
    initialType: types.TypeIndex,
    flowContainer: ast_gen.NodeIndex,
    flowNodeParam: flow_ast.FlowNodeIndex,
) types.TypeIndex {
    if (c.flowAnalysisDisabled) {
        return c.getUnknownType() catch 0; // TODO: return errorType
    }
    
    var flowNode = flowNodeParam;
    if (flowNode == 0) {
        flowNode = getFlowNodeOfNode(c, reference);
        if (flowNode == 0) {
            return declaredType;
        }
    }
    
    var f = getFlowState(c);
    f.reference = reference;
    f.declaredType = declaredType;
    f.initialType = if (initialType != 0) initialType else declaredType;
    f.flowContainer = flowContainer;
    f.sharedFlowStart = c.sharedFlows.items.len;
    
    c.flowInvocationCount += 1;
    
    const evolvedType = getTypeAtFlowNode(c, f, flowNode).typeIndex;
    
    c.sharedFlows.shrinkRetainingCapacity(f.sharedFlowStart);
    putFlowState(c, f);
    
    // Finalize type
    // TODO: implement isEvolvingArrayOperationTarget, finalizeEvolvingArrayType, etc.
    return evolvedType;
}

pub fn getTypeAtFlowNode(c: *Checker, f: *FlowState, flowParam: flow_ast.FlowNodeIndex) FlowType {
    if (f.depth == 2000) {
        c.flowAnalysisDisabled = true;
        // reportFlowControlError(c, f.reference);
        return FlowType{ .typeIndex = c.getUnknownType() catch 0 }; // TODO: errorType
    }
    f.depth += 1;
    defer f.depth -= 1;
    
    var flow = flowParam;
    var sharedFlow: flow_ast.FlowNodeIndex = 0;
    
    while (true) {
        if (flow == 0) break;
        const flowNode = c.binder.flowNodes.items[flow];
        const flags = flowNode.flags;
        
        if ((flags & flow_ast.FlowFlags.Shared) != 0) {
            var i: usize = f.sharedFlowStart;
            while (i < c.sharedFlows.items.len) : (i += 1) {
                if (c.sharedFlows.items[i].flow == flow) {
                    return c.sharedFlows.items[i].flowType;
                }
            }
            sharedFlow = flow;
        }
        
        var t = FlowType{};
        
        if ((flags & flow_ast.FlowFlags.Assignment) != 0) {
            t = getTypeAtFlowAssignment(c, f, flow);
            if (t.isNil()) {
                flow = flowNode.antecedent;
                continue;
            }
        } else if ((flags & flow_ast.FlowFlags.Call) != 0) {
            t = getTypeAtFlowCall(c, f, flow);
            if (t.isNil()) {
                flow = flowNode.antecedent;
                continue;
            }
        } else if ((flags & flow_ast.FlowFlags.Condition) != 0) {
            t = getTypeAtFlowCondition(c, f, flow);
        } else if ((flags & flow_ast.FlowFlags.SwitchClause) != 0) {
            t = getTypeAtSwitchClause(c, f, flow);
        } else if ((flags & flow_ast.FlowFlags.BranchLabel) != 0) {
            const antecedents = getBranchLabelAntecedents(c, flow, f.reduceLabels.items);
            if (antecedents == 0 or c.binder.flowLists.items[antecedents].next == 0) {
                flow = if (antecedents != 0) c.binder.flowLists.items[antecedents].flow else flowNode.antecedent;
                continue;
            }
            t = getTypeAtFlowBranchLabel(c, f, flow, antecedents);
        } else if ((flags & flow_ast.FlowFlags.LoopLabel) != 0) {
            if (flowNode.antecedents == 0 or c.binder.flowLists.items[flowNode.antecedents].next == 0) {
                flow = if (flowNode.antecedents != 0) c.binder.flowLists.items[flowNode.antecedents].flow else flowNode.antecedent;
                continue;
            }
            t = getTypeAtFlowLoopLabel(c, f, flow);
        } else if ((flags & flow_ast.FlowFlags.ArrayMutation) != 0) {
            t = getTypeAtFlowArrayMutation(c, f, flow);
            if (t.isNil()) {
                flow = flowNode.antecedent;
                continue;
            }
        } else if ((flags & flow_ast.FlowFlags.ReduceLabel) != 0) {
            // ...
            flow = flowNode.antecedent;
            continue;
        } else if ((flags & flow_ast.FlowFlags.Start) != 0) {
            t = FlowType{ .typeIndex = f.initialType };
        } else {
            t = FlowType{ .typeIndex = f.declaredType }; // fallback
        }
        
        if (sharedFlow != 0) {
            c.sharedFlows.append(c.allocator, .{
                .flow = sharedFlow,
                .flowType = t,
            }) catch @panic("OOM");
        }
        return t;
    }
    
    return FlowType{};
}

// --- Stubs for Checker methods needed by Flow ---
fn isMatchingReference(c: *Checker, source: ast.NodeIndex, target: ast.NodeIndex) bool {
    _ = c; _ = source; _ = target; return false;
}
fn getAssignmentTargetKind(node: ast.NodeIndex) u32 {
    _ = node; return 0; // AssignmentKindSimple
}
fn isEmptyArrayAssignment(c: *Checker, node: ast.NodeIndex) bool {
    _ = c; _ = node; return false;
}
fn getEvolvingArrayType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c; return t;
}
fn getWidenedLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c; return t;
}
fn getInitialOrAssignedType(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex) types.TypeIndex {
    _ = c; _ = f; _ = flow; return 0;
}
fn isTypeAssignableTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    _ = c; _ = source; _ = target; return true;
}
fn isInCompoundLikeAssignment(node: ast.NodeIndex) bool {
    _ = node; return false;
}
fn getBaseTypeOfLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c; return t;
}
fn getAssignmentReducedType(c: *Checker, t: types.TypeIndex, initialOrAssigned: types.TypeIndex) types.TypeIndex {
    _ = c; _ = initialOrAssigned; return t;
}
fn containsMatchingReference(c: *Checker, source: ast.NodeIndex, target: ast.NodeIndex) bool {
    _ = c; _ = source; _ = target; return false;
}

fn optionalChainContainsReference(c: *Checker, expr: ast.NodeIndex, ref: ast.NodeIndex) bool {
    _ = c; _ = expr; _ = ref; return false;
}

fn finalizeEvolvingArrayType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c; return t;
}
fn getNonNullableTypeIfNeeded(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c; return t;
}
fn isExpressionOfOptionalChainRoot(c: *Checker, expr: ast_gen.NodeIndex) bool {
    _ = c; _ = expr; return false;
}
fn getParentNode(c: *Checker, expr: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = c; _ = expr; return 0;
}
fn getTypeWithFacts(c: *Checker, t: types.TypeIndex, facts: u32) types.TypeIndex {
    _ = c; _ = facts; return t;
}

fn narrowTypeByOptionality(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumePresent: bool) types.TypeIndex {
    if (isMatchingReference(c, f.reference, expr)) {
        return getAdjustedTypeWithFacts(c, t, if (assumePresent) types.TypeFacts.NEUndefinedOrNull else types.TypeFacts.EQUndefinedOrNull);
    }
    if (getDiscriminantPropertyAccess(c, f, expr, t)) |access| {
        return narrowTypeByDiscriminant(c, t, access, assumePresent); // note: narrowTypeByDiscriminant needs a callback in Go, here we stub with assumePresent flag
    }
    return t;
}
fn isConstantVariable(c: *Checker, symbol: ast_gen.SymbolIndex) bool {
    _ = c; _ = symbol; return false;
}
fn getResolvedSymbol(c: *Checker, expr: ast_gen.NodeIndex) ast_gen.SymbolIndex {
    _ = c; _ = expr; return 0;
}
fn isConstantReference(c: *Checker, expr: ast_gen.NodeIndex) bool {
    _ = c; _ = expr; return false;
}
fn narrowTypeByCallExpression(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    _ = c; _ = f; _ = expr; _ = assumeTrue; return t;
}
fn narrowTypeByBinaryExpression(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    _ = c; _ = f; _ = expr; _ = assumeTrue; return t;
}
fn getAdjustedTypeWithFacts(c: *Checker, t: types.TypeIndex, facts: u32) types.TypeIndex {
    _ = c; _ = facts; return t;
}

fn narrowTypeByDiscriminant(c: *Checker, t: types.TypeIndex, access: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    _ = c; _ = access; _ = assumeTrue; return t; // function pointer not possible easily, passing assumeTrue for stub
}
// -----------------------

pub fn narrowType(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    if (isExpressionOfOptionalChainRoot(c, expr)) {
        return narrowTypeByOptionality(c, f, t, expr, assumeTrue);
    }
    
    const parent = getParentNode(c, expr);
    if (parent != 0 and std.meta.activeTag(c.binder.ast.getNode(parent)) == .BinaryExpression) {
        const binExpr = c.binder.ast.getNode(parent).BinaryExpression;
        const opKind = std.meta.activeTag(c.binder.ast.getNode(binExpr.OperatorToken));
        if ((opKind == .QuestionQuestionToken or opKind == .QuestionQuestionEqualsToken) and binExpr.Left == expr) {
            return narrowTypeByOptionality(c, f, t, expr, assumeTrue);
        }
    }
    
    const exprKind = std.meta.activeTag(c.binder.ast.getNode(expr));
    switch (exprKind) {
        .Identifier => {
            if (!isMatchingReference(c, f.reference, expr) and c.inlineLevel < 5) {
                const symbol = getResolvedSymbol(c, expr);
                if (isConstantVariable(c, symbol)) {
                    // stub getDeclaration
                    const decl: ast_gen.NodeIndex = 0; 
                    if (decl != 0 and std.meta.activeTag(c.binder.ast.getNode(decl)) == .VariableDeclaration) {
                        // stub type and initializer check
                        if (isConstantReference(c, f.reference)) {
                            c.inlineLevel += 1;
                            const declInit = 0; // stub
                            const result = narrowType(c, f, t, declInit, assumeTrue);
                            c.inlineLevel -= 1;
                            return result;
                        }
                    }
                }
            }
            return narrowTypeByTruthiness(c, f, t, expr, assumeTrue);
        },
        .ThisKeyword, .SuperKeyword, .PropertyAccessExpression, .ElementAccessExpression => {
            return narrowTypeByTruthiness(c, f, t, expr, assumeTrue);
        },
        .CallExpression => {
            return narrowTypeByCallExpression(c, f, t, expr, assumeTrue);
        },
        .ParenthesizedExpression => {
            return narrowType(c, f, t, c.binder.ast.getNode(expr).ParenthesizedExpression.Expression, assumeTrue);
        },
        .NonNullExpression => {
            return narrowType(c, f, t, c.binder.ast.getNode(expr).NonNullExpression.Expression, assumeTrue);
        },
        .SatisfiesExpression => {
            return narrowType(c, f, t, c.binder.ast.getNode(expr).SatisfiesExpression.Expression, assumeTrue);
        },
        .BinaryExpression => {
            return narrowTypeByBinaryExpression(c, f, t, expr, assumeTrue);
        },
        .PrefixUnaryExpression => {
            const prefix = c.binder.ast.getNode(expr).PrefixUnaryExpression;
            if (prefix.Operator == 52) { // ExclamationToken TODO: get actual value
                return narrowType(c, f, t, prefix.Operand, !assumeTrue);
            }
        },
        else => {},
    }
    return t;
}

pub fn narrowTypeByTruthiness(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    if (isMatchingReference(c, f.reference, expr)) {
        return getAdjustedTypeWithFacts(c, t, if (assumeTrue) types.TypeFacts.Truthy else types.TypeFacts.Falsy);
    }
    if (c.strictNullChecks and assumeTrue and optionalChainContainsReference(c, expr, f.reference)) {
        return getAdjustedTypeWithFacts(c, t, types.TypeFacts.NEUndefinedOrNull);
    }
    if (getDiscriminantPropertyAccess(c, f, expr, t)) |access| {
        return narrowTypeByDiscriminant(c, t, access, assumeTrue);
    }
    return t;
}

pub fn getTypeAtFlowCondition(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex) FlowType {
    const flowNode = c.binder.flowNodes.items[flow];
    const flowType = getTypeAtFlowNode(c, f, flowNode.antecedent);
    
    if (flowType.typeIndex != 0 and flowType.typeIndex < c.typesList.items.len) {
        const flags = c.typesList.items[flowType.typeIndex].flags;
        if ((flags & types.TypeFlags.Never) != 0) {
            return flowType;
        }
    }
    
    const assumeTrue = (flowNode.flags & flow_ast.FlowFlags.TrueCondition) != 0;
    const nonEvolvingType = finalizeEvolvingArrayType(c, flowType.typeIndex);
    const narrowedType = narrowType(c, f, nonEvolvingType, flowNode.node, assumeTrue);
    if (narrowedType == nonEvolvingType) {
        return flowType;
    }
    return .{ .typeIndex = narrowedType, .incomplete = flowType.incomplete };
}

// --- getTypeAtSwitchClause Dependencies ---
fn getSwitchClauseTypes(c: *Checker, switchStatement: ast_gen.NodeIndex) []const types.TypeIndex {
    _ = c; _ = switchStatement; return &[_]types.TypeIndex{};
}
fn getUnionType(c: *Checker, typesArr: []const types.TypeIndex) types.TypeIndex {
    _ = c; _ = typesArr; return 0;
}
fn filterType(c: *Checker, t: types.TypeIndex, comptime filterFn: anytype, ctx: anytype) types.TypeIndex {
    _ = c; _ = filterFn; _ = ctx; return t;
}
fn areTypesComparable(c: *Checker, t1: types.TypeIndex, t2: types.TypeIndex) bool {
    _ = c; _ = t1; _ = t2; return false;
}
fn replacePrimitivesWithLiterals(c: *Checker, t: types.TypeIndex, discriminantType: types.TypeIndex) types.TypeIndex {
    _ = c; _ = discriminantType; return t;
}
fn isUnitLikeType(c: *Checker, t: types.TypeIndex) bool {
    _ = c; _ = t; return false;
}
fn extractUnitType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c; return t;
}
fn getRegularTypeOfLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    _ = c; return t;
}
fn isUnitType(c: *Checker, t: types.TypeIndex) bool {
    _ = c; _ = t; return false;
}
// ------------------------------------------

fn narrowTypeBySwitchOnDiscriminant(c: *Checker, t: types.TypeIndex, data: anytype) types.TypeIndex {
    const switchTypes = getSwitchClauseTypes(c, data.switchStatement);
    if (switchTypes.len == 0) return t;

    const clauseTypes = switchTypes[@intCast(data.clauseStart)..@intCast(data.clauseEnd)];
    var hasDefaultClause = data.clauseStart == data.clauseEnd;
    for (clauseTypes) |ct| {
        if (ct == c.neverTypeIndex.?) {
            hasDefaultClause = true;
            break;
        }
    }

    const tflags = c.typesList.items[t].flags;
    if ((tflags & types.TypeFlags.Unknown) != 0 and !hasDefaultClause) {
        var groundClauseTypes: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
        defer if (groundClauseTypes.capacity > 0) groundClauseTypes.deinit(c.allocator);
        
        for (clauseTypes, 0..) |s, i| {
            const sflags = c.typesList.items[s].flags;
            if ((sflags & (types.TypeFlags.Primitive | types.TypeFlags.NonPrimitive)) != 0) {
                if (groundClauseTypes.capacity > 0) {
                    groundClauseTypes.append(c.allocator, s) catch unreachable;
                }
            } else if ((sflags & types.TypeFlags.Object) != 0) {
                if (groundClauseTypes.capacity == 0) {
                    groundClauseTypes.appendSlice(c.allocator, clauseTypes[0..i]) catch unreachable;
                }
                groundClauseTypes.append(c.allocator, c.nonPrimitiveTypeIndex.?) catch unreachable;
            } else {
                return t;
            }
        }
        return getUnionType(c, if (groundClauseTypes.capacity == 0) clauseTypes else groundClauseTypes.items);
    }

    const discriminantType = getUnionType(c, clauseTypes);
    var caseType: types.TypeIndex = 0;
    if ((c.typesList.items[discriminantType].flags & types.TypeFlags.Never) != 0) {
        caseType = c.neverTypeIndex.?;
    } else {
        // Stub for filterType usage:
        const filtered = filterType(c, t, areTypesComparable, discriminantType);
        caseType = replacePrimitivesWithLiterals(c, filtered, discriminantType);
    }

    if (!hasDefaultClause) return caseType;

    // Stub for defaultType
    const defaultType = t; // we need a complex closure to do the full logic, let's keep it simple for now
    
    if ((c.typesList.items[caseType].flags & types.TypeFlags.Never) != 0) {
        return defaultType;
    }
    return getUnionType(c, &[_]types.TypeIndex{caseType, defaultType});
}
fn narrowTypeBySwitchOnTypeOf(c: *Checker, t: types.TypeIndex, data: anytype) types.TypeIndex {
    _ = c; _ = data; return t;
}
fn narrowTypeBySwitchOnTrue(c: *Checker, f: *FlowState, t: types.TypeIndex, data: anytype) types.TypeIndex {
    _ = c; _ = f; _ = data; return t;
}
fn narrowTypeBySwitchOptionalChainContainment(c: *Checker, t: types.TypeIndex, data: anytype, predicateId: u32) types.TypeIndex {
    _ = c; _ = data; _ = predicateId; return t;
}
fn getDiscriminantPropertyAccess(c: *Checker, f: *FlowState, expr: ast.NodeIndex, t: types.TypeIndex) ?ast.NodeIndex {
    _ = c; _ = f; _ = expr; _ = t; return null;
}
fn narrowTypeBySwitchOnDiscriminantProperty(c: *Checker, t: types.TypeIndex, access: ast.NodeIndex, data: anytype) types.TypeIndex {
    _ = c; _ = access; _ = data; return t;
}
fn skipParentheses(c: *Checker, expr: ast.NodeIndex) ast.NodeIndex {
    _ = c; return expr;
}
// ------------------------------------

pub fn getTypeAtSwitchClause(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex) FlowType {
    const flowNode = c.binder.flowNodes.items[flow];
    const data = flowNode.nodeData.SwitchClauseData;
    const expr = skipParentheses(c, c.binder.ast.getNode(data.switchStatement).SwitchStatement.Expression);
    const flowType = getTypeAtFlowNode(c, f, flowNode.antecedent);
    var t = flowType.typeIndex;
    const exprNode = c.binder.ast.getNode(expr);
    const exprKind = std.meta.activeTag(exprNode);

    if (isMatchingReference(c, f.reference, expr)) {
        t = narrowTypeBySwitchOnDiscriminant(c, t, data);
    } else if (exprKind == .TypeOfExpression and isMatchingReference(c, f.reference, exprNode.TypeOfExpression.Expression)) {
        t = narrowTypeBySwitchOnTypeOf(c, t, data);
    } else if (exprKind == .TrueKeyword) {
        t = narrowTypeBySwitchOnTrue(c, f, t, data);
    } else {
        if (c.strictNullChecks) {
            if (optionalChainContainsReference(c, expr, f.reference)) {
                t = narrowTypeBySwitchOptionalChainContainment(c, t, data, 1); // 1 = undefined/never check
            } else if (exprKind == .TypeOfExpression and optionalChainContainsReference(c, exprNode.TypeOfExpression.Expression, f.reference)) {
                t = narrowTypeBySwitchOptionalChainContainment(c, t, data, 2); // 2 = undefined string check
            }
        }
        if (getDiscriminantPropertyAccess(c, f, expr, t)) |access| {
            t = narrowTypeBySwitchOnDiscriminantProperty(c, t, access, data);
        }
    }
    return .{ .typeIndex = t, .incomplete = flowType.incomplete };
}
// --- getTypeAtFlowBranchLabel Stubs ---
fn isTypeSubsetOf(c: *Checker, t: types.TypeIndex, initialType: types.TypeIndex) bool {
    _ = c; _ = t; _ = initialType; return true;
}
fn isExhaustiveSwitchStatement(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c; _ = node; return false;
}
fn getUnionOrEvolvingArrayType(c: *Checker, f: *FlowState, typesArray: []const types.TypeIndex, subtypeReduction: u32) types.TypeIndex {
    _ = c; _ = f; _ = subtypeReduction;
    if (typesArray.len > 0) return typesArray[0];
    return 0; // fallback
}
// -------------------------------------

pub fn getTypeAtFlowBranchLabel(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex, antecedents: flow_ast.FlowListIndex) FlowType {
    _ = flow;
    const antecedentStart = c.antecedentTypes.items.len;
    var subtypeReduction = false;
    var seenIncomplete = false;
    var bypassFlow: ?flow_ast.FlowNodeIndex = null;

    var listIndex = antecedents;
    while (listIndex != 0) {
        const list = c.binder.flowLists.items[listIndex];
        const antecedent = list.flow;
        const antNode = c.binder.flowNodes.items[antecedent];

        if (bypassFlow == null and (antNode.flags & flow_ast.FlowFlags.SwitchClause) != 0) {
            const data = antNode.nodeData.SwitchClauseData;
            if (data.clauseStart == data.clauseEnd) {
                bypassFlow = antecedent;
                listIndex = list.next;
                continue;
            }
        }

        const flowType = getTypeAtFlowNode(c, f, antecedent);
        if (flowType.typeIndex == f.declaredType and f.declaredType == f.initialType) {
            c.antecedentTypes.shrinkRetainingCapacity(antecedentStart);
            return .{ .typeIndex = flowType.typeIndex };
        }

        if (std.mem.indexOfScalar(types.TypeIndex, c.antecedentTypes.items[antecedentStart..], flowType.typeIndex) == null) {
            c.antecedentTypes.append(c.allocator, flowType.typeIndex) catch unreachable;
        }

        if (!isTypeSubsetOf(c, flowType.typeIndex, f.initialType)) {
            subtypeReduction = true;
        }
        if (flowType.incomplete) {
            seenIncomplete = true;
        }
        listIndex = list.next;
    }

    if (bypassFlow) |bf| {
        const bfNode = c.binder.flowNodes.items[bf];
        const flowType = getTypeAtFlowNode(c, f, bf);

        var isNever = false;
        if (flowType.typeIndex != 0 and flowType.typeIndex < c.typesList.items.len) {
            if ((c.typesList.items[flowType.typeIndex].flags & types.TypeFlags.Never) != 0) {
                isNever = true;
            }
        }

        const contains = std.mem.indexOfScalar(types.TypeIndex, c.antecedentTypes.items[antecedentStart..], flowType.typeIndex) != null;

        if (!isNever and !contains and !isExhaustiveSwitchStatement(c, bfNode.nodeData.SwitchClauseData.switchStatement)) {
            if (flowType.typeIndex == f.declaredType and f.declaredType == f.initialType) {
                c.antecedentTypes.shrinkRetainingCapacity(antecedentStart);
                return .{ .typeIndex = flowType.typeIndex };
            }
            c.antecedentTypes.append(c.allocator, flowType.typeIndex) catch unreachable;
            if (!isTypeSubsetOf(c, flowType.typeIndex, f.initialType)) {
                subtypeReduction = true;
            }
            if (flowType.incomplete) {
                seenIncomplete = true;
            }
        }
    }

    const unionReduction: u32 = if (subtypeReduction) 1 else 0; // 1=Subtype, 0=Literal
    const combinedType = getUnionOrEvolvingArrayType(c, f, c.antecedentTypes.items[antecedentStart..], unionReduction);

    c.antecedentTypes.shrinkRetainingCapacity(antecedentStart);
    return .{ .typeIndex = combinedType, .incomplete = seenIncomplete };
}
fn getFlowReferenceKey(c: *Checker, f: *FlowState) u64 {
    _ = c; _ = f; return 1; // stub nonDottedNameCacheKey? Wait, let's just return 1
}

pub fn getTypeAtFlowLoopLabel(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex) FlowType {
    if (f.refKey == 0) {
        f.refKey = getFlowReferenceKey(c, f);
    }
    const nonDottedNameCacheKey = std.math.maxInt(u64); // TODO: defined constant?
    if (f.refKey == nonDottedNameCacheKey) {
        return .{ .typeIndex = f.declaredType };
    }
    
    const key = FlowLoopKey{ .flowNode = flow, .refKey = f.refKey };
    if (c.flowLoopCache.get(key)) |cached| {
        return .{ .typeIndex = cached };
    }
    
    for (c.flowLoopStack.items) |loopInfo| {
        if (std.meta.eql(loopInfo.key, key) and loopInfo.typesStart < loopInfo.typesEnd) {
            const typesArray = c.flowLoopTypes.items[loopInfo.typesStart..loopInfo.typesEnd];
            return .{ .typeIndex = getUnionOrEvolvingArrayType(c, f, typesArray, 0), .incomplete = true }; // 0 = Literal
        }
    }
    
    const antecedentTypesStart = c.flowLoopTypes.items.len;
    var subtypeReduction = false;
    var firstAntecedentType: ?FlowType = null;
    
    const flowNode = c.binder.flowNodes.items[flow];
    var listIndex = flowNode.antecedents;
    
    while (listIndex != 0) {
        const list = c.binder.flowLists.items[listIndex];
        var flowType: FlowType = undefined;
        
        if (firstAntecedentType == null) {
            firstAntecedentType = getTypeAtFlowNode(c, f, list.flow);
            flowType = firstAntecedentType.?;
        } else {
            const info = FlowLoopInfo{
                .key = key,
                .typesStart = antecedentTypesStart,
                .typesEnd = c.flowLoopTypes.items.len,
            };
            c.flowLoopStack.append(c.allocator, info) catch unreachable;
            // Temporarily ignore flowTypeCache if any? Go version saves flowTypeCache to nil
            flowType = getTypeAtFlowNode(c, f, list.flow);
            _ = c.flowLoopStack.pop();
            
            if (c.flowLoopCache.get(key)) |cached| {
                c.flowLoopTypes.shrinkRetainingCapacity(antecedentTypesStart);
                return .{ .typeIndex = cached };
            }
        }
        
        const currentTypes = c.flowLoopTypes.items[antecedentTypesStart..];
        if (std.mem.indexOfScalar(types.TypeIndex, currentTypes, flowType.typeIndex) == null) {
            c.flowLoopTypes.append(c.allocator, flowType.typeIndex) catch unreachable;
        }
        
        if (!isTypeSubsetOf(c, flowType.typeIndex, f.initialType)) {
            subtypeReduction = true;
        }
        if (flowType.typeIndex == f.declaredType) {
            break;
        }
        
        listIndex = list.next;
    }
    
    const unionReduction: u32 = if (subtypeReduction) 1 else 0;
    const result = getUnionOrEvolvingArrayType(c, f, c.flowLoopTypes.items[antecedentTypesStart..], unionReduction);
    
    if (firstAntecedentType != null and firstAntecedentType.?.incomplete) {
        c.flowLoopTypes.shrinkRetainingCapacity(antecedentTypesStart);
        return .{ .typeIndex = result, .incomplete = true };
    }
    
    c.flowLoopCache.put(c.allocator, key, result) catch unreachable;
    c.flowLoopTypes.shrinkRetainingCapacity(antecedentTypesStart);
    return .{ .typeIndex = result };
}
// --- getTypeAtFlowArrayMutation Stubs ---
fn getReferenceCandidate(c: *Checker, expr: ast_gen.NodeIndex) ast_gen.NodeIndex {
    _ = c; return expr;
}
fn addEvolvingArrayElementType(c: *Checker, evolvedType: types.TypeIndex, arg: ast_gen.NodeIndex) types.TypeIndex {
    _ = c; _ = arg; return evolvedType;
}
fn getContextFreeTypeOfExpression(c: *Checker, expr: ast_gen.NodeIndex) types.TypeIndex {
    _ = c; _ = expr; return 0;
}
fn isTypeAssignableToKind(c: *Checker, t: types.TypeIndex, kindflags: u32) bool {
    _ = c; _ = t; _ = kindflags; return false;
}
// ----------------------------------------

pub fn getTypeAtFlowArrayMutation(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex) FlowType {
    if ((c.autoTypeIndex != null and f.declaredType == c.autoTypeIndex.?) or 
        (c.autoArrayTypeIndex != null and f.declaredType == c.autoArrayTypeIndex.?)) {
        const flowNode = c.binder.flowNodes.items[flow];
        const node = flowNode.node;
        const nodeKind = std.meta.activeTag(c.binder.ast.getNode(node));
        
        var expr: ast_gen.NodeIndex = 0;
        if (nodeKind == .CallExpression) {
            expr = c.binder.ast.getNode(c.binder.ast.getNode(node).CallExpression.Expression).PropertyAccessExpression.Expression;
        } else {
            expr = c.binder.ast.getNode(c.binder.ast.getNode(node).BinaryExpression.Left).ElementAccessExpression.Expression;
        }
        
        if (isMatchingReference(c, f.reference, getReferenceCandidate(c, expr))) {
            const flowType = getTypeAtFlowNode(c, f, flowNode.antecedent);
            
            if (flowType.typeIndex != 0 and flowType.typeIndex < c.typesList.items.len) {
                const objectflags = c.typesList.items[flowType.typeIndex].objectFlags;
                if ((objectflags & types.ObjectFlags.EvolvingArray) != 0) {
                    var evolvedType = flowType.typeIndex;
                    
                    if (nodeKind == .CallExpression) {
                        const args = c.binder.ast.getNodeList(node); // stub, get args list
                        for (args) |arg| {
                            evolvedType = addEvolvingArrayElementType(c, evolvedType, arg);
                        }
                    } else {
                        const left = c.binder.ast.getNode(node).BinaryExpression.Left;
                        const argExpr = c.binder.ast.getNode(left).ElementAccessExpression.ArgumentExpression;
                        const indexType = getContextFreeTypeOfExpression(c, argExpr);
                        if (isTypeAssignableToKind(c, indexType, types.TypeFlags.NumberLike)) {
                            const right = c.binder.ast.getNode(node).BinaryExpression.Right;
                            evolvedType = addEvolvingArrayElementType(c, evolvedType, right);
                        }
                    }
                    return .{ .typeIndex = evolvedType, .incomplete = flowType.incomplete };
                }
            }
            return flowType;
        }
    }
    return .{};
}
// ----------------------------------------------

// --- getTypeAtFlowCall Stubs ---
fn getEffectsSignature(c: *Checker, node: ast.NodeIndex) ?types.SignatureIndex {
    _ = c; _ = node; return null;
}
fn getTypePredicateOfSignature(c: *Checker, signature: types.SignatureIndex) ?*const types.TypePredicate {
    _ = c; _ = signature; return null;
}
fn narrowTypeByTypePredicate(c: *Checker, f: *FlowState, t: types.TypeIndex, predicate: *const types.TypePredicate, callExpression: ast.NodeIndex, assumeTrue: bool) types.TypeIndex {
    _ = c; _ = f; _ = predicate; _ = callExpression; _ = assumeTrue; return t;
}
fn narrowTypeByAssertion(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast.NodeIndex) types.TypeIndex {
    _ = c; _ = f; _ = expr; return t;
}
fn getReturnTypeOfSignature(c: *Checker, signature: types.SignatureIndex) types.TypeIndex {
    _ = c; _ = signature; return 0;
}
// --------------------------------

pub fn getTypeAtFlowCall(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex) FlowType {
    const flowNode = c.binder.flowNodes.items[flow];
    const node = flowNode.node;
    if (getEffectsSignature(c, node)) |signature| {
        if (getTypePredicateOfSignature(c, signature)) |predicate| {
            if (predicate.kind == .AssertsThis or predicate.kind == .AssertsIdentifier) {
                const flowType = getTypeAtFlowNode(c, f, flowNode.antecedent);
                const t = finalizeEvolvingArrayType(c, flowType.typeIndex);
                var narrowedType: types.TypeIndex = t;

                if (predicate.t != null) {
                    narrowedType = narrowTypeByTypePredicate(c, f, t, predicate, node, true);
                } else if (predicate.kind == .AssertsIdentifier and predicate.parameterIndex >= 0) {
                    const callNodeArgs = c.binder.ast.getNodeList(node); // TODO: get real arguments
                    if (predicate.parameterIndex < callNodeArgs.len) {
                        narrowedType = narrowTypeByAssertion(c, f, t, callNodeArgs[@intCast(predicate.parameterIndex)]);
                    }
                }

                if (narrowedType == t) {
                    return flowType;
                }
                return .{ .typeIndex = narrowedType, .incomplete = flowType.incomplete };
            }
        }
        const retTypeIdx = getReturnTypeOfSignature(c, signature);
        if (retTypeIdx != 0 and retTypeIdx < c.typesList.items.len) {
            const retTypeflags = c.typesList.items[retTypeIdx].flags;
            if ((retTypeflags & types.TypeFlags.Never) != 0) {
                return .{ .typeIndex = c.getNeverType() catch 0 };
            }
        }
    }
    return .{};
}

pub fn getTypeAtFlowAssignment(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex) FlowType {
    const flowNode = c.binder.flowNodes.items[flow];
    const node = flowNode.node;

    if (isMatchingReference(c, f.reference, node)) {
        if (!isReachableFlowNode(c, flow)) {
            return .{ .typeIndex = c.getNeverType() catch 0 }; // unreachableNeverType
        }
        if (getAssignmentTargetKind(node) == 1) { // Compound
            const flowType = getTypeAtFlowNode(c, f, flowNode.antecedent);
            return .{ .typeIndex = getBaseTypeOfLiteralType(c, flowType.typeIndex), .incomplete = flowType.incomplete };
        }
        // TODO: autoType and autoArrayType check
        // if (f.declaredType == c.autoType or f.declaredType == c.autoArrayType) { ... }
        
        var t = f.declaredType;
        if (isInCompoundLikeAssignment(node)) {
            t = getBaseTypeOfLiteralType(c, t);
        }
        if (t != 0 and t < c.typesList.items.len) {
            const declTypeflags = c.typesList.items[t].flags;
            if ((declTypeflags & types.TypeFlags.Union) != 0) {
                return .{ .typeIndex = getAssignmentReducedType(c, t, getInitialOrAssignedType(c, f, flow)) };
            }
        }
        return .{ .typeIndex = t };
    }

    if (containsMatchingReference(c, f.reference, node)) {
        if (!isReachableFlowNode(c, flow)) {
            return .{ .typeIndex = c.getNeverType() catch 0 };
        }
        // TODO: IsVariableDeclaration and expando properties...
        return .{ .typeIndex = f.declaredType };
    }

    // TODO: for (const _ in ref)
    return .{};
}

pub fn isReachableFlowNode(c: *Checker, flow: flow_ast.FlowNodeIndex) bool {
    const f = getFlowState(c);
    const result = isReachableFlowNodeWorker(c, f, flow, false);
    putFlowState(c, f);
    c.lastFlowNode = flow;
    c.lastFlowNodeReachable = result;
    return result;
}

pub fn isReachableFlowNodeWorker(c: *Checker, f: *FlowState, flowParam: flow_ast.FlowNodeIndex, noCacheCheckParam: bool) bool {
    var flow = flowParam;
    var noCacheCheck = noCacheCheckParam;

    while (true) {
        if (flow == c.lastFlowNode) {
            return c.lastFlowNodeReachable;
        }
        
        const flowNode = c.binder.flowNodes.items[flow];
        const flags = flowNode.flags;
        
        if ((flags & flow_ast.FlowFlags.Shared) != 0) {
            if (!noCacheCheck) {
                if (c.flowNodeReachable.get(flow)) |reachable| {
                    return reachable;
                }
                const reachable = isReachableFlowNodeWorker(c, f, flow, true);
                c.flowNodeReachable.put(c.allocator, flow, reachable) catch @panic("OOM");
                return reachable;
            }
            noCacheCheck = false;
        }
        
        if ((flags & (flow_ast.FlowFlags.Assignment | flow_ast.FlowFlags.Condition | flow_ast.FlowFlags.ArrayMutation)) != 0) {
            flow = flowNode.antecedent;
        } else if ((flags & flow_ast.FlowFlags.Call) != 0) {
            // TODO: call predicates checking
            flow = flowNode.antecedent;
        } else if ((flags & flow_ast.FlowFlags.BranchLabel) != 0) {
            var list = getBranchLabelAntecedents(c, flow, f.reduceLabels.items);
            while (list != 0) {
                const listNode = c.binder.flowLists.items[list];
                if (isReachableFlowNodeWorker(c, f, listNode.flow, false)) {
                    return true;
                }
                list = listNode.next;
            }
            return false;
        } else if ((flags & flow_ast.FlowFlags.LoopLabel) != 0) {
            if (flowNode.antecedents == 0) return false;
            flow = c.binder.flowLists.items[flowNode.antecedents].flow;
        } else if ((flags & flow_ast.FlowFlags.SwitchClause) != 0) {
            // TODO: if exhaustive switch return false
            flow = flowNode.antecedent;
        } else if ((flags & flow_ast.FlowFlags.ReduceLabel) != 0) {
            c.lastFlowNode = 0;
            f.reduceLabels.append(c.allocator, flowNode.nodeData) catch @panic("OOM");
            const result = isReachableFlowNodeWorker(c, f, flowNode.antecedent, false);
            f.reduceLabels.items.len -= 1;
            return result;
        } else {
            return (flags & flow_ast.FlowFlags.Unreachable) == 0;
        }
    }
}

fn getBranchLabelAntecedents(c: *Checker, flow: flow_ast.FlowNodeIndex, reduceLabels: []flow_ast.FlowNodeData) flow_ast.FlowListIndex {
    var i: usize = reduceLabels.len;
    while (i != 0) {
        i -= 1;
        const data = reduceLabels[i];
        switch (data) {
            .ReduceLabelData => |rl| {
                if (rl.target == flow) {
                    return rl.antecedents;
                }
            },
            else => {},
        }
    }
    return c.binder.flowNodes.items[flow].antecedents;
}
