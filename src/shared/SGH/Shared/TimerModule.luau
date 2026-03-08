-- TimerModule: countdown timer with Tick (per-second) and Expired signals
local RunService = game:GetService("RunService")
local TimerModule = {}
TimerModule.__index = TimerModule

function TimerModule.new(duration)
	local self = setmetatable({}, TimerModule)
	self._duration  = duration
	self._remaining = duration
	self._running   = false
	self._conn      = nil
	self.Tick       = Instance.new("BindableEvent")  -- fires(remaining) each second
	self.Expired    = Instance.new("BindableEvent")  -- fires when reaches 0
	return self
end

function TimerModule:Start()
	if self._running then return end
	self._running = true
	local lastFire = math.ceil(self._remaining)
	self._conn = RunService.Heartbeat:Connect(function(dt)
		if not self._running then return end
		self._remaining = math.max(0, self._remaining - dt)
		local whole = math.ceil(self._remaining)
		if whole < lastFire then
			lastFire = whole
			self.Tick:Fire(self._remaining)
		end
		if self._remaining <= 0 then
			self._running = false
			if self._conn then self._conn:Disconnect(); self._conn = nil end
			self.Expired:Fire()
		end
	end)
end

function TimerModule:GetRemaining()
	return self._remaining
end

function TimerModule:Destroy()
	self._running = false
	if self._conn then self._conn:Disconnect(); self._conn = nil end
	pcall(function() self.Tick:Destroy() end)
	pcall(function() self.Expired:Destroy() end)
end

return TimerModule
