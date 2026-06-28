// ---------------------------------------------------------------------------
// ctm_import.inc
// Generic CharPad CTM (binary export) -> Kick Assembler converter
// For use in IOTA build system
//
// You MUST export from CharPad as a BINARY CTM (not the project format).
// Then adjust the layout constants below to match your CTM export.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// HOW TO USE
// ---------------------------------------------------------------------------
// Include the converter
// #import "CTM_import.inc"

// Load CTM (binary export from CharPad)
// .var level1 = CtmLoad("assets/levels/level1.ctm")

// Emit data
/* CtmEmitAll(level1,
    $2000,   // charset
    $2800,   // tiles
    $3000,   // map
    $3800)   // attributes (if enabled)
*/

// ---------------------------------------------------------------------------
// CONFIGURATION SECTION
// ---------------------------------------------------------------------------

// Size of the CTM header in bytes (depends on CharPad version/settings).
// 64 is a common value, but adjust to your actual export.
.var CTM_HEADER_SIZE      = 64

// Charset: usually 256 chars x 8 bytes = 2048 bytes
.var CTM_CHARSET_OFFSET   = CTM_HEADER_SIZE
.var CTM_CHARSET_SIZE     = 2048

// Tile data:
// You MUST set these according to your CharPad project.
// Example: 2x2 tiles -> 4 chars per tile.
.var CTM_TILE_COUNT_OFFSET = CTM_CHARSET_OFFSET + CTM_CHARSET_SIZE
.var CTM_TILE_COUNT_BYTES  = 1                    // 1 or 2
.var CTM_CHARS_PER_TILE    = 4

// Map data:
// Set these to your map dimensions in tiles.
// If CTM_MAP_SIZE is 0, the importer will attempt to infer the
// map size from the remaining binary length when possible.
.var CTM_MAP_WIDTH_TILES   = 40
.var CTM_MAP_HEIGHT_TILES  = 25
.var CTM_MAP_SIZE          = CTM_MAP_WIDTH_TILES * CTM_MAP_HEIGHT_TILES

// Attribute data (optional): usually one attribute byte per tile.
.var CTM_ATTRIBUTE_SIZE    = CTM_MAP_SIZE

// If enabled, the importer will derive map/attribute size from the file
// when the binary is shorter than the configured values.
.var CTM_ENABLE_DERIVE_MAP_SIZE = true

// If your CTM export includes per-tile attributes, enable and size them here.
.var CTM_HAS_ATTRIBUTES    = true

// ---------------------------------------------------------------------------
// INTERNAL HELPER FUNCTIONS
// ---------------------------------------------------------------------------

// Returns a hashtable with:
//  "raw"       -> full binary
//  "charset"   -> charset bytes
//  "tiles"     -> tile index data
//  "map"       -> map tile indices
//  "attrib"    -> attribute bytes (if present)
//
.function CtmLoad(fileName) {
    .var bin = LoadBinary(fileName)
    .var rawSize = bin.size()
    .var h   = Hashtable()

    .assert "CTM tile count width must be 1 or 2 bytes", CTM_TILE_COUNT_BYTES == 1 || CTM_TILE_COUNT_BYTES == 2, true
    .assert "CTM binary too small for header, charset and tile count field", rawSize >= CTM_HEADER_SIZE + CTM_CHARSET_SIZE + CTM_TILE_COUNT_BYTES, true

    // Store raw
    .eval h.put("raw", bin)
    .eval h.put("rawSize", rawSize)

    // Charset
    .assert "CTM binary too small for charset data", rawSize >= CTM_CHARSET_OFFSET + CTM_CHARSET_SIZE, true
    .var charset = bin.slice(CTM_CHARSET_OFFSET, CTM_CHARSET_SIZE)
    .eval h.put("charset", charset)

    // Tile count
    .var tileCount = 0
    .if (CTM_TILE_COUNT_BYTES == 1) {
        .eval tileCount = bin.get(CTM_TILE_COUNT_OFFSET)
    } else {
        .eval tileCount = bin.get(CTM_TILE_COUNT_OFFSET) + (bin.get(CTM_TILE_COUNT_OFFSET + 1) * 256)
    }
    .eval h.put("tileCount", tileCount)

    // Tile data
    .var tileDataStart = CTM_TILE_COUNT_OFFSET + CTM_TILE_COUNT_BYTES
    .var tileDataSize  = tileCount * CTM_CHARS_PER_TILE
    .assert "CTM binary too small for tile data", rawSize >= tileDataStart + tileDataSize, true
    .var tiles         = bin.slice(tileDataStart, tileDataSize)
    .eval h.put("tiles", tiles)

    // Map and attribute data
    .var mapStart = tileDataStart + tileDataSize
    .var configuredMapSize = CTM_MAP_SIZE
    .var configuredAttribSize = 0
    .if (CTM_HAS_ATTRIBUTES) {
        .eval configuredAttribSize = CTM_ATTRIBUTE_SIZE
    }

    .var mapSize = configuredMapSize
    .var attribSize = configuredAttribSize

    .if (CTM_ENABLE_DERIVE_MAP_SIZE) {
        .if (configuredMapSize == 0) {
            .if (CTM_HAS_ATTRIBUTES) {
                .assert "CTM_ATTRIBUTE_SIZE must be set when CTM_MAP_SIZE is zero and attributes are enabled", CTM_ATTRIBUTE_SIZE > 0, true
                .eval mapSize = rawSize - mapStart - CTM_ATTRIBUTE_SIZE
                .assert "CTM binary too small for inferred map+attribute data", mapSize >= 0, true
            } else {
                .eval mapSize = rawSize - mapStart
            }
        } else {
            .if (rawSize < mapStart + configuredMapSize) {
                .eval mapSize = rawSize - mapStart
                .eval attribSize = 0
            } else {
                .if (CTM_HAS_ATTRIBUTES && rawSize < mapStart + configuredMapSize + configuredAttribSize) {
                    .eval mapSize = configuredMapSize
                    .eval attribSize = rawSize - (mapStart + configuredMapSize)
                }
            }
        }
    } else {
        .assert "CTM binary too small for configured map and attribute data", rawSize >= mapStart + configuredMapSize + configuredAttribSize, true
    }

    .assert "Inferred map size is invalid", mapSize >= 0, true
    .assert "Inferred attribute size is invalid", attribSize >= 0, true

    .var map = bin.slice(mapStart, mapSize)
    .eval h.put("map", map)
    .eval h.put("mapSize", mapSize)

    .if (CTM_HAS_ATTRIBUTES) {
        .if (attribSize > 0) {
            .var attribStart = mapStart + mapSize
            .var attrib = bin.slice(attribStart, attribSize)
            .eval h.put("attrib", attrib)
            .eval h.put("attribSize", attribSize)
        } else {
            .eval h.put("attribSize", 0)
        }
    }

    .return h
}

// ---------------------------------------------------------------------------
// EMIT MACROS
// ---------------------------------------------------------------------------

// Emit charset at a given address
.macro CtmEmitCharset(ctm, addr) {
    * = addr
    .var cs = ctm.get("charset")
    .fill cs.size(), cs.get(i)
}

// Emit tile index table at a given address
// Each tile = CTM_CHARS_PER_TILE bytes (char indices)
.macro CtmEmitTiles(ctm, addr) {
    * = addr
    .var t = ctm.get("tiles")
    .fill t.size(), t.get(i)
}

// Emit map (tile indices) at a given address
.macro CtmEmitMap(ctm, addr) {
    * = addr
    .var m = ctm.get("map")
    .fill m.size(), m.get(i)
}

// Emit attributes (if present) at a given address
.macro CtmEmitAttrib(ctm, addr) {
    .if (CTM_HAS_ATTRIBUTES) {
        * = addr
        .var a = ctm.get("attrib")
        .fill a.size(), a.get(i)
    }
}

// ---------------------------------------------------------------------------
// OPTIONAL: HELPER TO EMIT EVERYTHING IN ONE GO
// ---------------------------------------------------------------------------

.macro CtmEmitAll(ctm, charsetAddr, tilesAddr, mapAddr, attribAddr) {
    CtmEmitCharset(ctm, charsetAddr)
    CtmEmitTiles(ctm, tilesAddr)
    CtmEmitMap(ctm, mapAddr)
    .if (CTM_HAS_ATTRIBUTES) {
        CtmEmitAttrib(ctm, attribAddr)
    }
}
