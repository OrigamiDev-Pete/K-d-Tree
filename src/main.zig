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
    // raylib.SetConfigFlags(raylib.ConfigFlags{ .FLAG_WINDOW_RESIZABLE = true });
    // raylib.InitWindow(screenWidth, screenHeight, "hello world!");
    // raylib.SetTargetFPS(60);
    // defer raylib.CloseWindow();

    var points = [_]KDPoint{
        KDPoint{ .value = &.{ 0.0, 5.0 } },
        KDPoint{ .value = &.{ 1.0, -1.0 } },
        KDPoint{ .value = &.{ -1.0, 1.0 } },
        KDPoint{ .value = &.{ -1.0, 6.0 } },
        KDPoint{ .value = &.{ 2.0, -5.0 } },
        KDPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.createBalanced(points[0..], allocator);
    _ = try tree.insert(KDPoint{ .value = &.{ -1.5, -2 } });
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

    // while (!raylib.WindowShouldClose()) {
    //     if (raylib.IsWindowResized()) {
    //         screenWidth = raylib.GetScreenWidth();
    //         screenHeight = raylib.GetScreenHeight();
    //     }

    //     const screenXMiddle = @divTrunc(screenWidth, 2);
    //     const screenYMiddle = @divTrunc(screenHeight, 2);

    //     raylib.BeginDrawing();
    //     defer raylib.EndDrawing();

    //     raylib.DrawLine(screenXMiddle, 0, screenXMiddle, screenHeight, raylib.GRAY);
    //     raylib.DrawLine(0, screenYMiddle, screenWidth, screenYMiddle, raylib.GRAY);

    //     for (points) |p| {
    //         raylib.DrawCircle(@as(i32, @intFromFloat(p.value[0])) + screenXMiddle, screenYMiddle - @as(i32, @intFromFloat(p.value[1])), 3, raylib.RED);
    //     }

    //     raylib.ClearBackground(raylib.WHITE);
    //     raylib.DrawFPS(10, 10);
    // }
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

    _ = try tree.insert(KDPoint { .value = &.{ 5.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 5.0 }, root.right_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.right_child.?.direction);

    _ = try tree.insert(KDPoint { .value = &.{ 3.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 3.0 }, root.right_child.?.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.right_child.?.left_child.?.direction);

    _ = try tree.insert(KDPoint { .value = &.{ -1.0 } });
    try std.testing.expectEqualSlices(f32, &.{ -1.0 }, root.left_child.?.point.value);
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
    try std.testing.expect(result);

}
