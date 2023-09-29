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
    _size: usize = 0,
    allocator: std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,

    /// Note(Pete): This is the original create function I added when starting out which simply adds the points
    /// in order. This was left in as a comparison to the preferred createBalanced function.
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
        // Note(Pete): The entire tree uses an arena allocator for its allocation strategy. This means that the tree can
        // allocating cheaply as needed and when the tree is destroyed it can easily deallocate by resetting the arena.
        // As K-d tree are mutated infrequently after their creation we needn't worry too much about reclaiming memory when we remove individual elements.
        var arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        var k: u32 = 0;
        if (points.len > 0) {
            k = points[0].dimensions();
        }
        var tree = KDTree{ .root = null, .k = k, .allocator = arena.allocator(), .arena = arena };
        tree.root = try _createBalanced(points, 0, tree.k, tree.allocator);
        tree._size = points.len;

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
            // Split the points in to (as near as possible) two even parts in order to distribute the points evenly through the tree
            // to create a balanced tree. This is important in the creation step because K-d Trees typically do not rebalance themselves once created.
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
        // Note(Pete): The arena's allocator allocated the arena struct itself in th create* functions so we need to remember to deallocate the arena here.
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
        const left = copy[0..middle];
        const right = copy[middle + 1 ..];
        return .{ .median = median, .left = left, .right = right };
    }

    pub fn size(self: KDTree) usize {
        return self._size;
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

    /// Recursively move through the tree until we find an empty child where we can insert the new point.
    /// If the point already exists in the tree then we do not create a duplicate.
    fn _insert(self: *KDTree, node: ?*KDNode, point: KDPoint, direction: u32) !*KDNode {
        const newDirection = (direction + 1) % self.k;
        if (node == null) {
            const newNode = try self.allocator.create(KDNode);
            const v = try self.allocator.dupe(f32, point.value);
            newNode.* = KDNode{ .point = KDPoint{ .value = v }, .direction = direction };
            self._size += 1;
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

    const RemoveResult = struct {
        node: ?*KDNode,
        removed: bool,
    };

    pub fn remove(self: *KDTree, point: KDPoint) !bool {
        const result = try self._remove(self.root, point);
        if (result.removed) {
            self.root = result.node;
            self._size -= 1;
            return true;
        } else {
            return false;
        }
    }

    fn _remove(self: KDTree, node: ?*KDNode, point: KDPoint) !RemoveResult {
        if (node) |n| {
            if (n.point.equals(point)) {
                // Note(Pete): In order to satisfy the conditions of a K-d Tree after removing an internal node we need to do some shuffling around of nodes.
                // This is not as simple as with a typical Binary Search Tree as the dimensionality of the nodes impacts where they may be placed.
                if (n.right_child) |right| {
                    // Find the minimum node in this dimension that will replace the node we're trying to remove.
                    const min_node = findMin(right, n.direction);
                    const r = try self._remove(n.right_child, min_node.?.point);
                    const new_right = r.node;
                    const new_node = try self.allocator.create(KDNode);
                    new_node.* = KDNode{ .left_child = n.left_child, .right_child = new_right, .point = min_node.?.point, .direction = n.direction };
                    return .{ .node = new_node, .removed = true };
                } else if (n.left_child) |left| {
                    // Find the minimum node in this dimension that will replace the node we're trying to remove.
                    const min_node = findMin(left, n.direction);
                    const r = try self._remove(left, min_node.?.point);
                    const new_right = r.node;
                    const new_node = try self.allocator.create(KDNode);
                    new_node.* = KDNode{ .right_child = new_right, .point = min_node.?.point, .direction = n.direction };
                    return .{ .node = new_node, .removed = true };
                } else {
                    return .{ .node = null, .removed = true };
                }
            } else if (n.point.kCompare(point, n.direction) < 0) {
                const r = try self._remove(n.left_child, point);
                n.left_child = r.node;
                return .{ .node = n, .removed = r.removed };
            } else {
                const r = try self._remove(n.right_child, point);
                n.right_child = r.node;
                return .{ .node = n, .removed = r.removed };
            }
        } else {
            return .{ .node = null, .removed = false };
        }
    }

    pub fn search(self: KDTree, point: KDPoint) bool {
        if (self.root == null)
            return false;
        return self._search(self.root, point);
    }

    fn _search(self: KDTree, node: ?*KDNode, point: KDPoint) bool {
        if (node == null) {
            return false;
        } else if (node.?.point.equals(point)) {
            return true;
        } else if (node.?.point.kCompare(point, node.?.direction) < 0) {
            return self._search(node.?.left_child, point);
        } else {
            return self._search(node.?.right_child, point);
        }
    }

    const NearestNeighbourResult = struct {
        distance: f32 = std.math.floatMax(f32),
        point: ?*KDPoint = null,

        fn compare(_: void, a: NearestNeighbourResult, b: NearestNeighbourResult) std.math.Order {
            if (std.math.approxEqRel(f32, a.distance, b.distance, 0.01)) {
                return std.math.Order.eq;
            } else if (a.distance < b.distance) {
                return std.math.Order.lt;
            } else {
                return std.math.Order.gt;
            }
        }
    };

    /// Returns a slice of the n nearest points. The points are ordered from nearest to farthest.
    /// Ownership of the slice is returned to the caller.
    pub fn nNearestNeighbours(self: KDTree, target: KDPoint, n: u32, allocator: std.mem.Allocator) ![]NearestNeighbourResult {
        std.debug.assert(n <= self._size);
        // A Priority Queue will keep the points in order from nearest to farthest as we add them to the queue. 
        var priorityQueue = std.PriorityQueue(NearestNeighbourResult, void, NearestNeighbourResult.compare).init(allocator, {});
        defer priorityQueue.deinit();
        try self._nNearestNeighbours(self.root, target, &priorityQueue);

        const nearest_neighbours = try allocator.alloc(NearestNeighbourResult, n);
        var i: u32 = 0;
        while (i < n and priorityQueue.count() > 0) {
            nearest_neighbours[i] = priorityQueue.remove();
            i += 1;
        }
        return nearest_neighbours;
    }

    fn _nNearestNeighbours(self: KDTree, node: ?*KDNode, target: KDPoint, priorityQueue: *std.PriorityQueue(NearestNeighbourResult, void, NearestNeighbourResult.compare)) !void {
        const n = node orelse return;

        const dist = distance(n.point, target);
        try priorityQueue.add(NearestNeighbourResult{ .distance = dist, .point = &n.point });
        var close_branch: ?*KDNode = undefined;
        var far_branch: ?*KDNode = undefined;
        if (n.point.kCompare(target, n.direction) < 0) {
            close_branch = n.left_child;
            far_branch = n.right_child;
        } else {
            close_branch = n.right_child;
            far_branch = n.left_child;
        }
        try self._nNearestNeighbours(close_branch, target, priorityQueue);
        const nearest_distance = priorityQueue.peek().?.distance;
        if (std.math.fabs(n.point.kCompare(target, n.direction)) < nearest_distance) {
            try self._nNearestNeighbours(far_branch, target, priorityQueue);
        }
    }

    pub fn nearestNeighbour(self: KDTree, target: KDPoint, nearestPoint: *KDPoint) f32 {
        var result = NearestNeighbourResult{};
        self._nearestNeighbour(self.root, target, &result);
        if (result.point) |p| {
            nearestPoint.* = p.*;
        }
        return result.distance;
    }

    fn _nearestNeighbour(self: KDTree, node: ?*KDNode, target: KDPoint, result: *NearestNeighbourResult) void {
        if (node) |n| {
            const dist = distance(n.point, target);
            if (dist < result.distance) {
                result.distance = dist;
                result.point = &n.point;
            }
            var close_branch: ?*KDNode = undefined;
            var far_branch: ?*KDNode = undefined;
            if (n.point.kCompare(target, n.direction) < 0) {
                close_branch = n.left_child;
                far_branch = n.right_child;
            } else {
                close_branch = n.right_child;
                far_branch = n.left_child;
            }
            self._nearestNeighbour(close_branch, target, result);
            // Compare the distance projected onto the split line passing through the points and the distance of the current nearest neighbour.
            // If the distance is closer then their may be points in the far branch that could be closer to the target.
            if (std.math.fabs(n.point.kCompare(target, n.direction)) < result.distance) {
                self._nearestNeighbour(far_branch, target, result);
            }
        }
    }

    fn distanceSquared(a: KDPoint, b: KDPoint) f32 {
        var d: f32 = 0;
        for (a.value, b.value) |p1, p2| {
            const p = p1 - p2;
            d += p * p;
        }
        return d;
    }

    fn distance(a: KDPoint, b: KDPoint) f32 {
        return std.math.sqrt(distanceSquared(a, b));
    }

    fn splitDistance(a: KDPoint, b: KDPoint) f32 {
        _ = b;
        _ = a;
    }

    pub fn pointsInRegion(self: KDTree, region: KBoundingRegion) []KDPoint {
        _ = region;
        _ = self;
    }

    /// Utility function to find the minimum node in a dimension (direction).
    /// Useful in managing the gymnasctics required to remove a node.
    fn findMin(node: ?*KDNode, direction: u32) ?*KDNode {
        if (node) |n| {
            if (n.direction == direction) {
                // If the node is in the correct orientation then the minimum could be this node or any of its left children.
                if (n.left_child == null) {
                    return n;
                } else {
                    return findMin(n.left_child, direction);
                }
            } else {
                // The minimum node could be this one or either if its children.
                var result = n;
                if (findMin(n.left_child, direction)) |left_min| {
                    if (result.point.kCompare(left_min.point, direction) < 0) {
                        result = left_min;
                    }
                }

                if (findMin(n.right_child, direction)) |right_min| {
                    if (result.point.kCompare(right_min.point, direction) < 0) {
                        result = right_min;
                    }
                }

                return result;
            }
        } else {
            return null;
        }
    }
};
