const std = @import("std");
const kdt = @import("kdTree.zig");
const KDTree = kdt.KDTree;
const KPoint = kdt.KPoint;

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

    var points = [_]KPoint{ 
        KPoint{ .value = &.{ 0.0, 5.0 } }, 
        KPoint{ .value = &.{ 1.0, -1.0 } },
        KPoint{ .value = &.{ -1.0, 6.0 } },
        KPoint{ .value = &.{ -1.0, 1.0 } },
        KPoint{ .value = &.{ 2.0, -5.0 } },
        KPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.init(points[0..], allocator);
    _ = try tree.insert(KPoint{ .value = &.{ -1.5, -2 } });
    _ = tree.isEmpty();

    var t = KDTree{ .root = null, .k = 1, .allocator = allocator };
    defer t.deinit();
    const node_a = try t.insert(KPoint { .value = &.{ 0.0 } });
    _ = node_a;

    const node_b = try t.insert(KPoint { .value = &.{ 5.0 } });
    _ = node_b;

    const node_c = try t.insert(KPoint { .value = &.{ 3.0 } });
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
    var tree = KDTree{ .root = null, .k = 1, .allocator = testing_allocator };
    defer tree.deinit();
    const root = try tree.insert(KPoint { .value = &.{ 0.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 0.0 }, root.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.direction);

    _ = try tree.insert(KPoint { .value = &.{ 5.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 5.0 }, root.right_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.right_child.?.direction);

    _ = try tree.insert(KPoint { .value = &.{ 3.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 3.0 }, root.right_child.?.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.right_child.?.left_child.?.direction);

    _ = try tree.insert(KPoint { .value = &.{ -1.0 } });
    try std.testing.expectEqualSlices(f32, &.{ -1.0 }, root.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.left_child.?.direction);
}

test "Insert 2D" {
    const testing_allocator = std.testing.allocator;
    var tree = KDTree{ .root = null, .k = 2, .allocator = testing_allocator };
    defer tree.deinit();
    const root = try tree.insert(KPoint { .value = &.{ 0.0, 0.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 0.0, 0.0 }, root.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.direction);

    _ = try tree.insert(KPoint { .value = &.{ 5.0, 2.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 5.0, 2.0 }, root.right_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 1), root.right_child.?.direction);

    _ = try tree.insert(KPoint { .value = &.{ 3.0, 1.0 } });
    try std.testing.expectEqualSlices(f32, &.{ 3.0, 1.0 }, root.right_child.?.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 0), root.right_child.?.left_child.?.direction);

    _ = try tree.insert(KPoint { .value = &.{ -1.0, -3.0 } });
    try std.testing.expectEqualSlices(f32, &.{ -1.0, -3.0 }, root.left_child.?.point.value);
    try std.testing.expectEqual(@as(u32, 1), root.left_child.?.direction);
}

test "Init Tree" {
    const testing_allocator = std.testing.allocator;
    var points = [_]KPoint{ 
        KPoint{ .value = &.{ 0.0, 5.0 } }, 
        KPoint{ .value = &.{ 1.0, -1.0 } },
        KPoint{ .value = &.{ -1.0, 6.0 } },
        KPoint{ .value = &.{ -1.0, 1.0 } },
        KPoint{ .value = &.{ 2.0, -5.0 } },
        KPoint{ .value = &.{ -0.5, 0.0 } },
    };
    var tree = try KDTree.init(points[0..], testing_allocator);
    defer tree.deinit();

    try std.testing.expectEqualSlices(f32, &.{ 2.0, -5.0 }, tree.root.?.right_child.?.left_child.?.point.value);
    try std.testing.expectEqualSlices(f32, &.{ -0.5, 0.0 }, tree.root.?.left_child.?.left_child.?.right_child.?.point.value);
}