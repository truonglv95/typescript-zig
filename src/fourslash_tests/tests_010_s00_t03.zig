const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCompletionListForShorthandPropertyAssignment" {
    const content =
        \\var person: {name:string; id: number} = { n/**/
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
//                 "id",
//                 "name",
//             },
//         },
//     });
}

test "TestInlayHintsInteractiveJsDocParameterNames" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @Filename: /a.js
        \\var x
        \\x.foo(1, 2);
        \\/**
        \\ * @type {{foo: (a: number, b: number) => void}}
        \\ */
        \\var y
        \\y.foo(1, 2)
        \\/**
        \\ * @type {string}
        \\ */
        \\var z = ""
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToFile(undefined, "/a.js");
    // try f.VerifyBaselineInlayHints(undefined, null , &.{.InlayHints = .{.IncludeInlayParameterNameHints = lsutil.IncludeInlayParameterNameHintsLiterals}});
}

test "TestNavigationBarItemsItems" {
    const content =
        \\// Interface
        \\interface IPoint {
        \\    getDist(): number;
        \\    new(): IPoint;
        \\    (): any;
        \\    [x:string]: number;
        \\    prop: string;
        \\}
        \\
        \\/// Module
        \\namespace Shapes {
        \\
        \\    // Class
        \\    export class Point implements IPoint {
        \\        constructor (public x: number, public y: number) { }
        \\
        \\        // Instance member
        \\        getDist() { return Math.sqrt(this.x * this.x + this.y * this.y); }
        \\
        \\        // Getter
        \\        get value(): number { return 0; }
        \\
        \\        // Setter
        \\        set value(newValue: number) { return; }
        \\
        \\        // Static member
        \\        static origin = new Point(0, 0);
        \\
        \\        // Static method
        \\        private static getOrigin() { return Point.origin; }
        \\    }
        \\
        \\    enum Values { value1, value2, value3 }
        \\}
        \\
        \\// Local variables
        \\var p: IPoint = new Shapes.Point(3, 4);
        \\var dist = p.getDist();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineDocumentSymbol(undefined);
}

test "TestLinkedEditingJsxTag11" {
    const content =
        \\// @Filename: /customElements.tsx
        \\const jsx = <fbt:enum knownProp="accepted"
        \\    unknownProp="rejected">
        \\</fbt:enum>;
        \\
        \\const customElement = <custom-element></custom-element>;
        \\
        \\const standardElement = 
        \\   <Link href="/hello" passHref>
        \\       <Button component="a">
        \\           Next
        \\       </Button>
        \\   </Link>;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyBaselineLinkedEditing(undefined);
}

test "TestGoToImplementationInterfaceMethod_04" {
    const content =
        \\interface Foo {
        \\    hello (): void;
        \\}
        \\
        \\class Bar extends SuperBar {
        \\    [|hello|]() {}
        \\}
        \\
        \\class SuperBar implements Foo {
        \\    [|hello|]() {}
        \\}
        \\
        \\class OtherBar implements Foo {
        \\    hello() {} // should not show up
        \\}
        \\
        \\function (x: SuperBar) {
        \\    x.he/*function_call*/llo()
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToImplementation(undefined, "function_call");
}

test "TestReferencesForLabel4" {
    const content =
        \\/*1*/label: function foo(label) {
        \\    while (true) {
        \\        /*2*/break /*3*/label;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineFindAllReferences(undefined, "1", "2", "3");
}

test "TestGoToDefinitionLabels" {
    const content =
        \\/*label1Definition*/label1: while (true) {
        \\    /*label2Definition*/label2: while (true) {
        \\        break [|/*1*/label1|];
        \\        continue [|/*2*/label2|];
        \\        () => { break [|/*3*/label1|]; }
        \\        continue /*4*/unknownLabel;
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyBaselineGoToDefinition(undefined, true, "1", "2", "3", "4");
}

test "TestCodeFixMissingTypeAnnotationOnExports25_heritage_formatting_3" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\function mixin<T extends new (...a: any) => any>(ctor: T): T {
        \\    return ctor;
        \\}
        \\class Point2D { x = 0; y = 0; }
        \\export class Point3D3 extends mixin(Point2D) /* DD*/ {
        \\    z = 0;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyCodeFixAvailable(undefined, &.{"Extract base class to variable"});
    try f.VerifyCodeFix(undefined, .{
        .Description = "Extract base class to variable",
        .NewFileContent = "function mixin<T extends new (...a: any) => any>(ctor: T): T {\n    return ctor;\n}\nclass Point2D { x = 0; y = 0; }\nconst Point3D3Base: typeof Point2D = mixin(Point2D) /* DD*/;\nexport class Point3D3 extends Point3D3Base {\n    z = 0;\n}",
        .Index = 0,
    });
}

test "TestCompletionListAndMemberListOnCommentedDot" {
    const content =
        \\namespace M {
        \\  export class C { public pub = 0; private priv = 1; }
        \\  export var V = 0;
        \\}
        \\
        \\
        \\var c = new M.C();
        \\
        \\c. // test on c.
        \\
        \\//Test for comment
        \\//c./**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCompletions(undefined, "", null);
}

test "TestCompletionListProtectedMembers" {
    const content =
        \\class Base {
        \\    protected y;
        \\    constructor(protected x) {}
        \\    method() { this./*1*/; }
        \\}
        \\class D1 extends Base {
        \\    protected z;
        \\    method1() { this./*2*/; }
        \\}
        \\class D2 extends Base {
        \\    method2() { this./*3*/; }
        \\}
        \\class D3 extends D1 {
        \\    method2() { this./*4*/; }
        \\}
        \\var b: Base;
        \\f./*5*/
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
//             .Unsorted = &.{
//                 "y",
//                 "x",
//                 "method",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "2", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "z",
//                 "method1",
//                 "y",
//                 "x",
//                 "method",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "3", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "method2",
//                 "y",
//                 "x",
//                 "method",
//             },
//         },
//     });
    // f.VerifyCompletions(undefined, "4", &.{
//         .IsIncomplete = false,
//         .ItemDefaults = &.{
//             .CommitCharacters = &DefaultCommitCharacters,
//             .EditRange =        Ignored,
//         },
//         .Items = &.{
//             .Unsorted = &.{
//                 "method2",
//                 "z",
//                 "method1",
//                 "y",
//                 "x",
//                 "method",
//             },
//         },
//     });
    _ = f.VerifyCompletions(undefined, "5", null);
}

