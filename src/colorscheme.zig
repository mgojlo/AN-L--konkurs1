const rl = @import("raylib");

fn colorFromInt(color: u24) rl.Color {
    return rl.Color{
        .r = @shrExact(color & 0xFF0000, 16),
        .g = @shrExact(color & 0xFF00, 8),
        .b = color & 0xFF,
        .a = 0xFF,
    };
}

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

const base = blueforest;

pub const palette = struct {
    pub const colors = base;
    pub const bg_colors = base[0..8];
    pub const fg_colors = base[8..16];
};
