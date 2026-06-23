const std = @import("std");
const ast_gen = @import("ast_generated.zig");

pub const SymbolFlags = struct {
    pub const None: u32 = 0;
    pub const FunctionScopedVariable: u32 = 1 << 0;
    pub const BlockScopedVariable: u32 = 1 << 1;
    pub const Property: u32 = 1 << 2;
    pub const EnumMember: u32 = 1 << 3;
    pub const Function: u32 = 1 << 4;
    pub const Class: u32 = 1 << 5;
    pub const Interface: u32 = 1 << 6;
    pub const ConstEnum: u32 = 1 << 7;
    pub const RegularEnum: u32 = 1 << 8;
    pub const ValueModule: u32 = 1 << 9;
    pub const NamespaceModule: u32 = 1 << 10;
    pub const TypeLiteral: u32 = 1 << 11;
    pub const ObjectLiteral: u32 = 1 << 12;
    pub const Method: u32 = 1 << 13;
    pub const All: u32 = 0x1FFFFFFF;
    pub const Constructor: u32 = 1 << 14;
    pub const GetAccessor: u32 = 1 << 15;
    pub const SetAccessor: u32 = 1 << 16;
    pub const Signature: u32 = 1 << 17;
    pub const TypeParameter: u32 = 1 << 18;
    pub const TypeAlias: u32 = 1 << 19;
    pub const ExportValue: u32 = 1 << 20;
    pub const Alias: u32 = 1 << 21;
    pub const Prototype: u32 = 1 << 22;
    pub const ExportStar: u32 = 1 << 23;
    pub const Optional: u32 = 1 << 24;
    pub const Transient: u32 = 1 << 25;
    pub const Assignment: u32 = 1 << 26;
    pub const ModuleExports: u32 = 1 << 27;

    // Derived flags
    pub const Variable: u32 = FunctionScopedVariable | BlockScopedVariable;
    pub const Value: u32 = Variable | Property | EnumMember | ObjectLiteral | Function | Class | Enum | ValueModule | Method | GetAccessor | SetAccessor;

    pub const Type: u32 = Class | Interface | Enum | EnumMember | TypeLiteral | TypeParameter | TypeAlias;
    pub const Accessor: u32 = GetAccessor | SetAccessor;
    pub const PropertyOrAccessor: u32 = Property | Accessor;
    pub const Enum: u32 = RegularEnum | ConstEnum;
    pub const FunctionScopedVariableExcludes: u32 = Value & ~FunctionScopedVariable;
    pub const BlockScopedVariableExcludes: u32 = Value;
    pub const ParameterExcludes: u32 = Value;
    pub const PropertyExcludes: u32 = Value & ~(Property | Accessor);
    pub const EnumMemberExcludes: u32 = Value | Type;
    pub const FunctionExcludes: u32 = Value & ~(Function | ValueModule | Class);
    pub const ClassExcludes: u32 = (Value | Type) & ~(ValueModule | Interface | Function);
    pub const InterfaceExcludes: u32 = Type & ~(Interface | Class);
    pub const RegularEnumExcludes: u32 = (Value | Type) & ~(RegularEnum | ValueModule);
    pub const ConstEnumExcludes: u32 = (Value | Type) & ~ConstEnum;
    pub const ValueModuleExcludes: u32 = Value & ~(Function | Class | RegularEnum | ValueModule);
    pub const NamespaceModuleExcludes: u32 = None;
    pub const MethodExcludes: u32 = Value & ~Method;
    pub const GetAccessorExcludes: u32 = Value & ~(SetAccessor | Property);
    pub const SetAccessorExcludes: u32 = Value & ~(GetAccessor | Property);
    pub const AccessorExcludes: u32 = Value & ~Property;
    pub const TypeParameterExcludes: u32 = Type & ~TypeParameter;
    pub const TypeAliasExcludes: u32 = Type;
    pub const AliasExcludes: u32 = Alias;
};

pub const InternalSymbolNamePrefix = "\xFE";
pub const InternalSymbolNameMissing = InternalSymbolNamePrefix ++ "missing";
pub const InternalSymbolNameObject = InternalSymbolNamePrefix ++ "object";
pub const InternalSymbolNameComputed = InternalSymbolNamePrefix ++ "computed";
pub const InternalSymbolNameExportStar = InternalSymbolNamePrefix ++ "export";
pub const InternalSymbolNameExportEquals = "export=";

pub const SymbolTableEntry = struct {
    name: []const u8,
    symbolIndex: ast_gen.SymbolIndex,
};

pub const SymbolTable = std.ArrayListUnmanaged(SymbolTableEntry);

pub const Symbol = struct {
    Flags: u32,
    Name: []const u8,
    Declarations: std.ArrayListUnmanaged(ast_gen.NodeIndex),
    ValueDeclaration: ?ast_gen.NodeIndex,
    Members: SymbolTable,
    Exports: SymbolTable,
    Parent: ?ast_gen.SymbolIndex,
    ExportSymbol: ?ast_gen.SymbolIndex,

    pub fn get(self: *const Symbol, name: []const u8) ?ast_gen.SymbolIndex {
        _ = self;
        _ = name;
        return null;
    }
};

pub fn symbolTableGet(table: *const SymbolTable, name: []const u8) ?ast_gen.SymbolIndex {
    for (table.items) |entry| {
        if (std.mem.eql(u8, entry.name, name)) {
            return entry.symbolIndex;
        }
    }
    return null;
}

pub fn symbolTablePut(table: *SymbolTable, allocator: std.mem.Allocator, name: []const u8, symbolIndex: ast_gen.SymbolIndex) !void {
    if (symbolTableGet(table, name) == null) {
        try table.append(allocator, .{ .name = name, .symbolIndex = symbolIndex });
    }
}
