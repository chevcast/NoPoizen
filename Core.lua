local addonName, addonTable = ...

local NoPoizen = _G.NoPoizen or addonTable or {}
_G.NoPoizen = NoPoizen

NoPoizen.addonName = addonName or "NoPoizen"
NoPoizen.MISSING_SOUND_FILE_PATH = "Interface\\AddOns\\NoPoizen\\nopoizen.wav"
NoPoizen.SATISFIED_SOUND_FILE_PATH = "Interface\\AddOns\\NoPoizen\\hahaha.wav"
NoPoizen.DRAGON_TEMPERED_BLADES_SPELL_ID = 381801

NoPoizen.WIDGET_SCALE_MIN = 0.6
NoPoizen.WIDGET_SCALE_MAX = 2.0
NoPoizen.WIDGET_SCALE_STEP = 0.05
NoPoizen.AUDIO_VOLUME_MIN = 0
NoPoizen.AUDIO_VOLUME_MAX = 1
NoPoizen.AUDIO_VOLUME_STEP = 0.05

NoPoizen.DEFAULT_INDICATOR_ANCHOR = {
	point = "CENTER",
	relativePoint = "CENTER",
	x = 0,
	y = 140,
}

NoPoizen.DEFAULTS = {
	enabled = true,
	showVisualIndicator = true,
	playAudioIndicator = true,
	audioVolume = 0.5,
	playSatisfiedAudioIndicator = true,
	satisfiedAudioVolume = 0.5,
	widgetScale = 1.0,
	indicatorAnchor = {
		point = "CENTER",
		relativePoint = "CENTER",
		x = 0,
		y = 140,
	},
}

NoPoizen.isInitialized = NoPoizen.isInitialized or false
NoPoizen.hasLoggedIn = NoPoizen.hasLoggedIn or false
NoPoizen.isEnabled = NoPoizen.isEnabled or false
NoPoizen.audioMissingState = NoPoizen.audioMissingState or false

NoPoizen.runtimeEvents = {
	"PLAYER_ENTERING_WORLD",
	"UNIT_AURA",
	"SPELLS_CHANGED",
	"PLAYER_TALENT_UPDATE",
	"ACTIVE_TALENT_GROUP_CHANGED",
	"PLAYER_SPECIALIZATION_CHANGED",
	"TRAIT_CONFIG_UPDATED",
	"TRAIT_CONFIG_LIST_UPDATED",
}

NoPoizen.API = NoPoizen.API or {
	Delay = function(delaySeconds, callbackFn)
		if C_Timer and C_Timer.After then
			C_Timer.After(delaySeconds, callbackFn)
		end
	end,
	GetTime = function()
		return GetTime and GetTime() or 0
	end,
}

local function IsNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

function NoPoizen:SafeToString(value, fallback)
	if value == nil then
		return fallback or ""
	end
	return tostring(value)
end

function NoPoizen:DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, item in pairs(value) do
		copy[key] = self:DeepCopy(item)
	end
	return copy
end

function NoPoizen:ApplyDefaults(destination, defaults)
	if type(destination) ~= "table" or type(defaults) ~= "table" then
		return destination
	end

	for key, defaultValue in pairs(defaults) do
		if destination[key] == nil then
			destination[key] = self:DeepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(destination[key]) == "table" then
			self:ApplyDefaults(destination[key], defaultValue)
		end
	end

	return destination
end

function NoPoizen:Print(message)
	local text = "|cffff4f4fNoPoizen|r: " .. self:SafeToString(message)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(text)
	else
		print("NoPoizen:", self:SafeToString(message))
	end
end

function NoPoizen:GetPlayerClassFile()
	local _, classFile = UnitClass("player")
	return classFile
end

function NoPoizen:IsPlayerRogue()
	return self:GetPlayerClassFile() == "ROGUE"
end

function NoPoizen:NormalizeWidgetScale(value)
	local numberValue = tonumber(value)
	if not numberValue then
		return nil
	end
	local step = self.WIDGET_SCALE_STEP
	numberValue = math.floor((numberValue / step) + 0.5) * step
	numberValue = math.floor((numberValue * 100) + 0.5) / 100
	if numberValue < self.WIDGET_SCALE_MIN or numberValue > self.WIDGET_SCALE_MAX then
		return nil
	end
	return numberValue
end

function NoPoizen:NormalizeAudioVolume(value)
	local numberValue = tonumber(value)
	if not numberValue then
		return nil
	end
	local step = self.AUDIO_VOLUME_STEP
	numberValue = math.floor((numberValue / step) + 0.5) * step
	numberValue = math.floor((numberValue * 100) + 0.5) / 100
	if numberValue < self.AUDIO_VOLUME_MIN or numberValue > self.AUDIO_VOLUME_MAX then
		return nil
	end
	return numberValue
end

function NoPoizen:GetEffectiveAudioVolume(value)
	local normalized = self:NormalizeAudioVolume(value)
	if not normalized then
		normalized = self:NormalizeAudioVolume(self:GetOption("audioVolume")) or self.DEFAULTS.audioVolume
	end
	return math.min(1, normalized * 2)
end

function NoPoizen:InitializeDatabase()
	if type(_G.NoPoizenDBChar) ~= "table" then
		_G.NoPoizenDBChar = {}
	end
	self.db = _G.NoPoizenDBChar
	self:ApplyDefaults(self.db, self.DEFAULTS)

	self.db.widgetScale = self:NormalizeWidgetScale(self.db.widgetScale) or self.DEFAULTS.widgetScale
	self.db.audioVolume = self:NormalizeAudioVolume(self.db.audioVolume) or self.DEFAULTS.audioVolume
	self.db.satisfiedAudioVolume = self:NormalizeAudioVolume(self.db.satisfiedAudioVolume) or self.DEFAULTS.satisfiedAudioVolume
end

function NoPoizen:GetOption(optionKey)
	if not self.db then
		return nil
	end
	return self.db[optionKey]
end

function NoPoizen:SetOption(optionKey, value)
	if not self.db then
		return false
	end

	local normalizedValue = value
	if
		optionKey == "showVisualIndicator"
		or optionKey == "playAudioIndicator"
		or optionKey == "playSatisfiedAudioIndicator"
		or optionKey == "enabled"
	then
		normalizedValue = value and true or false
	elseif optionKey == "widgetScale" then
		normalizedValue = self:NormalizeWidgetScale(value)
		if not normalizedValue then
			return false
		end
	elseif optionKey == "audioVolume" or optionKey == "satisfiedAudioVolume" then
		normalizedValue = self:NormalizeAudioVolume(value)
		if not normalizedValue then
			return false
		end
	else
		return false
	end

	local oldValue = self.db[optionKey]
	if oldValue == normalizedValue then
		return true
	end
	self.db[optionKey] = normalizedValue

	if optionKey == "enabled" then
		if normalizedValue then
			self:Enable()
		else
			self:Disable()
		end
	else
		if self.RefreshPoisonState then
			self:RefreshPoisonState("OPTION_CHANGED")
		end
		if self.RefreshPoisonIndicatorVisualState then
			self:RefreshPoisonIndicatorVisualState()
		end
	end

	if self.RefreshOptionsWindow then
		self:RefreshOptionsWindow()
	end

	return true
end

function NoPoizen:GetIndicatorAnchor()
	local anchor = (self.db and self.db.indicatorAnchor) or self.DEFAULT_INDICATOR_ANCHOR
	return {
		point = IsNonEmptyString(anchor.point) and anchor.point or self.DEFAULT_INDICATOR_ANCHOR.point,
		relativePoint = IsNonEmptyString(anchor.relativePoint) and anchor.relativePoint or self.DEFAULT_INDICATOR_ANCHOR.relativePoint,
		x = tonumber(anchor.x) or self.DEFAULT_INDICATOR_ANCHOR.x,
		y = tonumber(anchor.y) or self.DEFAULT_INDICATOR_ANCHOR.y,
	}
end

function NoPoizen:SetIndicatorAnchor(point, relativePoint, x, y)
	if not self.db then
		return false
	end
	if not IsNonEmptyString(point) or not IsNonEmptyString(relativePoint) then
		return false
	end

	local roundedX = tonumber(x) or 0
	local roundedY = tonumber(y) or 0
	if roundedX >= 0 then
		roundedX = math.floor(roundedX + 0.5)
	else
		roundedX = math.ceil(roundedX - 0.5)
	end
	if roundedY >= 0 then
		roundedY = math.floor(roundedY + 0.5)
	else
		roundedY = math.ceil(roundedY - 0.5)
	end

	local existing = self:GetIndicatorAnchor()
	local changed = existing.point ~= point
		or existing.relativePoint ~= relativePoint
		or existing.x ~= roundedX
		or existing.y ~= roundedY
	if not changed then
		return false
	end

	self.db.indicatorAnchor = {
		point = point,
		relativePoint = relativePoint,
		x = roundedX,
		y = roundedY,
	}
	if self.ApplySavedIndicatorAnchor then
		self:ApplySavedIndicatorAnchor()
	end
	return true
end

function NoPoizen:ResetIndicatorAnchor()
	return self:SetIndicatorAnchor(
		self.DEFAULT_INDICATOR_ANCHOR.point,
		self.DEFAULT_INDICATOR_ANCHOR.relativePoint,
		self.DEFAULT_INDICATOR_ANCHOR.x,
		self.DEFAULT_INDICATOR_ANCHOR.y
	)
end

function NoPoizen:ForEachHelpfulAura(unitToken, callback)
	if type(callback) ~= "function" then
		return
	end

	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		for auraIndex = 1, 255 do
			local aura = C_UnitAuras.GetAuraDataByIndex(unitToken, auraIndex, "HELPFUL")
			if not aura then
				break
			end
			callback(aura.spellId, aura.name, aura.icon)
		end
		return
	end

	if UnitAura then
		for auraIndex = 1, 40 do
			local name, icon, _, _, _, _, _, _, _, spellID = UnitAura(unitToken, auraIndex, "HELPFUL")
			if not name then
				break
			end
			callback(spellID, name, icon)
		end
	end
end

local function ClampZeroToOne(value)
	local numberValue = tonumber(value) or 0
	if numberValue < 0 then
		return 0
	end
	if numberValue > 1 then
		return 1
	end
	return numberValue
end

function NoPoizen:AcquireTemporaryChannelVolume(cvarName, targetVolume)
	if not cvarName or cvarName == "" or type(SetCVar) ~= "function" then
		return false
	end

	self.activeChannelVolumeLocks = self.activeChannelVolumeLocks or {}
	local lock = self.activeChannelVolumeLocks[cvarName]
	if not lock then
		lock = {
			depth = 0,
			original = tonumber(GetCVar and GetCVar(cvarName)) or 1,
		}
		self.activeChannelVolumeLocks[cvarName] = lock
	end

	lock.depth = lock.depth + 1
	local clampedTarget = ClampZeroToOne(targetVolume)
	pcall(SetCVar, cvarName, tostring(clampedTarget))
	return true
end

function NoPoizen:ReleaseTemporaryChannelVolume(cvarName)
	if not cvarName or cvarName == "" or type(SetCVar) ~= "function" then
		return
	end
	if not self.activeChannelVolumeLocks then
		return
	end

	local lock = self.activeChannelVolumeLocks[cvarName]
	if not lock then
		return
	end

	lock.depth = (lock.depth or 0) - 1
	if lock.depth > 0 then
		return
	end

	pcall(SetCVar, cvarName, tostring(ClampZeroToOne(lock.original)))
	self.activeChannelVolumeLocks[cvarName] = nil
end

function NoPoizen:RestoreChannelVolumeAfterPlayback(cvarName, soundHandle)
	local maxWaitSeconds = 10
	local pollSeconds = 0.05

	if soundHandle and C_Sound and type(C_Sound.IsPlaying) == "function" and self.API and self.API.GetTime and self.API.Delay then
		local startTime = self.API.GetTime()
		local function Poll()
			local isPlaying = false
			local ok = pcall(function()
				isPlaying = C_Sound.IsPlaying(soundHandle)
			end)
			local elapsed = (self.API.GetTime() or 0) - (startTime or 0)
			if ok and isPlaying and elapsed < maxWaitSeconds then
				self.API.Delay(pollSeconds, Poll)
				return
			end
			self:ReleaseTemporaryChannelVolume(cvarName)
		end
		self.API.Delay(pollSeconds, Poll)
		return
	end

	if self.API and self.API.Delay then
		self.API.Delay(1.25, function()
			self:ReleaseTemporaryChannelVolume(cvarName)
		end)
	else
		self:ReleaseTemporaryChannelVolume(cvarName)
	end
end

function NoPoizen:PlayAlertSound(soundFilePath, volumeOptionKey)
	if type(soundFilePath) ~= "string" or soundFilePath == "" then
		return false
	end

	local volume = self:GetEffectiveAudioVolume(self:GetOption(volumeOptionKey))
	if volume <= 0 then
		return false
	end

	local channel = "Dialog"
	local channelVolumeCVar = "Sound_DialogVolume"
	if GetCVar and GetCVar("Sound_EnableDialog") == "0" then
		channel = "SFX"
		channelVolumeCVar = "Sound_SFXVolume"
	end

	if not self:AcquireTemporaryChannelVolume(channelVolumeCVar, volume) then
		local ok, willPlay = pcall(PlaySoundFile, soundFilePath, channel)
		return ok and (willPlay and true or false)
	end

	local ok, willPlay, soundHandle = pcall(PlaySoundFile, soundFilePath, channel)
	if not ok or not willPlay then
		self:ReleaseTemporaryChannelVolume(channelVolumeCVar)
		return false
	end
	self:RestoreChannelVolumeAfterPlayback(channelVolumeCVar, type(soundHandle) == "number" and soundHandle or nil)
	return true
end

function NoPoizen:PlayMissingPoisonSound()
	return self:PlayAlertSound(self.MISSING_SOUND_FILE_PATH, "audioVolume")
end

function NoPoizen:PlaySatisfiedPoisonSound()
	return self:PlayAlertSound(self.SATISFIED_SOUND_FILE_PATH, "satisfiedAudioVolume")
end

function NoPoizen:RegisterRuntimeEvents()
	self.registeredRuntimeEvents = self.registeredRuntimeEvents or {}
	wipe(self.registeredRuntimeEvents)

	for _, eventName in ipairs(self.runtimeEvents) do
		local ok = pcall(self.eventFrame.RegisterEvent, self.eventFrame, eventName)
		if ok then
			self.registeredRuntimeEvents[eventName] = true
		end
	end
end

function NoPoizen:UnregisterRuntimeEvents()
	for eventName in pairs(self.registeredRuntimeEvents or {}) do
		pcall(self.eventFrame.UnregisterEvent, self.eventFrame, eventName)
	end
	if self.registeredRuntimeEvents then
		wipe(self.registeredRuntimeEvents)
	end
end

function NoPoizen:Enable()
	if not self.db then
		return false
	end
	self.db.enabled = true

	if not self.hasLoggedIn then
		return true
	end
	if self.isEnabled then
		return true
	end

	self:RegisterRuntimeEvents()
	self.isEnabled = true
	self.audioMissingState = false

	if self.EnsurePoisonIndicatorWidget then
		self:EnsurePoisonIndicatorWidget()
	end
	if self.TryInstallPoisonIndicatorEditModeHooks then
		self:TryInstallPoisonIndicatorEditModeHooks()
	end
	if self.RefreshPoisonState then
		self:RefreshPoisonState("ENABLE")
	end
	if self.RefreshPoisonIndicatorVisualState then
		self:RefreshPoisonIndicatorVisualState()
	end
	return true
end

function NoPoizen:Disable()
	if not self.db then
		return false
	end
	self.db.enabled = false

	if not self.isEnabled then
		return true
	end

	self:UnregisterRuntimeEvents()
	self.isEnabled = false
	self.audioMissingState = false
	if self.DeselectPoisonIndicatorAnchor then
		self:DeselectPoisonIndicatorAnchor()
	end
	if self.RefreshPoisonIndicatorVisualState then
		self:RefreshPoisonIndicatorVisualState()
	end
	return true
end

function NoPoizen:OpenHudEditMode()
	if not EditModeManagerFrame then
		pcall(UIParentLoadAddOn, "Blizzard_EditMode")
	end
	if EditModeManagerFrame and ShowUIPanel then
		ShowUIPanel(EditModeManagerFrame)
		return true
	end
	return false
end

function NoPoizen:InitializeSlashCommands()
	SLASH_NOPOIZEN1 = "/nopoizen"
	SLASH_NOPOIZEN2 = "/np"
	SlashCmdList.NOPOIZEN = function(input)
		NoPoizen:HandleSlashCommand(input or "")
	end
end

function NoPoizen:HandleSlashCommand(input)
	local command = string.match(input or "", "^(%S+)") or ""
	command = string.lower(command)

	if command == "" or command == "options" then
		if not self:OpenOptionsWindow() then
			self:Print("Options are unavailable right now.")
		end
		return
	end
	if command == "edit" then
		if not self:OpenHudEditMode() then
			self:Print("HUD Edit Mode is unavailable.")
		end
		return
	end
	if command == "test" then
		if self.RunTests then
			self:RunTests()
		else
			self:Print("Tests are unavailable.")
		end
		return
	end
	if command == "enable" then
		self:SetOption("enabled", true)
		self:Print("NoPoizen enabled.")
		return
	end
	if command == "disable" then
		self:SetOption("enabled", false)
		self:Print("NoPoizen disabled.")
		return
	end

	self:Print("Commands: /nopoizen options | edit | enable | disable | test")
end

function NoPoizen:OnInitialize()
	self:InitializeDatabase()
	self:InitializeSlashCommands()
	if self.InitializeOptionsWindow then
		self:InitializeOptionsWindow()
	end
	if self.TryInstallPoisonIndicatorEditModeHooks then
		self:TryInstallPoisonIndicatorEditModeHooks()
	end
	self.isInitialized = true
end

function NoPoizen:OnLogin()
	self.hasLoggedIn = true
	if self:GetOption("enabled") then
		self:Enable()
	else
		self:Disable()
	end
end

function NoPoizen:ADDON_LOADED(_, loadedAddonName)
	if loadedAddonName == "Blizzard_EditMode" and self.TryInstallPoisonIndicatorEditModeHooks then
		self:TryInstallPoisonIndicatorEditModeHooks()
	end
	if loadedAddonName ~= self.addonName then
		return
	end
	if not self.isInitialized then
		self:OnInitialize()
	end
end

function NoPoizen:PLAYER_LOGIN()
	if not self.isInitialized then
		self:OnInitialize()
	end
	self:OnLogin()
end

function NoPoizen:PLAYER_ENTERING_WORLD()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("PLAYER_ENTERING_WORLD")
	end
end

function NoPoizen:UNIT_AURA(_, unitToken)
	if not self.isEnabled or unitToken ~= "player" then
		return
	end
	if self.RefreshPoisonState then
		self:RefreshPoisonState("UNIT_AURA")
	end
end

function NoPoizen:PLAYER_TALENT_UPDATE()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("PLAYER_TALENT_UPDATE")
	end
end

function NoPoizen:SPELLS_CHANGED()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("SPELLS_CHANGED")
	end
end

function NoPoizen:ACTIVE_TALENT_GROUP_CHANGED()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("ACTIVE_TALENT_GROUP_CHANGED")
	end
end

function NoPoizen:PLAYER_SPECIALIZATION_CHANGED(_, unitToken)
	if unitToken ~= "player" then
		return
	end
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("PLAYER_SPECIALIZATION_CHANGED")
	end
end

function NoPoizen:TRAIT_CONFIG_UPDATED()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("TRAIT_CONFIG_UPDATED")
	end
end

function NoPoizen:TRAIT_CONFIG_LIST_UPDATED()
	if self.isEnabled and self.RefreshPoisonState then
		self:RefreshPoisonState("TRAIT_CONFIG_LIST_UPDATED")
	end
end

local function DispatchEvent(_, eventName, ...)
	local handler = NoPoizen[eventName]
	if type(handler) ~= "function" then
		return
	end
	local ok, err = pcall(handler, NoPoizen, eventName, ...)
	if not ok then
		NoPoizen:Print("Error in event " .. tostring(eventName) .. ": " .. tostring(err))
	end
end

NoPoizen.eventFrame = NoPoizen.eventFrame or CreateFrame("Frame")
NoPoizen.eventFrame:SetScript("OnEvent", DispatchEvent)
NoPoizen.eventFrame:RegisterEvent("ADDON_LOADED")
NoPoizen.eventFrame:RegisterEvent("PLAYER_LOGIN")
