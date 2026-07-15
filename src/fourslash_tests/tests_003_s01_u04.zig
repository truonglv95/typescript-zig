const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListWithUnresolvedModule" {
    const content =
        \\namespace m {
        \\    import foo = module('_foo');
        \\    var n: num/**/
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
//                 &.{
//                     .Label =    "number",
//                     .SortText = undefined(string(ls.SortTextGlobalsOrKeywords)),
//                 },
//             },
//         },
//     });
}

test "TestTsxCompletionsGenericComponent" {
    const content =
        \\// @jsx: preserve
        \\// @skipLibCheck: true
        \\// @Filename: file.tsx
        \\ declare namespace JSX {
        \\     interface Element { }
        \\     interface IntrinsicElements {
        \\     }
        \\     interface ElementAttributesProperty { props; }
        \\ }
        \\
        \\class Table<P> {
        \\    constructor(public props: P) {}
        \\}
        \\
        \\type Props = { widthInCol: number; text: string; };
        \\
        \\/**
        \\ * @param width {number} Table width in px
        \\ */
        \\function createTable(width) {
        \\    return <Table<Props> /*1*/ />
        \\}
        \\
        \\createTable(800);
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
//                 "widthInCol",
//                 "text",
//             },
//         },
//     });
}

