const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create executables for each day:
    const days = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };

    for (days) |day| {
        const day_str = b.fmt("day{d:02}", .{day});
        const src_path = b.fmt("{s}/main.zig", .{day_str});

        var cwd = std.fs.cwd();

        // Check if files exists.
        _ = cwd.statFile(day_str) catch continue;
        _ = cwd.statFile(src_path) catch continue;

        const exe = b.addExecutable(.{
            .name = day_str,
            .root_module = b.createModule(.{
                .root_source_file = b.path(src_path),
                .target = target,
                .optimize = optimize,
            }),
        });

        b.installArtifact(exe);

        // Also add a run step for the day.
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_cmd.addArgs(args);

        const run_step = b.step(day_str, b.fmt("Run {s}", .{day_str}));
        run_step.dependOn(&run_cmd.step);
    }
}
