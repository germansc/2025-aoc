# 2025 - Advent of Code

This repo contains my solution to the 2025 Advent of Code puzzles.

This year's language of choice will be `zig`. Given my unfamiliarity with its
base concepts and standard lib, I expect this year to be a particular challenge.

## Repository Structure

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

The `template` directory contains a boilerplate package of a day's solution to
jump-start it's development.

## Development Environment

The project uses a Nix flake for its environment setup. To start a reproducible
shell and compile the solutions, simply run:

```bash
nix develop
```

## Running the solutions

The `build.zig` file automatically detects all days implemented based on the
already mentioned directory structure, and adds targets to create their
solutions. To execute a specific day, simply run:

```bash
# Redirecting input to stdin:
zig build day01 < day01/input.txt

# or simply piping the input:
cat day01/input.txt | zig build day01
```

And to build all solutions, for benchmarks or whatever:

```bash
zig build -Doptimize=ReleaseFast
```

###### 2025 | germansc
