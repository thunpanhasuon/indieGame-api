const std = @import("std");

pub fn hash_password_verify_with_argon(allocator: std.mem.Allocator, input: []const u8, hash_input: []const u8) !bool {
    return std.crypto.pwhash.argon2.strVerify(
        input,
        hash_input,
        .{ .allocator = allocator },
    );
}
pub fn hash_password_with_argon(allocator: std.mem.Allocator, input: []const u8) []const u8 {
    var threaded_io = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer threaded_io.deinit();

    const io = threaded_io.io();

    const out_hash = allocator.alloc(u8, 128) catch |err| {
        std.debug.panic("failed to allocate argon2 hash buffer: {}", .{err});
    };

    const opts = std.crypto.pwhash.argon2.HashOptions{
        .allocator = allocator,
        .params = std.crypto.pwhash.argon2.Params.interactive_2id,
        .encoding = .phc,
    };

    const hash = std.crypto.pwhash.argon2.strHash(input, opts, out_hash, io) catch |err| {
        allocator.free(out_hash);
        std.debug.panic("argon2 password hashing failed: {}", .{err});
    };
    std.debug.print("Password successfully hashed!\n", .{});
    return hash;
}

pub fn remove_quotes(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    // create a arraylist
    //
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);

    for (input) |c| {
        if (c != '"' and c != '\'') {
            try list.append(allocator, c);
        }
    }
    return list.toOwnedSlice(allocator);
}
pub fn process_env(init: std.process.Init, allocator: std.mem.Allocator) !std.StringHashMap([]const u8) {
    // init the file file read
    //
    const io = init.io;
    const file = try std.Io.Dir.cwd().openFile(io, "./src/.env", .{});
    defer file.close(io);

    // set up buffering for io
    //
    var buff: [4096]u8 = undefined;
    var buff_reader = file.reader(io, &buff);

    const reader: *std.Io.Reader = &buff_reader.interface;

    // create a map
    //
    var map: std.StringHashMap([]const u8) = .init(allocator);
    while (try reader.takeDelimiter('\n')) |line| {
        std.debug.print("Line: {s}\n", .{line});
        const eq_pos = std.mem.indexOfScalar(u8, line, '=') orelse return error.NoEquals;
        const key = line[0..eq_pos];
        const value = line[eq_pos + 1 ..];
        std.debug.print("key: {s}, value: {s}\n", .{ key, value });
        // copy value into map
        //
        try map.put(key, value);
    }

    return map;
}
