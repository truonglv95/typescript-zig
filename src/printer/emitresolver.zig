const std = @import("std");
const ast = @import("../ast/ast.zig");

pub const EmitResolver = struct {
    pub fn getEnumMemberValue(self: *EmitResolver, a: anytype) struct { value: u32 } {
        _ = self;
        _ = a;
        return .{ .value = 0 };
    }

    // Stub implementation for now. Checker will implement these properly later.

    pub fn IsReferencedAliasDeclaration(self: *EmitResolver, node: ast.NodeIndex) bool {
        _ = self;
        _ = node;
        return true;
    }

    pub fn IsValueAliasDeclaration(self: *EmitResolver, node: ast.NodeIndex) bool {
        _ = self;
        _ = node;
        return true;
    }

    pub fn IsTopLevelValueImportEqualsWithEntityName(self: *EmitResolver, node: ast.NodeIndex) bool {
        _ = self;
        _ = node;
        return true;
    }

    pub fn hasVisibleDeclarations(self: *EmitResolver, symbol: ast.SymbolIndex, shouldComputeAliasesToMakeVisible: bool) ?SymbolAccessibilityResult {
        _ = self;
        _ = symbol;
        _ = shouldComputeAliasesToMakeVisible;
        return null;
    }

    pub fn getTypeReferenceSerializationKind(self: *EmitResolver, a: anytype, b: anytype) u32 {
        _ = self;
        _ = a;
        _ = b;
        return 0;
    }

    pub fn markLinkedReferencesRecursively(self: *EmitResolver, sourceFile: ast.NodeIndex) !void {
        _ = self;
        _ = sourceFile;
        // Stub
    }

    pub fn asReferenceResolver(self: *EmitResolver) @import("../binder/referenceresolver.zig").ReferenceResolver {
        _ = self;
        // Stub implementation, will need actual tree in the future.
        return @import("../binder/referenceresolver.zig").ReferenceResolver.init(undefined, .{});
    }
};

pub const SymbolAccessibility = enum(u32) {
    Accessible = 0,
    NotAccessible,
    CannotBeNamed,
    NotResolved,
};

pub const SymbolAccessibilityResult = struct {
    accessibility: SymbolAccessibility,
    aliasesToMakeVisible: []const ast.NodeIndex = &[_]ast.NodeIndex{}, // aliases that need to have this symbol visible
    errorSymbolName: ?[]const u8 = null, // Optional - symbol name that results in error
    errorNode: ?ast.NodeIndex = null, // Optional - node that results in error
    errorModuleName: ?[]const u8 = null, // Optional - If the symbol is not visible from module, module's name
};
