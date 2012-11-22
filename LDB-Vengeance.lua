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

addon.ScanTip = CreateFrame("GameTooltip","LDBVengeanceScanTip",nil,"GameTooltipTemplate")
addon.ScanTip:SetOwner(UIParent, "ANCHOR_NONE")

local playerClass = nil
local KNOWN_VENGEANCE_SPELL_ID = 93098
local BEAR_FORM = BEAR_FORM
local HEALTH_PER_STAMINA = HEALTH_PER_STAMINA

local vengeanceSpellName = nil
local vengeanceSpellIcon = nil
local vengeanceSpellId = nil

local function setDefaultVengeanceIcon()
	LDBVengeance.icon = defaultIcon
end

local function InitVengeanceData()
	vengeanceSpellIcon = select(3,GetSpellInfo(vengeanceSpellName))
	setDefaultVengeanceIcon()
end

function addon:checkIsTank()
	vengeanceSpellName = select(1,GetSpellInfo(KNOWN_VENGEANCE_SPELL_ID))
	local skillType, spellId = GetSpellBookItemInfo(vengeanceSpellName)
	if spellId ~= nil then
		vengeanceSpellId = spellId
		isTank = true
		self:RegisterEvent('UNIT_AURA')
		if playerClass == "DRUID" then -- for really checking those feral druids
			self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
		end
		InitVengeanceData()
	else 
		isTank = false		
		self:UnregisterEvent('UNIT_AURA')
		if playerClass == "DRUID" then -- for really checking those feral druids
			self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM")
		end
	end
end

--[[ Copy from Vengeance Status ]]--
local function getTooltipText(...)
	local text = ""
	for i=1,select("#",...) do
		local rgn = select(i,...)
		if rgn and rgn:GetObjectType() == "FontString" then
			text = text .. (rgn:GetText() or "")
		end
	end
	return text == "" and "0" or text
end

local function GetVengeanceValue()
	local n,_,icon,_,_,_,_,_,_,_,_ = UnitAura("player", vengeanceSpellName);
	if n then
		LDBVengeance.icon = icon
		addon.ScanTip:ClearLines()
		addon.ScanTip:SetUnitBuff("player",n)
		local tipText = getTooltipText(addon.ScanTip:GetRegions())
		local vengval
		vengval = tonumber(string.match(tipText,"%d+"))
		return vengval
	else
		setDefaultVengeanceIcon()
		return 0
	end
end

local function isPotentialVengeanceClasss()
	local potentialTanks = {
		PALADIN = true,
		WARRIOR = true,
		DRUID = true,
		DEATHKNIGHT = true,
		MONK = true,
	}
	if potentialTanks[playerClass] then
		return true
	else
		return false
	end
end

function addon:UNIT_AURA(...)
	local unit = ...;
	if unit ~= "player" then
		return
	end
	if isTank then
		local vengval = GetVengeanceValue()
		if  vengval > 0 then
			LDBVengeance.text = vengval
		else
			LDBVengeance.text = LDBVengeanceDB.defaultText
			setDefaultVengeanceIcon()
		end
		if LDBVengeanceDB.provideValue then
			LDBVengeance.value = vengval
		else
			LDBVengeance.value = false
		end
	else 
		LDBVengeance.text = LDBVengeanceDB.defaultText
		if LDBVengeanceDB.provideValue then
			LDBVengeance.value = 0
		else
			LDBVengeance.value = false
		end
		setDefaultVengeanceIcon()
	end
end

function addon:PLAYER_LOGIN()
	if (not LDBVengeanceDB or not LDBVengeanceDB.dbVersion or LDBVengeanceDB.dbVersion < DBversion) then
		addon:setDefaults()
	end
	if playerClass == nil then
		playerClass = select(2,UnitClass("player"))
	end
	if isPotentialVengeanceClasss() then
		self:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
		self:checkIsTank()
	end
	LDBVengeance.text = LDBVengeanceDB.defaultText
end

function addon:ACTIVE_TALENT_GROUP_CHANGED()
	self:checkIsTank()
	self:UNIT_AURA('player')
end

function addon:UPDATE_SHAPESHIFT_FORM()
	local form = GetShapeshiftFormID()
	--if form and form == BEAR_FORM then
	--	isTank = true
	--else
	--	isTank = false
	--end
end

function addon:ADDON_LOADED(name, event)
	if(name == addonName) then
		self:UnregisterEvent(event)
		self:PLAYER_LOGIN()
	end
end

function LDBVengeance:OnTooltipShow()
	self:AddLine(defaultText.." |cff00ff00"..addonversion.."|r")
	self:AddLine("|cffffffff"..L['Displays the current value of your vengeance buff'].."|r")
	if not isPotentialVengeanceClasss() then
		self:AddLine("|cffff0000"..L['Note: This addon does not make any sense for classes that don\'t have a Vengeance buff'].."|r")
	end
end

function addon:setDefaults()
	LDBVengeanceDB = LDBVengeanceDB or {}
	LDBVengeanceDB.dbVersion = DBversion
	LDBVengeanceDB.defaultText = LDBVengeanceDB.defaultText or defaultText
	LDBVengeanceDB.provideValue = LDBVengeanceDB.provideValue or 1
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

local AceCfg = LibStub("AceConfig-3.0")
local AceCfgReg = LibStub("AceConfigRegistry-3.0")
local AceDlg = LibStub("AceConfigDialog-3.0")

AceCfg:RegisterOptionsTable("LDB_Vengeance", options)

local brokerOptions = AceCfgReg:GetOptionsTable("Broker", "dialog", "LibDataBroker-1.1")
if (not brokerOptions) then
	brokerOptions = {
		type = "group",
		name = "Broker",
		args = {
		}
	}
	AceCfg:RegisterOptionsTable("Broker", brokerOptions)
	AceDlg:AddToBlizOptions("Broker", "Broker")
end

LDBVengeance.optionsFrame = AceDlg:AddToBlizOptions("LDB_Vengeance", "Vengeance", "Broker")

addon:RegisterEvent(IsAddOnLoaded('AddonLoader') and 'ADDON_LOADED' or 'PLAYER_LOGIN')
addon:SetScript('OnEvent', function(self, event, ...) self[event](self, ..., event) end)
