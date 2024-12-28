pub fn isNumber(T: type) bool {
    return switch (@typeInfo(T)) {
        .Float => true,
    };
}

pub fn returnIf(T: type, cond: bool) type {
    if (!cond) @compileError("Type assertion failure");
    return T;
}

pub fn returnIfF(T: type, cond: fn (type) bool) !type {
    return returnIf(T, cond(T));
}
