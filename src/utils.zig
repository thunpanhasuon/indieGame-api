const std = @import("std");

pub fn process_env(init: std.process.Init, allocator: std.mem.Allocator) !std.ArrayList(std.StringHashMap([]const u8)) {
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

    // set up an empty list
    //
    var list: std.ArrayList(std.StringHashMap([]const u8)) = .empty;
    errdefer {
        for (list.items) |*map| map.deinit();
        list.deinit(allocator);
    }

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

    try list.append(allocator, map);
    return list;
}
