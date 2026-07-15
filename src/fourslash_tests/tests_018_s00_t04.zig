const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestAddMemberNotInNodeModulesDeclarationFile" {
    const content =
        \\// @noImplicitReferences: true
        \\// @traceResolution: true
        \\// @Filename: /node_modules/foo/types.d.ts
        \\interface Response {}
        \\// @Filename: /node_modules/foo/package.json
        \\{ "types": "types.d.ts" }
        \\// @Filename: /foo.ts
        \\import { Response } from 'foo'
        \\declare const resp: Response
        \\resp.test()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/foo.ts");
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestImportNameCodeFixNewImportFileDetachedComments" {
    const content =
        \\[|/**
        \\ * This is a comment intended to be attached to this interface
        \\ */
        \\export interface SomeInterface {
        \\}
        \\f1/*0*/();|]
        \\// @Filename: module.ts
        \\export function f1() {}
        \\export var v1 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"./module\";\n\n/**\n * This is a comment intended to be attached to this interface\n */\nexport interface SomeInterface {\n}\nf1();",
    }, null );
}

test "TestFindAllRefsIsDefinition" {
    const content =
        \\declare function foo(a: number): number;
        \\declare function foo(a: string): string;
        \\declare function foo/*1*/(a: string | number): string | number;
        \\
        \\function foon(a: number): number;
        \\function foon(a: string): string;
        \\function foon/*2*/(a: string | number): string | number {
        \\    return a
        \\}
        \\
        \\foo; foon;
        \\
        \\export const bar/*3*/ = 123;
        \\console.log({ bar });
        \\
        \\interface IFoo {
        \\    foo/*4*/(): void;
        \\}
        \\class Foo implements IFoo {
        \\    constructor(n: number)
        \\    constructor()
        \\    /*5*/constructor(n: number?) { }
        \\    foo/*6*/(): void { }
        \\    static init() { return new this() }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6");
}

test "TestGetOccurrencesThrow4" {
    const content =
        \\function f(a: number) {
        \\    try {
        \\        throw "Hello";
        \\
        \\        try {
        \\            throw 10;
        \\        }
        \\        catch (x) {
        \\            return 100;
        \\        }
        \\        finally {
        \\            throw 10;
        \\        }
        \\    }
        \\    catch (x) {
        \\        throw "Something";
        \\    }
        \\    finally {
        \\        throw "Also something";
        \\    }
        \\    if (a > 0) {
        \\        return (function () {
        \\            [|return|];
        \\            [|return|];
        \\            [|return|];
        \\
        \\            if (false) {
        \\                [|return|] true;
        \\            }
        \\            [|th/**/row|] "Hello!";
        \\        })() || true;
        \\    }
        \\
        \\    throw 10;
        \\
        \\    var unusued = [1, 2, 3, 4].map(x => { throw 4 })
        \\
        \\    return;
        \\    return true;
        \\    throw false;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGoToImplementationTypeAlias_00" {
    const content =
        \\// @Filename: def.d.ts
        \\export type TypeAlias = { P: number }
        \\// @Filename: ref.ts
        \\import { TypeAlias } from "./def";
        \\const c: T/*ref*/ypeAlias = [|{ P: 2 }|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToImplementation(undefined, "ref");
}

test "TestQuickinfoVerbosityIndexType" {
    const content =
        \\interface T1 {
        \\    banana: string;
        \\    grape: number;
        \\    apple: boolean;
        \\}
        \\const x1/*x1*/: keyof T1 = 'banana';
        \\const x2/*x2*/: keyof T1 & ("grape" | "apple") = 'grape';
        \\function fn1<T extends T1>(obj: T, key: keyof T, k2: keyof T1) {
        \\    if (key === k2/*k2*/) {
        \\        return obj[key/*key*/];
        \\    }
        \\    return key;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"x1" = .{0, 1}, .@"x2" = .{0}, .@"k2" = .{0, 1}, .@"key" = .{0}});
}

test "TestCodefixInferFromUsageNullish" {
    const content =
        \\// @strict: false
        \\// @noImplicitAny: true
        \\declare const a: string
        \\function wat([|b |]) {
        \\    b(a ?? 1);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "b: (arg0: string | number) => void", false, 0, 0);
}

test "TestJsdocDeprecated_suggestion4" {
    const content =
        \\interface Foo {
        \\    /** @deprecated */
        \\    f: number
        \\    b: number
        \\    /** @deprecated */
        \\    baz: number
        \\}
        \\declare const f: Foo
        \\f.[|f|];
        \\f.b;
        \\f.[|baz|];
        \\const kf = 'f'
        \\const kb = 'b'
        \\declare const k: 'f' | 'b' | 'baz'
        \\declare const kfb: 'f' | 'b'
        \\declare const kfz: 'f' | 'baz'
        \\declare const keys: keyof Foo
        \\f[[|kf|]]
        \\f[kb]
        \\f[k]
        \\f[kfb]
        \\f[kfz]
        \\f[keys]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Message = .{.String = undefined("'f' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[0].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'baz' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[1].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//         .{
//             .Message = .{.String = undefined("'f' is deprecated.")},
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Range =   f.Ranges()[2].LSRange,
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//         },
//     });
}

test "TestCompletionsImportOrExportSpecifier" {
    const content =
        \\// @Filename: exports.ts
        \\export let foo = 1;
        \\let someValue = 2;
        \\let someType = 3;
        \\type someType2 = 4;
        \\export {
        \\  someValue as "__some value",
        \\  someType as "__some type",
        \\  type someType2 as "__some type2",
        \\};
        \\// @Filename: values.ts
        \\import { /*valueImport0*/ } from "./exports";
        \\import { /*valueImport1*/ as valueImport1 } from "./exports";
        \\import { foo as /*valueImport2*/ } from "./exports";
        \\import { foo, /*valueImport3*/ as valueImport3 } from "./exports";
        \\import * as _a from "./exports";
        \\_a./*namespaceImport1*/;
        \\
        \\export { /*valueExport0*/ } from "./exports";
        \\export { /*valueExport1*/ as valueExport1 } from "./exports";
        \\export { foo as /*valueExport2*/ } from "./exports";
        \\export { foo, /*valueExport3*/ } from "./exports";
        \\// @Filename: types.ts
        \\import { type /*typeImport0*/ } from "./exports";
        \\import { type /*typeImport1*/ as typeImport1 } from "./exports";
        \\import { type foo as /*typeImport2*/ } from "./exports";
        \\import { type foo, type /*typeImport3*/ as typeImport3 } from "./exports";
        \\import * as _a from "./exports";
        \\
        \\export { type /*typeExport0*/ } from "./exports";
        \\export { type /*typeExport1*/ as typeExport1 } from "./exports";
        \\export { type foo as /*typeExport2*/ } from "./exports";
        \\export { type foo, type /*typeExport3*/ } from "./exports";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "valueImport0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\" as __some_type"),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\" as __some_type2"),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\" as __some_value"),
//                 },
//                 "foo",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueImport1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\""),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\""),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\""),
//                 },
//                 "foo",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueImport2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, "valueImport3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\""),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\""),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\""),
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "namespaceImport1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueExport0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\""),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\""),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\""),
//                 },
//                 "foo",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueExport1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\""),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\""),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\""),
//                 },
//                 "foo",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "valueExport2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, "valueExport3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\""),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\""),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\""),
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeImport0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\" as __some_type"),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\" as __some_type2"),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\" as __some_value"),
//                 },
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeImport1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\""),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\""),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\""),
//                 },
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeImport2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, "typeImport3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\""),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\""),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\""),
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeExport0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\""),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\""),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\""),
//                 },
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeExport1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\""),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\""),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\""),
//                 },
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "typeExport2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{},
//         },
//     });
    // f.VerifyCompletions(undefined, "typeExport3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "__some type",
//                     .InsertText = undefined("\"__some type\""),
//                 },
//                 &.{
//                     .Label =      "__some type2",
//                     .InsertText = undefined("\"__some type2\""),
//                 },
//                 &.{
//                     .Label =      "__some value",
//                     .InsertText = undefined("\"__some value\""),
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoOnInternalAliases" {
    const content =
        \\/** Module comment*/
        \\export namespace m1 {
        \\    /** m2 comments*/
        \\    export namespace m2 {
        \\        /** class comment;*/
        \\        export class /*1*/c {
        \\        };
        \\    }
        \\    export function foo() {
        \\    }
        \\}
        \\/**This is on import declaration*/
        \\import /*2*/internalAlias = m1.m2./*3*/c;
        \\var /*4*/newVar = new /*5*/internalAlias();
        \\var /*6*/anotherAliasVar = /*7*/internalAlias;
        \\import /*8*/internalFoo = m1./*9*/foo;
        \\var /*10*/callVar = /*11*/internalFoo();
        \\var /*12*/anotherAliasFoo = /*13*/internalFoo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "class m1.m2.c", "class comment;");
    // f.VerifyQuickInfoAt(undefined, "2", "(alias) class internalAlias\nimport internalAlias = m1.m2.c", "This is on import declaration");
    // f.VerifyQuickInfoAt(undefined, "3", "class m1.m2.c", "class comment;");
    // f.VerifyQuickInfoAt(undefined, "4", "var newVar: internalAlias", "");
    // f.VerifyQuickInfoAt(undefined, "5", "(alias) new internalAlias(): internalAlias\nimport internalAlias = m1.m2.c", "This is on import declaration");
    // f.VerifyQuickInfoAt(undefined, "6", "var anotherAliasVar: typeof internalAlias", "");
    // f.VerifyQuickInfoAt(undefined, "7", "(alias) class internalAlias\nimport internalAlias = m1.m2.c", "This is on import declaration");
    // f.VerifyQuickInfoAt(undefined, "8", "(alias) function internalFoo(): void\nimport internalFoo = m1.foo", "");
    // f.VerifyQuickInfoAt(undefined, "9", "function m1.foo(): void", "");
    // f.VerifyQuickInfoAt(undefined, "10", "var callVar: void", "");
    // f.VerifyQuickInfoAt(undefined, "11", "(alias) internalFoo(): void\nimport internalFoo = m1.foo", "");
    // f.VerifyQuickInfoAt(undefined, "12", "var anotherAliasFoo: () => void", "");
    // f.VerifyQuickInfoAt(undefined, "13", "(alias) function internalFoo(): void\nimport internalFoo = m1.foo", "");
}

