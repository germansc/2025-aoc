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
    var graph = std.StringHashMap(std.ArrayList([]const u8)).init(allocator);
    defer {
        var it = graph.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        graph.deinit();
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var parts = std.mem.splitSequence(u8, line, ": ");
        const device = parts.next() orelse continue;
        const outputs_str = parts.next() orelse continue;

        var outputs = std.ArrayList([]const u8).empty;
        var output_iter = std.mem.splitScalar(u8, outputs_str, ' ');
        while (output_iter.next()) |output| {
            if (output.len > 0) {
                try outputs.append(allocator, output);
            }
        }

        try graph.put(device, outputs);
    }

    var memo = std.HashMap(MemoKey, i64, MemoContext, std.hash_map.default_max_load_percentage).init(allocator);
    defer memo.deinit();

    const path_count = try countPaths(&graph, &memo, "you", "out", .{ true, true });
    return @intCast(path_count);
}

fn solve_part_2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var graph = std.StringHashMap(std.ArrayList([]const u8)).init(allocator);
    defer {
        var it = graph.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }
        graph.deinit();
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var parts = std.mem.splitSequence(u8, line, ": ");
        const device = parts.next() orelse continue;
        const outputs_str = parts.next() orelse continue;

        var outputs = std.ArrayList([]const u8).empty;
        var output_iter = std.mem.splitScalar(u8, outputs_str, ' ');
        while (output_iter.next()) |output| {
            if (output.len > 0) {
                try outputs.append(allocator, output);
            }
        }

        try graph.put(device, outputs);
    }

    var memo = std.HashMap(MemoKey, i64, MemoContext, std.hash_map.default_max_load_percentage).init(allocator);
    defer memo.deinit();

    const path_count = try countPaths(&graph, &memo, "svr", "out", .{ false, false });
    return @intCast(path_count);
}

// For part 2, needed.
const MemoKey = struct {
    node: []const u8,
    seen: [2]bool,
};

const MemoContext = struct {
    pub fn hash(self: @This(), key: MemoKey) u64 {
        _ = self;
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHashStrat(&hasher, key.node, .Deep);
        std.hash.autoHashStrat(&hasher, key.seen, .Deep);
        return hasher.final();
    }

    pub fn eql(self: @This(), a: MemoKey, b: MemoKey) bool {
        _ = self;
        return std.mem.eql(u8, a.node, b.node) and
            a.seen[0] == b.seen[0] and
            a.seen[1] == b.seen[1];
    }
};

fn countPaths(
    graph: *std.StringHashMap(std.ArrayList([]const u8)),
    memo: *std.HashMap(MemoKey, i64, MemoContext, std.hash_map.default_max_load_percentage),
    current: []const u8,
    target: []const u8,
    seen: [2]bool,
) !i64 {
    const key = MemoKey{ .node = current, .seen = seen };
    if (memo.get(key)) |cached| return cached;

    var local_seen = seen;
    if (std.mem.eql(u8, current, "fft")) local_seen[0] = true;
    if (std.mem.eql(u8, current, "dac")) local_seen[1] = true;

    // reached target?
    if (std.mem.eql(u8, current, target)) {
        const result: u32 = if (local_seen[0] and local_seen[1]) 1 else 0;
        try memo.put(key, result);
        return result;
    }

    const neighbors = graph.get(current) orelse {
        try memo.put(key, 0);
        return 0;
    };

    var total: i64 = 0;
    for (neighbors.items) |neighbor| {
        total += try countPaths(graph, memo, neighbor, target, local_seen);
    }

    try memo.put(key, total);
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

    const expected: i64 = 5;

    try std.testing.expectEqual(expected, solve_part_1(allocator, data));
}

test "part 2 sample" {
    const data = @embedFile("sample2.txt");
    const allocator = std.testing.allocator;

    const expected: i64 = 2;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}
