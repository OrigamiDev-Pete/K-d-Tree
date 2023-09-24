const std = @import("std");

// Represents a k-dimensional point.
pub const KPoint = struct {
    value: []const f32,

    pub fn equals(self: KPoint, other: KPoint) bool {
        for (self.value, other.value) |component1, component2| {
            if (component1 != component2) return false;
        }
        return true;
    }

    pub fn kCompare(self: KPoint, other: KPoint, k: u32) f32 {
        return other.value[k] - self.value[k];
    }

    pub fn dimensions(self: KPoint) u32 {
        return @intCast(self.value.len);
    }
};

pub const KBoundingRegion = struct {
    position: KPoint,
    size: KPoint,
};

pub const KDTree = struct {
    const KDNode = struct {
        left_child: ?*KDNode = null,
        right_child: ?*KDNode = null,
        point: KPoint,
        // Note(Pete): direction determines the dimension in the hyperspace to use when comparing.
        // Other implementations may store a level and compute the direction based on the dimensionality of the tree.
        direction: u32 = 0,
        allocator: ?std.mem.Allocator = null,

        fn search(self: KDNode, point: KPoint) bool {
            if (self.point.equals(point)) return true else if (self.point.kCompare(point, self.direction) < 0 and self.left_child) {
                return self.left_child.search(point);
            } else if (self.right_child) {
                return self.right_child.search(point);
            } else return false;
        }

        fn insert(self: *KDNode, point: KPoint, direction: u32, k: u32, allocator: std.mem.Allocator) !*KDNode {
            const newDirection = (direction + 1) % k;
            if (self.point.equals(point)) return self else if (self.point.kCompare(point, direction) < 0) {
                if (self.left_child != null) {
                    self.left_child = try self.left_child.?.insert(point, newDirection, k, allocator);
                    return self;
                } else {
                    var node = try allocator.create(KDNode);
                    node.* = KDNode{ .point = point, .direction = direction };
                    self.left_child = node;
                    return node;
                }
            } else {
                if (self.right_child != null) {
                    self.right_child = try self.right_child.?.insert(point, newDirection, k, allocator);
                    return self;
                } else {
                    var node = try allocator.create(KDNode);
                    node.* = KDNode{ .point = point, .direction = direction };
                    self.right_child = node;
                    return node;
                }
            }
        }
    };

    root: ?*KDNode,
    k: u32, // Number of dimensions
    allocator: std.mem.Allocator,

    pub fn init(points: []KPoint, alloctor: std.mem.Allocator) !KDTree {
        var tree = KDTree{ .root = null, .k = points[0].dimensions(), .allocator = alloctor };
        for (points) |point| {
            _ = try tree.insert(point);
        }
        return tree;
    }

    pub fn deinit(self: KDTree) void {
        self._deinit(self.root);
    }

    fn _deinit(self: KDTree, node: ?*KDNode) void {
        if (node) |n| {
            self._deinit(n.left_child);
            self._deinit(n.right_child);
            self.allocator.destroy(n);
        }
    }

    pub fn size(self: KDTree) u32 {
        _ = self;
        return 0;
    }

    pub fn isEmpty(self: KDTree) bool {
        return self.size() == 0;
    }

    pub fn insert(self: *KDTree, point: KPoint) !*KDNode {
        self.root = try self._insert(self.root, point, 0);
        return self.root.?;
    }

    fn _insert(self: KDTree, node: ?*KDNode, point: KPoint, direction: u32) !*KDNode {
        const newDirection = (direction + 1) % self.k;
        if (node == null) {
            const newNode = try self.allocator.create(KDNode);
            newNode.* = KDNode{ .point = point, .direction = direction };
            return newNode;
        } else if (node.?.point.equals(point)) { return node.?; }
        else if (node.?.point.kCompare(point, direction) < 0) {
            node.?.left_child = try self._insert(node.?.left_child, point, newDirection);
            return node.?;
        } else {
            node.?.right_child = try self._insert(node.?.right_child, point, newDirection);
            return node.?;
        }
    }

    pub fn remove(self: KDTree, point: KPoint) void {
        _ = point;
        _ = self;
    }

    pub fn search(self: KDTree, point: KPoint) bool {
        if (self.root == null)
            return false;
        return self.root.search(point);
    }

    pub fn nearestNeighbour(self: KDTree, point: KPoint) KPoint {
        _ = point;
        _ = self;
    }

    pub fn pointsInRegion(self: KDTree, region: KBoundingRegion) []KPoint {
        _ = region;
        _ = self;
    }

};