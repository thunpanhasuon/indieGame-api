const utils = @import("../utils.zig");
const std = @import("std");

// global config for api
//
pub var global_config: std.StringHashMap([]const u8) = undefined;

pub fn init_config(allocator: std.mem.Allocator) void {
    global_config = std.StringHashMap([]const u8).init(allocator);
}
pub fn deinit_config() void {
    global_config.deinit();
}
// load all the global config
//
pub fn load_config(init: std.process.Init, allocator: std.mem.Allocator) !void {
    init_config(allocator);

    var maps = try utils.process_env(init, allocator);

    // Iterate every map, every entry
    //
    var it = maps.iterator();
    while (it.next()) |entry| {
        const key = try allocator.dupe(u8, entry.key_ptr.*);
        const value = try allocator.dupe(u8, entry.value_ptr.*);
        try global_config.put(key, value);
        std.debug.print("key: {s}, value: {s}\n", .{ key, value });
    }
}
