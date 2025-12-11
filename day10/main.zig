const std = @import("std");
const print = std.debug.print;

const Machine = struct {
    allocator: std.mem.Allocator,
    lights: usize,
    buttons: []usize,
    joltage: []usize,
    jolts_per_button: [][]usize,

    fn deinit(self: Machine) void {
        self.allocator.free(self.buttons);
        self.allocator.free(self.joltage);

        for (self.jolts_per_button) |b| {
            self.allocator.free(b);
        }
        self.allocator.free(self.jolts_per_button);
    }

    fn init(allocator: std.mem.Allocator, line: []const u8) !Machine {
        // Parse lights:
        const bracket = std.mem.indexOf(u8, line, "]") orelse unreachable;
        var lights: usize = 0;

        for (line[1..bracket], 0..) |c, i| {
            const bit: u6 = @truncate(i);
            if (c == '#') lights |= (@as(usize, 1) << bit);
        }

        // Parse button list:
        var n = std.mem.count(u8, line[bracket + 2 ..], " ");
        var buttons: []usize = try allocator.alloc(usize, n);
        var jolts_per_button: [][]usize = try allocator.alloc([]usize, n);

        var it = std.mem.tokenizeScalar(u8, line[bracket + 2 ..], ' ');
        for (0..n) |i| {
            const str = it.next() orelse unreachable;

            const m = std.mem.count(u8, str, ",") + 1;
            var jolt_idsx: []usize = try allocator.alloc(usize, m);

            var v = std.mem.tokenizeScalar(u8, str[1 .. str.len - 1], ',');
            var val: usize = 0;
            var j: usize = 0;
            while (v.next()) |bit_s| {
                const jolts = try std.fmt.parseInt(usize, bit_s, 10);
                const bit: u6 = @truncate(jolts);

                // Add bit maks to light toggler.
                val |= (@as(usize, 1) << bit);

                // Add index of jolt counter affected by this button.
                jolt_idsx[j] = jolts;
                j += 1;
            }

            buttons[i] = val;
            jolts_per_button[i] = jolt_idsx;
        }

        // Parse Jolts
        const str = it.next() orelse unreachable;
        n = std.mem.count(u8, str, ",") + 1;
        var joltage: []usize = try allocator.alloc(usize, n);

        it = std.mem.tokenizeScalar(u8, str[1 .. str.len - 1], ',');
        for (0..n) |i| {
            const jolt = it.next() orelse unreachable;
            const value: usize = try std.fmt.parseInt(usize, jolt, 10);
            joltage[i] = value;
        }

        return .{
            .allocator = allocator,
            .lights = lights,
            .buttons = buttons,
            .joltage = joltage,
            .jolts_per_button = jolts_per_button,
        };
    }

    // Struct to represent the state in the BFS queue
    const State = struct {
        val: usize,
        start_idx: usize,
        steps: i64,
    };

    fn solve_lights(self: Machine) !i64 {
        if (self.lights == 0) return 0;

        var queue = std.ArrayList(State).empty;
        defer queue.deinit(self.allocator);

        var visited = std.AutoHashMap(usize, usize).init(self.allocator);
        defer visited.deinit();

        try queue.append(self.allocator, .{ .val = 0, .start_idx = 0, .steps = 0 });
        try visited.put(0, 0);

        var idx: usize = 0;

        while (idx < queue.items.len) {
            const current = queue.items[idx];
            idx += 1;

            for (current.start_idx..self.buttons.len) |i| {
                const btn_val = self.buttons[i];
                const new_val = current.val ^ btn_val;
                const new_steps = current.steps + 1;

                if (new_val == self.lights) {
                    return new_steps;
                }

                const new_start_idx = i + 1;
                const entry = try visited.getOrPut(new_val);
                if (!entry.found_existing or entry.value_ptr.* > new_start_idx) {
                    entry.value_ptr.* = new_start_idx;
                    try queue.append(self.allocator, .{ .val = new_val, .start_idx = new_start_idx, .steps = new_steps });
                }
            }
        }

        return error.NotFound;
    }

    fn solve_joltage(self: Machine) !i64 {
        const n_buttons = self.jolts_per_button.len;
        const n_counters = self.joltage.len;
        if (n_counters == 0) return 0;

        // Build the constraint matrix A where A[counter][button] = 1 if button affects counter
        var matrix = try self.allocator.alloc([]i64, n_counters);
        defer {
            for (matrix) |row| self.allocator.free(row);
            self.allocator.free(matrix);
        }

        for (matrix) |*row| {
            row.* = try self.allocator.alloc(i64, n_buttons);
            @memset(row.*, 0);
        }

        for (self.jolts_per_button, 0..) |jolt_idxs, b| {
            for (jolt_idxs) |idx| matrix[idx][b] = 1;
        }

        // Set an upper bound to stop the search if reached, to be twice of the max counter.
        var max_presses: usize = 0;
        for (self.joltage) |t| max_presses = @max(max_presses, t);
        max_presses *= 2;

        const presses = try findMinSolution(self.allocator, matrix, self.joltage, n_buttons, max_presses);
        return @intCast(presses);
    }
};

fn findMinSolution(
    allocator: std.mem.Allocator,
    matrix: []const []const i64,
    targets: []const usize,
    n_buttons: usize,
    max_bound: usize,
) !usize {
    // Use iterative deepening to find minimum
    var min_presses: usize = std.math.maxInt(usize);

    // Start with a reasonable bound
    var current_bound: usize = @min(max_bound, 50); // Start with smaller bound

    while (current_bound <= max_bound) : (current_bound += 10) {
        const presses = try allocator.alloc(usize, n_buttons);
        defer allocator.free(presses);
        @memset(presses, 0);

        if (try searchSolution(matrix, targets, presses, 0, current_bound, &min_presses)) {
            // Found a solution within this bound
            if (min_presses < current_bound) {
                break; // We won't find better by increasing bound
            }
        }

        // If we found a solution, try to find better in same bound
        if (min_presses < std.math.maxInt(usize)) break;
    }

    return min_presses;
}

fn searchSolution(
    matrix: []const []const i64,
    targets: []const usize,
    presses: []usize,
    button_idx: usize,
    remaining_budget: usize,
    best: *usize,
) error{OutOfMemory}!bool {
    const n_buttons = presses.len;
    // const n_counters = targets.len;

    // Base case: tried all buttons
    if (button_idx == n_buttons) {
        // Check if solution is valid
        var valid = true;
        for (targets, 0..) |target, c| {
            var sum: i64 = 0;
            for (presses, 0..) |press, b| {
                sum += @as(i64, @intCast(press)) * matrix[c][b];
            }
            if (sum != target) {
                valid = false;
                break;
            }
        }

        if (valid) {
            var total: usize = 0;
            for (presses) |p| total += p;
            if (total < best.*) {
                best.* = total;
                return true;
            }
        }
        return false;
    }

    // Current total
    var current_total: usize = 0;
    for (presses) |p| current_total += p;

    // Pruning: if current solution already exceeds best, stop
    if (current_total >= best.*) return false;

    // Try different values for current button
    var found = false;
    var tries: usize = 0;
    while (tries <= remaining_budget) : (tries += 1) {
        presses[button_idx] = tries;

        // Check if still feasible (no counter exceeded)
        var feasible = true;
        for (targets, 0..) |target, c| {
            var sum: i64 = 0;
            for (presses[0 .. button_idx + 1], 0..) |press, b| {
                sum += @as(i64, @intCast(press)) * matrix[c][b];
            }
            if (sum > target) {
                feasible = false;
                break;
            }
        }

        if (feasible) {
            if (try searchSolution(matrix, targets, presses, button_idx + 1, remaining_budget - tries, best)) {
                found = true;
                // Continue searching for better solution
            }
        }
    }

    presses[button_idx] = 0; // Reset
    return found;
}

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
    var machine_list = std.ArrayList(Machine).empty;
    defer machine_list.deinit(allocator);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const m = try Machine.init(allocator, line);
        try machine_list.append(allocator, m);
    }

    var part1: i64 = 0;

    for (machine_list.items) |m| {
        const presses = try m.solve_lights();
        part1 += presses;

        print("DBG: Machine reached {} in {} presses\n", .{ m.lights, presses });
        m.deinit();
    }

    return part1;
}

fn solve_part_2(allocator: std.mem.Allocator, input: []const u8) !i64 {
    var machine_list = std.ArrayList(Machine).empty;
    defer machine_list.deinit(allocator);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const m = try Machine.init(allocator, line);
        try machine_list.append(allocator, m);
    }

    var part2: i64 = 0;

    for (machine_list.items, 0..) |m, i| {
        const presses = try m.solve_joltage();
        part2 += presses;

        print("DBG: Machine {}/{} reached {any} in {d} presses\n", .{ i, machine_list.items.len, m.joltage, presses });
        m.deinit();
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

    const expected: i64 = 7;

    try std.testing.expectEqual(expected, solve_part_1(allocator, data));
}

test "part 2 sample" {
    const data = @embedFile("sample.txt");
    const allocator = std.testing.allocator;

    const expected: i64 = 33;

    try std.testing.expectEqual(expected, solve_part_2(allocator, data));
}
