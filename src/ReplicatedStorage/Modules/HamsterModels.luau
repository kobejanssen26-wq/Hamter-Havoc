--[[
	HamsterModels: use your own Studio-made model for a hamster instead of the procedural one.

	Put the model in  ReplicatedStorage/Assets/HamsterModels/<ModelName>  (in the repo:
	src/ReplicatedStorage/Assets/HamsterModels/<ModelName>.rbxm, exported from Studio with "Save to File...") and set
	ModelName = "<ModelName>" in the hamster's file in Modules/Content/Hamsters.

	Rules for the model (checked here; a model that breaks them is rejected and the procedural hamster is used):
	  - a Model with at least one BasePart
	  - facing -Z (the front looks along negative Z), roughly 3.4 studs tall at scale 1 (it is scaled by species.Size)
	  - a PrimaryPart (or a part called "Root"); if there is none, the first part becomes the pivot
	  - scripts inside are removed; every part is anchored and non-colliding (the game moves it by pivot)
	Optional: Motor6Ds named BodyJ, HeadJ, EarLJ, EarRJ, PawFLJ, PawFRJ, PawBLJ, PawBRJ, TailJ give you the built-in
	procedural animation; without them the model simply stays rigid unless you register animations (docs/CONTENT_GUIDE.md).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HamsterModels = {}

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn("[HamsterModels] " .. message)
	end
end

function HamsterModels.template(modelName: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("HamsterModels")
	local template = folder and folder:FindFirstChild(modelName)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

-- Returns a ready-to-use clone, or nil (then the caller builds the procedural hamster).
function HamsterModels.instantiate(species: any, scale: number): Model?
	local name = species.ModelName
	if type(name) ~= "string" then
		return nil
	end
	local template = HamsterModels.template(name)
	if not template then
		warnOnce(name, string.format("model '%s' of hamster '%s' not found in ReplicatedStorage/Assets/HamsterModels - using the procedural look", name, species.Id))
		return nil
	end
	local model = template:Clone()
	local firstPart: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			firstPart = firstPart or descendant
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	if not firstPart then
		model:Destroy()
		warnOnce(name, string.format("model '%s' has no parts - using the procedural look", name))
		return nil
	end
	if not model.PrimaryPart then
		local root = model:FindFirstChild("Root", true)
		model.PrimaryPart = if root and root:IsA("BasePart") then root else firstPart
	end
	model.Name = species.Name
	local total = (species.Size or 1) * scale
	if math.abs(total - 1) > 0.001 then
		model:ScaleTo(total)
	end
	model:SetAttribute("SpeciesId", species.Id)
	model:SetAttribute("Rarity", species.Rarity)
	model:SetAttribute("Height", 3.4 * total)
	model:SetAttribute("CustomModel", true)
	return model
end

return HamsterModels
