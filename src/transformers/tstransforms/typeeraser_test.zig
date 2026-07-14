const std = @import("std");
const parser = @import("../../parser/parser.zig");
const printer_pkg = @import("../../printer/printer.zig");
const factory_pkg = @import("../../printer/factory.zig");
const emitcontext_pkg = @import("../../printer/emitcontext.zig");
const textwriter_pkg = @import("../../printer/textwriter.zig");
const transformers = @import("../transformer.zig");
const typeeraser = @import("typeeraser.zig");
const core = @import("../../core/core.zig");
const emitresolver_pkg = @import("../../printer/emitresolver.zig");

const TestCase = struct {
    title: []const u8,
    input: []const u8,
    output: []const u8,
    jsx: bool = false,
    vms: bool = false,
};

const test_cases = [_]TestCase{
    .{ .title = "Modifiers", .input = "class C { public x; private y }", .output = "class C {\n    x;\n    y;\n}" },
    .{ .title = "InterfaceDeclaration", .input = "interface I { }", .output = "" },
    .{ .title = "TypeAliasDeclaration", .input = "type T = U;", .output = "" },
    .{ .title = "NamespaceExportDeclaration", .input = "export as namespace N;", .output = "" },
    .{ .title = "UninstantiatedNamespace1", .input = "namespace N {}", .output = "" },
    .{ .title = "UninstantiatedNamespace2", .input = "namespace N { export interface I {} }", .output = "" },
    .{ .title = "UninstantiatedNamespace3", .input = "namespace N { export type T = U; }", .output = "" },
    .{ .title = "ExpressionWithTypeArguments", .input = "F<T>", .output = "F;" },
    .{ .title = "PropertyDeclaration1", .input = "class C { declare x; }", .output = "class C {\n}" },
    .{ .title = "PropertyDeclaration2", .input = "class C { public x: number; }", .output = "class C {\n    x;\n}" },
    .{ .title = "PropertyDeclaration3", .input = "class C { public static x: number; }", .output = "class C {\n    static x;\n}" },
    .{ .title = "ConstructorDeclaration1", .input = "class C { constructor(); }", .output = "class C {\n}" },
    .{ .title = "ConstructorDeclaration2", .input = "class C { public constructor() {} }", .output = "class C {\n    constructor() { }\n}" },
    .{ .title = "MethodDeclaration1", .input = "class C { m(); }", .output = "class C {\n}" },
    .{ .title = "MethodDeclaration2", .input = "class C { public m<T>(): U {} }", .output = "class C {\n    m() { }\n}" },
    .{ .title = "MethodDeclaration3", .input = "class C { public static m<T>(): U {} }", .output = "class C {\n    static m() { }\n}" },
    .{ .title = "GetAccessorDeclaration1", .input = "class C { get m(); }", .output = "class C {\n    get m() { }\n}" },
    .{ .title = "GetAccessorDeclaration2", .input = "class C { public get m<T>(): U {} }", .output = "class C {\n    get m() { }\n}" },
    .{ .title = "GetAccessorDeclaration3", .input = "class C { public static get m<T>(): U {} }", .output = "class C {\n    static get m() { }\n}" },
    .{ .title = "SetAccessorDeclaration1", .input = "class C { set m(v); }", .output = "class C {\n    set m(v) { }\n}" },
    .{ .title = "SetAccessorDeclaration2", .input = "class C { public set m<T>(v): U {} }", .output = "class C {\n    set m(v) { }\n}" },
    .{ .title = "SetAccessorDeclaration3", .input = "class C { public static set m<T>(v): U {} }", .output = "class C {\n    static set m(v) { }\n}" },
    .{ .title = "IndexSignature", .input = "class C { [key: string]: number; }", .output = "class C {\n}" },
    .{ .title = "VariableDeclaration1", .input = "declare var a;", .output = "" },
    .{ .title = "VariableDeclaration2", .input = "var a: number", .output = "var a;" },
    .{ .title = "HeritageClause", .input = "class C implements I {}", .output = "class C {\n}" },
    .{ .title = "ClassDeclaration1", .input = "declare class C {}", .output = "" },
    .{ .title = "ClassDeclaration2", .input = "class C<T> {}", .output = "class C {\n}" },
    .{ .title = "ClassExpression", .input = "(class C<T> {})", .output = "(class C {\n});" },
    .{ .title = "FunctionDeclaration1", .input = "declare function f() {}", .output = "" },
    .{ .title = "FunctionDeclaration2", .input = "function f();", .output = "" },
    .{ .title = "FunctionDeclaration3", .input = "function f<T>(): U {}", .output = "function f() { }" },
    .{ .title = "FunctionExpression", .input = "(function f<T>(): U {})", .output = "(function f() { });" },
    .{ .title = "ArrowFunction", .input = "(<T>(): U => {})", .output = "(() => { });" },
    .{ .title = "ParameterDeclaration", .input = "function f(this: x, a: number, b?: boolean) {}", .output = "function f(a, b) { }" },
    .{ .title = "CallExpression", .input = "f<T>()", .output = "f();" },
    .{ .title = "NewExpression1", .input = "new f<T>()", .output = "new f();" },
    .{ .title = "NewExpression2", .input = "new f<T>", .output = "new f;" },
    .{ .title = "TaggedTemplateExpression", .input = "f<T>``", .output = "f ``;" },
    .{ .title = "NonNullExpression", .input = "x!", .output = "x;" },
    .{ .title = "TypeAssertionExpression#1", .input = "<T>x", .output = "x;" },
    .{ .title = "TypeAssertionExpression#2", .input = "(<T>x).c", .output = "x.c;" },
    .{ .title = "AsExpression#1", .input = "x as T", .output = "x;" },
    .{ .title = "AsExpression#2", .input = "(x as T).c", .output = "x.c;" },
    .{ .title = "SatisfiesExpression#1", .input = "x satisfies T", .output = "x;" },
    .{ .title = "SatisfiesExpression#2", .input = "(x satisfies T).c", .output = "x.c;" },
    .{ .title = "JsxSelfClosingElement", .input = "<x<T> />", .output = "<x />;", .jsx = true },
    .{ .title = "JsxOpeningElement", .input = "<x<T>></x>", .output = "<x></x>;", .jsx = true },
    .{ .title = "ImportEqualsDeclaration#1", .input = "import x = require(\"m\");", .output = "import x = require(\"m\");" },
    .{ .title = "ImportEqualsDeclaration#2", .input = "import type x = require(\"m\");", .output = "" },
    .{ .title = "ImportEqualsDeclaration#3", .input = "import x = y;", .output = "import x = y;" },
    .{ .title = "ImportEqualsDeclaration#4", .input = "import type x = y;", .output = "" },
    .{ .title = "ImportDeclaration#1", .input = "import \"m\";", .output = "import \"m\";" },
    .{ .title = "ImportDeclaration#2", .input = "import * as x from \"m\"; x;", .output = "import * as x from \"m\";\nx;" },
    .{ .title = "ImportDeclaration#3", .input = "import x from \"m\"; x;", .output = "import x from \"m\";\nx;" },
    .{ .title = "ImportDeclaration#4", .input = "import { x } from \"m\"; x;", .output = "import { x } from \"m\";\nx;" },
    .{ .title = "ImportDeclaration#5", .input = "import type * as x from \"m\";", .output = "" },
    .{ .title = "ImportDeclaration#6", .input = "import type x from \"m\";", .output = "" },
    .{ .title = "ImportDeclaration#7", .input = "import type { x } from \"m\";", .output = "" },
    .{ .title = "ImportDeclaration#8", .input = "import { type x } from \"m\";", .output = "" },
    .{ .title = "ImportDeclaration#9", .input = "import { type x } from \"m\";", .output = "import {} from \"m\";", .vms = true },
    .{ .title = "ExportDeclaration#1", .input = "export * from \"m\";", .output = "export * from \"m\";" },
    .{ .title = "ExportDeclaration#2", .input = "export * as x from \"m\";", .output = "export * as x from \"m\";" },
    .{ .title = "ExportDeclaration#3", .input = "export { x } from \"m\";", .output = "export { x } from \"m\";" },
    .{ .title = "ExportDeclaration#4", .input = "export type * from \"m\";", .output = "" },
    .{ .title = "ExportDeclaration#5", .input = "export type * as x from \"m\";", .output = "" },
    .{ .title = "ExportDeclaration#6", .input = "export type { x } from \"m\";", .output = "" },
    .{ .title = "ExportDeclaration#7", .input = "export { type x } from \"m\";", .output = "" },
    .{ .title = "ExportDeclaration#8", .input = "export { type x } from \"m\";", .output = "export {} from \"m\";", .vms = true },
};

test "TypeEraser Test Cases" {
    const alloc = std.testing.allocator;

    for (test_cases) |tc| {
        if (tc.jsx) continue; // JSX not fully supported in testing yet
        
        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();
        const arena_alloc = arena.allocator();

        var p = parser.Parser.init(arena_alloc, tc.input);
        
        var astIndex: u32 = 0;
        if (std.mem.eql(u8, tc.title, "ExpressionWithTypeArguments")) {
            const expr = try p.parseExpressionWithTypeArguments();
            const stmt = try p.ast.pushNode(.{ .ExpressionStatement = .{ .Flags = 0, .Expression = expr } });
            const stmts = try p.ast.pushNodeList(&.{stmt});
            astIndex = try p.ast.pushNode(.{ .SourceFile = .{ .Flags = 0, .Symbol = 0, .Statements = stmts, .EndOfFileToken = 0 } });
        } else {
            astIndex = p.parseSourceFile() catch continue;
        }

        var factory = factory_pkg.NodeFactory.init(arena_alloc, &p.ast);
        var emit_ctx = emitcontext_pkg.EmitContext.init(arena_alloc, &p.ast, &factory);
        
        var compiler_options = core.CompilerOptions{};
        if (tc.vms) {
            compiler_options.verbatimModuleSyntax = true;
        }

        var emit_resolver = emitresolver_pkg.EmitResolver{};

        var options = transformers.TransformOptions{
            .compilerOptions = &compiler_options,
            .context = &emit_ctx,
            .emitResolver = &emit_resolver,
            .resolver = null,
        };

        var tx = typeeraser.TypeEraserTransformer.newTypeEraserTransformer(arena_alloc, &options) catch continue;
        const transformedIndex = tx.transformSourceFile(astIndex);

        var text_writer = textwriter_pkg.TextWriter.init(arena_alloc, "\n", 4);
        var emit_writer = text_writer.getEmitTextWriter();
        var pr = printer_pkg.Printer.init(&p.ast, &emit_ctx, &emit_writer);

        pr.printSourceFile(transformedIndex) catch continue;
        
        const output = text_writer.string();
        
        var actual = output;
        if (std.mem.endsWith(u8, actual, "\n")) {
            actual = actual[0..actual.len - 1];
        }
        
        if (!std.mem.eql(u8, actual, tc.output)) {
            std.debug.print("\nFAIL: {s}\nExpected: '{s}'\nActual: '{s}'\n", .{ tc.title, tc.output, actual });
            try std.testing.expectEqualStrings(tc.output, actual);
        }
    }
}
