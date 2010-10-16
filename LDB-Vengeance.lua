local addonName, ns = ...
local addon = CreateFrame("Frame", addonName)

local DBversion = "1"

local defaultText = "|cffC79C6ELDB|r-Vengeance"

local LDBVengeance = LibStub("LibDataBroker-1.1"):NewDataObject(
	addonName, 
	{ 
		icon = "Interface\\Icons\\Ability_Paladin_ShieldofVengeance", 
		type = "data source",
		text = defaultText 
	}
)

local maxVengeance = 0
local isTank = false

addon.ScanTip = CreateFrame("GameTooltip","VengeanceStatusScanTip",nil,"GameTooltipTemplate")
addon.ScanTip:SetOwner(UIParent, "ANCHOR_NONE")

local playerClass = ""
local KNOWN_VENGEANCE_SPELL_ID = 93098

local function getCorrectVengeanceIcon()
	if playerClass ~= "" then
		local name, _, _, _, _, _, _, _, _ = GetSpellInfo(KNOWN_VENGEANCE_SPELL_ID)
		local _, _, icon, _, _, _, _, _, _ = GetSpellInfo(name)
		if icon then
			LDBVengeance.icon = icon
		end
	end
end

local function checkIsTank()
	local masteryIndex 
	local tank = false
	if playerClass == "DRUID" then
		masteryIndex = GetPrimaryTalentTree()
		if masteryIndex and masteryIndex == 2 then			
			local form = GetShapeshiftFormID()
			if form and form == BEAR_FORM then
				tank = true
			end
		end
	end
	if playerClass == "DEATHKNIGHT" then
		masteryIndex = GetPrimaryTalentTree()
		if masteryIndex and masteryIndex == 1 then
			tank = true
		end
	end
	if playerClass == "PALADIN" then
		masteryIndex = GetPrimaryTalentTree()
		if masteryIndex and masteryIndex == 2 then
			tank = true
		end
	end
	if playerClass == "WARRIOR" then
		masteryIndex = GetPrimaryTalentTree()
		if masteryIndex and masteryIndex == 3 then
			tank = true
		end
	end
	isTank = tank
end

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
		local n,_,icon,_,_,_,_,_,_,_,id = UnitAura("player", (GetSpellInfo(93098)));
		if n then
			LDBVengeance.icon = icon
			addon.ScanTip:ClearLines()
			addon.ScanTip:SetUnitBuff("player",n)
			local tipText = getTooltipText(addon.ScanTip:GetRegions())
			local vengval,percentmax,downtime
			vengval = tonumber(string.match(tipText,"%d+"))
			return vengval
		else
			return 0
		end
end

function addon:UNIT_AURA(...)
	local unit = ...;
	if isTank then
		local vengval = GetVengeanceValue()
		if  vengval > 0 then
			local t = ""..vengval
			if LDBVengeanceDB.showTotal then
				t = t .. "/" .. maxVengeance
			end
			if LDBVengeanceDB.showPercent then
				local perc = vengval / maxVengeance * 100
				t = string.format("%s (%.2f%%)",t,perc)
			end			
			LDBVengeance.text = t
		else
			LDBVengeance.text = defaultText
		end
	else 
		LDBVengeance.text = defaultText
	end
end

function addon:PLAYER_LOGIN()
	self:RegisterEvent('UNIT_AURA')
	self:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
	self:RegisterEvent('UNIT_MAXHEALTH')
	if playerClass == "" then
		_ , playerClass = UnitClass("player")
		getCorrectVengeanceIcon()
		checkIsTank()
	end
	if playerClass == "DRUID" then
		self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	end
	LDBVengeance.text = defaultText
end

function addon:ACTIVE_TALENT_GROUP_CHANGED()
	checkIsTank()
end

function addon:UPDATE_SHAPESHIFT_FORM()
	local form = GetShapeshiftFormID()
	if form and form == BEAR_FORM then
		isTank = true
	else
		isTank = false
	end
end

function addon:ADDON_LOADED(name, event)
	if(name == addonName) then
		self:UnregisterEvent(event)
		--Set up defaults
		if (not LDBVengeanceDB or not LDBVengeanceDB.dbVersion or LDBVengeanceDB.dbVersion < DBversion) then
			addon:setDefaults()
		return
		end
		self:PLAYER_LOGIN()
		self:UNIT_MAXHEALTH("player")
	end
end

function addon:UNIT_MAXHEALTH(...)
	local unit = ...;
	if unit == "player" then
		maxVengeance = floor(0.1*UnitHealthMax("player"))
	end
end

function LDBVengeance:OnTooltipShow()
	self:AddLine(defaultText.." |cff00ff000.0.1|r")
	self:AddLine("|cffffffffDisplays the current, max and percentage value of your vengeance buff|r")
	if playerClass and playerClass ~= "DRUID" and playerClass ~= "WARRIOR" and playerClass ~= "DEATHKNIGHT" and playerClass ~= "PALADIN" then
		self:AddLine("|cffff0000Note: This addon does not make any sense for classes that don't have a Vengeance buff|r")
	end
end

function addon:setDefaults()
	LDBVengeanceDB = LDBVengeanceDB or {}
	LDBVengeanceDB.showTotal = LDBVengeanceDB.showTotal or 1
	LDBVengeanceDB.showPercent = LDBVengeanceDB.showPercent or 1
	LDBVengeanceDB.dbVersion = DBversion
end

local options = {
	type ="group",
	name = "|cffC79C6ELDB|r-Vengeance",
	handler = LDBVengeance,
	childGroups = "tree",
	args = {
		header1 = {
			type = "description",
			name = "v0.1",
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
		show = {
			type = "group",
			inline = true,
			name = "Display options",
			order = 10,
			args = {
				showMax = {
					type = "toggle",
					name = "Enabled",
					desc = "Show the maximum possible value",
					order = 1,
					set = function (info, value)
						LDBVengeanceDB.showMax = value
					end,
					get = function() return LDBVengeanceDB.showMax end
				},
				showPercent = {
					type = "toggle",
					name = "Enabled",
					desc = "Show percentage value",
					order = 1,
					set = function (info, value)
						LDBVengeanceDB.showPercent = value
					end,
					get = function() return LDBVengeanceDB.showPercent end
				},
			},
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
