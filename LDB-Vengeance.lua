--[[
	Credits
	To Dridzt for Vengeance Status – which gave me an initial idea how I could detect the vengeance buff, and how to check for the value
	To Shackleford for LDB-Threat – I had no clue how to write a data source
]]--

local addonName, ns = ...
local addon = CreateFrame("Frame", addonName)
local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale(addonName)

local addonversion ="@project-version@"

local DBversion = "2"

local defaultText = "|cffC79C6ELDB|r-Vengeance"
local defaultIcon = "Interface\\Icons\\Ability_Paladin_ShieldofVengeance"

local LDBVengeance = LibStub("LibDataBroker-1.1"):NewDataObject(
	addonName, 
	{ 
		icon = defaultIcon, 
		type = "data source",
		text = defaultText
	}
)

local isTank = false
local playerClass = select(2, UnitClass("player"))
local vengeanceSpellName = GetSpellInfo(93098)	-- known Vengeance spell ID

local GetSpellBookItemInfo, UnitAura = GetSpellBookItemInfo, UnitAura

-- Table of classes with a tanking specialization.
local tankClass = {
	DEATHKNIGHT = true,
	DRUID = true,
	MONK = true,
	PALADIN = true,
	WARRIOR = true,
}

-- Set the LDB display values.
function addon:SetLDBDisplay(text, icon)
	LDBVengeance.text = text
	LDBVengeance.icon = icon

	local value = tonumber(text) or 0
	if LDBVengeanceDB.provideValue then
		LDBVengeance.value = value
	else
		LDBVengeance.value = false
	end
end

function addon:UpdateTankStatus()
	-- Player is considered to be in a tanking specialization if the passive spell
	-- "Vengeance" is present in the player's spellbook.
	local spellId = select(2, GetSpellBookItemInfo(vengeanceSpellName))
	if spellId then
		isTank = true
		self:RegisterEvent('UNIT_AURA')
	else
		isTank = false		
		self:UnregisterEvent('UNIT_AURA')
	end
end

function addon:GetVengeance()
	local _, _, icon, _, _, _, _, _, _, _, _, _, _, value = UnitAura("player", vengeanceSpellName)

	icon = icon or LDBVengeance.icon or defaultIcon
	value = value or 0

	return value, icon
end

function addon:UNIT_AURA(event, unit)
	if unit == "player" and isTank then
		self:SetLDBDisplay(self:GetVengeance())
	end
end

function addon:ACTIVE_TALENT_GROUP_CHANGED()
	self:UpdateTankStatus()
	self:SetLDBDisplay(self:GetVengeance())
end

function addon:UpgradeSavedVariables()
	-- Upgrade saved variables if necessary.
	if (not LDBVengeanceDB or not LDBVengeanceDB.dbVersion or LDBVengeanceDB.dbVersion < DBversion) then
		LDBVengeanceDB = LDBVengeanceDB or {}
		LDBVengeanceDB.dbVersion = DBversion
		LDBVengeanceDB.defaultText = LDBVengeanceDB.defaultText or defaultText
		LDBVengeanceDB.provideValue = LDBVengeanceDB.provideValue or 1
	end
end

function addon:PLAYER_LOGIN()
	-- At this point, the saved variables are loaded.
	self:UpgradeSavedVariables()

	-- Set the default LDB display values when entering the world.
	self:SetLDBDisplay(LDBVengeanceDB.defaultText, defaultIcon)

	if tankClass[playerClass] then
		self:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
		self:UpdateTankStatus()
		self:SetLDBDisplay(self:GetVengeance())
	end
end

function addon:ADDON_LOADED(event, name)
	if name == addonName then
		-- Unregister ADDON_LOADED event so that this handler only runs once.
		self:UnregisterEvent(event)
		self:PLAYER_LOGIN(event)
	end
end

function LDBVengeance:OnTooltipShow()
	self:AddLine(defaultText.." |cff00ff00"..addonversion.."|r")
	self:AddLine("|cffffffff"..L['Displays the current value of your vengeance buff'].."|r")
	if not tankClass[playerClass] then
		self:AddLine("|cffff0000"..L['Note: This addon does not make any sense for classes that don\'t have a Vengeance buff'].."|r")
	end
end

function LDBVengeance:OnClick(msg)
	if msg == "RightButton" then
		InterfaceOptionsFrame_OpenToCategory(addon.optionsFrame)
	end
end

local options = {
	type ="group",
	name = defaultText,
	handler = LDBVengeance,
	childGroups = "tree",
	args = {
		header1 = {
			type = "description",
			name = L["Some useful description"],
			order = 0,
			width = "full",
			cmdHidden = true
		},
		spacer1 = {
			type = "header",
			name = "",
			order = 1,
			width = "full",
			cmdHidden = true
		},
		provideValue = {
			type = "toggle",
			name = L["Provide a 'value' for the LDB display"],
			width = "full",
			order = 2,
			set = function (info, value)
				LDBVengeanceDB.provideValue = value
			end,
			get = function() return LDBVengeanceDB.provideValue end
		},
		defaultText = {
			type = "input",
			name = L["Default data source text"],
			width = "double",
			order = 3,
			set = function (info,value)
				LDBVengeanceDB.defaultText = value
			end,
			get = function() return LDBVengeanceDB.defaultText end
		},
		resetToDefaultText = {
			type = "execute",
			name = L["Reset"],
			desc = L["Reset default text (|cffC79C6ELDB|r-Vengeance)"],
			order = 4,
			func = function() LDBVengeanceDB.defaultText = defaultText end,
		},
	},
}

LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options)
addon.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName)

local function EventHandler(self, event, ...)
	if self[event] then
		self[event](self, event, ...)
	end
end

addon:RegisterEvent(IsAddOnLoaded('AddonLoader') and 'ADDON_LOADED' or 'PLAYER_LOGIN')
addon:SetScript('OnEvent', EventHandler)
