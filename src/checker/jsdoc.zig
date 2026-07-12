const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeIndex = ast_gen.NodeIndex;
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const diagnostics = @import("../diagnostics/diagnostics.zig");
const utils = @import("utilities.zig");

pub fn checkUnmatchedJSDocParameters(c: *Checker, node: NodeIndex) void {
    const allocator = c.arena.allocator();

    var jsdocParameters = std.ArrayList(NodeIndex).init(allocator);

    const tags = getAllJSDocTags(c, node);
    for (tags) |tag| {
        if (c.ast.getKind(tag) == .JSDocParameterTag) {
            const name = c.ast.jsDocParameterOrPropertyTag_name(tag);
            if (c.ast.isIdentifier(name) and c.ast.identifier_text(name).len == 0) {
                continue;
            }
            jsdocParameters.append(tag) catch unreachable;
        }
    }

    if (jsdocParameters.items.len == 0) {
        return;
    }

    const isJs = c.ast.isInJSFile(node);

    var parameters = std.StringHashMap(void).init(allocator);
    var excludedParameters = std.AutoHashMap(usize, void).init(allocator);

    const paramsNode = c.ast.signatureDeclaration_parameters(node);
    const params = if (paramsNode != 0) c.ast.getNodes(paramsNode) else &[_]NodeIndex{};

    for (params, 0..) |param, i| {
        const name = c.ast.parameterDeclaration_name(param);
        if (c.ast.isIdentifier(name)) {
            parameters.put(c.ast.identifier_text(name), {}) catch unreachable;
        }
        if (c.ast.isBindingPattern(name)) {
            excludedParameters.put(i, {}) catch unreachable;
        }
    }

    if (c.containsArgumentsReference(node)) {
        if (isJs) {
            const lastJSDocParamIndex = jsdocParameters.items.len - 1;
            const lastJSDocParam = jsdocParameters.items[lastJSDocParamIndex];
            const name = c.ast.jsDocParameterOrPropertyTag_name(lastJSDocParam);

            if (!c.ast.isIdentifier(name)) {
                return;
            }
            if (excludedParameters.contains(lastJSDocParamIndex) or parameters.contains(c.ast.identifier_text(name))) {
                return;
            }

            const typeExpr = c.ast.jsDocParameterOrPropertyTag_typeExpression(lastJSDocParam);
            if (typeExpr == 0) return;
            const typeNode = c.ast.jsDocTypeExpression_type(typeExpr);
            if (typeNode == 0) return;

            if (c.isArrayType(c.getTypeFromTypeNode(typeNode))) {
                return;
            }
            c.errorNodeArgs(name, diagnostics.Diagnostics.JSDoc_param_tag_has_name_0_but_there_is_no_parameter_with_that_name_It_would_match_arguments_if_it_had_an_array_type, .{c.ast.identifier_text(name)});
        }
    } else {
        for (jsdocParameters.items, 0..) |tag, index| {
            const name = c.ast.jsDocParameterOrPropertyTag_name(tag);
            const isNameFirst = c.ast.jsDocParameterOrPropertyTag_isNameFirst(tag);

            if (excludedParameters.contains(index) or (c.ast.isIdentifier(name) and parameters.contains(c.ast.identifier_text(name)))) {
                continue;
            }

            if (c.ast.isQualifiedName(name)) {
                if (isJs) {
                    c.errorNodeArgs(name, diagnostics.Diagnostics.Qualified_name_0_is_not_allowed_without_a_leading_param_object_1, .{
                        utils.entityNameToString(c, name),
                        utils.entityNameToString(c, c.ast.qualifiedName_left(name)),
                    });
                }
            } else {
                if (!isNameFirst) {
                    c.errorOrSuggestionNodeArgs(isJs, name, diagnostics.Diagnostics.JSDoc_param_tag_has_name_0_but_there_is_no_parameter_with_that_name, .{c.ast.identifier_text(name)});
                }
            }
        }
    }
}

pub fn getAllJSDocTags(c: *Checker, node: NodeIndex) []const NodeIndex {
    if ((c.ast.getNodeFlags(node) & ast.NodeFlags.JSDoc) == 0) {
        var current: NodeIndex = node;
        while (current != 0) {
            const jsdocs = c.ast.getJSDoc(current);
            if (jsdocs.len > 0) {
                const lastJSDoc = jsdocs[jsdocs.len - 1];
                const tagsNode = c.ast.jsDoc_tags(lastJSDoc);
                if (tagsNode != 0) {
                    return c.ast.getNodes(tagsNode);
                }
            }
            current = c.ast.getNextJSDocCommentLocation(current);
        }
    }
    return &[_]NodeIndex{};
}
