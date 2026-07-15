const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_utils = @import("../ast/ast_utils.zig");
const astnav_tokens = @import("../astnav/tokens.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const languageservice = @import("languageservice.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const ast_gen = @import("../ast/ast_generated.zig");

pub const InvocationKind = enum {
    call,
    type_args,
    contextual,
};

pub const CallInvocation = struct {
    node: ast_gen.NodeIndex,
};

pub const TypeArgsInvocation = struct {
    called: ast_gen.NodeIndex,
};

pub const ContextualInvocation = struct {
    signature: checker.types.SignatureIndex,
    node: ast_gen.NodeIndex,
    symbol: ast_gen.SymbolIndex,
};

pub const Invocation = union(InvocationKind) {
    call: CallInvocation,
    type_args: TypeArgsInvocation,
    contextual: ContextualInvocation,
};

pub const ArgumentListInfo = struct {
    isTypeParameterList: bool,
    invocation: Invocation,
    argumentsSpan: ast.TextRange,
    argumentIndex: usize,
    argumentCount: usize,
};

pub fn provideSignatureHelp(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    documentURI: lsproto.DocumentUri,
    position: lsproto.Position,
    context: ?lsproto.SignatureHelpContext,
) !?lsproto.SignatureHelp {
    const programAndFile = ls.tryGetProgramAndFile(documentURI.fileName()) orelse return null;
    const script = ls.getScript(programAndFile.file);
    const pos = ls.converters.*.lineAndCharacterToPosition(script, position);

    const help = try getSignatureHelpItems(
        ls,
        allocator,
        undefined, // context for cancellation
        pos,
        programAndFile.file,
        context,
    );
    return help;
}

pub fn getSignatureHelpItems(
    ls: *languageservice.LanguageService,
    allocator: std.mem.Allocator,
    ctx: *anyopaque, // context for cancellation
    position: u32,
    file: compiler.FileId,
    context: ?lsproto.SignatureHelpContext,
) !?lsproto.SignatureHelp {
    _ = allocator;
    _ = ctx;

    const typeChecker = ls.getTypeCheckerForFile(file);
    const tree = ls.getAst(file);
    const sourceFile = ls.getSourceFileNode(file);

    const startingToken = astnav_tokens.findPrecedingToken(sourceFile, tree, position);
    if (startingToken == 0) {
        return null;
    }

    // Emulate VS Code's trigger reason.
    const signatureHelpTriggerReasonKindNone: u32 = 0;
    const signatureHelpTriggerReasonKindInvoked: u32 = 1;
    const signatureHelpTriggerReasonKindCharacterTyped: u32 = 2;
    const signatureHelpTriggerReasonKindRetriggered: u32 = 3;
    _ = signatureHelpTriggerReasonKindNone;

    var triggerReasonKind = signatureHelpTriggerReasonKindInvoked;
    if (context) |c_ctx| {
        if (c_ctx.triggerKind == .TriggerCharacter) {
            if (c_ctx.isRetrigger) {
                triggerReasonKind = signatureHelpTriggerReasonKindRetriggered;
            } else {
                triggerReasonKind = signatureHelpTriggerReasonKindCharacterTyped;
            }
        } else if (c_ctx.triggerKind == .ContentChange) {
            triggerReasonKind = signatureHelpTriggerReasonKindRetriggered;
        }
    }

    const onlyUseSyntacticOwners = triggerReasonKind == signatureHelpTriggerReasonKindCharacterTyped;

    const utilities = @import("utilities.zig");
    const hover = @import("hover.zig");
    if (onlyUseSyntacticOwners and (utilities.isInString(tree, position, startingToken) or hover.isInComment(ls, file, position, startingToken) != null)) {
        return null;
    }
    const isManuallyInvoked = triggerReasonKind == signatureHelpTriggerReasonKindInvoked;
    var argumentInfo = getContainingArgumentInfo(tree, startingToken, sourceFile, typeChecker, isManuallyInvoked, position) orelse return null;

    const candidateInfo = getCandidateOrTypeInfo(tree, &argumentInfo, typeChecker, sourceFile, startingToken, onlyUseSyntacticOwners) orelse return null;

    if (candidateInfo.candidateInfo) |c_info| {
        return createSignatureHelpItems(ls, c_info.candidates, c_info.resolvedSignature, &argumentInfo, sourceFile, typeChecker, onlyUseSyntacticOwners);
    }

    if (candidateInfo.typeInfo) |type_info| {
        return createTypeHelpItems(ls, type_info, &argumentInfo, sourceFile, typeChecker);
    }

    return null;
}

fn createTypeHelpItems(
    ls: *languageservice.LanguageService,
    symbol: ast_gen.SymbolIndex,
    argumentInfo: *ArgumentListInfo,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?lsproto.SignatureHelp {
    _ = ls;
    _ = symbol;
    _ = argumentInfo;
    _ = sourceFile;
    _ = c;
    return null;
    
}

fn createSignatureHelpItems(
    ls: *languageservice.LanguageService,
    candidates: []const checker.types.SignatureIndex,
    resolvedSignature: checker.types.SignatureIndex,
    argumentInfo: *ArgumentListInfo,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
    onlyUseSyntacticOwners: bool,
) ?lsproto.SignatureHelp {
    _ = onlyUseSyntacticOwners;

    var signatures = std.ArrayListUnmanaged(lsproto.SignatureInformation).empty;

    var selectedItemIndex: usize = 0;
    var itemSeen: usize = 0;

    for (candidates, 0..) |candidate, i| {
        _ = i;
        const signatureStr = c.signatureToStringEx(candidate, sourceFile, 0, null);

        const params = c.getExpandedParameters(candidate, false);
        const paramList = params;

        var paramInfos = std.ArrayListUnmanaged(lsproto.ParameterInformation).empty;

        for (paramList) |paramSym| {
            const symStr = c.symbolToString(paramSym);
            const typeIdx = c.getTypeOfSymbol(paramSym) catch 0;
            const typeStr = if (typeIdx != 0) c.typeToString(typeIdx, 0, 0, null) else "";

            const labelStr = if (typeStr.len > 0) std.fmt.allocPrint(ls.allocator, "{s}: {s}", .{ symStr, typeStr }) catch symStr else symStr;

            paramInfos.append(ls.allocator, lsproto.ParameterInformation{
                .label = labelStr,
                .documentation = null,
            }) catch unreachable;
        }

        var activeParam: ?u32 = null;
        if (paramList.len > 0) {
            const argIdx = @as(u32, @intCast(argumentInfo.argumentIndex));
            activeParam = if (argIdx >= paramList.len) @as(u32, @intCast(paramList.len - 1)) else argIdx;
        }

        if (candidate == resolvedSignature) {
            selectedItemIndex = itemSeen;
        }

        signatures.append(ls.allocator, lsproto.SignatureInformation{
            .label = signatureStr,
            .documentation = null,
            .parameters = paramInfos.items,
            .activeParameter = activeParam,
        }) catch unreachable;

        itemSeen += 1;
    }

    if (signatures.items.len == 0) return null;

    const activeSignature: ?u32 = @as(u32, @intCast(selectedItemIndex));
    return lsproto.SignatureHelp{
        .signatures = signatures.items,
        .activeSignature = activeSignature,
        .activeParameter = null,
    };
}

pub const CandidateOrTypeInfo = struct {
    candidateInfo: ?CandidateInfo,
    typeInfo: ?ast_gen.SymbolIndex,
};

pub const CandidateInfo = struct {
    candidates: []const checker.types.SignatureIndex,
    resolvedSignature: checker.types.SignatureIndex,
};

pub fn getContainingArgumentInfo(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
    isManuallyInvoked: bool,
    position: u32,
) ?ArgumentListInfo {
    var firstArgumentInfo: ?ArgumentListInfo = null;
    var n = node;
    while (n != sourceFile) : (n = tree.parents.items[n]) {
        if (!isManuallyInvoked) {
            const kind = std.meta.activeTag(tree.getNode(n));
            if (kind == .Block) break;
        }

        const argumentInfo = getImmediatelyContainingArgumentOrContextualParameterInfo(tree, n, position, sourceFile, c);
        if (argumentInfo) |info| {
            if (info.invocation == .contextual) {
                return info;
            }

            if (firstArgumentInfo == null) {
                firstArgumentInfo = info;
            }

            if (info.argumentsSpan.end == position) {
                return info;
            }

            if (info.argumentsSpan.pos <= position and position < info.argumentsSpan.end) {
                return info;
            }
        }
    }

    return firstArgumentInfo;
}

fn getImmediatelyContainingArgumentOrContextualParameterInfo(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    position: u32,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?ArgumentListInfo {
    if (tryGetParameterInfo(tree, node, sourceFile, c)) |result| {
        return result;
    }
    return getImmediatelyContainingArgumentInfo(tree, node, position, sourceFile, c);
}

fn tryGetParameterInfo(
    tree: *ast.Ast,
    startingToken: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?ArgumentListInfo {
    const parent = tree.parents.items[startingToken];
    const parent_kind = std.meta.activeTag(tree.getNode(parent));

    if (parent_kind == .ParenthesizedExpression or parent_kind == .MethodDeclaration or parent_kind == .FunctionExpression or parent_kind == .ArrowFunction) {
        if (getArgumentOrParameterListInfo(tree, startingToken, sourceFile, c)) |info| {
            var contextualType: checker.types.TypeIndex = 0;
            if (parent_kind == .MethodDeclaration) {
                contextualType = c.getContextualTypeForObjectLiteralElement(parent, 0);
            } else {
                contextualType = c.getContextualType(parent, 0);
            }

            if (contextualType != 0) {
                // For simplicity, just get signatures of contextualType
                const signatures = c.getSignaturesOfType(contextualType, .Call); // Call
                if (signatures.len > 0) {
                    const signature = c.resolvedSignaturesPool.items[signatures.start + signatures.len - 1];
                    const symbol = c.getSymbolOfType(contextualType);

                    return ArgumentListInfo{
                        .isTypeParameterList = false,
                        .invocation = .{
                            .contextual = .{
                                .signature = signature,
                                .node = startingToken,
                                .symbol = symbol,
                            },
                        },
                        .argumentsSpan = info.argumentsSpan,
                        .argumentIndex = info.argumentIndex,
                        .argumentCount = info.argumentCount,
                    };
                }
            }
        }
    } else if (parent_kind == .BinaryExpression) {
        const highestBinary = getHighestBinary(tree, parent);
        const contextualType = c.getContextualType(highestBinary, 0);
        
        var argumentIndex: usize = 0;
        if (std.meta.activeTag(tree.getNode(startingToken)) != .OpenParenToken) {
            argumentIndex = countBinaryExpressionParameters(tree, parent) - 1;
            const argumentCount = countBinaryExpressionParameters(tree, highestBinary);
            if (contextualType != 0) {
                // For simplicity, just get signatures of contextualType
                const signatures = c.getSignaturesOfType(contextualType, .Call); // Call
                if (signatures.len > 0) {
                    const signature = c.resolvedSignaturesPool.items[signatures.start + signatures.len - 1];
                    const symbol = c.getSymbolOfType(contextualType);

                    return ArgumentListInfo{
                        .isTypeParameterList = false,
                        .invocation = .{
                            .contextual = .{
                                .signature = signature,
                                .node = startingToken,
                                .symbol = symbol,
                            },
                        },
                        .argumentsSpan = .{ .pos = tree.getNodePos(parent), .end = tree.getNodeEnd(parent) },
                        .argumentIndex = argumentIndex,
                        .argumentCount = argumentCount,
                    };
                }
            }
        }
    }

    return null;
}

fn getImmediatelyContainingArgumentInfo(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    position: u32,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?ArgumentListInfo {
    const node_kind = std.meta.activeTag(tree.getNode(node));
    const parent = tree.parents.items[node];
    const parent_kind = std.meta.activeTag(tree.getNode(parent));

    if (parent_kind == .CallExpression or parent_kind == .NewExpression) {
        if (getArgumentOrParameterListAndIndex(tree, node, sourceFile, c)) |listInfo| {
            var isTypeParameterList = false;
            if (parent_kind == .CallExpression) {
                const typeArgs = tree.getNode(parent).CallExpression.TypeArguments;
                if (typeArgs != 0 and typeArgs == listInfo.list) isTypeParameterList = true;
            } else if (parent_kind == .NewExpression) {
                if (tree.getNode(parent).NewExpression.TypeArguments) |typeArgs| {
                    if (typeArgs != 0 and typeArgs == listInfo.list) isTypeParameterList = true;
                }
            }
            
            var invocation = Invocation{ .call = .{ .node = parent } };
            if (isTypeParameterList) {
                const expression = if (parent_kind == .CallExpression) tree.getNode(parent).CallExpression.Expression else tree.getNode(parent).NewExpression.Expression;
                invocation = .{ .type_args = .{ .called = expression } };
            }

            const argumentCount = getArgumentCount(tree, node, listInfo.list, sourceFile, c);
            const argumentsSpan = getApplicableSpanForArguments(tree, listInfo.list, node, sourceFile);

            return ArgumentListInfo{
                .isTypeParameterList = isTypeParameterList,
                .invocation = invocation,
                .argumentsSpan = argumentsSpan,
                .argumentIndex = listInfo.argumentIndex,
                .argumentCount = argumentCount,
            };
        }
    } else if (node_kind == .NoSubstitutionTemplateLiteral and parent_kind == .TaggedTemplateExpression) {
        if (isInsideTemplateLiteral(tree, node, position, sourceFile)) {
            return getArgumentListInfoForTemplate(tree, parent, 0, sourceFile);
        }
    } else if (node_kind == .TemplateHead and parent_kind == .TemplateExpression) {
        const grandparent = tree.parents.items[parent];
        if (std.meta.activeTag(tree.getNode(grandparent)) == .TaggedTemplateExpression) {
            return getArgumentListInfoForTemplate(tree, grandparent, 1, sourceFile);
        }
    } else if (parent_kind == .TemplateSpan) {
        const grandparent = tree.parents.items[parent];
        if (std.meta.activeTag(tree.getNode(grandparent)) == .TemplateExpression) {
            const greatgrandparent = tree.parents.items[grandparent];
            if (std.meta.activeTag(tree.getNode(greatgrandparent)) == .TaggedTemplateExpression) {
                var argumentIndex: usize = 1;
                const templateExpr = tree.getNode(grandparent).TemplateExpression;
                if (templateExpr.TemplateSpans != 0) {
                    const spans = tree.getNodeList(templateExpr.TemplateSpans);
                    for (spans) |span| {
                        if (span == parent) break;
                        argumentIndex += 1;
                    }
                }
                return getArgumentListInfoForTemplate(tree, greatgrandparent, argumentIndex, sourceFile);
            }
        }
    }

    return null;
}

fn isInsideTemplateLiteral(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    position: u32,
    sourceFile: ast_gen.NodeIndex,
) bool {
    _ = sourceFile;
    const kind = std.meta.activeTag(tree.getNode(node));
    if (kind != .NoSubstitutionTemplateLiteral and kind != .TemplateHead and kind != .TemplateMiddle and kind != .TemplateTail) {
        return false;
    }
    const pos = tree.getNodePos(node);
    const end = tree.getNodeEnd(node);
    return pos < position and position <= end;
}

fn getArgumentListInfoForTemplate(
    tree: *ast.Ast,
    tagExpression: ast_gen.NodeIndex,
    argumentIndex: usize,
    sourceFile: ast_gen.NodeIndex,
) ?ArgumentListInfo {
    _ = sourceFile;
    const tagged = tree.getNode(tagExpression).TaggedTemplateExpression;
    var argumentCount: usize = 1;
    const template = tagged.Template;
    
    if (template != 0) {
        if (std.meta.activeTag(tree.getNode(template)) != .NoSubstitutionTemplateLiteral) {
            const templateExpr = tree.getNode(template).TemplateExpression;
            if (templateExpr.TemplateSpans != 0) {
                const spans = tree.getNodeList(templateExpr.TemplateSpans);
                argumentCount = spans.len + 1;
            }
        }
    }

    var pos: u32 = 0;
    var end: u32 = 0;
    if (template != 0) {
        pos = tree.getNodePos(template);
        end = tree.getNodeEnd(template);
    }

    return ArgumentListInfo{
        .isTypeParameterList = false,
        .invocation = .{ .call = .{ .node = tagExpression } },
        .argumentsSpan = .{ .pos = pos, .end = end },
        .argumentIndex = argumentIndex,
        .argumentCount = argumentCount,
    };
}

const ArgumentOrParameterListAndIndex = struct {
    list: ast_gen.NodeIndex,
    argumentIndex: usize,
};

fn getArgumentOrParameterListInfo(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?ArgumentListInfo {
    if (getArgumentOrParameterListAndIndex(tree, node, sourceFile, c)) |info| {
        const argumentCount = getArgumentCount(tree, node, info.list, sourceFile, c);
        const argumentsSpan = getApplicableSpanForArguments(tree, info.list, node, sourceFile);
        return ArgumentListInfo{
            .isTypeParameterList = false, // handled in caller
            .invocation = .{ .call = .{ .node = 0 } }, // dummy
            .argumentsSpan = argumentsSpan,
            .argumentIndex = info.argumentIndex,
            .argumentCount = argumentCount,
        };
    }
    return null;
}

fn getArgumentOrParameterListAndIndex(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) ?ArgumentOrParameterListAndIndex {
    const node_kind = std.meta.activeTag(tree.getNode(node));
    if (node_kind == .LessThanToken or node_kind == .OpenParenToken) {
        const parent = tree.parents.items[node];
        if (getChildListThatStartsWithOpenerToken(tree, parent, node)) |list| {
            return ArgumentOrParameterListAndIndex{
                .list = list,
                .argumentIndex = 0,
            };
        }
    } else {
        if (findContainingList(tree, node, sourceFile)) |list| {
            return ArgumentOrParameterListAndIndex{
                .list = list,
                .argumentIndex = getArgumentIndex(tree, node, list, sourceFile, c),
            };
        }
    }
    return null;
}

fn getChildListThatStartsWithOpenerToken(
    tree: *ast.Ast,
    parent: ast_gen.NodeIndex,
    openerToken: ast_gen.NodeIndex,
) ?ast_gen.NodeIndex {
    const parent_node = tree.getNode(parent);
    const opener_kind = std.meta.activeTag(tree.getNode(openerToken));

    switch (parent_node) {
        .CallExpression => |call_expr| {
            if (opener_kind == .LessThanToken) {
                if (call_expr.TypeArguments) |v| if (v != 0) return v;
                return null;
            }
            if (call_expr.Arguments != 0) return call_expr.Arguments;
            return null;
        },
        .NewExpression => |new_expr| {
            if (opener_kind == .LessThanToken) {
                if (new_expr.TypeArguments) |v| if (v != 0) return v;
                return null;
            }
            if (new_expr.Arguments) |v| if (v != 0) return v;
            return null;
        },
        else => return null,
    }
}

fn findContainingList(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
) ?ast_gen.NodeIndex {
    _ = sourceFile;
    const parent = tree.parents.items[node];
    const parent_node = tree.getNode(parent);

    const nodePos = tree.getNodePos(node);
    switch (parent_node) {
        .CallExpression => |call_expr| {
            if (call_expr.TypeArguments) |targs| {
                if (targs != 0 and nodePos >= tree.getNodePos(targs) and nodePos < tree.getNodeEnd(targs)) return targs;
            }
            if (call_expr.Arguments != 0) return call_expr.Arguments;
        },
        .NewExpression => |new_expr| {
            if (new_expr.TypeArguments) |targs| {
                if (targs != 0 and nodePos >= tree.getNodePos(targs) and nodePos < tree.getNodeEnd(targs)) return targs;
            }
            if (new_expr.Arguments) |args| if (args != 0) return args;
        },
        else => {},
    }
    return null;
}

fn getArgumentIndex(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    list: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) usize {
    _ = sourceFile;
    _ = c;
    const items = tree.getNodeList(list);
    if (items.len == 0) return 0;

    // If node is exactly in the list:
    for (items, 0..) |item, i| {
        if (item == node) return i;
    }

    // If node is a token (like comma), check its pos
    const node_pos = tree.getNodePos(node);
    for (items, 0..) |item, i| {
        if (node_pos < tree.getNodeEnd(item)) {
            return i;
        }
    }

    return items.len;
}

fn getArgumentCount(
    tree: *ast.Ast,
    node: ast_gen.NodeIndex,
    list: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
    c: *checker.Checker,
) usize {
    _ = node;

    _ = c;
    const items = tree.getNodeList(list);
    const listCount = items.len;
    if (listCount == 0) return 0;
    
    var hasTrailingComma = false;
    const lastItem = items[listCount - 1];
    const token = @import("../astnav/tokens.zig").getTokenAtPosition(sourceFile, tree, tree.getNodeEnd(lastItem));
    if (token != 0 and tree.getNodeKind(token) == .CommaToken) {
        hasTrailingComma = true;
    }
    if (hasTrailingComma) return listCount + 1;
    return listCount;
}

fn getApplicableSpanForArguments(
    tree: *ast.Ast,
    argumentList: ast_gen.NodeIndex,
    node: ast_gen.NodeIndex,
    sourceFile: ast_gen.NodeIndex,
) ast.TextRange {
    _ = node;
    _ = sourceFile;
    const items = tree.getNodeList(argumentList);
    if (items.len == 0) return .{ .pos = 0, .end = 0 };
    return .{
        .pos = tree.getNodePos(items[0]),
        .end = tree.getNodeEnd(items[items.len - 1]),
    };
}

pub fn getCandidateOrTypeInfo(
    tree: *ast.Ast,
    info: *ArgumentListInfo,
    c: *checker.Checker,
    sourceFile: ast_gen.NodeIndex,
    startingToken: ast_gen.NodeIndex,
    onlyUseSyntacticOwners: bool,
) ?CandidateOrTypeInfo {
    _ = sourceFile;
    switch (info.invocation) {
        .call => |call| {
            if (onlyUseSyntacticOwners and !isSyntacticOwner(tree, startingToken, call.node)) {
                return null;
            }

            const res = checker.services_pkg.getResolvedSignatureForSignatureHelp(c, call.node, info.argumentCount);
            if (res.candidates.len == 0) return null;

            return CandidateOrTypeInfo{
                .candidateInfo = .{
                    .candidates = res.candidates,
                    .resolvedSignature = if (res.signature != 0) res.signature else res.candidates[0],
                },
                .typeInfo = null,
            };
        },
        .type_args => |type_args| {
            _ = type_args;
            return null;
        },
        .contextual => |contextual| {
            var candidates = c.allocator.alloc(checker.types.SignatureIndex, 1) catch unreachable;
            candidates[0] = contextual.signature;
            return CandidateOrTypeInfo{
                .candidateInfo = .{
                    .candidates = candidates,
                    .resolvedSignature = contextual.signature,
                },
                .typeInfo = null,
            };
        },
    }
}

fn containsPrecedingToken(
    tree: *ast.Ast,
    startingToken: ast_gen.NodeIndex,
    container: ast_gen.NodeIndex,
) bool {
    if (container == 0) return false;
    const container_pos = tree.getNodePos(container);
    const container_end = tree.getNodeEnd(container);
    const token_end = tree.getNodeEnd(startingToken);
    return container_pos <= token_end and token_end <= container_end;
}

fn isSyntacticOwner(
    tree: *ast.Ast,
    startingToken: ast_gen.NodeIndex,
    node: ast_gen.NodeIndex,
) bool {
    const node_kind = std.meta.activeTag(tree.getNode(node));
    if (node_kind == .Decorator) {
        return containsPrecedingToken(tree, startingToken, node);
    }
    if (node_kind == .JsxOpeningElement or node_kind == .JsxSelfClosingElement) {
        return containsPrecedingToken(tree, startingToken, node);
    }
    if (node_kind == .TaggedTemplateExpression) {
        const tagged = tree.getNode(node).TaggedTemplateExpression;
        if (tagged.Template != 0) return containsPrecedingToken(tree, startingToken, tagged.Template);
        return false;
    }
    if (node_kind == .CallExpression) {
        const call_expr = tree.getNode(node).CallExpression;
        if (call_expr.Arguments != 0) {
            return containsPrecedingToken(tree, startingToken, call_expr.Arguments);
        }
        if (call_expr.TypeArguments) |t| {
            if (t != 0) return containsPrecedingToken(tree, startingToken, t);
        }
        return containsPrecedingToken(tree, startingToken, call_expr.Expression);
    }
    if (node_kind == .NewExpression) {
        const new_expr = tree.getNode(node).NewExpression;
        if (new_expr.Arguments) |args| {
            if (args != 0) return containsPrecedingToken(tree, startingToken, args);
        }
        if (new_expr.TypeArguments) |t| {
            if (t != 0) return containsPrecedingToken(tree, startingToken, t);
        }
        return containsPrecedingToken(tree, startingToken, new_expr.Expression);
    }
    return false;
}

fn getHighestBinary(tree: *ast.Ast, b: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const parent = tree.getNodeParent(b);
    if (parent != 0 and std.meta.activeTag(tree.getNode(parent)) == .BinaryExpression) {
        return getHighestBinary(tree, parent);
    }
    return b;
}

fn countBinaryExpressionParameters(tree: *ast.Ast, b: ast_gen.NodeIndex) usize {
    const left = tree.getNode(b).BinaryExpression.Left;
    if (left != 0 and std.meta.activeTag(tree.getNode(left)) == .BinaryExpression) {
        return countBinaryExpressionParameters(tree, left) + 1;
    }
    return 2;
}
