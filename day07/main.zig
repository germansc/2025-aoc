const std = @import("std");
const print = std.debug.print;

const CharMap = struct {
    data: []u8,
    width: usize,
    height: usize,

    /// Creates a CharMap from an input buffer.
    fn init(allocator: std.mem.Allocator, buff: []const u8) !CharMap {
        std.debug.assert(buff.len != 0);

        const width = std.mem.indexOfScalar(u8, buff, '\n') orelse buff.len;
        const height: u64 = std.mem.count(u8, buff, "\n");

        var data = try allocator.alloc(u8, width * height);

        var it = std.mem.tokenizeScalar(u8, buff, '\n');
        var idx: usize = 0;
        while (it.next()) |line| {
            @memcpy(data[idx .. idx + line.len], line);
            idx += line.len;
        }

        return .{
            .data = data,
            .width = width,
            .height = height,
        };
    }

    fn deinit(self: CharMap, allocator: std.mem.Allocator) void {
        if (self.data.len != 0) allocator.free(self.data);
    }

    fn index(self: CharMap, x: i32, y: i32) ?usize {
        if (!self.inBounds(x, y)) return null;
        return @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
    }

    fn coords(self: CharMap, idx: usize) ?struct { x: i32, y: i32 } {
        if (idx >= self.data.len) return null;
        std.debug.assert(idx < self.data.len);

        return .{ .x = @intCast(idx % self.width), .y = @intCast(idx / self.width) };
    }

    fn inBounds(self: CharMap, x: i32, y: i32) bool {
        return x >= 0 and x < self.width and y >= 0 and y < self.height;
    }

    /// Prints basic stats about the char map.
    fn printStats(self: CharMap) void {
        print("CHARMAP:\n W: {d} | H: {d} | S: {d} bytes\n", .{ self.width, self.height, self.data.len });
        print("Data:\n", .{});

        for (0..self.height) |i| {
            const s_idx: usize = i * self.width;
            print("{s}\n", .{self.data[s_idx .. s_idx + self.width]});
        }
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
    const map = try CharMap.init(allocator, input);
    defer map.deinit(allocator);

    var result: i64 = 0;
    const start_idx = std.mem.indexOf(u8, map.data, "S") orelse unreachable;

    var queue = std.ArrayList(usize).empty;
    defer queue.deinit(allocator);

    try queue.append(allocator, start_idx + map.width);

    // Debug: Print initial map.
    // map.printStats();

    var qi: usize = 0;
    while (qi < queue.items.len) {
        const idx = queue.items[qi];
        const coords = map.coords(idx) orelse unreachable;
        qi += 1;

        // If empty, mark the cell as visited with its own data.
        if (map.data[idx] == '.') map.data[idx] = '|';

        switch (map.data[idx]) {
            '^' => {
                // Assuming there are no splitters together (^^) we can use the
                // actual value of the cell as a "seen" condition.
                if (map.inBounds(coords.x - 1, coords.y) and map.data[idx - 1] != '|' and notInArrayList(queue, idx - 1)) {
                    try queue.append(allocator, idx - 1);
                }
                if (map.inBounds(coords.x + 1, coords.y) and map.data[idx + 1] != '|' and notInArrayList(queue, idx + 1)) {
                    try queue.append(allocator, idx + 1);
                }
                result += 1;
            },
            else => {
                if (map.inBounds(coords.x, coords.y + 1) and map.data[idx + map.width] != '|' and notInArrayList(queue, idx + map.width)) {
                    try queue.append(allocator, idx + map.width);
                }
            },
        }
    }

    // Debug: Print final map.
    // map.printStats();

    return result;
}

fn solve_part_2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    // This can be simply computed as the sum of possible roads from the
    // starting cell. Since the movement is always downwards, we can get all
    // possible roads by starting from the bottom, knowing that all those cells
    // have one way out, and then iterating up. Each splitter simply adds the
    // possible roads from its two surrounding cells (which took their values
    // from the cell below each one).
    const map = try CharMap.init(allocator, input);
    defer map.deinit(allocator);

    var result: i64 = 0;
    const start_idx = std.mem.indexOf(u8, map.data, "S") orelse unreachable;

    // Possible roads from each cell of the map.
    var roads = try allocator.alloc(usize, map.data.len);
    defer allocator.free(roads);
    @memset(roads, 1);

    // We can skip the last row, since it's already set to "1".
    for (0..map.height - 1) |i| {
        const row = map.height - 2 - i;
        for (0..map.width) |col| {
            const idx = map.index(@intCast(col), @intCast(row)).?;
            switch (map.data[idx]) {
                '^' => {
                    const r1 = map.index(@intCast(col - 1), @intCast(row + 1));
                    const r2 = map.index(@intCast(col + 1), @intCast(row + 1));

                    roads[idx] = 0; // Discard the initial 1 from the memset.
                    if (r1) |a| roads[idx] += roads[a];
                    if (r2) |a| roads[idx] += roads[a];
                },
                else => roads[idx] = roads[idx + map.width],
            }

            // print("DBG: idx: {} ({},{}) \t| {} possible ways\n", .{ idx, col, row, roads[idx] });
        }
    }

    result = @intCast(roads[start_idx]);
    return result;
}

fn notInArrayList(list: std.ArrayList(usize), value: usize) bool {
    for (list.items) |item| {
        if (item == value) return false;
    }
    return true;
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

    const expected: i64 = 21;

    try std.testing.expectEqual(expected, solve_part_1(allocator, data));
}

test "part 2 sample" {
    const data = @embedFile("sample.txt");
    const allocator = std.testing.allocator;

    const expected: i64 = 40;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}
