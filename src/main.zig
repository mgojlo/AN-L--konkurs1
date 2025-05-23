// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// This Source Code Form is "Incompatible With Secondary Licenses", as
// defined by the Mozilla Public License, v. 2.0.

const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const Spline = @import("spline.zig").SplineUI(f64);

const palette = @import("colorscheme.zig").palette;

const fnames = .{
    .export_image = "konkurs-I-indeks.jpg",
    .export_data = "konkurs-I-indeks-dane.txt",
    .export_summary = "konkurs-I-indeks-podsumowanie.txt",
};

pub fn main() !void {
    var gpa = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const sw = 1280;
    const sh = 720;

    rl.setConfigFlags(.{
        .msaa_4x_hint = true,
        .vsync_hint = true,
    });
    rl.setTraceLogLevel(.warning);
    rl.initWindow(sw, sh, "Konkurs1");
    defer rl.closeWindow();

    var pwo = try rl.loadImage("pwo++.png");
    pwo = pwo;
    defer rl.unloadImage(pwo);

    const pwo_tex = try rl.loadTextureFromImage(pwo);
    defer rl.unloadTexture(pwo_tex);

    var state: State = try State.new(allocator);
    state.camera.offset = .{
        .x = @floatFromInt(@divTrunc(sw, 2)),
        .y = @floatFromInt(@divTrunc(sh, 2)),
    };
    state.camera.target = .{
        .x = @floatFromInt(@divTrunc(pwo_tex.width, 2)),
        .y = @floatFromInt(@divTrunc(-pwo_tex.height, 2)),
    };
    const save_splines = loadSave(allocator);
    if (save_splines) |val| {
        state.ui_splines.arr = val;
    } else |err| {
        std.log.scoped(.main).warn("Failed loading save: {}", .{err});
    }

    rg.guiSetStyle(.default, rg.GuiDefaultProperty.text_size, 20);
    rl.setExitKey(rl.KeyboardKey.q);

    while (!rl.windowShouldClose()) {
        try handleInput(&state);

        if (rl.isKeyPressed(rl.KeyboardKey.e)) {
            try exportImage(state.ui_splines.arr, @intCast(pwo_tex.width), @intCast(pwo_tex.height), state.thick, fnames.export_image);
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.yellow);

        {
            rl.beginMode2D(state.camera);
            defer rl.endMode2D();

            rl.drawTexture(pwo_tex, 0, -pwo_tex.height, rl.Color.white);

            const screenRect = res: {
                const tl = rl.getScreenToWorld2D(.{ .x = 0, .y = 0 }, state.camera);
                const br = rl.getScreenToWorld2D(.{ .x = sw, .y = sh }, state.camera);
                break :res rl.Rectangle{ .x = tl.x, .y = tl.y, .width = br.x - tl.x, .height = br.y - tl.y };
            };

            for (state.ui_splines.arr, 0..) |*sp, i| {
                // Avoid drawing off-screen splines
                if (!rl.checkCollisionRecs(screenRect, sp.collision_box(state.thick))) {
                    continue;
                }
                const color = res: {
                    if (state.dragged != null and state.dragged.?.spline == sp) {
                        break :res rl.Color.red.fade(0.5);
                    } else if (state.chosen != null and state.chosen.?.spline == sp) {
                        break :res rl.Color.orange.fade(0.5);
                    } else {
                        break :res palette.fg_colors[@mod(i, palette.fg_colors.len)];
                    }
                };
                sp.drawSpline2D(state.thick, color, true);
                sp.drawSpline2D(1, rl.Color.black, true);
                if (state.chosen) |chosen| {
                    if (chosen.spline == sp) {
                        try sp.drawSpline2Dpts(1, chosen.idx);
                    } else {
                        try sp.drawSpline2Dpts(1, null);
                    }
                } else {
                    try sp.drawSpline2Dpts(1, null);
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
                    _ = rg.guiSlider(.{ .x = 0, .y = sh - 40, .width = 120, .height = 20 }, "", "dt", &val, min, max);
                    try chosen.spline.setDt(chosen.idx, @max(min, @as(f64, @floatCast(std.math.pow(Spline.T, 2, val)))));
                }
                {
                    var val: i32 = @intCast(chosen.spline.getGran(chosen.idx));
                    _ = rg.guiSpinner(.{ .x = 0, .y = sh - 60, .width = 120, .height = 20 }, "gran", &val, 1, 64, true);
                    try chosen.spline.setGran(chosen.idx, @max(1, @as(usize, @intCast(val))));
                }
            }
        }

        rl.drawFPS(0, 0);
    }

    state.ui_splines.allocator.deinit();
}

fn exportImage(splines: []const Spline, width: usize, height: usize, thick: f32, name: [:0]const u8) !void {
    const rtex = try rl.loadRenderTexture(@intCast(width), @intCast(height));
    defer rl.unloadRenderTexture(rtex);

    {
        rtex.begin();
        defer rtex.end();

        rl.clearBackground(rl.Color.white);

        for (splines) |*sp| {
            sp.drawSpline2D(thick, rl.Color.red, false);
        }
    }

    std.log.scoped(.exportImage).info("Exporting image to {s}. Image size: {}x{}", .{ name, rtex.texture.width, rtex.texture.height });

    var img = try rl.loadImageFromTexture(rtex.texture);
    defer rl.unloadImage(img);

    if (!img.exportToFile(name)) {
        std.log.scoped(.exportImage).warn("Failed to export image to {s}", .{name});
    }
}

fn loadSave(allocator: std.mem.Allocator) ![]Spline {
    var f = try std.fs.cwd().openFile("save.json", .{});
    defer f.close();

    var json_reader = std.json.reader(allocator, f.reader().any());

    const res = try std.json.parseFromTokenSource([]Spline, allocator, &json_reader, .{});

    return res.value;
}

fn saveSave(sps: []const Spline) !void {
    var f = try std.fs.cwd().createFile("save.json", .{});
    defer f.close();

    try std.json.stringify(sps, .{ .whitespace = .indent_2 }, f.writer().any());
}

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

    pub fn new(allocator: std.mem.Allocator) !@This() {
        var spline_allocator = std.heap.ArenaAllocator.init(allocator);
        return .{
            .camera = .{
                .zoom = 1,
                .rotation = 0,
                .offset = .{
                    .x = 0,
                    .y = 0,
                },
                .target = .{
                    .x = 0,
                    .y = 0,
                },
            },
            .ui_splines = .{
                .arr = try spline_allocator.allocator().alloc(Spline, 0),
                .allocator = spline_allocator,
                .parent_allocator = allocator,
            },

            .thick = 5.0,
        };
    }

    pub fn addSpline(self: *@This(), p1: Spline.Point, p2: Spline.Point) !void {
        self.ui_splines.arr = try self.ui_splines.allocator.allocator().realloc(self.ui_splines.arr, self.ui_splines.arr.len + 1);
        self.ui_splines.arr[self.ui_splines.arr.len - 1] = try Spline.init(self.ui_splines.allocator.allocator(), &[_]f64{
            1,
            1,
        }, &[_]Spline.Point{
            p1, p2,
        }, &[_]usize{
            1,
            1,
        });
    }
};

fn handleInput(state: *State) !void {
    const mouse = rl.getScreenToWorld2D(rl.getMousePosition(), state.camera);
    for (state.ui_splines.arr) |*sp| {
        if (rl.checkCollisionPointRec(mouse, sp.collision_box(state.thick))) {
            for (sp.pts.items, 0..) |pt, idx| {
                if (rl.checkCollisionPointCircle(mouse, pt.toRlVector2().multiply(.{ .x = 1, .y = -1 }), @sqrt(8.0 / state.camera.zoom))) {
                    if (state.dragged == null) {
                        if (rl.isMouseButtonDown(rl.MouseButton.left)) {
                            state.dragged = .{ .spline = sp, .idx = idx };
                        } else if (rl.isMouseButtonPressed(rl.MouseButton.right)) {
                            state.chosen = .{ .spline = sp, .idx = idx };
                        }
                    }
                    break;
                }
            }
        }
    }

    if (state.dragged) |dragged| {
        if (rl.isKeyDown(rl.KeyboardKey.m)) {
            var dd = rl.getMouseDelta();
            dd.y = -dd.y;
            try dragged.spline.translate(Spline.Point.fromRlVector2(dd));
        } else {
            try dragged.spline.setPt(dragged.idx, Spline.Point.fromRlVector2(mouse.multiply(.{ .x = 1, .y = -1 })));
        }
        if (rl.isMouseButtonReleased(rl.MouseButton.left)) {
            state.chosen = state.dragged;
            state.dragged = null;
        }
    }

    switch (rl.getKeyPressed()) {
        .l => {
            std.log.info("Reloading save", .{});
            state.dragged = null;
            state.chosen = null;

            var arena = std.heap.ArenaAllocator.init(state.ui_splines.parent_allocator);
            const new_sp = loadSave(arena.allocator());

            if (new_sp) |val| {
                state.chosen = null;
                state.dragged = null;
                state.ui_splines.allocator.deinit();
                _ = state.ui_splines.allocator.reset(.free_all);
                state.ui_splines = .{
                    .arr = val,
                    .allocator = arena,
                    .parent_allocator = state.ui_splines.parent_allocator,
                };
            } else |err| {
                std.log.scoped(.handleInput).warn("Failed loading save: {}", .{err});
            }
        },
        .s => try saveSave(state.ui_splines.arr),
        .e => {
            {
                var f = try std.fs.cwd().createFile(fnames.export_data, .{});
                defer f.close();

                try Spline.savePwoCompatSplines(state.ui_splines.arr, f.writer().any());
            }
            {
                var f = try std.fs.cwd().createFile(fnames.export_summary, .{});
                defer f.close();

                try Spline.savePwoCompatSplinesSummary(state.ui_splines.arr, f.writer().any());
            }
        },
        .n => {
            const mouse_wiggle = rl.getScreenToWorld2D(rl.getMousePosition().add(.{ .x = 1, .y = 1 }), state.camera);
            try state.addSpline(Spline.Point.fromRlVector2(mouse.multiply(.{ .x = 1, .y = -1 })), Spline.Point.fromRlVector2(mouse_wiggle.multiply(.{ .x = 1, .y = -1 })));
        },
        .right => state.camera.target.x += 10.0 / state.camera.zoom,
        .left => state.camera.target.x -= 10.0 / state.camera.zoom,
        .up => state.camera.target.y -= 10.0 / state.camera.zoom,
        .down => state.camera.target.y += 10.0 / state.camera.zoom,
        .equal => {
            state.thick += 0.1;
        },
        .minus => {
            state.thick -= 0.1;
            if (state.thick <= 0) {
                state.thick = 0.1;
            }
        },
        .escape => {
            state.chosen = null;
            state.dragged = null;
        },
        .r => if (state.chosen) |chosen| {
            try chosen.spline.setDt(chosen.idx, 1);
        },
        .a => if (state.chosen) |chosen| {
            try chosen.spline.addPoint(chosen.idx, Spline.Point.fromRlVector2(mouse.multiply(.{ .x = 1, .y = -1 })));
        },
        .d => if (state.chosen) |chosen| {
            try chosen.spline.delPoint(chosen.idx);
            state.chosen = null;
        },
        // .t => if (state.chosen) |chosen| {
        //     const dir: Spline.T = if (rl.isKeyDown(rl.KeyboardKey.left_shift)) 0.5 else 2;
        //     const new_dt = @max(std.math.floatTrueMin(Spline.T), chosen.spline.getDt(chosen.idx) * dir);
        //     try chosen.spline.setDt(chosen.idx, new_dt);
        //     std.debug.print("new dt: {}\n", .{chosen.spline.getDt(chosen.idx)});
        // },
        .g => if (state.chosen) |chosen| {
            const cur = chosen.spline.getGran(chosen.idx);
            const amt = if (rl.isKeyDown(rl.KeyboardKey.left_control)) @divTrunc(cur, 2) else 1;
            if (rl.isKeyDown(rl.KeyboardKey.left_shift)) {
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

    if (rl.isMouseButtonDown(rl.MouseButton.middle) or rl.isKeyDown(rl.KeyboardKey.space)) {
        const delta = rl.getMouseDelta().scale(-1.0 / state.camera.zoom);
        state.camera.target = state.camera.target.add(delta);
    }
}
