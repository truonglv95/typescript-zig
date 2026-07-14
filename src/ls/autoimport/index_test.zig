const std = @import("std");
const testing = std.testing;
const Index = @import("index.zig").Index;

const TestEntry = struct {
    name_val: []const u8,
    package_: []const u8,

    pub fn name(self: TestEntry) []const u8 {
        return self.name_val;
    }
};

test "Index filters entries by package" {
    const allocator = testing.allocator;

    var idx = Index(TestEntry).init();
    defer idx.deinit(allocator);

    try idx.insertAsWords(allocator, .{ .name_val = "fooBar", .package_ = "pkg-a" });
    try idx.insertAsWords(allocator, .{ .name_val = "bazQux", .package_ = "pkg-b" });
    try idx.insertAsWords(allocator, .{ .name_val = "fooQux", .package_ = "pkg-a" });

    // Clone excluding pkg-b
    const FilterContext = struct {
        fn filter(e: TestEntry) bool {
            return !std.mem.eql(u8, e.package_, "pkg-b");
        }
    };
    
    var cloned = try idx.clone(allocator, FilterContext.filter);
    defer cloned.deinit(allocator);

    // Original should have all 3 entries
    try testing.expectEqual(@as(usize, 3), idx.entries.items.len);

    // Cloned should have 2 entries (only pkg-a)
    try testing.expectEqual(@as(usize, 2), cloned.entries.items.len);

    // Search should work on cloned index
    const results1 = try cloned.find(allocator, "fooBar", true);
    defer allocator.free(results1);
    try testing.expectEqual(@as(usize, 1), results1.len);
    try testing.expectEqualStrings("fooBar", results1[0].name_val);

    // bazQux should not be in cloned index
    const results2 = try cloned.find(allocator, "bazQux", true);
    defer allocator.free(results2);
    try testing.expectEqual(@as(usize, 0), results2.len);

    // Word prefix search should work
    const results3 = try cloned.searchWordPrefix(allocator, "foo");
    defer allocator.free(results3);
    try testing.expectEqual(@as(usize, 2), results3.len);
}

test "Index handles empty index" {
    const allocator = testing.allocator;

    var idx = Index(TestEntry).init();
    defer idx.deinit(allocator);

    const FilterContext = struct {
        fn filter(e: TestEntry) bool {
            _ = e;
            return true;
        }
    };

    var cloned = try idx.clone(allocator, FilterContext.filter);
    defer cloned.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), cloned.entries.items.len);
}

test "Index filters all entries" {
    const allocator = testing.allocator;

    var idx = Index(TestEntry).init();
    defer idx.deinit(allocator);

    try idx.insertAsWords(allocator, .{ .name_val = "fooBar", .package_ = "pkg-a" });
    try idx.insertAsWords(allocator, .{ .name_val = "bazQux", .package_ = "pkg-b" });

    const FilterContext = struct {
        fn filter(e: TestEntry) bool {
            _ = e;
            return false;
        }
    };

    var cloned = try idx.clone(allocator, FilterContext.filter);
    defer cloned.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), cloned.entries.items.len);
    try testing.expectEqual(@as(u32, 0), cloned.index.count());
}
