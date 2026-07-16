const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListInstanceProtectedMembers2" {
    const content =
        \\class Base {
        \\    private privateMethod() { }
        \\    private privateProperty;
        \\
        \\    protected protectedMethod() { }
        \\    protected protectedProperty;
        \\
        \\    public publicMethod() { }
        \\    public publicProperty;
        \\
        \\    protected protectedOverriddenMethod() { }
        \\    protected protectedOverriddenProperty;
        \\}
        \\
        \\class C1 extends Base {
        \\    protected  protectedOverriddenMethod() { }
        \\    protected  protectedOverriddenProperty;
        \\
        \\    test() {
        \\        this./*1*/;
        \\        super./*2*/;
        \\
        \\        var b: Base;
        \\        var c: C1;
        \\
        \\        b./*3*/;
        \\        c./*4*/;
        \\    }
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
//                 "protectedMethod",
//                 "protectedProperty",
//                 "publicMethod",
//                 "publicProperty",
//                 "protectedOverriddenMethod",
//                 "protectedOverriddenProperty",
//             },
//             .Excludes = &.{
//                 "privateMethod",
//                 "privateProperty",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "protectedMethod",
//                 "publicMethod",
//                 "protectedOverriddenMethod",
//             },
//             .Excludes = &.{
//                 "privateMethod",
//                 "privateProperty",
//                 "protectedProperty",
//                 "publicProperty",
//                 "protectedOverriddenProperty",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "publicMethod",
//                 "publicProperty",
//             },
//             .Excludes = &.{
//                 "privateMethod",
//                 "privateProperty",
//                 "protectedMethod",
//                 "protectedProperty",
//                 "protectedOverriddenMethod",
//                 "protectedOverriddenProperty",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "protectedMethod",
//                 "protectedProperty",
//                 "publicMethod",
//                 "publicProperty",
//                 "protectedOverriddenMethod",
//                 "protectedOverriddenProperty",
//             },
//             .Excludes = &.{
//                 "privateMethod",
//                 "privateProperty",
//             },
//         },
//     });
}

test "TestFindAllRefsJsThisPropertyAssignment" {
    const content =
        \\// @allowJs: true
        \\// @noImplicitThis: true
        \\// @Filename: infer.d.ts
        \\export declare function infer(o: { m(): void } & ThisType<{ x: number }>): void;
        \\// @Filename: a.js
        \\import { infer } from "./infer";
        \\infer({
        \\    m() {
        \\        this.x = 1;
        \\        this./*1*/x;
        \\    },
        \\});
        \\// @Filename: b.js
        \\/**
        \\ * @template T
        \\ * @param {{m(): void} & ThisType<{x: number}>} o
        \\ */
        \\function infer(o) {}
        \\infer({
        \\    m() {
        \\        this.x = 2;
        \\        this./*2*/x;
        \\    },
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestRenameDefaultImportDifferentName" {
    const content =
        \\// @Filename: B.ts
        \\[|export default class /*1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}C|] {
        \\    test() {
        \\    }
        \\}|]
        \\// @Filename: A.ts
        \\[|import /*2*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}B|] from "./B";|]
        \\let b = new [|B|]();
        \\b.test();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[3], f.Ranges()[4]);
    // try f.VerifyBaselineDocumentHighlights(undefined, null , "1");
}

test "TestOrganizeImportsAttributes" {
    const content =
        \\import { A } from "./file";
        \\import { type B } from "./file";
        \\import { C } from "./file" with { type: "a" };
        \\import { A as D } from "./file" with { type: "b" };
        \\import { E } from "./file" with { type: "a" };
        \\import { A as F } from "./file" with { type: "b" };
        \\
        \\type G = A | B | C | D | E | F;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import { A, type B } from \"./file\";\nimport { C, E } from \"./file\" with { type: \"a\" };\nimport { A as D, A as F } from \"./file\" with { type: \"b\" };\n\ntype G = A | B | C | D | E | F;",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestGoToImplementationNamespace_05" {
    const content =
        \\namespace /*implementation0*/Foo./*implementation2*/Baz {
        \\    export function hello() {}
        \\}
        \\
        \\module /*implementation1*/Bar./*implementation3*/Baz {
        \\    export function sure() {}
        \\}
        \\
        \\let x = Fo/*reference0*/o;
        \\let y = Ba/*reference1*/r;
        \\let x1 = Foo.B/*reference2*/az;
        \\let y1 = Bar.B/*reference3*/az;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "reference0", "reference1", "reference2", "reference3");
}

test "TestDocumentHighlightAtInheritedProperties3" {
    const content =
        \\// @Filename: file1.ts
        \\interface interface1 extends interface1 {
        \\   [|doStuff|](): void;
        \\   [|propName|]: string;
        \\}
        \\
        \\var v: interface1;
        \\v.[|propName|];
        \\v.[|doStuff|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGoToTypeDefinition2" {
    const content =
        \\// @Filename: goToTypeDefinition2_Definition.ts
        \\interface /*definition*/I1 {
        \\    p;
        \\}
        \\type propertyType = I1;
        \\interface I2 {
        \\    property: propertyType;
        \\}
        \\// @Filename: goToTypeDefinition2_Consumption.ts
        \\var i2: I2;
        \\i2.prop/*reference*/erty;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToTypeDefinition(undefined, "reference");
}

test "TestCompletionListInFatArrow" {
    const content =
        \\var items = [0, 1, 2];
        \\items.forEach((n) => {
        \\    /**/
        \\    var q = n;
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "it");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "items",
//             },
//         },
//     });
}

test "TestCompletionEntryForArrayElementConstrainedToString" {
    const content =
        \\declare function test<T extends 'a' | 'b'>(a: { foo: T[] }): void
        \\
        \\test({ foo: [/*ts*/] })
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"ts"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "\"a\"",
//                 "\"b\"",
//             },
//         },
//     });
}

test "TestSemanticModernClassificationObjectProperties" {
    const content =
        \\let x = 1, y = 1;
        \\const a1 = { e: 1 };
        \\var a2 = { x };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "variable.declaration", .Text = "y"},
//         .{.Type = "variable.declaration.readonly", .Text = "a1"},
//         .{.Type = "property.declaration", .Text = "e"},
//         .{.Type = "variable.declaration", .Text = "a2"},
//         .{.Type = "property.declaration", .Text = "x"},
//     });
}

