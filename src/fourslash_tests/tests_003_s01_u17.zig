const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionsOverridingProperties3" {
    const content =
        \\interface I {
        \\    prop: string;
        \\}
        \\class C implements I {
        \\    public pr/**/: string | number;
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
//                     .Label = "prop",
//                 },
//             },
//         },
//     });
}

test "TestGoToDefinitionImports" {
    const content =
        \\// @Filename: /a.ts
        \\export default function /*fDef*/f() {}
        \\export const /*xDef*/x = 0;
        \\// @Filename: /b.ts
        \\/*bDef*/declare const b: number;
        \\export = b;
        \\// @Filename: /b.ts
        \\import f, { x } from "./a";
        \\import * as /*aDef*/a from "./a";
        \\import b = require("./b");
        \\[|/*fUse*/f|];
        \\[|/*xUse*/x|];
        \\[|/*aUse*/a|];
        \\[|/*bUse*/b|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "aUse", "fUse", "xUse", "bUse");
}

