const std = @import("std");
const ast = @import("../ast/ast.zig");
const checker = @import("../checker/checker.zig");

pub const ErrNoSourceFile = error.NoSourceFile;
pub const ErrNoTokenAtPosition = error.NoTokenAtPosition;
