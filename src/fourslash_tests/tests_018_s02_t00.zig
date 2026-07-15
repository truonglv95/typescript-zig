const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGetOccurrencesExport1" {
    const content =
        \\namespace m {
        \\    [|export|] class C1 {
        \\        public pub1;
        \\        public pub2;
        \\        private priv1;
        \\        private priv2;
        \\        protected prot1;
        \\        protected prot2;
        \\
        \\        public public;
        \\        private private;
        \\        protected protected;
        \\
        \\        public constructor(public a, private b, protected c, public d, private e, protected f) {
        \\            this.public = 10;
        \\            this.private = 10;
        \\            this.protected = 10;
        \\        }
        \\
        \\        public get x() { return 10; }
        \\        public set x(value) { }
        \\
        \\        public static statPub;
        \\        private static statPriv;
        \\        protected static statProt;
        \\    }
        \\
        \\    [|export|] interface I1 {
        \\    }
        \\
        \\    [|export|] declare namespace ma.m1.m2.m3 {
        \\        interface I2 {
        \\        }
        \\    }
        \\
        \\    [|export|] namespace mb.m1.m2.m3 {
        \\        declare var foo;
        \\
        \\        export class C2 {
        \\            public pub1;
        \\            private priv1;
        \\            protected prot1;
        \\
        \\            protected constructor(public public, protected protected, private private) {
        \\            }
        \\        }
        \\    }
        \\
        \\    declare var ambientThing: number;
        \\    [|export|] var exportedThing = 10;
        \\    declare function foo(): string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestCompletionsOverridingMethod17" {
    const content =
        \\// @Filename: a.ts
        \\// @newline: LF
        \\interface Interface {
        \\    method(): void;
        \\}
        \\
        \\export class Class implements Interface {
        \\    property = "yadda";
        \\
        \\    /**/
        \\}
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
//             .Includes = &.{
//                 &.{
//                     .Label =      "method",
//                     .InsertText = undefined("method(): void {\n}"),
//                     .FilterText = undefined("method"),
//                     .SortText =   undefined(string(ls.SortTextLocationPriority)),
//                 },
//             },
//         },
//     });
}

test "TestImportNameCodeFix_HeaderComment1" {
    const content =
        \\// @Filename: /a.ts
        \\export const foo = 0;
        \\// @Filename: /b.ts
        \\export const bar = 0;
        \\// @Filename: /c.ts
        \\/*--------------------
        \\ *  Copyright Header
        \\ *--------------------*/
        \\
        \\import { bar } from "./b";
        \\foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/c.ts");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "/*--------------------\n *  Copyright Header\n *--------------------*/\n\nimport { foo } from \"./a\";\nimport { bar } from \"./b\";\nfoo;",
    }, null );
}

test "TestImportNameCodeFix_importType8" {
    const content =
        \\// @module: es2015
        \\// @verbatimModuleSyntax: true
        \\// @Filename: /exports.ts
        \\export interface SomeInterface {}
        \\export class SomePig {}
        \\// @Filename: /a.ts
        \\import type { SomeInterface, SomePig } from "./exports.js";
        \\new SomePig/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import { SomePig, type SomeInterface } from \"./exports.js\";\nnew SomePig",
    }, null );
}

test "TestCompletionsLiteralFromInferenceWithinInferredType1" {
    const content =
        \\// @stableTypeOrdering: true
        \\// @Filename: /a.tsx
        \\declare function test<T>(a: {
        \\  [K in keyof T]: {
        \\    b?: keyof T;
        \\  };
        \\}): void;
        \\
        \\test({
        \\  foo: {},
        \\  bar: {
        \\    b: "/*ts*/",
        \\  },
        \\});
        \\
        \\test({
        \\  foo: {},
        \\  bar: {
        \\    b: /*ts2*/,
        \\  },
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"ts"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "bar",
//                 "foo",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, &.{"ts2"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "\"bar\"",
//                 "\"foo\"",
//             },
//         },
//     });
}

test "TestQuickInfoOnMethodOfImportEquals" {
    const content =
        \\// @Filename: /a.d.ts
        \\declare class C<T> {
        \\    m(): void;
        \\}
        \\export = C;
        \\// @Filename: /b.ts
        \\import C = require("./a");
        \\declare var x: C<number>;
        \\x./**/m;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "", "(method) C<number>.m(): void", "");
}

test "TestAddInterfaceToNotSatisfyConstraint" {
    const content =
        \\interface A {
        \\    a: number;
        \\}
        \\/**/
        \\interface C<T extends A> {
        \\    x: T;
        \\}
        \\
        \\var v2: C<B>; // should not work
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Insert(undefined, "interface B { b: string; }");
}

test "TestCompletionListInUnclosedTemplate02" {
    const content =
        \\var x;
        \\var y = (p) => 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, "1", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "p",
//                 "x",
//             },
//         },
//     });
}

test "TestImportNameCodeFix_jsx2" {
    const content =
        \\// @lib: es5
        \\// @jsx: react
        \\// @module: esnext
        \\// @esModuleInterop: true
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/react/index.d.ts
        \\export = React;
        \\export as namespace React;
        \\declare namespace React {
        \\    class Component {}
        \\}
        \\// @Filename: /node_modules/react-native/index.d.ts
        \\import * as React from "react";
        \\export class Text extends React.Component {};
        \\// @Filename: /a.tsx
        \\import React from "react";
        \\<[|Text|]></Text>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add import from \"react-native\"",
        .NewFileContent = "import React from \"react\";\nimport { Text } from \"react-native\";\n<Text></Text>;",
        .Index = 0,
    });
}

test "TestImportNameCodeFixUMDGlobalReact1" {
    const content =
        \\// @jsx: react
        \\// @allowSyntheticDefaultImports: false
        \\// @module: es2015
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/@types/react/index.d.ts
        \\export = React;
        \\export as namespace React;
        \\declare namespace React {
        \\    export class Component { render(): JSX.Element | null; }
        \\}
        \\declare global {
        \\    namespace JSX {
        \\        interface Element {}
        \\    }
        \\}
        \\// @Filename: /a.tsx
        \\[|import { Component } from "react";
        \\export class MyMap extends Component { }
        \\<MyMap></MyMap>;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.tsx");
    _ = f.VerifyImportFixAtPosition(undefined, &.{
        "import * as React from \"react\";\nimport { Component } from \"react\";\nexport class MyMap extends Component { }\n<MyMap></MyMap>;",
    }, null );
}

