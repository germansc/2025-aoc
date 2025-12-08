const std = @import("std");
const print = std.debug.print;

const JunctionBox = struct {
    x: i64,
    y: i64,
    z: i64,

    fn distance(self: JunctionBox, other: JunctionBox) f64 {
        const dx: f64 = @floatFromInt(self.x - other.x);
        const dy: f64 = @floatFromInt(self.y - other.y);
        const dz: f64 = @floatFromInt(self.z - other.z);

        return std.math.sqrt(dx * dx + dy * dy + dz * dz);
    }

    fn init(string: []const u8) !JunctionBox {
        var numbers = std.mem.tokenizeScalar(u8, string, ',');
        const x_s = numbers.next() orelse unreachable;
        const y_s = numbers.next() orelse unreachable;
        const z_s = numbers.next() orelse unreachable;

        const x = try std.fmt.parseInt(i64, x_s, 10);
        const y = try std.fmt.parseInt(i64, y_s, 10);
        const z = try std.fmt.parseInt(i64, z_s, 10);

        return .{ .x = x, .y = y, .z = z };
    }
};

const Connection = struct {
    a: usize,
    b: usize,
    dist: f64,

    fn lessThan(_: void, a: Connection, b: Connection) bool {
        return a.dist < b.dist;
    }
};

const UnionFind = struct {
    parent: []usize,
    size: []usize,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, n: usize) !UnionFind {
        const parent = try allocator.alloc(usize, n);
        const size = try allocator.alloc(usize, n);
        for (0..n) |i| {
            parent[i] = i;
            size[i] = 1;
        }
        return .{ .parent = parent, .size = size, .allocator = allocator };
    }

    fn deinit(self: *UnionFind) void {
        self.allocator.free(self.parent);
        self.allocator.free(self.size);
    }

    fn find(self: *UnionFind, x: usize) usize {
        if (self.parent[x] != x) {
            // Look for the parent of this index, and update them recursively.
            self.parent[x] = self.find(self.parent[x]);
        }
        return self.parent[x];
    }

    fn unite(self: *UnionFind, x: usize, y: usize) bool {
        var root_x = self.find(x);
        var root_y = self.find(y);

        // Already connected return false.
        if (root_x == root_y) return false;

        // Merge the smaller circuit into the larger one.
        if (self.size[root_x] < self.size[root_y]) {
            const temp = root_x;
            root_x = root_y;
            root_y = temp;
        }

        self.parent[root_y] = root_x;
        self.size[root_x] += self.size[root_y];
        return true; // We merged circuits, return true.
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

    // Solve both parts.
    const results = try solve_parts(allocator, input, 1000);
    try stdout.print("Part 1: {d}\n", .{results.part1});
    try stdout.print("Part 2: {d}\n", .{results.part2});
}

fn solve_parts(allocator: std.mem.Allocator, input: []const u8, limit: usize) !struct { part1: i64, part2: i64 } {
    var boxes = std.ArrayList(JunctionBox).empty;
    defer boxes.deinit(allocator);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const box = try JunctionBox.init(line);
        try boxes.append(allocator, box);
    }

    // Generate all two-point connections
    var conn_list = std.ArrayList(Connection).empty;
    defer conn_list.deinit(allocator);

    for (boxes.items, 0..) |box_a, a| {
        for (boxes.items[a + 1 ..], a + 1..) |box_b, b| {
            try conn_list.append(allocator, .{
                .a = a,
                .b = b,
                .dist = box_a.distance(box_b),
            });
        }
    }

    // Sort them by distance.
    std.mem.sort(Connection, conn_list.items, {}, Connection.lessThan);
    // print("DBG: {} boxes | {} connections.\n", .{ boxes.items.len, conn_list.items.len });

    var uf = try UnionFind.init(allocator, boxes.items.len);
    defer uf.deinit();

    // We start with as many connection as boxes.
    var total_circuits = boxes.items.len;
    for (conn_list.items, 0..) |conn, i| {
        if (i >= limit) break;

        // unite returns true if two circuits were merged, false if they were
        // already connected. This is used to keep track for part 2.
        if (uf.unite(conn.a, conn.b)) total_circuits -= 1;
    }

    // Find the three largest circuits
    var circuit_sizes = std.AutoHashMap(usize, usize).init(allocator);
    defer circuit_sizes.deinit();

    for (0..boxes.items.len) |i| {
        const root = uf.find(i);
        const circ = try circuit_sizes.getOrPut(root);
        if (!circ.found_existing) {
            circ.value_ptr.* = uf.size[root];
        }
    }

    var sizes = std.ArrayList(usize).empty;
    defer sizes.deinit(allocator);

    var iter = circuit_sizes.valueIterator();
    while (iter.next()) |size| {
        try sizes.append(allocator, size.*);
    }

    // sanity check:
    std.debug.assert(total_circuits == sizes.items.len);

    std.mem.sort(usize, sizes.items, {}, std.sort.desc(usize));

    const part1 = sizes.items[0] * sizes.items[1] * sizes.items[2];
    // print("DBG: Part 1: {} circuits | largest: {}, {}, {}\n", .{ sizes.items.len, sizes.items[0], sizes.items[1], sizes.items[2] });

    // Proceed to part 2.
    // Continue making connection until we get only 1 circuit.
    var part2: i64 = 0;
    for (limit..conn_list.items.len) |i| {
        const conn = conn_list.items[i];

        // unite returns true if two circuits were merged, false if they were
        // already connected. This is used to keep track for part 2.
        if (uf.unite(conn.a, conn.b)) total_circuits -= 1;

        if (total_circuits == 1) {
            const box_a = boxes.items[conn.a];
            const box_b = boxes.items[conn.b];

            part2 = box_a.x * box_b.x;
            // print("DBG: Part 2: Last connection at index {} between boxes {any} and {any}\n", .{ i, box_a, box_b });
            break;
        }
    }

    return .{ .part1 = @intCast(part1), .part2 = @intCast(part2) };
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

    const expected1: i64 = 40;
    const expected2: i64 = 25272;
    const results = try solve_parts(allocator, data, 10);

    try std.testing.expectEqual(expected1, results.part1);
    try std.testing.expectEqual(expected2, results.part2);
}
