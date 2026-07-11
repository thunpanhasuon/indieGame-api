const std = @import("std");
const zap = @import("zap");

pub fn static_page(req: zap.Request) !void {
    req.setContentType(.HTML) catch return;
    try req.sendBody(
        \\ <html>
        \\   <head>
        \\     <title>Indie Game API v1</title>
        \\   </head>
        \\   <body>
        \\     <h1>Welcome To Indie Game API v1 :))</h1>
        \\     <p>Discover and get recommendations for top indie games.</p>
        \\     <h2>Available Endpoints</h2>
        \\     <ul>
        \\       <li>GET /api/v1/items: list/browse indie games (filters: genre, platform, year, tags)</li>
        \\       <li>GET /api/v1/items/{id}: full details for one game</li>
        \\       <li>GET /api/v1/items/{id}/similar: "if you liked this" recommendations</li>
        \\       <li>GET /api/v1/recommendations: personalized feed (auth required)</li>
        \\       <li>GET /api/v1/trending: trending this week</li>
        \\       <li>GET /api/v1/random: surprise me!</li>
        \\       <li>GET /api/v1/search?q=: full-text search</li>
        \\       <li>GET /api/v1/tags: list of tags/genres</li>
        \\       <li>GET /api/v1/items/{id}/reviews: get reviews for a game</li>
        \\       <li>POST /api/v1/items/{id}/reviews: submit a review</li>
        \\     </ul>
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
    ,
        .{},
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
