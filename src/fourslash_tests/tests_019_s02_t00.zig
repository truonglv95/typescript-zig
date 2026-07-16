const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGoToSource6_sameAsGoToDef2" {
    const content =
        \\// @lib: es5
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/package.json
        \\{ "name": "foo", "version": "1.2.3", "typesVersions": { "*": { "*": ["./types/*"] } } }
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/src/a.ts
        \\export const /*end*/a = 'a';
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/types/a.d.ts
        \\export declare const a: string;
        \\//# sourceMappingURL=a.d.ts.map
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/types/a.d.ts.map
        \\{"version":3,"file":"a.d.ts","sourceRoot":"","sources":["../src/a.ts"],"names":[],"mappings":"AAAA,eAAO,MAAM,EAAE,OAAO,CAAC;;AACvB,wBAAsB"}
        \\// @Filename: /home/src/workspaces/project/node_modules/foo/dist/a.js
        \\export const a = 'a';
        \\// @Filename: /home/src/workspaces/project/b.ts
        \\import { a } from 'foo/a';
        \\[|a/*start*/|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // try f.VerifyBaselineGoToSourceDefinition(undefined, "start");
    // try f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestDerivedTypeIndexerWithGenericConstraints" {
    const content =
        \\// @strict: false
        \\class CollectionItem {
        \\    x: number;
        \\}
        \\class Entity extends CollectionItem {
        \\    y: number;
        \\}
        \\class BaseCollection<TItem extends CollectionItem>  {
        \\    _itemsByKey: { [key: string]: TItem; };
        \\}
        \\class DbSet<TEntity extends Entity> extends BaseCollection<TEntity> { // error
        \\    _itemsByKey: { [key: string]: TEntity; } = {};
        \\}
        \\var a: BaseCollection<CollectionItem>;
        \\var /**/r = a._itemsByKey['x']; // should just say CollectionItem not TItem extends CollectionItem
        \\var result = r.x;
        \\a = new DbSet<Entity>();
        \\var r2 = a._itemsByKey['x'];
        \\var result2 = r2.x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "var r: CollectionItem", "");
    try f.VerifyNoErrors(undefined);
}

test "TestQuickinfoVerbosityIndexSignature" {
    const content =
        \\type Key = string | number;
        \\interface Apple {
        \\    banana: number;
        \\}
        \\interface Foo {
        \\    [a/*a*/: Key]: Apple;
        \\}
        \\const f/*f*/: Foo = {};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineHoverWithVerbosity(undefined, .{.@"a" = .{0, 1}, .@"f" = .{0, 1, 2}});
}

test "TestSmartSelection_JSDocTags5" {
    const content =
        \\/**
        \\ * @callback Foo
        \\ * @param {string} data
        \\ * @param {/**/number} [index] - comment
        \\ * @return {boolean}
        \\ */
        \\
        \\/** @type {Foo} */
        \\const foo = s => !(s.length % 2);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineSelectionRanges(undefined);
}

test "TestOrganizeImports15" {
    const content =
        \\// @filename: /a.ts
        \\export const foo = 1;
        \\// @filename: /b.ts
        \\/**
        \\ * Module doc comment
        \\ *
        \\ * @module
        \\ */
        \\
        \\// comment 1
        \\
        \\// comment 2
        \\
        \\import { foo } from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/b.ts");
    // try f.VerifyOrganizeImports(undefined,
//         "/**\n * Module doc comment\n *\n * @module\n */\n\n// comment 1\n\n// comment 2\n\n",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestCompletionsGenericIndexedAccess2" {
    const content =
        \\export type GetMethodsForType<T, G extends string> = { [K in keyof T]:
        \\  T[K] extends () => any ? { name: K, group: G, } : T[K] extends (s: infer U) => any ? { name: K, group: G, payload: U } : never }[keyof T];
        \\
        \\
        \\class Sample {
        \\  count = 0;
        \\  books: { name: string, year: number }[] = []
        \\  increment() {
        \\      this.count++
        \\      this.count++
        \\  }
        \\
        \\  addBook(book: Sample["books"][0]) {
        \\      this.books.push(book)
        \\  }
        \\}
        \\export declare function testIt<T, G extends string>(): (input: any, method: GetMethodsForType<T, G>) => any
        \\
        \\
        \\const t = testIt<Sample, "Sample">()
        \\
        \\const i = t(null, { name: "addBook", group: "Sample", payload: { /**/ } })
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
//                     .Label = "name",
//                 },
//                 &.{
//                     .Label = "year",
//                 },
//             },
//         },
//     });
}

test "TestCompletionListOnVarBetweenModules" {
    const content =
        \\namespace M1 {
        \\    export class C1 {
        \\    }
        \\    export class C2 {
        \\    }
        \\}
        \\var x: M1./**/
        \\namespace M2 {
        \\    export class Test3 {
        \\    }
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
//                 "C1",
//                 "C2",
//             },
//         },
//     });
}

test "TestFindAllRefsObjectBindingElementPropertyName02" {
    const content =
        \\interface I {
        \\    /*1*/property1: number;
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\/*2*/var { /*3*/property1: {} } = foo;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestNavigationBarItemsSymbols2" {
    const content =
        \\interface I {
        \\    [Symbol.isRegExp]: string;
        \\    [Symbol.iterator](): string;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestFormatTsxClosingAfterJsxText" {
    const content =
        \\// @Filename: foo.tsx
        \\
        \\const a = (
        \\    <div>
        \\        text
        \\               </div>
        \\)
        \\const b = (
        \\    <div>
        \\        text
        \\      twice
        \\               </div>
        \\)
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    try f.VerifyCurrentFileContent(undefined, "\nconst a = (\n    <div>\n        text\n    </div>\n)\nconst b = (\n    <div>\n        text\n        twice\n    </div>\n)\n");
}

