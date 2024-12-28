const std = @import("std");
const rl = @import("raylib");
const spline = @import("spline.zig");

pub fn SplineRL(T: type) type {
    if (@typeInfo(T) != .Float) {
        @compileError("SplineRL is well-defined only for floats");
    }

    return struct {
        spline: spline.SplineSoA(.{ .T = T, .dim = 2 }),
        us: ?[]const T,

        const Self = @This();

        pub fn jsonDump(self: Self, opts: std.json.StringifyOptions, out_stream: anytype) @TypeOf(out_stream).Error!void {
            var jw = std.json.writeStreamMaxDepth(out_stream, opts, 8);
            try jw.beginObject();
            try jw.write(self.spline);
            try jw.objectField("us");
            try jw.beginArray();
            if (self.us) |us| {
                while (us) |u| {
                    try jw.write(u);
                }
            }
            try jw.endArray();
            try jw.endObject();
        }

        // pub fn jsonLoad(allocator: std.mem.Allocator, scanner_or_reader: anytype, opts: std.json.ParseOptions) !Self {
        //     const SpJs = struct {
        //         ts: []const T,
        //         vs: []const [dim]T,
        //     };
        //
        //     var arena = std.heap.ArenaAllocator.init(allocator);
        //     defer arena.deinit();
        //
        //     const res = try std.json.parseFromTokenSource(SpJs, arena.allocator(), scanner_or_reader, opts);
        //
        //     return init_from_points(allocator, res.value.ts, res.value.vs);
        // }
    };
}
