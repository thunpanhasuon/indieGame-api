const std = @import("std");
const db = @import("../database/db.zig");
const util = @import("../utils.zig");
const zap = @import("zap");

pub const User = struct {
    email: []const u8,
    password: []const u8,
};

pub const LoginEndpoint = struct {
    path: []const u8 = "/api/login",
    error_strategy: zap.Endpoint.ErrorStrategy = .log_to_response,

    pub fn post(_: *LoginEndpoint, req: zap.Request) !void {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const body = req.body orelse {
            req.setStatus(.bad_request);
            req.sendJson("{\"error\":\"missing request body\"}") catch return;
            return;
        };

        const parsed = std.json.parseFromSlice(User, allocator, body, .{}) catch {
            req.setStatus(.bad_request);
            req.sendJson("{\"error\":\"invalid json\"}") catch return;
            return;
        };
        defer parsed.deinit();

        const request = parsed.value;
        const conn = db.db_connection() catch |err| {
            std.debug.print("fail to connect to the database -> {}", .{err});
            req.setStatus(.internal_server_error);
            req.sendJson("{\"error\":\"database connection failed\"}") catch return;
            return;
        };
        defer db.close_connection(conn);

        const credentials = try db.getEmail(allocator, conn, request.email);
        const valid = if (credentials) |creds| blk: {
            defer creds.deinit(allocator);
            break :blk try util.hash_password_verify_with_argon(
                allocator,
                request.password,
                creds.hash_password,
            );
        } else false;

        if (!valid) {
            req.setStatus(.unauthorized);
            req.sendJson("{\"error\":\"invalid credentials\"}") catch return;
            return;
        }

        req.setStatus(.ok);
        req.sendJson("{\"status\":\"logged_in\"}") catch return;
    }
};

pub const UsersEndpoint = struct {
    path: []const u8 = "/api/users",
    error_strategy: zap.Endpoint.ErrorStrategy = .log_to_response,

    pub fn post(_: *UsersEndpoint, req: zap.Request) !void {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const body = req.body orelse {
            req.setStatus(.bad_request);
            req.sendBody("invalid-requesst") catch return;
            return;
        };

        const parsed = std.json.parseFromSlice(User, allocator, body, .{}) catch {
            req.setStatus(.bad_request);
            req.sendBody("Invalid JSON") catch return;
            return;
        };
        defer parsed.deinit();

        const request = parsed.value;
        const hash_password = util.hash_password_with_argon(allocator, request.password);
        const user = User{
            .email = request.email,
            .password = hash_password,
        };

        // create use to the database
        //
        const conn = db.db_connection() catch |err| {
            std.debug.print("fail to connect to the database -> {}", .{err});
            return;
        };
        defer db.close_connection(conn);
        try db.createTable(conn);

        const c_email = try allocator.dupeZ(u8, user.email);
        const c_password = try allocator.dupeZ(u8, user.password);
        db.createUser(conn, c_email, c_password) catch |err| switch (err) {
            error.DuplicateEmail => std.debug.print("user already exists\n", .{}),
            else => return err,
        };

        std.debug.print("Email: {s}\nPassword: {s}\n", .{
            user.email,
            user.password,
        });
        req.sendJson("{\"status\":\"created\"}") catch return;
    }
};
