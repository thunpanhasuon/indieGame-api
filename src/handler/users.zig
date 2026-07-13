const std = @import("std");
const util = @import("../utils.zig");
const zap = @import("zap");

const User = struct {
    email: []const u8,
    password: []const u8,
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
        std.debug.print("Email: {s}\nPassword: {s}\n", .{
            user.email,
            user.password,
        });
        req.sendJson("{\"status\":\"created\"}") catch return;
    }
};
