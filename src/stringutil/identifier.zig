const std = @import("std");

pub fn isIdentifierStart(ch: u21, languageVersion: u8) bool {
    _ = languageVersion;
    if ((ch >= 'A' and ch <= 'Z') or (ch >= 'a' and ch <= 'z') or ch == '$' or ch == '_') {
        return true;
    }
    return false;
}

pub fn isIdentifierPart(ch: u21, languageVersion: u8) bool {
    _ = languageVersion;
    if ((ch >= 'A' and ch <= 'Z') or (ch >= 'a' and ch <= 'z') or (ch >= '0' and ch <= '9') or ch == '$' or ch == '_') {
        return true;
    }
    return false;
}
