--[[
	HamsterAnimator: procedural animation for the rigged hamster models (pure Motor6D.Transform work,
	no animation assets). Animations:  Idle (breathing, tail wag, ear twitch)  Walk  Happy  Collect
	Random idle behaviours: look around, sniff, jump, roll, scratch, eat, wave (+ wing flaps if winged).
]]

local HamsterAnimator = {}
HamsterAnimator.__index = HamsterAnimator

local CF = CFrame.new
local ANG = CFrame.Angles
local IDENTITY = CFrame.identity

local JOINT_NAMES = { "BodyJ", "HeadJ", "EarLJ", "EarRJ", "PawFLJ", "PawFRJ", "PawBLJ", "PawBRJ", "TailJ", "WingLJ", "WingRJ" }
local BEHAVIORS = { "look", "look", "sniff", "sniff", "jump", "roll", "scratch", "eat", "wave" }
local DURATIONS = { look = 1.8, sniff = 1.5, jump = 0.7, roll = 1.0, scratch = 1.4, eat = 2.4, wave = 1.9 }

-- Personality idles: small continuous motions layered on the normal idle so every character carries itself differently.
-- Set per hamster with Persona = "..." in its Content/Hamsters file (see HamsterBuilder / docs/CONTENT_GUIDE.md).
local PERSONA_IDLE: { [string]: (number, (string, CFrame) -> ()) -> () } = {
	hyper = function(t, add)
		add("BodyJ", CF(0, math.abs(math.sin(t * 7)) * 0.07, 0))
		add("HeadJ", ANG(math.sin(t * 5) * 0.08, math.sin(t * 3.1) * 0.16, 0))
		add("PawFLJ", ANG(math.sin(t * 8) * 0.3, 0, 0))
		add("PawFRJ", ANG(-math.sin(t * 8) * 0.3, 0, 0))
	end,
	smug = function(t, add)
		add("BodyJ", ANG(-0.06, 0, 0))
		add("HeadJ", ANG(-0.14 + math.sin(t * 0.6) * 0.04, math.sin(t * 0.4) * 0.25, math.sin(t * 0.4) * 0.08))
	end,
	scheming = function(t, add)
		local rub = math.sin(t * 9) * 0.25
		add("PawFLJ", ANG(-0.5 + rub, 0, 0.2))
		add("PawFRJ", ANG(-0.5 - rub, 0, -0.2))
		add("HeadJ", ANG(0.05, math.sin(t * 0.7) * 0.35, 0))
	end,
	mischievous = function(t, add)
		local glance = math.max(0, math.sin(t * 0.8)) ^ 6
		add("HeadJ", ANG(0, glance * 0.7 * (if math.sin(t * 0.4) > 0 then 1 else -1), glance * 0.15))
		add("TailJ", ANG(0, math.sin(t * 3) * 0.3, 0))
	end,
	screamer = function(t, add)
		local burst = math.max(0, math.sin(t * 1.4)) ^ 12 -- every few seconds: a short loud fit
		add("HeadJ", ANG(-0.25 * burst, math.sin(t * 38) * 0.18 * burst, 0))
		add("BodyJ", CF(math.sin(t * 41) * 0.06 * burst, burst * 0.12, 0) * ANG(0, 0, math.sin(t * 33) * 0.1 * burst))
		add("PawFLJ", ANG(-0.9 * burst, 0, 0))
		add("PawFRJ", ANG(-0.9 * burst, 0, 0))
	end,
	dancer = function(t, add)
		add("BodyJ", CF(0, math.abs(math.sin(t * 4)) * 0.05, 0) * ANG(0, 0, math.sin(t * 4) * 0.12))
		add("HeadJ", ANG(0, 0, -math.sin(t * 4) * 0.1))
		add("PawFLJ", ANG(math.sin(t * 4) * 0.5, 0, 0))
		add("PawFRJ", ANG(-math.sin(t * 4) * 0.5, 0, 0))
	end,
	sleepy = function(t, add)
		add("HeadJ", ANG(0.28 + math.sin(t * 0.7) * 0.12, 0, math.sin(t * 0.5) * 0.06))
		add("BodyJ", ANG(0.05, 0, 0))
	end,
	confused = function(t, add)
		add("HeadJ", ANG(0, math.sin(t * 0.9) * 0.3, math.sin(t * 0.9 + 1) * 0.25))
	end,
	rich = function(t, add)
		add("HeadJ", ANG(-0.28, math.sin(t * 0.5) * 0.12, 0))
		add("BodyJ", ANG(-0.05, 0, 0))
	end,
}

export type Animator = typeof(setmetatable({} :: {
	Model: Model,
	Joints: { [string]: Motor6D },
	Scale: number,
	Time: number,
	Phase: number,
	Behavior: { Name: string, T: number, Duration: number, Dir: number }?,
	NextBehavior: number,
	OneShot: { Name: string, T: number, Duration: number }?,
	OnStep: (() -> ())?,
	StepSign: number,
	HasWings: boolean,
	Lean: number,
	Persona: string?,
}, HamsterAnimator))

function HamsterAnimator.new(model: Model): Animator
	local self = setmetatable({
		Model = model,
		Joints = {},
		Scale = model:GetScale(),
		Time = math.random() * 10,
		Phase = math.random() * 6,
		Behavior = nil,
		NextBehavior = 0,
		OneShot = nil,
		OnStep = nil,
		StepSign = 1,
		HasWings = false,
		Lean = 0,
		Persona = model:GetAttribute("Persona"),
	}, HamsterAnimator)

	for _, name in JOINT_NAMES do
		local joint = model:FindFirstChild(name, true)
		if joint and joint:IsA("Motor6D") then
			self.Joints[name] = joint
		end
	end
	self.HasWings = self.Joints.WingLJ ~= nil
	self.NextBehavior = self.Time + 1.5 + math.random() * 4
	return self
end

function HamsterAnimator.PlayOneShot(self: Animator, name: string)
	local durations = { Happy = 1.1, Collect = 0.45, Cheer = 1.6 }
	self.OneShot = { Name = name, T = 0, Duration = durations[name] or 1 }
end

local function envelope(t: number, duration: number): number
	return math.sin(math.clamp(t / duration, 0, 1) * math.pi)
end

-- moveSpeed: studs per second the hamster is travelling (0 = standing still).
-- turnRate: radians per second the hamster is turning (positive = to the left); it leans into the turn.
function HamsterAnimator.Update(self: Animator, dt: number, moveSpeed: number, turnRate: number?)
	self.Time += dt
	local wantedLean = if moveSpeed > 0.5 then math.clamp((turnRate or 0) / 3, -1, 1) else 0
	self.Lean += (wantedLean - self.Lean) * math.min(1, dt * 8)
	local scale = self.Scale
	local time = self.Time
	local pose: { [string]: CFrame } = {}

	local function add(joint: string, cframe: CFrame)
		pose[joint] = (pose[joint] or IDENTITY) * cframe
	end

	if moveSpeed > 0.5 then
		-- walking / running
		local stepsPerSecond = math.clamp(2 + moveSpeed * 0.16, 2.5, 11)
		self.Phase += dt * stepsPerSecond * math.pi * 2
		local phase = self.Phase
		local swing = math.sin(phase) * 0.85
		add("BodyJ", CF(0, math.abs(math.sin(phase)) * 0.18 * scale, 0) * ANG(math.sin(phase * 2) * 0.03, 0, math.sin(phase) * 0.05))
		add("HeadJ", ANG(math.sin(phase * 2 + 0.6) * 0.06, 0, 0))
		add("PawFLJ", ANG(swing, 0, 0) * CF(0, math.max(0, math.cos(phase)) * 0.12 * scale, 0))
		add("PawBRJ", ANG(swing, 0, 0) * CF(0, math.max(0, math.cos(phase)) * 0.12 * scale, 0))
		add("PawFRJ", ANG(-swing, 0, 0) * CF(0, math.max(0, -math.cos(phase)) * 0.12 * scale, 0))
		add("PawBLJ", ANG(-swing, 0, 0) * CF(0, math.max(0, -math.cos(phase)) * 0.12 * scale, 0))
		add("EarLJ", ANG(0, 0, math.sin(phase * 2 + 0.3) * 0.2))
		add("EarRJ", ANG(0, 0, -math.sin(phase * 2 + 0.3) * 0.2))
		add("TailJ", ANG(0, math.sin(phase) * 0.5, 0))
		-- lean into the turn: body rolls, head looks where it is going, tail swings out
		add("BodyJ", ANG(0, 0, -self.Lean * 0.2))
		add("HeadJ", ANG(0, self.Lean * 0.3, 0))
		add("TailJ", ANG(0, -self.Lean * 0.35, 0))
		local flap = math.sin(phase * 1.4) * 0.45
		add("WingRJ", ANG(0, 0, flap))
		add("WingLJ", ANG(0, 0, -flap))

		local sign = if math.sin(phase) >= 0 then 1 else -1
		if sign ~= self.StepSign then
			self.StepSign = sign
			if self.OnStep then
				self.OnStep()
			end
		end
		self.Behavior = nil
	else
		-- idle
		add("BodyJ", CF(0, math.sin(time * 2.2) * 0.025 * scale, 0))
		add("HeadJ", ANG(0, math.sin(time * 0.8) * 0.07, 0))
		add("TailJ", ANG(0, math.sin(time * 1.3) * 0.18, 0))
		local twitch = math.max(0, math.sin(time * 0.9 + 2)) ^ 14
		add("EarLJ", ANG(0, 0, twitch * 0.3))
		add("EarRJ", ANG(0, 0, -twitch * 0.2))
		local flap = math.sin(time * 1.8) * 0.14
		add("WingRJ", ANG(0, 0, flap))
		add("WingLJ", ANG(0, 0, -flap))
		local persona = if self.Persona then PERSONA_IDLE[self.Persona] else nil
		if persona then
			persona(time, add)
		end

		-- random behaviours
		if not self.Behavior and not self.OneShot and time >= self.NextBehavior then
			local name = BEHAVIORS[math.random(1, #BEHAVIORS)]
			self.Behavior = { Name = name, T = 0, Duration = DURATIONS[name], Dir = if math.random() > 0.5 then 1 else -1 }
		end
		local behavior = self.Behavior
		if behavior then
			behavior.T += dt
			local t = behavior.T
			local e = envelope(t, behavior.Duration)
			local name = behavior.Name
			if name == "look" then
				add("HeadJ", ANG(0, e * 0.8 * behavior.Dir, 0) * ANG(0, 0, e * 0.1 * behavior.Dir))
			elseif name == "sniff" then
				add("HeadJ", ANG(-0.15 * e - math.abs(math.sin(t * 14)) * 0.12 * e, 0, 0))
				add("BodyJ", ANG(0.05 * e, 0, 0))
			elseif name == "jump" then
				add("BodyJ", CF(0, e * 0.95 * scale, 0))
				add("PawFLJ", ANG(-0.6 * e, 0, 0))
				add("PawFRJ", ANG(-0.6 * e, 0, 0))
				add("PawBLJ", ANG(0.5 * e, 0, 0))
				add("PawBRJ", ANG(0.5 * e, 0, 0))
				add("EarLJ", ANG(0, 0, 0.3 * e))
				add("EarRJ", ANG(0, 0, -0.3 * e))
			elseif name == "roll" then
				add("BodyJ", CF(0, e * 0.25 * scale, 0) * ANG(t / behavior.Duration * math.pi * 2 * behavior.Dir, 0, 0))
			elseif name == "scratch" then
				add("PawBRJ", ANG(-1.1 * math.min(1, e * 2) + math.sin(t * 28) * 0.45 * e, 0, 0))
				add("HeadJ", ANG(0, 0, 0.18 * e))
				add("BodyJ", ANG(0, 0, -0.08 * e))
			elseif name == "eat" then
				local raise = math.min(1, e * 2.2)
				add("PawFLJ", ANG(-1.4 * raise, 0, 0) * CF(0, 0.15 * raise * scale, 0))
				add("PawFRJ", ANG(-1.4 * raise, 0, 0) * CF(0, 0.15 * raise * scale, 0))
				add("HeadJ", ANG(math.sin(t * 17) * 0.07 * raise, 0, 0))
			elseif name == "wave" then
				local raise = math.min(1, e * 2.2)
				add("PawFRJ", ANG(0, 0, (2.3 + math.sin(t * 9) * 0.35) * raise))
				add("HeadJ", ANG(0, 0, 0.12 * raise))
			end
			if t >= behavior.Duration then
				self.Behavior = nil
				self.NextBehavior = time + 2.5 + math.random() * 4.5
			end
		end
	end

	-- one-shot reactions (override / add on top)
	local oneShot = self.OneShot
	if oneShot then
		oneShot.T += dt
		local t = oneShot.T
		local progress = math.clamp(t / oneShot.Duration, 0, 1)
		if oneShot.Name == "Happy" or oneShot.Name == "Cheer" then
			add("BodyJ", CF(0, math.abs(math.sin(progress * math.pi * 2)) * 0.9 * scale, 0) * ANG(0, progress * math.pi * 2, 0))
			add("EarLJ", ANG(0, 0, 0.5))
			add("EarRJ", ANG(0, 0, -0.5))
			add("PawFLJ", ANG(0, 0, -2.2))
			add("PawFRJ", ANG(0, 0, 2.2))
		elseif oneShot.Name == "Collect" then
			add("BodyJ", CF(0, math.sin(progress * math.pi) * 1.4 * scale, 0) * ANG(-progress * 0.8, 0, 0))
		end
		if progress >= 1 then
			self.OneShot = nil
			self.NextBehavior = time + 2
		end
	end

	for name, joint in self.Joints do
		joint.Transform = pose[name] or IDENTITY
	end
end

return HamsterAnimator
