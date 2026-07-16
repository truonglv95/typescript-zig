const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListsStringLiteralTypeAsIndexedAccessTypeObject" {
    const content =
        \\let firstCase: "a/*case_1*/"["foo"]
        \\let secondCase: "b/*case_2*/"["bar"]
        \\let thirdCase: "c/*case_3*/"["baz"]
        \\let fourthCase: "en/*case_4*/"["qux"]
        \\interface Foo {
        \\ bar: string;
        \\ qux: string;
        \\}
        \\let fifthCase: Foo["b/*case_5*/"]
        \\let sixthCase: Foo["qu/*case_6*/"]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, &.{"case_1", "case_2", "case_3", "case_4"}, null);
    // f.VerifyCompletions(undefined, "case_5", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "bar",
//                 },
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "case_6", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 &.{
//                     .Label = "qux",
//                 },
//             },
//         },
//     });
}

test "TestAutoImportPackageJsonImportsPattern_ts_ts" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*.ts": "./src/*.ts"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\something/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"#something.ts"}, null );
}

test "TestOrganizeImportsReactJsxDev" {
    const content =
        \\// @allowSyntheticDefaultImports: true
        \\// @moduleResolution: bundler
        \\// @noUnusedLocals: true
        \\// @target: es2018
        \\// @jsx: react-jsxdev
        \\// @filename: test.tsx
        \\import React from 'react';
        \\export default () => <div></div>
        \\// @filename: node_modules/react/package.json
        \\{
        \\    "name": "react",
        \\    "types": "index.d.ts"
        \\}
        \\// @filename: node_modules/react/index.d.ts
        \\export = React;
        \\declare namespace JSX {
        \\    interface IntrinsicElements { [x: string]: any; }
        \\}
        \\declare namespace React {}
        \\// @filename: node_modules/react/jsx-runtime.d.ts
        \\import './';
        \\// @filename: node_modules/react/jsx-dev-runtime.d.ts
        \\import './';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "test.tsx");
    // try f.VerifyOrganizeImports(undefined,
//         "export default () => <div></div>",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestTsxGoToDefinitionUnionElementType2" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\class RC1 extends React.Component<{}, {}> {
        \\    render() {
        \\        return null;
        \\    }
        \\}
        \\class RC2 extends React.Component<{}, {}> {
        \\    render() {
        \\        return null;
        \\    }
        \\    private method() { }
        \\}
        \\var /*pt1*/RCComp = RC1 || RC2;
        \\<[|RC/*one*/Comp|] />
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "one");
}

test "TestSemanticClassificationUninstantiatedModuleWithVariableOfSameName1" {
    const content =
        \\declare module /*0*/M {
        \\    interface /*1*/I {
        \\
        \\    }
        \\}
        \\
        \\var M = { I: 10 };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifySemanticTokens(undefined, &.{
//         .{.Type = "variable", .Text = "M"},
//         .{.Type = "interface.declaration", .Text = "I"},
//         .{.Type = "variable.declaration", .Text = "M"},
//         .{.Type = "property.declaration", .Text = "I"},
//     });
}

test "TestCodeFixInferFromUsageCallbackParameter6" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @noImplicitAny: false
        \\// @filename: /foo.js
        \\const foo = [(/** @type {number} */ x) => x + 1];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestCompletionListAfterRegularExpressionLiteral04" {
    const content =
        \\let v = 100;
        \\let x = /absidey/ /**/
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
//                 "v",
//             },
//         },
//     });
}

test "TestImportCompletions_importsMap1" {
    const content =
        \\// @Filename: /home/src/workspaces/project/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "nodenext",
        \\    "lib": ["es5"],
        \\    "rootDir": "src",
        \\    "outDir": "dist"
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/package.json
        \\{
        \\  "type": "module",
        \\  "imports": {
        \\    "#is-browser": {
        \\      "browser": "./dist/env/browser.js",
        \\      "default": "./dist/env/node.js"
        \\    }
        \\  }
        \\}
        \\// @Filename: /home/src/workspaces/project/src/env/browser.ts
        \\export const isBrowser = true;
        \\// @Filename: /home/src/workspaces/project/src/env/node.ts
        \\export const isBrowser = false;
        \\// @Filename: /home/src/workspaces/project/src/a.ts
        \\import {} from "/*1*/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "#is-browser",
//             },
//         },
//     });
}

test "TestDocCommentTemplateFunctionWithParameters_js" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\/*0*/
        \\function f(a, ...b): boolean {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyJSDocCompletion(undefined, "0", 7, "/**\n * \n * @param {any} a\n * @param {...any} b\n */", null);
}

test "TestImportNameCodeFix_shorthandPropertyAssignment1" {
    const content =
        \\// @Filename: /a.ts
        \\export const a = 1;
        \\// @Filename: /b.ts
        \\const b = { /**/a };
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { a } from \"./a\";\n\nconst b = { a };",
    }, null );
}

test "TestGetOccurrencesLoopBreakContinue4" {
    const content =
        \\var arr = [1, 2, 3, 4];
        \\label1: for (var n in arr) {
        \\    break;
        \\    continue;
        \\    break label1;
        \\    continue label1;
        \\
        \\    label2: for (var i = 0; i < arr[n]; i++) {
        \\        break label1;
        \\        continue label1;
        \\
        \\        break;
        \\        continue;
        \\        break label2;
        \\        continue label2;
        \\
        \\        function foo() {
        \\            label3: while (true) {
        \\                break;
        \\                continue;
        \\                break label3;
        \\                continue label3;
        \\
        \\                // these cross function boundaries
        \\                break label1;
        \\                continue label1;
        \\                break label2;
        \\                continue label2;
        \\
        \\                label4: [|do|] {
        \\                    [|break|];
        \\                    [|continue|];
        \\                    [|break|] label4;
        \\                    [|continue|] label4;
        \\
        \\                    break label3;
        \\                    continue label3;
        \\
        \\                    switch (10) {
        \\                        case 1:
        \\                        case 2:
        \\                            break;
        \\                            [|break|] label4;
        \\                        default:
        \\                            [|continue|];
        \\                    }
        \\
        \\                    // these cross function boundaries
        \\                    break label1;
        \\                    continue label1;
        \\                    break label2;
        \\                    continue label2;
        \\                    () => { break; }
        \\                } [|wh/**/ile|] (true)
        \\            }
        \\        }
        \\    }
        \\}
        \\
        \\label5: while (true) break label5;
        \\
        \\label7: while (true) continue label5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
}

test "TestImportCompletionsPackageJsonImportsPattern_js" {
    const content =
        \\// @module: node18
        \\// @Filename: /package.json
        \\{
        \\  "imports": {
        \\    "#*": "./src/*.js"
        \\  }
        \\}
        \\// @Filename: /src/something.ts
        \\export function something(name: string): any;
        \\// @Filename: /a.ts
        \\import {} from "/*1*/";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCompletions(undefined, &.{"1"}, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &&.{},
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = &.{
//                 "#something",
//             },
//         },
//     });
}

test "TestFunctionTypePredicateFormatting" {
    const content =
        \\/**/function bar(a: A):     a        is       B    {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentLineContent(undefined, "function bar(a: A): a is B { }");
}

test "TestFindReferencesBindingPatternInJsdocNoCrash1" {
    const content =
        \\// @moduleResolution: bundler
        \\// @Filename: node_modules/use-query/package.json
        \\{
        \\  "name": "use-query",
        \\  "types": "index.d.ts"
        \\}
        \\// @Filename: node_modules/use-query/index.d.ts
        \\declare function useQuery(): {
        \\  data: string[];
        \\};
        \\// @Filename: node_modules/other/package.json
        \\{
        \\  "name": "other",
        \\  "types": "index.d.ts"
        \\}
        \\// @Filename: node_modules/other/index.d.ts
        \\interface BottomSheetModalProps {
        \\  /**
        \\   * A scrollable node or normal view.
        \\   * @type {({ data: any }?) => any}
        \\   */
        \\  children: ({ data: any }?) => any;
        \\}
        \\// @Filename: src/index.ts
        \\import { useQuery } from "use-query";
        \\const { /*1*/data } = useQuery();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestFindAllRefsForDefaultExport09" {
    const content =
        \\// @filename: /tsconfig.json
        \\{
        \\    "compilerOptions": {
        \\        "target": "esnext",
        \\        "strict": true,
        \\        "outDir": "./out",
        \\        "allowSyntheticDefaultImports": true
        \\    }
        \\}
        \\// @filename: /a.js
        \\module.exports = [];
        \\// @filename: /b.js
        \\module.exports = 1;
        \\// @filename: /c.ts
        \\export = [];
        \\// @filename: /d.ts
        \\export = 1;
        \\// @filename: /foo.ts
        \\import * as /*0*/a from "./a.js"
        \\import /*1*/aDefault from "./a.js"
        \\import * as /*2*/b from "./b.js"
        \\import /*3*/bDefault from "./b.js"
        \\
        \\import * as /*4*/c from "./c"
        \\import /*5*/cDefault from "./c"
        \\import * as /*6*/d from "./d"
        \\import /*7*/dDefault from "./d"
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "0", "1", "2", "3", "4", "5", "6", "7");
}

test "TestTsxRename1" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\        [|[|{| "contextRangeIndex": 0 |}div|]: {
        \\            name?: string;
        \\            isOpen?: boolean;
        \\        };|]
        \\        span: { n: string; };
        \\    }
        \\}
        \\var x = [|<[|{| "contextRangeIndex": 2 |}div|] />|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "div");
}

test "TestJavascriptModules22" {
    const content =
        \\// @allowJs: true
        \\// @module: commonjs
        \\// @allowSyntheticDefaultImports: false
        \\// @esModuleInterop: false
        \\// @Filename: mod.js
        \\function foo() { return {a: "hello, world"}; }
        \\module.exports = foo();
        \\// @Filename: mod2.js
        \\var x = {name: 'test'};
        \\(function createExport(obj){
        \\    module.exports = {
        \\        "default": x,
        \\        "sausages": {eggs: 2}
        \\    };
        \\})();
        \\// @Filename: app.js
        \\import {a} from "./mod"
        \\import def, {sausages} from "./mod2"
        \\a./**/
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
//                 "toString",
//             },
//         },
//     });
    _ = f.Backspace(undefined, 2);
    _ = f.Insert(undefined, "def.");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "name",
//             },
//         },
//     });
    _ = f.Insert(undefined, "name;\nsausages.");
    // f.VerifyCompletions(undefined, null, &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Includes = &.{
//                 "eggs",
//             },
//         },
//     });
    _ = f.Insert(undefined, "eggs;");
    try f.VerifyNoErrors(undefined);
}

test "TestSignatureHelpExpandedRestTuples" {
    const content =
        \\export function complex(item: string, another: string, ...rest: [] | [settings: object, errorHandler: (err: Error) => void] | [errorHandler: (err: Error) => void, ...mixins: object[]]) {
        \\    
        \\}
        \\
        \\complex(/*1*/);
        \\complex("ok", "ok", /*2*/);
        \\complex("ok", "ok", e => void e, {}, /*3*/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "complex(item: string, another: string): void", .ParameterCount = 2, .ParameterName = "item", .ParameterSpan = "item: string", .OverloadsCount = 3, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "2");
    // try f.VerifySignatureHelp(undefined, .{.Text = "complex(item: string, another: string, settings: object, errorHandler: (err: Error) => void): void", .ParameterCount = 4, .ParameterName = "settings", .ParameterSpan = "settings: object", .OverloadsCount = 3, .IsVariadic = false, .IsVariadicSet = true});
    _ = f.GoToMarker(undefined, "3");
    // try f.VerifySignatureHelp(undefined, .{.Text = "complex(item: string, another: string, errorHandler: (err: Error) => void, ...mixins: object[]): void", .OverloadsCount = 3, .IsVariadic = true, .IsVariadicSet = true});
}

test "TestCodeFixClassImplementClassMultipleSignatures1" {
    const content =
        \\class A {
        \\    method(a: number, b: string): boolean;
        \\    method(a: string | number, b?: string | number): boolean | Function { return a + b as any; }
        \\}
        \\class C implements A {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'A'",
        .NewFileContent = "class A {\n    method(a: number, b: string): boolean;\n    method(a: string | number, b?: string | number): boolean | Function { return a + b as any; }\n}\nclass C implements A {\n    method(a: number, b: string): boolean;\n    method(a: string | number, b?: string | number): boolean | Function {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

test "TestCodeFixTopLevelForAwait_target_compatibleCompilerOptionsInTsConfig" {
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
    // try f.VerifyCodeFixNotAvailable(undefined);
}

test "TestCodeFixMissingTypeAnnotationOnExports56_toplevel_import" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\// @Filename: /person-code.ts
        \\export interface Person { x: string; }
        \\export function getPerson() : Person {
        \\  return null!
        \\}
        \\// @Filename: /code.ts
        \\import { getPerson } from "./person-code";
        \\export function wrapPerson() {
        \\  return { person: getPerson() }
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/code.ts");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Add return type '{ person: Person; }'",
        .NewFileContent = "import { getPerson, Person } from \"./person-code\";\nexport function wrapPerson(): {\n    person: Person;\n} {\n  return { person: getPerson() }\n};",
        .Index = 0,
    });
}

test "TestGotoDefinitionLinkTag5" {
    const content =
        \\enum E {
        \\    /** {@link /*1*/[|B|]} */
        \\    A,
        \\    [|/*2*/B|]
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, false, "1");
}

test "TestToggleDuplicateFunctionDeclaration" {
    const content =
        \\class D { }
        \\D();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToBOF(undefined);
    _ = f.Insert(undefined, "declare function D();");
    _ = f.GoToBOF(undefined);
    _ = f.DeleteAtCaret(undefined, 21);
}

test "TestCompletionOfAwaitPromise2" {
    const content =
        \\interface Foo { foo: string }
        \\async function foo(x: Promise<Foo>) {
        \\   [|x./**/|]
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
//             .Includes = &.{
//                 "then",
//                 &.{
//                     .Label =      "foo",
//                     .InsertText = undefined("(await x).foo"),
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

test "TestSpaceAfterStatementConditions" {
    const content =
        \\let i = 0;
        \\
        \\if(i<0) ++i;
        \\if(i<0) --i;
        \\
        \\while(i<0) ++i;
        \\while(i<0) --i;
        \\
        \\do ++i;
        \\while(i<0)
        \\do --i;
        \\while(i<0)
        \\
        \\for(let prop in { foo: 1 }) ++i;
        \\for(let prop in { foo: 1 }) --i;
        \\
        \\for(let foo of [1, 2]) ++i;
        \\for(let foo of [1, 2]) --i;
        \\
        \\for(let j = 0; j < 10; j++) ++i;
        \\for(let j = 0; j < 10; j++) --i;
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "let i = 0;\n\nif (i < 0) ++i;\nif (i < 0) --i;\n\nwhile (i < 0) ++i;\nwhile (i < 0) --i;\n\ndo ++i;\nwhile (i < 0)\ndo --i;\nwhile (i < 0)\n\nfor (let prop in { foo: 1 }) ++i;\nfor (let prop in { foo: 1 }) --i;\n\nfor (let foo of [1, 2]) ++i;\nfor (let foo of [1, 2]) --i;\n\nfor (let j = 0; j < 10; j++) ++i;\nfor (let j = 0; j < 10; j++) --i;\n");
}

test "TestImportNameCodeFixDefaultExport6" {
    const content =
        \\// @Filename: /a.ts
        \\export default Math.foo;
        \\// @Filename: /index.ts
        \\a/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "a",
//         .Source =      "./a",
//         .Description = "Add import from \"./a\"",
//         .NewFileContent = undefined("import a from \"./a\";\n\na"),
//     });
}

test "TestCompletionListAtIdentifierDefinitionLocations_catch" {
    const content =
        \\var aa = 1;
        \\ try {} catch(/*catchVariable1*/
        \\ try {} catch(a/*catchVariable2*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, f.Markers(), null);
}

test "TestOrganizeImports21" {
    const content =
        \\// @filename: /a.ts
        \\export interface LocationDefinitions {}
        \\export interface PersonDefinitions {}
        \\// @filename: /b.ts
        \\export {
        \\    /** @deprecated Use LocationDefinitions instead */
        \\    LocationDefinitions as AddressDefinitions,
        \\    LocationDefinitions,
        \\    /** @deprecated Use PersonDefinitions instead */
        \\    PersonDefinitions as NameDefinitions,
        \\    PersonDefinitions,
        \\} from './a';
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // try f.VerifyOrganizeImports(undefined,
//         "export {\n    /** @deprecated Use LocationDefinitions instead */\n    LocationDefinitions as AddressDefinitions,\n    LocationDefinitions,\n    /** @deprecated Use PersonDefinitions instead */\n    PersonDefinitions as NameDefinitions,\n    PersonDefinitions\n} from './a';\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestCompletionTypeGuard" {
    const content =
        \\// @lib: es5
        \\const x = "str";
        \\function assert1(condition: any, msg?: string): /*1*/ ;
        \\function assert2(condition: any, msg?: string): /*2*/ { }
        \\function assert3(condition: any, msg?: string): /*3*/
        \\hi
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
//             .Exact = CompletionGlobalTypes,
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalTypes,
//         },
//     });
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Exact = CompletionGlobalTypes,
//         },
//     });
}

test "TestQuickInfoOnPropertyAccessInWriteLocation4" {
    const content =
        \\// @strict: true
        \\interface Serializer {
        \\  set value(v: string | number | boolean);
        \\  get value(): string;
        \\}
        \\declare let box: Serializer;
        \\box.value/*1*/ = true;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "(property) Serializer.value: string | number | boolean", "");
}

test "TestQuickinfoVerbosity2" {
    const content =
        \\type Str = string | {};
        \\type FooType = Str | number;
        \\type Sym = symbol | (() => void);
        \\type BarType = Sym | boolean;
        \\type BothType = FooType | BarType;
        \\const both/*b*/: BothType = 1;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"b" = .{0, 1, 2, 3}});
}

test "TestGetOutliningSpansForComments" {
    const content =
        \\// @lib: es5
        \\[|/*
        \\    Block comment at the beginning of the file before module:
        \\        line one of the comment
        \\        line two of the comment
        \\        line three
        \\        line four
        \\        line five
        \\*/|]
        \\declare module "m";
        \\[|// Single line comments at the start of the file
        \\// line 2
        \\// line 3
        \\// line 4|]
        \\declare module "n";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyOutliningSpans(undefined, lsproto.FoldingRangeKindComment);
}

test "TestImportNameCodeFixNewImportAllowSyntheticDefaultImports1" {
    const content =
        \\// @Module: system
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
        "import bar from \"./foo\";\n\nexport var x = 0;\nbar();",
    }, null );
}

test "TestQuickInfoLink11" {
    const content =
        \\/**
        \\ * {@link https://vscode.dev}
        \\ * [link text]{https://vscode.dev}
        \\ * {@link https://vscode.dev|link text}
        \\ * {@link https://vscode.dev link text}
        \\ */
        \\function f() {}
        \\
        \\/**/f();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

test "TestCodeFixClassImplementInterfaceAutoImports_typeOnly" {
    const content =
        \\// @module: esnext
        \\// @verbatimModuleSyntax: true
        \\// @Filename: types1.ts
        \\type A = {};
        \\export default A;
        \\// @Filename: types2.ts
        \\export type B = {};
        \\export type C = {};
        \\export type D<T> = {};
        \\// @Filename: interface.ts
        \\import type A from './types1';
        \\import type { B, C, D } from './types2';
        \\
        \\export interface Base {
        \\  a: A;
        \\  b<T extends B = B>(p1: C): D<C>;
        \\}
        \\// @Filename: index.ts
        \\import type { Base } from './interface';
        \\
        \\export class C implements Base {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "index.ts");
    try f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'Base'",
        .NewFileContent = "import type { Base } from './interface';\nimport type A from './types1';\nimport type { B, C, D } from './types2';\n\nexport class C implements Base {\n    a: A;\n    b<T extends B = B>(p1: C): D<C> {\n        throw new Error('Method not implemented.');\n    }\n}",
        .Index = 0,
    });
}

test "TestCompletionListInTypeLiteralInTypeParameter4" {
    const content =
        \\interface Foo {
        \\    one: string;
        \\    two: number;
        \\}
        \\
        \\interface Bar<T extends Foo> {
        \\    foo: T;
        \\}
        \\
        \\var foobar: Bar<{ one: string } & {/**/
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
//                 "two",
//             },
//         },
//     });
}

test "TestGoToDefinitionDynamicImport1" {
    const content =
        \\// @Filename: foo.ts
        \\/*Destination*/export function foo() { return "foo"; }
        \\import([|"./f/*1*/oo"|])
        \\var x = import([|"./fo/*2*/o"|])
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1", "2");
}

test "TestQuickInfoForSyntaxErrorNoError" {
    const content =
        \\namespace X {
        \\    export =
        \\}
        \\X.add/*1*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "any", "");
}

test "TestCompletionListForExportEquals2" {
    const content =
        \\// @Filename: /node_modules/foo/index.d.ts
        \\export = Foo;
        \\interface Foo { bar: number; }
        \\declare namespace Foo {
        \\    interface Static {}
        \\}
        \\// @Filename: /a.ts
        \\import { /**/ } from "foo";
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
//                 "Static",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestCompletionListAtEndOfWordInArrowFunction01" {
    const content =
        \\xyz => x/*1*/
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
//                 "xyz",
//             },
//         },
//     });
}

test "TestMemberOverloadEdits" {
    const content =
        \\namespace M {
        \\    export class A {
        \\        public m(n: number) {
        \\            return 0;
        \\        }
        \\        public n() {
        \\            return this.m(0);
        \\        }
        \\    }
        \\    export class B extends A { /*1*/ }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "public m(n: number) { return 0; }");
    try f.VerifyNoErrors(undefined);
}

test "TestFormattingNestedScopes" {
    const content =
        \\/*1*/        namespace      My.App      {
        \\/*2*/export      var appModule =      angular.module("app", [
        \\/*3*/            ]).config([() =>            {
        \\/*4*/                        configureStates
        \\/*5*/($stateProvider);
        \\/*6*/}]).run(My.App.setup);
        \\/*7*/      }
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyCurrentLineContent(undefined, "namespace My.App {");
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyCurrentLineContent(undefined, "    export var appModule = angular.module(\"app\", [");
    _ = f.GoToMarker(undefined, "3");
    try f.VerifyCurrentLineContent(undefined, "    ]).config([() => {");
    _ = f.GoToMarker(undefined, "4");
    try f.VerifyCurrentLineContent(undefined, "        configureStates");
    _ = f.GoToMarker(undefined, "5");
    try f.VerifyCurrentLineContent(undefined, "            ($stateProvider);");
    _ = f.GoToMarker(undefined, "6");
    try f.VerifyCurrentLineContent(undefined, "    }]).run(My.App.setup);");
    _ = f.GoToMarker(undefined, "7");
    try f.VerifyCurrentLineContent(undefined, "}");
}

test "TestDeclarationMapsGoToDefinitionRelativeSourceRoot" {
    const content =
        \\// @lib: es5
        \\// @Filename: index.ts
        \\export class Foo {
        \\    member: string;
        \\    /*2*/methodName(propName: SomeType): void {}
        \\    otherMethod() {
        \\        if (Math.random() > 0.5) {
        \\            return {x: 42};
        \\        }
        \\        return {y: "yes"};
        \\    }
        \\}
        \\
        \\export interface SomeType {
        \\    member: number;
        \\}
        \\// @Filename: out/indexdef.d.ts.map
        \\{"version":3,"file":"indexdef.d.ts","sourceRoot":"../","sources":["index.ts"],"names":[],"mappings":"AAAA;IACI,MAAM,EAAE,MAAM,CAAC;IACf,UAAU,CAAC,QAAQ,EAAE,QAAQ,GAAG,IAAI;IACpC,WAAW;;;;;;;CAMd;AAED,MAAM,WAAW,QAAQ;IACrB,MAAM,EAAE,MAAM,CAAC;CAClB"}
        \\// @Filename: out/indexdef.d.ts
        \\export declare class Foo {
        \\    member: string;
        \\    methodName(propName: SomeType): void;
        \\    otherMethod(): {
        \\        x: number;
        \\        y?: undefined;
        \\    } | {
        \\        y: string;
        \\        x?: undefined;
        \\    };
        \\}
        \\export interface SomeType {
        \\    member: number;
        \\}
        \\//# sourceMappingURL=out/indexdef.d.ts.map
        \\// @Filename: mymodule.ts
        \\import * as mod from "./out/indexdef";
        \\const instance = new mod.Foo();
        \\instance.[|/*1*/methodName|]({member: 12});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestCompletionListStringParenthesizedExpression" {
    const content =
        \\const foo = {
        \\    a: 1,
        \\    b: 1,
        \\    c: 1
        \\}
        \\const a = foo["[|/*1*/|]"];
        \\const b = foo[("[|/*2*/|]")];
        \\const c = foo[(("[|/*3*/|]"))];
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
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//                 &.{
//                     .Label = "c",
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
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//                 &.{
//                     .Label = "c",
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
//                     .Label = "a",
//                 },
//                 &.{
//                     .Label = "b",
//                 },
//                 &.{
//                     .Label = "c",
//                 },
//             },
//         },
//     });
}

test "TestPaste" {
    const content =
        \\fn(/**/);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.Paste(undefined, "x,y,z");
    try f.VerifyCurrentLineContent(undefined, "fn(x, y, z);");
}

test "TestRenameJsThisProperty01" {
    const content =
        \\// @allowJs: true
        \\// @Filename: a.js
        \\function bar() {
        \\    [|this.[|{| "contextRangeIndex": 0 |}x|] = 10;|]
        \\}
        \\var t = new bar();
        \\[|t.[|{| "contextRangeIndex": 2 |}x|] = 11;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineRenameAtRangesWithText(undefined, null , "x");
}

test "TestGoToTypeDefinitionEnumMembers" {
    const content =
        \\enum E {
        \\    value1,
        \\    /*definition*/value2
        \\}
        \\var x = E.value2;
        \\
        \\/*reference*/x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToTypeDefinition(undefined, "reference");
}

test "TestJsxGenericQuickInfo" {
    const content =
        \\//@Filename: file.tsx
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props }
        \\}
        \\interface PropsA<T> {
        \\    /** comments for A */
        \\    name: 'A',
        \\    items: T[];
        \\    renderItem: (item: T) => string;
        \\}
        \\interface PropsB<T> {
        \\    /** comments for B */
        \\    name: 'B',
        \\    items: T[];
        \\    renderItem: (item: T) => string;
        \\}
        \\class Component<T> {
        \\    constructor(props: PropsA<T> | PropsB<T>) {}
        \\    props: PropsA<T> | PropsB<T>;
        \\}   
        \\var b = new Component({items: [0, 1, 2], render/*0*/Item: it/*1*/em => item.toFixed(), name/*2*/: 'A',});
        \\var c = <Component items={[0, 1, 2]} render/*3*/Item={it/*4*/em => item.toFixed()} name/*5*/="A" />
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "0", "(property) PropsA<number>.renderItem: (item: number) => string", "");
    try f.VerifyQuickInfoAt(undefined, "1", "(parameter) item: number", "");
    try f.VerifyQuickInfoAt(undefined, "2", "(property) PropsA<T>.name: \"A\"", "comments for A");
    try f.VerifyQuickInfoAt(undefined, "3", "(property) PropsA<number>.renderItem: (item: number) => string", "");
    try f.VerifyQuickInfoAt(undefined, "4", "(parameter) item: number", "");
    try f.VerifyQuickInfoAt(undefined, "5", "(property) PropsA<T>.name: \"A\"", "comments for A");
}

test "TestCompletionsNewTarget" {
    const content =
        \\class C {
        \\    constructor() {
        \\        if (C === new./*1*/)
        \\    }
        \\}
        \\class D {
        \\    constructor() {
        \\        if (D === new.target./*2*/)
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
//             .Exact = &.{
//                 "target",
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
//                 "target",
//             },
//         },
//     });
}

test "TestQuickInfoDisplayPartsClassDefaultNamed" {
    const content =
        \\/*1*/export /*2*/default /*3*/class /*4*/C /*5*/ {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineHover(undefined);
}

