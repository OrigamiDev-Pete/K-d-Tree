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
        return self.value[k] < other.value[k];
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
        leftChild: ?*KDNode,
        rightChild: ?*KDNode,
        point: KPoint,
        // Note(Pete): direction determines the dimension in the hyperspace to use when comparing. 
        // Other implementations may store a level and compute the direction based on the dimensionality of the tree.
        direction: u32, 
        allocator: ?std.mem.Allocator,

        fn search(self: KDNode, point: KPoint) bool {
            if (self.point.equals(point)) return true
            else if (self.point.kCompare(point, self.direction) < 0 and self.leftChild) {
                return self.leftChild.search(point);
            } 
            else if (self.rightChild) {
                return self.rightChild.search(point);
            }
            else return false;
        }

        fn insert(self: KDNode, point: KPoint, direction: u32, k: u32, allocator: std.mem.Allocator) KDNode {
            const newDirection = (direction + 1) % k;
            if (self.point.equals(point)) return self
            else if (self.point.kCompare(point, direction) < 0) {
                if (self.leftChild) {
                    self.leftChild = self.leftChild.insert(point, newDirection);
                    return self;
                } else {
                    return allocator.create(KDNode{ .point = point, .direction = direction, .allocator = allocator });
                }
            } else { 
                if (self.rightChild) {
                    self.rightChild = self.rightChild.insert(point, newDirection);
                    return self;
                } else {
                    return allocator.create(KDNode{ .point = point, .direction = direction, .allocator = allocator });
                }
            }
        }

    };

    root: ?*KDNode,
    k: u32, // Number of dimensions
    allocator: std.mem.Allocator,
    
    pub fn init(points: []KPoint, alloctor: std.mem.Allocator) KDTree {
        return KDTree{
            .root = null,
            .k = points[0].dimensions(),
            .allocator = alloctor
        };
    }

    pub fn size(self: KDTree) u32 {
        _ = self;
        return 0;
    }

    pub fn isEmpty(self: KDTree) bool {
        return self.size() == 0;
    }

    pub fn insert(self: KDTree, point: KPoint) KDNode {
        if (self.root == null) 
            return self.allocator.create(KDNode{ .point = point, .level = 0, .allocator = self.allocator });
        return self.root.insert(point, 0, self.allocator);
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
