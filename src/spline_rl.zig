const std = @import("std");
const rl = @import("raylib");
const spline = @import("spline.zig");

pub fn SplineRL(Tp: type) type {
    if (@typeInfo(Tp) != .Float) {
        @compileError("SplineRL is well-defined only for floats");
    }

    return struct {
        spline: Spline,
        us: []const Tp,
        allocator: std.mem.Allocator,

        const Self = @This();
        pub const T = Tp;
        pub const Spline = spline.SplineSoA(.{ .T = Tp, .dim = 2 });

        pub fn init(allocator: std.mem.Allocator, sp: Spline, us: []const T) !Self {
            std.debug.assert(us.len >= 2);
            return Self{
                .spline = sp,
                .us = try allocator.dupe(T, us),
                .allocator = allocator,
            };
        }

        pub fn init_from_dists(allocator: std.mem.Allocator, sp: Spline, dists: []const T) !Self {
            std.debug.assert(dists.len >= 2);

            var us = try allocator.alloc(T, dists.len);

            var dt: T = dists[0];
            for (0..us.len) |i| {
                dt += dists[i];
                us[i] = dt;
            }

            return Self{
                .spline = sp,
                .us = us,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            self.spline.deinit();
            self.allocator.free(self.us);
        }

        pub fn drawSpline2Dpts(self: Self, thick: f32, scale: f64) void {
            const logger = std.log.scoped(.drawSpline2Dpts);
            for (self.spline.ts, 0..) |t, idx| {
                if (self.spline.at(t)) |res| {
                    const xy: rl.Vector2 = .{
                        .x = @floatCast(res[0] * scale),
                        .y = @floatCast(-res[1] * scale),
                    };
                    rl.drawCircleV(xy, thick, rl.Color.blue);
                    {
                        const text = std.fmt.allocPrintZ(self.allocator, "{}", .{idx});
                        if (text) |val| {
                            defer self.allocator.free(val);
                            rl.drawTextEx(rl.getFontDefault(), val, xy, 1, 1, rl.Color.red);
                            // rl.drawText(val, @intFromFloat(xy.x), @intFromFloat(xy.y), 1, rl.Color.red);
                        } else |err| {
                            switch (err) {
                                else => {
                                    logger.warn("{}", .{err});
                                },
                            }
                        }
                    }
                } else |err| {
                    logger.warn("{}, t = {}", .{ err, t });
                    continue;
                }
            }
        }

        pub fn drawSpline2D(self: Self, thick: f32, scale: f64) void {
            const logger = std.log.scoped(.drawSpline2D);
            const color = rl.Color.alpha(rl.Color.green, 0.5);
            var prev: rl.Vector2 = undefined;
            var first = true;
            for (self.us) |u| {
                if (self.spline.at(u)) |res| {
                    const xy: rl.Vector2 = .{
                        .x = @floatCast(res[0] * scale),
                        .y = @floatCast(-res[1] * scale),
                    };

                    if (!first) {
                        rl.drawLineEx(prev, xy, thick, color);
                        // rl.drawSplineSegmentLinear(prev, xy, thick, rl.colorAlpha(rl.Color.red, 0.5));
                        // rl.drawLineV(prev, xy, rl.Color.green);
                    } else {
                        first = false;
                    }
                    rl.drawCircleV(xy, thick / 2, color);
                    prev = xy;
                } else |err| {
                    logger.warn("{}, u = {}", .{ err, u });
                    continue;
                }
            }
        }

        pub fn jsonStringify(self: Self, jw: anytype) !void {
            try jw.beginObject();
            try jw.objectField("spline");
            try jw.write(self.spline);
            try jw.objectField("dus");
            try jw.beginArray();
            for (self.us) |u| {
                try jw.write(u);
            }
            try jw.endArray();
            try jw.endObject();
        }

        pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, opts: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!Self {
            if (.object_begin != try source.next()) {
                return error.UnexpectedToken;
            }

            var res: struct {
                spline: ?Spline = null,
                dus: ?[]const Tp = null,
            } = .{};

            while (true) {
                const token = try source.nextAlloc(allocator, opts.allocate.?);
                switch (token) {
                    inline .string, .allocated_string => |k| {
                        if (std.mem.eql(u8, k, "spline")) {
                            if (res.spline != null) {
                                switch (opts.duplicate_field_behavior) {
                                    .use_first => {
                                        _ = try std.json.innerParse(Self.Spline, allocator, source, opts);
                                        continue;
                                    },
                                    .@"error" => return error.DuplicateField,
                                    .use_last => {},
                                }
                            }
                            res.spline = try std.json.innerParse(Self.Spline, allocator, source, opts);
                        } else if (std.mem.eql(u8, k, "dus")) {
                            if (res.dus != null) {
                                switch (opts.duplicate_field_behavior) {
                                    .use_first => {
                                        _ = try std.json.innerParse([]const T, allocator, source, opts);
                                        continue;
                                    },
                                    .@"error" => return error.DuplicateField,
                                    .use_last => {},
                                }
                            }
                            res.dus = try std.json.innerParse([]const T, allocator, source, opts);
                        }
                    },
                    .object_end => break,
                    else => unreachable,
                }
            }

            if (res.spline == null or res.dus == null) {
                return error.MissingField;
            }

            if (res.dus.?.len < 2) {
                return error.LengthMismatch;
            }

            return try Self.init_from_dists(allocator, res.spline.?, res.dus.?);
        }
        // pub fn jsonParse(allocator: std.mem.Allocator, scanner_or_reader: anytype, opts: std.json.ParseOptions) !Self {
        //     const SpRLJs = struct {
        //         spline: Spline,
        //         us: ?[]const Tp,
        //     };
        //
        //     var arena = std.heap.ArenaAllocator.init(allocator);
        //     defer arena.deinit();
        //
        //     const sp = std.json.parseFromTokenSource(SpRLJs, arena.allocator(), scanner_or_reader, opts);
        //     return if (sp) |val| Self{ .spline = val.value.spline, .us = val.value.us, .allocator = arena.allocator() } else |err| switch (err) {
        //         else => err,
        //     };
        // }
    };
}
