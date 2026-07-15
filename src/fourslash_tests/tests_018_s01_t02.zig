const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionsImport_promoteTypeOnly2" {
    const content =
        \\// @module: es2015
        \\// @Filename: /exports.ts
        \\export interface SomeInterface {}
        \\// @Filename: /a.ts
        \\import type { SomeInterface } from "./exports.js";
        \\const SomeInterface = {};
        \\SomeI/**/
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
//                     .Label = "SomeInterface",
//                 },
//             },
//         },
//     });
}

test "TestFormatTsxMultilineAttributeString" {
    const content =
        \\// @Filename: foo.tsx
        \\(
        \\    <input
        \\        value="x
        \\        x"
        \\    />
        \\);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "(\n    <input\n        value=\"x\n        x\"\n    />\n);");
}

test "TestGetEditsForFileRename_keepFileExtensions" {
    const content =
        \\// @Filename: /tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "Node16",
        \\    "rootDirs": ["src"]
        \\  }
        \\}
        \\// @Filename: /src/person.ts
        \\export const name = 0;
        \\// @Filename: /src/index.ts
        \\import {name} from "./person.js";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyWillRenameFilesEdits(undefined, "/src/person.ts", "/src/vip.ts", .{
//         .@"/src/index.ts" = "import {name} from \"./vip.js\";",
//     }, null );
}

test "TestJsdocTypedefTag" {
    const content =
        \\// @lib: es5
        \\// @allowNonTsExtensions: true
        \\// @Filename: jsdocCompletion_typedef.js
        \\/** @typedef {(string | number)} NumberLike */
        \\
        \\/**
        \\ * @typedef Animal - think Giraffes
        \\ * @type {Object}
        \\ * @property {string} animalName
        \\ * @property {number} animalAge
        \\ */
        \\
        \\/**
        \\ * @typedef {Object} Person
        \\ * @property {string} personName
        \\ * @property {number} personAge
        \\ */
        \\
        \\/**
        \\ * @typedef {Object}
        \\ * @property {string} catName
        \\ * @property {number} catAge
        \\ */
        \\var Cat;
        \\
        \\/** @typedef {{ dogName: string, dogAge: number }} */
        \\var Dog;
        \\
        \\/** @type {NumberLike} */
        \\var numberLike; numberLike./*numberLike*/
        \\
        \\/** @type {Person} */
        \\var p;p./*person*/;
        \\p.personName./*personName*/;
        \\p.personAge./*personAge*/;
        \\
        \\/** @type {/*AnimalType*/Animal} */
        \\var a;a./*animal*/;
        \\a.animalName./*animalName*/;
        \\a.animalAge./*animalAge*/;
        \\
        \\/** @type {Cat} */
        \\var c;c./*cat*/;
        \\c.catName./*catName*/;
        \\c.catAge./*catAge*/;
        \\
        \\/** @type {Dog} */
        \\var d;d./*dog*/;
        \\d.dogName./*dogName*/;
        \\d.dogAge./*dogAge*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, "numberLike", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "charAt",
//                 "toExponential",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "person", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "personName",
//                 "personAge",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "personName", &.{
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
    // f.VerifyCompletions(undefined, "personAge", &.{
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
    // f.VerifyCompletions(undefined, "animal", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "animalName",
//                 "animalAge",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "animalName", &.{
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
    // f.VerifyCompletions(undefined, "animalAge", &.{
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
    // f.VerifyCompletions(undefined, "dog", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "dogName",
//                 "dogAge",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "dogName", &.{
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
    // f.VerifyCompletions(undefined, "dogAge", &.{
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
    // f.VerifyCompletions(undefined, "cat", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "catName",
//                 "catAge",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "catName", &.{
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
    // f.VerifyCompletions(undefined, "catAge", &.{
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
    // f.VerifyQuickInfoAt(undefined, "AnimalType", "type Animal = {\n    animalName: string;\n    animalAge: number;\n}", "- think Giraffes");
}

test "TestAugmentedTypesClass1" {
    const content =
        \\class c5b { public foo() { } }
        \\namespace c5b { export var y = 2; } // should be ok
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
//             .Includes = &.{
//                 &.{
//                     .Label =  "prototype",
//                     .Detail = undefined("(property) c5b.prototype: c5b"),
//                 },
//             },
//         },
//     });
    _ = f.Insert(undefined, "y;");
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label =  "foo",
//                     .Detail = undefined("(method) c5b.foo(): void"),
//                 },
//             },
//         },
//     });
}

test "TestFindAllReferencesOfConstructor" {
    const content =
        \\// @Filename: a.ts
        \\export class C {
        \\    /*0*/constructor(n: number);
        \\    /*1*/constructor();
        \\    /*2*/constructor(n?: number){}
        \\    static f() {
        \\        this.f();
        \\        new this();
        \\    }
        \\}
        \\new C();
        \\const D = C;
        \\new D();
        \\// @Filename: b.ts
        \\import { C } from "./a";
        \\new C();
        \\// @Filename: c.ts
        \\import { C } from "./a";
        \\class D extends C {
        \\    constructor() {
        \\        super();
        \\        super.method();
        \\    }
        \\    method() { super(); }
        \\}
        \\class E implements C {
        \\    constructor() { super(); }
        \\}
        \\// @Filename: d.ts
        \\import * as a from "./a";
        \\new a.C();
        \\class d extends a.C { constructor() { super(); }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2");
}

test "TestFindAllRefs_importType_named" {
    const content =
        \\// @Filename: /a.ts
        \\/*1*/export type /*2*/T = number;
        \\/*3*/export type /*4*/U = string;
        \\// @Filename: /b.ts
        \\const x: import("./a")./*5*/T = 0;
        \\const x: import("./a")./*6*/U = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6");
}

test "TestAutoImportBundlerBlockRelativeNodeModulesPaths" {
    const content =
        \\// @module: esnext
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/dep/package.json
        \\{
        \\  "name": "dep",
        \\  "version": "1.0.0",
        \\  "exports": "./dist/index.js"
        \\}
        \\// @Filename: /node_modules/dep/dist/utils.d.ts
        \\export const util: () => void;
        \\// @Filename: /node_modules/dep/dist/index.d.ts
        \\export * from "./utils";
        \\// @Filename: /index.ts
        \\util/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"dep"}, null );
}

test "TestOrganizeImports1" {
    const content =
        \\import {
        \\    d, d as D,
        \\    c,
        \\    c as C, b,
        \\    b as B, a
        \\} from './foo';
        \\import {
        \\    h, h as H,
        \\    g,
        \\    g as G, f,
        \\    f as F, e
        \\} from './foo';
        \\
        \\console.log(a, B, b, c, C, d, D);
        \\console.log(e, f, F, g, G, H, h);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    a,\n    b,\n    b as B,\n    c,\n    c as C,\n    d, d as D,\n    e,\n    f,\n    f as F,\n    g,\n    g as G,\n    h, h as H\n} from './foo';\n\nconsole.log(a, B, b, c, C, d, D);\nconsole.log(e, f, F, g, G, H, h);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSTrue,
//         },
//     );
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    b as B,\n    c as C,\n    d as D,\n    f as F,\n    g as G,\n    h as H,\n    a,\n    b,\n    c,\n    d,\n    e,\n    f,\n    g,\n    h\n} from './foo';\n\nconsole.log(a, B, b, c, C, d, D);\nconsole.log(e, f, F, g, G, H, h);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//         },
//     );
}

test "TestCodeFixAddOptionalParam14" {
    const content =
        \\function f(a: string): string;
        \\function f(a: string, b: number): string;
        \\function f(a: string, b?: number): string {
        \\    return "";
        \\}
        \\f("", "", 1);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined, "addOptionalParam");
}

