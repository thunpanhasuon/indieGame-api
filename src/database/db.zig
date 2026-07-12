const std = @import("std");
const c = @import({
    @cInclude("libpq-fe.h");
});

// connected the postgressDB
//
pub fn db_connection() !void {
    const connection_str = "Hello Postgress";
    const conn = c.PQconnectdb(connection_str);
    defer c.PQfinish(conn);

    if (c.PQstatus(conn) != c.CONNECTION_OK) {
        std.debug.print("Connection failed: {s}\n", .{c.PQerrorMessage(conn)});
        return error.ConnectionFailed;
    }
    std.debug.print("Connected!\n", .{});
}
