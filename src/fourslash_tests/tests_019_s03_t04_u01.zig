const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestImportNameCodeFix_jsxOpeningTagImportDefault" {
    const content =
        \\// @module: commonjs
        \\// @jsx: react-jsx
        \\// @Filename: /component.tsx
        \\export default function (props: any) {}
        \\// @Filename: /index.tsx
        \\export function Index() {
        \\    return <Component/**/ />;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import Component from \"./component\";\n\nexport function Index() {\n    return <Component />;\n}",
    }, null );
}

test "TestCompletionsCombineOverloads_returnType" {
    const content =
        \\interface A { a: number }
        \\interface B { b: number }
        \\declare function f(n: number): A;
        \\declare function f(s: string): B;
        \\f()./**/
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
//                 "a",
//                 "b",
//             },
//         },
//     });
}

