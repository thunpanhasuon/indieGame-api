const std = @import("std");
const zap = @import("zap");

const ApiInfo = struct {
    name: []const u8,
    version: []const u8,
    api_version: []const u8,
};
pub const homePageEndpoint = struct {
    path: []const u8 = "/app/doc",
    error_strategy: zap.Endpoint.ErrorStrategy = .log_to_response,

    pub fn get(_: *homePageEndpoint, req: zap.Request) !void {
        req.setContentType(.HTML) catch return;
        try req.sendBody(
            \\ <html>
            \\   <head>
            \\     <title>weather-api</title>
            \\   </head>
            \\   <body>
            \\     <h1>weather-api</h1>
            \\     <p>This project proves Zig can run a small REST-style web server.</p>
            \\     <p>The server calls Open-Meteo, then returns the weather JSON from Zig.</p>
            \\     <h2>Available Endpoints</h2>
            \\     <ul>
            \\       <li>GET /app/healthz: server health check</li>
            \\       <li>GET /app/doc: this documentation page</li>
            \\       <li>GET /api/v1/weather: weather for Phnom Penh by default</li>
            \\       <li>GET /api/v1/weather?lat=13.7563&amp;lon=100.5018: weather for custom coordinates</li>
            \\       <li>POST /api/users: create a local demo user</li>
            \\       <li>POST /api/login: verify a local demo user's password</li>
            \\     </ul>
            \\     <h2>Try It</h2>
            \\     <pre>curl "http://localhost:3000/api/v1/weather"</pre>
            \\     <pre>curl "http://localhost:3000/api/v1/weather?lat=13.7563&amp;lon=100.5018"</pre>
            \\     <p>No weather API key is required for this demo.</p>
            \\   </body>
            \\ </html>
        );
    }
};
