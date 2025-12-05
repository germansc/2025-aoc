const std = @import("std");
const print = std.debug.print;

const Range = struct {
    s: i64,
    e: i64,

    fn overlaps(self: Range, other: Range) bool {
        return self.s <= other.e and self.e >= other.s;
    }

    fn merge(self: Range, other: Range) Range {
        return .{
            .s = @min(self.s, other.s),
            .e = @max(self.e, other.e),
        };
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

    // Both parts can be solved on the same run.
    const results = try solve_parts(allocator, input);
    try stdout.print("Part 1: {d}\n", .{results.part1});
    try stdout.print("Part 2: {d}\n", .{results.part2});
}

fn solve_parts(allocator: std.mem.Allocator, input: []const u8) !struct { part1: i64, part2: i64 } {
    var ranges = std.ArrayList(Range).empty;
    defer ranges.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');

    var part1: i64 = 0;

    while (lines.next()) |line| {
        if (line.len == 0) break; // End of ranges

        var fields = std.mem.splitAny(u8, line, "-");
        const s_str = fields.next() orelse return error.InvalidInput;
        const e_str = fields.next() orelse return error.InvalidInput;

        const start = try std.fmt.parseInt(i64, s_str, 10);
        const end = try std.fmt.parseInt(i64, e_str, 10);

        // Add range to Arraylist, might merge with existing ranges.
        const new_range = Range{ .s = start, .e = end };
        try add_range(allocator, &ranges, new_range);
    }

    while (lines.next()) |line| {
        if (line.len == 0) break;

        const id = try std.fmt.parseInt(u64, line, 10);

        for (ranges.items) |range| {
            if ((id <= range.e) and (id >= range.s)) {
                part1 += 1;
                break;
            }
        }
    }

    // Part 2:
    var part2: i64 = 0;
    for (ranges.items) |r| {
        const ids = r.e - r.s + 1;

        // print("DEBUG: {} | total: {d}\n", .{ r, ids });
        part2 += ids;
    }

    return .{ .part1 = part1, .part2 = part2 };
}

fn add_range(allocator: std.mem.Allocator, ranges: *std.ArrayList(Range), new_range: Range) !void {
    var merged = new_range;

    var i: usize = 0;
    while (i < ranges.items.len) {
        const existing = ranges.items[i];

        if (existing.overlaps(merged)) {
            merged = merged.merge(existing);
            _ = ranges.orderedRemove(i);
        } else {
            i += 1;
        }
    }

    try ranges.append(allocator, merged);
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

    const expected_1: i64 = 3;
    const expected_2: i64 = 14;
    const results = try solve_parts(allocator, data);

    try std.testing.expectEqual(expected_1, results.part1);
    try std.testing.expectEqual(expected_2, results.part2);
}
