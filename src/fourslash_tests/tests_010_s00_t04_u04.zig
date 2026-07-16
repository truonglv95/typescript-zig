const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestImportNameCodeFix_trailingComma" {
    const content =
        \\// @Filename: index.ts
        \\import {
        \\  T2,
        \\  T1,
        \\} from "./types";
        \\
        \\const x: T3/**/
        \\// @Filename: types.ts
        \\export type T1 = 0;
        \\export type T2 = 0;
        \\export type T3 = 0;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import {\n  T2,\n  T1,\n  T3,\n} from \"./types\";\n\nconst x: T3",
    }, null );
}

test "TestAutoImportTypeOnlyPreferred2" {
    const content =
        \\// @Filename: /node_modules/react/index.d.ts
        \\export interface ComponentType {}
        \\export interface ComponentProps {}
        \\export declare function useState<T>(initialState: T): [T, (newState: T) => void];
        \\export declare function useEffect(callback: () => void, deps: any[]): void;
        \\// @Filename: /main.ts
        \\import type { ComponentType } from "react";
        \\import { useState } from "react";
        \\
        \\export function Component({ prop } : { prop: ComponentType }) {
        \\    const codeIsUnimportant = useState(1);
        \\    useEffect/*1*/(() => {}, []);
        \\}
        \\// @Filename: /main2.ts
        \\import { useState } from "react";
        \\import type { ComponentType } from "react";
        \\
        \\type _ = ComponentProps/*2*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import type { ComponentType } from \"react\";\nimport { useEffect, useState } from \"react\";\n\nexport function Component({ prop } : { prop: ComponentType }) {\n    const codeIsUnimportant = useState(1);\n    useEffect(() => {}, []);\n}",
    }, null );
    _ = f.GoToMarker(undefined, "2");
    try f.VerifyImportFixAtPosition(undefined, &.{
        "import { useState } from \"react\";\nimport type { ComponentProps, ComponentType } from \"react\";\n\ntype _ = ComponentProps;",
    }, null );
}

