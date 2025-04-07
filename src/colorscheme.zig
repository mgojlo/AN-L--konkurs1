// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// This Source Code Form is "Incompatible With Secondary Licenses", as
// defined by the Mozilla Public License, v. 2.0.

const rl = @import("raylib");

fn colorFromInt(color: u24) rl.Color {
    return rl.Color{
        .r = @shrExact(color & 0xFF0000, 16),
        .g = @shrExact(color & 0xFF00, 8),
        .b = color & 0xFF,
        .a = 0xFF,
    };
}

const base = blueforest;

pub const palette = struct {
    pub const colors = base;
    pub const bg_colors = base[0..8];
    pub const fg_colors = base[8..16];
};

// Color palettes from base 16
// MIT License
//
// Copyright (c) 2024 Tinted Theming
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

const aztec = &[_]rl.Color{
    colorFromInt(0x101600),
    colorFromInt(0x1A1E01),
    colorFromInt(0x242604),
    colorFromInt(0x2E2E05),
    colorFromInt(0xFFD129),
    colorFromInt(0xFFDA51),
    colorFromInt(0xFFE178),
    colorFromInt(0xFFEBA0),
    colorFromInt(0xEE2E00),
    colorFromInt(0xEE8800),
    colorFromInt(0xEEBB00),
    colorFromInt(0x63D932),
    colorFromInt(0x3D94A5),
    colorFromInt(0x5B4A9F),
    colorFromInt(0x883E9F),
    colorFromInt(0xA928B9),
};

const blueforest = &[_]rl.Color{
    colorFromInt(0x141F2E),
    colorFromInt(0x1E5C1E),
    colorFromInt(0x273E5C),
    colorFromInt(0xA0FFA0),
    colorFromInt(0x1E5C1E),
    colorFromInt(0xFFCC33),
    colorFromInt(0x91CCFF),
    colorFromInt(0x375780),
    colorFromInt(0xFFFAB1),
    colorFromInt(0xFF8080),
    colorFromInt(0x91CCFF),
    colorFromInt(0x80FF80),
    colorFromInt(0x80FF80),
    colorFromInt(0xA2CFF5),
    colorFromInt(0x0099FF),
    colorFromInt(0xE7E7E7),
};

const simple = &[_]rl.Color{
    colorFromInt(0x111111),
    colorFromInt(0x333333),
    colorFromInt(0x555555),
    colorFromInt(0x777777),
    colorFromInt(0x999999),
    colorFromInt(0xBBBBBB),
    colorFromInt(0xDDDDDD),
    colorFromInt(0xFFFFFF),
    rl.Color.red,
    rl.Color.orange,
    rl.Color.yellow,
    rl.Color.green,
    rl.Color.blue,
    rl.Color.dark_blue,
    rl.Color.purple,
    rl.Color.dark_purple,
};
