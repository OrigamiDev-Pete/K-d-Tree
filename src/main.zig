const std = @import("std");
const kdt = @import("kdTree.zig");
const KDTree = kdt.KDTree;
const KPoint = kdt.KPoint;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    var point = KPoint{ .value = &.{ 1.0 } };
    var points = [_]KPoint{ point };
    const tree = KDTree.init(points[0..], allocator);
    _ = tree.isEmpty();

}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "example test" {
    try std.testing.expectEqual(39, 39);
}

