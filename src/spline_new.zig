const std = @import("std");
const rl = @import("raylib");
const spline = @import("spline.zig");

pub fn Point2D(T: type) type {
    return struct {
        x: T,
        y: T,

        pub fn toRlVector2(self: @This()) rl.Vector2 {
            return .{
                .x = @floatCast(self.x),
                .y = @floatCast(self.y),
            };
        }

        pub fn fromRlVector2(vec: rl.Vector2) @This() {
            return @This(){
                .x = @floatCast(vec.x),
                .y = @floatCast(vec.y),
            };
        }

        pub fn fromArray(arr: [2]T) @This() {
            return @This(){
                .x = arr[0],
                .y = arr[1],
            };
        }

        pub fn eq(self: @This(), other: @This()) bool {
            return self.x == other.x and self.y == other.y;
        }
    };
}

pub fn uniformSpacingIterator(T: type) type {
    return struct {
        start: T,
        end: T,
        cur: usize,
        divs: usize,

        pub fn iterate(start: T, end: T, divs: usize) @This() {
            std.debug.assert(divs > 0);
            if (start > end) {
                std.log.err("{} > {}", .{ start, end });
            }
            std.debug.assert(start <= end);

            return @This(){
                .start = start,
                .end = end,
                .cur = 0,
                .divs = divs,
            };
        }

        pub fn next(self: *@This()) ?T {
            if (self.cur >= self.divs) {
                return null;
            }

            defer self.cur += 1;
            return self.start + (self.end - self.start) * @as(T, @floatFromInt(self.cur)) / @as(T, @floatFromInt(self.divs));
        }
    };
}

pub fn SplineUI(Tp: type) type {
    return struct {
        pub const Self = @This();
        pub const T = Tp;
        pub const Point = Point2D(T);

        const ArrayList = std.ArrayList;
        const Dynamic = struct {
            spline: Spline2D(T),
            bbox: rl.Rectangle,
        };

        dts: ArrayList(T),
        pts: ArrayList(Point),
        gran_us: ArrayList(usize),
        dynamic: Dynamic,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, dts: []const T, pts: []const Point, gran_us: []const usize) !Self {
            std.debug.assert(dts.len >= 2);
            std.debug.assert(pts.len == dts.len);
            std.debug.assert(gran_us.len >= 2);

            var s_dts = try ArrayList(T).initCapacity(allocator, dts.len);
            errdefer s_dts.deinit();
            var s_pts = try ArrayList(Point).initCapacity(allocator, pts.len);
            errdefer s_pts.deinit();
            var s_gran_us = try ArrayList(usize).initCapacity(allocator, gran_us.len);
            errdefer s_gran_us.deinit();

            try s_dts.appendSlice(dts);
            try s_pts.appendSlice(pts);
            try s_gran_us.appendSlice(gran_us);

            var result = Self{
                .dts = s_dts,
                .pts = s_pts,
                .gran_us = s_gran_us,
                .allocator = allocator,

                .dynamic = undefined,
            };

            try result.recalc();

            return result;
        }

        pub fn drawSpline2Dpts(self: Self, thick: f32, chosen_idx: ?usize) void {
            const logger = std.log.scoped(.drawSpline2Dpts);
            for (self.dynamic.spline.ts, 0..) |t, idx| {
                if (self.dynamic.spline.at(t)) |res| {
                    const xy: rl.Vector2 = .{
                        .x = @floatCast(res.x),
                        .y = @floatCast(-res.y),
                    };
                    const color = if (chosen_idx != null and idx == chosen_idx.?) rl.Color.green else rl.Color.blue;
                    rl.drawCircleV(xy, thick, color);
                    {
                        const text = std.fmt.allocPrintZ(self.allocator, "{}", .{idx});
                        if (text) |val| {
                            defer self.allocator.free(val);
                            rl.drawTextEx(rl.getFontDefault(), val, xy, 1, 1, rl.Color.pink);
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

        pub fn drawSpline2D(self: Self, thick: f32, color: rl.Color, flipY: bool) void {
            const logger = std.log.scoped(.drawSpline2D);
            const ysc: T = if (flipY) -1 else 1;
            var prev: rl.Vector2 = undefined;
            var first = true;
            for (self.gran_us.items, 0..) |gus, i| {
                const t = self.dynamic.spline.ts[i];
                const dt = self.dts.items[i];

                var iterator = uniformSpacingIterator(T).iterate(0, dt, gus);

                while (iterator.next()) |du| {
                    const u = t + du;

                    if (self.dynamic.spline.at(u)) |res| {
                        const xy: rl.Vector2 = .{
                            .x = @floatCast(res.x),
                            .y = @floatCast(ysc * res.y),
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
        }

        pub fn collision_box(self: Self, thick: f32) rl.Rectangle {
            return rl.Rectangle{
                .x = self.dynamic.bbox.x - thick / 2,
                .y = -self.dynamic.bbox.y - self.dynamic.bbox.height - thick / 2,
                .width = self.dynamic.bbox.width + thick,
                .height = self.dynamic.bbox.height + thick,
            };
        }

        pub fn addPoint(self: *Self, i: usize, pt: Point) !void {
            try self.dts.insert(i, 1);
            try self.pts.insert(i, pt);
            try self.gran_us.insert(i, 8);

            try self.recalc();
        }

        pub fn delPoint(self: *Self, i: usize) !void {
            _ = self.dts.orderedRemove(i);
            _ = self.pts.orderedRemove(i);
            _ = self.gran_us.orderedRemove(i);

            try self.recalc();
        }

        pub fn getDt(self: Self, i: usize) T {
            return self.dts.items[i];
        }

        pub fn setDt(self: *Self, i: usize, dt: T) !void {
            if (self.dts.items[i] == dt) {
                return;
            }
            self.dts.items[i] = dt;
            try self.recalc();
        }

        pub fn getPt(self: Self, i: usize) Point {
            return self.pts.items[i];
        }

        pub fn setPt(self: *Self, i: usize, pt: Point) !void {
            if (self.pts.items[i].eq(pt)) {
                return;
            }
            self.pts.items[i] = pt;
            try self.recalc();
        }

        pub fn getGran(self: Self, i: usize) usize {
            return self.gran_us.items[i];
        }

        pub fn setGran(self: *Self, i: usize, gran: usize) !void {
            if (i >= self.gran_us.items.len - 1) {
                return;
            }
            if (self.gran_us.items[i] == gran) {
                return;
            }
            self.gran_us.items[i] = gran;
            try self.recalc();
        }

        pub fn save(self: Self, writer: std.io.AnyWriter) !void {
            try std.json.stringify(self, .{ .whitespace = .indent_tab }, writer);
        }

        pub fn load(allocator: std.mem.Allocator, reader: std.io.AnyReader) !Self {
            const json_reader = std.json.reader(allocator, reader);

            const res = try std.json.parseFromTokenSource(Self, allocator, json_reader, .{});
            // defer res.deinit();

            return res.value;
        }

        pub fn savePwoCompatSplinesSummary(splines: []const Self, writer: std.io.AnyWriter) !void {
            const num_curves = splines.len;
            var num_ts: usize = 0;
            var num_us: usize = 0;
            for (splines) |sp| {
                num_ts += sp.dts.items.len;
                for (sp.gran_us.items) |gus| {
                    num_us += gus;
                }
            }
            try writer.print("{}, {}, {}\n", .{ num_curves, num_ts, num_us });
        }

        pub fn savePwoCompatSplines(splines: []const Self, writer: std.io.AnyWriter) !void {
            var first = true;
            for (splines) |sp| {
                if (!first) {
                    try writer.writeAll("\n");
                } else {
                    first = false;
                }
                try sp.savePwoCompat(writer);
            }
        }

        pub fn savePwoCompat(self: Self, writer: std.io.AnyWriter) !void {
            try self.dynamic.spline.savePwoCompat(writer);
            {
                try writer.writeAll("[");
                var len: usize = 0;
                for (self.gran_us.items) |gus| {
                    len += gus;
                }

                var us = try self.allocator.alloc(T, len);
                defer self.allocator.free(us);

                var j: usize = 0;
                for (self.gran_us.items, 0..) |gus, i| {
                    const t = self.dynamic.spline.ts[i];
                    const dt = self.dts.items[i];

                    var iterator = uniformSpacingIterator(T).iterate(0, dt, gus);

                    while (iterator.next()) |du| {
                        us[j] = t + du;
                        j += 1;
                    }
                }

                var first = true;
                // Normalize to [0;1]
                const min = us[0];
                const max = us[us.len - 1];
                for (us) |u| {
                    if (!first) {
                        try writer.writeAll(",");
                    } else {
                        first = false;
                    }
                    try writer.print("{d}", .{(u - min) / (max - min)});
                }
                try writer.writeAll("]\n");
                // for (self.gran_us.items, 0..) |gus, i| {
                //     const t = self.dynamic.spline.ts[i];
                //     const dt = self.dts.items[i];
                //
                //     var iterator = uniformSpacingIterator(T).iterate(0, dt, gus);
                //
                //     while (iterator.next()) |du| {
                //         if (!first) {
                //             try writer.writeAll(",");
                //         } else {
                //             first = false;
                //         }
                //         try writer.print("{d}", .{t + du});
                //     }
                // }
                // try writer.writeAll("]\n");
            }
        }

        pub fn jsonStringify(self: Self, jw: anytype) !void {
            try jw.beginObject();
            {
                try jw.objectField("dts");
                try jw.write(self.dts.items);
            }
            {
                try jw.objectField("pts");
                try jw.write(self.pts.items);
            }
            {
                try jw.objectField("gran_us");
                try jw.write(self.gran_us.items);
            }
            try jw.endObject();
        }

        pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, opts: std.json.ParseOptions) !Self {
            if (.object_begin != try source.next()) {
                return error.UnexpectedToken;
            }

            //var arena = std.heap.ArenaAllocator.init(allocator);
            // defer arena.deinit();
            const ally = allocator; //arena.allocator();

            var res: struct {
                dts: ?[]const T = null,
                pts: ?[]const Point = null,
                gran_us: ?[]const usize = null,
            } = .{};

            const logger = std.log.scoped(.jsonParse);

            outer: while (true) {
                const token = try source.nextAlloc(ally, opts.allocate.?);
                switch (token) {
                    inline .string, .allocated_string => |k| {
                        inline for (std.meta.fields(@TypeOf(res))) |field| {
                            if (std.mem.eql(u8, k, field.name)) {
                                if (@field(res, field.name) != null) {
                                    switch (opts.duplicate_field_behavior) {
                                        .use_first => {
                                            _ = try std.json.innerParse(field.type, allocator, source, opts);
                                            continue :outer;
                                        },
                                        .@"error" => return error.DuplicateField,
                                        .use_last => {},
                                    }
                                }
                                @field(res, field.name) = try std.json.innerParse(field.type, allocator, source, opts);
                            }
                        }
                    },
                    .object_end => break,
                    else => {
                        logger.err("Unexpected token: {}", .{token});
                        return error.UnexpectedToken;
                    },
                }
            }

            var l: ?usize = null;
            inline for (.{ "dts", "pts", "gran_us" }) |fname| {
                if (@field(res, fname)) |field| {
                    if (field.len < 2) {
                        return error.LengthMismatch;
                    } else {
                        if (l) |v| {
                            if (v != field.len) {
                                return error.LengthMismatch;
                            }
                        } else {
                            l = field.len;
                        }
                    }
                } else {
                    return error.MissingField;
                }
            }

            return init(allocator, res.dts.?, res.pts.?, res.gran_us.?);
        }

        fn recalc(self: *Self) !void {
            var res: Dynamic = undefined;

            res.spline = try Spline2D(T).init_from_dists(self.allocator, self.dts.items, self.pts.items);
            {
                var min = self.pts.items[0];
                var max = self.pts.items[0];

                for (self.gran_us.items, 0..) |gus, i| {
                    const t = res.spline.ts[i];
                    const dt = self.dts.items[i];

                    var iterator = uniformSpacingIterator(T).iterate(0, dt, gus);

                    while (iterator.next()) |du| {
                        const u = t + du;
                        const pt = try res.spline.at(u);
                        if (pt.x < min.x) min.x = pt.x;
                        if (pt.y < min.y) min.y = pt.y;
                        if (pt.x > max.x) max.x = pt.x;
                        if (pt.y > max.y) max.y = pt.y;
                    }
                }

                res.bbox = .{
                    .x = @floatCast(min.x),
                    .y = @floatCast(min.y),
                    .width = @floatCast(max.x - min.x),
                    .height = @floatCast(max.y - min.y),
                };
            }

            self.dynamic.spline.deinit();
            self.dynamic = res;
        }

        pub fn deinit(self: Self) void {
            self.dts.deinit();
            self.pts.deinit();
            self.gran_us.deinit();
            self.spline.deinit();
        }
    };
}

fn Spline2D(Tp: type) type {
    return struct {
        pub const Self = @This();
        pub const T = Tp;

        pub const Point = Point2D(T);
        ts: []const T,
        hs: []const T,
        eq_params: []const EqParams,
        allocator: std.mem.Allocator,

        const EqParams = struct {
            m: Point,
            v: Point,
        };

        pub fn deinit(self: Self) void {
            self.allocator.free(self.ts);
            self.allocator.free(self.hs);
            self.allocator.free(self.eq_params);
        }

        pub fn init_from_dists(allocator: std.mem.Allocator, dists: []const T, pts: []const Point) !Self {
            std.debug.assert(dists.len == pts.len);

            const precomps = try Precomps(T).init_from_dists(allocator, dists);
            defer precomps.deinit();

            return Self{
                .ts = try allocator.dupe(T, precomps.ts),
                .hs = try allocator.dupe(T, dists),
                .eq_params = try calc_params(allocator, precomps, pts),
                .allocator = allocator,
            };
        }

        pub fn at(self: Self, t: T) !Point {
            for (1..self.ts.len) |k| {
                if (t >= self.ts[k - 1] and t <= self.ts[k]) {
                    return self.s(k, t);
                }
            }

            return error.ArgumentOutOfRange;
        }

        fn s(self: Self, k: usize, t: T) Point {
            var pt: Point = undefined;

            inline for (std.meta.fields(Point)) |f| {
                const d = f.name;

                const hk = self.hs[k - 1];
                const mk = @field(self.eq_params[k].m, d);
                const mk_1 = @field(self.eq_params[k - 1].m, d);
                const tk = self.ts[k];
                const tk_1 = self.ts[k - 1];
                const vk = @field(self.eq_params[k].v, d);
                const vk_1 = @field(self.eq_params[k - 1].v, d);
                const p1 = mk_1 * std.math.pow(T, tk - t, 3) / 6;
                const p2 = mk * std.math.pow(T, t - tk_1, 3) / 6;
                const p3 = (tk - t) * (vk_1 - mk_1 * (std.math.pow(f64, hk, 2) / 6));
                const p4 = (t - tk_1) * (vk - mk * std.math.pow(f64, hk, 2) / 6);
                @field(pt, d) = (p1 + p2 + p3 + p4) / hk;
            }

            return pt;
        }

        pub fn savePwoCompat(self: Self, writer: std.io.AnyWriter) !void {
            {
                try writer.writeAll("[");
                var first = true;
                // Normalize to [0;1]
                const min = self.ts[0];
                const max = self.ts[self.ts.len - 1];
                for (self.ts) |t| {
                    if (!first) {
                        try writer.writeAll(",");
                    } else {
                        first = false;
                    }
                    try writer.print("{d}", .{(t - min) / (max - min)});
                }
                try writer.writeAll("]\n");
            }
            inline for (.{ "x", "y" }) |dim| {
                try writer.writeAll("[");
                var first = true;
                for (self.eq_params) |ep| {
                    if (!first) {
                        try writer.writeAll(",");
                    } else {
                        first = false;
                    }
                    try writer.print("{d}", .{@field(ep.v, dim)});
                }
                try writer.writeAll("]\n");
            }
        }

        fn calc_params(allocator: std.mem.Allocator, precomps: Precomps(T), pts: []const Point) ![]const EqParams {
            std.debug.assert(precomps.ts.len == pts.len);

            var res = try allocator.alloc(EqParams, pts.len);
            for (0..pts.len) |i| {
                res[i].v = pts[i];
            }

            var us = try allocator.alloc(Point, pts.len - 2);
            defer allocator.free(us);
            var ds = try allocator.alloc(Point, pts.len - 2);
            defer allocator.free(ds);
            var prev_us: Point = .{ .x = 0, .y = 0 };
            for (0..ds.len) |k| {
                const ts3 = precomps.ts[k .. k + 3];
                inline for (.{ "x", "y" }) |field| {
                    const vs3 = &[_]T{
                        @field(pts[k], field),
                        @field(pts[k + 1], field),
                        @field(pts[k + 2], field),
                    };
                    @field(ds[k], field) = 6 * try divdiffs(ts3, vs3);
                    @field(us[k], field) = (@field(ds[k], field) - precomps.ls[k] * @field(prev_us, field)) / precomps.ps[k];
                }
                prev_us = us[k];
            }

            inline for (.{ "x", "y" }) |field| {
                @field(res[0].m, field) = 0;
                @field(res[res.len - 1].m, field) = 0;
            }
            for (2..res.len) |i| {
                const k = res.len - i;
                inline for (.{ "x", "y" }) |field| {
                    @field(res[k].m, field) = @field(us[k - 1], field) + precomps.qs[k - 1] * @field(res[k + 1].m, field);
                }
            }

            return res;
        }
    };
}

fn divdiffs(x: []const f64, y: []const f64) !f64 {
    if (x.len != y.len) {
        return error.NonEqualArgumentsLengths;
    }

    return switch (x.len) {
        1 => error.ArgumentOutOfRange,
        2 => (y[1] - y[0]) / (x[1] - x[0]),
        else => (try divdiffs(x[1..x.len], y[1..y.len]) - try divdiffs(x[0 .. x.len - 1], y[0 .. y.len - 1])) / (x[x.len - 1] - x[0]),
    };
}

pub fn Precomps(Tp: type) type {
    return struct {
        const Self = @This();
        const T = Tp;

        ts: []const T,
        hs: []const T,
        ls: []const T,
        ps: []const T,
        qs: []const T,
        allocator: std.mem.Allocator,

        pub fn init_from_dists(allocator: std.mem.Allocator, dts: []const T) !Self {
            std.debug.assert(dts.len >= 2);

            var ts = try allocator.alloc(T, dts.len);

            var dt: T = dts[0];
            for (0..ts.len) |i| {
                ts[i] = dt;
                dt += dts[i];
            }

            var hs: []T = try allocator.alloc(T, ts.len -| 1);
            var ls: []T = try allocator.alloc(T, ts.len -| 2);
            var ps: []T = try allocator.alloc(T, ts.len -| 2);
            var qs: []T = try allocator.alloc(T, ts.len -| 2);

            for (0..hs.len) |i| {
                hs[i] = ts[i + 1] - ts[i];
            }

            if (ts.len > 2) {
                ls[0] = hs[0] / (hs[0] + hs[1]);
                ps[0] = 2;
                qs[0] = (ls[0] - 1) / ps[0];
                for (1..ls.len) |i| {
                    ls[i] = hs[i] / (hs[i] + hs[i + 1]);
                    ps[i] = ls[i] * qs[i - 1] + 2;
                    qs[i] = (ls[i] - 1) / ps[i];
                }
            }

            return Self{
                .ts = ts,
                .hs = hs,
                .ls = ls,
                .ps = ps,
                .qs = qs,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.ts);
            self.allocator.free(self.hs);
            self.allocator.free(self.ls);
            self.allocator.free(self.ps);
            self.allocator.free(self.qs);
        }
    };
}
