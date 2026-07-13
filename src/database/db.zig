const std = @import("std");
const util = @import("../utils.zig");

const c = @cImport({
    @cInclude("libpq-fe.h");
});
const config = @import("../config/config.zig");

// connected the postgressDB
//
pub fn db_connection() !void {
    // set up a simple allocator
    //
    var arena_allocator: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    const map_str = config.global_config.get("DB") orelse "not-found";
    const conn_str = util.remove_quotes(allocator, map_str) catch |err| {
        std.debug.print("Error occurred: {}\n", .{err});
        return;
    };

    const c_connection_str = try allocator.dupeZ(u8, conn_str);
    defer allocator.free(c_connection_str);

    const conn = c.PQconnectdb(c_connection_str);
    defer c.PQfinish(conn);

    if (c.PQstatus(conn) != c.CONNECTION_OK) {
        std.debug.print("Connection failed -> {s}\n", .{c.PQerrorMessage(conn)});
        std.debug.print("Actual Connection String -> {s}\n", .{c_connection_str});
        return error.ConnectionFailed;
    }
    std.debug.print("Connected!\n", .{});
}
