const std = @import("std");
const zap = @import("zap");
const db = @import("../database/db.zig");
const util = @import("../utils.zig");
// s_user (struct user)
const s_user = @import("../handler/users.zig");

pub const Context = struct {};
pub const Handler = zap.Middleware.Handler(Context);

pub const LoggingHandler = struct {
    handler: Handler,

    pub fn init(next: ?*Handler) LoggingHandler {
        return .{ .handler = Handler.init(onRequest, next) };
    }

    pub fn onRequest(handler: *Handler, req: zap.Request, context: *Context) !bool {
        std.debug.print("[LOG] Request from {s}\n", .{req.path orelse ""});
        return handler.handleOther(req, context);
    }
};
pub const authHandler = struct {
    handler: Handler,

    pub fn init(next: ?*Handler) authHandler {
        return .{ .handler = Handler.init(onRequest, next) };
    }

    pub fn onRequest(handler: *Handler, req: zap.Request, context: *Context) void!bool {
        // setting up auth by email
        //
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const body = req.body orelse {
            req.setStatus(.bad_request);
            req.sendBody("invalid-requesst") catch return;
            return;
        };
        const parsed = std.json.parseFromSlice(s_user.User, allocator, body, .{}) catch {
            req.setStatus(.bad_request);
            req.sendBody("Invalid JSON") catch return;
            return;
        };
        defer parsed.deinit();
        const request = parsed.value;
        const user = s_user.User{
            .email = request.email,
            .password = request.password,
        };
        const conn = db.db_connection() catch |err| {
            std.debug.print("fail to connect to the database -> {}", .{err});
            return;
        };
        const valid_auth = false;
        const creds = try db.getEmail(allocator, conn, user.email);
        if (creds) |cred| {
            defer cred.deinit(allocator);
            if (util.hash_password_verify_with_argon(allocator, user.password, cred.password)) {
                valid_auth = true;
            }
        }
        if (!valid_auth) {
            req.setContentType(.json) catch return;
            req.sendBody("{\"error\":\"Invalid credentials\"}") catch return;
            req.setStatus(.forbidden);
            return;
        }
        return handler.handleOther(req, context);
    }
};
//pub fn loginByEmail(req: zap.Request) bool {
//
//}
