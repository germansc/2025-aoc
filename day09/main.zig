const std = @import("std");
const print = std.debug.print;

const Point = struct {
    x: i64,
    y: i64,

    fn init(string: []const u8) !Point {
        var numbers = std.mem.tokenizeScalar(u8, string, ',');
        const x_s = numbers.next() orelse unreachable;
        const y_s = numbers.next() orelse unreachable;

        const x = try std.fmt.parseInt(i64, x_s, 10);
        const y = try std.fmt.parseInt(i64, y_s, 10);

        return .{ .x = x, .y = y };
    }
};

const Rect = struct {
    a: Point,
    b: Point,
    area: i64,

    fn init(a: Point, b: Point) Rect {
        const dx: i64 = @intCast(@abs(a.x - b.x) + 1);
        const dy: i64 = @intCast(@abs(a.y - b.y) + 1);

        return .{ .a = a, .b = b, .area = dy * dx };
    }

    /// Compare two rectables by area.
    fn gt(_: void, a: Rect, b: Rect) bool {
        return a.area > b.area;
    }

    /// Returns the center point of the rect.
    fn center(self: Rect) Point {
        return .{
            .x = @divFloor(self.a.x + self.b.x, 2),
            .y = @divFloor(self.a.y + self.b.y, 2),
        };
    }

    /// Check if two rectangles intersect (AABB collision)
    fn intersects(self: Rect, other: Rect) bool {
        const self_min_x = @min(self.a.x, self.b.x);
        const self_max_x = @max(self.a.x, self.b.x);
        const self_min_y = @min(self.a.y, self.b.y);
        const self_max_y = @max(self.a.y, self.b.y);

        const other_min_x = @min(other.a.x, other.b.x);
        const other_max_x = @max(other.a.x, other.b.x);
        const other_min_y = @min(other.a.y, other.b.y);
        const other_max_y = @max(other.a.y, other.b.y);

        // Rectangles intersect if they overlap in both X and Y
        return !(self_max_x <= other_min_x or
            other_max_x <= self_min_x or
            self_max_y <= other_min_y or
            other_max_y <= self_min_y);
    }
};

const Polygon = struct {
    allocator: std.mem.Allocator,
    points: []Point,
    edges: []Rect,
    vert_edges: []Rect,

    fn init(allocator: std.mem.Allocator, points: []Point) !Polygon {
        std.debug.assert(points.len != 0);

        var edges: []Rect = try allocator.alloc(Rect, points.len);

        // Assuming the shape is closed... and always rectilinear?
        var vert_edges: []Rect = try allocator.alloc(Rect, points.len / 2);

        var v: usize = 0;
        for (0..points.len) |i| {
            var next = i + 1;
            if (next == points.len) next = 0; // loop around.

            edges[i] = Rect.init(points[i], points[next]);

            if (edges[i].a.x == edges[i].b.x) {
                vert_edges[v] = edges[i];
                v += 1;
            }
        }

        return .{
            .allocator = allocator,
            .points = points,
            .edges = edges,
            .vert_edges = vert_edges,
        };
    }

    fn deinit(self: Polygon) void {
        if (self.edges.len != 0) {
            self.allocator.free(self.edges);
            self.allocator.free(self.vert_edges);
        }
    }

    /// Checks if a given point is inside the poligon shape by ray casting.
    fn containsPoint(self: Polygon, point: Point) bool {
        var intersections: usize = 0;

        // Cast a horizontal ray towards x = 0, so we only care about vertical
        // edges on the polygon.
        for (self.vert_edges) |edge| {
            if (edge.a.x >= point.x) continue;

            const e_min = @min(edge.a.y, edge.b.y);
            const e_max = @max(edge.a.y, edge.b.y);

            if (point.y >= e_min and point.y < e_max) intersections += 1;
        }

        return (intersections % 2 == 1);
    }

    /// Checks if a rectangle is fully contained within the polygon
    fn containsRect(self: Polygon, rect: Rect) bool {
        // 1. Check if the rect center is inside polygon.
        // 2. Check if any polygon edge intersects the rectangle
        // If center is inside AND no edges intersect, rectangle is fully
        // contained
        const center = rect.center();
        if (!self.containsPoint(center)) return false;

        for (self.edges) |edge| {
            if (rect.intersects(edge)) return false;
        }

        return true;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Unbuffered readers/writers. Not critical for this applications :P
    var writer = std.fs.File.stdout().writer(&.{});
    const stdout = &writer.interface;

    var reader = std.fs.File.stdin().reader(&.{});
    const stdin = &reader.interface;

    // Read all input from stdin.
    const MAX_SIZE = 4 * 1024 * 1024;
    const input = try stdin.allocRemaining(allocator, @enumFromInt(MAX_SIZE));
    defer allocator.free(input);

    print("[INPUT: {} Lines | {} bytes]\n", .{ std.mem.count(u8, input, "\n"), input.len });

    // Part 1
    const part1_result = try solve_part_1(allocator, input);
    try stdout.print("Part 1: {d}\n", .{part1_result});

    // Part 2
    const part2_result = try solve_part_2(allocator, input);
    try stdout.print("Part 2: {d}\n", .{part2_result});
}

fn solve_part_1(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var points = std.ArrayList(Point).empty;
    defer points.deinit(allocator);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const point = try Point.init(line);
        try points.append(allocator, point);
    }

    // Generate all rectanbles.
    var rect_list = std.ArrayList(Rect).empty;
    defer rect_list.deinit(allocator);

    var max_rect: Rect = Rect.init(.{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 });

    for (points.items, 0..) |point_a, a| {
        for (points.items[a + 1 ..]) |point_b| {
            const rect = Rect.init(point_a, point_b);
            if (rect.area > max_rect.area) max_rect = rect;
        }
    }

    return @intCast(max_rect.area);
}

fn solve_part_2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var points = std.ArrayList(Point).empty;
    defer points.deinit(allocator);

    // Reparsing the input... could be improved.
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const point = try Point.init(line);
        try points.append(allocator, point);
    }

    // Generate a Poly
    const poly = try Polygon.init(allocator, points.items);
    defer poly.deinit();

    var max_rect: Rect = Rect.init(.{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 });

    for (points.items, 0..) |point_a, a| {
        for (points.items[a + 1 ..]) |point_b| {
            const rect = Rect.init(point_a, point_b);

            // If smaller than current, don't even bother.
            if (rect.area <= max_rect.area) continue;

            if (poly.containsRect(rect)) max_rect = rect;
        }
    }

    return @intCast(max_rect.area);
}

// ---------------------------- UNIT TESTING -------------------------------

/// Helper function to ignore a test block execution.
/// It logs a warning for the user and returns "true".
inline fn test_ignore(src: std.builtin.SourceLocation) bool {
    std.log.warn("IGNORED: Test '{s}' [ {s}:{d} ] is a placeholder.", .{ src.fn_name, src.file, src.line });
    std.log.warn("         Add its expected value and remove the 'test_ignore' guard to execute.", .{});
    return true;
}

test "part 1 sample" {
    const data = @embedFile("sample.txt");
    const allocator = std.testing.allocator;

    const expected: i64 = 50;

    try std.testing.expectEqual(expected, solve_part_1(allocator, data));
}

test "part 2 sample" {
    const data = @embedFile("sample.txt");
    const allocator = std.testing.allocator;

    const expected: i64 = 24;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}

test "polygon logic" {
    var vertices = [_]Point{
        .{ .x = 5, .y = 5 },
        .{ .x = 15, .y = 5 },
        .{ .x = 15, .y = 15 },
        .{ .x = 5, .y = 15 },
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const poly = try Polygon.init(allocator, vertices[0..vertices.len]);
    defer poly.deinit();

    // INSIDE
    try std.testing.expect(poly.containsPoint(.{ .x = 10, .y = 10 }));
    try std.testing.expect(poly.containsPoint(.{ .x = 6, .y = 6 }));
    try std.testing.expect(poly.containsPoint(.{ .x = 14, .y = 14 }));

    // OUTSIDE
    try std.testing.expect(!poly.containsPoint(.{ .x = 4, .y = 10 }));
    try std.testing.expect(!poly.containsPoint(.{ .x = 16, .y = 10 }));
    try std.testing.expect(!poly.containsPoint(.{ .x = 10, .y = 4 }));
    try std.testing.expect(!poly.containsPoint(.{ .x = 10, .y = 16 }));
}

test "AABB intersection check" {
    const rect1 = Rect.init(.{ .x = 0, .y = 0 }, .{ .x = 10, .y = 10 });
    const rect2 = Rect.init(.{ .x = 5, .y = 5 }, .{ .x = 15, .y = 15 });
    const rect3 = Rect.init(.{ .x = 20, .y = 20 }, .{ .x = 30, .y = 30 });
    const rect4 = Rect.init(.{ .x = 10, .y = 0 }, .{ .x = 20, .y = 10 });

    try std.testing.expect(rect1.intersects(rect1));
    try std.testing.expect(rect1.intersects(rect2));
    try std.testing.expect(!rect1.intersects(rect3));
    try std.testing.expect(!rect1.intersects(rect4));
    try std.testing.expect(rect2.intersects(rect1));
}
