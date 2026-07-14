const std = @import("std");
const collections = @import("../collections/pkg.zig");
const core = @import("../core/pkg.zig");
const module = @import("../module/pkg.zig");
const symlinks = @import("../symlinks/pkg.zig");
const tspath = @import("../tspath/pkg.zig");
const vfs = @import("../vfs/pkg.zig");
const cachedvfs = @import("../vfs/cachedvfs/pkg.zig");

const CompilerHost = @import("program.zig").CompilerHost;
const FileLoader = @import("filesparser.zig").FileLoader;
const ProjectReferenceFileMapper = @import("projectreferencefilemapper.zig").ProjectReferenceFileMapper;

pub const ProjectReferenceDtsFakingHost = struct {
    host: CompilerHost,
    fs: *cachedvfs.FS,
};

pub fn newProjectReferenceDtsFakingHost(loader: *FileLoader) module.ResolutionHost {
    _ = loader;
    return undefined;
}

pub const ProjectReferenceDtsFakingVfs = struct {
    projectReferenceFileMapper: *ProjectReferenceFileMapper,
    dtsDirectories: collections.Set(tspath.Path),
    knownSymlinks: symlinks.KnownSymlinks,
};
