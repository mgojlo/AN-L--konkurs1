pub fn Vector(comptime options: struct { T: type, dim: usize }) type {
    return struct {
        val: [dim]T,

        const dim = options.dim;
        const T = options.T;
        const Self = @This();

        pub fn fromArray(arr: [dim]T) Self {
            return Self{
                .val = arr,
            };
        }
    };
}
