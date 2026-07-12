const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const target_os = target.result.os.tag;
    const libpq_prefix = b.option(
        []const u8,
        "libpq-prefix",
        "Path prefix containing libpq include/ and lib/ directories",
    );

    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false,
    });

    const exe = b.addExecutable(.{
        .name = "indie-rest",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "zap", .module = zap.module("zap") },
            },
        }),
    });
    exe.root_module.linkSystemLibrary("pq", .{
        .use_pkg_config = if (target_os.isDarwin()) .no else .yes,
    });

    if (libpq_prefix) |prefix| {
        addLibpqPrefix(exe.root_module, b, prefix, true);
    } else if (target_os.isDarwin()) {
        const homebrew_prefix = switch (target.result.cpu.arch) {
            .aarch64 => "/opt/homebrew/opt/libpq",
            else => "/usr/local/opt/libpq",
        };
        addLibpqPrefix(exe.root_module, b, homebrew_prefix, true);
    } else if (target_os == .linux) {
        exe.root_module.addIncludePath(.{ .cwd_relative = "/usr/include/postgresql" });
    }
    b.installArtifact(exe);
    const check_step = b.step("check", "Check if the code compiles");
    check_step.dependOn(&exe.step);

    const run_step = b.step("run", "Run the server");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}

fn addLibpqPrefix(module: *std.Build.Module, b: *std.Build, prefix: []const u8, add_rpath: bool) void {
    const include_dir = b.pathJoin(&.{ prefix, "include" });
    const lib_dir = b.pathJoin(&.{ prefix, "lib" });

    module.addIncludePath(.{ .cwd_relative = include_dir });
    module.addLibraryPath(.{ .cwd_relative = lib_dir });
    if (add_rpath) {
        module.addRPath(.{ .cwd_relative = lib_dir });
    }
}
