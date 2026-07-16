const std = @import("std");
const fourslash = @import("../fourslash/fourslash.zig");

test "TestSignatureHelpForOptionalMethods" {
    const content =
        \\// @strict: true
        \\interface Obj {
        \\    optionalMethod?: (current: any) => any;
        \\};
        \\
        \\const o: Obj = {
        \\  optionalMethod(/*1*/) {
        \\    return {};
        \\  }
        \\};
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "1");
    // try f.VerifySignatureHelp(undefined, .{.Text = "optionalMethod(current: any): any", .ParameterName = "current", .ParameterSpan = "current: any"});
}

test "TestIssue57585_2" {
    const content =
        \\// @strict: true
        \\// @target: esnext
        \\// @lib: esnext
        \\declare const EffectTypeId: unique symbol;
        \\
        \\type Covariant<A> = (_: never) => A;
        \\
        \\interface VarianceStruct<out A, out E, out R> {
        \\  readonly _V: string;
        \\  readonly _A: Covariant<A>;
        \\  readonly _E: Covariant<E>;
        \\  readonly _R: Covariant<R>;
        \\}
        \\
        \\interface Variance<out A, out E, out R> {
        \\  readonly [EffectTypeId]: VarianceStruct<A, E, R>;
        \\}
        \\
        \\type Success<T extends Effect<any, any, any>> = [T] extends [
        \\  Effect<infer _A, infer _E, infer _R>,
        \\]
        \\  ? _A
        \\  : never;
        \\
        \\declare const YieldWrapTypeId: unique symbol;
        \\
        \\class YieldWrap<T> {
        \\  readonly #value: T;
        \\  constructor(value: T) {
        \\    this.#value = value;
        \\  }
        \\  [YieldWrapTypeId](): T {
        \\    return this.#value;
        \\  }
        \\}
        \\
        \\interface EffectGenerator<T extends Effect<any, any, any>> {
        \\  next(...args: ReadonlyArray<any>): IteratorResult<YieldWrap<T>, Success<T>>;
        \\}
        \\
        \\interface Effect<out A, out E = never, out R = never>
        \\  extends Variance<A, E, R> {
        \\  [Symbol.iterator](): EffectGenerator<Effect<A, E, R>>;
        \\}
        \\
        \\declare const gen: {
        \\  <Eff extends YieldWrap<Effect<any, any, any>>, AEff>(
        \\    f: () => Generator<Eff, AEff, never>,
        \\  ): Effect<
        \\    AEff,
        \\    [Eff] extends [never]
        \\      ? never
        \\      : [Eff] extends [YieldWrap<Effect<infer _A, infer E, infer _R>>]
        \\      ? E
        \\      : never,
        \\    [Eff] extends [never]
        \\      ? never
        \\      : [Eff] extends [YieldWrap<Effect<infer _A, infer _E, infer R>>]
        \\      ? R
        \\      : never
        \\  >;
        \\};
        \\
        \\declare const succeed: <A>(value: A) => Effect<A>;
        \\
        \\gen(function* () {
        \\  const a = yield* succeed(1);
        \\  const b/*1*/ = yield* succeed(2);
        \\  return a + b;
        \\});
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "const b: number", "");
    try f.VerifyNonSuggestionDiagnostics(undefined, null);
}

test "TestIndexerReturnTypes1" {
    const content =
        \\interface Numeric {
        \\    [x: number]: Date;
        \\}
        \\}
        \\interface Stringy {
        \\    [x: string]: RegExp;
        \\}
        \\}
        \\interface NumericPlus {
        \\    [x: number]: Date;
        \\    foo(): Date;
        \\}
        \\}
        \\interface StringyPlus {
        \\    [x: string]: RegExp;
        \\    foo(): RegExp;
        \\}
        \\}
        \\interface NumericG<T> {
        \\    [x: number]: T;
        \\}
        \\}
        \\interface StringyG<T> {
        \\    [x: string]: T;
        \\}
        \\}
        \\interface Ty<T> {
        \\    [x: number]: Ty<T>;
        \\}
        \\interface Ty2<T> {
        \\    [x: number]: { [x: number]: T };
        \\}
        \\
        \\
        \\}
        \\var numeric: Numeric;
        \\var stringy: Stringy;
        \\var numericPlus: NumericPlus;
        \\var stringPlus: StringyPlus;
        \\var numericG: NumericG<Date>;
        \\var stringyG: StringyG<Date>;
        \\var ty: Ty<Date>;
        \\var ty2: Ty2<Date>;
        \\
        \\var /*1*/r1 = numeric[1];
        \\var /*2*/r2 = numeric['1'];
        \\var /*3*/r3 = stringy[1];
        \\var /*4*/r4 = stringy['1'];
        \\var /*5*/r5 = numericPlus[1];
        \\var /*6*/r6 = numericPlus['1'];
        \\var /*7*/r7 = stringPlus[1];
        \\var /*8*/r8 = stringPlus['1'];
        \\var /*9*/r9 = numericG[1];
        \\var /*10*/r10 = numericG['1'];
        \\var /*11*/r11 = stringyG[1];
        \\var /*12*/r12 = stringyG['1'];
        \\var /*13*/r13 = ty[1];
        \\var /*14*/r14 = ty['1'];
        \\var /*15*/r15 = ty2[1];
        \\var /*16*/r16 = ty2['1'];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "1", "var r1: Date", "");
    try f.VerifyQuickInfoAt(undefined, "2", "var r2: Date", "");
    try f.VerifyQuickInfoAt(undefined, "3", "var r3: RegExp", "");
    try f.VerifyQuickInfoAt(undefined, "4", "var r4: RegExp", "");
    try f.VerifyQuickInfoAt(undefined, "5", "var r5: Date", "");
    try f.VerifyQuickInfoAt(undefined, "6", "var r6: Date", "");
    try f.VerifyQuickInfoAt(undefined, "7", "var r7: RegExp", "");
    try f.VerifyQuickInfoAt(undefined, "8", "var r8: RegExp", "");
    try f.VerifyQuickInfoAt(undefined, "9", "var r9: Date", "");
    try f.VerifyQuickInfoAt(undefined, "10", "var r10: Date", "");
    try f.VerifyQuickInfoAt(undefined, "11", "var r11: Date", "");
    try f.VerifyQuickInfoAt(undefined, "12", "var r12: Date", "");
    try f.VerifyQuickInfoAt(undefined, "13", "var r13: Ty<Date>", "");
    try f.VerifyQuickInfoAt(undefined, "14", "var r14: Ty<Date>", "");
    try f.VerifyQuickInfoAt(undefined, "15", "var r15: {\n    [x: number]: Date;\n}", "");
    try f.VerifyQuickInfoAt(undefined, "16", "var r16: {\n    [x: number]: Date;\n}", "");
}

test "TestRenameDestructuringAssignmentInFor" {
    const content =
        \\// @strict: false
        \\interface I {
        \\    [|[|{| "contextRangeIndex": 0 |}property1|]: number;|]
        \\    property2: string;
        \\}
        \\var elems: I[];
        \\
        \\var p2: number, [|[|{| "contextRangeIndex": 2 |}property1|]: number|];
        \\for ([|{ [|{| "contextRangeIndex": 4 |}property1|] } = elems[0]|]; p2 < 100; p2++) {
        \\   p2 = [|property1|]++;
        \\}
        \\for ([|{ [|{| "contextRangeIndex": 7 |}property1|]: p2 } = elems[0]|]; p2 < 100; p2++) {
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyNoErrors(undefined);
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[1], f.Ranges()[8], f.Ranges()[3], f.Ranges()[5], f.Ranges()[6]);
}

test "TestJsDocServices" {
    const content =
        \\interface /*I*/I {}
        \\
        \\/**
        \\ * @param /*use*/[|foo|] I pity the foo
        \\ */
        \\function f([|[|/*def*/{| "contextRangeIndex": 1 |}foo|]: I|]) {
        \\    return /*use2*/[|foo|];
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "use");
    try f.VerifyQuickInfoIs(undefined, "(parameter) foo: I", "I pity the foo");
    // try f.VerifyBaselineFindAllReferences(undefined, "use", "def", "use2");
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[0], f.Ranges()[2], f.Ranges()[3]);
    // try f.VerifyBaselineDocumentHighlights(undefined, null , f.Ranges()[0], f.Ranges()[2], f.Ranges()[3]);
    // try f.VerifyBaselineGoToTypeDefinition(undefined, "use");
    // try f.VerifyBaselineGoToDefinition(undefined, false, "use");
}

test "TestUnusedFunctionInNamespace4" {
    const content =
        \\// @noUnusedLocals: true
        \\// @noUnusedParameters:true
        \\ [| namespace Validation {
        \\    var function1 = function() {
        \\    }
        \\} |]
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyRangeAfterCodeFix(undefined, "namespace Validation {\n}", false, 0, 0);
}

test "TestQuickInfoSignatureOptionalParameterFromUnion1" {
    const content =
        \\// @strict: false
        \\declare const optionals:
        \\  | ((a?: { a: true }) => unknown)
        \\  | ((b?: { b: true }) => unknown);
        \\
        \\/**/optionals();
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "const optionals: (arg0?: {\n    a: true;\n} & {\n    b: true;\n}) => unknown", "");
}

test "TestQuickInfoOnCatchVariable" {
    const content =
        \\// @strict: false
        \\function f() {
        \\   try { } catch (/**/e) { }
        \\}
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    try f.VerifyQuickInfoAt(undefined, "", "(local var) e: any", "");
}

test "TestRenameThis" {
    const content =
        \\function f([|this|]) {
        \\    return [|this|];
        \\}
        \\this/**/;
        \\const _ = { [|[|{| "contextRangeIndex": 2 |}this|]: 0|] }.[|this|];
    ;

    const f = fourslash.NewFourslash(undefined, undefined, content);
    defer f.deinit();
    _ = f.GoToMarker(undefined, "");
    // try f.VerifyRenameFailed(undefined, null );
    // try f.VerifyBaselineRename(undefined, null , f.Ranges()[0], f.Ranges()[1], f.Ranges()[3], f.Ranges()[4]);
}

test "TestCompletionsImport_46332" {
    const content =
        \\// @module: esnext
        \\// @moduleResolution: bundler
        \\// @Filename: /node_modules/vue/package.json
        \\{
        \\  "name": "vue",
        \\  "types": "dist/vue.d.ts"
        \\}
        \\// @Filename: /node_modules/vue/dist/vue.d.ts
        \\export * from "@vue/runtime-dom"
        \\// @Filename: /node_modules/@vue/runtime-dom/package.json
        \\{
        \\  "name": "@vue/runtime-dom",
        \\  "types": "dist/runtime-dom.d.ts"
        \\}
        \\// @Filename: /node_modules/@vue/runtime-dom/dist/runtime-dom.d.ts
        \\export * from "@vue/runtime-core";
        \\export {}
        \\declare module '@vue/reactivity' {
        \\  export interface RefUnwrapBailTypes {
        \\    runtimeDOMBailTypes: any
        \\  }
        \\}
        \\// @Filename: /node_modules/@vue/runtime-core/package.json
        \\{
        \\  "name": "@vue/runtime-core",
        \\  "types": "dist/runtime-core.d.ts"
        \\}
        \\// @Filename: /node_modules/@vue/runtime-core/dist/runtime-core.d.ts
        \\import { ref } from '@vue/reactivity';
        \\export { ref };
        \\declare module '@vue/reactivity' {
        \\  export interface RefUnwrapBailTypes {
        \\    runtimeCoreBailTypes: any
        \\  }
        \\}
        \\// @Filename: /node_modules/@vue/reactivity/package.json
        \\{
        \\  "name": "@vue/reactivity",
        \\  "types": "dist/reactivity.d.ts"
        \\}
        \\// @Filename: /node_modules/@vue/reactivity/dist/reactivity.d.ts
        \\export declare function ref<T = any>(): T;
        \\// @Filename: /package.json
        \\{
        \\  "dependencies": {
        \\    "vue": "*"
        \\  }
        \\}
        \\// @Filename: /index.ts
        \\import {} from "vue";
        \\ref/**/
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
//             .Includes = &.{
//                 &.{
//                     .Label = "ref",
//                     .Data = &.{
//                         .AutoImport = &.{
//                             .ModuleSpecifier = "vue",
//                         },
//                     },
//                     .AdditionalTextEdits = fourslash.AnyTextEdits,
//                     .SortText =            undefined(string(ls.SortTextAutoImportSuggestions)),
//                 },
//             },
//         },
//     });
    // try f.VerifyApplyCodeActionFromCompletion(undefined, undefined(""), &.{
//         .Name =          "ref",
//         .Source =        "vue",
//         .Description =   "Update import from \"vue\"",
//         .AutoImportFix = &.{},
//         .NewFileContent = undefined("import { ref } from \"vue\";\nref"),
//     });
}

