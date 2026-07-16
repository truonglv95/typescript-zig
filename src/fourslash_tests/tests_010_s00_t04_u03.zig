const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestCallHierarchyContainerName" {
    const content =
        \\function /**/f() {}
        \\
        \\class A {
        \\  static sameName() {
        \\    f();
        \\  }
        \\}
        \\
        \\class B {
        \\  sameName() {
        \\    A.sameName();
        \\  }
        \\}
        \\
        \\const Obj = {
        \\  get sameName() {
        \\    return new B().sameName;
        \\  }
        \\};
        \\
        \\namespace Foo {
        \\  function sameName() {
        \\    return Obj.sameName;
        \\  }
        \\
        \\  export class C {
        \\    constructor() {
        \\      sameName();
        \\    }
        \\  }
        \\}
        \\
        \\namespace Foo.Bar {
        \\  const sameName = () => new Foo.C();
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyBaselineCallHierarchy(undefined);
}

test "TestOrganizeImportsType6" {
    const content =
        \\import { type a, A, b } from "foo";
        \\interface Use extends A {}
        \\console.log(a, b);
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // try f.VerifyOrganizeImports(undefined,
//         "import { type a, A, b } from \"foo\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsTypeOrder = lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type a, A, b } from \"foo1\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type a, A, b } from \"foo1\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSUnknown,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type a, A, b } from \"foo2\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { type a, A, b } from \"foo2\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSTrue,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
    _ = f.ReplaceLine(undefined, 0, "import { type a, A, b } from \"foo3\";");
    // try f.VerifyOrganizeImports(undefined,
//         "import { A, type a, b } from \"foo3\";\ninterface Use extends A {}\nconsole.log(a, b);",
//         lsproto.CodeActionKindSourceOrganizeImports,
//         &.{
//             .OrganizeImportsIgnoreCase = core.TSFalse,
//             .OrganizeImportsTypeOrder =  lsutil.OrganizeImportsTypeOrderInline,
//         },
//     );
}

