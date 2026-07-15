const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCodeFixClassImplementInterfaceTypeParamInstantiateDeeply" {
    const content =
        \\interface I<T> {
        \\    x: { y: T, z: T[] };
        \\}
        \\class C implements I<number> {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I<number>'",
        .NewFileContent = "interface I<T> {\n    x: { y: T, z: T[] };\n}\nclass C implements I<number> {\n    x: { y: number; z: number[]; };\n}",
        .Index = 0,
    });
}

test "TestCompletionListInContextuallyTypedArgument" {
    const content =
        \\interface MyPoint {
        \\    x1: number;
        \\    y1: number;
        \\}
        \\
        \\function foo(a: (e: MyPoint) => string) { }
        \\foo((e) => {
        \\    e./*1*/
        \\} );
        \\
        \\class test {
        \\    constructor(a: (e: MyPoint) => string) { }
        \\}
        \\var t = new test((e) => {
        \\    e./*2*/
        \\} );
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
//                 "x1",
//                 "y1",
//             },
//         },
//     });
}

