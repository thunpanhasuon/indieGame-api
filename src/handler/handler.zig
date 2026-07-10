const std = @import("std");
const zap = @import("zap");

pub fn static_page(req: zap.Request) !void {
    try req.sendBody(
        \\ <html>
        \\   <body>
        \\     <h1>Hello, Welcome To Indie Game API v1 :)) </h1>
        \\   </body>
        \\ </html>
    );
}

const ApiInfo = struct {
    name: []const u8, 
    version: []const u8, 
    api_version: []const u8,
};

pub fn handle_info(req: zap.Request) !void {
    const parse = try std.json.parseFromSlice(
        ApiInfo, 
        std.heap.page_allocator, 
        \\{ "name": "indie-rest", "version": "0.0.1", "api_version": "v1"}
        ,.{},
    ); 
    defer parse.deinit();
     
    var output: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try std.json.Stringify.value(
        parse.value,
        .{},
        &writer,
    );

    try req.sendBody(writer.buffered());
}
