const ast_utils = @import("../ast/ast_utils.zig");
const std = @import("std");
const ast_gen = @import("../ast/ast_generated.zig");
const ast = @import("../ast/ast.zig");
const Checker = @import("checker.zig").Checker;
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");

// --- Error Reporting ---

pub fn grammarErrorOnFirstToken(c: *Checker, node: ast_gen.NodeIndex, message: *const diagnostics_gen.Message) bool {
    const sourceFile = ast_utils.getSourceFileOfNode(c.binder.ast, node);
    if (!c.hasParseDiagnostics(sourceFile)) {
        c.reportError(node, message); // fallback
        return true;
    }
    return false;
}

pub fn grammarErrorAtPos(c: *Checker, nodeForSourceFile: ast_gen.NodeIndex, start: usize, length: usize, message: *const diagnostics_gen.Message) bool {
    _ = start;
    _ = length;
    const sourceFile = ast_utils.getSourceFileOfNode(c.binder.ast, nodeForSourceFile);
    if (!c.hasParseDiagnostics(sourceFile)) {
        c.reportError(nodeForSourceFile, message);
        return true;
    }
    return false;
}

pub fn grammarErrorOnNode(c: *Checker, node: ast_gen.NodeIndex, message: *const diagnostics_gen.Message) bool {
    const sourceFile = ast_utils.getSourceFileOfNode(c.binder.ast, node);
    if (!c.hasParseDiagnostics(sourceFile)) {
        c.reportError(node, message);
        return true;
    }
    return false;
}

pub fn grammarErrorOnNodeSkippedOnNoEmit(c: *Checker, node: ast_gen.NodeIndex, message: *const diagnostics_gen.Message) bool {
    const sourceFile = ast_utils.getSourceFileOfNode(c.binder.ast, node);
    if (!c.hasParseDiagnostics(sourceFile)) {
        c.reportError(node, message);
        return true;
    }
    return false;
}

// --- Helpers ---

pub fn getIdentifierFromEntityNameExpression(c: *Checker, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const nodeData = c.binder.ast.getNode(node);
    switch (nodeData) {
        .Identifier => return node,
        .PropertyAccessExpression => |n| return n.name,
        else => return 0,
    }
}

// --- Grammar Checks ---

pub fn checkGrammarRegularExpressionLiteral(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarPrivateIdentifierExpression(c: *Checker, privId: ast_gen.NodeIndex) bool {
    if (0 == 0) {
        return grammarErrorOnNode(c, privId, &diagnostics_gen.Private_identifiers_are_not_allowed_outside_class_bodies);
    }

    const parent = c.binder.ast.getNodeParent(privId);
    if (!ast_utils.isForInStatement(c.binder.ast, parent)) {
        if (!ast_utils.isExpressionNode(c.binder.ast, privId)) {
            return grammarErrorOnNode(c, privId, &diagnostics_gen.Private_identifiers_are_only_allowed_in_class_bodies_and_may_only_be_used_as_part_of_a_class_member_declaration_property_access_or_on_the_left_hand_side_of_an_in_expression);
        }

        const parentTag = c.binder.ast.getNode(parent);
        const isInOperation = parentTag == .BinaryExpression and c.binder.ast.getNode(c.binder.ast.getNode(parent).BinaryExpression.OperatorToken) == .InKeyword;
        if (c.getSymbolForPrivateIdentifierExpression(privId) == null and !isInOperation) {
            // we should pass privId.Text but we will just pass a stub string for now
            // return c.grammarErrorOnNode(privId, diagnostics.Cannot_find_name_0, privId.Text)
            return grammarErrorOnNode(c, privId, &diagnostics_gen.Cannot_find_name_0);
        }
    }

    return false;
}

pub fn checkGrammarMappedType(c: *Checker, node: ast_gen.NodeIndex) bool {
    const n = c.binder.ast.getNode(node).MappedType;
    if (n.members != 0) {
        const members = c.binder.ast.getNodeList(n.members);
        if (members.len > 0) {
            return grammarErrorOnNode(c, members[0], &diagnostics_gen.A_mapped_type_may_not_declare_properties_or_methods);
        }
    }
    return false;
}

pub fn checkGrammarDecorator(c: *Checker, decorator: ast_gen.NodeIndex) bool {
    const sourceFile = ast_utils.getSourceFileOfNode(c.binder.ast, decorator);
    if (!c.hasParseDiagnostics(sourceFile)) {
        const decNode = c.binder.ast.getNode(decorator).Decorator;
        var node = decNode.Expression;

        const initialTag = c.binder.ast.getNode(node);
        if (initialTag == .ParenthesizedExpression) {
            return false;
        }

        var canHaveCallExpression = true;
        var errorNode: ?ast_gen.NodeIndex = null;

        while (true) {
            const tag = c.binder.ast.getNode(node);
            if (tag == .ExpressionWithTypeArguments) {
                node = c.binder.ast.getNode(node).ExpressionWithTypeArguments.Expression;
                continue;
            }
            if (tag == .NonNullExpression) {
                node = c.binder.ast.getNode(node).NonNullExpression.Expression;
                continue;
            }

            if (tag == .CallExpression) {
                const callExpr = c.binder.ast.getNode(node).CallExpression;
                if (!canHaveCallExpression) {
                    errorNode = node;
                }
                if (callExpr.QuestionDotToken) |qdt| {
                    errorNode = qdt;
                }
                node = callExpr.Expression;
                canHaveCallExpression = false;
                continue;
            }

            if (tag == .PropertyAccessExpression) {
                const propAccess = c.binder.ast.getNode(node).PropertyAccessExpression;
                if (propAccess.QuestionDotToken) |qdt| {
                    errorNode = qdt;
                }
                node = propAccess.Expression;
                canHaveCallExpression = false;
                continue;
            }

            if (tag != .Identifier) {
                errorNode = node;
            }

            break;
        }

        if (errorNode) |errN| {
            c.reportError(decNode.Expression, &diagnostics_gen.Expression_must_be_enclosed_in_parentheses_to_be_used_as_a_decorator);
            _ = errN; // In full port, we would attach a related info to the error
            return true;
        }
    }

    return false;
}

pub fn checkGrammarExportDeclaration(c: *Checker, node: ast_gen.NodeIndex) bool {
    const n = c.binder.ast.getNode(node).ExportDeclaration;
    if (n.IsTypeOnly and n.exportClause != 0 and c.binder.ast.getNode(n.exportClause) == .NamedExports) {
        return checkGrammarTypeOnlyNamedImportsOrExports(c, n.exportClause);
    }
    return false;
}

pub fn checkGrammarModuleElementContext(c: *Checker, node: ast_gen.NodeIndex, errorMessage: *const diagnostics_gen.Message) bool {
    const parent = c.binder.ast.getNodeParent(node);
    const parentTag = c.binder.ast.getNode(parent);
    const isInAppropriateContext = parentTag == .SourceFile or parentTag == .ModuleBlock or parentTag == .ModuleDeclaration;
    if (!isInAppropriateContext) {
        _ = grammarErrorOnFirstToken(c, node, errorMessage);
    }
    return !isInAppropriateContext;
}

pub fn checkGrammarModifiers(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn reportObviousModifierErrors(c: *Checker, node: ast_gen.NodeIndex) bool {
    const modifier = findFirstIllegalModifier(c, node);
    if (modifier == 0) {
        return false;
    }
    return grammarErrorOnFirstToken(c, modifier, &diagnostics_gen.Modifiers_cannot_appear_here);
}

pub fn findFirstModifierExcept(c: *Checker, node: ast_gen.NodeIndex, allowedModifier: std.meta.Tag(ast_gen.NodeData)) ast_gen.NodeIndex {
    if (ast_utils.getModifiers(c.binder.ast, node)) |modListId| {
        const modifiers = c.binder.ast.getNodeList(modListId);
        for (modifiers) |mod| {
            if (ast_utils.isModifier(c.binder.ast, mod)) {
                if (c.binder.ast.getNode(mod) != allowedModifier) {
                    return mod;
                }
            }
        }
    }
    return 0;
}

pub fn findFirstIllegalModifier(c: *Checker, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    const tag = c.binder.ast.getNode(node);

    switch (tag) {
        .GetAccessor, .SetAccessor, .Constructor, .PropertyDeclaration, .PropertySignature, .MethodDeclaration, .MethodSignature, .IndexSignature, .ModuleDeclaration, .ImportDeclaration, .JSImportDeclaration, .ImportEqualsDeclaration, .ExportDeclaration, .ExportAssignment, .FunctionExpression, .ArrowFunction, .Parameter, .TypeParameter, .JSTypeAliasDeclaration => return 0,

        .ClassStaticBlockDeclaration, .PropertyAssignment, .ShorthandPropertyAssignment, .NamespaceExportDeclaration, .MissingDeclaration => {
            if (ast_utils.getModifiers(c.binder.ast, node)) |modListId| {
                const modifiers = c.binder.ast.getNodeList(modListId);
                for (modifiers) |mod| {
                    if (ast_utils.isModifier(c.binder.ast, mod)) return mod;
                }
            }
            return 0;
        },

        else => {
            const parent = c.binder.ast.getNodeParent(node);
            const parentTag = c.binder.ast.getNode(parent);
            if (parentTag == .ModuleBlock or parentTag == .SourceFile) {
                return 0;
            }

            switch (tag) {
                .FunctionDeclaration => return findFirstModifierExcept(c, node, .AsyncKeyword),
                .ClassDeclaration, .ConstructorType => return findFirstModifierExcept(c, node, .AbstractKeyword),
                .ClassExpression, .InterfaceDeclaration, .TypeAliasDeclaration => {
                    if (ast_utils.getModifiers(c.binder.ast, node)) |modListId| {
                        const modifiers = c.binder.ast.getNodeList(modListId);
                        for (modifiers) |mod| {
                            if (ast_utils.isModifier(c.binder.ast, mod)) return mod;
                        }
                    }
                    return 0;
                },
                .VariableStatement => {
                    const stmt = c.binder.ast.getNode(node).VariableStatement;
                    const declList = c.binder.ast.getNode(stmt.declarationList).VariableDeclarationList;
                    const isUsing = (declList.flags & ast_utils.NodeFlags.Using) != 0;
                    if (isUsing) {
                        return findFirstModifierExcept(c, node, .AwaitKeyword);
                    }
                    if (ast_utils.getModifiers(c.binder.ast, node)) |modListId| {
                        const modifiers = c.binder.ast.getNodeList(modListId);
                        for (modifiers) |mod| {
                            if (ast_utils.isModifier(c.binder.ast, mod)) return mod;
                        }
                    }
                    return 0;
                },
                .EnumDeclaration => return findFirstModifierExcept(c, node, .ConstKeyword),
                else => std.debug.panic("Unhandled case in findFirstIllegalModifier.", .{}),
            }
        },
    }
}

pub fn reportObviousDecoratorErrors(c: *Checker, node: ast_gen.NodeIndex) bool {
    const decorator = findFirstIllegalDecorator(c, node);
    if (decorator == 0) {
        return false;
    }
    return grammarErrorOnFirstToken(c, decorator, &diagnostics_gen.Decorators_are_not_valid_here);
}

pub fn findFirstIllegalDecorator(c: *Checker, node: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (ast_utils.canHaveIllegalDecorators(c.binder.ast, node)) {
        if (ast_utils.getModifiers(c.binder.ast, node)) |modListId| {
            const modifiers = c.binder.ast.getNodeList(modListId);
            for (modifiers) |mod| {
                if (ast_utils.isDecorator(c.binder.ast, mod)) return mod;
            }
        }
    }
    return 0;
}

pub fn checkGrammarAsyncModifier(c: *Checker, node: ast_gen.NodeIndex, asyncModifier: ast_gen.NodeIndex) bool {
    const tag = c.binder.ast.getNode(node);
    switch (tag) {
        .MethodDeclaration, .FunctionDeclaration, .FunctionExpression, .ArrowFunction => return false,
        else => return grammarErrorOnNode(c, asyncModifier, &diagnostics_gen.X_0_modifier_cannot_be_used_here), // "async" as arg removed for now
    }
}

pub fn checkGrammarForDisallowedTrailingComma(c: *Checker, listId: ast_gen.NodeListIndex, diag: *const diagnostics_gen.Message) bool {
    if (listId != 0 and c.binder.ast.listHasTrailingComma(listId)) {
        const list = c.binder.ast.getNodeList(listId);
        if (list.len > 0) {
            // we should do grammarErrorAtPos, but we'll use OnNode for now since we don't have trailing comma pos
            return grammarErrorOnNode(c, list[0], diag);
        }
    }
    return false;
}

pub fn checkGrammarTypeParameterList(c: *Checker, typeParametersId: ast_gen.NodeListIndex, file: ast_gen.NodeIndex) bool {
    _ = file;
    if (typeParametersId != 0) {
        const list = c.binder.ast.getNodeList(typeParametersId);
        if (list.len == 0) {
            // We should use grammarErrorAtPos, but we'll use OnNode for now
            // We don't have the parent node easily accessible here without knowing who owns this list.
            // For now, we will return false since we can't reliably report an error on a 0-length list.
            // In a more complete port, we would pass the parent node to report on it.
            return false;
        }
    }
    return checkGrammarForDisallowedTrailingComma(c, typeParametersId, &diagnostics_gen.Type_parameter_list_may_not_have_a_trailing_comma);
}

pub fn checkGrammarParameterList(c: *Checker, parametersId: ast_gen.NodeListIndex) bool {
    var seenOptionalParameter = false;

    if (parametersId != 0) {
        const parameters = c.binder.ast.getNodeList(parametersId);
        const parameterCount = parameters.len;

        for (parameters, 0..) |paramNode, i| {
            const parameter = c.binder.ast.getNode(paramNode).Parameter;
            if (parameter.DotDotDotToken) |dotdotdot| {
                if (i != parameterCount - 1) {
                    return grammarErrorOnNode(c, dotdotdot, &diagnostics_gen.A_rest_parameter_must_be_last_in_a_parameter_list);
                }
                if (parameter.Flags & ast_utils.NodeFlags.Ambient == 0) {
                    _ = checkGrammarForDisallowedTrailingComma(c, parametersId, &diagnostics_gen.A_rest_parameter_or_binding_pattern_may_not_have_a_trailing_comma);
                }

                if (parameter.QuestionToken) |qtoken| {
                    return grammarErrorOnNode(c, qtoken, &diagnostics_gen.A_rest_parameter_cannot_be_optional);
                }

                if (parameter.Initializer != null and parameter.Initializer.? != 0) {
                    return grammarErrorOnNode(c, parameter.name, &diagnostics_gen.A_rest_parameter_cannot_have_an_initializer);
                }
            } else if (parameter.QuestionToken != null and parameter.QuestionToken.? != 0) {
                seenOptionalParameter = true;
                const qToken = parameter.QuestionToken.?;
                const qTokenFlags = c.binder.ast.getNodeFlags(qToken);

                if (qTokenFlags & ast_utils.NodeFlags.Reparsed == 0 and parameter.Initializer != null and parameter.Initializer.? != 0) {
                    return grammarErrorOnNode(c, parameter.name, &diagnostics_gen.Parameter_cannot_have_question_mark_and_initializer);
                }
            } else if (seenOptionalParameter and (parameter.Initializer == null or parameter.Initializer.? == 0)) {
                return grammarErrorOnNode(c, parameter.name, &diagnostics_gen.A_required_parameter_cannot_follow_an_optional_parameter);
            }
        }
    }
    return false;
}

pub fn checkGrammarForUseStrictSimpleParameterList(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    // TODO: implement use strict parameter checks when binder.findUseStrictPrologue is available
    return false;
}

pub fn checkGrammarFunctionLikeDeclaration(c: *Checker, node: ast_gen.NodeIndex) bool {
    const file = ast_utils.getSourceFileOfNode(c.binder.ast, node);

    var typeParameters: ?ast_gen.NodeListIndex = null;
    var parameters: ast_gen.NodeListIndex = 0;

    const tag = c.binder.ast.getNode(node);
    switch (tag) {
        .FunctionDeclaration => {
            const func = c.binder.ast.getNode(node).FunctionDeclaration;
            typeParameters = if (func.TypeParameters != null) func.TypeParameters.? else null;
            parameters = func.Parameters;
        },
        .MethodDeclaration => {
            const method = c.binder.ast.getNode(node).MethodDeclaration;
            typeParameters = if (method.TypeParameters != null) method.TypeParameters.? else null;
            parameters = method.Parameters;
        },
        .Constructor => {
            const cons = c.binder.ast.getNode(node).Constructor;
            typeParameters = if (cons.TypeParameters != null) cons.TypeParameters.? else null;
            parameters = cons.Parameters;
        },
        .GetAccessor => {
            const get = c.binder.ast.getNode(node).GetAccessor;
            typeParameters = if (get.TypeParameters != null) get.TypeParameters.? else null;
            parameters = get.Parameters;
        },
        .SetAccessor => {
            const set = c.binder.ast.getNode(node).SetAccessor;
            typeParameters = if (set.TypeParameters != null) set.TypeParameters.? else null;
            parameters = set.Parameters;
        },
        .ArrowFunction => {
            const arrow = c.binder.ast.getNode(node).ArrowFunction;
            typeParameters = if (arrow.TypeParameters != null) arrow.TypeParameters.? else null;
            parameters = arrow.Parameters;
        },
        .FunctionExpression => {
            const func = c.binder.ast.getNode(node).FunctionExpression;
            typeParameters = if (func.TypeParameters != null) func.TypeParameters.? else null;
            parameters = func.Parameters;
        },
        else => {},
    }

    if (checkGrammarModifiers(c, node)) return true;
    if (typeParameters) |tp| {
        if (checkGrammarTypeParameterList(c, tp, file)) return true;
    }
    if (checkGrammarParameterList(c, parameters)) return true;
    if (checkGrammarArrowFunction(c, node, file)) return true;
    if (tag == .FunctionDeclaration or tag == .MethodDeclaration or tag == .Constructor or tag == .GetAccessor or tag == .SetAccessor or tag == .ArrowFunction or tag == .FunctionExpression) {
        if (checkGrammarForUseStrictSimpleParameterList(c, node)) return true;
    }

    return false;
}

pub fn checkGrammarClassLikeDeclaration(c: *Checker, node: ast_gen.NodeIndex) bool {
    const file = ast_utils.getSourceFileOfNode(c.binder.ast, node);
    if (checkGrammarClassDeclarationHeritageClauses(c, node, file)) return true;

    // We should get typeParameters list of ClassLikeDeclaration
    const tag = c.binder.ast.getNode(node);
    var typeParameters: ?ast_gen.NodeListIndex = null;
    if (tag == .ClassDeclaration) {
        const cls = c.binder.ast.getNode(node).ClassDeclaration;
        typeParameters = if (cls.TypeParameters != null) cls.TypeParameters.? else null;
    } else if (tag == .ClassExpression) {
        const cls = c.binder.ast.getNode(node).ClassExpression;
        typeParameters = if (cls.TypeParameters != null) cls.TypeParameters.? else null;
    }

    if (typeParameters) |tp| {
        if (checkGrammarTypeParameterList(c, tp, file)) return true;
    }
    return false;
}

pub fn checkGrammarArrowFunction(c: *Checker, node: ast_gen.NodeIndex, file: ast_gen.NodeIndex) bool {
    _ = file; // needed for later
    if (c.binder.ast.getNode(node) != .ArrowFunction) {
        return false;
    }

    const arrowFunc = c.binder.ast.getNode(node).ArrowFunction;
    if (arrowFunc.TypeParameters) |tpId| {
        if (tpId != 0) {
            const tpNodes = c.binder.ast.getNodeList(tpId);
            const hasConstraint = tpNodes.len > 0 and c.binder.ast.getNode(tpNodes[0]).TypeParameter.Constraint != null;
            if (!(tpNodes.len > 1 or c.binder.ast.listHasTrailingComma(tpId) or hasConstraint)) {
                // In TS we would check file extension (.mts, .cts).
                // We'll skip file extension check and report error.
                // Wait, it says `if (tspath.FileExtensionIsOneOf(...)) { c.grammarError(...) }`
                // Let's just not report it for now since we don't have file extension checking readily available here.
            }
        }
    }

    const eqToken = arrowFunc.EqualsGreaterThanToken;
    // In TS: startLine != endLine check. We'll use getLineOfPos if it exists, or skip for now.
    // For now we will just assume they are on the same line.
    _ = eqToken;
    return false;
}

pub fn checkGrammarIndexSignatureParameters(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarIndexSignature(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarForAtLeastOneTypeArgument(c: *Checker, node: ast_gen.NodeIndex, typeArguments: ast_gen.NodeListIndex) bool {
    _ = c;
    _ = node;
    _ = typeArguments;
    return false;
}

pub fn checkGrammarTypeArguments(c: *Checker, node: ast_gen.NodeIndex, typeArguments: ast_gen.NodeListIndex) bool {
    _ = c;
    _ = node;
    _ = typeArguments;
    return false;
}

pub fn checkGrammarTaggedTemplateChain(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarHeritageClause(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarExpressionWithTypeArguments(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarClassDeclarationHeritageClauses(c: *Checker, node: ast_gen.NodeIndex, file: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    _ = file;
    return false;
}

pub fn checkGrammarInterfaceDeclaration(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarComputedPropertyName(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarForGenerator(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarForInvalidQuestionMark(c: *Checker, postfixToken: ast_gen.NodeIndex, message: *const diagnostics_gen.Message) bool {
    _ = c;
    _ = postfixToken;
    _ = message;
    return false;
}

pub fn checkGrammarForInvalidExclamationToken(c: *Checker, postfixToken: ast_gen.NodeIndex, message: *const diagnostics_gen.Message) bool {
    _ = c;
    _ = postfixToken;
    _ = message;
    return false;
}

pub fn checkGrammarObjectLiteralExpression(c: *Checker, node: ast_gen.NodeIndex, inDestructuring: bool) bool {
    _ = c;
    _ = node;
    _ = inDestructuring;
    return false;
}

pub fn checkGrammarJsxElement(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarJsxName(c: *Checker, node: ast_gen.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarJsxExpression(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarForInOrForOfStatement(c: *Checker, forInOrOfStatement: ast.NodeIndex) bool {
    _ = c;
    _ = forInOrOfStatement;
    return false;
}

pub fn checkGrammarAccessor(c: *Checker, accessor: ast.NodeIndex) bool {
    _ = c;
    _ = accessor;
    return false;
}

pub fn doesAccessorHaveCorrectParameterCount(c: *Checker, accessor: ast.NodeIndex) bool {
    _ = c;
    _ = accessor;
    return false;
}

pub fn checkGrammarTypeOperatorNode(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarForInvalidDynamicName(c: *Checker, node: ast.NodeIndex, message: *const diagnostics_gen.Message) bool {
    _ = c;
    _ = node;
    _ = message;
    return false;
}

pub fn isNonBindableDynamicName(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarMethod(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarBreakOrContinueStatement(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarBindingElement(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarVariableDeclaration(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarForEsModuleMarkerInBindingName(c: *Checker, name: ast.NodeIndex) bool {
    _ = c;
    _ = name;
    return false;
}

pub fn checkGrammarNameInLetOrConstDeclarations(c: *Checker, name: ast.NodeIndex) bool {
    _ = c;
    _ = name;
    return false;
}

pub fn checkGrammarVariableDeclarationList(c: *Checker, declarationList: ast.NodeIndex) bool {
    _ = c;
    _ = declarationList;
    return false;
}

pub fn checkGrammarAwaitOrAwaitUsing(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarYieldExpression(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarForDisallowedBlockScopedVariableStatement(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn containerAllowsBlockScopedVariable(c: *Checker, parent: ast.NodeIndex) bool {
    _ = c;
    _ = parent;
    return false;
}

pub fn checkGrammarMetaProperty(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarConstructorTypeParameters(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarConstructorTypeAnnotation(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarProperty(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkAmbientInitializer(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn isInitializerStringOrNumberLiteralExpression(c: *Checker, expr: ast.NodeIndex) bool {
    _ = c;
    _ = expr;
    return false;
}

pub fn isInitializerBigIntLiteralExpression(c: *Checker, expr: ast.NodeIndex) bool {
    _ = c;
    _ = expr;
    return false;
}

pub fn isInitializerSimpleLiteralEnumReference(c: *Checker, expr: ast.NodeIndex) bool {
    _ = c;
    _ = expr;
    return false;
}

pub fn checkGrammarTopLevelElementForRequiredDeclareModifier(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarTopLevelElementsForRequiredDeclareModifier(c: *Checker, file: ast.NodeIndex) bool {
    _ = c;
    _ = file;
    return false;
}

pub fn checkGrammarSourceFile(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarStatementInAmbientContext(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarNumericLiteral(c: *Checker, node: ast.NodeIndex) void {
    _ = c;
    _ = node;
}

pub fn checkGrammarBigIntLiteral(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarImportClause(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}

pub fn checkGrammarTypeOnlyNamedImportsOrExports(c: *Checker, namedBindings: ast.NodeIndex) bool {
    _ = c;
    _ = namedBindings;
    return false;
}

pub fn checkGrammarImportCallExpression(c: *Checker, node: ast.NodeIndex) bool {
    _ = c;
    _ = node;
    return false;
}
