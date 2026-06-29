pub const transformer = @import("transformer.zig");
pub const chain = @import("chain.zig");
pub const inliners = @import("inliners.zig");
pub const jsxtransforms = @import("jsxtransforms.zig");
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
    pub const classfields = @import("estransforms/classfields.zig");
    pub const esdecorator = @import("estransforms/esdecorator.zig");
    pub const taggedtemplate = @import("estransforms/taggedtemplate.zig");
    pub const objectrestspread = @import("estransforms/objectrestspread.zig");
    pub const async_transform = @import("estransforms/async.zig");
};
test "compile all" {
    _ = @import("tstransforms/metadata.zig");
    _ = @import("tstransforms/runtimesyntax.zig");
    _ = @import("tstransforms/legacydecorators.zig");
    _ = @import("tstransforms/typeserializer.zig");
}
