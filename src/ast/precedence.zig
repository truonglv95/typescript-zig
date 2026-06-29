const std = @import("std");
const ast = @import("ast.zig");
const ast_gen = @import("ast_generated.zig");
const kind = @import("kind.zig");
const ast_utils = @import("ast_utils.zig");

pub const OperatorPrecedence = enum(i32) {
    Invalid = -1,
    Comma = 0,
    Spread = 1,
    Yield = 2,
    Assignment = 3,
    Conditional = 4,
    LogicalOR = 5,
    LogicalAND = 6,
    BitwiseOR = 7,
    BitwiseXOR = 8,
    BitwiseAND = 9,
    Equality = 10,
    Relational = 11,
    Shift = 12,
    Additive = 13,
    Multiplicative = 14,
    Exponentiation = 15,
    Unary = 16,
    Update = 17,
    LeftHandSide = 18,
    OptionalChain = 19,
    Member = 20,
    Primary = 21,
    Parentheses = 22,

    pub const Coalesce = OperatorPrecedence.LogicalOR;
    pub const Lowest = OperatorPrecedence.Comma;
    pub const Highest = OperatorPrecedence.Parentheses;
};

pub const OperatorPrecedenceFlags = packed struct {
    NewWithoutArguments: bool = false,
    OptionalChain: bool = false,
};

pub fn getOperator(tree: *ast.Ast, node: ast_gen.NodeIndex) kind.Kind {
    const nodeData = tree.getNode(node);
    return switch (nodeData) {
        .BinaryExpression => |n| std.meta.activeTag(tree.getNode(n.OperatorToken)),
        .PrefixUnaryExpression => |n| @enumFromInt(n.Operator),
        .PostfixUnaryExpression => |n| @enumFromInt(n.Operator),
        else => std.meta.activeTag(nodeData),
    };
}

pub fn getExpressionPrecedence(tree: *ast.Ast, node: ast_gen.NodeIndex) OperatorPrecedence {
    if (node == 0) return .Invalid;
    const nodeData = tree.getNode(node);
    const op = getOperator(tree, node);
    var flags = OperatorPrecedenceFlags{};
    if (nodeData == .NewExpression) {
        if (nodeData.NewExpression.Arguments == 0) {
            flags.NewWithoutArguments = true;
        }
    } else if (ast_utils.isOptionalChain(tree, node)) {
        flags.OptionalChain = true;
    }
    return getOperatorPrecedence(tree, std.meta.activeTag(nodeData), op, flags);
}

pub fn getOperatorPrecedence(tree: *ast.Ast, nodeKind: kind.Kind, operatorKind: kind.Kind, flags: OperatorPrecedenceFlags) OperatorPrecedence {
    _ = tree;
    switch (nodeKind) {
        .SpreadElement => return .Spread,
        .YieldExpression => return .Yield,
        .ArrowFunction => return .Assignment,
        .ConditionalExpression => return .Conditional,
        .BinaryExpression => {
            switch (operatorKind) {
                .CommaToken => return .Comma,
                .EqualsToken, .PlusEqualsToken, .MinusEqualsToken, .AsteriskAsteriskEqualsToken, .AsteriskEqualsToken, .SlashEqualsToken, .PercentEqualsToken, .LessThanLessThanEqualsToken, .GreaterThanGreaterThanEqualsToken, .GreaterThanGreaterThanGreaterThanEqualsToken, .AmpersandEqualsToken, .CaretEqualsToken, .BarEqualsToken, .BarBarEqualsToken, .AmpersandAmpersandEqualsToken, .QuestionQuestionEqualsToken => return .Assignment,
                else => return getBinaryOperatorPrecedence(operatorKind),
            }
        },
        .TypeAssertionExpression, .NonNullExpression, .PrefixUnaryExpression, .TypeOfExpression, .VoidExpression, .DeleteExpression, .AwaitExpression => return .Unary,

        .PostfixUnaryExpression => return .Update,

        .PropertyAccessExpression, .ElementAccessExpression => {
            if (flags.OptionalChain) return .OptionalChain;
            return .Member;
        },

        .CallExpression => {
            if (flags.OptionalChain) return .OptionalChain;
            return .Member;
        },

        .NewExpression => {
            if (flags.NewWithoutArguments) return .LeftHandSide;
            return .Member;
        },

        .TaggedTemplateExpression, .MetaProperty, .ExpressionWithTypeArguments => return .Member,

        .AsExpression, .SatisfiesExpression => return .Relational,

        .ThisKeyword, .SuperKeyword, .ImportKeyword, .Identifier, .PrivateIdentifier, .NullKeyword, .TrueKeyword, .FalseKeyword, .NumericLiteral, .BigIntLiteral, .StringLiteral, .ArrayLiteralExpression, .ObjectLiteralExpression, .FunctionExpression, .ClassExpression, .RegularExpressionLiteral, .NoSubstitutionTemplateLiteral, .TemplateExpression, .OmittedExpression, .JsxElement, .JsxSelfClosingElement, .JsxFragment, .MissingDeclaration => return .Primary,

        .ParenthesizedExpression => return .Parentheses,

        else => return .Invalid,
    }
}

pub fn getBinaryOperatorPrecedence(operatorKind: kind.Kind) OperatorPrecedence {
    switch (operatorKind) {
        .QuestionQuestionToken => return .Coalesce,
        .BarBarToken => return .LogicalOR,
        .AmpersandAmpersandToken => return .LogicalAND,
        .BarToken => return .BitwiseOR,
        .CaretToken => return .BitwiseXOR,
        .AmpersandToken => return .BitwiseAND,
        .EqualsEqualsToken, .ExclamationEqualsToken, .EqualsEqualsEqualsToken, .ExclamationEqualsEqualsToken => return .Equality,
        .LessThanToken, .GreaterThanToken, .LessThanEqualsToken, .GreaterThanEqualsToken, .InstanceOfKeyword, .InKeyword, .AsKeyword, .SatisfiesKeyword => return .Relational,
        .LessThanLessThanToken, .GreaterThanGreaterThanToken, .GreaterThanGreaterThanGreaterThanToken => return .Shift,
        .PlusToken, .MinusToken => return .Additive,
        .AsteriskToken, .SlashToken, .PercentToken => return .Multiplicative,
        .AsteriskAsteriskToken => return .Exponentiation,
        else => return .Invalid,
    }
}

pub fn getLeftmostExpression(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex, stopAtCallExpressions: bool) ast_gen.NodeIndex {
    var node = nodeIndex;
    while (node != 0) {
        const nodeData = tree.getNode(node);
        switch (nodeData) {
            .PostfixUnaryExpression => |n| {
                node = n.Operand;
                continue;
            },
            .BinaryExpression => |n| {
                node = n.Left;
                continue;
            },
            .ConditionalExpression => |n| {
                node = n.Condition;
                continue;
            },
            .TaggedTemplateExpression => |n| {
                node = n.Tag;
                continue;
            },
            .CallExpression => |n| {
                if (stopAtCallExpressions) {
                    return node;
                }
                node = n.Expression;
                continue;
            },
            .AsExpression => |n| {
                node = n.Expression;
                continue;
            },
            .ElementAccessExpression => |n| {
                node = n.Expression;
                continue;
            },
            .PropertyAccessExpression => |n| {
                node = n.Expression;
                continue;
            },
            .NonNullExpression => |n| {
                node = n.Expression;
                continue;
            },
            .PartiallyEmittedExpression => |n| {
                node = n.Expression;
                continue;
            },
            .SatisfiesExpression => |n| {
                node = n.Expression;
                continue;
            },
            else => {},
        }
        break;
    }
    return node;
}

pub fn skipPartiallyEmittedExpressions(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) ast_gen.NodeIndex {
    var node = nodeIndex;
    while (node != 0) {
        const nodeData = tree.getNode(node);
        if (nodeData == .PartiallyEmittedExpression) {
            node = nodeData.PartiallyEmittedExpression.Expression;
        } else {
            break;
        }
    }
    return node;
}

pub fn isBinaryOperation(tree: *ast.Ast, node: ast_gen.NodeIndex, op: kind.Kind) bool {
    if (node == 0) return false;
    const nodeData = tree.getNode(node);
    if (nodeData == .BinaryExpression) {
        return std.meta.activeTag(tree.getNode(nodeData.BinaryExpression.OperatorToken)) == op;
    }
    return false;
}

pub fn isLiteralKind(k: kind.Kind) bool {
    return switch (k) {
        .NumericLiteral, .BigIntLiteral, .StringLiteral, .JsxText, .JsxTextAllWhiteSpaces, .RegularExpressionLiteral, .NoSubstitutionTemplateLiteral => true,
        else => false,
    };
}

pub fn mixingBinaryOperatorsRequiresParentheses(a: kind.Kind, b: kind.Kind) bool {
    if (a == .QuestionQuestionToken) {
        return b == .AmpersandAmpersandToken or b == .BarBarToken;
    }
    if (b == .QuestionQuestionToken) {
        return a == .AmpersandAmpersandToken or a == .BarBarToken;
    }
    return false;
}

pub fn getLiteralKindOfBinaryPlusOperand(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) kind.Kind {
    const node = skipPartiallyEmittedExpressions(tree, nodeIndex);
    if (node == 0) return .Unknown;
    const k = std.meta.activeTag(tree.getNode(node));
    if (isLiteralKind(k)) {
        return k;
    }
    if (k == .BinaryExpression) {
        const n = tree.getNode(node).BinaryExpression;
        if (std.meta.activeTag(tree.getNode(n.OperatorToken)) == .PlusToken) {
            const leftKind = getLiteralKindOfBinaryPlusOperand(tree, n.Left);
            if (isLiteralKind(leftKind) and leftKind == getLiteralKindOfBinaryPlusOperand(tree, n.Right)) {
                return leftKind;
            }
        }
    }
    return .Unknown;
}

pub fn getBinaryExpressionPrecedence(tree: *ast.Ast, nodeIndex: ast_gen.NodeIndex) struct { left: OperatorPrecedence, right: OperatorPrecedence } {
    const node = tree.getNode(nodeIndex).BinaryExpression;
    const precedence = getExpressionPrecedence(tree, nodeIndex);
    var leftPrec = precedence;
    var rightPrec = precedence;
    switch (precedence) {
        .Comma => {},
        .Assignment => {
            leftPrec = .Conditional;
            rightPrec = .Yield;
        },
        .LogicalOR => {
            rightPrec = .LogicalAND;
        },
        .LogicalAND => {
            rightPrec = .BitwiseOR;
        },
        .BitwiseOR, .BitwiseXOR, .BitwiseAND => {},
        .Equality => {
            rightPrec = .Relational;
        },
        .Relational => {
            rightPrec = .Shift;
        },
        .Shift => {
            rightPrec = .Additive;
        },
        .Additive => {
            if (std.meta.activeTag(tree.getNode(node.OperatorToken)) == .PlusToken and isBinaryOperation(tree, node.Right, .PlusToken)) {
                const leftKind = getLiteralKindOfBinaryPlusOperand(tree, node.Left);
                if (isLiteralKind(leftKind) and leftKind == getLiteralKindOfBinaryPlusOperand(tree, node.Right)) {
                    return .{ .left = leftPrec, .right = rightPrec };
                }
            }
            rightPrec = .Multiplicative;
        },
        .Multiplicative => {
            if (std.meta.activeTag(tree.getNode(node.OperatorToken)) == .AsteriskToken and isBinaryOperation(tree, node.Right, .AsteriskToken)) {
                return .{ .left = leftPrec, .right = rightPrec };
            }
            rightPrec = .Exponentiation;
        },
        .Exponentiation => {
            leftPrec = .Update;
        },
        else => unreachable,
    }
    return .{ .left = leftPrec, .right = rightPrec };
}
