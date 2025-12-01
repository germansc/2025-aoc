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

    const NOTCHES = 100;
    var dial: u64 = 50;

    // iterate over lines.
    var it = std.mem.tokenizeScalar(u8, input, '\n');

    while (it.next()) |move| {
        // std.debug.print("{d:02} {s} -> ", .{ dial, move });
        var value = try std.fmt.parseInt(u32, move[1..], 10);

        value = value % NOTCHES;
        if (move[0] == 'R') {
            dial = (dial + value) % NOTCHES;
        } else {
            dial = (dial + NOTCHES - value) % NOTCHES;
        }

        // std.debug.print("{d:02}\n", .{dial});
        if (dial == 0) total += 1;
    }

    return total;
}

fn solve_part_2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    _ = allocator;

    var total: i64 = 0;

    const NOTCHES = 100;
    var dial: u64 = 50;

    // iterate over lines.
    var it = std.mem.tokenizeScalar(u8, input, '\n');

    while (it.next()) |move| {
        // std.debug.print("{d:02} {s} -> ", .{ dial, move });
        const prev = dial;
        var value = try std.fmt.parseInt(u32, move[1..], 10);

        total += @divTrunc(value, NOTCHES);
        value = value % NOTCHES;

        if (move[0] == 'R') {
            dial = (dial + value) % NOTCHES;
            if (prev != 0 and ((dial < prev) or (dial == 0))) total += 1;
        } else {
            dial = (dial + NOTCHES - value) % NOTCHES;
            if (prev != 0 and ((dial > prev) or (dial == 0))) total += 1;
        }

        // std.debug.print("{d:02}\n", .{dial});
    }

    return total;
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

    const expected: i64 = 3;

    try std.testing.expectEqual(expected, solve_part_1(allocator, data));
}

test "part 2 sample" {
    const data = @embedFile("sample.txt");
    const allocator = std.testing.allocator;

    const expected: i64 = 6;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}

test "part 2 sub-sample" {
    const data = "R1000";
    const allocator = std.testing.allocator;

    const expected: i64 = 10;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}

test "part 2 sub-sample 2" {
    const data = "R50\nL49";
    const allocator = std.testing.allocator;

    // 50 --R50-> 00 (COUNT) --L49-> 51
    const expected: i64 = 1;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}
