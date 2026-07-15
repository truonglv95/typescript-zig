const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestTsxFindAllReferencesUnionElementType1" {
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
        \\function SFC1(prop: { x: number }) {
        \\    return <div>hello </div>;
        \\};
        \\function SFC2(prop: { x: boolean }) {
        \\    return <h1>World </h1>;
        \\}
        \\/*1*/var /*2*/SFCComp = SFC1 || SFC2;
        \\/*3*/</*4*/SFCComp x={ "hi" } />
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3", "4");
}

test "TestCompletionListForGenericInstance1" {
    const content =
        \\// @lib: es5
        \\interface Iterator<T, U> {
        \\    (value: T, index: any, list: any): U
        \\}
        \\var i: Iterator<string, number>;
        \\i/**/
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
//                     .Label =  "i",
//                     .Detail = undefined("var i: Iterator<string, number>"),
//                 },
//             },
//         },
//     });
}

