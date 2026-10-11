--[[
	AnimationController: plays animations from the registry (Modules/Content/Animations) or from a raw asset id on any
	Humanoid / AnimationController, and never lets a bad animation hurt the game:
	  - an id that fails to load is reported once (warn) and then ignored for the rest of the session
	  - an entry without AssetId is "not set up yet" and silently skipped
	  - tracks are cached per animator so repeated plays do not create new Animation objects
	Check your uploads in Studio (client view command bar):  require(...AnimationController).preflight()
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AnimationRegistry = require(Modules:WaitForChild("AnimationRegistry"))
local ContentValidator = require(Modules:WaitForChild("ContentValidator"))

local AnimationController = {}

export type PlayOptions = { Priority: Enum.AnimationPriority?, Looped: boolean?, Speed: number?, FadeTime: number?, Weight: number? }

local failed: { [string]: boolean } = {}
local cache: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

local function animatorOf(target: Instance): Animator?
	if target:IsA("Animator") then
		return target
	end
	local existing = target:FindFirstChildOfClass("Animator")
	if existing then
		return existing
	end
	if target:IsA("Humanoid") or target:IsA("AnimationController") then
		local animator = Instance.new("Animator")
		animator.Parent = target
		return animator
	end
	return nil
end

local function priorityOf(name: string?): Enum.AnimationPriority
	local ok, value = pcall(function()
		return (Enum.AnimationPriority :: any)[name or "Action"]
	end)
	if ok and value then
		return value
	end
	return Enum.AnimationPriority.Action
end

local function warnOnce(key: string, message: string)
	if not failed[key] then
		failed[key] = true
		warn("[AnimationController] " .. message)
	end
end

-- Loads (or returns the cached) track for an asset id. nil when it cannot be used.
function AnimationController.loadAsset(target: Instance, assetId: string, key: string?): AnimationTrack?
	local cacheKey = key or assetId
	if failed[cacheKey] then
		return nil
	end
	local ok, set = ContentValidator.assetIdState(assetId)
	if not ok or not set then
		warnOnce(cacheKey, string.format("'%s' is not a valid animation asset id", tostring(assetId)))
		return nil
	end
	local animator = animatorOf(target)
	if not animator then
		return nil
	end
	local perAnimator = cache[animator]
	if not perAnimator then
		perAnimator = {}
		cache[animator] = perAnimator
	end
	if perAnimator[cacheKey] then
		return perAnimator[cacheKey]
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = assetId
	local loaded, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not loaded or not track then
		warnOnce(cacheKey, string.format("could not load %s: %s", assetId, tostring(track)))
		return nil
	end
	perAnimator[cacheKey] = track
	return track
end

local function start(track: AnimationTrack, options: PlayOptions?, def: any?): AnimationTrack
	local opts = options or {}
	track.Priority = opts.Priority or priorityOf(def and def.Priority)
	local looped = opts.Looped
	if looped == nil and def then
		looped = def.Looped
	end
	if looped ~= nil then
		track.Looped = looped
	end
	local fade = opts.FadeTime or (def and def.FadeTime) or 0.15
	track:Play(fade, opts.Weight or 1, opts.Speed or (def and def.Speed) or 1)
	return track
end

-- Plays a registry animation by name on a Humanoid / AnimationController / Animator. Returns the track or nil.
function AnimationController.play(target: Instance, name: string, options: PlayOptions?): AnimationTrack?
	local def = AnimationRegistry.playable(name)
	if not def then
		return nil
	end
	local track = AnimationController.loadAsset(target, def.AssetId, "reg:" .. name)
	if not track then
		return nil
	end
	return start(track, options, def)
end

function AnimationController.playAsset(target: Instance, assetId: string, options: PlayOptions?): AnimationTrack?
	local track = AnimationController.loadAsset(target, assetId)
	if not track then
		return nil
	end
	return start(track, options, nil)
end

function AnimationController.stop(track: AnimationTrack?, fadeTime: number?)
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.15)
	end
end

-- Developer check: tries to load every registered animation and returns { [name] = "Success" | "Failure" | "NotSet" }.
function AnimationController.preflight(): { [string]: string }
	local results = {}
	for _, def in AnimationRegistry.List do
		if def.AssetId == nil or def.AssetId == "" then
			results[def.Name] = "NotSet"
		else
			local animation = Instance.new("Animation")
			animation.AnimationId = def.AssetId
			local assets = { animation }
			local ok = pcall(function()
				ContentProvider:PreloadAsync(assets, function(_id, status)
					results[def.Name] = status.Name
				end)
			end)
			results[def.Name] = results[def.Name] or (if ok then "Success" else "Failure")
			animation:Destroy()
		end
	end
	return results
end

return AnimationController
