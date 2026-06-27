pub const transformer = @import("transformer.zig");
pub const chain = @import("chain.zig");
pub const tstransforms = struct {
    pub const typeeraser = @import("tstransforms/typeeraser.zig");
    pub const importelision = @import("tstransforms/importelision.zig");
    pub const legacydecorators = @import("tstransforms/legacydecorators.zig");
    pub const runtimesyntax = @import("tstransforms/runtimesyntax.zig");
    pub const metadata = @import("tstransforms/metadata.zig");
    pub const typeserializer = @import("tstransforms/typeserializer.zig");
    pub const utilities = @import("tstransforms/utilities.zig");
};
pub const moduletransforms = struct {
    pub const esmodule = @import("moduletransforms/esmodule.zig");
};
pub const estransforms = struct {
    pub const using = @import("estransforms/using.zig");
};
test "compile all" {
    _ = @import("tstransforms/metadata.zig");
    _ = @import("tstransforms/runtimesyntax.zig");
    _ = @import("tstransforms/legacydecorators.zig");
    _ = @import("tstransforms/typeserializer.zig");
}
