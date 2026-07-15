const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestSuggestionOfUnusedVariableWithExternalModule" {
    const content =
        \\//@allowJs: true
        \\//@module: commonjs
        \\// @Filename: /mymodule.js
        \\(function ([|root|], factory) {
        \\    module.exports = factory();
        \\}(this, function () {
        \\    var [|unusedVar|] = "something";
        \\    return {};
        \\}));
        \\// @Filename: /app.js
        \\//@ts-check
        \\[|require("./mymodule")|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/app.js");
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(80001))},
//             .Message = .{.String = undefined("File is a CommonJS module; it may be converted to an ES module.")},
//             .Range =   f.Ranges()[2].LSRange,
//         },
//     });
    _ = f.GoToFile(undefined, "/mymodule.js");
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Message = .{.String = undefined("'root' is declared but its value is never read.")},
//             .Code =    &.{.Integer = undefined(int32(6133))},
//             .Range =   f.Ranges()[0].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagUnnecessary},
//         },
//         .{
//             .Message = .{.String = undefined("'unusedVar' is declared but its value is never read.")},
//             .Code =    &.{.Integer = undefined(int32(6133))},
//             .Range =   f.Ranges()[1].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagUnnecessary},
//         },
//     });
}

test "TestQuickInfoMappedSpreadTypes" {
    const content =
        \\interface Foo {
        \\    /** Doc */
        \\    bar: number;
        \\}
        \\
        \\const f: Foo = { bar: 0 };
        \\f./*f*/bar;
        \\
        \\const f2: { [TKey in keyof Foo]: string } = { bar: "0" };
        \\f2./*f2*/bar;
        \\
        \\const f3 = { ...f };
        \\f3./*f3*/bar;
        \\
        \\const f4 = { ...f2 };
        \\f4./*f4*/bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "f");
    _ = f.VerifyQuickInfoIs(undefined, "(property) Foo.bar: number", "Doc");
    _ = f.GoToMarker(undefined, "f2");
    _ = f.VerifyQuickInfoIs(undefined, "(property) bar: string", "Doc");
    _ = f.GoToMarker(undefined, "f3");
    _ = f.VerifyQuickInfoIs(undefined, "(property) Foo.bar: number", "Doc");
    _ = f.GoToMarker(undefined, "f4");
    _ = f.VerifyQuickInfoIs(undefined, "(property) bar: string", "Doc");
}

test "TestFindAllRefsObjectBindingElementPropertyName03" {
    const content =
        \\interface I {
        \\    /*1*/property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\var [ { property1: prop1 }, { /*2*/property1, property2 } ] = [foo, foo];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestCompletionListInUnclosedFunction03" {
    const content =
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string, c: typeof /*1*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "foo",
//                 "x",
//                 "y",
//                 "z",
//                 "bar",
//                 "a",
//                 "b",
//             },
//         },
//     });
}

test "TestCodeFixClassImplementInterfaceEmptyMultilineBody" {
    const content =
        \\// @lib: es2017
        \\interface I {
        \\    x: number;
        \\    y: number;
        \\}
        \\class C implements I {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    x: number;\n    y: number;\n}\nclass C implements I {\n    x: number;\n    y: number;\n}",
        .Index = 0,
    });
}

test "TestImportNameCodeFix_reExportDefault" {
    const content =
        \\// @Filename: /user.ts
        \\foo;
        \\// @Filename: /user2.ts
        \\unnamed;
        \\// @Filename: /user3.ts
        \\reExportUnnamed;
        \\// @Filename: /reExportNamed.ts
        \\export { default } from "./named";
        \\// @Filename: /reExportUnnamed.ts
        \\export { default } from "./unnamed";
        \\// @Filename: /named.ts
        \\function foo() {}
        \\export default foo;
        \\// @Filename: /unnamed.ts
        \\export default 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/user.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import foo from \"./named\";\n\nfoo;",
        "import foo from \"./reExportNamed\";\n\nfoo;",
    }, null );
    _ = f.GoToFile(undefined, "/user2.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import unnamed from \"./unnamed\";\n\nunnamed;",
        "import unnamed from \"./reExportUnnamed\";\n\nunnamed;",
    }, null );
    _ = f.GoToFile(undefined, "/user3.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import reExportUnnamed from \"./reExportUnnamed\";\n\nreExportUnnamed;",
    }, null );
}

test "TestGoToImplementationShorthandPropertyAssignment_01" {
    const content =
        \\interface Foo {
        \\    someFunction(): void;
        \\}
        \\
        \\interface FooConstructor {
        \\    new (): Foo
        \\}
        \\
        \\interface Bar {
        \\    Foo: FooConstructor;
        \\}
        \\
        \\// Class expression that gets used in a bar implementation
        \\var x = class [|Foo|] {
        \\    createBarInClassExpression(): Bar {
        \\        return {
        \\            Foo
        \\        };
        \\    }
        \\
        \\    someFunction() {}
        \\};
        \\
        \\// Class declaration that gets used in a bar implementation. This class has multiple definitions
        \\// (the class declaration and the interface above), but we only want the class returned
        \\class [|Foo|] {
        \\
        \\}
        \\
        \\function createBarUsingClassDeclaration(): Bar {
        \\    return {
        \\        Foo
        \\    };
        \\}
        \\
        \\// Class expression that does not get used in a bar implementation
        \\var y = class Foo {
        \\    someFunction() {}
        \\};
        \\
        \\createBarUsingClassDeclaration().Fo/*reference*/o;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "reference");
}

test "TestReferencesBloomFilters3" {
    const content =
        \\// @Filename: declaration.ts
        \\enum Test { /*1*/"/*2*/42" = 1 };
        \\// @Filename: expression.ts
        \\(Test[/*3*/42]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestCodeFixAddMissingFunctionDeclaration20" {
    const content =
        \\const a = {
        \\   b: { f(x: number) {} }
        \\}
        \\a.b.f(foo);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "fixMissingFunctionDeclaration");
}

test "TestGotoDefinitionSatisfiesTag" {
    const content =
        \\// @noEmit: true
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @filename: /a.js
        \\/**
        \\ * @typedef {Object} [|/*def*/T|]
        \\ * @property {number} a
        \\ */
        \\
        \\/** @satisfies {/*use*/[|T|]} comment */
        \\const foo = { a: 1 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, false, "use");
}

