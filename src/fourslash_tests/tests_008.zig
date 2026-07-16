const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestFindAllReferencesJsRequireDestructuring" {
    const content =
        \\// @allowJs: true
        \\// @noEmit: true
        \\// @checkJs: true
        \\// @Filename: foo.js
        \\module.exports = {
        \\    foo: '1'
        \\};
        \\// @Filename: bar.js
        \\const { /*1*/foo: bar } = require('./foo');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCodeFixAddVoidToPromiseJS5" {
    const content =
        \\// @target: esnext
        \\// @lib: es2015
        \\// @strict: true
        \\// @allowJS: true
        \\// @checkJS: true
        \\// @filename: main.js
        \\/** @type {Promise<number>} */
        \\const p2 = new Promise(resolve => resolve());
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "Add 'void' to Promise resolved without a value");
}

test "TestNavigationBarPrivateNameMethod" {
    const content =
        \\class A {
        \\  #foo() {
        \\    class B {
        \\      #bar() {
        \\         function baz () {
        \\         }
        \\      }
        \\    }
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestGoToImplementationShorthandPropertyAssignment_00" {
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
        \\var x = class /*classExpression*/Foo {
        \\    createBarInClassExpression(): Bar {
        \\        return {
        \\            Fo/*classExpressionRef*/o
        \\        };
        \\    }
        \\
        \\    someFunction() {}
        \\}
        \\
        \\class /*declaredClass*/Foo {
        \\
        \\}
        \\
        \\function createBarUsingClassDeclaration(): Bar {
        \\    return {
        \\        Fo/*declaredClassRef*/o
        \\    };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "classExpressionRef", "declaredClassRef");
}

test "TestCompletionsJsdocParamTypeBeforeName" {
    const content =
        \\// @lib: es5
        \\/** @param /*name1*/ {/*type*/} /*name2*/ */
        \\function toString(obj) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "type", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalTypes,
//         },
//     });
    // f.VerifyCompletions(undefined, "name1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "obj",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "name2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "obj",
//             },
//         },
//     });
}

test "TestGetOccurrencesClassExpressionThis" {
    const content =
        \\var x = class C {
        \\    public x;
        \\    public y;
        \\    public z;
        \\    constructor() {
        \\        [|this|];
        \\        [|this|].x;
        \\        [|this|].y;
        \\        [|this|].z;
        \\    }
        \\    foo() {
        \\        [|this|];
        \\        () => [|this|];
        \\        () => {
        \\            if ([|this|]) {
        \\                [|this|];
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\        return [|this|].x;
        \\    }
        \\
        \\    static bar() {
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCodeFixAddMissingAttributes6" {
    const content =
        \\// @jsx: preserve
        \\// @filename: foo.tsx
        \\interface P {
        \\    a: number;
        \\    b: string;
        \\    c: number[];
        \\    d: any;
        \\}
        \\
        \\const A = ({ a, b, c, d }: P) =>
        \\    <div>{a}{b}{c}{d}</div>;
        \\
        \\const props = { a: 1, b: "", c: [], d: undefined };
        \\const Bar = () =>
        \\    [|<A {...props}></A>|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixMissingAttributes");
}

test "TestTsxCompletion1" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        div: { ONE: string; TWO: number; }
        \\    }
        \\}
        \\var x = <div /**//>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "ONE",
//                 "TWO",
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedFunction18" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: MyType) => y + /*1*/
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
//                 "c",
//                 "v",
//                 "p",
//             },
//         },
//     });
}

test "TestCompletionsNamespaceMergedWithObject" {
    const content =
        \\namespace N {
        \\    export type T = number;
        \\}
        \\const N = { m() {} };
        \\let x: N./*type*/;
        \\N./*value*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "type", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "T",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "value", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "m",
//             },
//         },
//     });
}

test "TestGoToSource16_callbackParamDifferentFile" {
    const content =
        \\// @lib: es5
        \\// @moduleResolution: bundler
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/package.json
        \\{
        \\    "name": "@types/yargs",
        \\    "version": "1.0.0",
        \\    "types": "./index.d.ts"
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/callback.d.ts
        \\export declare class Yargs { positional(): Yargs; }
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/yargs/index.d.ts
        \\import { Yargs } from "./callback";
        \\export declare function command(command: string, cb: (yargs: Yargs) => void): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/package.json
        \\{
        \\    "name": "yargs",
        \\    "version": "1.0.0",
        \\    "main": "index.js"
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/callback.js
        \\export class Yargs { positional() { } }
        \\// @Filename: /home/src/workspaces/project/node_modules/yargs/index.js
        \\import { Yargs } from "./callback";
        \\export function command(cmd, cb) { cb(Yargs) }
        \\// @Filename: /home/src/workspaces/project/index.ts
        \\import { command } from "yargs";
        \\command("foo", yargs => {
        \\    yargs.[|/*start*/positional|]();
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToSourceDefinition(undefined, "start");
}

test "TestSignatureHelpBeforeSemicolon1" {
    const content =
        \\function Foo(arg1: string, arg2: string) {
        \\}
        \\
        \\Foo(/**/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifySignatureHelp(undefined, .{.Text = "Foo(arg1: string, arg2: string): void", .ParameterCount = 2, .ParameterName = "arg1", .ParameterSpan = "arg1: string"});
}

test "TestSignatureHelpConstructorCallParamProperties" {
    const content =
        \\class Circle {
        \\    /**
        \\      * Initialize a circle.
        \\      * @param  radius The radius of the circle.
        \\      */
        \\    constructor(private radius: number) {
        \\    }
        \\}
        \\var a = new Circle(/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestRenameFromNodeModulesDep2" {
    const content =
        \\// @Filename: /node_modules/first/index.d.ts
        \\import { /*okWithAlias*/[|Foo|] } from "foo";
        \\declare type FooBar = Foo[/*notOk*/"bar"];
        \\// @Filename: /node_modules/first/node_modules/foo/package.json
        \\ { "types": "index.d.ts" }
        \\// @Filename: /node_modules/first/node_modules/foo/index.d.ts
        \\export interface Foo {
        \\    /*ok2*/[|bar|]: string;
        \\}
        \\// @Filename: /node_modules/first/node_modules/foo/bar.d.ts
        \\import { Foo } from "./index";
        \\declare type FooBar = Foo[/*ok3*/"[|bar|]"];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "okWithAlias");
    // try f.VerifyRenameSucceeded(undefined, &.{.UseAliasesForRename = core.TSTrue});
    // try f.VerifyRenameFailed(undefined, &.{.UseAliasesForRename = core.TSFalse});
    _ = f.GoToMarker(undefined, "notOk");
    // try f.VerifyRenameFailed(undefined, null );
    _ = f.GoToMarker(undefined, "ok2");
    try f.VerifyRenameSucceeded(undefined, null );
    _ = f.GoToMarker(undefined, "ok3");
    try f.VerifyRenameSucceeded(undefined, null );
}

test "TestEnumUpdate1" {
    const content =
        \\namespace M {
        \\    export enum E {
        \\        A = 1,
        \\        B = 2,
        \\        C = 3,
        \\        /*1*/
        \\    }
        \\}
        \\namespace M {
        \\    function foo(): M.E {
        \\        return M.E.A;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "D = C << 1,");
    try f.VerifyNoErrors(undefined);
}

test "TestCommentsUnion" {
    const content =
        \\var a: Array<string> | Array<number>;
        \\a./*1*/length
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) Array<T>.length: number", "Gets or sets the length of the array. This is a number one higher than the highest index in the array.");
}

test "TestTsxCompletion15" {
    const content =
        \\//@module: commonjs
        \\//@jsx: preserve
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\//@Filename: exporter.tsx
        \\export namespace M {
        \\   export declare function SFCComp(props: { Three: number; Four: string }): JSX.Element;
        \\}
        \\//@Filename: file.tsx
        \\import * as Exp from './exporter';
        \\var x1  = <Exp.M.SFCComp></[|/*1*/|]>;
        \\var x2  = <Exp.M.SFCComp></[|Exp./*2*/|]>;
        \\var x3  = <Exp.M.SFCComp></[|Exp.M./*3*/|]>;
        \\var x4  = <Exp.M.SFCComp></[|Exp.M.SFCComp/*4*/|]
        \\var x5  = <Exp.M.SFCComp></[|Exp.M.SFCComp/*5*/|]>;
        \\var x6  = <Exp.M.SFCComp></      [|Exp./*6*/|]>;
        \\var x7  = <Exp.M.SFCComp></[|/*7*/Exp.M.SFCComp|]>;
        \\var x8  = <Exp.M.SFCComp></[|Exp/*8*/|]>;
        \\var x9  = <Exp.M.SFCComp></[|Exp.M./*9*/|]>;
        \\var x10 = <Exp.M.SFCComp></      [|/*10*/Exp.M.Foo.Bar.Baz.Wut|]>;
        \\var x11 = <Exp.M.SFCComp></[|Exp./*11*/M.SFCComp|]>;
        \\var x12 = <Exp.M.SFCComp><div><span /></div></[|Exp.M./*12*/SFCComp|]>;
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
//             .Exact = &.{
//                 "Exp.M.SFCComp",
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
//             .Exact = &.{
//                 "Exp.M.SFCComp",
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
//             .Exact = &.{
//                 "Exp.M.SFCComp",
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
//             .Exact = &.{
//                 "Exp.M.SFCComp>",
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
//             .Exact = &.{
//                 "Exp.M.SFCComp",
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
//             .Exact = &.{
//                 "Exp.M.SFCComp",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "7", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Exp.M.SFCComp",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "8", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Exp.M.SFCComp",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "9", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Exp.M.SFCComp",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "10", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Exp.M.SFCComp",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "11", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Exp.M.SFCComp",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "12", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "Exp.M.SFCComp",
//             },
//         },
//     });
}

test "TestImportNameCodeFix_require_namedAndDefault" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: blah.ts
        \\export default class Blah {}
        \\export const Named1 = 0;
        \\export const Named2 = 1;
        \\// @Filename: index.js
        \\Named1 + Named2;
        \\new Blah;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "index.js");
    try f.VerifyCodeFixAll(undefined, .{
        .FixID = "fixMissingImport",
        .NewFileContent = "const { default: Blah, Named1, Named2 } = require(\"./blah\");\n\nNamed1 + Named2;\nnew Blah;",
    });
}

test "TestArityErrorAfterSignatureHelp" {
    const content =
        \\// @strict: true
        \\
        \\declare function f(x: string, y: number): any;
        \\
        \\/*1*/f/*2*/(/*3*/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{});
    _ = f.Insert(undefined, "\"");
    _ = f.Insert(undefined, "\"");
    // try f.VerifySignatureHelp(undefined, .{});
    // try f.VerifyCodeFixNotAvailable(undefined);
    try f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
}

test "TestCompletionListInstanceProtectedMembers3" {
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
        \\}
        \\
        \\ var b: Base;
        \\ var c: C1;
        \\ b./*1*/;
        \\ c./*2*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "publicMethod",
//                 "publicProperty",
//             },
//         },
//     });
}

test "TestFindReferencesSeeTagInTs" {
    const content =
        \\function doStuffWithStuff/*1*/(stuff: { quantity: number }) {}
        \\
        \\declare const stuff: { quantity: number };
        \\/** @see {doStuffWithStuff} */
        \\if (stuff.quantity) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCodeFixInferFromExpressionStatement" {
    const content =
        \\// @noImplicitAny: true
        \\function inferVoid( [| app |] ) {
        \\    app.use('hi')
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "app: { use: (arg0: string) => void; }", false, 0, 0);
}

test "TestQuickInfoOnThis2" {
    const content =
        \\class Bar<T> {
        \\    public explicitThis(this: this) {
        \\        console.log(th/*1*/is);
        \\    }
        \\    public explicitClass(this: Bar<T>) {
        \\        console.log(thi/*2*/s);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "this: this", "");
    try f.VerifyQuickInfoAt(undefined, "2", "this: Bar<T>", "");
}

test "TestQuickInfoInheritDoc3" {
    const content =
        \\// @noEmit: true
        \\// @allowJs: true
        \\// @Filename: quickInfoInheritDoc3.ts
        \\function getBaseClass() {
        \\    return class Base {
        \\        /**
        \\         * Base.prop
        \\         */
        \\        prop: string | undefined;
        \\    }
        \\}
        \\class SubClass extends getBaseClass() {
        \\    /**
        \\     * @inheritdoc
        \\     * SubClass.prop
        \\     */
        \\    /*1*/prop: string | undefined;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCompletionsJSDocImportTagAttributesEmptyModuleSpecifier1" {
    const content =
        \\// @strict: true
        \\// @checkJs: true
        \\// @allowJs: true
        \\// @filename: global.d.ts
        \\interface ImportAttributes { 
        \\  type: "json";
        \\}
        \\// @filename: index.js
        \\/** @import * as ns from "" with { type: "/**/" } */
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "json",
//             },
//         },
//     });
}

test "TestDocCommentTemplateFunctionWithParameters" {
    const content =
        \\// @Filename: functionWithParams.ts
        \\/*0*/
        \\    /*1*/
        \\        function foo(x: number, y: string): boolean {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "0");
    // try f.VerifyJSDocCompletion(undefined, "0", 7, "/**\n * \n * @param x\n * @param y\n */", null);
    // try f.VerifyJSDocCompletion(undefined, "1", 0, "/**\n     * \n     * @param x\n     * @param y\n     */", null);
}

test "TestGoToImplementationSuper_00" {
    const content =
        \\class [|Foo|] {
        \\    constructor() {}
        \\}
        \\
        \\class Bar extends Foo {
        \\    constructor() {
        \\        su/*super_call*/per();
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "super_call");
}

test "TestSignatureHelpSkippedArgs1" {
    const content =
        \\function fn(a: number, b: number, c: number) {}
        \\fn(/*1*/, /*2*/, /*3*/, /*4*/, /*5*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestNoQuickInfoInWhitespace" {
    const content =
        \\class C {
        \\/*1*/    private _mspointerupHandler(args) {
        \\        if (args.button === 3) {
        \\            return null; 
        \\/*2*/        } else if (args.button === 4) {
        \\/*3*/            return null;
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyNotQuickInfoExists(undefined);
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyNotQuickInfoExists(undefined);
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyNotQuickInfoExists(undefined);
}

test "TestGenericCallsWithOptionalParams1" {
    const content =
        \\class Collection<T> {
        \\    public add(x: T) { }
        \\}
        \\interface Utils {
        \\    fold<T, S>(c: Collection<T>, folder: (s: S, t: T) => T, init?: S): T;
        \\}
        \\var c = new Collection<string>();
        \\var utils: Utils;
        \\var /*1*/r = utils.fold(c, (s, t) => t, "");
        \\var /*2*/r2 = utils.fold(c, (s, t) => t);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var r: string", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var r2: string", "");
}

test "TestCodeFixMissingTypeAnnotationOnExports12" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function foo() {
        \\    return { x: 1, y: 1 };
        \\}
        \\export const { x, y } = foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract binding expressions to variable",
        .NewFileContent = "function foo() {\n    return { x: 1, y: 1 };\n}\nconst dest = foo();\nexport const x: number = dest.x;\nexport const y: number = dest.y;",
        .Index = 0,
    });
}

test "TestAutoImportProvider_exportMap5" {
    const content =
        \\// @types package lookup
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"]
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "type": "module",
        \\  "dependencies": {
        \\    "dependency": "^1.0.0"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/package.json
        \\{
        \\  "type": "module",
        \\  "name": "dependency",
        \\  "version": "1.0.0",
        \\  "exports": {
        \\    ".": "./lib/index.js",
        \\    "./lol": "./lib/lol.js"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/index.js
        \\export function fooFromIndex() {}
        \\// @Filename: /home/src/workspaces/project/node_modules/dependency/lib/lol.js
        \\export function fooFromLol() {}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/dependency/package.json
        \\{
        \\  "type": "module",
        \\  "name": "@types/dependency",
        \\  "version": "1.0.0",
        \\  "exports": {
        \\    ".": "./lib/index.d.ts",
        \\    "./lol": "./lib/lol.d.ts"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/dependency/lib/index.d.ts
        \\export declare function fooFromIndex(): void;
        \\// @Filename: /home/src/workspaces/project/node_modules/@types/dependency/lib/lol.d.ts
        \\export declare function fooFromLol(): void;
        \\// @Filename: /home/src/workspaces/project/src/foo.ts
        \\fooFrom/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "fooFromIndex",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "dependency",
//                         },
//                     },
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                 },
//                 &.{
//                     .Label = "fooFromLol",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "dependency/lol",
//                         },
//                     },
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                 },
//             },
//         },
//     });
}

test "TestQuickInfoParameter_skipThisParameter" {
    const content =
        \\function f(cb: (x: number) => void) {}
        \\f(function(this: any, /**/x) {});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(parameter) x: number", "");
}

test "TestCompletionTypeAssertion" {
    const content =
        \\// @lib: es5
        \\var x = 'something'
        \\var y = this as/*1*/
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
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     "x",
//                 }, false,
//             ),
//         },
//     });
}

test "TestAmbientShorthandGotoDefinition" {
    const content =
        \\// @Filename: declarations.d.ts
        \\declare module /*module*/"jquery"
        \\// @Filename: user.ts
        \\///<reference path="declarations.d.ts"/>
        \\import [|/*importFoo*/foo|], {bar} from "jquery";
        \\import * as [|/*importBaz*/baz|] from "jquery";
        \\import [|/*importBang*/bang|] = require("jquery");
        \\[|foo/*useFoo*/|]([|bar/*useBar*/|], [|baz/*useBaz*/|], [|bang/*useBang*/|]);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "useFoo", "(alias) module \"jquery\"\nimport foo", "");
    try f.VerifyQuickInfoAt(undefined, "useBar", "(alias) module \"jquery\"\nimport bar", "");
    try f.VerifyQuickInfoAt(undefined, "useBaz", "(alias) module \"jquery\"\nimport baz", "");
    try f.VerifyQuickInfoAt(undefined, "useBang", "(alias) module \"jquery\"\nimport bang = require(\"jquery\")", "");
    // try f.VerifyBaselineGoToDefinition(undefined, true, "useFoo", "importFoo", "useBar", "useBaz", "importBaz", "useBang", "importBang");
}

test "TestFindAllRefsReExportLocal" {
    const content =
        \\// @noLib: true
        \\// @strict: false
        \\// @Filename: /a.ts
        \\[|var /*ax0*/[|{| "isDefinition": true, "contextRangeIndex": 0 |}x|];|]
        \\[|export { /*ax1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}x|] };|]
        \\[|export { /*ax2*/[|{| "contextRangeIndex": 4 |}x|] as /*ay*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 4 |}y|] };|]
        \\// @Filename: /b.ts
        \\[|import { /*bx0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 7 |}x|], /*by0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 7 |}y|] } from "./a";|]
        \\/*bx1*/[|x|]; /*by1*/[|y|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineFindAllReferences(undefined, "ax0", "ax1", "ax2", "bx0", "bx1", "ay", "by0", "by1");
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[5]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[3]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[8], f.Ranges()[10]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[6]);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[9], f.Ranges()[11]);
}

test "TestCompletionsImport_uriStyleNodeCoreModules3" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @Filename: /node_modules/@types/node/index.d.ts
        \\declare module "path" { function join(...segments: readonly string[]): string; }
        \\declare module "node:path" { export * from "path"; }
        \\declare module "fs" { function writeFile(): void }
        \\declare module "fs/promises" { function writeFile(): Promise<void> }
        \\declare module "node:fs" { export * from "fs"; }
        \\declare module "node:fs/promises" { export * from "fs/promises"; }
        \\// @Filename: /other.ts
        \\import "node:fs/promises";
        \\// @Filename: /noPrefix.ts
        \\import "path";
        \\write/*noPrefix*/
        \\// @Filename: /prefix.ts
        \\import "node:path";
        \\write/*prefix*/
        \\// @Filename: /mixed1.ts
        \\import "path";
        \\import "node:path";
        \\write/*mixed1*/
        \\// @Filename: /mixed2.ts
        \\import "node:path";
        \\import "path";
        \\write/*mixed2*/
        \\// @Filename: /test1.ts
        \\import "node:test";
        \\import "path";
        \\writeFile/*test1*/
        \\// @Filename: /test2.ts
        \\import "node:test";
        \\writeFile/*test2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "noPrefix", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "fs",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "fs/promises",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, "prefix", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs/promises",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, "mixed1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs/promises",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, "mixed2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs/promises",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//     });
    // try f.VerifyImportFixModuleSpecifiers(undefined, "test1", &.{"fs", "fs/promises"}, null );
    // try f.VerifyImportFixModuleSpecifiers(undefined, "test2", &.{"node:fs", "node:fs/promises"}, null );
    // f.VerifyCompletions(undefined, "test1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "fs",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "fs/promises",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//     });
    // f.VerifyCompletions(undefined, "test2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "writeFile",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "node:fs/promises",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//     });
}

test "TestCompletionListAtIdentifierDefinitionLocations_enumMembers2" {
    const content =
        \\var aa = 1;
        \\enum a { foo, /*enumValueName3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestLocalGetReferences" {
    const content =
        \\// @Filename: localGetReferences_1.ts
        \\// Comment Refence Test: g/*43*/lobalVar
        \\// References to a variable declared in global.
        \\/*1*/var /*2*/globalVar: number = 2;
        \\
        \\class fooCls {
        \\    // References to static variable declared in a class.
        \\    /*3*/static /*4*/clsSVar = 1;
        \\    // References to a variable declared in a class.
        \\    /*5*/clsVar = 1;
        \\
        \\    constructor (/*6*/public /*7*/clsParam: number) {
        \\        //Increments
        \\        /*8*/globalVar++;
        \\        this./*9*/clsVar++;
        \\        fooCls./*10*/clsSVar++;
        \\        // References to a class parameter.
        \\        this./*11*/clsParam++;
        \\        modTest.modVar++;
        \\    }
        \\}
        \\
        \\// References to a function parameter.
        \\/*12*/function /*13*/foo(/*14*/x: number) {
        \\    // References to a variable declared in a function.
        \\    /*15*/var /*16*/fnVar = 1;
        \\
        \\    //Increments
        \\    fooCls./*17*/clsSVar++;
        \\    /*18*/globalVar++;
        \\    modTest.modVar++;
        \\    /*19*/fnVar++;
        \\
        \\    //Return
        \\    return /*20*/x++;
        \\}
        \\
        \\namespace modTest {
        \\    //Declare
        \\    export var modVar:number;
        \\
        \\    //Increments
        \\    /*21*/globalVar++;
        \\    fooCls./*22*/clsSVar++;
        \\    modVar++;
        \\
        \\    class testCls {
        \\        static boo = /*23*/foo;
        \\    }
        \\
        \\    function testFn(){
        \\        static boo = /*24*/foo;
        \\
        \\        //Increments
        \\        /*25*/globalVar++;
        \\        fooCls./*26*/clsSVar++;
        \\        modVar++;
        \\    }
        \\
        \\    namespace testMod {
        \\        var boo = /*27*/foo;
        \\    }
        \\}
        \\
        \\//Type test
        \\var clsTest: fooCls;
        \\
        \\//Arguments
        \\// References to a class argument.
        \\clsTest = new fooCls(/*28*/globalVar);
        \\// References to a function argument.
        \\/*29*/foo(/*30*/globalVar);
        \\
        \\//Increments
        \\fooCls./*31*/clsSVar++;
        \\modTest.modVar++;
        \\/*32*/globalVar = /*33*/globalVar + /*34*/globalVar;
        \\
        \\//ETC - Other cases
        \\/*35*/globalVar = 3;
        \\// References to illegal assignment.
        \\/*36*/foo = /*37*/foo + 1;
        \\/*44*/err = err++;
        \\/*45*/
        \\//Shadowed fn Parameter
        \\function shdw(/*38*/globalVar: number) {
        \\    //Increments
        \\    /*39*/globalVar++;
        \\    return /*40*/globalVar;
        \\}
        \\
        \\//Remotes
        \\//Type test
        \\var remoteclsTest: remotefooCls;
        \\
        \\//Arguments
        \\remoteclsTest = new remotefooCls(remoteglobalVar);
        \\remotefoo(remoteglobalVar);
        \\
        \\//Increments
        \\remotefooCls.remoteclsSVar++;
        \\remotemodTest.remotemodVar++;
        \\remoteglobalVar = remoteglobalVar + remoteglobalVar;
        \\
        \\//ETC - Other cases
        \\remoteglobalVar = 3;
        \\
        \\//Find References misses method param
        \\var
        \\
        \\
        \\
        \\ array = ["f", "o", "o"];
        \\
        \\array.forEach(
        \\
        \\
        \\function(/*41*/str) {
        \\
        \\
        \\
        \\   // Reference misses function parameter.
        \\   return /*42*/str + " ";
        \\
        \\});
        \\// @Filename: localGetReferences_2.ts
        \\var remoteglobalVar: number = 2;
        \\
        \\class remotefooCls {
        \\    //Declare
        \\    remoteclsVar = 1;
        \\    static remoteclsSVar = 1;
        \\
        \\    constructor(public remoteclsParam: number) {
        \\        //Increments
        \\        remoteglobalVar++;
        \\        this.remoteclsVar++;
        \\        remotefooCls.remoteclsSVar++;
        \\        this.remoteclsParam++;
        \\        remotemodTest.remotemodVar++;
        \\    }
        \\}
        \\
        \\function remotefoo(remotex: number) {
        \\    //Declare
        \\    var remotefnVar = 1;
        \\
        \\    //Increments
        \\    remotefooCls.remoteclsSVar++;
        \\    remoteglobalVar++;
        \\    remotemodTest.remotemodVar++;
        \\    remotefnVar++;
        \\
        \\    //Return
        \\    return remotex++;
        \\}
        \\
        \\namespace remotemodTest {
        \\    //Declare
        \\    export var remotemodVar: number;
        \\
        \\    //Increments
        \\    remoteglobalVar++;
        \\    remotefooCls.remoteclsSVar++;
        \\    remotemodVar++;
        \\
        \\    class remotetestCls {
        \\        static remoteboo = remotefoo;
        \\    }
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45");
}

test "TestCodeFixRemoveUnnecessaryAwait_mixedUnion" {
    const content =
        \\// @target: esnext
        \\async function fn1(a: Promise<void> | void) {
        \\  await a;
        \\}
        \\
        \\async function fn2<T extends Promise<void> | void>(a: T) {
        \\  await a;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestMemberListInWithBlock2" {
    const content =
        \\interface IFoo {
        \\    a: number;
        \\}
        \\
        \\with (x) {
        \\    var y: IFoo = { /*1*/ };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "1", null);
}

test "TestGoToImplementationInterfaceMethod_10" {
    const content =
        \\interface BaseFoo {
        \\     hello(): void;
        \\}
        \\
        \\interface Foo extends BaseFoo {
        \\     aloha(): void;
        \\}
        \\
        \\interface Bar {
        \\      hello(): void;
        \\      goodbye(): void;
        \\}
        \\
        \\class FooImpl implements Foo {
        \\      [|hello|]() {/**FooImpl*/}
        \\      aloha() {}
        \\}
        \\
        \\class BaseFooImpl implements BaseFoo {
        \\      hello() {/**BaseFooImpl*/}    // Should not show up
        \\}
        \\
        \\class BarImpl implements Bar {
        \\     [|hello|]() {/**BarImpl*/}
        \\     goodbye() {}
        \\}
        \\
        \\class FooAndBarImpl implements Foo, Bar {
        \\     [|hello|]() {/**FooAndBarImpl*/}
        \\     aloha() {}
        \\     goodbye() {}
        \\}
        \\
        \\function someFunction(x: Foo | Bar) {
        \\     x.he/*function_call0*/llo();
        \\}
        \\
        \\function anotherFunction(x: Foo & Bar) {
        \\     x.he/*function_call1*/llo();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call0", "function_call1");
}

test "TestCompletionForComputedStringProperties" {
    const content =
        \\const p2 = "p2";
        \\interface A {
        \\    ["p1"]: string;
        \\    [p2]: string;
        \\}
        \\declare const a: A;
        \\a[|./**/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "p1",
//                 },
//                 &.{
//                     .Label =      "p2",
//                     .InsertText = undefined("[p2]"),
//                     .SortText =   undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "p2",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestFormattingForOfKeyword" {
    const content =
        \\/**/for ([]of[]) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "for ([] of []) { }");
}

test "TestJsdocTypedefTag2" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsdocCompletion_typedef.js
        \\/**
        \\ * @typedef {Object} A.B.MyType
        \\ * @property {string} yes
        \\ */
        \\function foo() {}
        \\/**
        \\ * @param {A.B.MyType} my2
        \\ */
        \\function a(my2) {
        \\    my2.yes./*1*/
        \\}
        \\/**
        \\ * @param {MyType} my2
        \\ */
        \\function b(my2) {
        \\    my2.yes./*2*/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "charAt",
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
//             .Excludes = &.{
//                 "charAt",
//             },
//         },
//     });
}

test "TestCompletionListInUnclosedFunction17" {
    const content =
        \\interface MyType {
        \\}
        \\
        \\function foo(x: string, y: number, z: boolean) {
        \\    function bar(a: number, b: string = "hello", c: typeof x = "hello") {
        \\        var v = (p: MyType) => y + /*1*/
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
//                 "c",
//                 "v",
//                 "p",
//             },
//         },
//     });
}

test "TestSignatureHelpJSMissingPropertyAccess" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: test.js
        \\foo.filter(/**/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestMissingMethodAfterEditAfterImport" {
    const content =
        \\namespace foo {
        \\    export namespace bar { namespace baz { export class boo { } } }
        \\}
        \\
        \\import f = /*foo*/foo;
        \\
        \\/*delete*/var x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "foo", "namespace foo", "");
    _ = f.GoToMarker(undefined, "delete");
    _ = f.DeleteAtCaret(undefined, 6);
    try f.VerifyQuickInfoAt(undefined, "foo", "namespace foo", "");
}

test "TestQuickInfoOnMergedModule" {
    const content =
        \\// @strict: false
        \\namespace M2 {
        \\    export interface A {
        \\        foo: string;
        \\    }
        \\    var a: A;
        \\    var r = a.foo + a.bar;
        \\}
        \\namespace M2 {
        \\    export interface A {
        \\        bar: number;
        \\    }
        \\    var a: A;
        \\    var r = a.fo/*1*/o + a.bar;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) M2.A.foo: string", "");
    try f.VerifyNoErrors(undefined);
}

test "TestCallHierarchyExportDefaultClass" {
    const content =
        \\// @filename: main.ts
        \\import Bar from "./other";
        \\
        \\function foo() {
        \\    new Bar();
        \\}
        \\// @filename: other.ts
        \\export /**/default class {
        \\    constructor() {
        \\        baz();
        \\    }
        \\}
        \\
        \\function baz() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestJsxElementExtendsNoCrash3" {
    const content =
        \\// @filename: index.tsx
        \\<T extends /=>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifySuggestionDiagnostics(undefined, null);
}

test "TestGetJavaScriptSyntacticDiagnostics4" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\public class C { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestGlobalThisCompletion" {
    const content =
        \\// @allowJs: true
        \\// @target: esnext
        \\// @Filename: test.js
        \\(typeof foo !== "undefined"
        \\  ? foo
        \\  : {}
        \\)./**/;
        \\// @Filename: someLib.d.ts
        \\declare var foo: typeof globalThis;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{},
//     });
}

test "TestCodeFixClassImplementDeepInheritance" {
    const content =
        \\// @stableTypeOrdering: true
        \\// @strict: false
        \\// Referenced throughout the inheritance chain.
        \\interface I0 { a: number }
        \\
        \\class C1 implements I0 { a: number }
        \\interface I1 { b: number }
        \\interface I2 extends C1, I1 {}
        \\
        \\class C2 { c: number }
        \\interface I3 {d: number}
        \\class C3 extends C2 implements I0, I2, I3 {
        \\    a: number;
        \\    b: number;
        \\    d: number;
        \\}
        \\
        \\interface I4 { e: number }
        \\interface I5 { f: number }
        \\class C4 extends C3 implements I0, I4, I5 {
        \\    e: number;
        \\    f: number;
        \\}
        \\
        \\interface I6 extends C4 {}
        \\class C5 implements I6 {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I6'",
        .NewFileContent = "// Referenced throughout the inheritance chain.\ninterface I0 { a: number }\n\nclass C1 implements I0 { a: number }\ninterface I1 { b: number }\ninterface I2 extends C1, I1 {}\n\nclass C2 { c: number }\ninterface I3 {d: number}\nclass C3 extends C2 implements I0, I2, I3 {\n    a: number;\n    b: number;\n    d: number;\n}\n\ninterface I4 { e: number }\ninterface I5 { f: number }\nclass C4 extends C3 implements I0, I4, I5 {\n    e: number;\n    f: number;\n}\n\ninterface I6 extends C4 {}\nclass C5 implements I6 {\n    c: number;\n    a: number;\n    b: number;\n    d: number;\n    e: number;\n    f: number;\n}",
        .Index = 0,
    });
}

test "TestDocumentHighlightInExport1" {
    const content =
        \\class [|C|] {}
        \\[|export|] { [|C|] [|as|] [|D|] };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestImportNameCodeFixNewImportPaths_withParentRelativePath" {
    const content =
        \\// @Filename: /src/a.ts
        \\[|foo|]
        \\// @Filename: /thisHasPathMapping.ts
        \\export function foo() {};
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": "src",
        \\        "paths": {
        \\            "foo": ["..\\thisHasPathMapping"]
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"foo\";\n\nfoo",
    }, null );
}

test "TestQuickInfoOnValueSymbolWithoutExportWithSameNameExportSymbol" {
    const content =
        \\// @strict: true
        \\
        \\declare function num(): number
        \\const /*1*/Unit = num()
        \\export type Unit = number
        \\const value = /*2*/Unit
        \\
        \\function Fn() {}
        \\export type Fn = () => void
        \\/*3*/Fn()
        \\
        \\// repro from #41897
        \\const /*4*/X = 1;
        \\export interface X {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "const Unit: number", "");
    try f.VerifyQuickInfoAt(undefined, "2", "const Unit: number", "");
    try f.VerifyQuickInfoAt(undefined, "3", "function Fn(): void", "");
    try f.VerifyQuickInfoAt(undefined, "4", "const X: 1", "");
}

test "TestAddDuplicateSetter" {
    const content =
        \\class C {
        \\    set foo(value) { }
        \\    /**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "set foo(value) { }");
}

test "TestQuickInfoJsDocTags14" {
    const content =
        \\/**
        \\ * @param {Object} options the args object
        \\ * @param {number} options.a first number
        \\ * @param {number} options.b second number
        \\ * @param {Object} options.c sub-object
        \\ * @param {number} options.c.d third number
        \\ * @param {Function} callback the callback function
        \\ * @returns {number}
        \\ */
        \\function /**/fn(options, callback = null) { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestUnderscoreTypings02" {
    const content =
        \\// @strict: false
        \\// @module: CommonJS
        \\interface Dictionary<T> {
        \\    [x: string]: T;
        \\}
        \\export interface ChainedObject<T> {
        \\    functions: ChainedArray<string>;
        \\    omit(): ChainedObject<T>;
        \\    clone(): ChainedObject<T>;
        \\}
        \\interface ChainedDictionary<T> extends ChainedObject<Dictionary<>> {
        \\    foldl(): ChainedObject<T>;
        \\    clone(): ChainedDictionary<T>;
        \\}
        \\export interface ChainedArray<T> extends ChainedObject<Array<T>> {
        \\    groupBy(): ChainedDictionary<any[]>;
        \\    groupBy(propertyName): ChainedDictionary<any[]>;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToPosition(undefined, 0);
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 2);
}

test "TestQuickInfoJsDocTags1" {
    const content =
        \\// @Filename: quickInfoJsDocTags1.ts
        \\/**
        \\ * Doc
        \\ * @author Me <me@domain.tld>
        \\ * @augments {C<T>} Augments it
        \\ * @template T A template
        \\ * @type {number | string} A type
        \\ * @typedef {number | string} NumOrStr
        \\ * @property {number} x The prop
        \\ * @param {number} x The param
        \\ * @returns The result
        \\ * @see x (the parameter)
        \\ */
        \\function /**/foo(x) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestFormatSelectionWithTrivia4" {
    const content =
        \\if (true) {
        \\/*begin*/// test comment
        \\/*end*/console.log();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "begin", "end");
    try f.VerifyCurrentFileContent(undefined, "if (true) {\n    // test comment\nconsole.log();\n}");
}

test "TestCompletionForStringLiteral" {
    const content =
        \\type Options = "Option 1" | "Option 2" | "Option 3";
        \\var x: Options = "[|/*1*/Option 3|]";
        \\
        \\function f(a: Options) { };
        \\f("/*2*/
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
//             .Exact = &.{
//                 &.{
//                     .Label = "Option 1",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "Option 1",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "Option 2",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "Option 2",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "Option 3",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "Option 3",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
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
//             .Exact = &.{
//                 &.{
//                     .Label = "Option 1",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "Option 1",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "Option 2",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "Option 2",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "Option 3",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "Option 3",
//                             .Range =   f.Ranges()[1].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestGetRenameInfoTests1" {
    const content =
        \\class [|/**/C|] {
        \\
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyRenameSucceeded(undefined, null );
}

test "TestQuickInfoForJSDocWithHttpLinks" {
    const content =
        \\// @checkJs: true
        \\// @filename: quickInfoForJSDocWithHttpLinks.js
        \\/** @typedef {number} /*1*/https://wat */
        \\
        \\/**
        \\* @typedef {Object} Oops
        \\* @property {number} /*2*/https://wass
        \\*/
        \\
        \\
        \\/** @callback /*3*/http://vad */
        \\
        \\/** @see https://hvad */
        \\var /*4*/see1 = true
        \\
        \\/** @see {@link https://hva} */
        \\var /*5*/see2 = true
        \\
        \\/** {@link https://hvaD} */
        \\var /*6*/see3 = true
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestInsertArgumentBeforeOverloadedConstructor" {
    const content =
        \\alert(/**/100);
        \\
        \\class OverloadedMonster {
        \\    constructor();
        \\    constructor(name) { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "'1', ");
}

test "TestAsOperatorFormatting" {
    const content =
        \\/**/var x = 3   as  number;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "var x = 3 as number;");
}

test "TestGetJavaScriptCompletions15" {
    const content =
        \\// @allowNonTsExtensions: true
        \\// @Filename: refFile1.ts
        \\export var V = 1;
        \\// @Filename: refFile2.ts
        \\export var V = "123"
        \\// @Filename: refFile3.ts
        \\export var V = "123"
        \\// @Filename: main.js
        \\import ref1 = require("./refFile1");
        \\var ref2 = require("./refFile2");
        \\ref1.V./*1*/;
        \\ref2.V./*2*/;
        \\var v = { x: require("./refFile3") };
        \\v.x./*3*/;
        \\v.x.V./*4*/;
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
//                 "toExponential",
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
//                 "toLowerCase",
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
//             .Exact = &.{
//                 "V",
//                 &.{
//                     .Label =    "ref1",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "ref2",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "require",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "v",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
//                 &.{
//                     .Label =    "x",
//                     .SortText = undefined(string(ls.SortTextJavascriptIdentifiers)),
//                 },
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
//                 "toLowerCase",
//             },
//         },
//     });
}

test "TestSignatureHelpNegativeTests2" {
    const content =
        \\class clsOverload { constructor(); constructor(test: string); constructor(test?: string) { } }
        \\var x = new clsOverload/*beforeOpenParen*/()/*afterCloseParen*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyNoSignatureHelpForMarkers(undefined, "beforeOpenParen", "afterCloseParen");
}

test "TestDocCommentTemplateVariableStatements01" {
    const content =
        \\/*a*/
        \\var a = 10;
        \\
        \\/*b*/
        \\let b = "";
        \\
        \\/*c*/
        \\const c = 30;
        \\
        \\/*d*/
        \\let d = {
        \\    foo: 10,
        \\    bar: "20"
        \\};
        \\
        \\/*e*/
        \\let e = function e(x, y, z) {
        \\    return +(x + y + z);
        \\};
        \\
        \\/*f*/
        \\let f = class F {
        \\    constructor(a, b, c) {
        \\        this.a = a;
        \\        this.b = b || (this.c = c);
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, varName, 3, "/** */", null);
    // try f.VerifyJSDocCompletion(undefined, "e", 7, "/**\n * \n * @param x\n * @param y\n * @param z\n * @returns\n */", null);
    // try f.VerifyJSDocCompletion(undefined, "f", 7, "/**\n * \n * @param a\n * @param b\n * @param c\n */", null);
}

test "TestCompletionListFunctionExpression" {
    const content =
        \\// @lib: es5
        \\class DataHandler {
        \\    dataArray: Uint8Array;
        \\    loadData(filename) {
        \\        var xmlReq = new XMLHttpRequest();
        \\        xmlReq.open("GET", "/" + filename, true);
        \\        xmlReq.responseType = "arraybuffer";
        \\        xmlReq.onload = function(xmlEvent) {
        \\            /*local*/
        \\            this./*this*/;
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "local");
    _ = f.InsertLine(undefined, "");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "xmlEvent",
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "this", null);
}

test "TestAutoImportProvider_importsMap5" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"],
        \\    "rootDir": "src",
        \\    "outDir": "dist",
        \\    "declarationDir": "types",
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "type": "module",
        \\  "imports": {
        \\    "#is-browser": {
        \\      "types": "./types/env/browser.d.ts",
        \\      "default": "./not-dist-on-purpose/env/browser.js"
        \\    }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/src/env/browser.ts
        \\export const isBrowser = true;
        \\// @Filename: /home/src/workspaces/project/src/a.ts
        \\isBrowser/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#is-browser"}, null );
}

test "TestFormat01" {
    const content =
        \\// @lib: es5
        \\/**/namespace Default{var x= ( { } ) ;}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "namespace Default { var x = ({}); }");
}

test "TestCodeFixAddMissingMember8" {
    const content =
        \\// @Filename: a.ts
        \\declare var x: [1, 2];
        \\x.b;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestQuickinfoVerbosityConditionalType" {
    const content =
        \\interface Apple {
        \\    color: string;
        \\    weight: number;
        \\}
        \\type StrInt = string | bigint;
        \\type T1<T extends Apple | Apple[]> = T extends { color: string } ? "one apple" : StrInt;
        \\function f<T extends Apple | Apple[]>(x: T1<T>): void {
        \\    x/*x*/;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"x" = .{0, 1, 2}});
}

test "TestCompletionListCladule" {
    const content =
        \\class Foo {
        \\    doStuff(): number { return 0; }
        \\    static staticMethod() {}
        \\}
        \\namespace Foo {
        \\    export var x: number;
        \\}
        \\Foo/*c1*/; // should get "x", "prototype"
        \\var s: Foo/*c2*/; // no types, in Foo, so shouldnt have anything
        \\var f = new Foo();
        \\f/*c3*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "c1");
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "x",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "prototype",
//                     .SortText = undefined(string(ls.SortTextLocationPriority)),
//                 },
//                 &.{
//                     .Label =    "staticMethod",
//                     .SortText = undefined(string(ls.SortTextLocalDeclarationPriority)),
//                 },
//             },
//         },
//     });
    _ = f.GoToMarker(undefined, "c2");
    _ = f.Insert(undefined, ".");
    _ = f.VerifyCompletions(undefined, null, null);
    _ = f.GoToMarker(undefined, "c3");
    _ = f.Insert(undefined, ".");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "doStuff",
//             },
//         },
//     });
}

test "TestFormatImplicitModule" {
    const content =
        \\       export class A {
        \\
        \\       }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToBOF(undefined);
    try f.VerifyCurrentLineContent(undefined, "export class A {");
    _ = f.GoToEOF(undefined);
    try f.VerifyCurrentLineContent(undefined, "}");
}

test "TestCompletionListPrivateNames" {
    const content =
        \\class Foo {
        \\    #x;
        \\    y;
        \\}
        \\
        \\class Bar extends Foo {
        \\    #z;
        \\    t;
        \\    constructor() {
        \\        this./*1*/
        \\        class Baz {
        \\            #z;
        \\            #u;
        \\            v;
        \\            constructor() {
        \\                this./*2*/
        \\                new Bar()./*3*/
        \\            }
        \\        }
        \\    }
        \\}
        \\
        \\new Foo()./*4*/
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
//             .Unsorted = &.{
//                 "#z",
//                 "t",
//                 "y",
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
//                 "#z",
//                 "#u",
//                 "v",
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
//                 "#z",
//                 "t",
//                 "y",
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
//             .Exact = &.{
//                 "y",
//             },
//         },
//     });
}

test "TestInlayHintsInteractiveFunctionParameterTypes1" {
    const content =
        \\ type F1 = (a: string, b: number) => void
        \\ const f1: F1 = (a, b) => { }
        \\ const f2: F1 = (a, b: number) => { }
        \\ function foo1 (cb: (a: string) => void) {}
        \\ foo1((a) => { })
        \\ function foo2 (cb: (a: Exclude<1 | 2 | 3, 1>) => void) {}
        \\ foo2((a) => { })
        \\ function foo3 (a: (b: (c: (d: Exclude<1 | 2 | 3, 1>) => void) => void) => void) {}
        \\ foo3(a => {
        \\     a(d => {})
        \\ })
        \\ function foo4<T>(v: T, a: (v: T) => void) {}
        \\ foo4(1, a => { })
        \\ type F2 = (a: {
        \\     a: number
        \\     b: string
        \\     readonly c: boolean
        \\     d?: number
        \\     e(): string
        \\     f?(): boolean
        \\     g<T>(): T
        \\     h?<X, Y>(x: X): Y
        \\     <X, Y>(x: X): Y
        \\     [i: string]: number
        \\ }) => void
        \\ const foo5: F2 = (a) => { }
        \\ type F3 = (a: {
        \\     (): 42
        \\ }) => void
        \\ const foo6: F3 = (a) => { }
        \\interface Thing {}
        \\function foo4(callback: (thing: Thing) => void) {}
        \\foo4(p => {})
        \\ type F4 = (a: {
        \\     [i in string]: number
        \\ }) => void
        \\ const foo5: F4 = (a) => { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionParameterTypeHints = core.TSTrue}});
}

test "TestImportNameCodeFixNewImportBaseUrl2" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": "./a"
        \\    }
        \\}
        \\// @Filename: /a/b/x.ts
        \\export function f1() { };
        \\// @Filename: /a/c/y.ts
        \\[|f1/*0*/();|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a/c/y.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"b/x\";\n\nf1();",
    }, null );
    // try f.VerifyImportFixAtPosition(undefined, &.{
//         "import { f1 } from \"../b/x\";\n\nf1();",
//     }, &.{.ImportModuleSpecifierPreference = "relative"});
}

test "TestQuickInfoDisplayPartsUsing" {
    const content =
        \\// @lib: esnext
        \\using a/*a*/ = "a";
        \\const f = async () => {
        \\    await using /*b*/b = { async [Symbol.asyncDispose]() {} };
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestFindAllRefsNoSubstitutionTemplateLiteralNoCrash1" {
    const content =
        \\type Test = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestSignatureHelpTypeArguments2" {
    const content =
        \\/** some documentation
        \\ * @template T some documentation 2
        \\ * @template W
        \\ * @template U,V others
        \\ * @param a ok
        \\ * @param b not ok
        \\ */
        \\function f<T, U, V, W>(a: number, b: string, c: boolean): void { }
        \\f</*f0*/;
        \\f<number, /*f1*/;
        \\f<number, string, /*f2*/;
        \\f<number, string, boolean, /*f3*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestCompletionListOfSplitInterface" {
    const content =
        \\interface A {
        \\    a: number;
        \\}
        \\interface I extends A {
        \\    i1: number;
        \\}
        \\interface I1 extends A {
        \\    i11: number;
        \\}
        \\interface B {
        \\    b: number;
        \\}
        \\interface B1 {
        \\    b1: number;
        \\}
        \\interface I extends B {
        \\    i2: number;
        \\}
        \\interface I1 extends B, B1 {
        \\    i12: number;
        \\}
        \\interface C {
        \\    c: number;
        \\}
        \\interface I extends C {
        \\    i3: number;
        \\}
        \\var ci: I;
        \\ci./*1*/b;
        \\var ci1: I1;
        \\ci1./*2*/b;
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
//             .Unsorted = &.{
//                 "i1",
//                 "i2",
//                 "i3",
//                 "a",
//                 "b",
//                 "c",
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
//                 "i11",
//                 "i12",
//                 "a",
//                 "b",
//                 "b1",
//             },
//         },
//     });
}

test "TestFindAllRefsTypedef" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/**
        \\ * @typedef I {Object}
        \\ * /*1*/@prop /*2*/p {number}
        \\ */
        \\
        \\/** @type {I} */
        \\let x;
        \\x./*3*/p;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestSwitchCompletions" {
    const content =
        \\enum E { A, B }
        \\declare const e: E;
        \\switch (e) {
        \\    case E.A:
        \\        return 0;
        \\    case E./*1*/
        \\}
        \\declare const f: 1 | 2 | 3;
        \\switch (f) {
        \\    case 1:
        \\        return 1;
        \\    case /*2*/
        \\}
        \\declare const f2: 'foo' | 'bar' | 'baz';
        \\switch (f2) {
        \\    case 'bar':
        \\        return 1;
        \\    case '/*3*/'
        \\}
        \\
        \\// repro from #52874
        \\declare let x: "foo" | "bar";
        \\switch (x) {
        \\    case ('/*4*/')
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
//                 "B",
//             },
//             .Excludes = &.{
//                 "A",
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
//                 "2",
//                 "3",
//             },
//             .Excludes = &.{
//                 "1",
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
//                 "foo",
//                 "baz",
//             },
//             .Excludes = &.{
//                 "bar",
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
//                 "foo",
//                 "bar",
//             },
//         },
//     });
}

test "TestCodeFixGenerateDefinitions" {
    const content =
        \\// @Filename: /node_modules/foo/index.d.ts
        \\module.exports = 0;
        \\// @Filename: /a.ts
        \\import * as foo from "foo";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestFindAllRefsWithLeadingUnderscoreNames5" {
    const content =
        \\class Foo {
        \\    public _bar;
        \\    public __bar;
        \\    /*1*/public /*2*/___bar;
        \\    public ____bar;
        \\}
        \\
        \\var x: Foo;
        \\x._bar;
        \\x.__bar;
        \\x./*3*/___bar;
        \\x.____bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestReferencesToStringLiteralValue" {
    const content =
        \\// @lib: es5
        \\const s: string = "some /*1*/ string";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFindAllRefsDestructureGeneric" {
    const content =
        \\interface I<T> {
        \\    /*0*/x: boolean;
        \\}
        \\declare const i: I<number>;
        \\const { /*1*/x } = i;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1");
}

test "TestCodeFixTopLevelAwait_module_targetES2017CompilerOptionsInTsConfig" {
    const content =
        \\// @filename: /dir/a.ts
        \\declare const p: Promise<number>;
        \\await p;
        \\export {};
        \\// @filename: /dir/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "target": "es2017"
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined, "fixTargetOption");
    try f.VerifyCodeFixAvailable(undefined, null);
}

test "TestAugmentedTypesModule1" {
    const content =
        \\namespace m1c {
        \\    export interface I { foo(): void; }
        \\}
        \\var m1c = 1; // Should be allowed
        \\var x: m1c./*1*/;
        \\var /*2*/r = m1c;
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
//             .Exact = &.{
//                 "I",
//             },
//         },
//     });
    try f.VerifyQuickInfoAt(undefined, "2", "var r: number", "");
}

test "TestFormatSpaceBetweenFunctionAndArrayIndex" {
    const content =
        \\// @lib: es5
        \\
        \\function test() {
        \\    return [];
        \\}
        \\
        \\test() [0]
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "\nfunction test() {\n    return [];\n}\n\ntest()[0]\n");
}

test "TestGoToDefinitionOverriddenMember3" {
    const content =
        \\// @noImplicitOverride: true
        \\abstract class Foo {
        \\    abstract /*2*/m() {}
        \\}
        \\
        \\export class Bar extends Foo {
        \\    [|/*1*/override|] m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCodeFixMissingTypeAnnotationOnExports59_drops_unneeded_after_unknown" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\
        \\export interface Foo<S = string, T = unknown, U = number> {}
        \\export function g(x: Foo<number, unknown, number>) { return x; }
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'Foo<number>'",
        .NewFileContent = "\nexport interface Foo<S = string, T = unknown, U = number> {}\nexport function g(x: Foo<number, unknown, number>): Foo<number> { return x; }\n",
        .Index = 0,
    });
}

test "TestFormattingInComment" {
    const content =
        \\class A {
        \\foo(              ); // /*1*/
        \\}
        \\function foo() {       var x;       } // /*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, ";");
    try f.VerifyCurrentLineContent(undefined, "foo(              ); // ;");
    _ = f.GoToMarker(undefined, "2");
    _ = f.Insert(undefined, "}");
    try f.VerifyCurrentLineContent(undefined, "function foo() {       var x;       } // }");
}

test "TestRenamePrivateAccessor" {
    const content =
        \\class Foo {
        \\   [|get [|{| "contextRangeIndex": 0 |}#foo|]() { return 1 }|]
        \\   [|set [|{| "contextRangeIndex": 2 |}#foo|](value: number) { }|]
        \\   retFoo() {
        \\       return this.[|#foo|];
        \\   }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , ToAny(f.GetRangesByText().Get("#foo")));
}

test "TestCodeFixClassImplementInterfaceTypeParamInstantiateU" {
    const content =
        \\interface I<T> { x: T; }
        \\class C<U> implements I<U> {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I<U>'",
        .NewFileContent = "interface I<T> { x: T; }\nclass C<U> implements I<U> {\n    x: U;\n}",
        .Index = 0,
    });
}

test "TestQuickInfoBindingPatternInJsdocNoCrash1" {
    const content =
        \\/** @type {({ /*1*/data: any }?) => { data: string[] }} */
        \\function useQuery({ data }): { data: string[] } {
        \\  return {
        \\    data,
        \\  };
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "", "");
}

test "TestFormatRangeEndingAfterCommaOfCall" {
    const content =
        \\someCall(
        \\    /*start*/"firstParameter",/*end*/
        \\    "something else"
        \\);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "start", "end");
}

test "TestGoToImplementationLocal_04" {
    const content =
        \\function [|he/*local_var*/llo|]() {}
        \\
        \\hello();
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "local_var");
}

test "TestRenameJsDocImportTag" {
    const content =
        \\// @allowJS: true
        \\// @checkJs: true
        \\// @Filename: /b.ts
        \\export interface A { }
        \\// @Filename: /a.js
        \\/**
        \\ * @import { A } from "./b";
        \\ */
        \\
        \\/**
        \\ * @param { [|A/**/|] } a
        \\ */
        \\function f(a) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRename(undefined, null , "");
}

test "TestImportNameCodeFixNewImportFile0" {
    const content =
        \\[|f1/*0*/();|]
        \\// @Filename: jalapeño.ts
        \\export function f1() {}
        \\export var v1 = 5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"./jalapeño\";\n\nf1();",
    }, null );
}

test "TestFormatNoSpaceBeforeCloseBrace5" {
    const content =
        \\new Foo(1, 
        \\    /* comment */    );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "new Foo(1,\n    /* comment */);");
}

test "TestCompletionListInTypeLiteralInTypeParameter18" {
    const content =
        \\class Foo<T extends { x: 'one' | 'two' }> {}
        \\function foo<T extends { x: 'one' | 'two' }>() {}
        \\declare function tag<T extends { x: 'one' | 'two' }>(x: TemplateStringsArray): void;
        \\declare function decorator<T extends { x: 'one' | 'two' }>(...args: unknown[]): never
        \\
        \\type A = Foo<{ x: '/*0*/' }>;
        \\new Foo<{ x: '/*1*/' }>();
        \\foo<{ x: '/*2*/' }>();
        \\foo<{ x: '/*3*/' }>;
        \\Foo<{ x: '/*4*/' }>;
        \\tag<{ x: '/*5*/' }>
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

test "TestRewriteRelativeImportExtensionsProjectReferences2" {
    const content =
        \\// @Filename: src/tsconfig-base.json
        \\{
        \\    "compilerOptions": {
        \\        "lib": ["es5"],
        \\        "module": "nodenext",
        \\        "composite": true,
        \\        "rootDir": ".",
        \\        "outDir": "../dist",
        \\        "rewriteRelativeImportExtensions": true,
        \\    }
        \\}
        \\// @Filename: src/compiler/tsconfig.json
        \\{
        \\    "extends": "../tsconfig-base.json",
        \\    "compilerOptions": { "lib": ["es5"] }
        \\}
        \\// @Filename: src/compiler/parser.ts
        \\export {};
        \\// @Filename: src/services/tsconfig.json
        \\{
        \\    "extends": "../tsconfig-base.json",
        \\    "compilerOptions": { "lib": ["es5"] },
        \\    "references": [
        \\        { "path": "../compiler" }
        \\    ]
        \\}
        \\// @Filename: src/services/services.ts
        \\import {} from "../compiler/parser.ts";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "/src/services/services.ts");
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestTsxFindAllReferences9" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\interface ClickableProps {
        \\    children?: string;
        \\    className?: string;
        \\}
        \\interface ButtonProps extends ClickableProps {
        \\    onClick(event?: React.MouseEvent<HTMLButtonElement>): void;
        \\}
        \\interface LinkProps extends ClickableProps {
        \\    /*1*/goTo: string;
        \\}
        \\declare function MainButton(buttonProps: ButtonProps): JSX.Element;
        \\declare function MainButton(linkProps: LinkProps): JSX.Element;
        \\declare function MainButton(props: ButtonProps | LinkProps): JSX.Element;
        \\let opt = <MainButton />;
        \\let opt = <MainButton children="chidlren" />;
        \\let opt = <MainButton onClick={()=>{}} />;
        \\let opt = <MainButton onClick={()=>{}} ignore-prop />;
        \\let opt = <MainButton goTo="goTo" />;
        \\let opt = <MainButton goTo />;
        \\let opt = <MainButton wrong />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCompletionsImport_preferUpdatingExistingImport" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @Filename: /deep/module/why/you/want/this/path.ts
        \\export const x = 0;
        \\export const y = 1;
        \\// @Filename: /nice/reexport.ts
        \\import { x, y } from "../deep/module/why/you/want/this/path";
        \\export { x, y };
        \\// @Filename: /index.ts
        \\import { x } from "./deep/module/why/you/want/this/path";
        \\
        \\y/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     "x",
//                     &.{
//                         .Label = "y",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "./deep/module/why/you/want/this/path",
//                             },
//                         },
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     },
//                 }, false,
//             ),
//         },
//     });
}

test "TestQuickInfoOnExpandoLikePropertyWithSetterDeclarationJs1" {
    const content =
        \\// @strict: true
        \\// @checkJs: true
        \\// @filename: index.js
        \\const x = {};
        \\
        \\Object.defineProperty(x, "foo", {
        \\  /** @param {number} v */
        \\  set(v) {},
        \\});
        \\
        \\x.foo/**/ = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(property) x.foo: number", "");
}

test "TestImportNameCodeFix_symlink" {
    const content =
        \\// @moduleResolution: bundler
        \\// @noLib: true
        \\// @Filename: /node_modules/real/index.d.ts
        \\// @Symlink: /node_modules/link/index.d.ts
        \\export const foo: number;
        \\// @Filename: /a.ts
        \\import { foo } from "link";
        \\// @Filename: /b.ts
        \\[|foo;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"link\";\n\nfoo;",
        "import { foo } from \"real\";\n\nfoo;",
    }, null );
}

test "TestCompletionInNamedImportLocation" {
    const content =
        \\// @Filename: file.ts
        \\export var x = 10;
        \\export var y = 10;
        \\export { x as await, x as interface, x as unique };
        \\export default class C {
        \\}
        \\// @Filename: a.ts
        \\import { /*1*/ } from "./file";
        \\import { x, /*2*/ } from "./file";
        \\import { x, y, /*3*/ } from "./file";
        \\import { x, y, await as await_, /*4*/ } from "./file";
        \\import { x, y, await as await_, interface as interface_, /*5*/ } from "./file";
        \\import { x, y, await as await_, interface as interface_, unique, /*6*/ } from "./file";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "a.ts");
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "await",
//                     .InsertText = undefined("await as await_"),
//                 },
//                 &.{
//                     .Label =      "interface",
//                     .InsertText = undefined("interface as interface_"),
//                 },
//                 &.{
//                     .Label = "unique",
//                 },
//                 &.{
//                     .Label =  "x",
//                     .Detail = undefined("var x: number"),
//                 },
//                 &.{
//                     .Label =  "y",
//                     .Detail = undefined("var y: number"),
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
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
//             .Exact = &.{
//                 &.{
//                     .Label =      "await",
//                     .InsertText = undefined("await as await_"),
//                 },
//                 &.{
//                     .Label =      "interface",
//                     .InsertText = undefined("interface as interface_"),
//                 },
//                 &.{
//                     .Label = "unique",
//                 },
//                 &.{
//                     .Label =  "y",
//                     .Detail = undefined("var y: number"),
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
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
//             .Exact = &.{
//                 &.{
//                     .Label =      "await",
//                     .InsertText = undefined("await as await_"),
//                 },
//                 &.{
//                     .Label =      "interface",
//                     .InsertText = undefined("interface as interface_"),
//                 },
//                 &.{
//                     .Label = "unique",
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
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
//             .Exact = &.{
//                 &.{
//                     .Label =      "interface",
//                     .InsertText = undefined("interface as interface_"),
//                 },
//                 &.{
//                     .Label = "unique",
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
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
//             .Exact = &.{
//                 &.{
//                     .Label = "unique",
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
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
//             .Exact = &.{},
//         },
//     });
}

test "TestSyntacticClassificationsJsx1" {
    const content =
        \\// @Filename: file1.tsx
        \\let x  = <div a = "some-value" b = {1}>
        \\    some jsx text
        \\</div>;
        \\
        \\let y = <element attr="123"/>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable.declaration", .Text = "x"},
//         .{.Type = "variable.declaration", .Text = "y"},
//     });
}

test "TestMemberCompletionOnTypeParameters2" {
    const content =
        \\class A {
        \\    foo(): string { return ''; }
        \\}
        \\
        \\class B extends A {
        \\    bar(): string {
        \\        return '';
        \\    }
        \\}
        \\
        \\class C<U extends A, T extends A> {
        \\    x: U;
        \\    y = this.x./**/ // completion list here
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
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

test "TestGetJavaScriptSyntacticDiagnostics6" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\interface I { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestGetOccurrencesIfElse" {
    const content =
        \\[|if|] (true) {
        \\    if (false) {
        \\    }
        \\    else {
        \\    }
        \\    if (true) {
        \\    }
        \\    else {
        \\        if (false)
        \\            if (true)
        \\                var x = undefined;
        \\    }
        \\}
        \\[|else            i/**/f|] (null) {
        \\}
        \\[|else|] /* whar garbl */ [|if|] (undefined) {
        \\}
        \\[|else|]
        \\[|if|] (false) {
        \\}
        \\[|else|] { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestInlayHintsInteractiveInferredTypePredicate1" {
    const content =
        \\// @strict: true
        \\function test(x: unknown) {
        \\  return typeof x === 'number';
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayFunctionLikeReturnTypeHints = core.TSTrue}});
}

test "TestCompletionsGenericTypeWithMultipleBases1" {
    const content =
        \\export interface iBaseScope {
        \\    watch: () => void;
        \\}
        \\export interface iMover {
        \\    moveUp: () => void;
        \\}
        \\export interface iScope<TModel> extends iBaseScope, iMover {
        \\    family: TModel;
        \\}
        \\var x: iScope<number>;
        \\x./**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "family",
//                     .Detail = undefined("(property) iScope<number>.family: number"),
//                 },
//                 &.{
//                     .Label =  "moveUp",
//                     .Detail = undefined("(property) iMover.moveUp: () => void"),
//                 },
//                 &.{
//                     .Label =  "watch",
//                     .Detail = undefined("(property) iBaseScope.watch: () => void"),
//                 },
//             },
//         },
//     });
}

test "TestSignatureHelpOnOverloadsDifferentArity2" {
    const content =
        \\declare function f(s: string);
        \\declare function f(n: number);
        \\declare function f(s: string, b: boolean);
        \\declare function f(n: number, b: boolean);
        \\
        \\f(1/**/ var
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f(n: number): any", .ParameterName = "n", .ParameterSpan = "n: number", .OverloadsCount = 4});
    _ = f.Insert(undefined, ", ");
    // try f.VerifySignatureHelp(undefined, .{.Text = "f(n: number, b: boolean): any", .ParameterName = "b", .ParameterSpan = "b: boolean", .OverloadsCount = 4});
}

test "TestCompletionListOnMethodParameterName" {
    const content =
        \\class A {
        \\    foo(nu/**/: number) {
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestImportNameCodeFixNewImportIndex_notForClassicResolution" {
    const content =
        \\// @moduleResolution: classic
        \\// @Filename: /a/index.ts
        \\export const foo = 0;
        \\// @Filename: /node_modules/x/index.d.ts
        \\export const bar = 0;
        \\// @Filename: /b.ts
        \\[|foo;|]
        \\// @Filename: /c.ts
        \\[|bar;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a/index.ts");
    _ = f.GoToFile(undefined, "/b.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { foo } from \"./a/index\";\n\nfoo;",
    }, null );
    _ = f.GoToFile(undefined, "/c.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { bar } from \"./node_modules/x/index\";\n\nbar;",
    }, null );
}

test "TestCompletionsGenericIndexedAccess3" {
    const content =
        \\interface CustomElements {
        \\  'component-one': {
        \\      foo?: string;
        \\  },
        \\  'component-two': {
        \\      bar?: string;
        \\  }
        \\}
        \\
        \\interface Options<T extends keyof CustomElements> {
        \\  props: CustomElements[T];
        \\}
        \\
        \\declare function create<T extends keyof CustomElements>(name: T, options: Options<T>): void;
        \\
        \\create('component-one', { props: { /*1*/ } });
        \\create('component-two', { props: { /*2*/ } });
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
//             .Exact = &.{
//                 &.{
//                     .Label =      "foo?",
//                     .InsertText = undefined("foo"),
//                     .FilterText = undefined("foo"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
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
//             .Exact = &.{
//                 &.{
//                     .Label =      "bar?",
//                     .InsertText = undefined("bar"),
//                     .FilterText = undefined("bar"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionForStringLiteralNonrelativeImport2" {
    const content =
        \\// @Filename: tests/test0.ts
        \\import * as foo1 from "fake-module//*import_as0*/
        \\import foo2 = require("fake-module//*import_equals0*/
        \\var foo3 = require("fake-module//*require0*/
        \\// @Filename: package.json
        \\{ "dependencies": { "fake-module": "latest" }, "devDependencies": { "fake-module-dev": "latest" } }
        \\// @Filename: node_modules/fake-module/repeated.ts
        \\/*repeatedts*/
        \\// @Filename: node_modules/fake-module/repeated.tsx
        \\/*repeatedtsx*/
        \\// @Filename: node_modules/fake-module/repeated.d.ts
        \\/*repeateddts*/
        \\// @Filename: node_modules/fake-module/other.js
        \\/*other*/
        \\// @Filename: node_modules/fake-module/other2.js
        \\/*other2*/
        \\// @Filename: node_modules/unlisted-module/index.js
        \\/*unlisted-module*/
        \\// @Filename: ambient.ts
        \\declare module "fake-module/other"
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"import_as0", "import_equals0", "require0"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "other",
//                 "repeated",
//             },
//         },
//     });
}

test "TestGetJavaScriptSyntacticDiagnostics18" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\class C {
        \\    x; // Regular property declaration allowed
        \\    static y; // static allowed
        \\    public z; // public not allowed
        \\}
        \\// @Filename: b.js
        \\class C {
        \\    x: number; // Types not allowed
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineNonSuggestionDiagnostics(undefined);
}

test "TestSyntheticImportFromBabelGeneratedFile2" {
    const content =
        \\// @allowJs: true
        \\// @allowSyntheticDefaultImports: true
        \\// @Filename: /a.js
        \\Object.defineProperty(exports, "__esModule", {
        \\    value: true
        \\});
        \\exports.default = f;
        \\/**
        \\ * Run this function
        \\ * @param {string} t
        \\ */
        \\function f(t) {}
        \\// @Filename: /b.js
        \\import f from "./a"
        \\/**/f
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(alias) function f(t: string): void\nimport f", "Run this function");
}

test "TestJsxQualifiedTagCompletion" {
    const content =
        \\//@Filename: file.tsx
        \\declare var React: any;
        \\namespace NS {
        \\    export var Foo: any = null;
        \\}
        \\const j = <NS.Foo>Hello!/**/
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "</");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "NS.Foo>",
//             },
//         },
//     });
}

test "TestQuickInfoSignatureRestParameterFromUnion1" {
    const content =
        \\declare const rest:
        \\  | ((v: { a: true }, ...rest: string[]) => unknown)
        \\  | ((v: { b: true }) => unknown);
        \\
        \\/**/rest({ a: true, b: true }, "foo", "bar");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "const rest: (v: {\n    a: true;\n} & {\n    b: true;\n}, ...rest: string[]) => unknown", "");
}

test "TestQuickInfoLink7" {
    const content =
        \\/**
        \\ * See {@link |       } instead
        \\ */
        \\const /**/B = 456;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCompletionsImport_umdDefaultNoCrash2" {
    const content =
        \\// @moduleResolution: bundler
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /node_modules/dottie/package.json
        \\{
        \\  "name": "dottie",
        \\  "main": "dottie.js"
        \\}
        \\// @Filename: /node_modules/dottie/dottie.js
        \\(function (undefined) {
        \\  var root = this;
        \\
        \\  var Dottie = function () {};
        \\
        \\  Dottie["default"] = function (object, path, value) {};
        \\
        \\  if (typeof module !== "undefined" && module.exports) {
        \\    exports = module.exports = Dottie;
        \\  } else {
        \\    root["Dottie"] = Dottie;
        \\    root["Dot"] = Dottie;
        \\
        \\    if (typeof define === "function") {
        \\      define([], function () {
        \\        return Dottie;
        \\      });
        \\    }
        \\  }
        \\})();
        \\// @Filename: /src/index.js
        \\import Dottie from 'dottie';
        \\/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "Dottie",
//                 },
//             },
//         },
//     });
}

test "TestSmartSelection_JSDocTags12" {
    const content =
        \\type B = {};
        \\type A = {
        \\    a(/** Comment */ /*1*/p0: number, /** Comment */ /*2*/p1: number, /** Comment */ /*3*/p2: number): string;
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestOrganizeImports6" {
    const content =
        \\import * as something from "path"; /* small comment */ // single line one.
        \\/* some comment here
        \\* and there
        \\*/
        \\import * as somethingElse from "anotherpath";
        \\import * as anotherThing from "someopath"; /* small comment */ // single line one.
        \\/* some comment here
        \\* and there
        \\*/
        \\import * as anotherThingElse from "someotherpath";
        \\
        \\anotherThing;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "/* some comment here\n* and there\n*/\nimport * as anotherThing from \"someopath\"; /* small comment */ // single line one.\n/* some comment here\n* and there\n*/\n\nanotherThing;",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestCallHierarchyExportEqualsFunction" {
    const content =
        \\// @filename: main.ts
        \\import bar = require("./other");
        \\
        \\function foo() {
        \\    bar();
        \\}
        \\// @filename: other.ts
        \\export = /**/function () {
        \\    baz();
        \\}
        \\
        \\function baz() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestCompletionsStringLiteral_fromTypeConstraint" {
    const content =
        \\// @stableTypeOrdering: true
        \\interface Foo { foo: string; bar: string; }
        \\type T = Pick<Foo, "[|/**/|]">;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label = "bar",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "bar",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label = "foo",
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFixNewImportFileQuoteStyle0" {
    const content =
        \\[|import { v2 } from './module2';
        \\
        \\f1/*0*/();|]
        \\// @Filename: module1.ts
        \\export function f1() {}
        \\// @Filename: module2.ts
        \\export var v2 = 6;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from './module1';\nimport { v2 } from './module2';\n\nf1();",
    }, null );
}

test "TestGoToImplementationLocal_01" {
    const content =
        \\const [|hello|] = function() {};
        \\he/*function_call*/llo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call");
}

test "TestImportNameCodeFix_order" {
    const content =
        \\// @Filename: /a.ts
        \\export const foo: number;
        \\// @Filename: /b.ts
        \\export const foo: number;
        \\export const bar: number;
        \\// @Filename: /c.ts
        \\[|import { bar } from "./b";
        \\foo;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/c.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { bar, foo } from \"./b\";\nfoo;",
        "import { foo } from \"./a\";\nimport { bar } from \"./b\";\nfoo;",
    }, null );
}

test "TestGoToDefinitionUnionTypeProperty3" {
    const content =
        \\interface Array<T> {
        \\    /*definition*/specialPop(): T
        \\}
        \\
        \\var strings: string[];
        \\var numbers: number[];
        \\
        \\var x = (strings || numbers).[|/*usage*/specialPop|]()
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "usage");
}

test "TestInlayHintsRestParameters1" {
    const content =
        \\function foo1(a: number, ...b: number[]) {}
        \\foo1(1, 1, 1, 1);
        \\type Args2 = [a: number, b: number]
        \\declare function foo2(c: number, ...args: Args2);
        \\foo2(1, 2, 3)
        \\type Args3 = [number, number]
        \\declare function foo3(c: number, ...args: Args3);
        \\foo3(1, 2, 3)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsLiterals}});
}

test "TestGetOccurrencesTryCatchFinallyBroken" {
    const content =
        \\t /*1*/ry {
        \\    t/*2*/ry {
        \\    }
        \\    ctch (x) {
        \\    }
        \\
        \\    tr {
        \\    }
        \\    fin/*3*/ally {
        \\    }
        \\}
        \\c/*4*/atch (e) {
        \\}
        \\f/*5*/inally {
        \\}
        \\
        \\// Missing catch variable
        \\t/*6*/ry {
        \\}
        \\catc/*7*/h {
        \\}
        \\/*8*/finally {
        \\}
        \\
        \\// Missing try entirely
        \\cat/*9*/ch (x) {
        \\}
        \\final/*10*/ly {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestQuickInfoInheritDoc6" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: quickInfoInheritDoc6.js
        \\class B extends UNRESOLVED_VALUE_DEFINITELY_DOES_NOT_EXIST {
        \\    /**
        \\     * @inheritdoc
        \\     */
        \\    static /**/value() {
        \\        return undefined;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestRenameJsThisProperty05" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\class C {
        \\  constructor(y) {
        \\    this.x = y;
        \\  }
        \\}
        \\[|C.prototype.[|{| "contextRangeIndex": 0 |}z|] = 1;|]
        \\var t = new C(12);
        \\[|t.[|{| "contextRangeIndex": 2 |}z|] = 11;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "z");
}

test "TestArrayCallAndConstructTypings" {
    const content =
        \\var a/*1*/1 = new Array();
        \\var a/*2*/2 = new Array(1);
        \\var a/*3*/3 = new Array<boolean>();
        \\var a/*4*/4 = new Array<boolean>(1);
        \\var a/*5*/5 = new Array("s");
        \\var a/*6*/6 = Array();
        \\var a/*7*/7 = Array(1);
        \\var a/*8*/8 = Array<boolean>();
        \\var a/*9*/9 = Array<boolean>(1);
        \\var a/*10*/10 = Array("s");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var a1: any[]", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var a2: any[]", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var a3: boolean[]", "");
    try f.VerifyQuickInfoAt(undefined, "4", "var a4: boolean[]", "");
    try f.VerifyQuickInfoAt(undefined, "5", "var a5: string[]", "");
    try f.VerifyQuickInfoAt(undefined, "6", "var a6: any[]", "");
    try f.VerifyQuickInfoAt(undefined, "7", "var a7: any[]", "");
    try f.VerifyQuickInfoAt(undefined, "8", "var a8: boolean[]", "");
    try f.VerifyQuickInfoAt(undefined, "9", "var a9: boolean[]", "");
    try f.VerifyQuickInfoAt(undefined, "10", "var a10: string[]", "");
}

test "TestOccurrences01" {
    const content =
        \\// @lib: es5
        \\foo: [|switch|] (10) {
        \\    [|case|] 1:
        \\    [|case|] 2:
        \\    [|case|] 3:
        \\        [|break|];
        \\        [|break|] foo;
        \\        continue;
        \\        continue foo;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestGetEditsForFileRename_tsconfig" {
    const content =
        \\// @Filename: /src/tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "baseUrl": "./old",
        \\        "paths": {
        \\            "foo": ["old"],
        \\        },
        \\        "rootDir": "old",
        \\        "rootDirs": ["old"],
        \\        "typeRoots": ["old"],
        \\    },
        \\    "files": ["old/a.ts"],
        \\    "include": ["old/*.ts"],
        \\    "exclude": ["old"],
        \\}
        \\// @Filename: /src/old/someFile.ts
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyWillRenameFilesEdits(undefined, "/src/old", "/src/new", .{
//         .@"/src/tsconfig.json" = "{\n    \"compilerOptions\": {\n        \"baseUrl\": \"new\",\n        \"paths\": {\n            \"foo\": [\"new\"],\n        },\n        \"rootDir\": \"new\",\n        \"rootDirs\": [\"new\"],\n        \"typeRoots\": [\"new\"],\n    },\n    \"files\": [\"new/a.ts\"],\n    \"include\": [\"new/*.ts\"],\n    \"exclude\": [\"new\"],\n}",
//     }, null );
}

test "TestJsDocPropertyDescription5" {
    const content =
        \\interface Multiple1Example {
        \\    /** Something generic */
        \\    [key: number | symbol | 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "multiple1", "any", "");
}

test "TestGetEditsForFileRename_directory" {
    const content =
        \\// @Filename: /a.ts
        \\/// <reference path="./src/old/file.ts" />
        \\import old from "./src/old";
        \\import old2 from "./src/old/file";
        \\export default 0;
        \\// @Filename: /src/b.ts
        \\/// <reference path="./old/file.ts" />
        \\import old from "./old";
        \\import old2 from "./old/file";
        \\export default 0;
        \\// @Filename: /src/foo/c.ts
        \\/// <reference path="../old/file.ts" />
        \\import old from "../old";
        \\import old2 from "../old/file";
        \\export default 0;
        \\// @Filename: /src/old/index.ts
        \\import a from "../../a";
        \\import a2 from "../b";
        \\import a3 from "../foo/c";
        \\import f from "./file";
        \\export default 0;
        \\// @Filename: /src/old/file.ts
        \\export default 0;
        \\// @Filename: /tsconfig.json
        \\{ "files": ["a.ts", "src/b.ts", "src/foo/c.ts", "src/old/index.ts", "src/old/file.ts"] }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyWillRenameFilesEdits(undefined, "/src/old", "/src/new", .{
//         .@"/a.ts" = "/// <reference path=\"./src/new/file.ts\" />\nimport old from \"./src/new\";\nimport old2 from \"./src/new/file\";\nexport default 0;",
//         .@"/src/b.ts" = "/// <reference path=\"./new/file.ts\" />\nimport old from \"./new\";\nimport old2 from \"./new/file\";\nexport default 0;",
//         .@"/src/foo/c.ts" = "/// <reference path=\"../new/file.ts\" />\nimport old from \"../new\";\nimport old2 from \"../new/file\";\nexport default 0;",
//         .@"/tsconfig.json" = "{ \"files\": [\"a.ts\", \"src/b.ts\", \"src/foo/c.ts\", \"src/new/index.ts\", \"src/new/file.ts\"] }",
//     }, null );
}

test "TestJsdocLink3" {
    const content =
        \\// @Filename: /jsdocLink3.ts
        \\export class C {
        \\}
        \\// @Filename: /module1.ts
        \\import { C } from './jsdocLink3'
        \\/**
        \\ * {@link C}
        \\ * @wat Makes a {@link C}. A default one.
        \\ * {@link C()}
        \\ * {@link C|postfix text}
        \\ * {@link unformatted postfix text}
        \\ * @see {@link C} its great
        \\ */
        \\function /**/CC() {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestMemberListInWithBlock3" {
    const content =
        \\var x = { a: 0 };
        \\with(x./*1*/
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
//             .Exact = &.{
//                 "a",
//             },
//         },
//     });
}

test "TestInlayHintsInteractiveTemplateLiteralTypes" {
    const content =
        \\declare function getTemplateLiteral1(): 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue}});
}

test "TestOccurrences02" {
    const content =
        \\// @lib: es5
        \\function [|f|](x: typeof [|f|]) {
        \\    [|f|]([|f|]);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestSignatureHelpFunctionOverload" {
    const content =
        \\function functionOverload();
        \\function functionOverload(test: string);
        \\function functionOverload(test?: string) { }
        \\functionOverload(/*functionOverload1*/);
        \\functionOverload(""/*functionOverload2*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "functionOverload1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "functionOverload(): any", .ParameterCount = 0, .OverloadsCount = 2});
    _ = f.GoToMarker(undefined, "functionOverload2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "functionOverload(test: string): any", .ParameterName = "test", .ParameterSpan = "test: string", .OverloadsCount = 2});
}

test "TestSyntacticClassificationsConflictMarkers2" {
    const content =
        \\<<<<<<< HEAD
        \\class C { }
        \\=======
        \\class D { }
        \\>>>>>>> Branch - a
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "class.declaration", .Text = "C"},
//     });
}

test "TestCompletionEntryAfterASIExpressionInClass" {
    const content =
        \\class Parent {
        \\  protected shouldWork() {
        \\      console.log();
        \\  }
        \\}
        \\
        \\class Child extends Parent {
        \\            // this assumes ASI, but on next line wants to  
        \\  x = () => 1
        \\  shoul/*insideid*/ 
        \\}
        \\
        \\class ChildTwo extends Parent {
        \\            // this assumes ASI, but on next line wants to  
        \\  x = () => 1
        \\  /*root*/ //nothing
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"insideid", "root"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "shouldWork",
//             },
//         },
//     });
}

test "TestDocCommentTemplateWithMultipleJSDoc2" {
    const content =
        \\/** @typedef {string} Id */
        \\
        \\/** /**/ */
        \\function foo(x, y, z) {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "", 7, "/**\n * \n * @param x\n * @param y\n * @param z\n */", null);
}

test "TestDocCommentTemplateInSingleLineComment" {
    const content =
        \\// @Filename: justAComment.ts
        \\// We want to check off-by-one errors in assessing the end of the comment, so we check twice,
        \\// first with a trailing space and then without.
        \\// /*0*/ 
        \\// /*1*/
        \\// We also want to check EOF handling at the end of a comment
        \\// /*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.Markers();
    // try f.VerifyNoJSDocCompletion(undefined, marker);
}

test "TestGetOccurrencesClassExpressionPrivate" {
    const content =
        \\let A = class Foo {
        \\    [|private|] foo;
        \\    [|private|] private;
        \\    constructor([|private|] y: string, public x: string) {
        \\    }
        \\    [|private|] method() { }
        \\    public method2() { }
        \\    [|private|] static static() { }
        \\}
        \\
        \\let B = class D {
        \\    constructor(private x: number) {
        \\    }
        \\    private test() {}
        \\    public test2() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestPrototypeProperty" {
    const content =
        \\class A {}
        \\A./*1*/prototype;
        \\A./*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) A.prototype: A", "");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "prototype",
//                     .Detail = undefined("(property) A.prototype: A"),
//                 },
//             },
//         },
//     });
}

test "TestRenameInheritedProperties7" {
    const content =
        \\class C extends D {
        \\    [|[|{| "contextRangeIndex": 0 |}prop1|]: string;|]
        \\}
        \\
        \\class D extends C {
        \\    prop1: string;
        \\}
        \\
        \\var c: C;
        \\c.[|prop1|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "prop1");
}

test "TestMemberListOfEnumFromExternalModule" {
    const content =
        \\// @Filename: memberListOfEnumFromExternalModule_file0.ts
        \\export enum Topic{ One, Two }
        \\var topic = Topic.One;
        \\// @Filename: memberListOfEnumFromExternalModule_file1.ts
        \\import t = require('./memberListOfEnumFromExternalModule_file0');
        \\var topic = t.Topic./*1*/
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
//             .Exact = &.{
//                 "One",
//                 "Two",
//             },
//         },
//     });
}

test "TestFormattingJsxTexts3" {
    const content =
        \\//@Filename: file.tsx
        \\function foo() {
        \\const bar = "Oh no";
        \\
        \\return (
        \\<div>"{bar}"</div>
        \\)
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "function foo() {\n    const bar = \"Oh no\";\n\n    return (\n        <div>\"{bar}\"</div>\n    )\n}");
}

test "TestImportNameCodeFixNewImportFileQuoteStyle1" {
    const content =
        \\[|import { v2 } from "./module2";
        \\
        \\f1/*0*/();|]
        \\// @Filename: module1.ts
        \\export function f1() {}
        \\// @Filename: module2.ts
        \\export var v2 = 6;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { f1 } from \"./module1\";\nimport { v2 } from \"./module2\";\n\nf1();",
    }, null );
}

test "TestFindAllRefsForFunctionExpression01" {
    const content =
        \\// @Filename: file1.ts
        \\var foo = /*1*/function /*2*/foo(a = /*3*/foo(), b = () => /*4*/foo) {
        \\    /*5*/foo(/*6*/foo, /*7*/foo);
        \\}
        \\// @Filename: file2.ts
        \\/// <reference path="file1.ts" />
        \\foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7");
}

test "TestImportNameCodeFixNewImportAllowSyntheticDefaultImports5" {
    const content =
        \\// @AllowSyntheticDefaultImports: false
        \\// @Module: umd
        \\// @Filename: a/f1.ts
        \\[|export var x = 0;
        \\bar/*0*/();|]
        \\// @Filename: a/foo.d.ts
        \\declare function bar(): number;
        \\export = bar;
        \\export as namespace bar;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import bar = require(\"./foo\");\n\nexport var x = 0;\nbar();",
    }, null );
}

test "TestDocumentHighlights_moduleImport_filesToSearch" {
    const content =
        \\// @Filename: /node_modules/@types/foo/index.d.ts
        \\export const x: number;
        \\// @Filename: /a.ts
        \\import * as foo from "foo";
        \\foo.[|x|];
        \\// @Filename: /b.ts
        \\import { [|x|] } from "foo";
        \\// @Filename: /c.ts
        \\import { x } from "foo";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlightsWithOptions(undefined, null , &.{"/a.ts", "/b.ts"}, ToAny(f.Ranges()));
}

test "TestTypeAssertionsFormatting" {
    const content =
        \\( <  any   >      publisher);/*1*/
        \\ <  any  >      3;/*2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "(<any>publisher);");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "<any>3;");
}

test "TestGoToImplementationInterface_03" {
    const content =
        \\interface Fo/*interface_definition*/o { hello: () => void }
        \\
        \\var x = <Foo> [|{ hello: () => {} }|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "interface_definition");
}

test "TestGoToDefinitionObjectLiteralProperties3" {
    const content =
        \\type A = {
        \\  foo: unknown;
        \\};
        \\
        \\type B = {
        \\  foo?: unknown;
        \\  bar: unknown;
        \\};
        \\
        \\function test1(arg: A | B) {}
        \\
        \\test1({
        \\  foo/*1*/: 1,
        \\});
        \\
        \\function test2<T extends A>(arg: T | B) {}
        \\
        \\test2({
        \\  foo/*2*/: 2,
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1", "2");
}

test "TestTsxFindAllReferences6" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\interface OptionPropBag {
        \\    propx: number
        \\    propString: string
        \\    optional?: boolean
        \\}
        \\declare function Opt(attributes: OptionPropBag): JSX.Element;
        \\let opt = <Opt /*1*/wrong />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestOrganizeImportsGroup_CommentInNewline" {
    const content =
        \\// polyfill
        \\import c from "C";
        \\// not polyfill
        \\import d from "D";
        \\import a from "A";
        \\import b from "B";
        \\
        \\console.log(a, b, c, d)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "// polyfill\nimport c from \"C\";\n// not polyfill\nimport a from \"A\";\nimport b from \"B\";\nimport d from \"D\";\n\nconsole.log(a, b, c, d)",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestCompletionAfterNewline" {
    const content =
        \\// @lib: es5
        \\let foo /*1*/
        \\/*2*/
        \\/*3*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "1", null);
    // f.VerifyCompletions(undefined, &.{"2", "3"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalsPlus(
//                 &.{
//                     &.{
//                         .Label = "foo",
//                     },
//                 }, false,
//             ),
//         },
//     });
}

test "TestGetEditsForFileRename_tsconfig_empty_include" {
    const content =
        \\// @Filename: /a/foo.ts
        \\const x = 1
        \\// @Filename: /a/tsconfig.json
        \\{ "include": [] }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyWillRenameFilesEdits(undefined, "/a/foo.ts", "/a/bar.ts", .{}, null );
}

test "TestUnusedClassInNamespaceWithTrivia1" {
    const content =
        \\// @noUnusedLocals: true
        \\[| namespace greeter {
        \\  /* comment1 */
        \\  class /* comment2 */ class1 {
        \\  }
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "namespace greeter {\n   /* comment1 */\n}", false, 0, 0);
}

test "TestIsDefinitionSingleReference" {
    const content =
        \\function /*1*/f() {}
        \\/*2*/f();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2");
}

test "TestSignatureHelpExpandedTuplesArgumentIndex" {
    const content =
        \\function foo(...args: [string, string] | [number, string, string]
        \\) {
        \\
        \\}
        \\
        \\foo(123/*1*/,)
        \\foo(""/*2*/, ""/*3*/)
        \\foo(123/*4*/, ""/*5*/, )
        \\foo(123/*6*/, ""/*7*/, ""/*8*/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(args_0: number, args_1: string, args_2: string): void", .ParameterCount = 3, .ParameterName = "args_0", .ParameterSpan = "args_0: number", .OverloadsCount = 2, .OverrideSelectedItemIndex = 1, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(args_0: string, args_1: string): void", .ParameterCount = 2, .ParameterName = "args_0", .ParameterSpan = "args_0: string", .OverloadsCount = 2, .OverrideSelectedItemIndex = 0, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(args_0: string, args_1: string): void", .ParameterCount = 2, .ParameterName = "args_1", .ParameterSpan = "args_1: string", .OverloadsCount = 2, .OverrideSelectedItemIndex = 0, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "4");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(args_0: number, args_1: string, args_2: string): void", .ParameterCount = 3, .ParameterName = "args_0", .ParameterSpan = "args_0: number", .OverloadsCount = 2, .OverrideSelectedItemIndex = 1, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "5");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(args_0: number, args_1: string, args_2: string): void", .ParameterCount = 3, .ParameterName = "args_1", .ParameterSpan = "args_1: string", .OverloadsCount = 2, .OverrideSelectedItemIndex = 1, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "6");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(args_0: number, args_1: string, args_2: string): void", .ParameterCount = 3, .ParameterName = "args_0", .ParameterSpan = "args_0: number", .OverloadsCount = 2, .OverrideSelectedItemIndex = 1, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "7");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(args_0: number, args_1: string, args_2: string): void", .ParameterCount = 3, .ParameterName = "args_1", .ParameterSpan = "args_1: string", .OverloadsCount = 2, .OverrideSelectedItemIndex = 1, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "8");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(args_0: number, args_1: string, args_2: string): void", .ParameterCount = 3, .ParameterName = "args_2", .ParameterSpan = "args_2: string", .OverloadsCount = 2, .OverrideSelectedItemIndex = 1, .IsVariadic = false, .IsVariadicSet = true});
}

test "TestGoToDefinitionOverriddenMember6" {
    const content =
        \\// @noImplicitOverride: true
        \\class Foo {
        \\    m() {}
        \\}
        \\class Bar extends Foo {
        \\    [|/*1*/override|] m1() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCodeFixMissingTypeAnnotationOnExports34_object_spread" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @Filename: /code.ts
        \\const Start = {
        \\  A: 'A',
        \\  B: 'B',
        \\} as const;
        \\
        \\const End = {
        \\  Y: "Y",
        \\  Z: "Z"
        \\} as const;
        \\export const All_Part1 = {};
        \\function getPart() {
        \\  return { M: "Z"}
        \\}
        \\
        \\export const All = {
        \\  x: 1,
        \\  ...Start,
        \\  y: 1,
        \\  ...getPart(),
        \\  ...End,
        \\  z: 1,
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add annotation of type 'typeof All_Part1_1 & typeof Start & typeof All_Part3 & typeof All_Part4 & typeof End & typeof All_Part6'",
        .NewFileContent = "const Start = {\n  A: 'A',\n  B: 'B',\n} as const;\n\nconst End = {\n  Y: \"Y\",\n  Z: \"Z\"\n} as const;\nexport const All_Part1 = {};\nfunction getPart() {\n  return { M: \"Z\"}\n}\n\nconst All_Part1_1 = {\n    x: 1\n};\nconst All_Part3 = {\n    y: 1\n};\nconst All_Part4 = getPart();\nconst All_Part6 = {\n    z: 1\n};\nexport const All: typeof All_Part1_1 & typeof Start & typeof All_Part3 & typeof All_Part4 & typeof End & typeof All_Part6 = {\n    ...All_Part1_1,\n    ...Start,\n    ...All_Part3,\n    ...All_Part4,\n    ...End,\n    ...All_Part6\n};",
        .Index = 1,
    });
}

test "TestCompletionsWithDeprecatedTag7" {
    const content =
        \\// @strict: true
        \\interface I {
        \\    /** @deprecated a */
        \\    a: number;
        \\}
        \\const foo = {
        \\    a: 1
        \\}
        \\const i: I = {
        \\    ...foo,
        \\    /**/
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =    "a",
//                     .SortText = undefined(string(ls.DeprecateSortText(ls.SortTextMemberDeclaredBySpreadAssignment))),
//                     .Kind =     undefined(lsproto.CompletionItemKindField),
//                     .Tags =     &&.{lsproto.CompletionItemTagDeprecated},
//                 },
//             },
//         },
//     });
}

test "TestReferencesForStringLiteralPropertyNames" {
    const content =
        \\class Foo {
        \\    public "/*1*/ss": any;
        \\}
        \\
        \\var x: Foo;
        \\x.ss;
        \\x["ss"];
        \\x = { "ss": 0 };
        \\x = { ss: 0 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFormatDocumentPreserveTrailingWhitespace" {
    const content =
        \\
        \\var a;     
        \\var b     
        \\     
        \\//     
        \\function b(){     
        \\    while(true){     
        \\    }     
        \\}     
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts233);
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "\nvar a;     \nvar b     \n     \n//     \nfunction b() {     \n    while (true) {     \n    }     \n}     \n");
}

test "TestRenameAliasExternalModule3" {
    const content =
        \\// @Filename: a.ts
        \\namespace SomeModule { [|export class [|{| "contextRangeIndex": 0 |}SomeClass|] { }|] }
        \\export = SomeModule;
        \\// @Filename: b.ts
        \\import M = require("./a");
        \\import C = M.[|SomeClass|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "SomeClass");
}

test "TestCompletionUsingKeyword" {
    const content =
        \\function foo() {
        \\    usin/*1*/
        \\}
        \\async function bar() {
        \\    await usin/*2*/
        \\}
        \\
        \\class C {
        \\    foo() {
        \\        usin/*3*/
        \\    }
        \\
        \\    async bar() {
        \\        await usin/*4*/
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1", "2", "3", "4"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =    "using",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestJsDocPropertyDescription2" {
    const content =
        \\interface SymbolExample {
        \\    /** Something generic */
        \\    [key: symbol]: string;
        \\}
        \\function symbolExample(e: SymbolExample) {
        \\    console.log(e./*symbol*/anything);
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "symbol", "any", "");
}

test "TestRenameParameterPropertyDeclaration3" {
    const content =
        \\class Foo {
        \\    constructor([|protected [|{| "contextRangeIndex": 0 |}protectedParam|]: number|]) {
        \\        let protectedParam = [|protectedParam|];
        \\        this.[|protectedParam|] += 10;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "protectedParam");
}

test "TestCompletionListInTypeLiteralInTypeParameter14" {
    const content =
        \\interface Foo {
        \\   one: string;
        \\   two: number;
        \\}
        \\declare function f<T extends Foo>(x: TemplateStringsArray): void;
        \\f<{/*0*/}>
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "0", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
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

test "TestFindAllReferencesDynamicImport3" {
    const content =
        \\// @Filename: foo.ts
        \\[|export function /*0*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 0 |}bar|]() { return "bar"; }|]
        \\import('./foo').then(([|{ /*1*/[|{| "isWriteAccess": true, "isDefinition": true, "contextRangeIndex": 2 |}bar|] }|]) => undefined);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1");
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[3]);
}

test "TestGoToDefinitionReturn2" {
    const content =
        \\function foo() {
        \\    return /*end*/() => {
        \\        [|/*start*/return|] 10;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestCodeFixClassImplementInterfaceObjectLiteral" {
    const content =
        \\interface IPerson {
        \\    coordinate: {
        \\        x: number;
        \\        y: number;
        \\    }
        \\}
        \\class Person implements IPerson { }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'IPerson'",
        .NewFileContent = "interface IPerson {\n    coordinate: {\n        x: number;\n        y: number;\n    }\n}\nclass Person implements IPerson {\n    coordinate: { x: number; y: number; };\n}",
        .Index = 0,
    });
}

test "TestJsdocTypedefTagRename03" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsDocTypedef_form3.js
        \\
        \\/**
        \\ * [|@typedef /*1*/[|{| "contextRangeIndex": 0 |}Person|]
        \\ * @type {Object}
        \\ * @property {number} age
        \\ * @property {string} name
        \\ |]*/
        \\
        \\/** @type {/*2*/[|Person|]} */
        \\var person;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    _ = f.GoToFile(undefined, "jsDocTypedef_form3.js");
    // try f.VerifyBaselineRename(undefined, null , ToAny(f.GetRangesByText().Get("Person")));
}

test "TestNavigationBarItemsItemsExternalModules3" {
    const content =
        \\// @Filename: test/my fil    e.ts
        \\export class Bar {
        \\    public s: string;
        \\}
        \\export var x: number;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestCompletionsAugmentedTypesClass2" {
    const content =
        \\class c5b { public foo(){ } }
        \\namespace c5b { var y = 2; } // should be ok
        \\c5b./*1*/
        \\var r = new c5b();
        \\r./*2*/
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
//             .Excludes = &.{
//                 "y",
//             },
//         },
//     });
    _ = f.Backspace(undefined, 4);
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =  "foo",
//                     .Detail = undefined("(method) c5b.foo(): void"),
//                 },
//             },
//         },
//     });
}

test "TestCompletionsWithOptionalPropertiesGenericDeep" {
    const content =
        \\// @strict: true
        \\interface DeepOptions {
        \\    another?: boolean;
        \\}
        \\interface MyOptions {
        \\    hello?: boolean;
        \\    world?: boolean;
        \\    deep?: DeepOptions
        \\}
        \\declare function bar<T extends MyOptions>(options?: Partial<T>): void;
        \\bar({ deep: {/*1*/} });
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
//                 &.{
//                     .Label =      "another?",
//                     .InsertText = undefined("another"),
//                     .FilterText = undefined("another"),
//                     .SortText =   undefined(string(ls.SortTextOptionalMember)),
//                 },
//             },
//         },
//     });
}

test "TestIncrementalUpdateToClassImplementingGenericClass" {
    const content =
        \\declare function alert(message?: string): void;
        \\class Animal<T> {
        \\    constructor(public name: T) { }
        \\    move(meters: number) {
        \\        alert(this.name + " moved " + meters + "m.");
        \\    }
        \\}
        \\class Animal2 extends Animal<string> {
        \\    constructor(name: string) { super(name); }
        \\    /*1*/get name2() { return this.name; }
        \\}
        \\var a = new Animal2('eprst');
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyNoErrors(undefined);
    _ = f.Insert(undefined, "//");
    try f.VerifyNoErrors(undefined);
}

test "TestSignatureHelpRestArgs1" {
    const content =
        \\function fn(a: number, b: number, c: number) {}
        \\const a = [1, 2] as const;
        \\const b = [1] as const;
        \\
        \\fn(...a, /*1*/);
        \\fn(/*2*/, ...a);
        \\
        \\fn(...b, /*3*/);
        \\fn(/*4*/, ...b, /*5*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSignatureHelp(undefined);
}

test "TestSquiggleIllegalSubclassOverride" {
    const content =
        \\// @strict: false
        \\class Foo {
        \\    public x: number;
        \\}
        \\
        \\class Bar extends Foo {
        \\    public /*1*/x/*2*/: string = 'hi';
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyErrorExistsBetweenMarkers(undefined, "1", "2");
    try f.VerifyNumberOfErrorsInCurrentFile(undefined, 1);
}

test "TestCodeFixClassImplementInterfaceConstructorName1" {
    const content =
        \\interface I {
        \\    constructor: number;
        \\}
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    constructor: number;\n}\nclass C implements I {\n    [\"constructor\"]: number;\n}",
        .Index = 0,
    });
}

test "TestGenericInterfacePropertyInference1" {
    const content =
        \\// @strict: false
        \\interface I {
        \\    x: number;
        \\}
        \\
        \\var anInterface: I;
        \\interface IG<T> {
        \\    x: T;
        \\}
        \\var aGenericInterface: IG<number>;
        \\
        \\class C<T> implements IG<T> {
        \\    x: T;
        \\}
        \\
        \\interface Foo<T> {
        \\    prim1: number;
        \\    prim2: string;
        \\    ofT: T;
        \\    ofFooNum: Foo<number>;
        \\    ofInterface: I;
        \\    ofIG4: { x: number };
        \\    ofIG6: { x: T };
        \\    ofC2: C<number>;
        \\    ofC4: C<{ x: T }>
        \\}
        \\
        \\var f: Foo<any>;
        \\var f2: Foo<number>;
        \\var f3: Foo<I>;
        \\var f4: Foo<{ x: number }>;
        \\var f5: Foo<Foo<number>>;
        \\
        \\// T is any
        \\var f_/*a1*/r1  = f.prim1;
        \\var f_/*a2*/r2  = f.prim2;
        \\var f_/*a3*/r3  = f.ofT;
        \\var f_/*a4*/r5  = f.ofFooNum;
        \\var f_/*a5*/r8  = f.ofInterface;
        \\var f_/*a6*/r12 = f.ofIG4;
        \\var f_/*a7*/r14 = f.ofIG6;
        \\var f_/*a8*/r18 = f.ofC2;
        \\var f_/*a9*/r20 = f.ofC4;
        \\
        \\// T is number
        \\var f2_/*b1*/r1  = f2.prim1;
        \\var f2_/*b2*/r2  = f2.prim2;
        \\var f2_/*b3*/r3  = f2.ofT;
        \\var f2_/*b4*/r5  = f2.ofFooNum;
        \\var f2_/*b5*/r8  = f2.ofInterface;
        \\var f2_/*b6*/r12 = f2.ofIG4;
        \\var f2_/*b7*/r14 = f2.ofIG6;
        \\var f2_/*b8*/r18 = f2.ofC2;
        \\var f2_/*b9*/r20 = f2.ofC4;
        \\
        \\// T is I
        \\var f3_/*c1*/r1  = f3.prim1;
        \\var f3_/*c2*/r2  = f3.prim2;
        \\var f3_/*c3*/r3  = f3.ofT;
        \\var f3_/*c4*/r5  = f3.ofFooNum;
        \\var f3_/*c5*/r8  = f3.ofInterface;
        \\var f3_/*c6*/r12 = f3.ofIG4;
        \\var f3_/*c7*/r14 = f3.ofIG6;
        \\var f3_/*c8*/r18 = f3.ofC2;
        \\var f3_/*c9*/r20 = f3.ofC4;
        \\
        \\// T is {x: number}
        \\var f4_/*d1*/r1 =  f4.prim1;
        \\var f4_/*d2*/r2 =  f4.prim2;
        \\var f4_/*d3*/r3 =  f4.ofT;
        \\var f4_/*d4*/r5 =  f4.ofFooNum;
        \\var f4_/*d5*/r8 =  f4.ofInterface;
        \\var f4_/*d6*/r12 = f4.ofIG4;
        \\var f4_/*d7*/r14 = f4.ofIG6;
        \\var f4_/*d8*/r18 = f4.ofC2;
        \\var f4_/*d9*/r20 = f4.ofC4;
        \\
        \\// T is Foo<number>
        \\var f5_/*e1*/r1  = f5.prim1;
        \\var f5_/*e2*/r2  = f5.prim2;
        \\var f5_/*e3*/r3  = f5.ofT;
        \\var f5_/*e4*/r5  = f5.ofFooNum;
        \\var f5_/*e5*/r8  = f5.ofInterface;
        \\var f5_/*e6*/r12 = f5.ofIG4;
        \\var f5_/*e7*/r14 = f5.ofIG6;
        \\var f5_/*e8*/r18 = f5.ofC2;
        \\var f5_/*e9*/r20 = f5.ofC4;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    try f.VerifyQuickInfoAt(undefined, "a1", "var f_r1: number", "");
    try f.VerifyQuickInfoAt(undefined, "a2", "var f_r2: string", "");
    try f.VerifyQuickInfoAt(undefined, "a3", "var f_r3: any", "");
    try f.VerifyQuickInfoAt(undefined, "a4", "var f_r5: Foo<number>", "");
    try f.VerifyQuickInfoAt(undefined, "a5", "var f_r8: I", "");
    try f.VerifyQuickInfoAt(undefined, "a6", "var f_r12: {\n    x: number;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "a7", "var f_r14: {\n    x: any;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "a8", "var f_r18: C<number>", "");
    try f.VerifyQuickInfoAt(undefined, "a9", "var f_r20: C<{\n    x: any;\n}>", "");
    try f.VerifyQuickInfoAt(undefined, "b1", "var f2_r1: number", "");
    try f.VerifyQuickInfoAt(undefined, "b2", "var f2_r2: string", "");
    try f.VerifyQuickInfoAt(undefined, "b3", "var f2_r3: number", "");
    try f.VerifyQuickInfoAt(undefined, "b4", "var f2_r5: Foo<number>", "");
    try f.VerifyQuickInfoAt(undefined, "b5", "var f2_r8: I", "");
    try f.VerifyQuickInfoAt(undefined, "b6", "var f2_r12: {\n    x: number;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "b7", "var f2_r14: {\n    x: number;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "b8", "var f2_r18: C<number>", "");
    try f.VerifyQuickInfoAt(undefined, "b9", "var f2_r20: C<{\n    x: number;\n}>", "");
    try f.VerifyQuickInfoAt(undefined, "c1", "var f3_r1: number", "");
    try f.VerifyQuickInfoAt(undefined, "c2", "var f3_r2: string", "");
    try f.VerifyQuickInfoAt(undefined, "c3", "var f3_r3: I", "");
    try f.VerifyQuickInfoAt(undefined, "c4", "var f3_r5: Foo<number>", "");
    try f.VerifyQuickInfoAt(undefined, "c5", "var f3_r8: I", "");
    try f.VerifyQuickInfoAt(undefined, "c6", "var f3_r12: {\n    x: number;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "c7", "var f3_r14: {\n    x: I;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "c8", "var f3_r18: C<number>", "");
    try f.VerifyQuickInfoAt(undefined, "c9", "var f3_r20: C<{\n    x: I;\n}>", "");
    try f.VerifyQuickInfoAt(undefined, "d1", "var f4_r1: number", "");
    try f.VerifyQuickInfoAt(undefined, "d2", "var f4_r2: string", "");
    try f.VerifyQuickInfoAt(undefined, "d3", "var f4_r3: {\n    x: number;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "d4", "var f4_r5: Foo<number>", "");
    try f.VerifyQuickInfoAt(undefined, "d5", "var f4_r8: I", "");
    try f.VerifyQuickInfoAt(undefined, "d6", "var f4_r12: {\n    x: number;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "d7", "var f4_r14: {\n    x: {\n        x: number;\n    };\n}", "");
    try f.VerifyQuickInfoAt(undefined, "d8", "var f4_r18: C<number>", "");
    try f.VerifyQuickInfoAt(undefined, "d9", "var f4_r20: C<{\n    x: {\n        x: number;\n    };\n}>", "");
    try f.VerifyQuickInfoAt(undefined, "e1", "var f5_r1: number", "");
    try f.VerifyQuickInfoAt(undefined, "e2", "var f5_r2: string", "");
    try f.VerifyQuickInfoAt(undefined, "e3", "var f5_r3: Foo<number>", "");
    try f.VerifyQuickInfoAt(undefined, "e4", "var f5_r5: Foo<number>", "");
    try f.VerifyQuickInfoAt(undefined, "e5", "var f5_r8: I", "");
    try f.VerifyQuickInfoAt(undefined, "e6", "var f5_r12: {\n    x: number;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "e7", "var f5_r14: {\n    x: Foo<number>;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "e8", "var f5_r18: C<number>", "");
    try f.VerifyQuickInfoAt(undefined, "e9", "var f5_r20: C<{\n    x: Foo<number>;\n}>", "");
}

test "TestReferencesBloomFilters2" {
    const content =
        \\// @Filename: declaration.ts
        \\var container = { /*1*/42: 1 };
        \\// @Filename: expression.ts
        \\function blah() { return (container[42]) === 2;  };
        \\// @Filename: stringIndexer.ts
        \\function blah2() { container["42"] };
        \\// @Filename: redeclaration.ts
        \\container = { "42" : 18 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFormatIfTryCatchBlocks" {
    const content =
        \\try {
        \\}
        \\catch {
        \\}
        \\
        \\try {
        \\}
        \\catch (e) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.GetOptions();
    // f.Configure(undefined, opts187);
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "try\n{\n}\ncatch\n{\n}\n\ntry\n{\n}\ncatch (e)\n{\n}");
}

test "TestGoToDefinitionSignatureAlias_require" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\module.exports = function /*f*/f() {}
        \\// @Filename: /b.js
        \\const f = require("./a");
        \\[|/*use*/f|]();
        \\// @Filename: /bar.ts
        \\import f = require("./a");
        \\[|/*useTs*/f|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "use", "useTs");
}

test "TestQuickInfoCloduleWithRecursiveReference" {
    const content =
        \\namespace M {
        \\    export class C {
        \\        foo() { }
        \\    }
        \\    export namespace C {
        \\    export var /**/C = M.C
        \\  }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var M.C.C: typeof M.C", "");
    try f.VerifyNoErrors(undefined);
}

test "TestImportStatementCompletions_esModuleInterop1" {
    const content =
        \\// @esModuleInterop: false
        \\// @allowSyntheticDefaultImports: false
        \\// @module: commonjs
        \\// @Filename: /mod.ts
        \\const foo = 0;
        \\export = foo;
        \\// @Filename: /importExportEquals.ts
        \\[|import f/**/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 &.{
//                     .Label =      "foo",
//                     .InsertText = undefined("import foo$1 = require(\"./mod\");"),
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "./mod",
//                         },
//                     },
//                     .InsertTextFormat = undefined(lsproto.InsertTextFormatSnippet),
//                     .TextEdit = &.{
//                         .TextEdit = &.{
//                             .NewText = "foo",
//                             .Range =   f.Ranges()[0].LSRange,
//                         },
//                     },
//                 },
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

