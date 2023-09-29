const std = @import("std");
const kdt = @import("kdTree.zig");
const KDTree = kdt.KDTree;
const KDPoint = kdt.KDPoint;

const raylib = @import("raylib");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var screenWidth: i32 = 800;
var screenHeight: i32 = 600;

pub fn main() !void {
    var points = [_]KDPoint{
        KDPoint{ .value = &.{ 0.0, 5.0 } },
        KDPoint{ .value = &.{ 1.0, -1.0 } },
        KDPoint{ .value = &.{ -1.0, 1.0 } },
        KDPoint{ .value = &.{ -1.0, 6.0 } },
        KDPoint{ .value = &.{ 2.0, -5.0 } },
        KDPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.createBalanced(points[0..], allocator);
    // _ = try tree.insert(KDPoint{ .value = &.{ -1.5, -2 } });

    var nn: KDPoint = undefined;
    var dist = tree.nearestNeighbour(KDPoint{ .value = &.{ 0.5, 4.5 } }, &nn);
    _ = dist;

    var nnn = try tree.nNearestNeighbours(KDPoint{ .value = &.{ 0.5, 4.5 } }, 5, allocator);
    defer allocator.free(nnn);

    var r = try tree.remove(KDPoint{ .value = &.{ -0.5, 0.0 } });
    r = try tree.remove(KDPoint{ .value = &.{ 0.0, 5.0 } });
    _ = tree.isEmpty();
    tree.destroy();

    var arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    var t = KDTree{ .root = null, .k = 1, .allocator = arena.allocator(), .arena = arena };
    defer t.destroy();
    const node_a = try t.insert(KDPoint{ .value = &.{0.0} });
    _ = node_a;

    const node_b = try t.insert(KDPoint{ .value = &.{5.0} });
    _ = node_b;

    const node_c = try t.insert(KDPoint{ .value = &.{3.0} });
    _ = node_c;
    _ = t.isEmpty();
}

test "Insert 1D" {
    const testing_allocator = std.testing.allocator;
    var arena = try testing_allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(testing_allocator);

    var tree = KDTree{ .root = null, .k = 1, .allocator = arena.allocator(), .arena = arena };
    defer tree.destroy();
    const root = try tree.insert(KDPoint{ .value = &.{0.0} });
    try std.testing.expectEqualSlices(f32, &.{0.0}, root.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.direction);

    _ = try tree.insert(KDPoint{ .value = &.{5.0} });
    try std.testing.expectEqualSlices(f32, &.{5.0}, root.right_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.right_child.?.direction);

    _ = try tree.insert(KDPoint{ .value = &.{3.0} });
    try std.testing.expectEqualSlices(f32, &.{3.0}, root.right_child.?.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.right_child.?.left_child.?.direction);

    _ = try tree.insert(KDPoint{ .value = &.{-1.0} });
    try std.testing.expectEqualSlices(f32, &.{-1.0}, root.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.left_child.?.direction);
}

test "Insert 2D" {
    const testing_allocator = std.testing.allocator;
    var arena = try testing_allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(testing_allocator);

    var tree = KDTree{ .root = null, .k = 2, .allocator = arena.allocator(), .arena = arena };
    defer tree.destroy();
    const root = try tree.insert(KDPoint{ .value = &.{ 0.0, 0.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 0.0, 0.0 }, root.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.direction);

    _ = try tree.insert(KDPoint{ .value = &.{ 5.0, 2.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 5.0, 2.0 }, root.right_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 1), root.right_child.?.direction);

    _ = try tree.insert(KDPoint{ .value = &.{ 3.0, 1.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 3.0, 1.0 }, root.right_child.?.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.right_child.?.left_child.?.direction);

    _ = try tree.insert(KDPoint{ .value = &.{ -1.0, -3.0 } });
    try std.testing.expectEqualSlices(f32, &.{ -1.0, -3.0 }, root.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 1), root.left_child.?.direction);
}

test "Init Balanced Tree" {
    const testing_allocator = std.testing.allocator;
    var points = [_]KDPoint{
        KDPoint{ .value = &.{ 0.0, 5.0 } },
        KDPoint{ .value = &.{ 1.0, -1.0 } },
        KDPoint{ .value = &.{ -1.0, 6.0 } },
        KDPoint{ .value = &.{ -1.0, 1.0 } },
        KDPoint{ .value = &.{ 2.0, -5.0 } },
        KDPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.createBalanced(points[0..], testing_allocator);
    defer tree.destroy();

    try std.testing.expectEqualSlices(f32, &.{ 0.0, 5.0 }, tree.root.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), tree.root.?.direction);

    try std.testing.expectEqualSlices(f32, &.{ 1.0, -1.0 }, tree.root.?.right_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 1), tree.root.?.right_child.?.direction);

    try std.testing.expectEqualSlices(f32, &.{ 2.0, -5.0 }, tree.root.?.right_child.?.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), tree.root.?.right_child.?.left_child.?.direction);

    try std.testing.expectEqualSlices(f32, &.{ -1.0, 1.0 }, tree.root.?.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 1), tree.root.?.left_child.?.direction);

    try std.testing.expectEqualSlices(f32, &.{ -1.0, 6.0 }, tree.root.?.left_child.?.right_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), tree.root.?.left_child.?.right_child.?.direction);

    try std.testing.expectEqualSlices(f32, &.{ -0.5, 0.0 }, tree.root.?.left_child.?.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), tree.root.?.left_child.?.left_child.?.direction);
}

test "Search" {
    const testing_allocator = std.testing.allocator;
    var points = [_]KDPoint{
        KDPoint{ .value = &.{ 0.0, 5.0 } },
        KDPoint{ .value = &.{ 1.0, -1.0 } },
        KDPoint{ .value = &.{ -1.0, 6.0 } },
        KDPoint{ .value = &.{ -1.0, 1.0 } },
        KDPoint{ .value = &.{ 2.0, -5.0 } },
        KDPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.createBalanced(points[0..], testing_allocator);
    defer tree.destroy();

    var result = tree.search(KDPoint{ .value = &.{ 0.0, 5.0 } });
    try std.testing.expect(result);

    result = tree.search(KDPoint{ .value = &.{ 2.0, -5.0 } });
    try std.testing.expect(result);

    result = tree.search(KDPoint{ .value = &.{ 20.0, -5.0 } });
    try std.testing.expect(!result);
}

test "Remove Root Node" {
    const testing_allocator = std.testing.allocator;
    var points = [_]KDPoint{
        KDPoint{ .value = &.{ 0.0, 5.0 } },
        KDPoint{ .value = &.{ 1.0, -1.0 } },
        KDPoint{ .value = &.{ -1.0, 6.0 } },
        KDPoint{ .value = &.{ -1.0, 1.0 } },
        KDPoint{ .value = &.{ 2.0, -5.0 } },
        KDPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.createBalanced(points[0..], testing_allocator);
    defer tree.destroy();

    var result = try tree.remove(KDPoint{ .value = &.{ 0.0, 5.0 } });
    try std.testing.expect(result);

    result = try tree.remove(KDPoint{ .value = &.{ 0.0, 5.0 } });
    try std.testing.expect(!result);

    try std.testing.expectEqual(@as(usize, 5), tree.size());
}

test "Remove Node With Only Left Child" {
    const testing_allocator = std.testing.allocator;
    var points = [_]KDPoint{
        KDPoint{ .value = &.{ 0.0, 5.0 } },
        KDPoint{ .value = &.{ 1.0, -1.0 } },
        KDPoint{ .value = &.{ -1.0, 6.0 } },
        KDPoint{ .value = &.{ -1.0, 1.0 } },
        KDPoint{ .value = &.{ 2.0, -5.0 } },
        KDPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.createBalanced(points[0..], testing_allocator);
    defer tree.destroy();

    var result = try tree.remove(KDPoint{ .value = &.{ 1.0, -1.0 } });
    try std.testing.expect(result);

    result = try tree.remove(KDPoint{ .value = &.{ 1.0, -1.0 } });
    try std.testing.expect(!result);

    try std.testing.expectEqual(@as(usize, 5), tree.size());
}

test "Remove Leaf Node" {
    const testing_allocator = std.testing.allocator;
    var points = [_]KDPoint{
        KDPoint{ .value = &.{ 0.0, 5.0 } },
        KDPoint{ .value = &.{ 1.0, -1.0 } },
        KDPoint{ .value = &.{ -1.0, 6.0 } },
        KDPoint{ .value = &.{ -1.0, 1.0 } },
        KDPoint{ .value = &.{ 2.0, -5.0 } },
        KDPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.createBalanced(points[0..], testing_allocator);
    defer tree.destroy();

    var result = try tree.remove(KDPoint{ .value = &.{ -1.0, 6.0 } });
    try std.testing.expect(result);

    result = try tree.remove(KDPoint{ .value = &.{ -1.0, 6.0 } });
    try std.testing.expect(!result);

    try std.testing.expectEqual(@as(usize, 5), tree.size());
}

test "Remove Node With Only Right Child" {
    const testing_allocator = std.testing.allocator;
    var points = [_]KDPoint{
        KDPoint{ .value = &.{ 0.0, 5.0 } },
        KDPoint{ .value = &.{ 1.0, -1.0 } },
        KDPoint{ .value = &.{ -1.0, 6.0 } },
        KDPoint{ .value = &.{ -1.0, 1.0 } },
        KDPoint{ .value = &.{ 2.0, -5.0 } },
        KDPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.createBalanced(points[0..], testing_allocator);
    defer tree.destroy();

    _ = try tree.insert(KDPoint{ .value = &.{ 3, -2 } });

    var result = try tree.remove(KDPoint{ .value = &.{ 2.0, -5.0 } });
    try std.testing.expect(result);

    result = try tree.remove(KDPoint{ .value = &.{ 2.0, -5.0 } });
    try std.testing.expect(!result);

    try std.testing.expectEqual(@as(usize, 6), tree.size());
}

test "Nearest Neighbour" {
    const testing_allocator = std.testing.allocator;
    var points = [_]KDPoint{
        KDPoint{ .value = &.{ 0.0, 5.0 } },
        KDPoint{ .value = &.{ 1.0, -1.0 } },
        KDPoint{ .value = &.{ -1.0, 6.0 } },
        KDPoint{ .value = &.{ -1.0, 1.0 } },
        KDPoint{ .value = &.{ 2.0, -5.0 } },
        KDPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.createBalanced(points[0..], testing_allocator);
    defer tree.destroy();

    var nearest_point: KDPoint = undefined;
    var distance = tree.nearestNeighbour(KDPoint{ .value = &.{ 0.5, 4.5 } }, &nearest_point);

    try std.testing.expectEqualSlices(f32, &.{ 0.0, 5.0 }, nearest_point.value);
    try std.testing.expectApproxEqRel(@as(f32, 0.7071), distance, @as(f32, 0.001));

    distance = tree.nearestNeighbour(KDPoint{ .value = &.{ 2.5, -5.0 } }, &nearest_point);
    try std.testing.expectEqualSlices(f32, &.{ 2.0, -5.0 }, nearest_point.value);
    try std.testing.expectApproxEqRel(@as(f32, 0.5), distance, @as(f32, 0.001));

    distance = tree.nearestNeighbour(KDPoint{ .value = &.{ 20.0, 50.0 } }, &nearest_point);
    try std.testing.expectEqualSlices(f32, &.{ -1.0, 6.0 }, nearest_point.value);
    try std.testing.expectApproxEqRel(@as(f32, 48.7544), distance, @as(f32, 0.001));
}

test "N Nearest Neighbours" {
    const testing_allocator = std.testing.allocator;
    var points = [_]KDPoint{
        KDPoint{ .value = &.{ 0.0, 5.0 } },
        KDPoint{ .value = &.{ 1.0, -1.0 } },
        KDPoint{ .value = &.{ -1.0, 6.0 } },
        KDPoint{ .value = &.{ -1.0, 1.0 } },
        KDPoint{ .value = &.{ 2.0, -5.0 } },
        KDPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.createBalanced(points[0..], testing_allocator);
    defer tree.destroy();

    const nearest_neighbours = try tree.nNearestNeighbours(KDPoint{ .value = &.{ 0.5, 4.5 } }, 3, testing_allocator);
    defer testing_allocator.free(nearest_neighbours);

    try std.testing.expectEqualSlices(f32, &.{ 0.0, 5.0 }, nearest_neighbours[0].point.?.value);
    try std.testing.expectApproxEqRel(@as(f32, 0.7071), nearest_neighbours[0].distance, @as(f32, 0.001));

    try std.testing.expectEqualSlices(f32, &.{ -1.0, 6.0 }, nearest_neighbours[1].point.?.value);
    try std.testing.expectApproxEqRel(@as(f32, 2.121), nearest_neighbours[1].distance, @as(f32, 0.001));

    try std.testing.expectEqualSlices(f32, &.{ -1.0, 1.0 }, nearest_neighbours[2].point.?.value);
    try std.testing.expectApproxEqRel(@as(f32, 3.807), nearest_neighbours[2].distance, @as(f32, 0.001));
}
