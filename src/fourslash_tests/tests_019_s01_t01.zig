const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGoToTypeDefinition_Pick" {
    const content =
        \\// @lib: es5
        \\type User = { id: number; name: string; };
        \\declare const user: Pick<User, "name">
        \\/*reference*/user
        \\
        \\type PickedUser = Pick<User, "name">
        \\declare const user2: PickedUser
        \\/*reference2*/user2
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToTypeDefinition(undefined, "reference", "reference2");
}

test "TestGoToDefinitionMember" {
    const content =
        \\// @Filename: /a.ts
        \\class A {
        \\    private z/*z*/: string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "z");
}

test "TestCodeFixMissingTypeAnnotationOnExports16" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo() {
        \\    return { x: 1, y: {42: {dd: "45"}, b: 2} };
        \\}
        \\function foo3(): "42" {
        \\    return "42";
        \\}
        \\export const { x: a , y: { [foo3()]: {dd: e} } } = foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract binding expressions to variable",
        .NewFileContent = "function foo() {\n    return { x: 1, y: {42: {dd: \"45\"}, b: 2} };\n}\nfunction foo3(): \"42\" {\n    return \"42\";\n}\nconst dest = foo();\nexport const a: number = dest.x;\nconst _a = foo3();\nexport const e: string = (dest.y)[_a].dd;",
        .Index = 0,
    });
}

test "TestGoToDefinitionSatisfiesExpression1" {
    const content =
        \\const STRINGS = {
        \\    [|/*definition*/title|]: 'A Title',
        \\} satisfies Record<string,string>;
        \\
        \\//somewhere in app
        \\STRINGS.[|/*usage*/title|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "definition", "usage");
}

test "TestImportNameCodeFixExportAsDefault" {
    const content =
        \\// @Filename: /foo.ts
        \\const foo = 'foo'
        \\export { foo as default }
        \\// @Filename: /index.ts
        \\ foo/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "foo",
//         .Source =      "./foo",
//         .Description = "Add import from \"./foo\"",
//         .NewFileContent = undefined("import foo from \"./foo\";\n\nfoo"),
//     });
}

test "TestCompletionListInTypeLiteralInTypeParameter19" {
    const content =
        \\class Foo<T extends 'one' | 'two'> {}
        \\function foo<T extends 'one' | 'two'>() {}
        \\declare function tag<T extends 'one' | 'two'>(x: TemplateStringsArray): void;
        \\declare function decorator<T extends 'one' | 'two'>(...args: unknown[]): never
        \\
        \\type A = Foo<'/*0*/'>;
        \\new Foo<'/*1*/'>();
        \\foo<'/*2*/'>();
        \\foo<'/*3*/'>;
        \\Foo<'/*4*/'>;
        \\tag<'/*5*/'>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "one",
//                 "two",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "one",
//                 "two",
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
//             .Unsorted = &.{
//                 "one",
//                 "two",
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
//             .Unsorted = &.{
//                 "one",
//                 "two",
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
//             .Unsorted = &.{
//                 "one",
//                 "two",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "one",
//                 "two",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "one",
//                 "two",
//             },
//         },
//     });
}

test "TestContextualTypingOfGenericCallSignatures2" {
    const content =
        \\interface I {
        \\    <T>(x: T): void
        \\}
        \\function f6(x: <T extends I>(p: T) => void) { }
        \\// x should not be contextually typed so this should be an error
        \\f6(/**/x => x<number>())
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(parameter) x: T extends I", "");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestAugmentedTypesClass3Fourslash" {
    const content =
        \\class c/*1*/5b { public foo() { } }
        \\namespace c/*2*/5b { export var y = 2; } // should be ok
        \\/*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "class c5b\nnamespace c5b", "");
    try f.VerifyQuickInfoAt(undefined, "2", "class c5b\nnamespace c5b", "");
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "c5b",
//                     .Detail = undefined("class c5b\nnamespace c5b"),
//                 },
//             },
//         },
//     });
}

test "TestFormattingInDestructuring5" {
    const content =
        \\let a, b;
        \\/*1*/if (false)[a, b] = [1, 2];
        \\/*2*/if (true)        [a, b] = [1, 2];
        \\/*3*/var a = [1, 2, 3].map(num => num) [0];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "if (false) [a, b] = [1, 2];");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "if (true) [a, b] = [1, 2];");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "var a = [1, 2, 3].map(num => num)[0];");
}

test "TestCodeFixMissingTypeAnnotationOnExports19" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @lib: es2019
        \\export const a = {
        \\    z: Symbol()
        \\} as const;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type '{ readonly z: symbol; }'",
        .NewFileContent = "export const a: {\n    readonly z: symbol;\n} = {\n    z: Symbol()\n} as const;",
        .Index = 0,
    });
}

