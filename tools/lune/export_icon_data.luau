-- Writes IconShapes as JSON (for tools/export_icons.py). usage: lune run tools/lune/export_icon_data.luau <root> <out.json>
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Runtime = require("./runtime")
Runtime.boot(process.args[1] or ".")
local IconShapes = Runtime.mod("IconShapes")
local out = {}
for _, name in IconShapes.Unique do
	out[name] = IconShapes.Shapes[name]
end
fs.writeFile(process.args[2] or "icons.json", serde.encode("json", { Icons = out, Aliases = IconShapes.Aliases }, true))
print("icons:", #IconShapes.Unique)
