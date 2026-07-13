const std = @import("std");
const zap = @import("zap");

pub const Context = struct {};
pub const Handler = zap.Middleware.Handler(Context);

pub const LoggingHandler = struct {
    handler: Handler,

    pub fn init(next: ?*Handler) LoggingHandler {
        return .{ .handler = Handler.init(onRequest, next) };
    }

    pub fn onRequest(handler: *Handler, req: zap.Request, context: *Context) !bool {
        std.debug.print("[LOG] Request from {s}\n", .{req.path orelse ""});
        return handler.handleOther(req, context);
    }
};
//pub fn loginByEmail(req: zap.Request) bool {
//
//}
