const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestJsDocExtends" {
    const content =
        \\// @allowJs: true
        \\// @Filename: dummy.js
        \\/**
        \\ * @extends {Thing<string>}
        \\ */
        \\class MyStringThing extends Thing {
        \\    constructor() {
        \\        var x = this.mine;
        \\        x/**/;
        \\    }
        \\}
        \\// @Filename: declarations.d.ts
        \\declare class Thing<T> {
        \\    mine: T;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    _ = f.VerifyQuickInfoIs(undefined, "(local var) x: string", "");
}

test "TestCodeFixInferFromFunctionThisUsageObjectPropertyShorthandParameter" {
    const content =
        \\// @noImplicitThis: true
        \\function returnThisMember([| |]suffix: string) {
        \\     return this.member + suffix;
        \\ }
        \\
        \\ interface Container {
        \\     member: string;
        \\     returnThisMember(suffix: string): string;
        \\ }
        \\
        \\ const container: Container = {
        \\     member: "sample",
        \\     returnThisMember,
        \\ };
        \\
        \\ container.returnThisMember("");
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyRangeAfterCodeFix(undefined, "this: Container, ", false, 0, 0);
}

