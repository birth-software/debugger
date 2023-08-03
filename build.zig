const std = @import("std");
const assert = std.debug.assert;
const zgui = @import("libs/zig-gamedev/libs/zgui/build.zig");

// Needed for glfw/wgpu rendering backend
const zglfw = @import("libs/zig-gamedev/libs/zglfw/build.zig");
const zgpu = @import("libs/zig-gamedev/libs/zgpu/build.zig");
const zpool = @import("libs/zig-gamedev/libs/zpool/build.zig");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "debugger",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    const zgui_pkg = zgui.package(b, target, optimize, .{
        .options = .{ .backend = .glfw_wgpu },
    });

    zgui_pkg.link(exe);

    // Needed for glfw/wgpu rendering backend
    const zglfw_pkg = zglfw.package(b, target, optimize, .{});
    const zpool_pkg = zpool.package(b, target, optimize, .{});
    const zgpu_pkg = zgpu.package(b, target, optimize, .{
        .deps = .{ .zpool = zpool_pkg.zpool, .zglfw = zglfw_pkg.zglfw },
    });

    zglfw_pkg.link(exe);
    zgpu_pkg.link(exe);

    const test_directory_name = "test";
    const test_directory = try std.fs.cwd().openIterableDir(test_directory_name, .{});
    var test_directory_iterator = test_directory.iterate();
    var c_source_file_count: usize = 0;
    var c_executables = std.ArrayList(*std.Build.CompileStep).init(b.allocator);
    while (try test_directory_iterator.next()) |entry| {
        switch (entry.kind) {
            .file => {
                const file_name = entry.name;

                if (file_name.len >= 2 and file_name[file_name.len - 2] == '.' and file_name[file_name.len - 1] == 'c') {
                    defer c_source_file_count += 1;

                    const executable = b.addExecutable(.{
                        .name = file_name[0 .. file_name.len - 2],
                        .target = target,
                        .optimize = optimize,
                    });

                    const c_source_file_relative_path = try std.mem.concat(b.allocator, u8, &.{ test_directory_name ++ "/", file_name });
                    const c_flags = &.{"-g"};
                    executable.addCSourceFile(.{ .file = std.Build.LazyPath.relative(c_source_file_relative_path), .flags = c_flags });
                    executable.linkLibC();

                    try c_executables.append(executable);
                }
            },
            else => {},
        }
    }

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.addArtifactArg(c_executables.items[0]);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
