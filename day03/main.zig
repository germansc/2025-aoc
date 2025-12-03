const std = @import("std");
const print = std.debug.print;

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
    _ = allocator;

    var total: i64 = 0;
    var it = std.mem.tokenizeScalar(u8, input, '\n');

    while (it.next()) |line| {
        const a = indexOfMax(line[0 .. line.len - 1]);
        const b = indexOfMax(line[a + 1 ..]);

        const joltage: i64 = (line[a] - '0') * 10 + (line[a + 1 + b] - '0');
        total += joltage;

        // print("{s} -> {d}:{d} = {d}\n", .{ line, a, a + b + 1, joltage });
    }

    return total;
}

fn solve_part_2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    _ = allocator;

    var total: i64 = 0;
    var it = std.mem.tokenizeScalar(u8, input, '\n');

    while (it.next()) |line| {
        var joltage: i64 = 0;
        var idx_start: usize = 0;

        for (0..12) |i| {
            const a = indexOfMax(line[idx_start..(line.len - 11 + i)]);
            joltage = joltage * 10 + (line[idx_start + a] - '0');
            idx_start = idx_start + a + 1;
        }

        total += joltage;

        // print("{s} -> = {d}\n", .{ line, joltage });
    }

    return total;
}

fn indexOfMax(slice: []const u8) usize {
    std.debug.assert(slice.len != 0);

    var idx: usize = 0;
    var max: u8 = slice[0];

    for (slice[1..], 1..) |val, i| {
        if (val > max) {
            max = val;
            idx = i;
        }
    }

    return idx;
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

    const expected: i64 = 357;

    try std.testing.expectEqual(expected, solve_part_1(allocator, data));
}

test "part 2 sample" {
    const data = @embedFile("sample.txt");
    const allocator = std.testing.allocator;

    const expected: i64 = 3121910778619;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}
