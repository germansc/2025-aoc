const std = @import("std");
const print = std.debug.print;

const Op = enum { PRODUCT, SUM };

const Problem = struct {
    operands: std.ArrayList(i64),
    op: Op,

    fn result(self: Problem) i64 {
        var total: i64 = 0;
        if (self.op == .PRODUCT) total = 1;

        for (self.operands.items) |val| {
            switch (self.op) {
                .PRODUCT => total *= val,
                .SUM => total += val,
            }
        }

        return total;
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
    var probs = std.ArrayList(Problem).empty;
    defer probs.deinit(allocator);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var first_line = true;

    while (lines.next()) |line| {
        var values = std.mem.tokenizeScalar(u8, line, ' ');
        var idx: usize = 0;

        while (values.next()) |val| {
            if (first_line) try probs.append(allocator, .{ .op = .SUM, .operands = .{} });

            switch (val[0]) {
                '*' => probs.items[idx].op = .PRODUCT,
                '+' => probs.items[idx].op = .SUM,
                else => {
                    const v = try std.fmt.parseInt(i64, val, 10);
                    try probs.items[idx].operands.append(allocator, v);
                },
            }

            idx += 1;
        }

        if (first_line) first_line = false;
    }

    var part1: i64 = 0;
    for (probs.items) |prob| {
        // print("DBG: {any} = {}\n", .{ prob, prob.result() });
        part1 += prob.result();
    }

    // Cleanup
    for (probs.items) |*prob| {
        prob.*.operands.clearAndFree(allocator);
    }

    return part1;
}

fn solve_part_2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    const n_prob = std.mem.count(u8, input, "+") + std.mem.count(u8, input, "*");
    var probs = std.ArrayList(Problem).empty;
    defer probs.deinit(allocator);

    // Preallocate the known amount of probs.
    for (0..n_prob) |_| try probs.append(allocator, .{ .op = .SUM, .operands = .{} });

    const width = std.mem.indexOfScalar(u8, input, '\n') orelse input.len;
    const height: u64 = std.mem.count(u8, input, "\n");

    var charmap = try allocator.alloc(u8, width * height);
    defer allocator.free(charmap);

    var it = std.mem.tokenizeScalar(u8, input, '\n');
    var idx: usize = 0;
    while (it.next()) |line| {
        @memcpy(charmap[idx .. idx + line.len], line);
        idx += line.len;
    }

    // Run the map backwards, generating the values, until an operand is found
    // in the last line, that's a full problem.
    var i: usize = width - 1;
    var n: usize = 0;
    while (i >= 0) {
        var skip: usize = 0;
        var str_val: [5]u8 = undefined;
        for (0..height) |h| str_val[h] = charmap[i + h * width];

        const v = try std.fmt.parseInt(i64, std.mem.trim(u8, str_val[0 .. height - 1], " "), 10);
        try probs.items[n].operands.append(allocator, v);

        switch (str_val[height - 1]) {
            '*' => {
                probs.items[n].op = .PRODUCT;
                skip = 1;
                n += 1;
            },
            '+' => {
                probs.items[n].op = .SUM;
                skip = 1;
                n += 1;
            },
            else => {},
        }

        i = std.math.sub(usize, i, 1 + skip) catch {
            break;
        };
    }

    var part2: i64 = 0;
    for (probs.items) |prob| {
        // print("DBG: {any} = {}\n", .{ prob, prob.result() });
        part2 += prob.result();
    }

    for (probs.items) |*prob| {
        prob.*.operands.clearAndFree(allocator);
    }

    return part2;
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

    const expected: i64 = 4277556;

    try std.testing.expectEqual(expected, solve_part_1(allocator, data));
}

test "part 2 sample" {
    const data = @embedFile("sample.txt");
    const allocator = std.testing.allocator;

    const expected: i64 = 3263827;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}
