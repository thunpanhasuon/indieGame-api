const std = @import("std");
const zap = @import("zap");

const User = struct {
    email: []const u8,
    password: []const u8,
};

pub fn create_user(req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (req.method != null and std.mem.eql(u8, req.method.?, "POST")) {
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
        const user = User{
            .email = request.email,
            .password = request.password,
        };
        std.debug.print("Email: {s}\nPassword: {s}\n", .{
            user.email,
            user.password,
        });
        req.sendJson("{\"status\":\"created\"}") catch return;
    }
}
