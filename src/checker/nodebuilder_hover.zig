const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeIndex = ast_gen.NodeIndex;
const SymbolIndex = ast_gen.SymbolIndex;
const SymbolFlags = ast_gen.SymbolFlags;
const NodeFlags = ast_gen.NodeFlags;
const ModifierFlags = ast_gen.ModifierFlags;
const checker_mod = @import("checker.zig");
const Checker = checker_mod.Checker;
const nodebuilderimpl = @import("nodebuilderimpl.zig");
const NodeBuilderImpl = nodebuilderimpl.NodeBuilderImpl;
const NodeBuilderContext = nodebuilderimpl.NodeBuilderContext;
const types = @import("types.zig");
const TypeIndex = types.TypeIndex;

pub fn isExpanding(ctx: *NodeBuilderContext) bool {
    return ctx.maxExpansionDepth != -1;
}

pub fn expandSymbolForHover(b: *NodeBuilderImpl, symbol: SymbolIndex) []NodeIndex {
    _ = b;
    _ = symbol;
    return &[_]NodeIndex{};
}

pub fn expandEnumDecl(b: *NodeBuilderImpl, symbol: SymbolIndex) NodeIndex {
    _ = b;
    _ = symbol;
    return 0;
}

pub fn enumMemberInitializer(b: *NodeBuilderImpl, p: SymbolIndex) NodeIndex {
    _ = b;
    _ = p;
    return 0;
}

pub fn expandClassDecl(b: *NodeBuilderImpl, symbol: SymbolIndex) NodeIndex {
    _ = b;
    _ = symbol;
    return 0;
}

pub fn addClassModifiers(b: *NodeBuilderImpl, members: []NodeIndex, isStatic: bool) []NodeIndex {
    _ = b;
    _ = members;
    _ = isStatic;
    return &[_]NodeIndex{};
}

pub fn typeElementsToClassElements(f: *ast.NodeFactory, members: []NodeIndex) []NodeIndex {
    _ = f;
    _ = members;
    return &[_]NodeIndex{};
}

pub fn expandInterfaceDecl(b: *NodeBuilderImpl, symbol: SymbolIndex) NodeIndex {
    _ = b;
    _ = symbol;
    return 0;
}

pub fn hoverHeritageClauses(b: *NodeBuilderImpl, declarations: []NodeIndex) []NodeIndex {
    _ = b;
    _ = declarations;
    return &[_]NodeIndex{};
}

pub fn serializePropertiesWithTruncation(b: *NodeBuilderImpl, properties: []SymbolIndex, elements: []NodeIndex) []NodeIndex {
    _ = b;
    _ = properties;
    _ = elements;
    return &[_]NodeIndex{};
}

pub fn serializeConstructors(b: *NodeBuilderImpl, staticType: TypeIndex, staticBaseType: TypeIndex, isClass: bool, symbol: SymbolIndex) []NodeIndex {
    _ = b;
    _ = staticType;
    _ = staticBaseType;
    _ = isClass;
    _ = symbol;
    return &[_]NodeIndex{};
}

pub fn serializeIndexSignaturesOfType(b: *NodeBuilderImpl, input: TypeIndex, baseType: TypeIndex) []NodeIndex {
    _ = b;
    _ = input;
    _ = baseType;
    return &[_]NodeIndex{};
}

pub fn serializeNamespaceMember(b: *NodeBuilderImpl, resolved: SymbolIndex, name: []const u8) NodeIndex {
    _ = b;
    _ = resolved;
    _ = name;
    return 0;
}

pub fn expandModuleDecl(b: *NodeBuilderImpl, symbol: SymbolIndex) NodeIndex {
    _ = b;
    _ = symbol;
    return 0;
}

pub fn serializeTypeAliasForNamespace(b: *NodeBuilderImpl, symbol: SymbolIndex, name: []const u8) NodeIndex {
    _ = b;
    _ = symbol;
    _ = name;
    return 0;
}

pub fn filterInheritedProperties(b: *NodeBuilderImpl, t: TypeIndex, baseTypes: []TypeIndex, properties: []SymbolIndex) []SymbolIndex {
    _ = b;
    _ = t;
    _ = baseTypes;
    _ = properties;
    return &[_]SymbolIndex{};
}

pub fn isNamespaceMember(b: *NodeBuilderImpl, p: SymbolIndex) bool {
    _ = b;
    _ = p;
    return false;
}

pub fn isHashPrivate(b: *NodeBuilderImpl, s: SymbolIndex) bool {
    _ = b;
    _ = s;
    return false;
}
