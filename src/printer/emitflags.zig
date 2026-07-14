const std = @import("std");

pub const EmitFlags = struct {
    pub const None: u32 = 0;
    pub const SingleLine: u32 = 1 << 0; // The contents of this node should be emitted on a single line.
    pub const MultiLine: u32 = 1 << 1; // The contents of this node should be emitted on multiple lines.
    pub const NoLeadingSourceMap: u32 = 1 << 2; // Do not emit a leading source map location for this node.
    pub const NoTrailingSourceMap: u32 = 1 << 3; // Do not emit a trailing source map location for this node.
    pub const NoNestedSourceMaps: u32 = 1 << 4; // Do not emit source map locations for children of this node.
    pub const NoTokenLeadingSourceMaps: u32 = 1 << 5; // Do not emit leading source map location for token nodes.
    pub const NoTokenTrailingSourceMaps: u32 = 1 << 6; // Do not emit trailing source map location for token nodes.
    pub const NoLeadingComments: u32 = 1 << 7; // Do not emit leading comments for this node.
    pub const NoTrailingComments: u32 = 1 << 8; // Do not emit trailing comments for this node.
    pub const NoNestedComments: u32 = 1 << 9; // Do not emit nested comments for children of this node.
    pub const HelperName: u32 = 1 << 10; // The Identifier refers to an *unscoped* emit helper (one that is emitted at the top of the file)
    pub const ExportName: u32 = 1 << 11; // Ensure an export prefix is added for an identifier that points to an exported declaration with a local name (see SymbolFlags.ExportHasLocal).
    pub const LocalName: u32 = 1 << 12; // Ensure an export prefix is not added for an identifier that points to an exported declaration.
    pub const Indented: u32 = 1 << 13; // Adds an explicit extra indentation level for class and function bodies when printing (used to match old emitter).
    pub const NoIndentation: u32 = 1 << 14; // Do not indent the node.
    pub const ReuseTempVariableScope: u32 = 1 << 15; // Reuse the existing temp variable scope during emit.
    pub const CustomPrologue: u32 = 1 << 16; // Treat the statement as if it were a prologue directive (NOTE: Prologue directives are *not* transformed).
    pub const NoAsciiEscaping: u32 = 1 << 17; // When synthesizing nodes that lack an original node or textSourceNode, we want to write the text on the node with ASCII escaping substitutions.
    pub const ExternalHelpers: u32 = 1 << 18; // This source file has external helpers
    pub const StartOnNewLine: u32 = 1 << 19; // Start this node on a new line
    pub const IndirectCall: u32 = 1 << 20; // Emit CallExpression as an indirect call: `(0, f)()`
    pub const AsyncFunctionBody: u32 = 1 << 21; // The node was originally an async function body.
    pub const NoLexicalArguments: u32 = 1 << 22; // Do not capture `arguments` for this arrow function. Set on arrows lowered from class static blocks, where `arguments` is an error; preserves Strada's emit behavior.
    pub const TransformPrivateStaticElements: u32 = 1 << 23; // Indicates static private elements in a file or class should be transformed regardless of --target (used by esDecorators transform).
    pub const NoLexicalThis: u32 = 1 << 24; // Do not capture `this` for this node's subtree. Set on relocated static initializers, where `this` is handled by the class fields transform.

    pub const NoSourceMap: u32 = NoLeadingSourceMap | NoTrailingSourceMap; // Do not emit a source map location for this node.
    pub const NoTokenSourceMaps: u32 = NoTokenLeadingSourceMaps | NoTokenTrailingSourceMaps; // Do not emit source map locations for tokens of this node.
    pub const NoComments: u32 = NoLeadingComments | NoTrailingComments; // Do not emit comments for this node.
};
