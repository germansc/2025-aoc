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

    fn index(self: CharMap, x: i32, y: i32) usize {
        return @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
    }

    fn coords(self: CharMap, idx: usize) struct { x: i32, y: i32 } {
        std.debug.assert(idx < self.data.len);

        return .{ .x = @intCast(idx % self.width), .y = @intCast(idx / self.height) };
    }

    fn inBounds(self: CharMap, x: i32, y: i32) bool {
        return x >= 0 and x < self.width and y >= 0 and y < self.height;
    }

    fn getNeighbors(self: CharMap, idx: usize) [9]u8 {
        const point = self.coords(idx);
        const x = point.x;
        const y = point.y;

        const directions = [_][2]i32{
            .{ -1, -1 },
            .{ 0, -1 },
            .{ 1, -1 },
            .{ -1, 0 },
            .{ 0, 0 },
            .{ 1, 0 },
            .{ -1, 1 },
            .{ 0, 1 },
            .{ 1, 1 },
        };

        var neighs: [9]u8 = .{0} ** 9;

        for (directions, 0..) |d, i| {
            const nx: i32 = @intCast(x + d[0]);
            const ny: i32 = @intCast(y + d[1]);
            if (self.inBounds(nx, ny)) {
                neighs[i] = self.data[self.index(nx, ny)];
            }
        }

        return neighs;
    }

    /// Prints basic stats about the char map.
    fn printStats(self: CharMap) void {
        print("CHARMAP:\n W: {d} | H: {d} | S: {d} bytes\n", .{ self.width, self.height, self.data.len });
        print("Data:\n{s}\n", .{self.data});
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

    for (0..map.data.len) |idx| {
        if (map.data[idx] != '@') continue;

        const neighs = map.getNeighbors(idx);
        const rolls = std.mem.count(u8, neighs[0..], "@"); // Also counts self
        if (rolls < 5) result += 1;
    }

    return result;
}

fn solve_part_2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    const map = try CharMap.init(allocator, input);
    defer map.deinit(allocator);

    var result: i64 = 0;
    var removable = std.ArrayList(usize).empty;
    defer removable.deinit(allocator);

    while (true) {
        removable.clearRetainingCapacity();
        for (0..map.data.len) |idx| {
            if (map.data[idx] != '@') continue;

            const neighs = map.getNeighbors(idx);
            const rolls = std.mem.count(u8, neighs[0..], "@"); // Also counts self
            if (rolls < 5) {
                result += 1;
                try removable.append(allocator, idx);
            }
        }

        if (removable.items.len == 0) break;

        for (removable.items) |idx| {
            map.data[idx] = 'x';
        }
    }

    return result;
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

    const expected: i64 = 13;

    try std.testing.expectEqual(expected, solve_part_1(allocator, data));
}

test "part 2 sample" {
    const data = @embedFile("sample.txt");
    const allocator = std.testing.allocator;

    const expected: i64 = 43;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}
