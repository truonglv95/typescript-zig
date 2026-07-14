const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeIndex = ast_gen.NodeIndex;
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const nodebuilderimpl = @import("nodebuilderimpl.zig");
const NodeBuilderImpl = nodebuilderimpl.NodeBuilderImpl;
const types = @import("types.zig");
const TypeIndex = types.TypeIndex;

const pchecker = @import("../pseudochecker/checker.zig");
const PseudoChecker = pchecker.PseudoChecker;
const ptype = @import("../pseudochecker/type.zig");
const PseudoTypeIndex = ptype.PseudoTypeIndex;
const PseudoTypeKind = ptype.PseudoTypeKind;

pub fn pseudoTypeToNodeWithCheckerFallback(b: *NodeBuilderImpl, pc: *const PseudoChecker, t: PseudoTypeIndex, checkerType: TypeIndex) NodeIndex {
    const pType = pc.types.items[t];
    switch (pType) {
        .Inferred => |inferred| {
            if (!b.ctx.suppressReportInferenceFallback) {
                if (inferred.errorNodes.len > 0) {
                    for (inferred.errorNodes) |n| {
                        b.reportInferenceFallback(n);
                    }
                } else {
                    b.reportInferenceFallback(inferred.expression);
                }
            }
            const oldSuppress = b.ctx.suppressReportInferenceFallback;
            b.ctx.suppressReportInferenceFallback = true;
            const result = b.typeToTypeNode(checkerType);
            b.ctx.suppressReportInferenceFallback = oldSuppress;
            return result;
        },
        .Direct => |direct| {
            const existing = direct.typeNode;
            if (!b.existingTypeNodeIsNotReferenceOrIsReferenceWithCompatibleTypeArgumentCount(existing, checkerType)) {
                if (!b.ctx.suppressReportInferenceFallback) {
                    b.reportInferenceFallback(existing);
                }
                const oldSuppress = b.ctx.suppressReportInferenceFallback;
                b.ctx.suppressReportInferenceFallback = true;
                const result = b.typeToTypeNode(checkerType);
                b.ctx.suppressReportInferenceFallback = oldSuppress;
                return result;
            }
        },
        else => {},
    }
    return pseudoTypeToNode(b, pc, t);
}

pub fn pseudoTypeToNode(b: *NodeBuilderImpl, pc: *const PseudoChecker, t: PseudoTypeIndex) NodeIndex {
    const pType = pc.types.items[t];
    switch (pType) {
        .Direct => |direct| {
            return b.reuseTypeNode(direct.typeNode);
        },
        .Inferred => |inferred| {
            const node = inferred.expression;
            if (inferred.errorNodes.len > 0) {
                for (inferred.errorNodes) |n| {
                    b.reportInferenceFallback(n);
                }
            } else if (b.c.binder.ast.isEntityNameExpression(node) and b.c.binder.ast.isDeclaration(b.c.binder.ast.getParent(node))) {
                b.reportInferenceFallback(b.c.binder.ast.getParent(node));
            } else {
                b.reportInferenceFallback(node);
            }

            const parent = b.c.binder.ast.getParent(node);
            if (b.c.binder.ast.getNodeKind(parent) == .ReturnStatement) {
                const enclosing = b.c.binder.ast.getContainingFunction(node);
                if (b.c.binder.ast.isAccessor(enclosing)) {
                    return b.serializeTypeForDeclaration(enclosing, 0, 0, false);
                }
                return b.serializeReturnTypeForSignature(b.c.getSignatureFromDeclaration(enclosing), false);
            }
            if (b.c.binder.ast.getNodeKind(parent) == .ArrowFunction and b.c.binder.ast.getNode(parent).ArrowFunction.body == node) {
                return b.serializeReturnTypeForSignature(b.c.getSignatureFromDeclaration(parent), false);
            }
            if (b.c.binder.ast.isDeclaration(parent)) {
                return b.serializeTypeForDeclaration(parent, 0, 0, false);
            }

            const ty = b.c.getTypeOfExpression(node);
            return b.typeToTypeNode(ty);
        },
        .NoResult => |noResult| {
            const node = noResult.declaration;
            b.reportInferenceFallback(node);
            if (b.c.binder.ast.isFunctionLike(node) and !b.c.binder.ast.isAccessor(node)) {
                return b.serializeReturnTypeForSignature(b.c.getSignatureFromDeclaration(node), false);
            }
            return b.serializeTypeForDeclaration(node, 0, 0, false);
        },
        .MaybeConstLocation => |maybeConst| {
            var isInConstContext = b.c.isConstContext(maybeConst.node);
            if (!isInConstContext and pchecker.isInConstContext(maybeConst.node)) {
                const contextualType = b.c.getContextualType(maybeConst.node, .{});
                const constTy = pseudoTypeToType(b, pc, maybeConst.constType);
                if (constTy != 0 and b.c.isLiteralOfContextualType(constTy, b.c.instantiateContextualType(contextualType, maybeConst.node, .{}))) {
                    isInConstContext = true;
                }
            }
            if (isInConstContext) {
                return pseudoTypeToNode(b, pc, maybeConst.constType);
            } else {
                return pseudoTypeToNode(b, pc, maybeConst.regularType);
            }
        },
        .Union => |union_data| {
            var res = std.ArrayList(NodeIndex).init(b.c.allocator);
            defer res.deinit();
            var hasElidedType = false;
            var hasUndefined = false;

            for (union_data.types) |m_idx| {
                const mType = pc.types.items[m_idx];
                if (!b.c.strictNullChecks) {
                    switch (mType) {
                        .Undefined, .Null => {
                            hasElidedType = true;
                            continue;
                        },
                        else => {},
                    }
                }
                const n = pseudoTypeToNode(b, pc, m_idx);
                if (b.c.binder.ast.getNodeKind(n) == .UnionTypeNode) {
                    res.append(n) catch {};
                } else if (b.c.binder.ast.getNodeKind(n) == .UndefinedKeyword) {
                    if (!hasUndefined) {
                        hasUndefined = true;
                        res.append(n) catch {};
                    }
                } else {
                    res.append(n) catch {};
                }
            }
            if (res.items.len == 1) return res.items[0];
            if (res.items.len == 0) {
                if (hasElidedType) return b.newKeywordTypeNode(.AnyKeyword);
                return b.newKeywordTypeNode(.NeverKeyword);
            }
            const nodeList = b.newNodeList(res.items);
            return b.newUnionTypeNode(nodeList);
        },
        .Undefined => {
            if (!b.c.strictNullChecks) return b.newKeywordTypeNode(.AnyKeyword);
            return b.newKeywordTypeNode(.UndefinedKeyword);
        },
        .Null => {
            if (!b.c.strictNullChecks) return b.newKeywordTypeNode(.AnyKeyword);
            return b.newLiteralTypeNode(b.newKeywordExpression(.NullKeyword));
        },
        .Any => return b.newKeywordTypeNode(.AnyKeyword),
        .String => return b.newKeywordTypeNode(.StringKeyword),
        .Number => return b.newKeywordTypeNode(.NumberKeyword),
        .BigInt => return b.newKeywordTypeNode(.BigIntKeyword),
        .Boolean => return b.newKeywordTypeNode(.BooleanKeyword),
        .False => return b.newLiteralTypeNode(b.newKeywordExpression(.FalseKeyword)),
        .True => return b.newLiteralTypeNode(b.newKeywordExpression(.TrueKeyword)),
        .SingleCallSignature => |sig_data| {
            const signature = b.c.getSignatureFromDeclaration(sig_data.signature);
            const expandedParams = b.c.getExpandedParameters(signature, true);
            const cleanup = b.enterNewScope(sig_data.signature, if (expandedParams.len > 0) expandedParams[0] else 0, signature.typeParameters, signature.parameters, signature.mapper);
            defer cleanup();

            var typeParamsList: NodeIndex = 0;
            if (sig_data.typeParameters.len > 0) {
                var tpRes = std.ArrayList(NodeIndex).init(b.c.allocator);
                defer tpRes.deinit();
                for (sig_data.typeParameters) |tp| {
                    tpRes.append(b.reuseNode(tp)) catch {};
                }
                typeParamsList = b.newNodeList(tpRes.items);
            }
            const params = pseudoParametersToNodeList(b, pc, sig_data.parameters);
            const returnType = pseudoTypeToNode(b, pc, sig_data.returnType);
            return b.newFunctionTypeNode(typeParamsList, params, returnType);
        },
        .Tuple => |tuple_data| {
            var elementsRes = std.ArrayList(NodeIndex).init(b.c.allocator);
            defer elementsRes.deinit();
            for (tuple_data.elements) |e| {
                elementsRes.append(pseudoTypeToNode(b, pc, e)) catch {};
            }
            const result = b.newTupleTypeNode(b.newNodeList(elementsRes.items));
            b.addEmitFlags(result, .SingleLine);
            return b.newTypeOperatorNode(.ReadonlyKeyword, result);
        },
        .ObjectLiteral => |obj| {
            if (obj.elements.len == 0) {
                const result = b.newTypeLiteralNode(b.newNodeList(&[_]NodeIndex{}));
                b.addEmitFlags(result, .SingleLine);
                return result;
            }
            const isConst = b.c.isConstContext(b.c.binder.ast.getParent(b.c.binder.ast.getParent(obj.elements[0].name)));
            _ = isConst;
            var newElements = std.ArrayList(NodeIndex).init(b.c.allocator);
            defer newElements.deinit();

            const restoreFlags = b.saveRestoreFlags();
            defer restoreFlags();
            b.ctx.flags.InObjectTypeLiteral = true;

            for (obj.elements) |e| {
                newElements.append(b.newPropertySignatureDeclaration(0, e.name, 0, 0, 0)) catch {};
            }

            const result = b.newTypeLiteralNode(b.newNodeList(newElements.items));
            if (!b.ctx.flags.MultilineObjectLiterals) {
                b.addEmitFlags(result, .SingleLine);
            }
            return result;
        },
        .StringLiteral, .NumericLiteral, .BigIntLiteral => |lit| {
            return b.newLiteralTypeNode(b.reuseNode(lit.node));
        },
    }
}

pub fn pseudoParametersToNodeList(b: *NodeBuilderImpl, pc: *const PseudoChecker, params: []ptype.PseudoParameter) NodeIndex {
    var res = std.ArrayList(NodeIndex).init(b.c.allocator);
    defer res.deinit();
    for (params) |p| {
        res.append(pseudoParameterToNode(b, pc, p)) catch {};
    }
    return b.newNodeList(res.items);
}

pub fn pseudoParameterToNode(b: *NodeBuilderImpl, pc: *const PseudoChecker, p: ptype.PseudoParameter) NodeIndex {
    const dotDotDot = if (p.rest) b.newToken(.DotDotDotToken) else 0;
    const questionMark = if (p.optional) b.newToken(.QuestionToken) else 0;
    const parent = b.c.binder.ast.getParent(p.name);
    const sym = b.c.getSymbolOfNode(parent);
    const nameNode = b.parameterToParameterDeclarationName(sym, parent);
    const parameter = b.newParameterDeclaration(0, dotDotDot, nameNode, questionMark, pseudoTypeToNode(b, pc, p.type), 0);
    if (b.c.binder.ast.getNodeKind(parent) == .ParameterDeclaration) {
        b.setCommentRange(parameter, parent);
    }
    return parameter;
}

pub fn pseudoTypeEquivalentToType(b: *NodeBuilderImpl, pc: *const PseudoChecker, t: PseudoTypeIndex, type_idx: TypeIndex, isOptionalAnnotated: bool, reportErrors: bool) bool {
    _ = b;
    _ = pc;
    _ = t;
    _ = type_idx;
    _ = isOptionalAnnotated;
    _ = reportErrors;
    // Stub
    return false;
}

pub fn pseudoParametersEquivalentToParameters(b: *NodeBuilderImpl, pc: *const PseudoChecker, params: []ptype.PseudoParameter, targetSig: types.SignatureIndex, reportErrors: bool, nonParamErrorLocation: NodeIndex) bool {
    _ = b;
    _ = pc;
    _ = params;
    _ = targetSig;
    _ = reportErrors;
    _ = nonParamErrorLocation;
    // Stub
    return false;
}

pub fn isStructuralPseudoType(pc: *const PseudoChecker, t: PseudoTypeIndex) bool {
    const pType = pc.types.items[t];
    switch (pType) {
        .ObjectLiteral, .Tuple, .SingleCallSignature => return true,
        .MaybeConstLocation => |d| return isStructuralPseudoType(pc, d.constType) or isStructuralPseudoType(pc, d.regularType),
        else => return false,
    }
}

pub fn pseudoReturnTypeMatchesPredicate(b: *NodeBuilderImpl, pc: *const PseudoChecker, rt: PseudoTypeIndex, predicate: types.TypePredicate) bool {
    _ = b;
    _ = pc;
    _ = rt;
    _ = predicate;
    // Stub
    return false;
}

pub fn pseudoTypeToType(b: *NodeBuilderImpl, pc: *const PseudoChecker, t: PseudoTypeIndex) TypeIndex {
    const pType = pc.types.items[t];
    switch (pType) {
        .Direct => |d| return b.c.getTypeFromTypeNode(d.typeNode, false),
        .Inferred => |inferred| {
            const ty = b.c.getWidenedType(b.c.getRegularTypeOfExpression(inferred.expression));
            return ty;
        },
        .NoResult => return 0,
        .MaybeConstLocation => |d| {
            if (b.c.isConstContext(d.node)) {
                return pseudoTypeToType(b, pc, d.constType);
            }
            return pseudoTypeToType(b, pc, d.regularType);
        },
        .Union => |union_data| {
            var res = std.ArrayList(TypeIndex).init(b.c.allocator);
            defer res.deinit();
            var hasElidedType = false;
            for (union_data.types) |m_idx| {
                const mType = pc.types.items[m_idx];
                if (!b.c.strictNullChecks) {
                    switch (mType) {
                        .Undefined, .Null => {
                            hasElidedType = true;
                            continue;
                        },
                        else => {},
                    }
                }
                const pTy = pseudoTypeToType(b, pc, m_idx);
                if (pTy == 0) return 0;
                res.append(pTy) catch {};
            }
            if (res.items.len == 1) return res.items[0];
            if (res.items.len == 0) {
                if (hasElidedType) return b.c.anyType;
                return b.c.neverType;
            }
            return b.c.getUnionType(res.items);
        },
        .Undefined => return b.c.undefinedWideningType,
        .Null => return b.c.nullWideningType,
        .Any => return b.c.anyType,
        .String => return b.c.stringType,
        .Number => return b.c.numberType,
        .BigInt => return b.c.bigintType,
        .Boolean => return b.c.booleanType,
        .False => return b.c.falseType,
        .True => return b.c.trueType,
        .StringLiteral, .NumericLiteral, .BigIntLiteral => |lit| {
            return b.c.getRegularTypeOfExpression(lit.node);
        },
        .ObjectLiteral, .SingleCallSignature, .Tuple => return 0,
    }
}
