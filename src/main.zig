const std = @import("std");
const zap = @import("zap");
const middleware = @import("./middleware/middleware.zig");
const ep_home = @import("./handler/handler.zig");
const ep_weather = @import("./handler/weather.zig");
const ep_user = @import("./handler/users.zig");
const config = @import("./config/config.zig");

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
    // Build the request chain from the end back to the start:
    // fallback handles anything no endpoint matched.
    // user_handler handles POST /api/users, then falls back.
    // login_handler handles POST /api/login, then falls through to users.
    // weather_handler handles GET /api/v1/weather, then falls through to login.
    // home_handler handles GET /app/doc, then falls through to weather.
    // logger is the first handler the listener calls.
    //
    // Final flow:
    // listener -> logger -> home_handler -> weather_handler -> login_handler -> user_handler -> fallback
    var fallback = Handler.init(dispatch_routes, null);

    var user_endpoint = ep_user.UsersEndpoint{ .path = "/api/users" };
    var user_handler = zap.Middleware.EndpointHandler(Handler, ep_user.UsersEndpoint, Context).init(&user_endpoint, &fallback, .{
        .checkPath = true,
    });

    var login_endpoint = ep_user.LoginEndpoint{ .path = "/api/login" };
    var login_handler = zap.Middleware.EndpointHandler(Handler, ep_user.LoginEndpoint, Context).init(&login_endpoint, user_handler.getHandler(), .{
        .checkPath = true,
    });

    var weather_endpoint = ep_weather.WeatherEndpoint{ .path = "/api/v1/weather" };
    var weather_handler = zap.Middleware.EndpointHandler(Handler, ep_weather.WeatherEndpoint, Context).init(&weather_endpoint, login_handler.getHandler(), .{
        .checkPath = true,
    });

    var home_end_point = ep_home.homePageEndpoint{ .path = "/app/doc" };
    var home_handler = zap.Middleware.EndpointHandler(
        Handler,
        ep_home.homePageEndpoint,
        Context,
    ).init(&home_end_point, weather_handler.getHandler(), .{ .checkPath = true });

    var logger = LoggingHandler.init(home_handler.getHandler());

    var listener = try zap.Middleware.Listener(Context).init(.{
        .on_request = null,
        .port = 3000,
        .log = true,
    }, &logger.handler, requestAllocator);
    try listener.listen();

    std.debug.print("Server running on http://localhost:3000\n", .{});

    // Local dev on macOS: keep one worker process.
    // workers > 1 enables facil.io cluster mode, which forks child processes.
    zap.start(.{
        .threads = 1,
        .workers = 1,
    });

    config.deinit_config();
}
