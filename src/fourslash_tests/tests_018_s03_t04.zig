const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestGotoDefinitionConstructorFunction" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @noEmit: true
        \\// @filename: gotoDefinitionConstructorFunction.js
        \\function /*end*/StringStreamm() {
        \\}
        \\StringStreamm.prototype = {
        \\};
        \\
        \\function runMode () {
        \\new [|/*start*/StringStreamm|]()
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestCompletionListAtEndOfWordInArrowFunction02" {
    const content =
        \\(d, defaultIsAnInvalidParameterName) => d/*1*/
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
//                 "d",
//                 "defaultIsAnInvalidParameterName",
//                 &.{
//                     .Label =    "default",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestSyntheticImportFromBabelGeneratedFile1" {
    const content =
        \\// @allowJs: true
        \\// @allowSyntheticDefaultImports: true
        \\// @Filename: /a.js
        \\exports.__esModule = true;
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
    // f.VerifyQuickInfoAt(undefined, "", "(alias) function f(t: string): void\nimport f", "Run this function");
}

test "TestGoToDefinitionTypeReferenceDirective" {
    const content =
        \\// @typeRoots: src/types
        \\// @Filename: src/types/lib/index.d.ts
        \\/*0*/declare let $: {x: number};
        \\// @Filename: src/app.ts
        \\ /// <reference types="[|lib/*1*/|]"/>
        \\ $.x;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1");
}

test "TestFormatTemplateStringOnPaste" {
    const content =
        \\const x = 
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatSelection(undefined, "0", "1");
    _ = f.VerifyCurrentFileContent(undefined, "const x = `${0}abc`;");
}

test "TestFormatMultipleFunctionArguments" {
    const content =
        \\
        \\ someRandomFunction({
        \\   prop1: 1,
        \\   prop2: 2
        \\ }, {
        \\   prop3: 3,
        \\   prop4: 4
        \\ }, {
        \\   prop5: 5,
        \\   prop6: 6
        \\ });
        \\
        \\ someRandomFunction(
        \\     { prop7: 1, prop8: 2 },
        \\     { prop9: 3, prop10: 4 },
        \\     {
        \\       prop11: 5,
        \\       prop2: 6
        \\     }
        \\ );
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "\nsomeRandomFunction({\n    prop1: 1,\n    prop2: 2\n}, {\n    prop3: 3,\n    prop4: 4\n}, {\n    prop5: 5,\n    prop6: 6\n});\n\nsomeRandomFunction(\n    { prop7: 1, prop8: 2 },\n    { prop9: 3, prop10: 4 },\n    {\n        prop11: 5,\n        prop2: 6\n    }\n);");
}

test "TestInlayHintsVariableTypes2" {
    const content =
        \\const object = { foo: 1, bar: 2 }
        \\const array = [1, 2]
        \\const a = object;
        \\const { foo, bar } = object;
        \\const {} = object;
        \\const b = array;
        \\const [ first, second ] = array;
        \\const [] = array;
        \\declare function foo<T extends number>(t: T): T
        \\const x = foo(1)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayVariableTypeHints = core.TSTrue}});
}

test "TestCompletionsInExport_invalid" {
    const content =
        \\function topLevel() {}
        \\if (!!true) {
        \\  const blockScoped = 0;
        \\  export { /**/ };
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
//                 "topLevel",
//                 &.{
//                     .Label =    "type",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestOrganizeImportsUnicode4" {
    const content =
        \\import {
        \\    Ab,
        \\    _aB,
        \\    aB,
        \\    _Ab,
        \\} from './foo';
        \\
        \\console.log(_aB, _Ab, aB, Ab);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    _Ab,\n    _aB,\n    Ab,\n    aB,\n} from './foo';\n\nconsole.log(_aB, _Ab, aB, Ab);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsCollation =  lsutil.OrganizeImportsCollationUnicode,
//             .OrganizeImportsCaseFirst =  lsutil.OrganizeImportsCaseFirstUpper,
//         },
//     );
    // f.VerifyOrganizeImports(undefined,
//         "import {\n    _aB,\n    _Ab,\n    aB,\n    Ab,\n} from './foo';\n\nconsole.log(_aB, _Ab, aB, Ab);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsCollation =  lsutil.OrganizeImportsCollationUnicode,
//             .OrganizeImportsCaseFirst =  lsutil.OrganizeImportsCaseFirstLower,
//         },
//     );
}

test "TestFindAllRefsTypedef_importType" {
    const content =
        \\// @allowJs: true
        \\// @Filename: /a.js
        \\module.exports = 0;
        \\/** /*1*/@typedef {number} /*2*/Foo */
        \\const dummy = 0;
        \\// @Filename: /b.js
        \\/** @type {import('./a')./*3*/Foo} */
        \\const x = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

