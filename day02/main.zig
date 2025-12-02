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
    var it = std.mem.splitScalar(u8, input, ',');
    var result: i64 = 0;

    while (it.next()) |range| {
        var invalid_ids = std.ArrayList(u64).empty;
        defer invalid_ids.deinit(allocator);

        var values = std.mem.splitAny(u8, range, "-\n");
        const s_str = values.next() orelse return error.InvalidInput;
        const e_str = values.next() orelse return error.InvalidInput;

        var start = try std.fmt.parseInt(u64, s_str, 10);
        const end = try std.fmt.parseInt(u64, e_str, 10);
        var s_n = countDigits(start);
        const e_n = countDigits(end);

        // Quick skip, if s_n is odd, and same length as end, no pattern can repeat.
        if (s_n % 2 != 0 and s_n == e_n) continue;

        // If s_n is odd, the repeats actually start after 10^(s_n) which has
        // s_n+1 digit (even)
        if ((s_n % 2) != 0) {
            start = @intCast(std.math.pow(u64, 10, s_n));
            s_n += 1;
        }

        // check possible repeats by taking the s_n / 2  most significant
        // digits and start repeating them, until they are bigger than the top
        // of the range. Equivalent to XX << 100 + XX.
        var pattern: u64 = @intCast(start / std.math.pow(u64, 10, s_n / 2));
        while (true) {
            // XX << 100 + XX . Base 10 bitshift and masking :P
            const pat_n = countDigits(pattern);
            const next_invalid_id = pattern * std.math.pow(u64, 10, pat_n) + pattern;
            pattern += 1;

            if (next_invalid_id < start) continue;

            if (next_invalid_id <= end) {
                try invalid_ids.append(allocator, next_invalid_id);
            } else {
                break;
            }
        }

        // Sum the invalid Ids to the final result.
        for (invalid_ids.items) |id| result += @intCast(id);

        // Done with this range.
        // print("{} ({} digits) - {} ({} digits): {any}\n", .{ start, s_n, end, e_n, invalid_ids.items });
    }

    return result;
}

fn solve_part_2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var it = std.mem.splitScalar(u8, input, ',');
    var result: i64 = 0;

    while (it.next()) |range| {
        var invalid_ids = std.ArrayList(u64).empty;
        defer invalid_ids.deinit(allocator);

        var values = std.mem.splitAny(u8, range, "-\n");
        const s_str = values.next() orelse return error.InvalidInput;
        const e_str = values.next() orelse return error.InvalidInput;

        const start = try std.fmt.parseInt(u64, s_str, 10);
        const end = try std.fmt.parseInt(u64, e_str, 10);
        // const s_n = countDigits(start);
        const e_n = countDigits(end);

        // Now check possible repeats by taking a pattern and repeting it
        // multiple times until it escapes the upper bound.
        var base: u64 = 1;
        while (true) {
            const base_n = countDigits(base);
            if (2 * base_n > e_n) break;

            var next_invalid_id = base;

            next_pat: while (true) {
                next_invalid_id = next_invalid_id * std.math.pow(u64, 10, base_n) + base;

                if (next_invalid_id < start) continue;

                if (next_invalid_id <= end and notInArrayList(invalid_ids, next_invalid_id)) {
                    try invalid_ids.append(allocator, next_invalid_id);
                } else {
                    break :next_pat;
                }
            }

            base += 1;
        }

        // Sum the invalid Ids to the final result.
        for (invalid_ids.items) |id| result += @intCast(id);

        // Done with this range.
        // print("{} ({} digits) - {} ({} digits): {any}\n", .{ start, s_n, end, e_n, invalid_ids.items });
    }

    return result;
}

fn countDigits(number: u64) u64 {
    if (number != 0) {
        const log = std.math.log10_int(number);
        return @intCast(log + 1);
    } else {
        return 1;
    }
}

fn notInArrayList(list: std.ArrayList(u64), value: u64) bool {
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

    const expected: i64 = 1_227_775_554;

    try std.testing.expectEqual(expected, solve_part_1(allocator, data));
}

test "part 2 sample" {
    const data = @embedFile("sample2.txt");
    const allocator = std.testing.allocator;

    const expected: i64 = 4174_379_265;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}
