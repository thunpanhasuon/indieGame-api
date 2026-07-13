const std = @import("std");
const zap = @import("zap");
const middleware = @import("./middleware/middleware.zig");
const ep_user = @import("./handler/users.zig");
const config = @import("./config/config.zig");
const db = @import("./database/db.zig");

const Context = middleware.Context;
const Handler = middleware.Handler;
const LoggingHandler = middleware.LoggingHandler;

fn requestAllocator() std.mem.Allocator {
    return std.heap.page_allocator;
}

// health end point that return status of a server
//
fn dispatch_routes(_: *Handler, req: zap.Request, _: *Context) !bool {
    if (req.path) |path| {
        if (std.mem.eql(u8, path, "/app/healthz")) {
            // error code 200
            req.setStatus(.ok);
            try req.sendBody("{\"status\":\"ok\"}");
            return true;
        }
    }

    // error code 404 fall back
    req.setStatus(.not_found);
    try req.sendBody("Not Found");
    return true;
}
pub fn main(init: std.process.Init) !void {
    // setup allocator
    //
    var arena_allocator: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    // load the glabol config
    //
    config.load_config(init, allocator) catch |err| {
        std.debug.print("load configure failure {}\n", .{err});
    };

    // connect to database
    //
    db.db_connection() catch |err| {
        std.debug.print("can't connect to database {}\n", .{err});
    };

    // Initialize the HTTP listener on port 3000
    //
    var user_endpoint = ep_user.UsersEndpoint{ .path = "/api/users" };
    var fallback = Handler.init(dispatch_routes, null);
    var endpoint = zap.Middleware.EndpointHandler(Handler, ep_user.UsersEndpoint, Context).init(&user_endpoint, &fallback, .{
        .checkPath = true,
    });
    var logger = LoggingHandler.init(endpoint.getHandler());

    var listener = try zap.Middleware.Listener(Context).init(.{
        .on_request = null,
        .port = 3000,
        .log = true,
    }, &logger.handler, requestAllocator);
    try listener.listen();

    std.debug.print("Server running on http://localhost:3000\n", .{});

    // Start the worker thread pool
    //
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });

    config.deinit_config();
}
