const process_env = @import("../utils.zig"); 
const std = @import("std"); 

// global config for api 
//
pub var global_config: std.StringHashMap(i32) = .init(allocator);
defer global_config.deinit();

// load all the global config 
//
pub fn load_config(init: std.process.Init, allocator: std.mem.Allocator) !void {
    var maps = try process_env(init, allocator);
    defer {
        for (maps.items) |*map| map.deinit();
        maps.deinit(allocator);
    }

    // Iterate every map, every entry
    //
    for (maps.items, 0..) |*map, i| {
        std.debug.print("map[{d}]:\n", .{i});
        var it = map.iterator();
        while (it.next()) |entry| {
            try global_config.put(entry.key_ptr.*, entry.value_ptr.*); 
        }
    }
}


