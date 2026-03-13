local NoPoizen = _G.NoPoizen

if not NoPoizen then
	return
end

NoPoizen.tests = NoPoizen.tests or {}

local function Fail(message)
	error(message or "test failed", 2)
end

local function AssertEquals(actual, expected, context)
	if actual ~= expected then
		Fail(string.format("%s (expected=%s actual=%s)", context or "assert", tostring(expected), tostring(actual)))
	end
end

local function AssertTrue(value, context)
	if not value then
		Fail((context or "assert") .. " (expected true)")
	end
end

local function FindRowByCategory(rows, category)
	for _, row in ipairs(rows or {}) do
		if row.category == category then
			return row
		end
	end
	return nil
end

function NoPoizen:RegisterTest(name, fn)
	if type(name) ~= "string" or name == "" or type(fn) ~= "function" then
		return false
	end
	self.tests[name] = fn
	return true
end

function NoPoizen:RunTests()
	local names = {}
	for name in pairs(self.tests) do
		table.insert(names, name)
	end
	table.sort(names)

	local passed = 0
	local failed = 0
	for _, name in ipairs(names) do
		local ok, err = pcall(self.tests[name])
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			self:Print("Test failed: " .. tostring(name) .. " -> " .. tostring(err))
		end
	end

	self:Print(string.format("Tests complete: %d passed, %d failed", passed, failed))
	return failed == 0
end

NoPoizen:RegisterTest("required counts baseline", function()
	local counts = NoPoizen.Testables.ResolveRequiredCounts(false)
	AssertEquals(counts.lethal, 1, "baseline lethal required")
	AssertEquals(counts.nonLethal, 1, "baseline nonLethal required")
end)

NoPoizen:RegisterTest("required counts dragon tempered blades", function()
	local counts = NoPoizen.Testables.ResolveRequiredCounts(true)
	AssertEquals(counts.lethal, 2, "dtb lethal required")
	AssertEquals(counts.nonLethal, 2, "dtb nonLethal required")
end)

NoPoizen:RegisterTest("missing counts computed from active and required", function()
	local missing = NoPoizen.Testables.CalculateMissingCounts({
		lethal = 2,
		nonLethal = 1,
	}, {
		lethal = 1,
		nonLethal = 1,
	})
	AssertEquals(missing.lethal, 1, "missing lethal")
	AssertEquals(missing.nonLethal, 0, "missing nonLethal")
	AssertEquals(missing.total, 1, "missing total")
end)

NoPoizen:RegisterTest("audio does not play when disabled", function()
	local shouldPlay = NoPoizen.Testables.ShouldPlayAudio(false, true, false, 1.0)
	AssertEquals(shouldPlay, false, "audio disabled should not play")
end)

NoPoizen:RegisterTest("audio does not play when volume is zero", function()
	local shouldPlay = NoPoizen.Testables.ShouldPlayAudio(false, true, true, 0)
	AssertEquals(shouldPlay, false, "zero volume should not play")
end)

NoPoizen:RegisterTest("audio plays only on missing state transition", function()
	local first = NoPoizen.Testables.ShouldPlayAudio(false, true, true, 1.0)
	local second = NoPoizen.Testables.ShouldPlayAudio(true, true, true, 1.0)
	local recovered = NoPoizen.Testables.ShouldPlayAudio(true, false, true, 1.0)
	AssertTrue(first == true, "first transition should play")
	AssertTrue(second == false, "steady missing should not play")
	AssertTrue(recovered == false, "resolved state should not play")
end)

NoPoizen:RegisterTest("indicator rows include both categories when both are missing", function()
	local rows = NoPoizen.Testables.BuildIndicatorRows(
		{
			lethal = {
				{ spellID = 1, name = "L1", icon = 1 },
				{ spellID = 2, name = "L2", icon = 2 },
			},
			nonLethal = {
				{ spellID = 3, name = "N1", icon = 3 },
				{ spellID = 4, name = "N2", icon = 4 },
			},
		},
		{
			counts = { lethal = 0, nonLethal = 0 },
			spellIDs = { lethal = {}, nonLethal = {} },
			names = { lethal = {}, nonLethal = {} },
		},
		{ lethal = 1, nonLethal = 1 }
	)

	AssertEquals(#rows, 2, "should contain two rows")
	AssertEquals(rows[1].category, "lethal", "first row should be lethal")
	AssertEquals(rows[2].category, "nonLethal", "second row should be nonLethal")
	AssertEquals(#rows[1].icons, 2, "lethal icons")
	AssertEquals(#rows[2].icons, 2, "nonLethal icons")
end)

NoPoizen:RegisterTest("row disappears when category is fully applied", function()
	local rows = NoPoizen.Testables.BuildIndicatorRows(
		{
			lethal = {
				{ spellID = 1, name = "L1", icon = 1 },
			},
			nonLethal = {
				{ spellID = 2, name = "N1", icon = 2 },
				{ spellID = 3, name = "N2", icon = 3 },
			},
		},
		{
			counts = { lethal = 1, nonLethal = 0 },
			spellIDs = { lethal = { [1] = true }, nonLethal = {} },
			names = { lethal = { l1 = true }, nonLethal = {} },
		},
		{ lethal = 1, nonLethal = 1 }
	)

	AssertEquals(#rows, 1, "only one row should remain")
	AssertEquals(rows[1].category, "nonLethal", "remaining row should be nonLethal")
end)

NoPoizen:RegisterTest("active poison icon is removed from category row", function()
	local rows = NoPoizen.Testables.BuildIndicatorRows(
		{
			lethal = {
				{ spellID = 1, name = "L1", icon = 1 },
				{ spellID = 2, name = "L2", icon = 2 },
				{ spellID = 3, name = "L3", icon = 3 },
			},
			nonLethal = {
				{ spellID = 9, name = "N1", icon = 9 },
			},
		},
		{
			counts = { lethal = 1, nonLethal = 0 },
			spellIDs = { lethal = { [2] = true }, nonLethal = {} },
			names = { lethal = { l2 = true }, nonLethal = {} },
		},
		{ lethal = 2, nonLethal = 1 }
	)

	local lethalRow = FindRowByCategory(rows, "lethal")
	AssertTrue(lethalRow ~= nil, "lethal row should exist")
	AssertEquals(#lethalRow.icons, 2, "active lethal icon should be removed")
	AssertEquals(lethalRow.icons[1].spellID, 1, "first lethal icon")
	AssertEquals(lethalRow.icons[2].spellID, 3, "second lethal icon")
end)
