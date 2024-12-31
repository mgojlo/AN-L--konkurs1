const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const Vector = @import("vector.zig");
const Spline = @import("spline_new.zig").SplineUI(f64);
// const Spline = @import("spline.zig");
// const SplineRL = @import("spline_rl.zig").SplineRL(f64);
// const Spline2D = SplineRL.Spline;
// const Spline2D = Spline.SplineSoA(.{ .T = f64, .dim = 2 });

const palette = @import("colorscheme.zig").palette;

const State = struct {
    const SelectedPt = ?struct {
        spline: *Spline,
        idx: usize,
    };
    camera: rl.Camera2D,
    ui_splines: struct {
        arr: []Spline,
        allocator: std.heap.ArenaAllocator,
        parent_allocator: std.mem.Allocator,
    },
    dragged: SelectedPt = null,
    chosen: SelectedPt = null,
    thick: f32,
};

// pub fn main() !void {
//     var gpa = std.heap.ArenaAllocator.init(std.heap.c_allocator);
//     defer _ = gpa.deinit();
//
//     const allocator = gpa.allocator();
//
//     const sp = try Spline.init(allocator, &[_]f64{ 0, 1, 1, 1, 1 }, &[_]Spline.Point{
//         .{ .x = 0, .y = 0 },
//         .{ .x = 1, .y = 1 },
//         .{ .x = 0, .y = 0 },
//         .{ .x = 1, .y = 1 },
//         .{ .x = 0, .y = 0 },
//     }, &[_]usize{ 1, 1, 1, 1, 1 });
//
//     try saveSave(&[_]Spline{sp});
// }

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var gpa = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const sw = 1280;
    const sh = 720;

    rl.setConfigFlags(.{
        .msaa_4x_hint = true,
        .vsync_hint = true,
    });
    rl.setTraceLogLevel(.log_warning);
    rl.initWindow(sw, sh, "Konkurs1");
    defer rl.closeWindow();

    var pwo = rl.loadImage("pwo++-cropped.png");
    pwo = pwo;
    defer rl.unloadImage(pwo);

    const pwo_tex = rl.loadTextureFromImage(pwo);
    defer rl.unloadTexture(pwo_tex);

    var state: State = .{
        .camera = .{
            .zoom = 1,
            .offset = .{
                .x = @floatFromInt(@divTrunc(sw, 2)),
                .y = @floatFromInt(@divTrunc(sh, 2)),
            },
            .target = .{
                .x = @floatFromInt(@divTrunc(pwo_tex.width, 2)),
                .y = @floatFromInt(@divTrunc(-pwo_tex.height, 2)),
            },
            .rotation = 0,
        },
        .ui_splines = .{
            .arr = try loadSave(allocator),
            .allocator = std.heap.ArenaAllocator.init(allocator),
            .parent_allocator = allocator,
        },

        .thick = 5.0,
    };

    rg.guiSetStyle(.default, @intFromEnum(rg.GuiDefaultProperty.text_size), 20);
    rl.setExitKey(rl.KeyboardKey.key_q);

    while (!rl.windowShouldClose()) {
        try handleInput(&state);

        if (rl.isKeyPressed(rl.KeyboardKey.key_e)) {
            try exportImage(state.ui_splines.arr, @intCast(pwo_tex.width), @intCast(pwo_tex.height), state.thick, "export.png");
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.yellow);

        {
            rl.beginMode2D(state.camera);
            defer rl.endMode2D();

            rl.drawTexture(pwo_tex, 0, -pwo_tex.height, rl.Color.white);

            for (state.ui_splines.arr, 0..) |*sp, i| {
                const color = res: {
                    if (state.dragged != null and state.dragged.?.spline == sp) {
                        break :res rl.Color.red.fade(0.5);
                    } else if (state.chosen != null and state.chosen.?.spline == sp) {
                        break :res rl.Color.blue.fade(0.5);
                    } else {
                        break :res palette.fg_colors[@mod(i, palette.fg_colors.len)];
                    }
                };
                sp.drawSpline2D(state.thick, color, true);
                if (state.chosen) |chosen| {
                    if (chosen.spline == sp) {
                        sp.drawSpline2Dpts(1, chosen.idx);
                    } else {
                        sp.drawSpline2Dpts(1, null);
                    }
                } else {
                    sp.drawSpline2Dpts(1, null);
                }
                rl.drawRectangleRec(sp.collision_box(state.thick), rl.Color.black.fade(0.2));
            }
        }
        {
            const mousexy = rl.getScreenToWorld2D(rl.getMousePosition(), state.camera);
            const idx = if (state.chosen) |chosen| chosen.idx else 0;
            const dt = if (state.chosen) |chosen| chosen.spline.getDt(chosen.idx) else std.math.nan(Spline.T);
            const gran = if (state.chosen) |chosen| chosen.spline.getGran(chosen.idx) else 0;
            const foo = 8.0 / state.camera.zoom;
            const text = try std.fmt.allocPrintZ(allocator, "Zoom: {d:.4} | THICK: {d:.2} | M: ({d:.2},{d:.2}) | Point: {} Dt: {} Gran: {} | Foo: {d:.2}", .{ state.camera.zoom, state.thick, mousexy.x, mousexy.y, idx, dt, gran, foo });
            defer allocator.free(text);
            _ = rg.guiStatusBar(.{ .x = 0, .y = sh - 20, .width = sw, .height = 20 }, text);

            if (state.chosen) |chosen| {
                {
                    var val: f32 = @floatCast(std.math.log2(chosen.spline.getDt(chosen.idx)));
                    const min: f32 = std.math.log2(1.0 / 512.0);
                    const max: f32 = std.math.log2(8);
                    _ = rg.guiSlider(.{ .x = 0, .y = 0, .width = 120, .height = 20 }, "", "dt", &val, min, max);
                    try chosen.spline.setDt(chosen.idx, @max(min, @as(f64, @floatCast(std.math.pow(Spline.T, 2, val)))));
                }
                {
                    var val: i32 = @intCast(chosen.spline.getGran(chosen.idx));
                    _ = rg.guiSpinner(.{ .x = 0, .y = 20, .width = 120, .height = 20 }, "gran", &val, 1, 64, true);
                    try chosen.spline.setGran(chosen.idx, @max(1, @as(usize, @intCast(val))));
                }
            }
        }

        // rl.drawFPS(0, 0);
    }

    try Spline.savePwoCompatSplines(state.ui_splines.arr, (try std.fs.cwd().createFile("export.txt", .{})).writer().any());

    state.ui_splines.allocator.deinit();
}

fn exportImage(splines: []const Spline, width: usize, height: usize, thick: f32, name: [:0]const u8) !void {
    const rtex = rl.loadRenderTexture(@intCast(width), @intCast(height));
    defer rl.unloadRenderTexture(rtex);

    {
        rtex.begin();
        defer rtex.end();

        for (splines) |*sp| {
            sp.drawSpline2D(thick, rl.Color.red, false);
        }
    }

    std.debug.print("{},{}\n", .{ rtex.texture.width, rtex.texture.height });

    var img = rl.loadImageFromTexture(rtex.texture);
    defer rl.unloadImage(img);

    _ = img.exportToFile(name.ptr);
}

fn loadSave(allocator: std.mem.Allocator) ![]Spline {
    var f = try std.fs.cwd().openFile("save.json", .{});
    defer f.close();

    var json_reader = std.json.reader(allocator, f.reader().any());

    const res = try std.json.parseFromTokenSource([]Spline, allocator, &json_reader, .{});
    // defer res.deinit();

    return res.value;
}

fn saveSave(sps: []const Spline) !void {
    var f = try std.fs.cwd().createFile("save.json", .{});
    defer f.close();

    try std.json.stringify(sps, .{ .whitespace = .indent_2 }, f.writer().any());
}

fn handleInput(state: *State) !void {
    // if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
    //     const mousexy = rl.getMousePosition();
    //     const xy = rl.getScreenToWorld2D(mousexy, state.camera);
    //     try std.io.getStdOut().writer().print("[{},{}]\n", .{ xy.x, -xy.y });
    // }

    const mouse = rl.getScreenToWorld2D(rl.getMousePosition(), state.camera);
    for (state.ui_splines.arr) |*sp| {
        if (rl.checkCollisionPointRec(mouse, sp.collision_box(state.thick))) {
            for (sp.pts.items, 0..) |pt, idx| {
                if (rl.checkCollisionPointCircle(mouse, pt.toRlVector2().multiply(.{ .x = 1, .y = -1 }), @sqrt(8.0 / state.camera.zoom))) {
                    if (state.dragged == null) {
                        if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
                            state.dragged = .{ .spline = sp, .idx = idx };
                        } else if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_right)) {
                            state.chosen = .{ .spline = sp, .idx = idx };
                        }
                    }
                    break;
                }
            }
        }
    }

    if (state.dragged) |dragged| {
        try dragged.spline.setPt(dragged.idx, Spline.Point.fromRlVector2(mouse.multiply(.{ .x = 1, .y = -1 })));
        if (rl.isMouseButtonReleased(rl.MouseButton.mouse_button_left)) {
            state.chosen = state.dragged;
            state.dragged = null;
        }
    }
    // const mouse = rl.getScreenToWorld2D(rl.getMousePosition(), state.camera);
    // for (state.sp.spline.eq_params, 0..) |ep, idx| {
    //     if (rl.checkCollisionPointCircle(mouse, .{ .x = @floatCast(ep.v[0]), .y = @floatCast(-ep.v[1]) }, 8.0)) {
    //         if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
    //             state.dragged_idx = idx;
    //         }
    //
    //         break;
    //     }
    // }
    //
    // if (state.dragged_idx) |idx| {
    //     state.sp.spline.eq_params[idx].v[0] = mouse.x;
    //     state.sp.spline.eq_params[idx].v[1] = -mouse.y;
    //     if (rl.isMouseButtonReleased(rl.MouseButton.mouse_button_left)) {
    //         state.dragged_idx = null;
    //     }
    // }

    switch (rl.getKeyPressed()) {
        .key_l => {
            std.log.info("Reloading save", .{});
            state.dragged = null;
            state.chosen = null;

            var arena = std.heap.ArenaAllocator.init(state.ui_splines.parent_allocator);
            const new_sp = loadSave(arena.allocator());

            if (new_sp) |val| {
                std.log.scoped(.handleInput).warn("A", .{});
                state.chosen = null;
                state.dragged = null;
                state.ui_splines.allocator.deinit();
                std.log.scoped(.handleInput).warn("B", .{});
                _ = state.ui_splines.allocator.reset(.free_all);
                std.log.scoped(.handleInput).warn("C", .{});
                state.ui_splines = .{
                    .arr = val,
                    .allocator = arena,
                    .parent_allocator = state.ui_splines.parent_allocator,
                };
            } else |err| {
                std.log.scoped(.handleInput).warn("Failed loading save: {}", .{err});
            }
        },
        .key_s => try saveSave(state.ui_splines.arr),
        .key_e => {
            var f = try std.fs.cwd().createFile("export.txt", .{});
            defer f.close();

            try Spline.savePwoCompatSplines(state.ui_splines.arr, f.writer().any());
        },
        .key_right => state.camera.target.x += 10.0 / state.camera.zoom,
        .key_left => state.camera.target.x -= 10.0 / state.camera.zoom,
        .key_up => state.camera.target.y -= 10.0 / state.camera.zoom,
        .key_down => state.camera.target.y += 10.0 / state.camera.zoom,
        .key_equal => {
            state.thick += 0.1;
        },
        .key_minus => {
            state.thick -= 0.1;
            if (state.thick <= 0) {
                state.thick = 0.1;
            }
        },
        .key_escape => {
            state.chosen = null;
            state.dragged = null;
        },
        .key_r => if (state.chosen) |chosen| {
            try chosen.spline.setDt(chosen.idx, 1);
        },
        .key_a => if (state.chosen) |chosen| {
            try chosen.spline.addPoint(chosen.idx, Spline.Point.fromRlVector2(mouse.multiply(.{ .x = 1, .y = -1 })));
        },
        .key_d => if (state.chosen) |chosen| {
            try chosen.spline.delPoint(chosen.idx);
            state.chosen = null;
        },
        // .key_t => if (state.chosen) |chosen| {
        //     const dir: Spline.T = if (rl.isKeyDown(rl.KeyboardKey.key_left_shift)) 0.5 else 2;
        //     const new_dt = @max(std.math.floatTrueMin(Spline.T), chosen.spline.getDt(chosen.idx) * dir);
        //     try chosen.spline.setDt(chosen.idx, new_dt);
        //     std.debug.print("new dt: {}\n", .{chosen.spline.getDt(chosen.idx)});
        // },
        .key_g => if (state.chosen) |chosen| {
            const cur = chosen.spline.getGran(chosen.idx);
            const amt = if (rl.isKeyDown(rl.KeyboardKey.key_left_control)) @divTrunc(cur, 2) else 1;
            if (rl.isKeyDown(rl.KeyboardKey.key_left_shift)) {
                try chosen.spline.setGran(chosen.idx, cur -| amt);
            } else {
                try chosen.spline.setGran(chosen.idx, cur +| amt);
            }
            std.debug.print("new gran: {}\n", .{chosen.spline.getGran(chosen.idx)});
        },
        else => {},
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
}
