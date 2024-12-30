const std = @import("std");
const metaExts = @import("meta_exts.zig");

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

fn DTTFnT(T: type) type {
    return (fn (std.mem.Allocator, []const T) (std.mem.Allocator.Error![]T));
}

pub fn distsToTs(T: type) DTTFnT(T) {
    const Transient = struct {
        fn f(allocator: std.mem.Allocator, dists: []const T) ![]T {
            var ts = try allocator.alloc(T, dists.len + 1);
            var dt: T = 0;
            for (0..ts.len) |i| {
                ts[i] = dt;
                if (i < dists.len) {
                    dt += dists[i];
                }
            }
            return ts;
        }
    };
    return Transient.f;
}

pub fn Precomps(options: struct { T: type = f64 }) type {
    return struct {
        ts: []const T,
        hs: []const T,
        ls: []const T,
        ps: []const T,
        qs: []const T,
        allocator: std.mem.Allocator,

        const Self = @This();
        const T = options.T;

        pub fn init(allocator: std.mem.Allocator, ts: []const T) !Self {
            const ts_copy: []T = try allocator.dupe(T, ts);
            var hs: []T = try allocator.alloc(T, ts.len - 1);
            var ls: []T = try allocator.alloc(T, ts.len - 2);
            var ps: []T = try allocator.alloc(T, ts.len - 2);
            var qs: []T = try allocator.alloc(T, ts.len - 2);

            for (0..hs.len) |i| {
                hs[i] = ts[i + 1] - ts[i];
            }

            ls[0] = hs[0] / (hs[0] + hs[1]);
            ps[0] = 2;
            qs[0] = (ls[0] - 1) / ps[0];
            for (1..ls.len) |i| {
                ls[i] = hs[i] / (hs[i] + hs[i + 1]);
                ps[i] = ls[i] * qs[i - 1] + 2;
                qs[i] = (ls[i] - 1) / ps[i];
            }

            return Self{
                .ts = ts_copy,
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

pub fn SplineSoA(comptime options: struct { T: type = f64, dim: usize = 1 }) type {
    if (@typeInfo(options.T) != .Float) {
        @compileError("SplineSoA is well-defined only for floats");
    }

    return struct {
        ts: []const T,
        hs: []const T,
        eq_params: []EqParams,
        allocator: std.mem.Allocator,

        pub const Self = @This();
        pub const T = options.T;
        pub const dim = options.dim;
        pub const Point = [dim]T;

        const EqParams = struct {
            m: [dim]T,
            v: [dim]T,
        };

        pub fn deinit(self: Self) void {
            self.allocator.free(self.ts);
            self.allocator.free(self.hs);
            self.allocator.free(self.eq_params);
        }

        fn calc_params(allocator: std.mem.Allocator, precomps: Precomps(.{ .T = T }), vss: []const [dim]T) ![]EqParams {
            if (vss.len != precomps.ts.len) {
                return error.NonEqualArgumentsLengths;
            }

            var res = try allocator.alloc(EqParams, vss.len);
            for (0..vss.len) |i| {
                for (0..dim) |d| {
                    res[i].v[d] = vss[i][d];
                }
            }

            var us = try allocator.alloc(T, vss.len - 2);
            defer allocator.free(us);
            var ds = try allocator.alloc(T, vss.len - 2);
            defer allocator.free(ds);
            for (0..dim) |d| {
                var prev_us = @as(T, 0);
                for (0..ds.len) |k| {
                    const vs3 = &[_]T{
                        vss[k][d],
                        vss[k + 1][d],
                        vss[k + 2][d],
                    };
                    ds[k] = 6 * try divdiffs(precomps.ts[k .. k + 3], vs3);
                    us[k] = (ds[k] - precomps.ls[k] * prev_us) / precomps.ps[k];
                    prev_us = us[k];
                }

                res[0].m[d] = 0;
                res[res.len - 1].m[d] = 0;
                for (2..res.len) |i| {
                    const k = res.len - i;
                    res[k].m[d] = us[k - 1] + precomps.qs[k - 1] * res[k + 1].m[d];
                }
            }
            return res;
        }

        pub fn init_from_precomps(allocator: std.mem.Allocator, precomps: Precomps(.{ .T = T }), vss: []const [dim]T) !Self {
            const eq_params = try calc_params(allocator, precomps, vss);

            return Self{
                .ts = try allocator.dupe(T, precomps.ts),
                .hs = try allocator.dupe(T, precomps.hs),
                .eq_params = eq_params,
                .allocator = allocator,
            };
        }

        pub fn init_from_points(allocator: std.mem.Allocator, ts: []const T, pts: []const Point) !Self {
            std.debug.assert(ts.len == pts.len);
            var vss = try allocator.alloc([dim]T, pts.len);
            defer allocator.free(vss);

            for (0..pts.len) |i| {
                inline for (0..dim) |d| {
                    vss[i][d] = pts[i][d];
                }
            }

            const precomps = try Precomps(.{ .T = T }).init(allocator, ts);
            defer precomps.deinit();

            return init_from_precomps(allocator, precomps, vss);
        }

        pub fn init_from_dists(allocator: std.mem.Allocator, dists: []const T, pts: []const Point) !Self {
            std.debug.assert(dists.len == pts.len);
            var ts = try allocator.alloc(T, dists.len);
            defer allocator.free(ts);

            var dt: T = dists[0];
            for (0..ts.len) |i| {
                dt += dists[i];
                ts[i] = dt;
            }

            return init_from_points(allocator, ts, pts);
        }

        fn s(self: Self, k: usize, t: T) Point {
            var pt: Point = undefined;

            for (0..dim) |d| {
                const hk = self.hs[k - 1];
                const mk = self.eq_params[k].m[d];
                const mk_1 = self.eq_params[k - 1].m[d];
                const tk = self.ts[k];
                const tk_1 = self.ts[k - 1];
                const vk = self.eq_params[k].v[d];
                const vk_1 = self.eq_params[k - 1].v[d];
                const p1 = mk_1 * std.math.pow(T, tk - t, 3) / 6;
                const p2 = mk * std.math.pow(T, t - tk_1, 3) / 6;
                const p3 = (tk - t) * (vk_1 - mk_1 * (std.math.pow(f64, hk, 2) / 6));
                const p4 = (t - tk_1) * (vk - mk * std.math.pow(f64, hk, 2) / 6);
                pt[d] = (p1 + p2 + p3 + p4) / hk;
            }

            return pt;
        }

        pub fn init_from_points_uniform(allocator: std.mem.Allocator, pts: []const Point) !Self {
            // _ = switch (@typeInfo(T)) {
            //     .Float => undefined,
            //     else => @compileError("Spline.init_from_points_uniform is well-defined only for floating point types"),
            // };

            var ts = try allocator.alloc(T, pts.len);
            defer allocator.free(ts);

            for (0..ts.len) |i| {
                const t = @as(T, @floatFromInt(i)) / @as(T, @floatFromInt(ts.len - 1));
                ts[i] = t;
            }

            return init_from_points(allocator, ts, pts);
        }

        pub fn at(self: Self, t: T) !Point {
            for (1..self.ts.len) |k| {
                if (t >= self.ts[k - 1] and t <= self.ts[k]) {
                    return self.s(k, t);
                }
            }

            return error.ArgumentOutOfRange;
        }

        pub fn jsonStringify(self: Self, jw: anytype) !void {
            try jw.beginObject();
            {
                try jw.objectField("dts");
                try jw.beginArray();
                var prev_t: T = 0;
                for (self.ts) |t| {
                    try jw.write(t - prev_t);
                    prev_t = t;
                }
                try jw.endArray();
            }

            {
                try jw.objectField("vs");
                try jw.beginArray();
                for (0..self.eq_params.len) |i| {
                    try jw.write(self.eq_params[i].v);
                }
                try jw.endArray();
            }

            try jw.endObject();
        }

        pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, opts: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!Self {
            if (.object_begin != try source.next()) {
                return error.UnexpectedToken;
            }

            var res: struct {
                dts: ?[]const T = null,
                vs: ?[]const [dim]T = null,
            } = .{};
            while (true) {
                const token = try source.nextAlloc(allocator, opts.allocate.?);
                switch (token) {
                    inline .string, .allocated_string => |k| {
                        if (std.mem.eql(u8, k, "dts")) {
                            if (res.dts != null) {
                                switch (opts.duplicate_field_behavior) {
                                    .use_first => {
                                        _ = try std.json.innerParse([]const T, allocator, source, opts);
                                        continue;
                                    },
                                    .@"error" => return error.DuplicateField,
                                    .use_last => {},
                                }
                            }
                            res.dts = try std.json.innerParse([]const T, allocator, source, opts);
                        } else if (std.mem.eql(u8, k, "vs")) {
                            if (res.vs != null) {
                                switch (opts.duplicate_field_behavior) {
                                    .use_first => {
                                        _ = try std.json.innerParse([]const [dim]T, allocator, source, opts);
                                        continue;
                                    },
                                    .@"error" => return error.DuplicateField,
                                    .use_last => {},
                                }
                            }
                            res.vs = try std.json.innerParse([]const [dim]T, allocator, source, opts);
                        }
                    },
                    .object_end => break,
                    else => unreachable,
                }
            }

            if (res.dts == null or res.vs == null) {
                return error.MissingField;
            }

            const sp = init_from_dists(allocator, res.dts.?, res.vs.?);

            return if (sp) |val|
                val
            else |err| switch (err) {
                error.NonEqualArgumentsLengths, error.ArgumentOutOfRange => error.LengthMismatch,
                error.OutOfMemory => error.OutOfMemory,
            };
        }

        // pub fn jsonParse(allocator: std.mem.Allocator, scanner_or_reader: anytype, opts: std.json.ParseOptions) std.json.ParseError(@TypeOf(scanner_or_reader.*))!Self {
        //     var arena = std.heap.ArenaAllocator.init(allocator);
        //     defer arena.deinit();
        //
        //     const res = try std.json.parseFromTokenSource(SpJs, arena.allocator(), scanner_or_reader, opts);
        //
        //     const sp = init_from_points(allocator, res.value.ts, res.value.vs);
        //
        //     return if (sp) |val|
        //         val
        //     else |err| switch (err) {
        //         error.NonEqualArgumentsLengths => error.LengthMismatch,
        //         error.ArgumentOutOfRange => error.LengthMismatch,
        //         error.OutOfMemory => error.OutOfMemory,
        //     };
        // }

        // pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: std.json.Value, opts: std.json.ParseOptions) !Self {
        //     var arena = std.heap.ArenaAllocator.init(allocator);
        //     defer arena.deinit();
        //
        //     const res = try std.json.parseFromValue(SpJs, allocator, source, opts);
        //
        //     const sp = init_from_points(allocator, res.value.ts, res.value.vs);
        //
        //     return if (sp) |val|
        //         val
        //     else |err| switch (err) {
        //         error.NonEqualArgumentsLengths => error.LengthMismatch,
        //         error.ArgumentOutOfRange => error.LengthMismatch,
        //         else => @errorCast(sp),
        //     };
        // }
    };
}
