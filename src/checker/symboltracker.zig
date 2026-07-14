const std = @import("std");
const ast = @import("../ast/ast.zig");
const ast_gen = @import("../ast/ast_generated.zig");
const NodeIndex = ast_gen.NodeIndex;
const checker_mod = @import("checker.zig");
const SymbolIndex = checker_mod.SymbolIndex;
const NodeBuilderContext = @import("../nodebuilder/nodebuilder.zig").NodeBuilderContext;

pub const TrackedSymbolArgs = struct {
    symbol: SymbolIndex,
    enclosingDeclaration: NodeIndex,
    meaning: u32,
};

pub const SymbolTrackerImpl = struct {
    context: *NodeBuilderContext,
    // Note: We use a placeholder inner interface, actual dispatch depends on nodebuilder architecture
    inner: ?*anyopaque,
    disableTrackSymbol: bool,

    pub fn init(context: *NodeBuilderContext, tracker: ?*anyopaque) SymbolTrackerImpl {
        return .{
            .context = context,
            .inner = tracker,
            .disableTrackSymbol = false,
        };
    }

    pub fn trackSymbol(self: *SymbolTrackerImpl, symbol: SymbolIndex, enclosingDeclaration: NodeIndex, meaning: u32) bool {
        if (!self.disableTrackSymbol) {
            // Note: If inner tracker tracking is true, return true (omitted until inner interface is defined)

            const flags = self.context.checker.getSymbolFlags(symbol);
            if ((flags & ast.SymbolFlags.TypeParameter) == 0) {
                self.context.trackedSymbols.append(.{
                    .symbol = symbol,
                    .enclosingDeclaration = enclosingDeclaration,
                    .meaning = meaning,
                }) catch unreachable;
            }
        }
        return false;
    }

    pub fn reportInaccessibleThisError(self: *SymbolTrackerImpl) void {
        self.onDiagnosticReported();
    }

    pub fn reportPrivateInBaseOfClassExpression(self: *SymbolTrackerImpl, propertyName: []const u8) void {
        self.onDiagnosticReported();
        _ = propertyName;
    }

    pub fn reportInaccessibleUniqueSymbolError(self: *SymbolTrackerImpl) void {
        self.onDiagnosticReported();
    }

    pub fn reportCyclicStructureError(self: *SymbolTrackerImpl) void {
        self.onDiagnosticReported();
    }

    pub fn reportLikelyUnsafeImportRequiredError(self: *SymbolTrackerImpl, specifier: []const u8, symbolName: []const u8) void {
        self.onDiagnosticReported();
        _ = specifier;
        _ = symbolName;
    }

    pub fn reportTruncationError(self: *SymbolTrackerImpl) void {
        self.onDiagnosticReported();
    }

    pub fn reportNonlocalAugmentation(self: *SymbolTrackerImpl, containingFile: NodeIndex, parentSymbol: SymbolIndex, augmentingSymbol: SymbolIndex) void {
        self.onDiagnosticReported();
        _ = containingFile;
        _ = parentSymbol;
        _ = augmentingSymbol;
    }

    pub fn reportNonSerializableProperty(self: *SymbolTrackerImpl, propertyName: []const u8) void {
        self.onDiagnosticReported();
        _ = propertyName;
    }

    fn onDiagnosticReported(self: *SymbolTrackerImpl) void {
        self.context.reportedDiagnostic = true;
    }

    pub fn reportInferenceFallback(self: *SymbolTrackerImpl, node: NodeIndex) void {
        _ = self;
        _ = node;
    }

    pub fn pushErrorFallbackNode(self: *SymbolTrackerImpl, node: NodeIndex) void {
        _ = self;
        _ = node;
    }

    pub fn popErrorFallbackNode(self: *SymbolTrackerImpl) void {
        _ = self;
    }
};
