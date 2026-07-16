const std = @import("std");

const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const astnav = @import("../astnav/astnav.zig");
const checker = @import("../checker/checker.zig");
const compiler = @import("../compiler/program.zig");
const core = @import("../core/core.zig");
const diagnostics_gen = @import("../diagnostics/diagnostics_generated.zig");
const autoimport = @import("autoimport/autoimport.zig");
const change = @import("change/tracker.zig");
const lsproto = @import("../lsp/lsproto/lsproto.zig");
const scanner = @import("../scanner/scanner.zig");
const codeactions = @import("codeactions.zig");
const missingmemberfixer = @import("codeactions_missingmemberfixer.zig");

pub const fixClassIncorrectlyImplementsInterfaceFixID = "fixClassIncorrectlyImplementsInterface";

pub const fixClassIncorrectlyImplementsInterfaceErrorCodes = &[_]u32{
    diagnostics_gen.Class_0_incorrectly_implements_interface_1.code,
    diagnostics_gen.Class_0_incorrectly_implements_class_1_Did_you_mean_to_extend_1_and_inherit_its_members_as_a_subclass.code,
};

pub const fixClassIncorrectlyImplementsInterfaceProvider = codeactions.CodeFixProvider{
    .errorCodes = fixClassIncorrectlyImplementsInterfaceErrorCodes,
    .getCodeActions = getCodeActionsToFixClassIncorrectlyImplementsInterface,
    .fixIds = &[_][]const u8{fixClassIncorrectlyImplementsInterfaceFixID},
    .getAllCodeActions = getAllCodeActionsToFixClassIncorrectlyImplementsInterface,
};

pub fn getCodeActionsToFixClassIncorrectlyImplementsInterface(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
) anyerror![]const codeactions.CodeAction {
    const tree = fixContext.program.getAst(fixContext.sourceFile) orelse return &.{};
    const classDeclaration = getClass(tree, fixContext.span);
    if (classDeclaration == 0) return &.{};

    const implementsTypes = ast.getImplementsTypeNodes(allocator, tree, classDeclaration);
    defer allocator.free(implementsTypes);

    const typeChecker = try fixContext.program.getTypeChecker(allocator);
    defer fixContext.program.releaseTypeChecker(typeChecker);

    var actions = std.ArrayList(codeactions.CodeAction).init(allocator);
    errdefer actions.deinit();

    for (implementsTypes) |implementedTypeNode| {
        var changeTracker = change.ChangeTracker.init(
            allocator,
            fixContext.ls.formatOptions(),
            fixContext.ls.host.getNewLine(),
            fixContext.ls.converters,
        );
        defer changeTracker.deinit();

        var importAdder = try createImportAdder(allocator, fixContext, typeChecker);
        defer if (importAdder) |*adder| adder.deinit();

        try addChanges(allocator, fixContext, tree, &changeTracker, if (importAdder) |*a| a else null, typeChecker, classDeclaration, implementedTypeNode);

        var changes_map = changeTracker.getChanges();
        defer changes_map.deinit(allocator, allocator);

        const changes = getChanges(allocator, tree, &changes_map, if (importAdder) |*a| a else null);
        if (changes.len == 0) continue;

        const interfaceName = ast.text(tree, implementedTypeNode);
        var description = std.ArrayList(u8).init(allocator);
        defer description.deinit();
        try description.writer().print("Implement interface '{s}'", .{interfaceName});

        try actions.append(.{
            .description = try description.toOwnedSlice(),
            .changes = changes,
            .fixID = fixClassIncorrectlyImplementsInterfaceFixID,
            .fixAllDescription = "Implement all unimplemented interfaces",
        });
    }
    return try actions.toOwnedSlice();
}

pub fn getAllCodeActionsToFixClassIncorrectlyImplementsInterface(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
) anyerror!?codeactions.CombinedCodeActions {
    const tree = fixContext.program.getAst(fixContext.sourceFile) orelse return null;

    const typeChecker = try fixContext.program.getTypeChecker(allocator);
    defer fixContext.program.releaseTypeChecker(typeChecker);

    var changeTracker = change.ChangeTracker.init(
        allocator,
        fixContext.ls.formatOptions(),
        fixContext.ls.host.getNewLine(),
        fixContext.ls.converters,
    );
    defer changeTracker.deinit();

    var importAdder = try createImportAdder(allocator, fixContext, typeChecker);
    defer if (importAdder) |*adder| adder.deinit();

    var seenClassDeclarations = std.AutoHashMap(ast_gen.NodeIndex, void).init(allocator);
    defer seenClassDeclarations.deinit();

    const allDiags = try fixContext.program.getSemanticDiagnostics(allocator, fixContext.sourceFile);
    defer allocator.free(allDiags);

    for (allDiags) |*diag| {
        if (!containsErrorCode(fixClassIncorrectlyImplementsInterfaceErrorCodes, diag.message.code)) continue;

        const classDeclaration = getClass(tree, .{ .pos = diag.start, .end = diag.start + diag.length });
        if (classDeclaration == 0) continue;

        if (seenClassDeclarations.contains(classDeclaration)) continue;
        try seenClassDeclarations.put(classDeclaration, {});

        const implementsTypes = ast.getImplementsTypeNodes(allocator, tree, classDeclaration);
        defer allocator.free(implementsTypes);

        for (implementsTypes) |implementedTypeNode| {
            try addChanges(allocator, fixContext, tree, &changeTracker, if (importAdder) |*a| a else null, typeChecker, classDeclaration, implementedTypeNode);
        }
    }

    var changes_map = changeTracker.getChanges();
    defer changes_map.deinit(allocator, allocator);

    const changes = getChanges(allocator, tree, &changes_map, if (importAdder) |*a| a else null);
    if (changes.len == 0) return null;

    return .{
        .description = "Implement all unimplemented interfaces",
        .changes = changes,
    };
}

fn addChanges(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
    tree: *ast.Ast,
    changeTracker: *change.ChangeTracker,
    importAdder: ?*autoimport.ImportAdder,
    typeChecker: *checker.Checker,
    classDeclaration: ast_gen.NodeIndex,
    implementedTypeNode: ast_gen.NodeIndex,
) !void {
    var missingMemberFixer = missingmemberfixer.MissingMemberFixer.init(
        allocator,
        changeTracker,
        typeChecker,
        fixContext.program,
        fixContext.ls.userPreferences(),
        importAdder,
    );

    const constructor = getConstructor(tree, classDeclaration);
    const implementedType = try typeChecker.getTypeAtLocation(allocator, implementedTypeNode);
    const classType = try typeChecker.getTypeAtLocation(allocator, classDeclaration);

    if (typeChecker.getNumberIndexType(classType) == null) {
        const member = missingMemberFixer.createIndexSignatureDeclarationFromType(tree, classDeclaration, implementedType, typeChecker.getNumberType());
        if (member != 0) {
            insertInterfaceMemberNode(changeTracker, tree, classDeclaration, constructor, member);
        }
    }

    if (typeChecker.getStringIndexType(classType) == null) {
        const member = missingMemberFixer.createIndexSignatureDeclarationFromType(tree, classDeclaration, implementedType, typeChecker.getStringType());
        if (member != 0) {
            insertInterfaceMemberNode(changeTracker, tree, classDeclaration, constructor, member);
        }
    }

    const implementedTypes = &[_]checker.TypeIndex{implementedType};
    const missingMembers = try getMissingMembers(allocator, tree, typeChecker, classDeclaration, implementedTypes);
    defer allocator.free(missingMembers);

    for (missingMembers) |member| {
        const memberNodes = try missingMemberFixer.createMemberFromSymbol(tree, member, classDeclaration, fixContext.sourceFile, 0, missingmemberfixer.preserveOptionalFlagsAll);
        defer allocator.free(memberNodes);

        for (memberNodes) |memberNode| {
            insertInterfaceMemberNode(changeTracker, tree, classDeclaration, constructor, memberNode);
        }
    }
}

fn getChanges(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    changesMap: *std.StringHashMapUnmanaged([]const lsproto.TextEdit),
    importAdder: ?*autoimport.ImportAdder,
) []const lsproto.TextEdit {
    const file_name = tree.path;
    var fileChanges = changesMap.get(file_name) orelse &.{};

    if (importAdder != null and importAdder.?.hasFixes()) {
        const edits = importAdder.?.edits() catch &.{};
        if (edits.len > 0) {
            var combined = std.ArrayList(lsproto.TextEdit).init(allocator);
            combined.appendSlice(fileChanges) catch {};
            for (edits) |e| combined.append(e.*) catch {};
            fileChanges = combined.toOwnedSlice() catch &.{};
        }
    }
    return fileChanges;
}

fn insertInterfaceMemberNode(
    changeTracker: *change.ChangeTracker,
    tree: *ast.Ast,
    classDeclaration: ast_gen.NodeIndex,
    constructor: ast_gen.NodeIndex,
    member: ast_gen.NodeIndex,
) void {
    if (constructor == 0) {
        changeTracker.insertMemberAtStart(tree, classDeclaration, member);
    } else {
        changeTracker.insertNodeAfter(tree, constructor, member);
    }
}

fn getClass(tree: *ast.Ast, span: ast.TextRange) ast_gen.NodeIndex {
    const token = astnav.getTokenAtPosition(tree, span.pos);
    if (token == 0) return 0;
    return astnav.getContainingClass(tree, token);
}

fn getConstructor(tree: *ast.Ast, classDeclaration: ast_gen.NodeIndex) ast_gen.NodeIndex {
    if (classDeclaration == 0) return 0;
    const cd = ast_gen.ClassDeclaration.cast(tree, classDeclaration) orelse return 0;
    const members = cd.members orelse return 0;
    const nodeList = ast_gen.NodeList.cast(tree, members) orelse return 0;

    for (nodeList.nodes.items) |member| {
        if (member != 0 and ast.kind(tree, member) == .Constructor) {
            return member;
        }
    }
    return 0;
}

fn getMissingMembers(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    typeChecker: *checker.Checker,
    classDeclaration: ast_gen.NodeIndex,
    implementedTypes: []const checker.TypeIndex,
) ![]ast.SymbolIndex {
    const inheritedMembers = try getInheritedMembers(allocator, tree, typeChecker, classDeclaration);
    defer inheritedMembers.deinit(allocator);

    var seenMembers = std.StringHashMap(ast.SymbolIndex).init(allocator);
    defer seenMembers.deinit();

    var classMembers: ?*const ast.SymbolTable = null;
    const classSymbol = typeChecker.symbolForNode(classDeclaration);
    if (classSymbol != null) {
        classMembers = &typeChecker.symbols.items[classSymbol.?].members;
    }

    var missingMembers = std.ArrayList(ast.SymbolIndex).init(allocator);

    for (implementedTypes) |implementedType| {
        const properties = typeChecker.getPropertiesOfType(allocator, implementedType);
        defer allocator.free(properties);

        for (properties) |symbol| {
            if (symbol == 0) continue;

            const symbolName = typeChecker.symbolName(symbol);
            if (classMembers != null and classMembers.?.contains(symbolName)) continue;
            if (inheritedMembers.contains(symbolName) or seenMembers.contains(symbolName)) continue;

            const flags = checker.getDeclarationModifierFlagsFromSymbol(typeChecker, symbol);
            if ((flags & .Private) == .None) {
                try seenMembers.put(symbolName, symbol);
                try missingMembers.append(symbol);
            }
        }
    }
    return try missingMembers.toOwnedSlice();
}

fn getInheritedMembers(
    allocator: std.mem.Allocator,
    tree: *ast.Ast,
    typeChecker: *checker.Checker,
    classDeclaration: ast_gen.NodeIndex,
) !std.StringHashMapUnmanaged(ast.SymbolIndex) {
    const typeNode = ast.getClassExtendsHeritageElement(tree, classDeclaration);
    if (typeNode == 0) return .{};

    const baseType = try typeChecker.getTypeAtLocation(allocator, typeNode);
    if (baseType == 0) return .{};

    var inheritedMembers = std.StringHashMapUnmanaged(ast.SymbolIndex){};
    const properties = typeChecker.getPropertiesOfType(allocator, baseType);
    defer allocator.free(properties);

    for (properties) |symbol| {
        if (symbol == 0) continue;
        const flags = checker.getDeclarationModifierFlagsFromSymbol(typeChecker, symbol);
        if ((flags & .Private) == .None) {
            try inheritedMembers.put(allocator, typeChecker.symbolName(symbol), symbol);
        }
    }
    return inheritedMembers;
}

fn createImportAdder(
    allocator: std.mem.Allocator,
    fixContext: *codeactions.CodeFixContext,
    typeChecker: *checker.Checker,
) !?autoimport.ImportAdder {
    const view = try fixContext.ls.getPreparedAutoImportView(allocator, fixContext.sourceFile);
    if (view == null) return null;

    return autoimport.ImportAdder.init(
        allocator,
        fixContext.program,
        typeChecker,
        fixContext.sourceFile,
        view.?,
        fixContext.ls.formatOptions(),
        fixContext.ls.converters,
        fixContext.ls.userPreferences(),
    );
}

fn containsErrorCode(codes: []const u32, code: u32) bool {
    for (codes) |c| {
        if (c == code) return true;
    }
    return false;
}
