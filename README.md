# 2025 - Advent of Code

This repo contains my solution to the 2025 Advent of Code puzzles.

This year's language of choice will be `zig`. Given my unfamiliarity with its
base concepts and standard lib, I expect this year to be a particular challenge.

### Repository Structure

As usual, each day's puzzle is organized in a separate directory with its own
directory. The solution for each day is implemented to take input from `stdin`
and print the result to `stdout`; `stderr` might be used for some info logging
or other annotations. The directory for each day contains the following
structure:

```
dayXX/
├── main.zig        # Solution implementation
├── input.txt       # Raw input data for the puzzle
├── sample.txt      # Example input extracted from the puzzle description
└── puzzle.md       # The original puzzle description
```

### Running the solutions

The `build.zig` package automatically detects all days implemented, and adds
targets to create their solutions, so to execute a specific day, simply run:

```bash
# Redirecting input to stdin:
zig build day01 < day01/input.txt

# or simply piping the input:
cat day01/input.txt | zig build day01
```

To build all solutions, for benchmarking or whatever, simply:

```bash
zig build
```

###### 2025 | germansc
