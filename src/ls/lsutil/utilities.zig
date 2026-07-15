const std = @import("std");
const ast = @import("../../ast/ast.zig");
const astnav = @import("../../ast/ast_utils.zig");
const compiler = @import("../../compiler/program.zig");
const core = @import("../../core/core.zig");
const scanner = @import("../../scanner/scanner.zig");
const stringutil = @import("../../stringutil/stringutil.zig");
const tspath = @import("../../tspath/tspath.zig");
const formatcodeoptions = @import("formatcodeoptions.zig");
const QuotePreference = @import("userpreferences.zig").QuotePreference;
const UserPreferences = @import("userpreferences.zig").UserPreferences;
const children = @import("children.zig");
const NodeIndex = ast.NodeIndex;

pub fn probablyUsesSemicolons(tree: *ast.Ast) bool {
    var withSemicolon: u32 = 0;
    var withoutSemicolon: u32 = 0;
    const nStatementsToObserve: u32 = 5;

    const VisitCtx = struct {
        tree: *ast.Ast,
        withSemicolon: *u32,
        withoutSemicolon: *u32,
        nStatementsToObserve: u32,

        fn visit(ctx: *@This(), node: NodeIndex) bool {
            if (node == 0) return false;
            if ((ctx.tree.getNodeFlags(node) & astnav.NodeFlags.Reparsed) != 0) {
                return false;
            }
            const kind = ctx.tree.getNodeKind(node);
            const asi = @import("asi.zig");
            if (asi.syntaxRequiresTrailingSemicolonOrASI(kind)) {
                const lastToken = children.getLastToken(ctx.tree, node);
                if (lastToken != null and ctx.tree.getNodeKind(lastToken.?) == .SemicolonToken) {
                    ctx.withSemicolon.* += 1;
                } else {
                    ctx.withoutSemicolon.* += 1;
                }
            } else if (asi.syntaxRequiresTrailingCommaOrSemicolonOrASI(kind)) {
                const lastToken = children.getLastToken(ctx.tree, node);
                if (lastToken != null and ctx.tree.getNodeKind(lastToken.?) == .SemicolonToken) {
                    ctx.withSemicolon.* += 1;
                } else if (lastToken != null and ctx.tree.getNodeKind(lastToken.?) != .CommaToken) {
                    const lastTokenLine = scanner.getECMALineOfPosition(
                        ctx.tree,
                        astnav.getStartOfNode(ctx.tree, lastToken.?, false),
                    );
                    const nextTokenLine = scanner.getECMALineOfPosition(
                        ctx.tree,
                        scanner.skipTrivia(ctx.tree.sourceText, ctx.tree.positions.items[lastToken.?].end, false),
                    );
                    if (lastTokenLine != nextTokenLine) {
                        ctx.withoutSemicolon.* += 1;
                    }
                }
            }

            if (ctx.withSemicolon.* + ctx.withoutSemicolon.* >= ctx.nStatementsToObserve) {
                return true;
            }

            return ast.forEachChild(ctx.tree, node, ctx, visit);
        }
    };

    var ctx = VisitCtx{
        .tree = tree,
        .withSemicolon = &withSemicolon,
        .withoutSemicolon = &withoutSemicolon,
        .nStatementsToObserve = nStatementsToObserve,
    };

    _ = ast.forEachChild(tree, 1, &ctx, VisitCtx.visit);

    if (withSemicolon == 0 and withoutSemicolon <= 1) {
        return true;
    }

    if (withoutSemicolon == 0) {
        return true;
    }
    return withSemicolon * nStatementsToObserve > withoutSemicolon;
}

pub fn shouldUseUriStyleNodeCoreModules(tree: *ast.Ast, prog: *compiler.Program) core.Tristate {
    for (tree.imports.items) |importNode| {
        const text = tree.getNodeText(importNode);
        if (core.nodeCoreModules.has(text) and !core.exclusivelyPrefixedNodeCoreModules.has(text)) {
            if (std.mem.startsWith(u8, text, "node:")) {
                return .True;
            } else {
                return .False;
            }
        }
    }
    return prog.usesUriStyleNodeCoreModules();
}

pub fn quotePreferenceFromString(tree: *ast.Ast, str: NodeIndex) QuotePreference {
    const node = tree.getNode(str);
    if (node == .StringLiteral) {
        if ((node.StringLiteral.TokenFlags & ast.TokenFlags.SingleQuote) != 0) {
            return .Single;
        }
    }
    return .Double;
}

pub fn getQuotePreference(tree: *ast.Ast, preferences: UserPreferences) QuotePreference {
    if (preferences.quotePreference) |pref| {
        if (!std.mem.eql(u8, pref, "auto")) {
            if (std.mem.eql(u8, pref, "single")) {
                return .Single;
            }
            return .Double;
        }
    }
    for (tree.imports.items) |importNode| {
        if (tree.getNodeKind(importNode) == .StringLiteral) {
            const parent = tree.getNodeParent(importNode);
            if ((tree.getNodeFlags(parent) & astnav.NodeFlags.Synthesized) == 0) {
                return quotePreferenceFromString(tree, importNode);
            }
        }
    }
    return .Double;
}

pub fn moduleSymbolToValidIdentifier(tree: *ast.Ast, moduleSymbol: ast.SymbolIndex, forceCapitalize: bool) []const u8 {
    const sym = tree.symbols.items[moduleSymbol];
    const name = stringutil.stripQuotes(sym.name);
    return moduleSpecifierToValidIdentifier(tree.allocator, name, forceCapitalize);
}

pub fn moduleSpecifierToValidIdentifier(allocator: std.mem.Allocator, moduleSpecifier: []const u8, forceCapitalize: bool) []const u8 {
    const baseName = tspath.getBaseFileName(std.mem.trimRight(u8, tspath.removeFileExtension(moduleSpecifier), "/index"));
    var res = std.ArrayList(u8).init(allocator);
    defer res.deinit();

    var lastCharWasValid = true;
    if (baseName.len > 0) {
        // we assume simple ASCII for scanner here, or handle unicode
        const firstChar = baseName[0];
        if (scanner.isIdentifierStart(firstChar)) {
            if (forceCapitalize) {
                res.append(std.ascii.toUpper(firstChar)) catch {};
            } else {
                res.append(firstChar) catch {};
            }
        } else {
            lastCharWasValid = false;
        }
    }

    var i: usize = 1;
    while (i < baseName.len) : (i += 1) {
        const char = baseName[i];
        const isValid = scanner.isIdentifierPart(char);
        if (isValid) {
            if (!lastCharWasValid) {
                res.append(std.ascii.toUpper(char)) catch {};
            } else {
                res.append(char) catch {};
            }
        }
        lastCharWasValid = isValid;
    }

    const resString = res.toOwnedSlice() catch return "";
    if (resString.len > 0) {
        const token = scanner.stringToToken(resString);
        if (!isNonContextualKeyword(token)) {
            return resString;
        }
    }
    return std.fmt.allocPrint(allocator, "_{s}", .{resString}) catch "";
}

pub fn isNonContextualKeyword(token: ast.Kind) bool {
    return astnav.isKeywordKind(token) and !astnav.isContextualKeyword(token);
}
