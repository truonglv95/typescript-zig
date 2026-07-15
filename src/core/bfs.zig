const std = @import("std");

pub fn BFS(comptime T: type, allocator: std.mem.Allocator, start_node: T, get_neighbors: *const fn(std.mem.Allocator, T) anyerror![]T) ![]T {
    var visited = std.AutoHashMap(T, void).init(allocator);
    defer visited.deinit();

    var queue = std.ArrayList(T).init(allocator);
    defer queue.deinit();

    var result = std.ArrayList(T).init(allocator);

    try queue.append(start_node);
    try visited.put(start_node, {});

    while (queue.items.len > 0) {
        const current = queue.orderedRemove(0);
        try result.append(current);

        const neighbors = try get_neighbors(allocator, current);
        defer allocator.free(neighbors);

        for (neighbors) |neighbor| {
            if (!visited.contains(neighbor)) {
                try visited.put(neighbor, {});
                try queue.append(neighbor);
            }
        }
    }

    return result.toOwnedSlice();
}
