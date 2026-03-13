local NoPoizen = _G.NoPoizen

if not NoPoizen then
	return
end

local function EnsurePoisonIndicatorSelection(hostFrame)
	if not hostFrame or hostFrame.Selection then
		return hostFrame and hostFrame.Selection or nil
	end
	if not EditModeManagerFrame then
		return nil
	end

	local ok, selection = pcall(CreateFrame, "Frame", nil, hostFrame, "EditModeSystemSelectionTemplate")
	if not ok or not selection then
		return nil
	end

	selection:SetAllPoints()
	selection:SetFrameLevel(hostFrame:GetFrameLevel() + 20)
	selection:EnableMouse(false)
	selection:Hide()
	if selection.SetSystem then
		selection:SetSystem({
			GetSystemName = function()
				return "NoPoizen"
			end,
		})
	elseif selection.SetGetLabelTextFunction then
		selection:SetGetLabelTextFunction(function()
			return "NoPoizen"
		end)
	end
	if selection.Label then
		selection.Label:Hide()
	end
	selection.UpdateLabelVisibility = function(frame)
		if frame.Label then
			frame.Label:Hide()
		end
		if frame.HorizontalLabel then
			frame.HorizontalLabel:Hide()
		end
		if frame.VerticalLabel then
			frame.VerticalLabel:Hide()
		end
	end

	hostFrame.Selection = selection
	return selection
end

local function SaveDialogPosition(dialog)
	if not dialog then
		return
	end
	local point, _, relativePoint, offsetX, offsetY = dialog:GetPoint(1)
	if not point or not relativePoint then
		return
	end
	dialog.qtUserPlaced = {
		point = point,
		relativePoint = relativePoint,
		x = offsetX,
		y = offsetY,
	}
end

local function GetDefaultDialogPoint()
	-- Keep settings dialog independent from widget scaling/position updates.
	return "CENTER", UIParent, "CENTER", 380, 0
end

local function GetPoisonIndicatorEditSession()
	return NoPoizen.poisonIndicatorEditSession
end

local function EnsurePoisonIndicatorEditSession()
	if NoPoizen.poisonIndicatorEditSession then
		return NoPoizen.poisonIndicatorEditSession
	end

	NoPoizen.poisonIndicatorEditSession = {
		saved = {
			widgetScale = NoPoizen:NormalizeWidgetScale(NoPoizen:GetOption("widgetScale")) or NoPoizen.DEFAULTS.widgetScale,
			anchor = NoPoizen:DeepCopy(NoPoizen:GetIndicatorAnchor()),
		},
		pending = false,
	}
	return NoPoizen.poisonIndicatorEditSession
end

local function SyncEditModeDirtyState()
	local session = GetPoisonIndicatorEditSession()
	local pending = session and session.pending or false
	if not EditModeManagerFrame then
		return
	end
	if pending then
		if EditModeManagerFrame.SetHasActiveChanges then
			EditModeManagerFrame:SetHasActiveChanges(true)
		end
	elseif EditModeManagerFrame.CheckForSystemActiveChanges then
		EditModeManagerFrame:CheckForSystemActiveChanges()
	end
end

local function IsSnapshotEqual(snapshot)
	if type(snapshot) ~= "table" then
		return true
	end
	local currentScale = NoPoizen:NormalizeWidgetScale(NoPoizen:GetOption("widgetScale")) or NoPoizen.DEFAULTS.widgetScale
	local currentAnchor = NoPoizen:GetIndicatorAnchor()
	local savedAnchor = snapshot.anchor or NoPoizen.DEFAULT_INDICATOR_ANCHOR
	return currentScale == snapshot.widgetScale
		and currentAnchor.point == savedAnchor.point
		and currentAnchor.relativePoint == savedAnchor.relativePoint
		and currentAnchor.x == savedAnchor.x
		and currentAnchor.y == savedAnchor.y
end

local function IsAtDefaultState()
	local defaults = NoPoizen.DEFAULTS
	local anchorDefaults = NoPoizen.DEFAULT_INDICATOR_ANCHOR
	local currentScale = NoPoizen:NormalizeWidgetScale(NoPoizen:GetOption("widgetScale")) or defaults.widgetScale
	local currentAnchor = NoPoizen:GetIndicatorAnchor()
	return currentScale == defaults.widgetScale
		and currentAnchor.point == anchorDefaults.point
		and currentAnchor.relativePoint == anchorDefaults.relativePoint
		and currentAnchor.x == anchorDefaults.x
		and currentAnchor.y == anchorDefaults.y
end

local function UpdateEditSessionPendingState()
	local session = EnsurePoisonIndicatorEditSession()
	session.pending = not IsSnapshotEqual(session.saved)
	if NoPoizen.poisonIndicatorEditDialog then
		if NoPoizen.poisonIndicatorEditDialog.RevertButton then
			NoPoizen.poisonIndicatorEditDialog.RevertButton:SetEnabled(session.pending)
		end
		if NoPoizen.poisonIndicatorEditDialog.ResetButton then
			NoPoizen.poisonIndicatorEditDialog.ResetButton:SetEnabled(not IsAtDefaultState())
		end
	end
	SyncEditModeDirtyState()
end

local function EnsurePoisonIndicatorEditDialog()
	if NoPoizen.poisonIndicatorEditDialog then
		return NoPoizen.poisonIndicatorEditDialog
	end
	if not EditModeManagerFrame then
		return nil
	end

	local dialog = CreateFrame("Frame", "NoPoizenIndicatorSettingsDialog", UIParent)
	dialog:SetSize(320, 168)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetFrameLevel(250)
	dialog:SetMovable(true)
	dialog:SetClampedToScreen(true)
	dialog:EnableMouse(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:Hide()

	local border = CreateFrame("Frame", nil, dialog, "DialogBorderTranslucentTemplate")
	border:SetAllPoints()
	dialog.Border = border

	local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	title:SetPoint("TOP", dialog, "TOP", 0, -15)
	title:SetText("NoPoizen Indicator")
	dialog.Title = title

	local closeButton = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT")
	closeButton:SetScript("OnClick", function()
		NoPoizen:DeselectPoisonIndicatorAnchor()
	end)
	dialog.CloseButton = closeButton

	local dragHandle = CreateFrame("Frame", nil, dialog)
	dragHandle:SetPoint("TOPLEFT", dialog, "TOPLEFT", 8, -8)
	dragHandle:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -4, -8)
	dragHandle:SetHeight(28)
	dragHandle:EnableMouse(true)
	dragHandle:RegisterForDrag("LeftButton")
	dragHandle:SetScript("OnDragStart", function()
		dialog:StartMoving()
	end)
	dragHandle:SetScript("OnDragStop", function()
		dialog:StopMovingOrSizing()
		SaveDialogPosition(dialog)
	end)
	dialog.DragHandle = dragHandle

	local slider = CreateFrame("Slider", nil, dialog, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -62)
	slider:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -24, -62)
	slider:SetMinMaxValues(NoPoizen.WIDGET_SCALE_MIN, NoPoizen.WIDGET_SCALE_MAX)
	slider:SetValueStep(NoPoizen.WIDGET_SCALE_STEP)
	if slider.SetObeyStepOnDrag then
		slider:SetObeyStepOnDrag(true)
	end
	if slider.Text then
		slider.Text:SetText("Indicator Scale")
	end
	if slider.Low then
		slider.Low:SetText(string.format("%.1fx", NoPoizen.WIDGET_SCALE_MIN))
	end
	if slider.High then
		slider.High:SetText(string.format("%.1fx", NoPoizen.WIDGET_SCALE_MAX))
	end

	local sliderValue = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	sliderValue:SetPoint("TOP", slider, "BOTTOM", 0, -4)
	sliderValue:SetText("")
	dialog.ScaleValueText = sliderValue
	dialog.ScaleSlider = slider

	slider:SetScript("OnValueChanged", function(_, value)
		local normalized = NoPoizen:NormalizeWidgetScale(value) or NoPoizen.DEFAULTS.widgetScale
		dialog.ScaleValueText:SetText(string.format("%.2fx", normalized))
		if dialog.qtUpdatingSlider then
			return
		end
		if NoPoizen:SetOption("widgetScale", normalized) and not NoPoizen.poisonIndicatorEditSessionRestoring then
			UpdateEditSessionPendingState()
			NoPoizen:AttachPoisonIndicatorEditDialog()
		end
	end)

	local revertButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	revertButton:SetSize(128, 24)
	revertButton:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 24, 18)
	revertButton:SetText("Revert Changes")
	revertButton:SetScript("OnClick", function()
		NoPoizen:RevertPoisonIndicatorEditSession()
	end)
	dialog.RevertButton = revertButton

	local resetButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	resetButton:SetSize(128, 24)
	resetButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -24, 18)
	resetButton:SetText("Reset To Default")
	resetButton:SetScript("OnClick", function()
		NoPoizen:ResetPoisonIndicatorEditSessionToDefaults()
	end)
	dialog.ResetButton = resetButton

	dialog:SetScript("OnDragStart", function(frame)
		frame:StartMoving()
	end)
	dialog:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		SaveDialogPosition(frame)
	end)
	dialog:SetScript("OnHide", function(frame)
		frame:StopMovingOrSizing()
	end)
	dialog:SetScript("OnKeyDown", function(_, key)
		if key == "ESCAPE" then
			NoPoizen:DeselectPoisonIndicatorAnchor()
		end
	end)

	NoPoizen.poisonIndicatorEditDialog = dialog
	return dialog
end

local function GetDefaultEditModeRows()
	local rows = {}
	local poisonCatalog = NoPoizen.poisonCatalog or {}

	for _, category in ipairs({ "lethal", "nonLethal" }) do
		local row = {
			category = category,
			icons = {},
		}
		for _, spell in ipairs(poisonCatalog[category] or {}) do
			table.insert(row.icons, {
				category = category,
				spellID = spell.spellID,
				name = spell.fallbackName,
				icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell.spellID))
					or (GetSpellTexture and GetSpellTexture(spell.spellID))
					or 134400,
			})
		end
		if #row.icons > 0 then
			table.insert(rows, row)
		end
	end
	return rows
end

local function GetCategoryLabel(category)
	if category == "lethal" then
		return "Lethal Poisons"
	end
	if category == "nonLethal" then
		return "Non-Lethal Poisons"
	end
	return tostring(category)
end

local function LayoutIndicatorRows(hostFrame, indicatorRows)
	hostFrame.iconTextures = hostFrame.iconTextures or {}
	hostFrame.rowLabels = hostFrame.rowLabels or {}

	local iconSize = 40
	local columnSpacing = 6
	local rowSpacing = 10
	local paddingX = 12
	local paddingY = 10
	local labelGap = 2
	local textureIndex = 0
	local maxColumns = 0

	for _, row in ipairs(indicatorRows) do
		maxColumns = math.max(maxColumns, #(row.icons or {}))
	end

	local width = math.max(1, (maxColumns * iconSize) + (math.max(0, maxColumns - 1) * columnSpacing) + (paddingX * 2))
	local cursorY = paddingY

	for rowIndex, row in ipairs(indicatorRows) do
		if not hostFrame.rowLabels[rowIndex] then
			hostFrame.rowLabels[rowIndex] = hostFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		end
		local rowLabel = hostFrame.rowLabels[rowIndex]
		rowLabel:ClearAllPoints()
		rowLabel:SetPoint("TOP", hostFrame, "TOP", 0, -cursorY)
		rowLabel:SetText(GetCategoryLabel(row.category))
		rowLabel:Show()

		local labelHeight = rowLabel:GetStringHeight() or 12
		cursorY = cursorY + labelHeight + labelGap

		local rowIconCount = #(row.icons or {})
		local rowWidth = (rowIconCount * iconSize) + (math.max(0, rowIconCount - 1) * columnSpacing)
		local rowStartX = (width - rowWidth) / 2

		for columnIndex, iconData in ipairs(row.icons or {}) do
			textureIndex = textureIndex + 1
			if not hostFrame.iconTextures[textureIndex] then
				hostFrame.iconTextures[textureIndex] = hostFrame:CreateTexture(nil, "ARTWORK")
			end

			local texture = hostFrame.iconTextures[textureIndex]
			texture:SetTexture(iconData.icon or 134400)
			texture:SetSize(iconSize, iconSize)
			texture:ClearAllPoints()
			texture:SetPoint(
				"TOPLEFT",
				hostFrame,
				"TOPLEFT",
				rowStartX + ((columnIndex - 1) * (iconSize + columnSpacing)),
				-cursorY
			)
			texture:Show()
		end

		cursorY = cursorY + iconSize
		if rowIndex < #indicatorRows then
			cursorY = cursorY + rowSpacing
		end
	end

	for index = textureIndex + 1, #hostFrame.iconTextures do
		if hostFrame.iconTextures[index] then
			hostFrame.iconTextures[index]:Hide()
		end
	end

	for index = #indicatorRows + 1, #hostFrame.rowLabels do
		if hostFrame.rowLabels[index] then
			hostFrame.rowLabels[index]:Hide()
		end
	end

	local rowCount = #indicatorRows
	local height = rowCount > 0 and (cursorY + paddingY) or 1
	hostFrame:SetSize(width, height)
end

function NoPoizen:IsPoisonIndicatorInEditMode()
	return self.isEnabled and EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

function NoPoizen:ApplySavedIndicatorAnchor()
	local hostFrame = self.poisonIndicatorHostFrame
	if not hostFrame then
		return
	end
	local anchor = self:GetIndicatorAnchor()
	hostFrame:ClearAllPoints()
	hostFrame:SetPoint(anchor.point, hostFrame:GetParent() or UIParent, anchor.relativePoint, anchor.x, anchor.y)
	if self.poisonIndicatorEditDialog and self.poisonIndicatorEditDialog:IsShown() then
		self:AttachPoisonIndicatorEditDialog()
	end
end

function NoPoizen:SaveIndicatorAnchorFromFrame(hostFrame)
	if not hostFrame then
		return false
	end
	local point, _, relativePoint, x, y = hostFrame:GetPoint(1)
	if not point or not relativePoint then
		return false
	end
	local changed = self:SetIndicatorAnchor(point, relativePoint, x, y)
	if changed and self:IsPoisonIndicatorInEditMode() and not self.poisonIndicatorEditSessionRestoring then
		UpdateEditSessionPendingState()
		self:RefreshPoisonIndicatorEditDialog()
	end
	return changed
end

function NoPoizen:EnsurePoisonIndicatorWidget()
	if self.poisonIndicatorHostFrame then
		return self.poisonIndicatorHostFrame
	end

	local parentFrame = UIParent or (C_UI and C_UI.GetUIParent and C_UI.GetUIParent()) or nil
	if not parentFrame then
		return nil
	end

	local hostFrame = CreateFrame("Frame", "NoPoizenIndicatorAnchor", parentFrame)
	hostFrame:SetSize(1, 1)
	hostFrame:SetFrameStrata("MEDIUM")
	hostFrame:SetFrameLevel(parentFrame:GetFrameLevel() + 1)
	hostFrame:SetClampedToScreen(true)
	hostFrame:SetMovable(true)
	hostFrame:RegisterForDrag("LeftButton")
	hostFrame:EnableMouse(false)

	local background = hostFrame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.03, 0.03, 0.03, 0.7)
	background:Hide()
	hostFrame.EditBackground = background

	local border = hostFrame:CreateTexture(nil, "BORDER")
	border:SetAllPoints()
	border:SetColorTexture(0.8, 0.2, 0.2, 0.4)
	border:Hide()
	hostFrame.EditBorder = border

	local label = hostFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("BOTTOM", hostFrame, "TOP", 0, 6)
	label:SetText("NoPoizen")
	label:Hide()
	hostFrame.EditLabel = label

	hostFrame:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" then
			return
		end
		NoPoizen:SelectPoisonIndicatorAnchor()
	end)
	hostFrame:SetScript("OnDragStart", function(frame)
		if not NoPoizen:IsPoisonIndicatorInEditMode() then
			return
		end
		NoPoizen:SelectPoisonIndicatorAnchor()
		frame:StartMoving()
	end)
	hostFrame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		NoPoizen:SaveIndicatorAnchorFromFrame(frame)
		NoPoizen:AttachPoisonIndicatorEditDialog()
	end)

	self.poisonIndicatorHostFrame = hostFrame
	self:ApplySavedIndicatorAnchor()
	self:RefreshPoisonIndicatorVisualState()
	return hostFrame
end

function NoPoizen:ApplyPoisonIndicatorEditSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	self.poisonIndicatorEditSessionRestoring = true
	if snapshot.widgetScale then
		self:SetOption("widgetScale", snapshot.widgetScale)
	end
	if snapshot.anchor then
		self:SetIndicatorAnchor(snapshot.anchor.point, snapshot.anchor.relativePoint, snapshot.anchor.x, snapshot.anchor.y)
	end
	self.poisonIndicatorEditSessionRestoring = false

	self:RefreshPoisonIndicatorVisualState()
	self:AttachPoisonIndicatorEditDialog()
	self:RefreshPoisonIndicatorEditDialog()
end

function NoPoizen:CommitPoisonIndicatorEditSession()
	self.poisonIndicatorEditSession = nil
	self.poisonIndicatorEditSessionRestoring = false
	SyncEditModeDirtyState()
	if self.poisonIndicatorEditDialog and self.poisonIndicatorEditDialog.RevertButton then
		self.poisonIndicatorEditDialog.RevertButton:SetEnabled(false)
	end
end

function NoPoizen:RevertPoisonIndicatorEditSession()
	local session = GetPoisonIndicatorEditSession()
	if not session then
		return
	end
	self:ApplyPoisonIndicatorEditSnapshot(session.saved)
	session.pending = false
	SyncEditModeDirtyState()
	if self.poisonIndicatorEditDialog and self.poisonIndicatorEditDialog.RevertButton then
		self.poisonIndicatorEditDialog.RevertButton:SetEnabled(false)
	end
end

function NoPoizen:ResetPoisonIndicatorEditSessionToDefaults()
	self.poisonIndicatorEditSessionRestoring = true
	self:SetOption("widgetScale", self.DEFAULTS.widgetScale)
	self:ResetIndicatorAnchor()
	self.poisonIndicatorEditSessionRestoring = false
	UpdateEditSessionPendingState()
	self:RefreshPoisonIndicatorVisualState()
	self:AttachPoisonIndicatorEditDialog()
	self:RefreshPoisonIndicatorEditDialog()
end

function NoPoizen:AttachPoisonIndicatorEditDialog()
	local dialog = self.poisonIndicatorEditDialog
	if not dialog then
		return
	end

	if dialog.qtUserPlaced then
		dialog:ClearAllPoints()
		dialog:SetPoint(
			dialog.qtUserPlaced.point,
			UIParent,
			dialog.qtUserPlaced.relativePoint,
			dialog.qtUserPlaced.x,
			dialog.qtUserPlaced.y
		)
		return
	end

	local point, relativeTo, relativePoint, offsetX, offsetY = GetDefaultDialogPoint()
	dialog:ClearAllPoints()
	dialog:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
end

function NoPoizen:RefreshPoisonIndicatorEditDialog()
	local dialog = EnsurePoisonIndicatorEditDialog()
	if not dialog then
		return
	end
	local session = GetPoisonIndicatorEditSession()

	local currentScale = self:NormalizeWidgetScale(self:GetOption("widgetScale")) or self.DEFAULTS.widgetScale
	dialog.qtUpdatingSlider = true
	dialog.ScaleSlider:SetValue(currentScale)
	dialog.ScaleValueText:SetText(string.format("%.2fx", currentScale))
	dialog.qtUpdatingSlider = false

	if dialog.RevertButton then
		dialog.RevertButton:SetEnabled(session and session.pending or false)
	end
	if dialog.ResetButton then
		dialog.ResetButton:SetEnabled(not IsAtDefaultState())
	end
end

function NoPoizen:SelectPoisonIndicatorAnchor()
	if not self:IsPoisonIndicatorInEditMode() then
		return
	end

	EnsurePoisonIndicatorEditSession()
	self.poisonIndicatorAnchorSelected = true
	self:RefreshPoisonIndicatorVisualState()
	self:AttachPoisonIndicatorEditDialog()
	self:RefreshPoisonIndicatorEditDialog()

	local dialog = EnsurePoisonIndicatorEditDialog()
	if dialog then
		dialog:Show()
	end
end

function NoPoizen:DeselectPoisonIndicatorAnchor()
	self.poisonIndicatorAnchorSelected = false
	if self.poisonIndicatorEditDialog then
		self.poisonIndicatorEditDialog:Hide()
	end
	self:RefreshPoisonIndicatorVisualState()
end

function NoPoizen:RefreshPoisonIndicatorVisualState()
	local hostFrame = self:EnsurePoisonIndicatorWidget()
	if not hostFrame then
		return
	end

	EnsurePoisonIndicatorSelection(hostFrame)
	local editModeActive = self:IsPoisonIndicatorInEditMode()
	local state = self.currentPoisonState or {}
	local shouldShowRuntime = self.isEnabled and state.showIndicator
	local indicatorRows = state.indicatorRows or {}

	if editModeActive and #indicatorRows == 0 then
		indicatorRows = GetDefaultEditModeRows()
	end

	local shouldShow = editModeActive or shouldShowRuntime
	if shouldShow and #indicatorRows == 0 then
		shouldShow = false
	end

	if shouldShow then
		LayoutIndicatorRows(hostFrame, indicatorRows)
		hostFrame:SetScale(self:NormalizeWidgetScale(self:GetOption("widgetScale")) or self.DEFAULTS.widgetScale)
		hostFrame:Show()
	else
		hostFrame:Hide()
	end

	hostFrame:EnableMouse(editModeActive)
	if hostFrame.EditBackground then
		hostFrame.EditBackground:SetShown(editModeActive and shouldShow)
	end
	if hostFrame.EditBorder then
		hostFrame.EditBorder:SetShown(editModeActive and shouldShow)
	end
	if hostFrame.EditLabel then
		hostFrame.EditLabel:SetShown(editModeActive and shouldShow)
	end

	if hostFrame.Selection then
		if editModeActive and shouldShow then
			if self.poisonIndicatorAnchorSelected then
				hostFrame.Selection:ShowSelected()
			else
				hostFrame.Selection:ShowHighlighted()
			end
		else
			hostFrame.Selection:Hide()
		end
	end

	if not editModeActive then
		self.poisonIndicatorAnchorSelected = false
		if self.poisonIndicatorEditDialog then
			self.poisonIndicatorEditDialog:Hide()
		end
	end
end

function NoPoizen:UpdatePoisonIndicator(state)
	self.currentPoisonState = state
	self:RefreshPoisonIndicatorVisualState()
end

function NoPoizen:TryInstallPoisonIndicatorEditModeHooks()
	if self.poisonIndicatorEditModeHooksInstalled then
		return
	end
	if not EditModeManagerFrame or not EditModeManagerFrame.HookScript then
		return
	end

	self:EnsurePoisonIndicatorWidget()
	EnsurePoisonIndicatorEditDialog()

	EditModeManagerFrame:HookScript("OnShow", function()
		EnsurePoisonIndicatorEditSession()
		NoPoizen:RefreshPoisonIndicatorVisualState()
		NoPoizen:RefreshPoisonIndicatorEditDialog()
	end)
	EditModeManagerFrame:HookScript("OnHide", function()
		NoPoizen:DeselectPoisonIndicatorAnchor()
	end)

	hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(_, systemFrame)
		local hostFrame = NoPoizen.poisonIndicatorHostFrame
		if hostFrame and systemFrame ~= hostFrame then
			NoPoizen:DeselectPoisonIndicatorAnchor()
		end
	end)
	hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
		NoPoizen:DeselectPoisonIndicatorAnchor()
	end)
	hooksecurefunc(EditModeManagerFrame, "SaveLayouts", function()
		NoPoizen:CommitPoisonIndicatorEditSession()
	end)
	hooksecurefunc(EditModeManagerFrame, "RevertAllChanges", function()
		NoPoizen:RevertPoisonIndicatorEditSession()
	end)
	if EditModeManagerFrame.RevertAllChangesButton and EditModeManagerFrame.RevertAllChangesButton.HookScript then
		EditModeManagerFrame.RevertAllChangesButton:HookScript("OnClick", function()
			NoPoizen:RevertPoisonIndicatorEditSession()
		end)
	end

	self.poisonIndicatorEditModeHooksInstalled = true
end
