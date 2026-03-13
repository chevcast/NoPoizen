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

local function BuildCategoryLookups(knownByCategory)
	local lookups = {
		ids = {},
		names = {},
	}
	for category, spells in pairs(knownByCategory) do
		for _, spell in ipairs(spells) do
			if spell.spellID then
				lookups.ids[spell.spellID] = category
			end
			if type(spell.name) == "string" and spell.name ~= "" then
				lookups.names[string.lower(spell.name)] = category
			end
		end
	end
	return lookups
end

local function BuildFallbackCategoryLookups(catalog)
	local lookups = {
		ids = {},
		names = {},
	}
	for category, spells in pairs(catalog) do
		for _, spell in ipairs(spells) do
			if spell.spellID then
				lookups.ids[spell.spellID] = category
			end
			local spellName = GetSpellNameSafe(spell.spellID) or spell.fallbackName
			if type(spellName) == "string" and spellName ~= "" then
				lookups.names[string.lower(spellName)] = category
			end
		end
	end
	return lookups
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

	local lookup = BuildCategoryLookups(knownByCategory)
	local fallbackLookup = BuildFallbackCategoryLookups(self.poisonCatalog)
	local seenAuraBySpellID = {}

	self:ForEachHelpfulAura("player", function(spellID, auraName)
		local category = nil
		if spellID and lookup.ids[spellID] then
			category = lookup.ids[spellID]
		elseif spellID and fallbackLookup.ids[spellID] then
			category = fallbackLookup.ids[spellID]
		elseif type(auraName) == "string" and auraName ~= "" then
			local key = string.lower(auraName)
			category = lookup.names[key] or fallbackLookup.names[key]
		end

		if not category then
			return
		end

		local dedupeKey = spellID or ("name:" .. tostring(auraName))
		if seenAuraBySpellID[dedupeKey] then
			return
		end
		seenAuraBySpellID[dedupeKey] = true
		activeCategoryState.counts[category] = (activeCategoryState.counts[category] or 0) + 1
		if spellID then
			activeCategoryState.spellIDs[category][spellID] = true
		end
		if type(auraName) == "string" and auraName ~= "" then
			activeCategoryState.names[category][string.lower(auraName)] = true
		end
	end)

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

	local state = self:EvaluatePoisonState()
	local shouldShowVisual = state.eligible and state.hasMissing and (self:GetOption("showVisualIndicator") == true)
	state.showIndicator = shouldShowVisual
	self.currentPoisonState = state

	if self.UpdatePoisonIndicator then
		self:UpdatePoisonIndicator(state)
	end

	local currentMissingState = state.eligible and state.hasMissing
	local shouldPlay = ShouldPlayAudio(
		self.audioMissingState,
		currentMissingState,
		self:GetOption("playAudioIndicator") == true,
		self:GetOption("audioVolume")
	)
	if shouldPlay then
		self:PlayMissingPoisonSound()
	end
	self.audioMissingState = currentMissingState
end
