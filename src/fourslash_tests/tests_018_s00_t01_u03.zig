const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestTsxFindAllReferences10" {
    const content =
        \\//@Filename: file.tsx
        \\// @jsx: preserve
        \\// @noLib: true
        \\declare namespace JSX {
        \\    interface Element { }
        \\    interface IntrinsicElements {
        \\    }
        \\    interface ElementAttributesProperty { props; }
        \\}
        \\interface ClickableProps {
        \\    children?: string;
        \\    className?: string;
        \\}
        \\interface ButtonProps extends ClickableProps {
        \\    /*1*/onClick(event?: React.MouseEvent<HTMLButtonElement>): void;
        \\}
        \\interface LinkProps extends ClickableProps {
        \\    goTo: string;
        \\}
        \\declare function MainButton(buttonProps: ButtonProps): JSX.Element;
        \\declare function MainButton(linkProps: LinkProps): JSX.Element;
        \\declare function MainButton(props: ButtonProps | LinkProps): JSX.Element;
        \\let opt = <MainButton />;
        \\let opt = <MainButton children="chidlren" />;
        \\let opt = <MainButton onClick={()=>{}} />;
        \\let opt = <MainButton onClick={()=>{}} ignore-prop />;
        \\let opt = <MainButton goTo="goTo" />;
        \\let opt = <MainButton wrong />;
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    // f.VerifyBaselineFindAllReferences(undefined, "1");
}

test "TestCodeFixClassImplementInterfaceMethodTypePredicate" {
    const content =
        \\interface I {
        \\    f(i: any): i is I;
        \\    f(): this is I;
        \\}
        \\
        \\class C implements I {}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.VerifyCodeFix(undefined, .{
        .Description = "Implement interface 'I'",
        .NewFileContent = "interface I {\n    f(i: any): i is I;\n    f(): this is I;\n}\n\nclass C implements I {\n    f(i: any): i is I;\n    f(): this is I;\n    f(i?: unknown): boolean {\n        throw new Error(\"Method not implemented.\");\n    }\n}",
        .Index = 0,
    });
}

