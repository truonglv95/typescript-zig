const std = @import("std");
const ast = @import("../../ast/ast.zig");
const checker = @import("../../checker/checker.zig");
const collections = @import("../../collections/collections.zig");
const core = @import("../../core/core.zig");
const NodeIndex = ast.NodeIndex;

pub const ScriptElementKind = enum {
    Unknown,
    Warning,
    Keyword,
    ScriptElement,
    ModuleElement,
    ClassElement,
    LocalClassElement,
    InterfaceElement,
    TypeElement,
    EnumElement,
    EnumMemberElement,
    VariableElement,
    LocalVariableElement,
    VariableUsingElement,
    VariableAwaitUsingElement,
    FunctionElement,
    LocalFunctionElement,
    MemberFunctionElement,
    MemberGetAccessorElement,
    MemberSetAccessorElement,
    MemberVariableElement,
    MemberAccessorVariableElement,
    ConstructorImplementationElement,
    CallSignatureElement,
    IndexSignatureElement,
    ConstructSignatureElement,
    ParameterElement,
    TypeParameterElement,
    PrimitiveType,
    Label,
    Alias,
    ConstElement,
    LetElement,
    Directory,
    ExternalModuleName,
    String,
    Link,
    LinkName,
    LinkText,
};

pub const ScriptElementKindModifier = u32;

pub const ScriptElementKindModifierNone: ScriptElementKindModifier = 0;
pub const ScriptElementKindModifierPublic: ScriptElementKindModifier = 1 << 0;
pub const ScriptElementKindModifierPrivate: ScriptElementKindModifier = 1 << 1;
pub const ScriptElementKindModifierProtected: ScriptElementKindModifier = 1 << 2;
pub const ScriptElementKindModifierExported: ScriptElementKindModifier = 1 << 3;
pub const ScriptElementKindModifierAmbient: ScriptElementKindModifier = 1 << 4;
pub const ScriptElementKindModifierStatic: ScriptElementKindModifier = 1 << 5;
pub const ScriptElementKindModifierAbstract: ScriptElementKindModifier = 1 << 6;
pub const ScriptElementKindModifierOptional: ScriptElementKindModifier = 1 << 7;
pub const ScriptElementKindModifierDeprecated: ScriptElementKindModifier = 1 << 8;
pub const ScriptElementKindModifierDts: ScriptElementKindModifier = 1 << 9;
pub const ScriptElementKindModifierTs: ScriptElementKindModifier = 1 << 10;
pub const ScriptElementKindModifierTsx: ScriptElementKindModifier = 1 << 11;
pub const ScriptElementKindModifierJs: ScriptElementKindModifier = 1 << 12;
pub const ScriptElementKindModifierJsx: ScriptElementKindModifier = 1 << 13;
pub const ScriptElementKindModifierJson: ScriptElementKindModifier = 1 << 14;
pub const ScriptElementKindModifierDmts: ScriptElementKindModifier = 1 << 15;
pub const ScriptElementKindModifierMts: ScriptElementKindModifier = 1 << 16;
pub const ScriptElementKindModifierMjs: ScriptElementKindModifier = 1 << 17;
pub const ScriptElementKindModifierDcts: ScriptElementKindModifier = 1 << 18;
pub const ScriptElementKindModifierCts: ScriptElementKindModifier = 1 << 19;
pub const ScriptElementKindModifierCjs: ScriptElementKindModifier = 1 << 20;

pub fn getSymbolKind(typeChecker: *checker.Checker, symbol: ast.SymbolIndex, location: NodeIndex) ScriptElementKind {
    _ = typeChecker;
    _ = symbol;
    _ = location;
    // TODO
    return .Unknown;
}

pub fn getSymbolModifiers(typeChecker: *checker.Checker, symbol: ast.SymbolIndex) ScriptElementKindModifier {
    _ = typeChecker;
    _ = symbol;
    // TODO
    return ScriptElementKindModifierNone;
}
