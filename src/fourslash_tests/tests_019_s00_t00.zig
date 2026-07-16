const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListBuilderLocations_parameters" {
    const content =
        \\var aa = 1;
        \\class bar1{ constructor(/*1*/
        \\class bar2{ constructor(a/*2*/
        \\class bar3{ constructor(a, /*3*/
        \\class bar4{ constructor(a, b/*4*/
        \\class bar6{ constructor(public a, /*5*/
        \\class bar7{ constructor(private a, /*6*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, f.Markers(), &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionConstructorParameterKeywords,
//         },
//     });
}

test "TestFindAllRefsPrivateNameProperties" {
    const content =
        \\class C {
        \\    /*1*/#foo = 10;
        \\    constructor() {
        \\        this./*2*/#foo = 20;
        \\        /*3*/#foo in this;
        \\    }
        \\}
        \\class D extends C {
        \\    constructor() {
        \\        super()
        \\        this.#foo = 20;
        \\    }
        \\}
        \\class E {
        \\    /*4*/#foo: number;
        \\    constructor() {
        \\        this./*5*/#foo = 20;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5");
}

test "TestJsdocDeprecated_suggestion14" {
    const content =
        \\// @module: esnext
        \\// @filename: /a.ts
        \\export const a = 1;
        \\export const b = 1;
        \\// @filename: /b.ts
        \\export {
        \\    /** @deprecated a is deprecated */
        \\    a
        \\} from "./a";
        \\// @filename: /c.ts
        \\import { [|a|] } from "./b";
        \\[|a|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/c.ts");
    // try f.VerifySuggestionDiagnostics(undefined, []*.{
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'a' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[0].LSRange,
//         },
//         .{
//             .Code =    &.{.Integer = undefined(int32(6385))},
//             .Message = .{.String = undefined("'a' is deprecated.")},
//             .Tags =    &&.{lsproto.DiagnosticTagDeprecated},
//             .Range =   f.Ranges()[1].LSRange,
//         },
//     });
}

test "TestCodeFixTopLevelAwait_target_noTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: Promise<number>;
        \\await p;
        \\export {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGoToDefinitionExternalModuleName6" {
    const content =
        \\// @Filename: b.ts
        \\import * from [|'e/*1*/'|];
        \\// @Filename: a.ts
        \\declare module /*2*/"e" {
        \\    class Foo { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestSignatureHelpForSignatureWithUnreachableType" {
    const content =
        \\// @Filename: /node_modules/foo/node_modules/bar/index.d.ts
        \\export interface SomeType {
        \\    x?: number;
        \\}
        \\// @Filename: /node_modules/foo/index.d.ts
        \\import { SomeType } from "bar";
        \\export function func<T extends SomeType>(param: T): void;
        \\export function func<T extends SomeType>(param: T, other: T): void;
        \\// @Filename: /usage.ts
        \\import { func } from "foo";
        \\func({/*1*/});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "func(param: {}): void", .OverloadsCount = 2});
}

test "TestCodeFixTopLevelForAwait_module_compatibleCompilerOptionsInTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: number[];
        \\for await (const _ of p);
        \\export {};
        \\// @filename: /dir/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "target": "es2017",
        \\        "module": "esnext"
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixModuleOption");
}

test "TestFormatExportAssignment" {
    const content =
        \\export='foo';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "export = 'foo';");
}

test "TestCompletionListInObjectLiteral7" {
    const content =
        \\type Foo = { foo: boolean };
        \\function f<T>(shape: Foo): any;
        \\function f<T>(shape: () => Foo): any;
        \\function f(arg: any) {
        \\  return arg;
        \\}
        \\
        \\f({ /*1*/ });
        \\f(() => ({ /*2*/ }));
        \\f(() => (({ /*3*/ })));
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2", "3"}, &.{
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
}

test "TestGoToDefinitionDestructuredRequire2" {
    const content =
        \\// @allowJs: true
        \\// @Filename: util.js
        \\class /*2*/Util {}
        \\module.exports = { Util };
        \\// @Filename: reexport.js
        \\const { Util } = require('./util');
        \\module.exports = { Util };
        \\// @Filename: index.js
        \\const { Util } = require('./reexport');
        \\new [|Util/*1*/|]()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

