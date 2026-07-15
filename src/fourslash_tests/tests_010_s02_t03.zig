const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestImportNameCodeFix_externalNonRelateive2" {
    const content =
        \\// @Filename: /home/src/workspaces/project/apps/app1/tsconfig.json
        \\{
        \\  "compilerOptions": {
        \\    "module": "commonjs",
        \\    "lib": ["es5"],
        \\    "paths": {
        \\      "shared/*": ["../../shared/*"]
        \\    }
        \\  },
        \\  "include": ["src", "../../shared"]
        \\}
        \\// @Filename: /home/src/workspaces/project/apps/app1/src/index.ts
        \\shared/*internal2external*/
        \\// @Filename: /home/src/workspaces/project/apps/app1/src/app.ts
        \\utils/*internal2internal*/
        \\// @Filename: /home/src/workspaces/project/apps/app1/src/utils.ts
        \\export const utils = 0;
        \\// @Filename: /home/src/workspaces/project/shared/constants.ts
        \\export const shared = 0;
        \\// @Filename: /home/src/workspaces/project/shared/data.ts
        \\shared/*external2external*/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.GetOptions();
    // f.Configure(undefined, opts839);
    _ = f.GoToMarker(undefined, "internal2external");
    // f.VerifyImportFixAtPosition(undefined, &.{
//         "import { shared } from \"shared/constants\";\n\nshared",
//     }, &.{.ImportModuleSpecifierPreference = "project-relative"});
    _ = f.GoToMarker(undefined, "internal2internal");
    // f.VerifyImportFixAtPosition(undefined, &.{
//         "import { utils } from \"./utils\";\n\nutils",
//     }, &.{.ImportModuleSpecifierPreference = "project-relative"});
    _ = f.GoToMarker(undefined, "external2external");
    // f.VerifyImportFixAtPosition(undefined, &.{
//         "import { shared } from \"./constants\";\n\nshared",
//     }, &.{.ImportModuleSpecifierPreference = "project-relative"});
}

test "TestQuickInfoDisplayPartsParameters" {
    const content =
        \\/** @return *crunch* */
        \\function /*1*/foo(/*2*/param: string, /*3*/optionalParam?: string, /*4*/paramWithInitializer = "hello", .../*5*/restParam: string[]) {
        \\    /*6*/param = "Hello";
        \\    /*7*/optionalParam = "World";
        \\    /*8*/paramWithInitializer = "Hello";
        \\    /*9*/restParam[0] = "World";
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineHover(undefined);
}

test "TestCallHierarchyInterfaceMethod" {
    const content =
        \\interface I {
        \\    /**/foo(): void;
        \\}
        \\
        \\const obj: I = { foo() {} };
        \\
        \\obj.foo();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // f.VerifyBaselineCallHierarchy(undefined);
}

test "TestCodeFixClassImplementClassMemberAnonymousClass" {
    const content =
        \\// @strict: false
        \\class A {
        \\    foo() {
        \\        return class { x: number; }
        \\    }
        \\    bar() {
        \\        return new class { x: number; }
        \\    }
        \\}
        \\class C implements A {[| |]}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestGoToDefinitionReturn7" {
    const content =
        \\function foo(a: string, b: string): string;
        \\function foo(a: number, b: number): number;
        \\function /*end*/foo(a: any, b: any): any {
        \\    [|/*start*/return|] a + b;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "start");
}

test "TestCodeFixConvertToMappedObjectType5" {
    const content =
        \\type K = "foo" | "bar";
        \\class SomeType {
        \\    [prop: K]: any;
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyCodeFixNotAvailable(undefined);
}

test "TestJsDocInheritDoc" {
    const content =
        \\// @Filename: inheritDoc.ts
        \\class Foo {
        \\    /**
        \\     * Foo constructor documentation
        \\     */
        \\    constructor(value: number) {}
        \\    /**
        \\     * Foo#method1 documentation
        \\     */
        \\    static method1() {}
        \\    /**
        \\     * Foo#method2 documentation
        \\     */
        \\    method2() {}
        \\    /**
        \\     * Foo#property1 documentation
        \\     */
        \\    property1: string;
        \\    /**
        \\     * Foo#property3 documentation
        \\     */
        \\    property3 = "instance prop";
        \\}
        \\interface Baz {
        \\    /** Baz#property1 documentation */
        \\    property1: string;
        \\    /**
        \\     * Baz#property2 documentation
        \\     */
        \\    property2: object;
        \\}
        \\class Bar extends Foo implements Baz {
        \\    ctorValue: number;
        \\    /** @inheritDoc */
        \\    constructor(value: number) {
        \\        super(value);
        \\        this.ctorValue = value;
        \\    }
        \\    /** @inheritDoc */
        \\    static method1() {}
        \\    method2() {}
        \\    /** @inheritDoc */
        \\    property1: string;
        \\    /**
        \\     * Bar#property2
        \\     * @inheritDoc
        \\     */
        \\    property2: object;
        \\
        \\    static /*6*/property3 = "class prop";
        \\}
        \\const b = new Bar/*1*/(5);
        \\b.method2/*2*/();
        \\Bar.method1/*3*/();
        \\const p1 = b.property1/*4*/;
        \\const p2 = b.property2/*5*/;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyQuickInfoAt(undefined, "1", "constructor Bar(value: number): Bar", "");
    // f.VerifyQuickInfoAt(undefined, "2", "(method) Bar.method2(): void", "Foo#method2 documentation");
    // f.VerifyQuickInfoAt(undefined, "3", "(method) Bar.method1(): void", "Foo#method1 documentation");
    // f.VerifyQuickInfoAt(undefined, "4", "(property) Bar.property1: string", "Foo#property1 documentation");
    // f.VerifyQuickInfoAt(undefined, "5", "(property) Bar.property2: object", "Baz#property2 documentation\nBar#property2");
    // f.VerifyQuickInfoAt(undefined, "6", "(property) Bar.property3: string", "");
}

test "TestGoToDefinitionConstructorOfClassExpression01" {
    const content =
        \\var x = class C {
        \\    /*definition*/constructor() {
        \\        var other = new [|/*xusage*/C|];
        \\    }
        \\}
        \\
        \\var y = class C extends x {
        \\    constructor() {
        \\        super();
        \\        var other = new [|/*yusage*/C|];
        \\    }
        \\}
        \\var z = class C extends x {
        \\    m() {
        \\        return new [|/*zusage*/C|];
        \\    }
        \\}
        \\
        \\var x1 = new [|/*cref*/C|]();
        \\var x2 = new [|/*xref*/x|]();
        \\var y1 = new [|/*yref*/y|]();
        \\var z1 = new [|/*zref*/z|]();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "xusage", "yusage", "zusage", "cref", "xref", "yref", "zref");
}

test "TestAutoImportBundlerExports" {
    const content =
        \\// @module: esnext
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/dep/package.json
        \\{
        \\  "name": "dep",
        \\  "version": "1.0.0",
        \\  "exports": {
        \\    ".": "./dist/index.js"
        \\  }
        \\}
        \\// @Filename: /node_modules/dep/dist/index.d.ts
        \\export const dep: number;
        \\// @Filename: /index.ts
        \\dep/**/
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyImportFixModuleSpecifiers(undefined, "", &.{"dep"}, null );
}

test "TestGetOccurrencesLoopBreakContinue6" {
    const content =
        \\var arr = [1, 2, 3, 4];
        \\label1: for (var n in arr) {
        \\    break;
        \\    continue;
        \\    break label1;
        \\    continue label1;
        \\
        \\    label2: for (var i = 0; i < arr[n]; i++) {
        \\        break label1;
        \\        continue label1;
        \\
        \\        break;
        \\        continue;
        \\        break label2;
        \\        continue label2;
        \\
        \\        function foo() {
        \\            label3: while (true) {
        \\                break;
        \\                continue;
        \\                break label3;
        \\                continue label3;
        \\
        \\                // these cross function boundaries
        \\                br/*1*/eak label1;
        \\                cont/*2*/inue label1;
        \\                bre/*3*/ak label2;
        \\                c/*4*/ontinue label2;
        \\
        \\                label4: do {
        \\                    break;
        \\                    continue;
        \\                    break label4;
        \\                    continue label4;
        \\
        \\                    break label3;
        \\                    continue label3;
        \\
        \\                    switch (10) {
        \\                        case 1:
        \\                        case 2:
        \\                            break;
        \\                            break label4;
        \\                        default:
        \\                            continue;
        \\                    }
        \\
        \\                    // these cross function boundaries
        \\                    br/*5*/eak label1;
        \\                    co/*6*/ntinue label1;
        \\                    br/*7*/eak label2;
        \\                    con/*8*/tinue label2;
        \\                    () => { b/*9*/reak; }
        \\                } while (true)
        \\            }
        \\        }
        \\    }
        \\}
        \\
        \\label5: while (true) break label5;
        \\
        \\label7: while (true) co/*10*/ntinue label5;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

