const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const ast_symbol = @import("../ast/symbol.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const flow_ast = @import("../ast/flow.zig");
const binder = @import("../binder/binder.zig");
const types = @import("types.zig");
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const relater = @import("relater.zig");
const utilities = @import("utilities.zig");

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
            // Define silentNeverType when needed
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
        return c.errorTypeIndex orelse 0;
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
    // EvolvingArray type logic to be implemented later
    return evolvedType;
}

pub fn getTypeAtFlowNode(c: *Checker, f: *FlowState, flowParam: flow_ast.FlowNodeIndex) FlowType {
    if (f.depth == 2000) {
        c.flowAnalysisDisabled = true;
        // reportFlowControlError(c, f.reference);
        return FlowType{ .typeIndex = c.errorTypeIndex orelse 0 };
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
fn isSymbolAssigned(c: *Checker, symbol: ast_gen.SymbolIndex) bool {
    c.ensureAssignmentsMarked(symbol);
    if (c.markedAssignmentSymbolLinks.get(symbol)) |links| {
        return links.lastAssignmentPos != 0;
    }
    return false;
}

fn getAccessedPropertyName(c: *Checker, access: ast.NodeIndex) ?[]const u8 {
    if (c.binder.ast.getKind(access) == .PropertyAccessExpression) {
        return ast_utils.getTextOfNode(c.binder.ast, ast_utils.getNameOfNode(c.binder.ast, access));
    }
    // We cannot fully implement ElementAccessExpression here yet because tryGetElementAccessExpressionName
    // requires resolveEntityName which is not yet ported.
    return null;
}

fn isMatchingReference(c: *Checker, source: ast.NodeIndex, target: ast.NodeIndex) bool {
    const targetKind = c.binder.ast.getKind(target);
    switch (targetKind) {
        .ParenthesizedExpression, .NonNullExpression => {
            return isMatchingReference(c, source, ast_utils.getExpressionOfNode(c.binder.ast, target));
        },
        .BinaryExpression => {
            const bin = c.binder.ast.getNode(target).BinaryExpression;
            if (ast_utils.isAssignmentExpression(c.binder.ast, target, false) and isMatchingReference(c, source, bin.Left)) {
                return true;
            }
            if (c.binder.ast.getKind(bin.OperatorToken) == .CommaToken and isMatchingReference(c, source, bin.Right)) {
                return true;
            }
        },
        else => {},
    }

    const sourceKind = c.binder.ast.getKind(source);
    switch (sourceKind) {
        .MetaProperty => {
            if (targetKind == .MetaProperty) {
                const sourceMeta = c.binder.ast.getNode(source).MetaProperty;
                const targetMeta = c.binder.ast.getNode(target).MetaProperty;
                if (sourceMeta.KeywordToken == targetMeta.KeywordToken) {
                    const sourceName = ast_utils.getTextOfNode(c.binder.ast, ast_utils.getNameOfNode(c.binder.ast, source));
                    const targetName = ast_utils.getTextOfNode(c.binder.ast, ast_utils.getNameOfNode(c.binder.ast, target));
                    return std.mem.eql(u8, sourceName, targetName);
                }
            }
        },
        .Identifier, .PrivateIdentifier => {
            if (ast_utils.isThisInTypeQuery(c.binder.ast, source)) {
                return targetKind == .ThisKeyword;
            }
            if (targetKind == .Identifier) {
                return checker_mod.getResolvedSymbol(c, source) == checker_mod.getResolvedSymbol(c, target);
            }
            if (targetKind == .VariableDeclaration or targetKind == .BindingElement) {
                return checker_mod.getExportSymbolOfValueSymbolIfExported(c, checker_mod.getResolvedSymbol(c, source)) == c.getSymbolOfDeclaration(target);
            }
        },
        .ThisKeyword => return targetKind == .ThisKeyword,
        .SuperKeyword => return targetKind == .SuperKeyword,
        .NonNullExpression, .ParenthesizedExpression, .SatisfiesExpression => {
            return isMatchingReference(c, ast_utils.getExpressionOfNode(c.binder.ast, source), target);
        },
        .PropertyAccessExpression, .ElementAccessExpression => {
            const sourcePropertyName = getAccessedPropertyName(c, source);
            if (sourcePropertyName) |spn| {
                const targetPropertyName = getAccessedPropertyName(c, target);
                if (targetPropertyName) |tpn| {
                    if (std.mem.eql(u8, spn, tpn)) {
                        return isMatchingReference(c, ast_utils.getExpressionOfNode(c.binder.ast, source), ast_utils.getExpressionOfNode(c.binder.ast, target));
                    }
                }
            }
            if (sourceKind == .ElementAccessExpression and targetKind == .ElementAccessExpression) {
                const sourceArg = c.binder.ast.getNode(source).ElementAccessExpression.ArgumentExpression;
                const targetArg = c.binder.ast.getNode(target).ElementAccessExpression.ArgumentExpression;
                if (c.binder.ast.getKind(sourceArg) == .Identifier and c.binder.ast.getKind(targetArg) == .Identifier) {
                    const symbol = checker_mod.getResolvedSymbol(c, sourceArg);
                    if (symbol != 0 and symbol == checker_mod.getResolvedSymbol(c, targetArg)) {
                        const sym = &c.binder.symbols.items[symbol];
                        if (utilities.isConstantVariable(c, sym) or (utilities.isParameterOrMutableLocalVariable(c, sym) and !isSymbolAssigned(c, symbol))) {
                            return isMatchingReference(c, ast_utils.getExpressionOfNode(c.binder.ast, source), ast_utils.getExpressionOfNode(c.binder.ast, target));
                        }
                    }
                }
            }
        },
        .QualifiedName => {
            const targetPropertyName = getAccessedPropertyName(c, target);
            if (targetPropertyName) |tpn| {
                const rightName = ast_utils.getTextOfNode(c.binder.ast, c.binder.ast.getNode(source).QualifiedName.Right);
                if (std.mem.eql(u8, rightName, tpn)) {
                    return isMatchingReference(c, c.binder.ast.getNode(source).QualifiedName.Left, ast_utils.getExpressionOfNode(c.binder.ast, target));
                }
            }
        },
        .BinaryExpression => {
            const bin = c.binder.ast.getNode(source).BinaryExpression;
            if (c.binder.ast.getKind(bin.OperatorToken) == .CommaToken) {
                return isMatchingReference(c, bin.Right, target);
            }
        },
        else => {},
    }
    return false;
}
fn getAssignmentTargetKind(c: *Checker, node: ast.NodeIndex) u32 {
    return @intFromEnum(utilities.getAssignmentTargetKind(c.binder.ast, node));
}
fn isEmptyArrayAssignment(c: *Checker, node: ast.NodeIndex) bool {
    const ast_data = c.binder.ast;
    const kind = ast_data.getKind(node);
    if (kind == .VariableDeclaration) {
        if (ast_data.getNode(node).VariableDeclaration.Initializer) |init| {
            return utilities.isEmptyArrayLiteral(ast_data, init);
        }
    } else if (kind != .BindingElement) {
        if (ast_data.getNode(node).Parent) |parent| {
            if (ast_data.getKind(parent) == .BinaryExpression) {
                const bin = ast_data.getNode(parent).BinaryExpression;
                return utilities.isEmptyArrayLiteral(ast_data, bin.Right);
            }
        }
    }
    return false;
}
fn getEvolvingArrayType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    return c.getEvolvingArrayType(t);
}
fn getWidenedLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    return c.getWidenedLiteralType(t);
}
fn getInitialOrAssignedType(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex) types.TypeIndex {
    _ = c;
    _ = f;
    _ = flow;
    return 0;
}
fn isTypeAssignableTo(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    return c.isTypeAssignableTo(source, target);
}

fn getBaseTypeOfLiteralType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    return c.getBaseTypeOfLiteralType(t);
}

fn getAssignmentReducedTypeWorker(c: *Checker, declaredType: types.TypeIndex, assignedType: types.TypeIndex) types.TypeIndex {
    _ = c;
    _ = assignedType;
    return declaredType; // Stub implementation: just return declaredType
}

fn getAssignmentReducedType(c: *Checker, declaredType: types.TypeIndex, assignedType: types.TypeIndex) types.TypeIndex {
    if (declaredType == assignedType) {
        return declaredType;
    }
    const t_assigned = c.typesList.items[assignedType];
    if ((t_assigned.flags & types.TypeFlags.Never) != 0) {
        return assignedType;
    }
    const key = types.AssignmentReducedKey{ .id1 = declaredType, .id2 = assignedType };
    if (c.assignmentReducedTypes.get(key)) |result| {
        return result;
    }
    const result = getAssignmentReducedTypeWorker(c, declaredType, assignedType);
    c.assignmentReducedTypes.put(c.allocator, key, result) catch {};
    return result;
}
fn containsMatchingReference(c: *Checker, source: ast.NodeIndex, target: ast.NodeIndex) bool {
    var current = source;
    while (ast_utils.isAccessExpression(c.binder.ast, current)) {
        current = ast_utils.getExpressionOfNode(c.binder.ast, current);
        if (isMatchingReference(c, current, target)) {
            return true;
        }
    }
    return false;
}

fn optionalChainContainsReference(c: *Checker, expr: ast.NodeIndex, ref: ast.NodeIndex) bool {
    var current = expr;
    while (ast_utils.isOptionalChain(c.binder.ast, current)) {
        current = ast_utils.getExpressionOfNode(c.binder.ast, current);
        if (isMatchingReference(c, current, ref)) {
            return true;
        }
    }
    return false;
}

fn finalizeEvolvingArrayType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    if ((c.typesList.items[t].objectFlags & types.ObjectFlags.EvolvingArray) != 0) {
        return getFinalArrayType(c, t);
    }
    return t;
}

fn getFinalArrayType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    var ty = &c.typesList.items[t];
    if (ty.data.Object.finalArrayType == null) {
        ty.data.Object.finalArrayType = createFinalArrayType(c, ty.data.Object.evolvingArrayElementType.?);
    }
    return ty.data.Object.finalArrayType.?;
}

fn createFinalArrayType(c: *Checker, elementType: types.TypeIndex) types.TypeIndex {
    const flags = Checker.getTypeFlags(c, elementType);
    if ((flags & types.TypeFlags.Never) != 0) {
        return c.autoArrayTypeIndex orelse 0;
    }
    if ((flags & types.TypeFlags.Union) != 0) {
        const unionTypes = Checker.getTypesFromUnion(c, elementType);
        const combined = Checker.getUnionTypeFromArray(c, unionTypes);
        return Checker.createArrayType(c, combined);
    }
    return Checker.createArrayType(c, elementType);
}

fn getNonNullableTypeIfNeeded(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    if (Checker.hasTypeFacts(c, t, types.TypeFacts.IsUndefinedOrNull)) {
        if (c.strictNullChecks) {
            return Checker.getAdjustedTypeWithFacts(c, t, types.TypeFacts.NEUndefinedOrNull);
        }
    }
    return t;
}

fn narrowTypeByOptionality(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumePresent: bool) types.TypeIndex {
    if (isMatchingReference(c, f.reference, expr)) {
        return Checker.getAdjustedTypeWithFacts(c, t, if (assumePresent) types.TypeFacts.NEUndefinedOrNull else types.TypeFacts.EQUndefinedOrNull);
    }
    if (getDiscriminantPropertyAccess(c, f, expr, t)) |access| {
        const Ctx = struct {
            c: *Checker,
            assumePresent: bool,
        };
        const ctx = Ctx{ .c = c, .assumePresent = assumePresent };

        const narrowFn = struct {
            fn f_inner(c_inner: *Checker, ty: types.TypeIndex, ctx_inner: Ctx) types.TypeIndex {
                _ = c_inner;
                return Checker.getTypeWithFacts(ctx_inner.c, ty, if (ctx_inner.assumePresent) types.TypeFacts.NEUndefinedOrNull else types.TypeFacts.EQUndefinedOrNull);
            }
        }.f_inner;

        return narrowTypeByDiscriminant(c, t, access, narrowFn, ctx);
    }
    return t;
}

pub fn isReadonlySymbol(c: *Checker, sym: ast_gen.SymbolIndex) bool {
    if (sym >= c.binder.symbols.items.len) return false;
    const symbol = c.binder.symbols.items[sym];
    const checkFlags = Checker.getSymbolCheckFlags(c, sym);
    if ((checkFlags & types.CheckFlags.Readonly) != 0) return true;
    if ((symbol.Flags & ast_symbol.SymbolFlags.Property) != 0 and (Checker.getDeclarationModifierFlagsFromSymbol(c, sym) & ast_utils.ModifierFlags.Readonly) != 0) return true;
    if ((symbol.Flags & ast_symbol.SymbolFlags.Variable) != 0 and (Checker.getDeclarationNodeFlagsFromSymbol(c, sym) & ast_utils.NodeFlags.Constant) != 0) return true;
    if ((symbol.Flags & ast_symbol.SymbolFlags.Accessor) != 0 and (symbol.Flags & ast_symbol.SymbolFlags.SetAccessor) == 0) return true;
    if ((symbol.Flags & ast_symbol.SymbolFlags.EnumMember) != 0) return true;

    // Stub for isReadonlyAssignmentDeclaration
    return false;
}
fn isSomeSymbolAssignedWorker(c: *Checker, node: ast_gen.NodeIndex) bool {
    const nodeKind = c.binder.ast.getKind(node);
    if (nodeKind == .Identifier) {
        return isSymbolAssigned(c, Checker.getSymbolOfDeclaration(c, ast_utils.getParent(c.binder.ast, node)));
    }
    const elements = ast_utils.getElements(c.binder.ast, node);
    for (elements) |element| {
        const name = ast_utils.getName(c.binder.ast, element);
        if (name != 0 and isSomeSymbolAssignedWorker(c, name)) {
            return true;
        }
    }
    return false;
}

fn isSomeSymbolAssigned(c: *Checker, declaration: ast_gen.NodeIndex) bool {
    const name = ast_utils.getName(c.binder.ast, declaration);
    if (name == 0) return false;
    return isSomeSymbolAssignedWorker(c, name);
}
fn isVarConstLike(c: *Checker, declaration: ast_gen.NodeIndex) bool {
    const blockScopeKind = ast_utils.getCombinedNodeFlags(c.binder.ast, declaration) & ast_utils.NodeFlags.BlockScoped;
    return blockScopeKind == ast_utils.NodeFlags.Const or blockScopeKind == ast_utils.NodeFlags.Using or blockScopeKind == ast_utils.NodeFlags.AwaitUsing;
}

fn isConstantReference(c: *Checker, expr: ast_gen.NodeIndex) bool {
    const kind = c.binder.ast.getKind(expr);
    switch (kind) {
        .ThisKeyword => return true,
        .Identifier => {
            if (!ast_utils.isThisInTypeQuery(c.binder.ast, expr)) {
                const symbolId = checker_mod.getResolvedSymbol(c, expr);
                if (symbolId != 0 and symbolId != c.unknownSymbol) {
                    const sym = &c.binder.symbols.items[symbolId];
                    if (utilities.isConstantVariable(c, sym)) return true;
                    if (utilities.isParameterOrMutableLocalVariable(c, sym) and !isSymbolAssigned(c, symbolId)) return true;
                    if (sym.ValueDeclaration) |decl| {
                        if (c.binder.ast.getKind(decl) == .FunctionExpression) return true;
                    }
                }
            }
        },
        .PropertyAccessExpression, .ElementAccessExpression => {
            if (isConstantReference(c, ast_utils.getExpressionOfNode(c.binder.ast, expr))) {
                const symbolId = checker_mod.getResolvedSymbol(c, expr);
                if (symbolId != 0 and symbolId != c.unknownSymbol) {
                    return isReadonlySymbol(c, symbolId);
                }
            }
        },
        .ObjectBindingPattern, .ArrayBindingPattern => {
            const parent = ast_utils.getParent(c.binder.ast, expr);
            const rootDeclaration = ast_utils.getRootDeclaration(c.binder.ast, parent);
            if (rootDeclaration != 0) {
                const rootKind = c.binder.ast.getKind(rootDeclaration);
                const rootParent = ast_utils.getParent(c.binder.ast, rootDeclaration);
                if (rootKind == .Parameter or (rootKind == .VariableDeclaration and rootParent != 0 and c.binder.ast.getKind(rootParent) == .CatchClause)) {
                    return !isSomeSymbolAssigned(c, rootDeclaration);
                }
                return rootKind == .VariableDeclaration and isVarConstLike(c, rootDeclaration);
            }
        },
        else => {},
    }
    return false;
}
fn isOrContainsMatchingReference(c: *Checker, source: ast.NodeIndex, target: ast.NodeIndex) bool {
    return isMatchingReference(c, source, target) or containsMatchingReference(c, source, target);
}

fn hasMatchingArgument(c: *Checker, callExpression: ast_gen.NodeIndex, ref: ast_gen.NodeIndex) bool {
    const argsNodeList = switch (c.binder.ast.getNode(callExpression)) {
        .CallExpression => |n| n.Arguments,
        .NewExpression => |n| n.Arguments,
        else => null,
    };
    if (argsNodeList != null and argsNodeList.? != 0) {
        for (c.binder.ast.getNodeList(argsNodeList.?)) |argument| {
            if (isOrContainsMatchingReference(c, ref, argument) or optionalChainContainsReference(c, argument, ref)) {
                return true;
            }
        }
    }
    const expr = ast_utils.getExpressionOfNode(c.binder.ast, callExpression);
    if (ast_utils.isPropertyAccessExpression(c.binder.ast, expr) and isOrContainsMatchingReference(c, ref, ast_utils.getExpressionOfNode(c.binder.ast, expr))) {
        return true;
    }
    return false;
}

fn isCallChain(c: *Checker, callExpression: ast_gen.NodeIndex) bool {
    return std.meta.activeTag(c.binder.ast.getNode(callExpression)) == .CallExpression and ast_utils.isOptionalChain(c.binder.ast, callExpression);
}

fn containsMissingType(c: *Checker, t: types.TypeIndex) bool {
    _ = c;
    _ = t;
    return false;
}

fn isTypeUsableAsPropertyName(c: *Checker, t: types.TypeIndex) bool {
    _ = c;
    _ = t;
    return false;
}

fn getPropertyNameFromType(c: *Checker, t: types.TypeIndex) ?[]const u8 {
    _ = c;
    _ = t;
    return null;
}

fn getApplicableIndexInfoForName(c: *Checker, t: types.TypeIndex, name: []const u8) ?types.IndexInfo {
    if (std.mem.startsWith(u8, name, "__@")) {
        return Checker.getApplicableIndexInfo(c, t, c.esSymbolTypeIndex orelse 0);
    }
    return Checker.getApplicableIndexInfo(c, t, Checker.getStringLiteralType(c, name));
}

fn isTypePresencePossible(c: *Checker, t: types.TypeIndex, propName: []const u8, assumeTrue: bool) bool {
    const prop = Checker.getPropertyOfType(c, t, propName);
    if (prop != null) {
        return (c.binder.symbols.items[prop.?].Flags & ast_symbol.SymbolFlags.Optional) != 0 or (Checker.getSymbolCheckFlags(c, prop.?) & types.CheckFlags.Partial) != 0 or assumeTrue;
    }
    return getApplicableIndexInfoForName(c, t, propName) != null or !assumeTrue;
}

const InKeywordCtx = struct {
    c: *Checker,
    name: []const u8,
    assumeTrue: bool,
};

fn inKeywordMap1(c: *Checker, t: types.TypeIndex, ctx: InKeywordCtx) bool {
    return isTypePresencePossible(c, t, ctx.name, true);
}

fn inKeywordMap2(c: *Checker, t: types.TypeIndex, ctx: InKeywordCtx) bool {
    return isTypePresencePossible(c, t, ctx.name, ctx.assumeTrue);
}

fn narrowTypeByInKeyword(c: *Checker, f: *FlowState, t: types.TypeIndex, nameType: types.TypeIndex, assumeTrue: bool) types.TypeIndex {
    _ = f;
    const name = getPropertyNameFromType(c, nameType);
    if (name == null) return t;
    const ctx = InKeywordCtx{ .c = c, .name = name.?, .assumeTrue = assumeTrue };
    const isKnownProperty = Checker.someType(c, t, inKeywordMap1, ctx);
    if (isKnownProperty) {
        return Checker.filterType(c, t, inKeywordMap2, ctx);
    }
    if (assumeTrue) {
        const recordSymbol = c.getGlobalRecordSymbol();
        if (recordSymbol != 0) {
            var args = [_]types.TypeIndex{ nameType, c.unknownTypeIndex orelse 0 };
            const recordType = Checker.getTypeAliasInstantiation(c, recordSymbol, &args, null);
            return Checker.getIntersectionType(c, &[_]types.TypeIndex{ t, recordType });
        }
    }
    return t;
}

fn getTypeOfExpression(c: *Checker, expr: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = expr;
    return 0;
}

fn narrowTypeByCallExpression(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    const callExpr = c.binder.ast.getNode(expr).CallExpression;
    if (c.binder.ast.getKind(callExpr.Expression) == .SuperKeyword) {
        return t;
    }
    if (hasMatchingArgument(c, expr, f.reference)) {
        var predicate: ?*const types.TypePredicate = null;
        if (assumeTrue or !isCallChain(c, expr)) {
            const signature = getEffectsSignature(c, expr);
            if (signature != null) {
                predicate = getTypePredicateOfSignature(c, signature.?);
            }
        }
        if (predicate != null and (predicate.?.kind == .This or predicate.?.kind == .Identifier)) {
            return narrowTypeByTypePredicate(c, f, t, predicate.?, expr, assumeTrue);
        }
    }
    const target = getReferenceCandidate(c, callExpr.Expression);
    if (containsMissingType(c, t) and ast_utils.isAccessExpression(c.binder.ast, f.reference) and ast_utils.isPropertyAccessExpression(c.binder.ast, callExpr.Expression)) {
        const callAccess = c.binder.ast.getNode(callExpr.Expression).PropertyAccessExpression;
        if (isMatchingReference(c, ast_utils.getExpressionOfNode(c.binder.ast, f.reference), getReferenceCandidate(c, callAccess.Expression)) and
            c.binder.ast.getKind(callAccess.name) == .Identifier and
            std.mem.eql(u8, c.binder.ast.getNode(callAccess.name).Identifier.Text, "hasOwnProperty") and
            c.binder.ast.getNodeList(callExpr.Arguments).len == 1)
        {
            const argument = c.binder.ast.getNodeList(callExpr.Arguments)[0];
            const accessedName = getAccessedPropertyName(c, f.reference);
            if (accessedName != null and ast_utils.isStringLiteralLike(c.binder.ast, argument)) {
                if (std.mem.eql(u8, accessedName.?, ast_utils.getTextOfNode(c.binder.ast, argument))) {
                    return Checker.getAdjustedTypeWithFacts(c, t, if (assumeTrue) types.TypeFacts.NEUndefined else types.TypeFacts.EQUndefined);
                }
            }
        }
    }
    if (isMatchingReference(c, f.reference, target)) {
        const leftType = getTypeOfExpression(c, callExpr.Expression);
        if (isTypeUsableAsPropertyName(c, leftType)) {
            return narrowTypeByInKeyword(c, f, t, leftType, assumeTrue);
        }
    }
    return t;
}
fn narrowTypeByTypeName(c: *Checker, t: types.TypeIndex, name: []const u8) types.TypeIndex {
    if (std.mem.eql(u8, name, "string")) {
        return Checker.narrowTypeByTypeFacts(c, t, c.getStringType() catch return 0, types.TypeFacts.TypeofEQString);
    } else if (std.mem.eql(u8, name, "number")) {
        return Checker.narrowTypeByTypeFacts(c, t, c.getNumberType() catch return 0, types.TypeFacts.TypeofEQNumber);
    } else if (std.mem.eql(u8, name, "bigint")) {
        return Checker.narrowTypeByTypeFacts(c, t, c.getBigIntType() catch return 0, types.TypeFacts.TypeofEQBigInt);
    } else if (std.mem.eql(u8, name, "boolean")) {
        return Checker.narrowTypeByTypeFacts(c, t, c.getBooleanType() catch return 0, types.TypeFacts.TypeofEQBoolean);
    } else if (std.mem.eql(u8, name, "symbol")) {
        return Checker.narrowTypeByTypeFacts(c, t, c.getEsSymbolType() catch return 0, types.TypeFacts.TypeofEQSymbol);
    } else if (std.mem.eql(u8, name, "object")) {
        if ((Checker.getTypeFlags(c, t) & types.TypeFlags.Any) != 0) return t;
        var args = [_]types.TypeIndex{
            Checker.narrowTypeByTypeFacts(c, t, c.getNonPrimitiveType() catch return 0, types.TypeFacts.TypeofEQObject),
            Checker.narrowTypeByTypeFacts(c, t, c.getNullType() catch return 0, types.TypeFacts.EQNull),
        };
        return Checker.getUnionTypeFromArray(c, &args);
    } else if (std.mem.eql(u8, name, "function")) {
        return Checker.narrowTypeByTypeFacts(c, t, c.globalFunctionType, types.TypeFacts.TypeofEQFunction);
    } else if (std.mem.eql(u8, name, "undefined")) {
        return Checker.narrowTypeByTypeFacts(c, t, c.getUndefinedType() catch return 0, types.TypeFacts.EQUndefined);
    }
    return Checker.narrowTypeByTypeFacts(c, t, c.getNonPrimitiveType() catch return 0, types.TypeFacts.TypeofEQHostObject);
}

fn narrowTypeByLiteralExpression(c: *Checker, t: types.TypeIndex, literal: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    if (assumeTrue) {
        return narrowTypeByTypeName(c, t, ast_utils.getTextOfNode(c.binder.ast, literal));
    }

    var facts: u32 = types.TypeFacts.TypeofNEHostObject;
    const text = ast_utils.getTextOfNode(c.binder.ast, literal);
    if (std.mem.eql(u8, text, "string")) {
        facts = types.TypeFacts.TypeofNEString;
    } else if (std.mem.eql(u8, text, "number")) {
        facts = types.TypeFacts.TypeofNENumber;
    } else if (std.mem.eql(u8, text, "bigint")) {
        facts = types.TypeFacts.TypeofNEBigInt;
    } else if (std.mem.eql(u8, text, "boolean")) {
        facts = types.TypeFacts.TypeofNEBoolean;
    } else if (std.mem.eql(u8, text, "symbol")) {
        facts = types.TypeFacts.TypeofNESymbol;
    } else if (std.mem.eql(u8, text, "object")) {
        facts = types.TypeFacts.TypeofNEObject;
    } else if (std.mem.eql(u8, text, "function")) {
        facts = types.TypeFacts.TypeofNEFunction;
    }

    return Checker.getTypeWithFacts(c, t, facts);
}

fn isCoercibleUnderDoubleEquals(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    const s_flags = Checker.getTypeFlags(c, source);
    const t_flags = Checker.getTypeFlags(c, target);
    return (s_flags & (types.TypeFlags.Number | types.TypeFlags.String | types.TypeFlags.BooleanLiteral) != 0) and
        (t_flags & (types.TypeFlags.Number | types.TypeFlags.String | types.TypeFlags.Boolean) != 0);
}

const NarrowByEqualityCtx = struct { valueType: types.TypeIndex, doubleEquals: bool };

fn narrowTypeByEqualityMap(c: *Checker, t: types.TypeIndex, ctx: NarrowByEqualityCtx) bool {
    return relater.areTypesComparable(c, t, ctx.valueType) or (ctx.doubleEquals and isCoercibleUnderDoubleEquals(c, t, ctx.valueType));
}

fn narrowTypeByEqualityUnitMap(c: *Checker, t: types.TypeIndex, ctx: NarrowByEqualityCtx) bool {
    return !(isUnitLikeType(c, t) and relater.areTypesComparable(c, t, ctx.valueType));
}

fn isEmptyAnonymousObjectTypeWrapper(c: *Checker, t: types.TypeIndex, ctx: void) bool {
    _ = ctx;
    return Checker.isEmptyAnonymousObjectType(c, t);
}

fn narrowTypeByEquality(c: *Checker, t: types.TypeIndex, operator: std.meta.Tag(ast_gen.NodeData), right: ast_gen.NodeIndex, assumeTrueOriginal: bool) types.TypeIndex {
    if ((Checker.getTypeFlags(c, t) & types.TypeFlags.Any) != 0) {
        return t;
    }
    var assumeTrue = assumeTrueOriginal;
    if (operator == .ExclamationEqualsToken or operator == .ExclamationEqualsEqualsToken) {
        assumeTrue = !assumeTrue;
    }
    const valueType = getTypeOfExpression(c, right);
    const doubleEquals = operator == .EqualsEqualsToken or operator == .ExclamationEqualsToken;
    const valueTypeFlags = Checker.getTypeFlags(c, valueType);

    if ((valueTypeFlags & types.TypeFlags.Nullable) != 0) {
        if (!c.strictNullChecks) {
            return t;
        }
        var facts: u32 = 0;
        if (doubleEquals) {
            facts = if (assumeTrue) types.TypeFacts.EQUndefinedOrNull else types.TypeFacts.NEUndefinedOrNull;
        } else if ((valueTypeFlags & types.TypeFlags.Null) != 0) {
            facts = if (assumeTrue) types.TypeFacts.EQNull else types.TypeFacts.NENull;
        } else {
            facts = if (assumeTrue) types.TypeFacts.EQUndefined else types.TypeFacts.NEUndefined;
        }
        return Checker.getAdjustedTypeWithFacts(c, t, facts);
    }

    if (assumeTrue) {
        if (!doubleEquals and ((Checker.getTypeFlags(c, t) & types.TypeFlags.Unknown) != 0 or Checker.someType(c, t, isEmptyAnonymousObjectTypeWrapper, {}))) {
            if ((valueTypeFlags & (types.TypeFlags.Primitive | types.TypeFlags.NonPrimitive)) != 0 or Checker.isEmptyAnonymousObjectType(c, valueType)) {
                return valueType;
            }
            if ((valueTypeFlags & types.TypeFlags.Object) != 0) {
                return c.getNonPrimitiveType() catch 0;
            }
        }
        const filteredType = Checker.filterType(c, t, narrowTypeByEqualityMap, NarrowByEqualityCtx{ .valueType = valueType, .doubleEquals = doubleEquals });
        return replacePrimitivesWithLiterals(c, filteredType, valueType);
    }
    if (isUnitType(c, valueType)) {
        return Checker.filterType(c, t, narrowTypeByEqualityUnitMap, NarrowByEqualityCtx{ .valueType = valueType, .doubleEquals = doubleEquals });
    }
    return t;
}

const NarrowTypeByTypeofCtx = struct {
    literal: ast_gen.NodeIndex,
    assumeTrue: bool,
};

fn narrowTypeByTypeofMap(c: *Checker, t: types.TypeIndex, ctx: NarrowTypeByTypeofCtx) types.TypeIndex {
    return narrowTypeByLiteralExpression(c, t, ctx.literal, ctx.assumeTrue);
}

fn narrowTypeByTypeof(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, operator: std.meta.Tag(ast_gen.NodeData), right: ast_gen.NodeIndex, assumeTrueOriginal: bool) types.TypeIndex {
    var assumeTrue = assumeTrueOriginal;
    if (operator == .ExclamationEqualsToken or operator == .ExclamationEqualsEqualsToken) {
        assumeTrue = !assumeTrue;
    }
    const typeOfExpr = c.binder.ast.getNode(expr).TypeOfExpression;
    const target = getReferenceCandidate(c, typeOfExpr.Expression);

    if (!isMatchingReference(c, f.reference, target)) {
        var currentT = t;
        const text = ast_utils.getTextOfNode(c.binder.ast, right);
        if (c.strictNullChecks and optionalChainContainsReference(c, target, f.reference) and assumeTrue == std.mem.eql(u8, text, "undefined")) {
            currentT = Checker.getAdjustedTypeWithFacts(c, currentT, types.TypeFacts.NEUndefinedOrNull);
        }
        const propertyAccess = getDiscriminantPropertyAccess(c, f, target, currentT);
        if (propertyAccess != null) {
            return narrowTypeByDiscriminant(c, currentT, propertyAccess.?, narrowTypeByTypeofMap, NarrowTypeByTypeofCtx{ .literal = right, .assumeTrue = assumeTrue });
        }
        return currentT;
    }
    return narrowTypeByLiteralExpression(c, t, right, assumeTrue);
}

fn checkNullableFlags(c: *Checker, t: types.TypeIndex, nullableFlags: u32) bool {
    return (Checker.getTypeFlags(c, t) & nullableFlags) != 0;
}
fn checkExcludeNullableFlags(c: *Checker, t: types.TypeIndex, nullableFlags: u32) bool {
    return (Checker.getTypeFlags(c, t) & (types.TypeFlags.Any | types.TypeFlags.Unknown | nullableFlags)) == 0;
}

fn everyType(c: *Checker, t: types.TypeIndex, comptime filterFn: anytype, ctx: anytype) bool {
    const flags = Checker.getTypeFlags(c, t);
    if ((flags & types.TypeFlags.Union) != 0) {
        for (c.getTypesFromUnion(t)) |u| {
            if (!everyType(c, u, filterFn, ctx)) return false;
        }
        return true;
    }
    if ((flags & types.TypeFlags.Intersection) != 0) {
        for (c.getTypesFromIntersection(t)) |u| {
            if (everyType(c, u, filterFn, ctx)) return true;
        }
        return false;
    }
    return filterFn(c, t, ctx);
}

fn narrowTypeByOptionalChainContainment(c: *Checker, f: *FlowState, t: types.TypeIndex, operator: std.meta.Tag(ast_gen.NodeData), right: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    _ = f;
    const equalsOperator = operator == .EqualsEqualsToken or operator == .EqualsEqualsEqualsToken;
    var nullableFlags: u32 = 0;
    if (operator == .EqualsEqualsToken or operator == .ExclamationEqualsToken) {
        nullableFlags = types.TypeFlags.Nullable;
    } else {
        nullableFlags = types.TypeFlags.Undefined;
    }
    const valueType = getTypeOfExpression(c, right);
    const removeNullable = (equalsOperator != assumeTrue and everyType(c, valueType, checkNullableFlags, nullableFlags)) or
        (equalsOperator == assumeTrue and everyType(c, valueType, checkExcludeNullableFlags, nullableFlags));
    if (removeNullable) {
        return Checker.getAdjustedTypeWithFacts(c, t, types.TypeFacts.NEUndefinedOrNull); // stub for getAdjustedTypeWithFacts
    }
    return t;
}

const NarrowByEqCtx = struct {
    operator: std.meta.Tag(ast_gen.NodeData),
    value: ast_gen.NodeIndex,
    assumeTrue: bool,
};

fn narrowTypeByEqualityWrapper(c: *Checker, t: types.TypeIndex, ctx: NarrowByEqCtx) types.TypeIndex {
    return narrowTypeByEquality(c, t, ctx.operator, ctx.value, ctx.assumeTrue);
}

fn narrowTypeByDiscriminantProperty(c: *Checker, t: types.TypeIndex, access: ast_gen.NodeIndex, operator: std.meta.Tag(ast_gen.NodeData), right: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    if ((operator == .EqualsEqualsEqualsToken or operator == .ExclamationEqualsEqualsToken) and (Checker.getTypeFlags(c, t) & types.TypeFlags.Union) != 0) {
        const keyPropertyName = relater.getKeyPropertyName(c, t);
        if (keyPropertyName.len > 0) {
            const accessedName = getAccessedPropertyName(c, access);
            if (accessedName != null and std.mem.eql(u8, keyPropertyName, accessedName.?)) {
                const candidate = relater.getConstituentTypeForKeyType(c, t, getTypeOfExpression(c, right));
                if (candidate != null) {
                    if ((assumeTrue and operator == .EqualsEqualsEqualsToken) or (!assumeTrue and operator == .ExclamationEqualsEqualsToken)) {
                        return candidate.?;
                    }
                    const propType = Checker.getTypeOfPropertyOfType(c, candidate.?, keyPropertyName);
                    if (propType != 0 and isUnitType(c, propType)) {
                        return Checker.removeType(c, t, candidate.?);
                    }
                    return t;
                }
            }
        }
    }
    return narrowTypeByDiscriminant(c, t, access, narrowTypeByEqualityWrapper, NarrowByEqCtx{ .operator = operator, .value = right, .assumeTrue = assumeTrue });
}

fn isMatchingConstructorReference(c: *Checker, f: *FlowState, expr: ast_gen.NodeIndex) bool {
    const exprData = c.binder.ast.getNode(expr);
    const isAccess = std.meta.activeTag(exprData) == .PropertyAccessExpression or std.meta.activeTag(exprData) == .ElementAccessExpression;
    if (isAccess) {
        if (getAccessedPropertyName(c, expr)) |accessedName| {
            if (std.mem.eql(u8, accessedName, "constructor")) {
                const expression = switch (exprData) {
                    .PropertyAccessExpression => |p| p.Expression,
                    .ElementAccessExpression => |e| e.Expression,
                    else => unreachable,
                };
                if (isMatchingReference(c, f.reference, expression)) {
                    return true;
                }
            }
        }
    }
    return false;
}

fn narrowTypeByConstructor(c: *Checker, t: types.TypeIndex, operator: std.meta.Tag(ast_gen.NodeData), right: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    if ((assumeTrue and operator != .EqualsEqualsToken and operator != .EqualsEqualsEqualsToken) or
        (!assumeTrue and operator != .ExclamationEqualsToken and operator != .ExclamationEqualsEqualsToken))
    {
        return t;
    }
    const identifierType = c.getTypeOfNode(right) catch return t;
    if (!Checker.isFunctionType(c, identifierType) and !Checker.isConstructorType(c, identifierType)) {
        return t;
    }
    const prototypeProperty = c.getPropertyOfType(identifierType, "prototype");
    if (prototypeProperty == null) {
        return t;
    }
    const prototypeType = c.getTypeOfSymbol(prototypeProperty.?) catch return t;
    var candidate: ?types.TypeIndex = null;
    if ((Checker.getTypeFlags(c, prototypeType) & types.TypeFlags.Any) == 0) {
        candidate = prototypeType;
    }
    if (candidate == null or candidate.? == c.globalObjectType or candidate.? == c.globalFunctionType) {
        return t;
    }
    if ((Checker.getTypeFlags(c, t) & types.TypeFlags.Any) != 0) {
        return candidate.?;
    }

    const Ctx = struct {
        c: *Checker,
        candidate: types.TypeIndex,
    };
    const ctx = Ctx{ .c = c, .candidate = candidate.? };

    const filterFn = struct {
        fn f(c_inner: *Checker, ty: types.TypeIndex, ctx_inner: Ctx) bool {
            _ = c_inner;
            return isConstructedBy(ctx_inner.c, ty, ctx_inner.candidate);
        }
    }.f;

    return Checker.filterType(c, t, filterFn, ctx);
}

fn isConstructedBy(c: *Checker, source: types.TypeIndex, target: types.TypeIndex) bool {
    const sourceFlags = Checker.getTypeFlags(c, source);
    const targetFlags = Checker.getTypeFlags(c, target);
    if (((sourceFlags & types.TypeFlags.Object) != 0 and (Checker.getObjectFlags(c, source) & types.ObjectFlags.Class) != 0) or
        ((targetFlags & types.TypeFlags.Object) != 0 and (Checker.getObjectFlags(c, target) & types.ObjectFlags.Class) != 0))
    {
        return c.typesList.items[source].symbol == c.typesList.items[target].symbol;
    }
    return c.isTypeDerivedFrom(source, target);
}

fn narrowTypeByBooleanComparison(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, boolValue: ast_gen.NodeIndex, operator: std.meta.Tag(ast_gen.NodeData), assumeTrue: bool) types.TypeIndex {
    const isTrue = std.meta.activeTag(c.binder.ast.getNode(boolValue)) == .TrueKeyword;
    const isNotEquals = operator != .ExclamationEqualsEqualsToken and operator != .ExclamationEqualsToken;
    const newAssumeTrue = (assumeTrue != isTrue) != isNotEquals;
    return narrowType(c, f, t, expr, newAssumeTrue);
}

fn narrowTypeByInstanceof(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    const binExpr = c.binder.ast.getNode(expr).BinaryExpression;
    const left = getReferenceCandidate(c, binExpr.Left);
    if (!isMatchingReference(c, f.reference, left)) {
        if (assumeTrue and c.strictNullChecks and optionalChainContainsReference(c, left, f.reference)) {
            return Checker.getAdjustedTypeWithFacts(c, t, types.TypeFacts.NEUndefinedOrNull);
        }
        return t;
    }
    const right = binExpr.Right;
    const rightType = c.getTypeOfNode(right) catch return t;

    if (!Checker.isTypeDerivedFrom(c, rightType, c.globalObjectType)) {
        return t;
    }

    var predicate: ?*const types.TypePredicate = null;
    if (getEffectsSignature(c, expr)) |signature| {
        predicate = getTypePredicateOfSignature(c, signature);
    }
    if (predicate != null and predicate.?.kind == .Identifier and predicate.?.parameterIndex == 0 and predicate.?.t != null) {
        return Checker.getNarrowedType(c, t, predicate.?.t.?, assumeTrue, true);
    }

    if (!Checker.isTypeDerivedFrom(c, rightType, c.globalFunctionType)) {
        return t;
    }

    const Ctx = struct {
        c: *Checker,
    };
    const ctx = Ctx{ .c = c };
    const mapFn = struct {
        fn map(c_inner: *Checker, ty: types.TypeIndex, ctx_inner: Ctx) types.TypeIndex {
            _ = c_inner;
            return Checker.getInstanceType(ctx_inner.c, ty);
        }
    }.map;
    const instanceType = Checker.mapType(c, rightType, mapFn, ctx);

    if (((Checker.getTypeFlags(c, t) & types.TypeFlags.Any) != 0 and (instanceType == c.globalObjectType or instanceType == c.globalFunctionType)) or
        (!assumeTrue and !((Checker.getTypeFlags(c, instanceType) & types.TypeFlags.Object) != 0 and !Checker.isEmptyAnonymousObjectType(c, instanceType))))
    {
        return t;
    }

    return Checker.getNarrowedType(c, t, instanceType, assumeTrue, true);
}

fn narrowTypeByPrivateIdentifierInInExpression(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    const binExpr = c.binder.ast.getNode(expr).BinaryExpression;
    const target = getReferenceCandidate(c, binExpr.Right);
    if (!isMatchingReference(c, f.reference, target)) {
        return t;
    }
    const symbol = c.getSymbolForPrivateIdentifierExpression(binExpr.Left); // Use c method
    if (symbol == 0) {
        return t;
    }
    const classSymbol = c.getParentOfSymbol(symbol); // Use c method
    var targetType: types.TypeIndex = 0;
    if ((ast_utils.getModifierFlags(c.binder.ast, c.getSymbolValueDeclaration(symbol)) & ast_utils.ModifierFlags.Static) != 0) {
        targetType = c.getTypeOfSymbol(classSymbol) catch 0;
    } else {
        targetType = c.getDeclaredTypeOfSymbol(classSymbol);
    }
    return Checker.getNarrowedType(c, t, targetType, assumeTrue, true);
}

fn narrowTypeByInExpression(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    const binExpr = c.binder.ast.getNode(expr).BinaryExpression;
    const target = getReferenceCandidate(c, binExpr.Right);
    if (!isMatchingReference(c, f.reference, target)) {
        return t;
    }
    const nameType = getTypeOfExpression(c, binExpr.Left);
    return narrowTypeByInKeyword(c, f, t, nameType, assumeTrue);
}

fn narrowTypeByBinaryExpression(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    const binExpr = c.binder.ast.getNode(expr).BinaryExpression;
    const operator = std.meta.activeTag(c.binder.ast.getNode(binExpr.OperatorToken));

    switch (operator) {
        .EqualsToken, .BarBarEqualsToken, .AmpersandAmpersandEqualsToken, .QuestionQuestionEqualsToken => {
            return narrowTypeByTruthiness(c, f, narrowType(c, f, t, binExpr.Right, assumeTrue), binExpr.Left, assumeTrue);
        },
        .EqualsEqualsToken, .ExclamationEqualsToken, .EqualsEqualsEqualsToken, .ExclamationEqualsEqualsToken => {
            const left = getReferenceCandidate(c, binExpr.Left);
            const right = getReferenceCandidate(c, binExpr.Right);
            const leftKind = c.binder.ast.getKind(left);
            const rightKind = c.binder.ast.getKind(right);

            if (leftKind == .TypeOfExpression and ast_utils.isStringLiteralLike(c.binder.ast, right)) {
                return narrowTypeByTypeof(c, f, t, c.binder.ast.getNode(left).TypeOfExpression.Expression, operator, right, assumeTrue);
            }
            if (rightKind == .TypeOfExpression and ast_utils.isStringLiteralLike(c.binder.ast, left)) {
                return narrowTypeByTypeof(c, f, t, c.binder.ast.getNode(right).TypeOfExpression.Expression, operator, left, assumeTrue);
            }
            if (isMatchingReference(c, f.reference, left)) {
                return narrowTypeByEquality(c, t, operator, right, assumeTrue);
            }
            if (isMatchingReference(c, f.reference, right)) {
                return narrowTypeByEquality(c, t, operator, left, assumeTrue);
            }
            var currentT = t;
            if (c.strictNullChecks) {
                if (optionalChainContainsReference(c, left, f.reference)) {
                    currentT = narrowTypeByOptionalChainContainment(c, f, currentT, operator, right, assumeTrue);
                } else if (optionalChainContainsReference(c, right, f.reference)) {
                    currentT = narrowTypeByOptionalChainContainment(c, f, currentT, operator, left, assumeTrue);
                }
            }
            const leftAccess = getDiscriminantPropertyAccess(c, f, left, currentT);
            if (leftAccess != null) {
                return narrowTypeByDiscriminantProperty(c, currentT, leftAccess.?, operator, right, assumeTrue);
            }
            const rightAccess = getDiscriminantPropertyAccess(c, f, right, currentT);
            if (rightAccess != null) {
                return narrowTypeByDiscriminantProperty(c, currentT, rightAccess.?, operator, left, assumeTrue);
            }
            if (isMatchingConstructorReference(c, f, left)) {
                return narrowTypeByConstructor(c, currentT, operator, right, assumeTrue);
            }
            if (isMatchingConstructorReference(c, f, right)) {
                return narrowTypeByConstructor(c, currentT, operator, left, assumeTrue);
            }
            if (ast_utils.isBooleanLiteral(c.binder.ast, right) and !ast_utils.isAccessExpression(c.binder.ast, left)) {
                return narrowTypeByBooleanComparison(c, f, currentT, left, right, operator, assumeTrue);
            }
            if (ast_utils.isBooleanLiteral(c.binder.ast, left) and !ast_utils.isAccessExpression(c.binder.ast, right)) {
                return narrowTypeByBooleanComparison(c, f, currentT, right, left, operator, assumeTrue);
            }
            return currentT;
        },
        .InstanceOfKeyword => {
            return narrowTypeByInstanceof(c, f, t, expr, assumeTrue);
        },
        .InKeyword => {
            if (c.binder.ast.getKind(binExpr.Left) == .PrivateIdentifier) {
                return narrowTypeByPrivateIdentifierInInExpression(c, f, t, expr, assumeTrue);
            }
            return narrowTypeByInExpression(c, f, t, expr, assumeTrue);
        },
        .CommaToken => {
            return narrowType(c, f, t, binExpr.Right, assumeTrue);
        },
        .AmpersandAmpersandToken => {
            if (assumeTrue) {
                return narrowType(c, f, narrowType(c, f, t, binExpr.Left, true), binExpr.Right, true);
            }
            const leftType = narrowType(c, f, t, binExpr.Left, false);
            const rightType = narrowType(c, f, t, binExpr.Right, false);
            return Checker.getUnionTypeFromArray(c, &[_]types.TypeIndex{ leftType, rightType });
        },
        .BarBarToken => {
            if (assumeTrue) {
                const leftType = narrowType(c, f, t, binExpr.Left, true);
                const rightType = narrowType(c, f, t, binExpr.Right, true);
                return Checker.getUnionTypeFromArray(c, &[_]types.TypeIndex{ leftType, rightType });
            }
            return narrowType(c, f, narrowType(c, f, t, binExpr.Left, false), binExpr.Right, false);
        },
        else => {},
    }
    return t;
}

fn filterDiscriminant(c: *Checker, t: types.TypeIndex, ctx: anytype) bool {
    const discriminantType = c.getTypeOfPropertyOrIndexSignatureOfType(t, ctx.propName) orelse c.getUnknownType() catch unreachable;
    return (Checker.getTypeFlags(c, discriminantType) & types.TypeFlags.Never) == 0 and
        (Checker.getTypeFlags(c, ctx.narrowedPropType) & types.TypeFlags.Never) == 0 and
        relater.areTypesComparable(c, ctx.narrowedPropType, discriminantType);
}

fn isNonNullAccess(c: *Checker, node: ast_gen.NodeIndex) bool {
    return ast_utils.isAccessExpression(c.binder.ast, node) and std.meta.activeTag(c.binder.ast.getNode(ast_utils.getExpressionOfNode(c.binder.ast, node))) == .NonNullExpression;
}

fn narrowTypeByDiscriminant(c: *Checker, t: types.TypeIndex, access: ast_gen.NodeIndex, comptime narrowTypeFn: anytype, ctx: anytype) types.TypeIndex {
    const propName = getAccessedPropertyName(c, access);
    if (propName == null) {
        return t;
    }
    const optionalChain = ast_utils.isOptionalChain(c.binder.ast, access);
    const removeNullable = c.strictNullChecks and (optionalChain or isNonNullAccess(c, access)) and Checker.maybeTypeOfKind(c, t, types.TypeFlags.Nullable);
    const nonNullType = if (removeNullable) Checker.getAdjustedTypeWithFacts(c, t, types.TypeFacts.NEUndefinedOrNull) else t;

    var propType = Checker.getTypeOfPropertyOfType(c, nonNullType, propName.?);
    if (propType == 0) {
        return t;
    }
    if (removeNullable and optionalChain) {
        propType = Checker.getOptionalType(c, propType, false);
    }
    const narrowedPropType = narrowTypeFn(c, propType, ctx);

    const Ctx = struct {
        propName: []const u8,
        narrowedPropType: types.TypeIndex,
    };

    const narrowedType = Checker.filterType(c, nonNullType, filterDiscriminant, Ctx{ .propName = propName.?, .narrowedPropType = narrowedPropType });
    if (narrowedType == nonNullType) {
        return t;
    }
    return narrowedType;
}
// -----------------------

pub fn narrowType(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    if (ast_utils.isExpressionOfOptionalChainRoot(c.binder.ast, expr)) {
        return narrowTypeByOptionality(c, f, t, expr, assumeTrue);
    }

    const parent = ast_utils.getParent(c.binder.ast, expr);
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
                const symbolId = checker_mod.getResolvedSymbol(c, expr);
                if (symbolId != 0 and utilities.isConstantVariable(c, &c.binder.symbols.items[symbolId])) {
                    const decl = c.getSymbolValueDeclaration(symbolId);
                    if (decl != 0 and std.meta.activeTag(c.binder.ast.getNode(decl)) == .VariableDeclaration) {
                        const varDecl = c.binder.ast.getNode(decl).VariableDeclaration;
                        if (varDecl.Type == null and varDecl.Initializer != null and isConstantReference(c, f.reference)) {
                            c.inlineLevel += 1;
                            const result = narrowType(c, f, t, varDecl.Initializer.?, assumeTrue);
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
            if (prefix.Operator == 52) { // ExclamationToken
                return narrowType(c, f, t, prefix.Operand, !assumeTrue);
            }
        },
        else => {},
    }
    return t;
}

const NarrowTypeByTruthinessCtx = struct {
    assumeTrue: bool,
};

fn narrowTypeByTruthinessMap(c: *Checker, t: types.TypeIndex, ctx: NarrowTypeByTruthinessCtx) types.TypeIndex {
    return Checker.getAdjustedTypeWithFacts(c, t, if (ctx.assumeTrue) types.TypeFacts.Truthy else types.TypeFacts.Falsy);
}

pub fn narrowTypeByTruthiness(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast_gen.NodeIndex, assumeTrue: bool) types.TypeIndex {
    if (isMatchingReference(c, f.reference, expr)) {
        return Checker.getAdjustedTypeWithFacts(c, t, if (assumeTrue) types.TypeFacts.Truthy else types.TypeFacts.Falsy);
    }
    var currentT = t;
    if (c.strictNullChecks and assumeTrue and optionalChainContainsReference(c, expr, f.reference)) {
        currentT = Checker.getAdjustedTypeWithFacts(c, currentT, types.TypeFacts.NEUndefinedOrNull);
    }
    if (getDiscriminantPropertyAccess(c, f, expr, currentT)) |access| {
        return narrowTypeByDiscriminant(c, currentT, access, narrowTypeByTruthinessMap, NarrowTypeByTruthinessCtx{ .assumeTrue = assumeTrue });
    }
    return currentT;
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

fn replacePrimitivesWithLiterals(c: *Checker, typeWithPrimitives: types.TypeIndex, typeWithLiterals: types.TypeIndex) types.TypeIndex {
    if (Checker.maybeTypeOfKind(c, typeWithPrimitives, types.TypeFlags.String | types.TypeFlags.TemplateLiteral | types.TypeFlags.Number | types.TypeFlags.BigInt) and
        Checker.maybeTypeOfKind(c, typeWithLiterals, types.TypeFlags.StringLiteral | types.TypeFlags.TemplateLiteral | types.TypeFlags.StringMapping | types.TypeFlags.NumberLiteral | types.TypeFlags.BigIntLiteral))
    {
        const Ctx = struct {
            c: *Checker,
            typeWithLiterals: types.TypeIndex,
        };
        const ctx = Ctx{ .c = c, .typeWithLiterals = typeWithLiterals };

        const mapFn = struct {
            fn f(c_inner: *Checker, t: types.TypeIndex, ctx_inner: Ctx) types.TypeIndex {
                _ = c_inner;
                const flags = Checker.getTypeFlags(ctx_inner.c, t);
                if ((flags & types.TypeFlags.String) != 0) {
                    return Checker.extractTypesOfKind(ctx_inner.c, ctx_inner.typeWithLiterals, types.TypeFlags.String | types.TypeFlags.StringLiteral | types.TypeFlags.TemplateLiteral | types.TypeFlags.StringMapping);
                } else if (Checker.isPatternLiteralType(ctx_inner.c, t) and !Checker.maybeTypeOfKind(ctx_inner.c, ctx_inner.typeWithLiterals, types.TypeFlags.String | types.TypeFlags.TemplateLiteral | types.TypeFlags.StringMapping)) {
                    return Checker.extractTypesOfKind(ctx_inner.c, ctx_inner.typeWithLiterals, types.TypeFlags.StringLiteral);
                } else if ((flags & types.TypeFlags.Number) != 0) {
                    return Checker.extractTypesOfKind(ctx_inner.c, ctx_inner.typeWithLiterals, types.TypeFlags.Number | types.TypeFlags.NumberLiteral);
                } else if ((flags & types.TypeFlags.BigInt) != 0) {
                    return Checker.extractTypesOfKind(ctx_inner.c, ctx_inner.typeWithLiterals, types.TypeFlags.BigInt | types.TypeFlags.BigIntLiteral);
                } else {
                    return t;
                }
            }
        }.f;

        return Checker.mapType(c, typeWithPrimitives, mapFn, ctx);
    }
    return typeWithPrimitives;
}

fn isUnitLikeType(c: *Checker, t: types.TypeIndex) bool {
    const ty = Checker.getBaseConstraintOfType(c, t);
    if ((Checker.getTypeFlags(c, ty) & types.TypeFlags.Intersection) != 0) {
        const intTypes = c.getTypesFromIntersection(ty);
        for (intTypes) |intType| {
            if (isUnitType(c, intType)) return true;
        }
        return false;
    }
    return isUnitType(c, ty);
}

fn extractUnitType(c: *Checker, t: types.TypeIndex) types.TypeIndex {
    const ty = Checker.getBaseConstraintOfType(c, t);
    if ((Checker.getTypeFlags(c, ty) & types.TypeFlags.Intersection) != 0) {
        for (c.getTypesFromIntersection(ty)) |intType| {
            if (isUnitType(c, intType)) return intType;
        }
        return ty;
    }
    return ty;
}

fn isUnitType(c: *Checker, t: types.TypeIndex) bool {
    return (c.typesList.items[t].flags & types.TypeFlags.Unit) != 0;
}
// ------------------------------------------

fn getTypeOfSwitchClause(c: *Checker, clause: ast_gen.NodeIndex) types.TypeIndex {
    if (std.meta.activeTag(c.binder.ast.getNode(clause)) == .CaseClause) {
        const expression = c.binder.ast.getNode(clause).CaseClause.Expression;
        return Checker.getRegularTypeOfLiteralType(c, getTypeOfExpression(c, expression));
    }
    return (c.getNeverType() catch 0);
}

fn getSwitchClauseTypes(c: *Checker, switchStmtNode: ast_gen.NodeIndex) []const types.TypeIndex {
    const switchStmt = c.binder.ast.getNode(switchStmtNode).SwitchStatement;
    const caseBlock = c.binder.ast.getNode(switchStmt.CaseBlock).CaseBlock;
    const clauses = c.binder.ast.getNodeList(caseBlock.Clauses);

    var typesList = c.allocator.alloc(types.TypeIndex, clauses.len) catch unreachable;
    for (clauses, 0..) |clause, i| {
        typesList[i] = getTypeOfSwitchClause(c, clause);
    }
    return typesList;
}

fn narrowTypeBySwitchOnDiscriminant(c: *Checker, t: types.TypeIndex, data: anytype) types.TypeIndex {
    const switchTypes = getSwitchClauseTypes(c, data.switchStatement);
    if (switchTypes.len == 0) return t;

    const clauseTypes = switchTypes[@intCast(data.clauseStart)..@intCast(data.clauseEnd)];
    var hasDefaultClause = data.clauseStart == data.clauseEnd;
    for (clauseTypes) |ct| {
        if (ct == (c.getNeverType() catch 0)) {
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
        return Checker.getUnionTypeFromArray(c, if (groundClauseTypes.capacity == 0) clauseTypes else groundClauseTypes.items);
    }

    const discriminantType = Checker.getUnionTypeFromArray(c, clauseTypes);
    var caseType: types.TypeIndex = 0;
    if ((c.typesList.items[discriminantType].flags & types.TypeFlags.Never) != 0) {
        caseType = c.getNeverType() catch 0;
    } else {
        const CaseTypeCtx = struct { discriminantType: types.TypeIndex };
        const caseTypeFilter = struct {
            fn filter(chk: *Checker, t_idx: types.TypeIndex, ctx: CaseTypeCtx) bool {
                return relater.areTypesComparable(chk, ctx.discriminantType, t_idx);
            }
        }.filter;
        const filtered = Checker.filterType(c, t, caseTypeFilter, CaseTypeCtx{ .discriminantType = discriminantType });
        caseType = replacePrimitivesWithLiterals(c, filtered, discriminantType);
    }

    if (!hasDefaultClause) return caseType;

    const DefaultTypeCtx = struct {
        switchTypes: []const types.TypeIndex,
    };
    const defaultTypeFilter = struct {
        fn filter(chk: *Checker, t_idx: types.TypeIndex, ctx: DefaultTypeCtx) bool {
            if (!isUnitLikeType(chk, t_idx)) return true;
            var u = chk.getUndefinedType() catch 0;
            if ((chk.typesList.items[t_idx].flags & types.TypeFlags.Undefined) == 0) {
                u = Checker.getRegularTypeOfLiteralType(chk, extractUnitType(chk, t_idx));
            }
            for (ctx.switchTypes) |st| {
                if (isUnitType(chk, st) and relater.areTypesComparable(chk, st, u)) return false;
            }
            return true;
        }
    }.filter;

    const defaultType = Checker.filterType(c, t, defaultTypeFilter, DefaultTypeCtx{ .switchTypes = switchTypes });

    if ((c.typesList.items[caseType].flags & types.TypeFlags.Never) != 0) {
        return defaultType;
    }
    return Checker.getUnionTypeFromArray(c, &[_]types.TypeIndex{ caseType, defaultType });
}
fn getNotEqualFactsFromTypeofSwitch(start: usize, end: usize, witnesses: []const []const u8) u32 {
    var facts: u32 = types.TypeFacts.None;
    for (witnesses, 0..) |witness, i| {
        if ((i < start or i >= end) and witness.len > 0) {
            var f = types.TypeFacts.TypeofNEHostObject;
            if (std.mem.eql(u8, witness, "string")) {
                f = types.TypeFacts.TypeofNEString;
            } else if (std.mem.eql(u8, witness, "number")) {
                f = types.TypeFacts.TypeofNENumber;
            } else if (std.mem.eql(u8, witness, "bigint")) {
                f = types.TypeFacts.TypeofNEBigInt;
            } else if (std.mem.eql(u8, witness, "boolean")) {
                f = types.TypeFacts.TypeofNEBoolean;
            } else if (std.mem.eql(u8, witness, "symbol")) {
                f = types.TypeFacts.TypeofNESymbol;
            } else if (std.mem.eql(u8, witness, "undefined")) {
                f = types.TypeFacts.NEUndefined;
            } else if (std.mem.eql(u8, witness, "object")) {
                f = types.TypeFacts.TypeofNEObject;
            } else if (std.mem.eql(u8, witness, "function")) {
                f = types.TypeFacts.TypeofNEFunction;
            }
            facts = facts | f;
        }
    }
    return facts;
}

fn getSwitchClauseTypeOfWitnesses(c: *Checker, switchStmtNode: ast_gen.NodeIndex) ?[]const []const u8 {
    const switchStmt = c.binder.ast.getNode(switchStmtNode).SwitchStatement;
    const caseBlock = c.binder.ast.getNode(switchStmt.CaseBlock).CaseBlock;
    const clauses = c.binder.ast.getNodeList(caseBlock.Clauses);

    var witnesses = std.ArrayListUnmanaged([]const u8).empty;
    for (clauses) |clause| {
        if (std.meta.activeTag(c.binder.ast.getNode(clause)) == .CaseClause) {
            const expression = c.binder.ast.getNode(clause).CaseClause.Expression;
            if (!ast_utils.isStringLiteralLike(c.binder.ast, expression)) {
                witnesses.deinit(c.allocator);
                return null;
            }
            const text = ast_utils.getTextOfNode(c.binder.ast, expression);
            var contains = false;
            for (witnesses.items) |w| {
                if (std.mem.eql(u8, w, text)) {
                    contains = true;
                    break;
                }
            }
            if (!contains) {
                witnesses.append(c.allocator, text) catch unreachable;
            } else {
                witnesses.append(c.allocator, "") catch unreachable; // Need to match index, Go uses witnesses[i] = text
            }
        } else {
            witnesses.append(c.allocator, "") catch unreachable;
        }
    }

    // Wait, in Go:
    // witnesses := make([]string, len(clauses))
    // for i, clause := range clauses {
    //     if clause.Kind == ast.KindCaseClause {
    //         if text := clause.Expression().Text(); !slices.Contains(witnesses, text) { witnesses[i] = text }
    //     }
    // }
    // So my logic above is correct if I just assign at index. Let's fix it.

    var finalWitnesses = c.allocator.alloc([]const u8, clauses.len) catch unreachable;
    for (finalWitnesses) |*w| w.* = "";

    for (clauses, 0..) |clause, i| {
        if (std.meta.activeTag(c.binder.ast.getNode(clause)) == .CaseClause) {
            const expression = c.binder.ast.getNode(clause).CaseClause.Expression;
            if (!ast_utils.isStringLiteralLike(c.binder.ast, expression)) {
                return null;
            }
            const text = ast_utils.getTextOfNode(c.binder.ast, expression);
            var contains = false;
            for (finalWitnesses) |w| {
                if (std.mem.eql(u8, w, text)) {
                    contains = true;
                    break;
                }
            }
            if (!contains) {
                finalWitnesses[i] = text;
            }
        }
    }
    return finalWitnesses;
}

fn narrowTypeBySwitchOnTypeOf(c: *Checker, t: types.TypeIndex, data: anytype) types.TypeIndex {
    const witnessesOpt = getSwitchClauseTypeOfWitnesses(c, data.switchStatement);
    if (witnessesOpt == null) return t;
    const witnesses = witnessesOpt.?;

    const switchStmt = c.binder.ast.getNode(data.switchStatement).SwitchStatement;
    const caseBlock = c.binder.ast.getNode(switchStmt.CaseBlock).CaseBlock;
    const clauses = c.binder.ast.getNodeList(caseBlock.Clauses);

    var defaultIndex: ?usize = null;
    for (clauses, 0..) |clause, i| {
        if (std.meta.activeTag(c.binder.ast.getNode(clause)) == .DefaultClause) {
            defaultIndex = i;
            break;
        }
    }

    const clauseStart: usize = @intCast(data.clauseStart);
    const clauseEnd: usize = @intCast(data.clauseEnd);
    const hasDefaultClause = clauseStart == clauseEnd or (defaultIndex != null and defaultIndex.? >= clauseStart and defaultIndex.? < clauseEnd);

    if (hasDefaultClause) {
        const notEqualFacts = getNotEqualFactsFromTypeofSwitch(clauseStart, clauseEnd, witnesses);

        const Ctx = struct {
            c: *Checker,
            notEqualFacts: u32,
        };
        const ctx = Ctx{ .c = c, .notEqualFacts = notEqualFacts };

        const filterFn = struct {
            fn f(c_inner: *Checker, ty: types.TypeIndex, ctx_inner: Ctx) bool {
                return Checker.getTypeFacts(c_inner, ty, ctx_inner.notEqualFacts) == ctx_inner.notEqualFacts;
            }
        }.f;

        return Checker.filterType(c, t, filterFn, ctx);
    }

    const clauseWitnesses = witnesses[clauseStart..clauseEnd];
    var unionTypes = std.ArrayListUnmanaged(types.TypeIndex).empty;
    defer unionTypes.deinit(c.allocator);

    for (clauseWitnesses) |text| {
        if (text.len > 0) {
            unionTypes.append(c.allocator, narrowTypeByTypeName(c, t, text)) catch unreachable;
        } else {
            unionTypes.append(c.allocator, c.getNeverType() catch 0) catch unreachable;
        }
    }

    return Checker.getUnionTypeFromArray(c, unionTypes.items);
}

fn narrowTypeBySwitchOnTrue(c: *Checker, f: *FlowState, t: types.TypeIndex, data: anytype) types.TypeIndex {
    const switchStmt = c.binder.ast.getNode(data.switchStatement).SwitchStatement;
    const caseBlock = c.binder.ast.getNode(switchStmt.CaseBlock).CaseBlock;
    const clauses = c.binder.ast.getNodeList(caseBlock.Clauses);

    var defaultIndex: ?usize = null;
    for (clauses, 0..) |clause, i| {
        if (std.meta.activeTag(c.binder.ast.getNode(clause)) == .DefaultClause) {
            defaultIndex = i;
            break;
        }
    }

    const clauseStart: usize = @intCast(data.clauseStart);
    const clauseEnd: usize = @intCast(data.clauseEnd);
    const hasDefaultClause = clauseStart == clauseEnd or (defaultIndex != null and defaultIndex.? >= clauseStart and defaultIndex.? < clauseEnd);

    var currentT = t;
    for (clauses[0..clauseStart]) |clause| {
        if (std.meta.activeTag(c.binder.ast.getNode(clause)) == .CaseClause) {
            currentT = narrowType(c, f, currentT, c.binder.ast.getNode(clause).CaseClause.Expression, false);
        }
    }

    if (hasDefaultClause) {
        for (clauses[clauseEnd..]) |clause| {
            if (std.meta.activeTag(c.binder.ast.getNode(clause)) == .CaseClause) {
                currentT = narrowType(c, f, currentT, c.binder.ast.getNode(clause).CaseClause.Expression, false);
            }
        }
        return currentT;
    }

    var unionTypes = std.ArrayListUnmanaged(types.TypeIndex).empty;
    defer unionTypes.deinit(c.allocator);

    for (clauses[clauseStart..clauseEnd]) |clause| {
        if (std.meta.activeTag(c.binder.ast.getNode(clause)) == .CaseClause) {
            unionTypes.append(c.allocator, narrowType(c, f, currentT, c.binder.ast.getNode(clause).CaseClause.Expression, true)) catch unreachable;
        } else {
            unionTypes.append(c.allocator, c.getNeverType() catch 0) catch unreachable;
        }
    }

    return Checker.getUnionTypeFromArray(c, unionTypes.items);
}

fn narrowTypeBySwitchOptionalChainContainment(c: *Checker, t: types.TypeIndex, data: anytype, predicateId: u32) types.TypeIndex {
    const clauseStart: usize = @intCast(data.clauseStart);
    const clauseEnd: usize = @intCast(data.clauseEnd);
    if (clauseStart == clauseEnd) return t;

    const switchTypes = getSwitchClauseTypes(c, data.switchStatement);
    const clauseTypes = switchTypes[clauseStart..clauseEnd];

    var everyClauseChecks = true;
    for (clauseTypes) |ct| {
        if (predicateId == 1) {
            if ((Checker.getTypeFlags(c, ct) & (types.TypeFlags.Undefined | types.TypeFlags.Never)) != 0) {
                everyClauseChecks = false;
                break;
            }
        } else if (predicateId == 2) {
            const ctFlags = Checker.getTypeFlags(c, ct);
            if ((ctFlags & types.TypeFlags.Never) != 0 or ((ctFlags & types.TypeFlags.StringLiteral) != 0 and c.typesList.items[ct].data == .StringLiteral and std.mem.eql(u8, c.typesList.items[ct].data.StringLiteral.text, "undefined"))) {
                everyClauseChecks = false;
                break;
            }
        }
    }

    if (everyClauseChecks) {
        return Checker.getTypeWithFacts(c, t, types.TypeFacts.NEUndefinedOrNull);
    }
    return t;
}

fn getDiscriminantPropertyAccess(c: *Checker, f: *FlowState, expr: ast.NodeIndex, t: types.TypeIndex) ?ast.NodeIndex {
    _ = c;
    _ = f;
    _ = expr;
    _ = t;
    return null;
}
fn narrowTypeBySwitchOnDiscriminantProperty(c: *Checker, t: types.TypeIndex, access: ast_gen.NodeIndex, data: anytype) types.TypeIndex {
    const clauseStart: usize = @intCast(data.clauseStart);
    const clauseEnd: usize = @intCast(data.clauseEnd);

    if (clauseStart < clauseEnd and (Checker.getTypeFlags(c, t) & types.TypeFlags.Union) != 0) {
        if (getAccessedPropertyName(c, access)) |accessedName| {
            const keyPropertyName = relater.getKeyPropertyName(c, t);
            if (keyPropertyName.len > 0 and std.mem.eql(u8, keyPropertyName, accessedName)) {
                const switchTypes = getSwitchClauseTypes(c, data.switchStatement);
                const clauseTypes = switchTypes[clauseStart..clauseEnd];

                var unionConstituents: std.ArrayListUnmanaged(types.TypeIndex) = .empty;
                defer unionConstituents.deinit(c.allocator);

                for (clauseTypes) |ct| {
                    const candidate = relater.getConstituentTypeForKeyType(c, t, ct);
                    if (candidate != null) {
                        unionConstituents.append(c.allocator, candidate.?) catch @panic("OOM");
                    } else {
                        unionConstituents.append(c.allocator, c.unknownTypeIndex orelse 0) catch @panic("OOM");
                    }
                }

                const candidate = Checker.getUnionTypeFromArray(c, unionConstituents.items);
                if (candidate != (c.unknownTypeIndex orelse 0)) {
                    return candidate;
                }
            }
        }
    }

    const Ctx = struct {
        c: *Checker,
        data: @TypeOf(data),
    };
    const ctx = Ctx{ .c = c, .data = data };

    const narrowFn = struct {
        fn f_inner(c_inner: *Checker, ty: types.TypeIndex, ctx_inner: Ctx) types.TypeIndex {
            _ = c_inner;
            return narrowTypeBySwitchOnDiscriminant(ctx_inner.c, ty, ctx_inner.data);
        }
    }.f_inner;

    return narrowTypeByDiscriminant(c, t, access, narrowFn, ctx);
}
fn skipParentheses(c: *Checker, expr: ast.NodeIndex) ast.NodeIndex {
    _ = c;
    return expr;
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
    _ = c;
    _ = t;
    _ = initialType;
    return true;
}
fn isExhaustiveSwitchStatement(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}
fn getUnionOrEvolvingArrayType(c: *Checker, f: *FlowState, typesArray: []const types.TypeIndex, subtypeReduction: u32) types.TypeIndex {
    _ = c;
    _ = f;
    _ = subtypeReduction;
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
    _ = c;
    _ = f;
    return 1; // stub nonDottedNameCacheKey? Wait, let's just return 1
}

pub fn getTypeAtFlowLoopLabel(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex) FlowType {
    if (f.refKey == 0) {
        f.refKey = getFlowReferenceKey(c, f);
    }
    const nonDottedNameCacheKey = std.math.maxInt(u64);
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
    _ = c;
    return expr;
}
fn addEvolvingArrayElementType(c: *Checker, evolvedType: types.TypeIndex, arg: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = arg;
    return evolvedType;
}
fn getContextFreeTypeOfExpression(c: *Checker, expr: ast_gen.NodeIndex) types.TypeIndex {
    _ = c;
    _ = expr;
    return 0;
}
fn isTypeAssignableToKind(c: *Checker, t: types.TypeIndex, kindflags: u32) bool {
    return c.isTypeAssignableToKind(t, kindflags);
}
// ----------------------------------------

pub fn getTypeAtFlowArrayMutation(c: *Checker, f: *FlowState, flow: flow_ast.FlowNodeIndex) FlowType {
    if ((c.autoTypeIndex != null and f.declaredType == c.autoTypeIndex.?) or
        (c.autoArrayTypeIndex != null and f.declaredType == c.autoArrayTypeIndex.?))
    {
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
fn getTypePredicateArgument(c: *Checker, predicate: *const types.TypePredicate, callExpression: ast.NodeIndex) ?ast.NodeIndex {
    if (predicate.kind == .Identifier or predicate.kind == .AssertsIdentifier) {
        const arguments = c.binder.ast.getNodeList(callExpression);
        if (predicate.parameterIndex >= 0 and predicate.parameterIndex < arguments.len) {
            return arguments[@intCast(predicate.parameterIndex)];
        }
    } else {
        const invokedExpression = ast_utils.skipParentheses(c.binder.ast, c.binder.ast.getNode(callExpression).CallExpression.Expression);
        if (ast_utils.isAccessExpression(c.binder.ast, invokedExpression)) {
            const accessExpr = c.binder.ast.getNode(invokedExpression);
            if (std.meta.activeTag(accessExpr) == .PropertyAccessExpression) {
                return ast_utils.skipParentheses(c.binder.ast, accessExpr.PropertyAccessExpression.Expression);
            } else if (std.meta.activeTag(accessExpr) == .ElementAccessExpression) {
                return ast_utils.skipParentheses(c.binder.ast, accessExpr.ElementAccessExpression.Expression);
            }
        }
    }
    return null;
}

fn getEffectsSignature(c: *Checker, node: ast.NodeIndex) ?types.SignatureIndex {
    _ = c;
    _ = node;
    return null;
}
fn getTypePredicateOfSignature(c: *Checker, signature: types.SignatureIndex) ?*const types.TypePredicate {
    _ = c;
    _ = signature;
    return null;
}
fn isNullableType(c: *Checker, t: types.TypeIndex, ctx: void) bool {
    _ = ctx;
    return (c.typesList.items[t].flags & types.TypeFlags.Nullable) != 0;
}
const NarrowTypeByTypePredicateCtx = struct {
    t: types.TypeIndex,
    assumeTrue: bool,
    checkDerived: bool,
};
fn narrowTypeByTypePredicateMap(c: *Checker, t: types.TypeIndex, ctx: NarrowTypeByTypePredicateCtx) types.TypeIndex {
    return Checker.getNarrowedType(c, t, ctx.t, ctx.assumeTrue, ctx.checkDerived);
}
fn narrowTypeByTypePredicate(c: *Checker, f: *FlowState, t: types.TypeIndex, predicate: *const types.TypePredicate, callExpression: ast.NodeIndex, assumeTrue: bool) types.TypeIndex {
    if (predicate.t != null and !((c.typesList.items[t].flags & types.TypeFlags.Any) != 0 and (predicate.t.? == c.globalObjectType or predicate.t.? == c.globalFunctionType))) {
        const predicateArgument = getTypePredicateArgument(c, predicate, callExpression);
        if (predicateArgument != null) {
            if (isMatchingReference(c, f.reference, predicateArgument.?)) {
                return Checker.getNarrowedType(c, t, predicate.t.?, assumeTrue, false);
            }
            var currentT = t;
            if (c.strictNullChecks) {
                if (optionalChainContainsReference(c, predicateArgument.?, f.reference)) {
                    if ((assumeTrue and !c.hasTypeFacts(predicate.t.?, types.TypeFacts.EQUndefined)) or (!assumeTrue and everyType(c, predicate.t.?, isNullableType, {}))) {
                        currentT = Checker.getAdjustedTypeWithFacts(c, currentT, types.TypeFacts.NEUndefinedOrNull);
                    }
                }
            }
            const access = getDiscriminantPropertyAccess(c, f, predicateArgument.?, currentT);
            if (access != null) {
                return narrowTypeByDiscriminant(c, currentT, access.?, narrowTypeByTypePredicateMap, NarrowTypeByTypePredicateCtx{ .t = predicate.t.?, .assumeTrue = assumeTrue, .checkDerived = false });
            }
            return currentT;
        }
    }
    return t;
}

fn narrowTypeByAssertion(c: *Checker, f: *FlowState, t: types.TypeIndex, expr: ast.NodeIndex) types.TypeIndex {
    const node = ast_utils.skipParentheses(c.binder.ast, expr);
    const nodeData = c.binder.ast.getNode(node);
    if (std.meta.activeTag(nodeData) == .FalseKeyword) {
        return c.getNeverType() catch 0;
    }
    if (std.meta.activeTag(nodeData) == .BinaryExpression) {
        if (c.binder.ast.getKind(nodeData.BinaryExpression.OperatorToken) == .AmpersandAmpersandToken) {
            const narrowedLeft = narrowTypeByAssertion(c, f, t, nodeData.BinaryExpression.Left);
            return narrowTypeByAssertion(c, f, narrowedLeft, nodeData.BinaryExpression.Right);
        }
    }
    return narrowType(c, f, t, node, true);
}

fn getReturnTypeOfSignature(c: *Checker, signature: types.SignatureIndex) types.TypeIndex {
    _ = c;
    _ = signature;
    return 0;
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
                    const callNodeArgs = c.binder.ast.getNodeList(node);
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
        if (getAssignmentTargetKind(c, node) == 1) { // Compound
            const flowType = getTypeAtFlowNode(c, f, flowNode.antecedent);
            return .{ .typeIndex = getBaseTypeOfLiteralType(c, flowType.typeIndex), .incomplete = flowType.incomplete };
        }
        // AutoType and autoArrayType check
        // if (f.declaredType == c.autoType or f.declaredType == c.autoArrayType) { ... }

        var t = f.declaredType;
        if (ast_utils.isInCompoundLikeAssignment(c.binder.ast, node)) {
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
        // VariableDeclaration and expando properties...
        return .{ .typeIndex = f.declaredType };
    }

    // for (const _ in ref)
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
            // Call predicates checking
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
            // If exhaustive switch return false
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
