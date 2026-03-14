local NoPoizen = _G.NoPoizen

if not NoPoizen then
	return
end

local function GetSpellNameSafe(spellID)
	if C_Spell and C_Spell.GetSpellName then
		local spellName = C_Spell.GetSpellName(spellID)
		if type(spellName) == "string" and spellName ~= "" then
			return spellName
		end
	end
	if GetSpellInfo then
		local spellName = GetSpellInfo(spellID)
		if type(spellName) == "string" and spellName ~= "" then
			return spellName
		end
	end
	return nil
end

local function GetSpellTextureSafe(spellID)
	if C_Spell and C_Spell.GetSpellTexture then
		local texture = C_Spell.GetSpellTexture(spellID)
		if texture then
			return texture
		end
	end
	if GetSpellTexture then
		local texture = GetSpellTexture(spellID)
		if texture then
			return texture
		end
	end
	return nil
end

local function IsSpellKnownSafe(spellID)
	if IsPlayerSpell and IsPlayerSpell(spellID) then
		return true
	end
	if IsSpellKnown and IsSpellKnown(spellID) then
		return true
	end
	return false
end

NoPoizen.poisonCatalog = {
	lethal = {
		{ spellID = 2823, fallbackName = "Deadly Poison" },
		{ spellID = 8679, fallbackName = "Wound Poison" },
		{ spellID = 315584, fallbackName = "Instant Poison" },
		{ spellID = 381664, fallbackName = "Amplifying Poison" },
	},
	nonLethal = {
		{ spellID = 3408, fallbackName = "Crippling Poison" },
		{ spellID = 5761, fallbackName = "Numbing Poison" },
		{ spellID = 381637, fallbackName = "Atrophic Poison" },
	},
}

local function CalculateMissingCounts(requiredCounts, activeCounts)
	local missingLethal = math.max(0, (requiredCounts.lethal or 0) - (activeCounts.lethal or 0))
	local missingNonLethal = math.max(0, (requiredCounts.nonLethal or 0) - (activeCounts.nonLethal or 0))
	return {
		lethal = missingLethal,
		nonLethal = missingNonLethal,
		total = missingLethal + missingNonLethal,
	}
end

local function ResolveRequiredCounts(hasDragonTemperedBlades)
	local extra = hasDragonTemperedBlades and 1 or 0
	return {
		lethal = 1 + extra,
		nonLethal = 1 + extra,
	}
end

local function ShouldPlayAudio(lastMissingState, currentMissingState, audioEnabled, audioVolume)
	if not audioEnabled then
		return false
	end
	if (tonumber(audioVolume) or 0) <= 0 then
		return false
	end
	if not currentMissingState then
		return false
	end
	return not lastMissingState
end

local function ShouldPlaySatisfiedAudio(lastMissingState, currentSatisfiedState, audioEnabled, audioVolume)
	if not audioEnabled then
		return false
	end
	if (tonumber(audioVolume) or 0) <= 0 then
		return false
	end
	if not currentSatisfiedState then
		return false
	end
	return lastMissingState
end

local function ResolveAudioArmingState(isArmed, armAtTime, nowTime)
	if isArmed then
		return true, false
	end

	local armAt = tonumber(armAtTime) or 0
	local now = tonumber(nowTime) or 0
	if now < armAt then
		return false, true
	end

	-- First refresh at/after arm-time seeds baseline state without firing transition audio.
	return true, true
end

local function HasHelpfulAuraBySpellID(unitToken, spellID)
	if not spellID then
		return false
	end

	if AuraUtil and AuraUtil.FindAuraBySpellID then
		local aura = AuraUtil.FindAuraBySpellID(spellID, unitToken, "HELPFUL")
		if aura then
			return true
		end
	end

	if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and unitToken == "player" then
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
		if aura then
			return true
		end
	end

	if UnitAura then
		local spellName = GetSpellNameSafe(spellID)
		if type(spellName) == "string" and spellName ~= "" then
			for auraIndex = 1, 40 do
				local auraName = UnitAura(unitToken, auraIndex, "HELPFUL")
				if not auraName then
					break
				end
				if auraName == spellName then
					return true
				end
			end
		end
	end

	return false
end

local function BuildIndicatorRows(knownByCategory, activeCategoryState, requiredCounts)
	local rows = {}

	for _, category in ipairs({ "lethal", "nonLethal" }) do
		local activeCount = (activeCategoryState.counts and activeCategoryState.counts[category]) or 0
		local requiredCount = requiredCounts[category] or 0
		if activeCount < requiredCount then
			local categoryRowIcons = {}
			for _, spell in ipairs(knownByCategory[category] or {}) do
				local isActiveByID = spell.spellID and activeCategoryState.spellIDs and activeCategoryState.spellIDs[category]
					and activeCategoryState.spellIDs[category][spell.spellID]
				local isActiveByName = type(spell.name) == "string" and spell.name ~= ""
					and activeCategoryState.names
					and activeCategoryState.names[category]
					and activeCategoryState.names[category][string.lower(spell.name)]
				if not isActiveByID and not isActiveByName then
					table.insert(categoryRowIcons, {
						spellID = spell.spellID,
						name = spell.name,
						icon = spell.icon,
					})
				end
			end

			if #categoryRowIcons > 0 then
				table.insert(rows, {
					category = category,
					icons = categoryRowIcons,
				})
			end
		end
	end

	return rows
end

NoPoizen.Testables = NoPoizen.Testables or {}
NoPoizen.Testables.CalculateMissingCounts = CalculateMissingCounts
NoPoizen.Testables.ResolveRequiredCounts = ResolveRequiredCounts
NoPoizen.Testables.ShouldPlayAudio = ShouldPlayAudio
NoPoizen.Testables.ShouldPlaySatisfiedAudio = ShouldPlaySatisfiedAudio
NoPoizen.Testables.ResolveAudioArmingState = ResolveAudioArmingState
NoPoizen.Testables.BuildIndicatorRows = BuildIndicatorRows

function NoPoizen:HasDragonTemperedBladesSelected()
	return IsSpellKnownSafe(self.DRAGON_TEMPERED_BLADES_SPELL_ID)
end

function NoPoizen:BuildKnownPoisonSpellsByCategory()
	local knownByCategory = {
		lethal = {},
		nonLethal = {},
	}

	for category, spells in pairs(self.poisonCatalog) do
		for _, spell in ipairs(spells) do
			if IsSpellKnownSafe(spell.spellID) then
				table.insert(knownByCategory[category], {
					spellID = spell.spellID,
					name = GetSpellNameSafe(spell.spellID) or spell.fallbackName,
					icon = GetSpellTextureSafe(spell.spellID),
				})
			end
		end
	end

	return knownByCategory
end

function NoPoizen:GetKnownPoisonSpellCount(knownByCategory)
	return #(knownByCategory.lethal or {}) + #(knownByCategory.nonLethal or {})
end

function NoPoizen:GetActivePoisonAuraState(knownByCategory)
	local activeCategoryState = {
		counts = {
			lethal = 0,
			nonLethal = 0,
		},
		spellIDs = {
			lethal = {},
			nonLethal = {},
		},
		names = {
			lethal = {},
			nonLethal = {},
		},
	}

	for category, spells in pairs(knownByCategory) do
		for _, spell in ipairs(spells) do
			if spell.spellID and HasHelpfulAuraBySpellID("player", spell.spellID) then
				activeCategoryState.counts[category] = (activeCategoryState.counts[category] or 0) + 1
				activeCategoryState.spellIDs[category][spell.spellID] = true
				if type(spell.name) == "string" and spell.name ~= "" then
					activeCategoryState.names[category][string.lower(spell.name)] = true
				end
			end
		end
	end

	return activeCategoryState
end

function NoPoizen:EvaluatePoisonState()
	local state = {
		eligible = false,
		knownPoisonCount = 0,
		requiredCounts = {
			lethal = 0,
			nonLethal = 0,
		},
		activeCounts = {
			lethal = 0,
			nonLethal = 0,
		},
		missingCounts = {
			lethal = 0,
			nonLethal = 0,
			total = 0,
		},
		indicatorRows = {},
		hasMissing = false,
		showIndicator = false,
	}

	if not self:IsPlayerRogue() then
		return state
	end

	local knownByCategory = self:BuildKnownPoisonSpellsByCategory()
	state.knownPoisonCount = self:GetKnownPoisonSpellCount(knownByCategory)
	if state.knownPoisonCount <= 0 then
		return state
	end

	state.eligible = true
	state.requiredCounts = ResolveRequiredCounts(self:HasDragonTemperedBladesSelected())
	local activeCategoryState = self:GetActivePoisonAuraState(knownByCategory)
	state.activeCounts = activeCategoryState.counts
	state.missingCounts = CalculateMissingCounts(state.requiredCounts, state.activeCounts)
	state.hasMissing = state.missingCounts.total > 0
	state.indicatorRows = BuildIndicatorRows(knownByCategory, activeCategoryState, state.requiredCounts)
	return state
end

function NoPoizen:RefreshPoisonState(_reason)
	if not self.isEnabled then
		return
	end

	local now = 0
	if self.API and self.API.GetTime then
		now = tonumber(self.API.GetTime()) or 0
	elseif GetTime then
		now = tonumber(GetTime()) or 0
	end

	if self.isLoadingScreenActive then
		return
	end
	local holdUntil = tonumber(self.postLoadRefreshAt) or 0
	if holdUntil > 0 then
		if now < holdUntil then
			return
		end
		self.postLoadRefreshAt = 0
	end

	local state = self:EvaluatePoisonState()
	local shouldShowVisual = state.eligible and state.hasMissing and (self:GetOption("showVisualIndicator") == true)
	state.showIndicator = shouldShowVisual
	self.currentPoisonState = state

	if self.UpdatePoisonIndicator then
		self:UpdatePoisonIndicator(state)
	end

	local previousMissingState = self.audioMissingState and true or false
	local currentMissingState = state.eligible and state.hasMissing
	local currentSatisfiedState = state.eligible and (not state.hasMissing)
	local nextArmedState, shouldSuppressPlayback = ResolveAudioArmingState(
		self.audioTransitionsArmed == true,
		self.audioTransitionsArmAt,
		now
	)
	self.audioTransitionsArmed = nextArmedState
	if shouldSuppressPlayback then
		self.audioMissingState = currentMissingState
		return
	end

	local shouldPlayMissing = ShouldPlayAudio(
		previousMissingState,
		currentMissingState,
		self:GetOption("playAudioIndicator") == true,
		self:GetOption("audioVolume")
	)
	if shouldPlayMissing then
		self:PlayMissingPoisonSound()
	end

	local shouldPlaySatisfied = ShouldPlaySatisfiedAudio(
		previousMissingState,
		currentSatisfiedState,
		self:GetOption("playSatisfiedAudioIndicator") == true,
		self:GetOption("satisfiedAudioVolume")
	)
	if shouldPlaySatisfied and self.PlaySatisfiedPoisonSound then
		self:PlaySatisfiedPoisonSound()
	end

	self.audioMissingState = currentMissingState
end
