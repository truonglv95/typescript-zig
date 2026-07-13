# LSP types code generator

This directory contains the generator scripts that produce
`src/lsp/lsproto/lsp_generated.zig` (the canonical LSP protocol type
declarations consumed by the Zig build).

## Files

| File | Purpose |
|---|---|
| `generate.mts` | TypeScript-based generator (canonical). Writes directly to `../lsp_generated.zig`. Run with `node --experimental-strip-types generate.mts`. |
| `generate.py` | Older Python prototype; kept for reference. Prints to stdout. |
| `fetchModel.mts` | Fetches the upstream LSP `metaModel.json` from microsoft/language-server-protocol. |
| `metaModelSchema.mts` | TypeScript types describing the metaModel schema. |
| `patchedMetaModel.json` | Cached meta-model with local patches (e.g., filtering notebook-only types). |
| `tsconfig.json` | TypeScript config for the generator. |

## Workflow

```sh
cd src/lsp/lsproto/_generate
node --experimental-strip-types fetchModel.mts   # refresh metaModel.json
node --experimental-strip-types generate.mts     # regenerate ../lsp_generated.zig
```

## Notes

- The generator output (`lsp_generated.zig`) lives **outside** this directory,
  at `src/lsp/lsproto/lsp_generated.zig`. The previous duplicate at
  `_generate/lsp_generated.zig` was removed to prevent drift.
- The Zig code does not import anything from `_generate/`; this directory is
  tooling-only and is safe to exclude from release tarballs.
