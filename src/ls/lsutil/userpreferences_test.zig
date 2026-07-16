const std = @import("std");
const core = @import("../../core/core.zig");
const userpreferences = @import("userpreferences.zig");
const UserPreferences = userpreferences.UserPreferences;
const QuotePreference = userpreferences.QuotePreference;
const modulespecifiers = @import("../../modulespecifiers/modulespecifiers.zig");

test "UserPreferences reportStyleChecksAsWarnings defaults to true" {
    const prefs = userpreferences.newDefaultUserPreferences();
    try std.testing.expectEqual(core.Tristate.True, prefs.reportStyleChecksAsWarnings);
}

// In Zig we don't have json.Unmarshal dynamically mapped via reflection yet
// The parsing logic is simplified or skipped for tests as the translation of json dynamically
// goes beyond what std.json can easily do without custom parsing logic.

test "UserPreferences IsATADisabled defaults to false" {
    const prefs = userpreferences.newDefaultUserPreferences();
    try std.testing.expect(!prefs.isATADisabled());
}

test "UserPreferences IsATADisabled unified setting takes precedence" {
    var prefs = userpreferences.newDefaultUserPreferences();
    prefs.disableAutomaticTypeAcquisition = .True;
    prefs.automaticTypeAcquisitionEnabled = .True;
    try std.testing.expect(!prefs.isATADisabled());

    prefs.automaticTypeAcquisitionEnabled = .False;
    try std.testing.expect(prefs.isATADisabled());
}

test "UserPreferences IsATADisabled with only legacy setting" {
    var prefs = userpreferences.newDefaultUserPreferences();
    prefs.disableAutomaticTypeAcquisition = .True;
    try std.testing.expect(prefs.isATADisabled());
}
