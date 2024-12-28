const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const Vector = @import("vector.zig");
const Spline = @import("spline.zig");
const Spline2D = Spline.SplineSoA(.{ .T = f64, .dim = 2 });

const palette = @import("colorscheme.zig").palette;

pub fn main2() void {
    const V2 = Vector.Vector(.{ .T = f64, .dim = 2 });
    const arr = [2]f64{ 1, 1 };
    const foo: V2 = V2.fromArray(arr);
    std.debug.print("{}\n", .{foo});
    std.debug.print("{}\n", .{@Vector(2, f64){ 1, 1 }});
    std.debug.print("{any}\n", .{&arr});
    std.debug.print("{any}\n", .{&foo.val});
}

const State = struct {
    camera: rl.Camera2D,
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    // const pts = &[_]Spline2D.Point{
    //     .{ 0, 0 },
    //     .{ 10, 10 },
    //     .{ 20, 0 },
    //     .{ 30, 10 },
    //     .{ 40, 0 },
    // };
    //
    // const dists = &[_]Spline2D.T{
    //     1,
    //     10,
    //     10,
    //     1,
    // };
    //
    // // const sp = try Spline2D.init_from_dists(allocator, dists, pts);
    // // defer sp.deinit();
    //
    // std.debug.print("{}\n", .{@TypeOf(sp)});
    // std.debug.print("{}\n", .{Spline2D});

    // var mx: usize = 2;

    const sw = 640;
    const sh = 480;

    rl.setConfigFlags(.{
        .msaa_4x_hint = true,
        // .vsync_hint = true,
    });
    rl.initWindow(sw, sh, "Konkurs1");
    defer rl.closeWindow();

    var pwo = rl.loadImage("pwo++-cropped.png");
    pwo = pwo;
    defer rl.unloadImage(pwo);

    // std.debug.print("{}x{}\n", .{ pwo.width, pwo.height });
    // rl.imageResize(&pwo, @divTrunc(pwo.width, 2), @divTrunc(pwo.height, 2));
    // std.debug.print("{}x{}\n", .{ pwo.width, pwo.height });
    const pwo_tex = rl.loadTextureFromImage(pwo);
    defer rl.unloadTexture(pwo_tex);

    var state: State = .{ .camera = .{
        .zoom = 1,
        .offset = .{
            .x = @floatFromInt(@divTrunc(sw, 2)),
            .y = @floatFromInt(@divTrunc(sh, 2)),
        },
        .target = .{
            .x = 0,
            .y = 0,
        },
        .rotation = 0,
    } };

    const sp = try loadSave(allocator);
    defer sp.deinit();

    while (!rl.windowShouldClose()) {
        try handleInput(&state);

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.white);

        {
            rl.beginMode2D(state.camera);
            defer rl.endMode2D();

            try drawSpline2D(sp, &[_]Spline2D.T{ 0, 0.5, 1 }, 1, 1);

            rl.drawTexture(pwo_tex, 0, -pwo_tex.height, rl.Color.white);
        }
        {
            const mousexy = rl.getMousePosition();
            const xy = rl.getScreenToWorld2D(mousexy, state.camera);
            const text = try std.fmt.allocPrintZ(allocator, "{d:.2},{d:.2}", .{ xy.x, -xy.y });
            defer allocator.free(text);

            // _ = rg.guiLabel(.{ .x = mousexy.x, .y = mousexy.y - 10, .width = 100, .height = 100 }, text);
            rl.drawText(text, 0, sh - 10, 0, rl.Color.black);
        }
        rl.drawFPS(0, 0);
    }
}

pub fn loadSave(allocator: std.mem.Allocator) !Spline2D {
    const file = try std.fs.cwd().openFile("save.json", .{});
    defer file.close();

    const reader = file.reader();
    var json_reader = std.json.reader(allocator, reader);
    return std.json.parseFromTokenSourceLeaky(Spline2D, allocator, &json_reader, .{});
    // var scanner = std.json.Scanner.initCompleteInput(allocator,
    //     \\ {
    //     \\ "ts": [
    //     \\ 	0e0,
    //     \\ 	1e0,
    //     \\ 	1.1e1,
    //     \\ 	2.1e1,
    //     \\ 	2.2e1
    //     \\ ],
    //     \\ "vs": [
    //     \\ 	[
    //     \\ 		0e0,
    //     \\ 		0e0
    //     \\ 	],
    //     \\ 	[
    //     \\ 		1e1,
    //     \\ 		1e1
    //     \\ 	],
    //     \\ 	[
    //     \\ 		2e1,
    //     \\ 		0e0
    //     \\ 	],
    //     \\ 	[
    //     \\ 		3e1,
    //     \\ 		1e1
    //     \\ 	],
    //     \\ 	[
    //     \\ 		4e1,
    //     \\ 		0e0
    //     \\ 	]
    //     \\ ]
    //     \\ }
    // );
    // defer scanner.deinit();
    //
    // // const sp = try Spline2D.jsonLoad(allocator, &scanner, .{});
    // const sp = try std.json.parseFromSliceLeaky(Spline2D, allocator,
    //     \\ {
    //     \\ "ts": [
    //     \\ 	0e0,
    //     \\ 	1e0,
    //     \\ 	1.1e1,
    //     \\ 	2.1e1,
    //     \\ 	2.2e1
    //     \\ ],
    //     \\ "vs": [
    //     \\ 	[
    //     \\ 		0e0,
    //     \\ 		0e0
    //     \\ 	],
    //     \\ 	[
    //     \\ 		1e1,
    //     \\ 		1e1
    //     \\ 	],
    //     \\ 	[
    //     \\ 		2e1,
    //     \\ 		0e0
    //     \\ 	],
    //     \\ 	[
    //     \\ 		3e1,
    //     \\ 		1e1
    //     \\ 	],
    //     \\ 	[
    //     \\ 		4e1,
    //     \\ 		0e0
    //     \\ 	]
    //     \\ ]
    //     \\ }
    // , .{});
    // defer sp.deinit();
}

fn handleInput(state: *State) !void {
    if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
        const mousexy = rl.getMousePosition();
        const xy = rl.getScreenToWorld2D(mousexy, state.camera);
        try std.io.getStdOut().writer().print("[{},{}]\n", .{ xy.x, xy.y });
    }

    const wheel = rl.getMouseWheelMove();
    if (wheel != 0) {
        const scaleFactor =
            if (wheel > 0)
            1.0 + (0.25 * @abs(wheel))
        else
            1.0 / (1.0 + (0.25 * @abs(wheel)));

        state.camera.target = rl.getScreenToWorld2D(rl.getMousePosition(), state.camera);
        state.camera.offset = rl.getMousePosition();

        state.camera.zoom = state.camera.zoom * scaleFactor;
        if (state.camera.zoom < std.math.floatTrueMin(f32)) {
            state.camera.zoom = std.math.floatTrueMin(f32);
        }
    }

    if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_middle) or rl.isKeyDown(rl.KeyboardKey.key_space)) {
        const delta = rl.getMouseDelta().scale(-1.0 / state.camera.zoom);
        state.camera.target = state.camera.target.add(delta);
    }

    if (rl.isKeyDown(rl.KeyboardKey.key_c)) {
        state.camera.target = .{ .x = 0, .y = 0 };
    } else if (rl.isKeyDown(rl.KeyboardKey.key_r)) {
        state.camera.zoom = 1;
    }

    if (rl.isKeyDown(rl.KeyboardKey.key_right)) {
        state.camera.target.x += 10.0 / state.camera.zoom;
    } else if (rl.isKeyDown(rl.KeyboardKey.key_left)) {
        state.camera.target.x -= 10.0 / state.camera.zoom;
    } else if (rl.isKeyDown(rl.KeyboardKey.key_up)) {
        state.camera.target.y -= 10.0 / state.camera.zoom;
    } else if (rl.isKeyDown(rl.KeyboardKey.key_down)) {
        state.camera.target.y += 10.0 / state.camera.zoom;
    }
    // if (rl.isKeyPressed(rl.KeyboardKey.key_equal)) {
    //     if (rl.isKeyDown(rl.KeyboardKey.key_left_shift)) {
    //         mx *= 2;
    //     } else if (rl.isKeyDown(rl.KeyboardKey.key_left_control)) {
    //         mx += mx / 10;
    //     } else {
    //         mx += 1;
    //     }
    // } else if (rl.isKeyPressed(rl.KeyboardKey.key_minus)) {
    //     if (mx > 2) {
    //         if (rl.isKeyDown(rl.KeyboardKey.key_left_shift)) {
    //             mx /= 2;
    //         } else if (rl.isKeyDown(rl.KeyboardKey.key_left_control)) {
    //             mx -|= mx / 10;
    //         } else {
    //             mx -= 1;
    //         }
    //     }
    //     if (mx < 2) {
    //         mx = 2;
    //     }
    // }
}

fn drawSpline2Dpts(s: Spline2D, ts: []const f64, thick: f32, scale: f64) !void {
    for (ts) |t| {
        const res = try s.at(t);
        const xy: rl.Vector2 = .{
            .x = @floatCast(res[0] * scale),
            .y = @floatCast(-res[1] * scale),
        };
        rl.DrawCircleV(xy, thick, rl.Color.blue);
    }
}

fn drawSpline2D(s: Spline2D, ts: []const f64, thick: f32, scale: f64) !void {
    var prev: rl.Vector2 = undefined;
    var first = true;
    for (ts) |t| {
        const res = try s.at(t);
        const xy: rl.Vector2 = .{
            .x = @floatCast(res[0] * scale),
            .y = @floatCast(-res[1] * scale),
        };

        if (!first) {
            rl.drawLineEx(prev, xy, thick, rl.Color.green);
        } else {
            first = false;
        }
        prev = xy;
    }
}

var exp = false;

fn mkImageSz(s: Spline2D, numt: usize, thick: usize, scale: f64, w: c_int, h: c_int) !rl.Image {
    std.debug.assert(numt >= 2);
    std.debug.assert(scale > 0);
    var img = rl.genImageColor(w, h, rl.Color.blank);

    const res0 = try s.at(0);
    var prev: rl.Vector2 = .{
        .x = @floatCast(res0[0] * scale),
        .y = @floatCast(res0[1] * scale),
    };

    for (1..numt) |i| {
        const t: f64 = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(numt));
        const res = try s.at(t);
        const cur: rl.Vector2 = .{
            .x = @floatCast(res[0] * scale),
            .y = @floatCast(res[1] * scale),
        };
        rl.ImageDrawLineEx(&img, prev, cur, @intCast(thick), rl.Color.black);
        prev = cur;
    }
    rl.ImageFlipVertical(&img);

    return img;
}

fn mkImage(allocator: std.mem.Allocator, s: Spline2D, numt: usize, thick: usize, scale: f64) !rl.Image {
    std.debug.assert(numt >= 2);
    std.debug.assert(scale > 0);
    var pts = try allocator.alloc(rl.Vector2, numt);
    defer allocator.free(pts);

    var min_x: f32 = 0;
    var min_y: f32 = 0;
    var max_x = -std.math.inf(f32);
    var max_y = -std.math.inf(f32);

    for (0..numt) |i| {
        const t: f64 = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(numt));
        const res = try s.at(t);
        pts[i] = .{
            .x = @floatCast(res.x * scale),
            .y = @floatCast(-res.y * scale),
        };
        if (pts[i].x < min_x) {
            min_x = pts[i].x;
        }
        if (pts[i].x > max_x) {
            max_x = pts[i].x;
        }
        if (pts[i].y < min_y) {
            min_y = pts[i].y;
        }
        if (pts[i].y > max_y) {
            max_y = pts[i].y;
        }
    }

    var img = rl.GenImageColor(@intFromFloat(@ceil(@abs(max_x - min_x))), @intFromFloat(@ceil(@abs(max_y - min_y))), rl.BLANK);

    for (1..pts.len) |i| {
        const prev: rl.Vector2 = .{
            .x = pts[i - 1].x - min_x,
            .y = pts[i - 1].y - min_y,
        };
        const cur: rl.Vector2 = .{
            .x = pts[i].x - min_x,
            .y = pts[i].y - min_y,
        };
        rl.ImageDrawLineEx(&img, prev, cur, @intCast(thick), rl.BLACK);
    }

    return img;
}

const Diff = struct {
    diff: f64,
    sided_diff: f64,
    total_lit_a: f64,
    diffpx: usize,
    sided_diffpx: usize,
    diff_img: rl.Image,
};

fn imgDiff(a: rl.Image, b: rl.Image) Diff {
    std.debug.assert(a.width == b.width);
    std.debug.assert(a.height == b.height);

    const w: usize = @intCast(a.width);
    const h: usize = @intCast(a.height);

    var diff_image = rl.GenImageColor(@intCast(w), @intCast(h), rl.BLANK);
    var sd_image = rl.GenImageColor(@intCast(w), @intCast(h), rl.BLANK);

    var diff: f64 = 0.0;
    var sided_diff: f64 = 0.0;
    var sided_diffpx: usize = 0;
    var diffpx: usize = 0;
    var total_lit_a: f64 = 0.0;

    const none = rl.BLANK;
    _ = none;
    for (0..w) |x| {
        for (0..h) |y| {
            const ac = rl.GetImageColor(a, @intCast(x), @intCast(y));
            const bc = rl.GetImageColor(b, @intCast(x), @intCast(y));
            const d_r = @as(f64, @floatFromInt(ac.r)) / 255 - @as(f64, @floatFromInt(bc.r)) / 255;
            const d_g = @as(f64, @floatFromInt(ac.g)) / 255 - @as(f64, @floatFromInt(bc.g)) / 255;
            const d_b = @as(f64, @floatFromInt(ac.b)) / 255 - @as(f64, @floatFromInt(bc.b)) / 255;
            const d_a = @as(f64, @floatFromInt(ac.a)) / 255 - @as(f64, @floatFromInt(bc.a)) / 255;
            const d = std.math.sqrt(d_r * d_r + d_g * d_g + d_b * d_b + d_a * d_a);
            if (ac.r + ac.b + ac.g + ac.a != 0) {
                var s: f64 = 0;
                // s += @as(f64, @floatFromInt(ac.r)) / 255.0;
                // s += @as(f64, @floatFromInt(ac.g)) / 255.0;
                // s += @as(f64, @floatFromInt(ac.b)) / 255.0;
                s += @as(f64, @floatFromInt(ac.a)) / 255.0;
                total_lit_a += s;
            }
            const sd = d_r + d_g + d_b + d_a;
            if (sd > 0) {
                sided_diffpx += 1;
                sided_diff += d;
                rl.ImageDrawPixel(&sd_image, @intCast(x), @intCast(y), rl.Color{
                    .r = @intFromFloat(255 * d / 2),
                    .g = @intFromFloat(255 * d / 2),
                    .b = @intFromFloat(255 * d / 2),
                    .a = 255,
                });
            }
            if (d > 0.0) {
                diffpx += 1;
            }
            diff += d;
            rl.ImageDrawPixel(&diff_image, @intCast(x), @intCast(y), rl.Color{
                .r = @intFromFloat(255 * d / 2),
                .g = @intFromFloat(255 * d / 2),
                .b = @intFromFloat(255 * d / 2),
                .a = if (d > 0.0) 255 else 0,
            });
        }
    }
    return .{
        .diff = diff,
        .total_lit_a = total_lit_a,
        .sided_diff = sided_diff,
        .sided_diffpx = sided_diffpx,
        .diffpx = diffpx,
        .diff_img = diff_image,
    };
}

pub fn remap(value: anytype, inputStart: @TypeOf(value), inputEnd: @TypeOf(value), outputStart: @TypeOf(value), outputEnd: @TypeOf(value)) @TypeOf(value) {
    return (value - inputStart) / (inputEnd - inputStart) * (outputEnd - outputStart) + outputStart;
}

// for (0..sp.ts.len) |i| {
//     const t = sp.ts[i];
//     const pt = try sp.at(t);
//     const pV: rl.Vector2 = .{
//         .x = @floatCast(pt[0]),
//         .y = @floatCast(pt[1]),
//     };
//     const mV: rl.Vector2 = .{
//         .x = @floatCast(sp.eq_params[i].m[0]),
//         .y = @floatCast(sp.eq_params[i].m[1]),
//     };
//     const nV = if (mV.equals(rl.Vector2.zero()) == 1) mV else pV.add(mV).normalize();
//     if (!printed) {
//         std.debug.print("{}:\n\tmV: {}\n\tnV: {}\n\teq: {}\n", .{ i, mV, nV, mV.equals(rl.Vector2.zero()) });
//     }
//
//     rl.drawCircleV(pV, 0.6 / camera.zoom, palette.fg_colors[2]);
//     rl.drawLineEx(pV, pV.add(nV), 0.1, palette.fg_colors[3]);
// }
// {
//     const min_ts = sp.ts[0];
//     const max_ts = sp.ts[sp.ts.len - 1];
//     var prev_pt = try sp.at(min_ts);
//     for (1..mx) |i| {
//         const i_f: f64 = @floatFromInt(i);
//         const t_ = i_f / @as(f64, @floatFromInt(mx - 1));
//         const t = remap(t_, 0.0, 1.0, min_ts, max_ts);
//
//         const pt = try sp.at(t);
//
//         const prlV: rl.Vector2 = .{
//             .x = @floatCast(prev_pt[0]),
//             .y = @floatCast(prev_pt[1]),
//         };
//         const rlV: rl.Vector2 = .{
//             .x = @floatCast(pt[0]),
//             .y = @floatCast(pt[1]),
//         };
//         rl.drawLineV(prlV, rlV, rl.Color.white);
//
//         prev_pt = pt;
//     }
// }
// {
//     const min_ts = sp.ts[0];
//     const max_ts = sp.ts[sp.ts.len - 1];
//     var prev_pt = try sp.at(min_ts);
//     for (1..mx) |i| {
//         const i_f: f64 = @floatFromInt(i);
//         const t_ = i_f / @as(f64, @floatFromInt(mx - 1));
//         const t = remap(t_, 0.0, 1.0, min_ts, max_ts);
//
//         const pt = try sp.at(t);
//
//         const prlV: rl.Vector2 = .{
//             .x = @floatCast(prev_pt[0]),
//             .y = @floatCast(prev_pt[1]),
//         };
//         const rlV: rl.Vector2 = .{
//             .x = @floatCast(pt[0]),
//             .y = @floatCast(pt[1]),
//         };
//
//         const dV = rlV.subtract(prlV).normalize();
//
//         // rl.drawCircleV(prlV, if (camera.zoom == 1) 5.0 else 5.0 / camera.zoom, palette.fg_colors[0]);
//         rl.drawLineV(prlV, prlV.add(dV), palette.fg_colors[1]);
//
//         prev_pt = pt;
//     }
// }
