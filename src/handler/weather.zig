const std = @import("std");
const zap = @import("zap");

pub const WeatherEndpoint = struct {
    path: []const u8 = "/api/v1/weather",
    error_strategy: zap.Endpoint.ErrorStrategy = .log_to_response,

    pub fn get(_: *WeatherEndpoint, req: zap.Request) !void {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const latitude = req.getParamSlice("lat") orelse "11.5564";
        const longitude = req.getParamSlice("lon") orelse "104.9282";
        const weather_url = try std.fmt.allocPrint(
            allocator,
            "https://api.open-meteo.com/v1/forecast?latitude={s}&longitude={s}&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m&timezone=auto",
            .{ latitude, longitude },
        );

        var threaded_io = std.Io.Threaded.init(std.heap.page_allocator, .{});
        defer threaded_io.deinit();

        const io = threaded_io.io();
        var client = std.http.Client{ .allocator = allocator, .io = io };
        defer client.deinit();

        var raw_body: std.Io.Writer.Allocating = .init(allocator);
        defer raw_body.deinit();

        const result = client.fetch(.{
            .location = .{ .url = weather_url },
            .response_writer = &raw_body.writer,
        }) catch |err| {
            std.debug.print("Weather request failed: {}\n", .{err});
            req.setStatus(.bad_gateway);
            try req.sendJson("{\"error\":\"weather request failed\"}");
            return;
        };

        if (result.status != .ok) {
            std.debug.print("Weather API returned HTTP status {}\n", .{@intFromEnum(result.status)});
            req.setStatus(.bad_gateway);
            try req.sendJson("{\"error\":\"weather api returned non-ok status\"}");
            return;
        }

        const parsed = std.json.parseFromSlice(
            std.json.Value,
            allocator,
            raw_body.writer.buffered(),
            .{},
        ) catch |err| {
            std.debug.print("Weather JSON parse failed: {}\n", .{err});
            req.setStatus(.bad_gateway);
            try req.sendJson("{\"error\":\"weather api returned invalid json\"}");
            return;
        };
        defer parsed.deinit();

        var pretty: std.Io.Writer.Allocating = .init(allocator);
        defer pretty.deinit();

        try std.json.Stringify.value(
            parsed.value,
            .{ .whitespace = .indent_2 },
            &pretty.writer,
        );

        req.setStatus(.ok);
        try req.setContentType(.JSON);
        try req.sendBody(pretty.writer.buffered());
    }
};
