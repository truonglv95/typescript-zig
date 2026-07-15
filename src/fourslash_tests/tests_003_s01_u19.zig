const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionsImport_ambient" {
    const content =
        \\// @lib: es5
        \\// @module: commonjs
        \\// @Filename: a.d.ts
        \\declare namespace foo { class Bar {} }
        \\declare module 'path1' {
        \\  import Bar = foo.Bar;
        \\  export default Bar;
        \\}
        \\declare module 'path2longer' {
        \\  import Bar = foo.Bar;
        \\  export {Bar};
        \\}
        \\
        \\// @Filename: b.ts
        \\Ba/**/
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
//                     &.{
//                         .Label =    "foo",
//                         .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                     },
//                     &.{
//                         .Label = "Bar",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "path1",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                     &.{
//                         .Label = "Bar",
//                         .Data = &.{
//                             .AutoImport = &.{
//                                 .ModuleSpecifier = "path2longer",
//                             },
//                         },
//                         .AdditionalTextEdits = fourslash.AnyTextEdits,
//                         .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                     },
//                 }, false,
//             ),
//         },
//     });
    // f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =        "Bar",
//         .Source =      "path2longer",
//         .Description = "Add import from \"path2longer\"",
//         .NewFileContent = undefined("import { Bar } from \"path2longer\";\n\nBa"),
//     });
}

test "TestTsxFindAllReferences5" {
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
        \\/*1*/declare function /*2*/Opt(attributes: OptionPropBag): JSX.Element;
        \\let opt = /*3*/</*4*/Opt />;
        \\let opt1 = /*5*/</*6*/Opt propx={100} propString />;
        \\let opt2 = /*7*/</*8*/Opt propx={100} optional/>;
        \\let opt3 = /*9*/</*10*/Opt wrong />;
        \\let opt4 = /*11*/</*12*/Opt propx={100} propString="hi" />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12");
}

