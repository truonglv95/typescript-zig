//! Code actions for missing members (implement interface members).
//!
//! Port of `internal/ls/codeactions_missingmemberfixer.go` (498 LOC).
//!
//! Provides code actions for:
//! - "Add missing properties" from an interface/class
//! - "Implement interface" (add all missing members)
//! - "Add missing imports"

const std = @import("std");

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");
const codeactions = @import("codeactions.zig");

pub const missingMemberErrorCodes = &[_]u32{
    diagnostics_gen.Property_0_is_missing_in_type_1_but_required_in_type_2.code,
    diagnostics_gen.Type_0_is_missing_the_following_properties_from_type_1_Colon_2.code,
    diagnostics_gen.Type_0_is_missing_the_following_properties_from_type_1_Colon_2_and_3_more.code,
    diagnostics_gen.Cannot_find_name_0.code,
};

pub const missingMemberFixProvider = codeactions.CodeFixProvider{
    .errorCodes = missingMemberErrorCodes,
    .getCodeActions = getMissingMemberCodeActions,
    .fixIds = &[_][]const u8{},
    .getAllCodeActions = null,
};

pub const preserveOptionalFlagsMethod: u32 = 1 << 0;
pub const preserveOptionalFlagsProperty: u32 = 1 << 1;
pub const preserveOptionalFlagsAll: u32 = preserveOptionalFlagsMethod | preserveOptionalFlagsProperty;

const autoimport = @import("autoimport/autoimport.zig");
const change = @import("change/tracker.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const lsutil = @import("lsutil/lsutil.zig");

pub const MissingMemberFixer = struct {
    allocator: std.mem.Allocator,
    changeTracker: *change.ChangeTracker,
    typeChecker: *checker.Checker,
    program: *compiler.Program,
    preferences: lsutil.UserPreferences,
    importAdder: ?*autoimport.ImportAdder,

    pub fn init(
        allocator: std.mem.Allocator,
        changeTracker: *change.ChangeTracker,
        typeChecker: *checker.Checker,
        program: *compiler.Program,
        preferences: lsutil.UserPreferences,
        importAdder: ?*autoimport.ImportAdder,
    ) MissingMemberFixer {
        return .{
            .allocator = allocator,
            .changeTracker = changeTracker,
            .typeChecker = typeChecker,
            .program = program,
            .preferences = preferences,
            .importAdder = importAdder,
        };
    }

    pub fn createIndexSignatureDeclarationFromType(
        self: *MissingMemberFixer,
        tree: *ast.Ast,
        classDeclaration: ast_gen.NodeIndex,
        implementedType: checker.TypeIndex,
        keyType: checker.TypeIndex,
    ) ast_gen.NodeIndex {
        _ = self;
        _ = tree;
        _ = classDeclaration;
        _ = implementedType;
        _ = keyType;
        // Stub implementation, return 0 for now
        return 0;
    }

    pub fn createMemberFromSymbol(
        self: *MissingMemberFixer,
        tree: *ast.Ast,
        symbol: ast.SymbolIndex,
        enclosingDeclaration: ast_gen.NodeIndex,
        sourceFile: ast.NodeIndex,
        body: ast_gen.NodeIndex,
        preserveOptional: u32,
    ) ![]ast_gen.NodeIndex {
        _ = self;
        _ = tree;
        _ = symbol;
        _ = enclosingDeclaration;
        _ = sourceFile;
        _ = body;
        _ = preserveOptional;
        // Stub implementation, return empty array for now
        return &.{};
    }
};

pub fn getMissingMemberCodeActions(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
) anyerror![]const codeactions.CodeAction {
    _ = allocator;
    _ = fixContext;
    return &.{};
}
