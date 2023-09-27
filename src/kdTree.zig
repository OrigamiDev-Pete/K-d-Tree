const std = @import("std");

// Represents a k-dimensional point.
pub const KDPoint = struct {
    value: []const f32,

    pub fn equals(self: KDPoint, other: KDPoint) bool {
        for (self.value, other.value) |component1, component2| {
            if (component1 != component2) return false;
        }
        return true;
    }

    pub fn kCompare(self: KDPoint, other: KDPoint, k: u32) f32 {
        const result = other.value[k] - self.value[k];
        // To improve tree balance we decide whether to favour a direction on equal comparisons by whether the k dimension is odd or even.
        if (result == 0) {
            return if (k % 2 == 0) -1 else 1;
        } else {
            return result;
        }
    }

    pub fn dimensions(self: KDPoint) u32 {
        return @intCast(self.value.len);
    }
};

pub const KBoundingRegion = struct {
    position: KDPoint,
    size: KDPoint,
};

const PartitionResult = struct {
    median: KDPoint,
    left: []KDPoint,
    right: []KDPoint,
};

pub const KDTree = struct {
    const KDNode = struct {
        left_child: ?*KDNode = null,
        right_child: ?*KDNode = null,
        point: KDPoint,
        // Note(Pete): direction determines the dimension in the hyperspace to use when comparing.
        // Other implementations may store a level and compute the direction based on the dimensionality of the tree.
        direction: u32 = 0,
    };

    root: ?*KDNode,
    k: u32, // Number of dimensions
    allocator: std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,

    pub fn create(points: []KDPoint, allocator: std.mem.Allocator) !KDTree {
        var arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        var tree = KDTree{ .root = null, .k = points[0].dimensions(), .allocator = arena.allocator(), .arena = arena };
        for (points) |point| {
            _ = try tree.insert(point);
        }
        return tree;
    }

    pub fn createBalanced(points: []KDPoint, allocator: std.mem.Allocator) !KDTree {
        var arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        var k: u32 = 0;
        if (points.len > 0) {
            k = points[0].dimensions();
        }
        var tree = KDTree{ .root = null, .k = k, .allocator = arena.allocator(), .arena = arena };
        tree.root = try _createBalanced(points, 0, tree.k, tree.allocator);

        return tree;
    }

    fn _createBalanced(points: []KDPoint, level: u32, k: u32, allocator: std.mem.Allocator) !?*KDNode {
        if (points.len == 0) {
            return null;
        } else if (points.len == 1) {
            const n = try allocator.create(KDNode);
            n.* = KDNode{ .point = points[0], .direction = level % k };
            return n;
        } else {
            const result = try partition(points, level % k, allocator);
            const left_tree = try _createBalanced(result.left, level + 1, k, allocator);
            const right_tree = try _createBalanced(result.right, level + 1, k, allocator);
            const n = try allocator.create(KDNode);
            n.* = KDNode{ .point = result.median, .left_child = left_tree, .right_child = right_tree, .direction = level % k };
            return n;
        }
    }

    pub fn destroy(self: *KDTree) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }

    fn _destroy(self: KDTree, node: ?*KDNode) void {
        if (node) |n| {
            self.allocator.destroy(n.point.value);
            self._destroy(n.left_child);
            self._destroy(n.right_child);
            self.allocator.destroy(n);
        }
    }

    /// Tries to get the best point to split the tree in order to create a balanced tree from a set of points.
    /// A median point is found by sorting the points in a given dimension (indicated by level % k). In this
    /// case, the sorting method is insertion which will tend to have a complexity of O(n^2).
    /// Subtrees are allocated by the arena allocator.
    noinline fn partition(points: []KDPoint, level: u32, allocator: std.mem.Allocator) !PartitionResult {
        const copy = try allocator.dupe(KDPoint, points);

        const Context = struct {
            level: u32,
        };

        const k_less_than = struct {
            fn inner(context: Context, a: KDPoint, b: KDPoint) bool {
                return a.value[context.level] < b.value[context.level];
            }
        }.inner;

        std.sort.insertion(KDPoint, copy, Context{ .level = level }, k_less_than);
        const middle = copy.len / 2;
        const median = copy[middle];
        const left = copy[0 .. middle];
        const right = copy[middle + 1..];
        return .{ .median = median, .left = left, .right = right };
    }

    pub fn size(self: KDTree) u32 {
        _ = self;
        return 0;
    }

    pub fn isEmpty(self: KDTree) bool {
        return self.size() == 0;
    }

    pub fn insert(self: *KDTree, point: KDPoint) !*KDNode {
        if (self.k == 0) {
            self.k = point.dimensions();
        }
        self.root = try self._insert(self.root, point, 0);
        return self.root.?;
    }

    fn _insert(self: KDTree, node: ?*KDNode, point: KDPoint, direction: u32) !*KDNode {
        const newDirection = (direction + 1) % self.k;
        if (node == null) {
            const newNode = try self.allocator.create(KDNode);
            const v = try self.allocator.dupe(f32, point.value);
            newNode.* = KDNode{ .point = KDPoint{ .value = v }, .direction = direction };
            return newNode;
        } else if (node.?.point.equals(point)) {
            return node.?;
        } else if (node.?.point.kCompare(point, direction) < 0) {
            const v = try self.allocator.dupe(f32, point.value);
            node.?.left_child = try self._insert(node.?.left_child, KDPoint{ .value = v }, newDirection);
            return node.?;
        } else {
            const v = try self.allocator.dupe(f32, point.value);
            node.?.right_child = try self._insert(node.?.right_child, KDPoint{ .value = v }, newDirection);
            return node.?;
        }
    }

    pub fn remove(self: KDTree, point: KDPoint) void {
        _ = point;
        _ = self;
    }

    pub fn search(self: KDTree, point: KDPoint) bool {
        if (self.root == null)
            return false;
        return self._search(self.root, point);
    }

    fn _search(self: KDTree, node: ?*KDNode, point: KDPoint) bool {
        if (node == null) return false
        else if (node.?.point.equals(point)) return true
        else if (node.?.point.kCompare(point, node.?.direction) < 0) {
            return self._search(node.?.left_child, point);
        } else {
            return self._search(node.?.right_child, point);
        }
    }

    pub fn nearestNeighbour(self: KDTree, point: KDPoint) KDPoint {
        _ = point;
        _ = self;
    }

    pub fn pointsInRegion(self: KDTree, region: KBoundingRegion) []KDPoint {
        _ = region;
        _ = self;
    }
};
