const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestOrganizeImportsGroup_Newline" {
    const content =
        \\import c from "C";
        \\
        \\import d from "D";
        \\import a from "A"; // not count
        \\import b from "B";
        \\
        \\console.log(a, b, c, d)
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyOrganizeImports(undefined,
//         "import c from \"C\";\n\nimport a from \"A\"; // not count\nimport b from \"B\";\nimport d from \"D\";\n\nconsole.log(a, b, c, d)",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         null,
//     );
}

test "TestRenameObjectBindingElementPropertyName01" {
    const content =
        \\interface I {
        \\    [|[|{| "contextRangeIndex": 0 |}property1|]: number;|]
        \\    property2: string;
        \\}
        \\
        \\var foo: I;
        \\[|var { [|{| "contextRangeIndex": 2 |}property1|]: prop1 } = foo;|]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineRenameAtRangesWithText(undefined, null , "property1");
}

test "TestSmartSelection_loneVariableDeclaration" {
    const content =
        \\const /**/x = 3;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyBaselineSelectionRanges(undefined);
}

test "TestDeclarationMapsGoToDefinitionSameNameDifferentDirectory" {
    const content =
        \\// @Filename: BaseClass/Source.d.ts
        \\declare class Control {
        \\    constructor();
        \\    /** this is a super var */
        \\    myVar: boolean | 'yeah';
        \\}
        \\//# sourceMappingURL=Source.d.ts.map
        \\// @Filename: BaseClass/Source.d.ts.map
        \\{"version":3,"file":"Source.d.ts","sourceRoot":"","sources":["Source.ts"],"names":[],"mappings":"AAAA,cAAM,OAAO;;IAIT,0BAA0B;IACnB,KAAK,EAAE,OAAO,GAAG,MAAM,CAAQ;CACzC"}
        \\// @Filename: BaseClass/Source.ts
        \\class /*2*/Control{
        \\    constructor(){
        \\        return;
        \\    }
        \\    /** this is a super var */
        \\    public /*4*/myVar: boolean | 'yeah' = true;
        \\}
        \\// @Filename: tsbase.json
        \\{
        \\    "$schema": "http://json.schemastore.org/tsconfig",
        \\    "compileOnSave": true,
        \\    "compilerOptions": {
        \\      "lib": ["es5"],
        \\      "strict": false,
        \\      "sourceMap": true,
        \\      "declaration": true,
        \\      "declarationMap": true
        \\    }
        \\  }
        \\// @Filename: buttonClass/tsconfig.json
        \\{
        \\    "extends": "../tsbase.json",
        \\    "compilerOptions": {
        \\      "outFile": "Source.js"
        \\    },
        \\    "files": [
        \\      "Source.ts"
        \\    ],
        \\    "include": [
        \\      "../BaseClass/Source.d.ts"
        \\    ]
        \\  }
        \\// @Filename: buttonClass/Source.ts
        \\// I cannot F12 navigate to Control
        \\//                   vvvvvvv
        \\class Button extends [|/*1*/Control|] {
        \\    public myFunction() {
        \\        // I cannot F12 navigate to myVar
        \\        //              vvvvv
        \\        if (typeof this.[|/*3*/myVar|] === 'boolean') {
        \\            this.myVar;
        \\        } else {
        \\            this.myVar.toLocaleUpperCase();
        \\        }
        \\    }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.MarkTestAsStradaServer();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1", "3");
}

test "TestGetOccurrencesThis6" {
    const content =
        \\this/*1*/;
        \\this;
        \\
        \\function f() {
        \\    this/*2*/;
        \\    this;
        \\    () => this;
        \\    () => {
        \\        if (this) {
        \\            this;
        \\        }
        \\        else {
        \\            this.this;
        \\        }
        \\    }
        \\    function inside() {
        \\        this;
        \\        (function (_) {
        \\            this;
        \\        })(this);
        \\    }
        \\}
        \\
        \\namespace m {
        \\    var x = th/*6*/is;
        \\    function f() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\}
        \\
        \\class A {
        \\    public b = this.method1;
        \\
        \\    public method1() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this/*3*/;
        \\            })(this);
        \\        }
        \\    }
        \\
        \\    private method2() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\
        \\    public static staticB = this.staticMethod1;
        \\
        \\    public static staticMethod1() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\
        \\    private static staticMethod2() {
        \\        this;
        \\        this;
        \\        () => this;
        \\        () => {
        \\            if (this) {
        \\                this;
        \\            }
        \\            else {
        \\                this.this;
        \\            }
        \\        }
        \\        function inside() {
        \\            this;
        \\            (function (_) {
        \\                this;
        \\            })(this);
        \\        }
        \\    }
        \\}
        \\
        \\var x = {
        \\    a: /*4*/this,
        \\
        \\    f() {
        \\        this/*5*/;
        \\        function foo() {
        \\            this;
        \\        }
        \\        const bar = () => {
        \\            this;
        \\        }
        \\    },
        \\
        \\    g() {
        \\        this;
        \\    },
        \\
        \\    get h() {
        \\        /*7*/this;
        \\        function foo() {
        \\            this;
        \\        }
        \\        const bar = () => {
        \\            this;
        \\        }
        \\        return;
        \\    },
        \\
        \\    set h(foo: any) {
        \\        this;
        \\    },
        \\
        \\    l: () => {
        \\        /*8*/this;
        \\        function foo() {
        \\            this;
        \\        }
        \\        const bar = () => {
        \\            this;
        \\        }
        \\    },
        \\};
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

test "TestFindAllRefsDefaultImport" {
    const content =
        \\// @Filename: /a.ts
        \\export default function /*0*/a() {}
        \\// @Filename: /b.ts
        \\import /*1*/a, * as ns from "./a";
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "0", "1");
}

test "TestCodeFixMissingTypeAnnotationOnExports60_drops_unneeded_non_trailing_unknown" {
    const content =
        \\// @isolatedDeclarations: true
        \\// @declaration: true
        \\
        \\export interface Foo<S = string, T = unknown> {}
        \\export function f(x: Foo<string, unknown>) { return x; }
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Add return type 'Foo'",
        .NewFileContent = "\nexport interface Foo<S = string, T = unknown> {}\nexport function f(x: Foo<string, unknown>): Foo { return x; }\n",
        .Index = 0,
    });
}

test "TestFormattingObjectLiteralOpenCurlySingleLine" {
    const content =
        \\
        \\let obj1 =
        \\{ x: 10 };
        \\
        \\let obj2 =
        \\    // leading trivia
        \\{ y: 10 };
        \\
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.FormatDocument(undefined, "");
    _ = f.VerifyCurrentFileContent(undefined, "\nlet obj1 =\n    { x: 10 };\n\nlet obj2 =\n    // leading trivia\n    { y: 10 };\n");
}

test "TestGoToDefinitionOverriddenMember11" {
    const content =
        \\// @allowJs: true
        \\// @checkJs: true
        \\// @noEmit: true
        \\// @noImplicitOverride: true
        \\// @filename: a.js
        \\class Foo {
        \\    /*Foo_m*/m() {}
        \\}
        \\class Bar extends Foo {
        \\    /** @[|over{|"name": "1"|}ride|][| se{|"name": "2"|}e {@li{|"name": "3"|}nk https://test.c{|"name": "4"|}om} {|"name": "5"|}description |]*/
        \\    m() {}
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineGoToDefinition(undefined, true, "1", "2", "3", "4", "5");
}

test "TestGetOccurrencesConst02" {
    const content =
        \\namespace m {
        \\    declare /*1*/const x;
        \\    declare [|const|] enum E {
        \\    }
        \\}
        \\
        \\declare /*2*/const x;
        \\declare [|const|] enum E {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Ranges()));
    // f.VerifyBaselineDocumentHighlights(undefined, null , ToAny(f.Markers()));
}

