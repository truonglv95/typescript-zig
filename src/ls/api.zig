const std = @import("std");
const ast = @import("../ast/ast.zig");
// const astnav = @import("../astnav/astnav.zig");
const checker = @import("../checker/checker.zig");

pub const ErrNoSourceFile = error.NoSourceFile;
pub const ErrNoTokenAtPosition = error.NoTokenAtPosition;

pub const LanguageService = struct {
    // fields will be added as we port LanguageService
};
