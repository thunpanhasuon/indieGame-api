const std = @import("std");
const zap = @import("zap");
const config = @import("utils.zig");
const app = @import("router.zig");

// health end point that return status of a server
//
fn dispatch_routes(req: zap.Request) !void {
    if (req.path) |path| {
        if (std.mem.eql(u8, path, "/app/healthz")) {
            // error code 200
            req.setStatus(.ok);
            req.sendBody("{\"status\":\"ok\"}") catch return;
            return;
        }
    }
    if (try app.dispatch(req)) {
        return;
    }

    // error code 404 fall back
    req.setStatus(.not_found);
    req.sendBody("Not Found") catch return;
}
pub fn main(init: std.process.Init) !void {
    _ = config.process_env(init) catch |err| {
        std.debug.print("processing env failure {}.\n", .{err});
    };

    // set up app route
    //
    try app.set_routes(std.heap.page_allocator);

    // Initialize the HTTP listener on port 3000
    //
    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = dispatch_routes,
    });
    try listener.listen();

    std.debug.print("Server running on http://localhost:3000\n", .{});

    // Start the worker thread pool
    //
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}
