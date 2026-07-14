const std = @import("std");
const util = @import("../utils.zig");

const c = @cImport({
    @cInclude("libpq-fe.h");
});
const config = @import("../config/config.zig");

pub const Credentials = struct {
    email: []const u8,
    hash_password: []const u8,

    pub fn deinit(self: Credentials, allocator: std.mem.Allocator) void {
        allocator.free(self.email);
        allocator.free(self.hash_password);
    }
};
// connected the postgressDB
//
pub fn db_connection() !?*c.PGconn {
    // set up a simple allocator
    //
    var arena_allocator: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    const map_str = config.global_config.get("DB") orelse "not-found";
    const conn_str = util.remove_quotes(allocator, map_str) catch |err| {
        std.debug.print("Error occurred: {}\n", .{err});
        return error.ConnectionFailed;
    };

    const c_connection_str = try allocator.dupeZ(u8, conn_str);
    defer allocator.free(c_connection_str);

    const conn = c.PQconnectdb(c_connection_str);

    if (c.PQstatus(conn) != c.CONNECTION_OK) {
        std.debug.print("Connection failed -> {s}\n", .{c.PQerrorMessage(conn)});
        std.debug.print("Actual Connection String -> {s}\n", .{c_connection_str});
        c.PQfinish(conn);
        return error.ConnectionFailed;
    }
    std.debug.print("Connected!\n", .{});

    return conn;
}

pub fn close_connection(conn: ?*c.PGconn) void {
    if (conn) |pg_conn| {
        c.PQfinish(pg_conn);
    }
}

pub fn createTable(conn: ?*c.PGconn) !void {
    const query =
        \\CREATE TABLE IF NOT EXISTS users (
        \\  id SERIAL PRIMARY KEY,
        \\  email TEXT NOT NULL UNIQUE,
        \\  password TEXT NOT NULL
        \\)
    ;
    const res = c.PQexec(conn, query);
    defer c.PQclear(res);

    if (c.PQresultStatus(res) != c.PGRES_COMMAND_OK) {
        std.debug.print("Create table failed: {s}\n", .{c.PQerrorMessage(conn)});
        return error.QueryFailed;
    }
}

pub fn createUser(conn: ?*c.PGconn, email: [*:0]const u8, password: [*:0]const u8) !void {
    const query = "INSERT INTO users (email, password) VALUES ($1, $2)";
    const params = [_]?[*:0]const u8{ email, password };

    const res = c.PQexecParams(
        conn,
        query,
        2,
        null,
        @ptrCast(&params),
        null,
        null,
        0,
    );

    defer c.PQclear(res);

    if (c.PQresultStatus(res) != c.PGRES_COMMAND_OK) {
        const err_msg = std.mem.span(c.PQerrorMessage(conn));
        if (std.mem.indexOf(u8, err_msg, "duplicate key") != null) {
            return error.DuplicateEmail;
        }
        std.debug.print("Insert failed: {s}\n", .{err_msg});
        return error.QueryFailed;
    }

    if (c.PQntuples(res) == 0) {
        return;
    }
}

pub fn getEmail(allocator: std.mem.Allocator, conn: ?*c.PGconn, email: []const u8) !?Credentials {
    const query = "SELECT email, password FROM users WHERE email = $1";
    const email_z = try allocator.dupeZ(u8, email);
    defer allocator.free(email_z);

    const params = [_]?[*:0]const u8{email_z};
    const res = c.PQexecParams(
        conn,
        query,
        1,
        null,
        @ptrCast(&params),
        null,
        null,
        0,
    );

    defer c.PQclear(res);

    if (c.PQresultStatus(res) != c.PGRES_TUPLES_OK) {
        std.debug.print("Query failed: {s}\n", .{c.PQerrorMessage(conn)});
        return error.QueryFailed;
    }

    if (c.PQntuples(res) == 0) {
        return null;
    }

    const email_val = c.PQgetvalue(res, 0, 0);
    const pass_val = c.PQgetvalue(res, 0, 1);

    return Credentials{
        .email = try allocator.dupe(u8, std.mem.span(email_val)),
        .hash_password = try allocator.dupe(u8, std.mem.span(pass_val)),
    };
}
