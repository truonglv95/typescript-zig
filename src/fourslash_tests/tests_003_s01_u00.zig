const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestSignatureHelpWithTriggers02" {
    const content =
        \\declare function foo<T>(x: T, y: T): T;
        \\declare function bar<U>(x: U, y: U): U;
        \\
        \\foo(bar/*1*/)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    _ = f.Insert(undefined, "(");
    // try f.VerifySignatureHelp(undefined, .{.Text = "bar(x: unknown, y: unknown): unknown"});
    _ = f.Backspace(undefined, 1);
    _ = f.Insert(undefined, "<");
    // try f.VerifySignatureHelp(undefined, .{.Text = "bar<U>(x: U, y: U): U"});
    _ = f.Backspace(undefined, 1);
    _ = f.Insert(undefined, ",");
    // try f.VerifySignatureHelp(undefined, .{.Text = "foo(x: <U>(x: U, y: U) => U, y: <U>(x: U, y: U) => U): <U>(x: U, y: U) => U"});
    _ = f.Backspace(undefined, 1);
}

test "TestUnusedImports8FS" {
    const content =
        \\// @noUnusedLocals: true
        \\// @Filename: file2.ts
        \\[|import {Calculator as calc, test as t1, test2 as t2} from "./file1"|]
        \\
        \\var x = new calc();
        \\x.handleChar();
        \\t1();
        \\// @Filename: file1.ts
        \\export class Calculator {
        \\    handleChar() { }
        \\}
        \\export function test() {
        \\
        \\}
        \\export function test2() {
        \\
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "import {Calculator as calc, test as t1} from \"./file1\"", false, 0, 0);
}

