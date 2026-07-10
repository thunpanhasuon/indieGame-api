const std = @import("std");
const zap = @import("zap");

pub fn main() !void {
    // 1. Initialize the HTTP listener on port 3000
    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request,
    });
    try listener.listen();

    std.debug.print("Server running on http://localhost:3000\n", .{});

    // 2. Start the worker thread pool
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}

// 3. Define your request handler
fn on_request(r: zap.Request) !void {
    try r.sendBody("Hello world!");
}
