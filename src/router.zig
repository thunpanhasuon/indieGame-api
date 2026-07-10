const std = @import("std");
const zap = @import("zap");
const handler = @import("handler/handler.zig");

var routes: std.StringHashMap(zap.HttpRequestFn) = undefined;

pub fn set_routes(a: std.mem.Allocator) !void {
    routes = std.StringHashMap(zap.HttpRequestFn).init(a);
    try routes.put("/app/home", handler.static_page);
    try routes.put("/api/info", handler.handle_info);
}

pub fn dispatch(req: zap.Request) !bool {
    if (req.path) |path| {
        if (routes.get(path)) |route| {
            try route(req);
            return true;
        }
    }

    return false;
}
