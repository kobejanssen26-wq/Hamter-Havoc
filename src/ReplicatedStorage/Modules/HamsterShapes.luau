--[[
	HamsterShapes: the body types. Every hamster has one (set `Look.Shape = "chonk"` in Content/Hamsters, or leave it out and it is
	picked from the id, always the same one for the same hamster). A shape changes the body proportions AND the overall size, so
	hamsters differ in height and silhouette, not only in colour:

	  standard  the classic round hamster          chonk     wide, round and a bit bigger
	  lanky     tall and slim (1.3x as tall)       long      a sausage: long body
	  bean      small, compact, cute               tiny      very small (0.6x)
	  giant     big and stocky (1.5x)

	Width / Height / Length multiply the body sphere, Head the head sphere (kept small so the face still fits), Size multiplies
	the hamster's overall size (and so its height in the ball, on the wheel and in the collection).
]]

local HamsterShapes = {}

HamsterShapes.List = {
	standard = { Width = 1.0, Height = 1.0, Length = 1.0, Head = 1.0, SizeMul = 1.0, Weight = 26 },
	chonk = { Width = 1.32, Height = 1.08, Length = 1.2, Head = 1.0, SizeMul = 1.12, Weight = 18 },
	lanky = { Width = 0.8, Height = 1.1, Length = 0.88, Head = 0.96, SizeMul = 1.32, Weight = 15 },
	long = { Width = 0.9, Height = 0.95, Length = 1.45, Head = 0.96, SizeMul = 1.05, Weight = 14 },
	bean = { Width = 0.92, Height = 0.92, Length = 0.92, Head = 1.1, SizeMul = 0.82, Weight = 16 },
	tiny = { Width = 0.9, Height = 0.9, Length = 0.9, Head = 1.08, SizeMul = 0.62, Weight = 6 },
	giant = { Width = 1.18, Height = 1.06, Length = 1.15, Head = 1.04, SizeMul = 1.5, Weight = 5 },
}

local ORDER = { "standard", "chonk", "lanky", "long", "bean", "tiny", "giant" }

local function hashOf(id: string): number
	local hash = 5381
	for index = 1, #id do
		hash = (hash * 33 + string.byte(id, index)) % 2147483647
	end
	return hash
end

-- The shape picked for a hamster id (stable).
function HamsterShapes.pick(id: string): string
	local total = 0
	for _, name in ORDER do
		total += HamsterShapes.List[name].Weight
	end
	local target = (hashOf(id) % 10007) / 10007 * total
	local running = 0
	for _, name in ORDER do
		running += HamsterShapes.List[name].Weight
		if target < running then
			return name
		end
	end
	return "standard"
end

function HamsterShapes.exists(name: any): boolean
	return type(name) == "string" and HamsterShapes.List[name] ~= nil
end

-- Body proportions of a shape with a tiny stable jitter (+-4 %) so two "chonk" hamsters are still not identical.
function HamsterShapes.proportions(shape: string, id: string): { Width: number, Height: number, Length: number, Head: number }
	local def = HamsterShapes.List[shape] or HamsterShapes.List.standard
	local hash = hashOf(id)
	local function jitter(shift: number): number
		return 1 + (((hash // shift) % 1000) / 999 * 2 - 1) * 0.04
	end
	return { Width = def.Width * jitter(1), Height = def.Height * jitter(7), Length = def.Length * jitter(31), Head = def.Head * jitter(127) }
end

return HamsterShapes
