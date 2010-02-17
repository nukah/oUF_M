local texture = "Interface\\Addons\\media\\frames\\cabaret5"
local texture2 = "Interface\\Addons\\media\\frames\\Flat"
local glowTex = "Interface\\Addons\\media\\common\\glowTex"
local auraTex = "Interface\\AddOns\\media\\frames\\aura"

local backdrop = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16,
	edgeFile = "", edgeSize = 16,
	insets = {left = -1, right = -1, top = -1, bottom = -1},
}

local glow = {
	edgeFile = glowTex, edgeSize = 4,
	insets = {left = 3, right = 3, top = 3, bottom = 3}
}

oUF.colors.power['MANA'] = {.2, .7, 1}
oUF.colors.power['RAGE'] = {1, .25, .25}
oUF.colors.power['FOCUS'] = {1, .86, .25}
oUF.colors.power['ENERGY'] = {1, .70, .25}
oUF.colors.power['RUNIC_POWER'] = {.45, .45, .75}
oUF.colors.health = {.2, .2, .2}

_G["BuffFrame"]:Hide()
_G["BuffFrame"]:UnregisterAllEvents()
_G["BuffFrame"]:SetScript("OnUpdate", nil)

local width, smallwidth, height = 195, 74, 15
local aurasize = 18

local fontn = "Interface\\Addons\\media\\frames\\COLLEGIA.ttf"
local font2 = "Fonts\\ARIALN.ttf"
local fontsize = 9
local partyraid = false -- true = show party in raid

local menu = function(self)
  local unit = string.gsub(self.unit, "(.)", string.upper, 1)
  if(_G[unit.."FrameDropDown"]) then
    ToggleDropDownMenu(1, nil, _G[unit.."FrameDropDown"], "cursor")
  end
  if(self.unit:match("^party%d$")) then
    ToggleDropDownMenu(1, nil, _G["PartyMemberFrame"..self.id.."DropDown"], "cursor")
  end  
end

local utf8sub = function(string, i, dots)
	local bytes = string:len()
	if bytes <= i then
		return string
	else
		local len, pos = 0, 1
		while pos <= bytes do
			len = len + 1
			local c = string:byte(pos)
			if c > 0 and c <= 127 then
				pos = pos + 1
			elseif c >= 194 and c <= 223 then
				pos = pos + 2
			elseif c >= 224 and c <= 239 then
				pos = pos + 3
			elseif c >= 240 and c <= 244 then
				pos = pos + 4
			end
			if len == i then break end
		end
		if len == i and pos <= bytes then
			return string:sub(1, pos - 1)..(dots and '....' or '')
		else
			return string
		end
	end
end

local short = function(value)
	if(value >= 1e6) then
		return string.format("%.1fm", value / 1e6)
	elseif(value >= 1e4) then
		return string.format("%.1fk", value / 1e3)
	else
		return value
	end
end

oUF.Tags["[nname]"] = function(u)
	color = RAID_CLASS_COLORS[select(2,UnitClass(u))]
	local name = utf8sub(UnitName(u),15,true)
	local short = utf8sub(UnitName(u),6,true)
	return 
	u == "targettarget" and string.format("|cff%02x%02x%02x%s|r",color.r*255,color.g*255,color.b*255,short)
	or string.format("|cff%02x%02x%02x%s|r",color.r*255,color.g*255,color.b*255,name)
end
oUF.TagEvents["[nname]"] = "PLAYER_TARGET_CHANGED"

oUF.TagEvents["[nhp]"] = "UNIT_HEALTH"
oUF.Tags["[nhp]"] = function(u)
	local min, max = UnitHealth(u), UnitHealthMax(u)
	local diff = UnitHealthMax(u)-UnitHealth(u)
	return   (not UnitIsConnected(u) and "Offline") or (UnitIsDead(u) and "Dead") or (UnitIsGhost(u) and "Ghost")
		or ((u == "target" or u == "player") and min==max) and short(min)
		or ((u == "player" or u == "target") and min~=max) and "|cffff0000-"..diff.."|r"
		or ""
end

oUF.TagEvents["[hpshort]"] = "UNIT_HEALTH"
oUF.Tags["[hpshort]"] = function(u)
	local min, max = UnitHealth(u), UnitHealthMax(u)
	local per = floor(min/max*100)
	return (not UnitIsConnected(u) or UnitIsDead(u) or UnitIsGhost(u)) and ""
	  or per.."%"
end

oUF.TagEvents["[power]"] = oUF.TagEvents["[curpp]"]
oUF.Tags["[power]"] = function(u)
	local min,max = UnitMana(u),UnitManaMax(u)
	local ptype = select(2, UnitPowerType(u))
	local r,g,b = unpack(oUF.colors.power[ptype])
	return (min == 0) and ""  
		or	(u == "target") and string.format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, short(min))
		or string.format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, min)
end

local SetFontString = function(parent, fontName, fontHeight, fontStyle)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(fontName, fontHeight, fontStyle)
	fs:SetJustifyH("LEFT")
	fs:SetShadowColor(0,0,0)
	fs:SetShadowOffset(1, -1)
	return fs
end

local updateRIcon = function(self, event)
	local index = GetRaidTargetIndex(self.unit)
	if(index) then
		self.RIcon:SetText(ICON_LIST[index].."22|t")
	else
		self.RIcon:SetText()
	end
end

local updateHealth = function(self, event, unit, bar, min, max)
	local bg = bar.bg
	local mu = .8
	a,b,c = self.ColorGradient((min/max),255/255,0/255,0/255,self.colors.health[1], self.colors.health[2], self.colors.health[3])
	bg:SetVertexColor(0.8*mu,0*mu,0*mu, 1*mu)
	bar:SetStatusBarColor(self.colors.health[1], self.colors.health[2], self.colors.health[3])
end

local updatePower = function(self, event, unit, bar, min, max)
	local bg = bar.bg
	local mu = .5
	local ptype = select(2, UnitPowerType(unit))	
	local color = self.colors.power[ptype] or {1,0,0} 
	bar:SetStatusBarColor(color[1],color[2],color[3])
	bg:SetVertexColor(color[1]*mu,color[2]*mu,color[3]*mu,mu)
end

local updateIcon = function(self,event)
	if self.owner ~= 'player' then 
		self.icon:SetDesaturated(false)
	else 
		self.icon:SetDesaturated(false)
	end
end



local CreateAuraIcon = function(self, button, icons, index, debuff)
	icons.showDebuffType = false
	button.cd.noCooldownCount = false
	button.cd:SetReverse()
	if(self.unit ~= "player") then
		icons.disableCooldown = false
	else 
		icons.disableCooldown = true
	end
	button.icon:SetTexCoord(0.07,0.93,0.07,0.93)
	button.overlay:SetTexture(auraTex)
	button.overlay:SetTexCoord(0.1, 0.9, 0.1, 0.9) 
	button.overlay:SetVertexColor(0, 0, 0)
	button.count:SetPoint("TOP", button, 0, 12)
	button.count:SetFont(fontn, 9, "THINOUTLINE")
	button.count:SetTextColor(1,1,1)
	button.overlay.Hide = function(self) self:SetVertexColor(0, 0, 0) end
	button.remaining = SetFontString(button, fontn, 10, "THINOUTLINE")
	button.remaining:SetPoint("BOTTOM", 0, -5)
end

local FormatTime = function(s)
	local day, hour, minute = 86400, 3600, 60
	if s >= day then
		return format("%dd", floor(s/day + 0.5)), s % day
	elseif s >= hour then
		return format("%dh", floor(s/hour + 0.5)), s % hour
	elseif s >= minute then
		if s <= minute * 5 then
			return format('%d:%02d', floor(s/60), s % minute), s - floor(s)
		end
		return format("%dm", floor(s/minute + 0.5)), s % minute
	elseif s >= minute / 12 then
		return floor(s + 0.5), (s * 100 - floor(s * 100))/100
	end
	return format("%.1f", s), (s * 100 - floor(s * 100))/100
end

------ [Create aura timer]
local CreateAuraTimer = function(self,elapsed)
	if self.timeLeft then
		self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed >= 0.1 then
		if not self.first then
			self.timeLeft = self.timeLeft - self.elapsed
		else
			self.timeLeft = self.timeLeft - GetTime()
			self.first = false
		end
		if self.timeLeft > 0 then
			local time = FormatTime(self.timeLeft)
			self.remaining:SetText(time)
			if self.timeLeft < 5 then
				self.remaining:SetTextColor(1, 0, 0)
			else
				self.remaining:SetTextColor(1,1,1)
			end
			else
				self.remaining:Hide()
				self:SetScript("OnUpdate", nil)
			end
			self.elapsed = 0
		end
	end
end

------ [Updating Auras]
local UpdateAuraIcon = function(self, icons, unit, icon, index)
	local _, _, _, _, _, duration, expirationTime, unitCaster, _ = UnitAura(unit, index, icon.filter)

	if unitCaster ~= 'player' and unitCaster ~= 'vehicle' and not UnitIsFriend('player', unit) and icon.debuff then
		icon.icon:SetDesaturated(true)
	else
		icon.icon:SetDesaturated(false)
	end
	---- [Creating aura timers]
	if duration and duration > 0 then
		icon.remaining:Show()
	end
	if unit == 'player' then
		icon.duration = duration
		icon.timeLeft = expirationTime
		icon.first = true
		icon:SetScript("OnUpdate", CreateAuraTimer)
	end
end


local styleFunc = function(self, unit)
	self.menu = menu
	self:RegisterForClicks("AnyUp")
	self:SetAttribute("type2", "menu")
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)

	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0, 0, 0, 0.8)
	self:SetBackdropBorderColor(0, 0, 0, 0)
	
	self.Glow = CreateFrame("Frame", nil, self)
	self.Glow:SetAllPoints(self)
	self.Glow:SetFrameStrata("LOW")
	self.Glow:SetPoint("TOPLEFT", self, "TOPLEFT", -3, 3)
	self.Glow:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 3, -3)
	self.Glow:SetBackdrop(glow)
	self.Glow:SetBackdropColor(0,0,0,1)
	self.Glow:SetBackdropBorderColor(0,0,0,1)
	
--	// HEALTH BAR
	local hb = CreateFrame("StatusBar", nil, self)
	hb:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
	hb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
	hb:SetStatusBarTexture(texture)
	hb:SetHeight(height*.9)
	
	local hbg = hb:CreateTexture(nil, "BORDER")
	hbg:SetAllPoints(hb)
	hbg:SetTexture(texture)
	hbg:SetVertexColor(0,0,0,1)
	
	self.Health = hb
	self.Health.bg = hbg

-- 	// POWER BAR
	local pb = CreateFrame("StatusBar", nil, self)
	pb:SetPoint("TOPLEFT", self.Health, "BOTTOMLEFT", 0, 0)
	pb:SetPoint("TOPRIGHT", self.Health, "BOTTOMRIGHT", 0, 0)
	pb:SetHeight(height*.1)
	pb:SetStatusBarTexture(texture2)
	
	local pbg = pb:CreateTexture(nil, "BORDER")
	pbg:SetAllPoints(pb)
	pbg:SetTexture(texture2)
	pbg:SetVertexColor(0,0,0,1)
	
	self.Power = pb
	self.Power.bg = pbg
	self.Power.frequentUpdates = true
	self.Power.Smooth = true
	
	self.Health.frequentUpdates = true
	self.Health.Smooth = true  
	self.Health.colorTapping = true
	self.Health.colorDisconnected = true

-- // TEXTS

	self.Name = SetFontString(self.Health, font2, 10, "THINOUTLINE")
	self.Name:SetPoint("LEFT", self.Health, 2,1)
	self:Tag(self.Name, "[nname]")
	
	self.Health.Text = SetFontString(self.Health, fontn, fontsize, "THINOUTLINE")
	self.Health.Text:SetPoint("RIGHT", 0, 0)

	self.Health.Text2 = SetFontString(self.Health, fontn, fontsize, "THINOUTLINE")
	self.Health.Text2:SetPoint("RIGHT", 0, 0)
	
	local ricon = self.Health:CreateFontString(nil, "OVERLAY")
	ricon:SetPoint("TOP", self, 0, 8)
	ricon:SetJustifyH"LEFT"
	ricon:SetFontObject(GameFontNormalSmall)
	ricon:SetTextColor(1, 1, 1)
	self.RIcon = ricon
	self:RegisterEvent("RAID_TARGET_UPDATE", updateRIcon)
	table.insert(self.__elements, updateRIcon)
	
	self.Auras = CreateFrame("Frame", nil, self)
	self.Auras.gap = true
	self.Auras.showDebuffType = true 
	self.Auras.spacing = 3
	
	self.Buffs = CreateFrame("Frame", nil, self)
	self.Debuffs = CreateFrame("Frame", nil, self)

	if (unit == "player") then
		self.Health.Text:SetPoint("LEFT", self.Health, "LEFT", 2, 0)
		self.Health.Text2:SetPoint("RIGHT", self.Health, "RIGHT", -2, 0)
		self:Tag(self.Health.Text, "[nhp]")
		self:Tag(self.Health.Text2, "[power]")
		self.Name:Hide()
		
		self.Buffs.size = 25
		self.Buffs:SetHeight(self.Buffs.size * 3)
		self.Buffs:SetWidth(self.Buffs.size * 12)
		self.Buffs:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -5, 0)
		self.Buffs.initialAnchor = "TOPRIGHT"
		self.Buffs["growth-y"] = "DOWN"
		self.Buffs["growth-x"] = "LEFT"
		self.Buffs.spacing = 3
		self.Buffs.disableCooldown = false

		self.Debuffs.size = 25
		self.Debuffs:SetHeight(self.Debuffs.size * 3)
		self.Debuffs:SetWidth(self.Debuffs.size * 12)
		self.Debuffs:SetPoint("TOPRIGHT", self.Buffs, "BOTTOMRIGHT", 0, -10)
		self.Debuffs.initialAnchor = "TOPRIGHT"
		self.Debuffs["growth-y"] = "DOWN"
		self.Debuffs["growth-x"] = "LEFT"
		self.Debuffs.filter = false
		self.Debuffs.spacing = 3
		self.Debuffs.disableCooldown = false
	end
	if(unit == "target") then
		self.CPoints = SetFontString(self.Health, fontn, 16, "THINOUTLINE")
		self.CPoints:SetPoint("RIGHT", self.Health, -2, 0)
		self.CPoints.unit = "player"
		
		self.Auras:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 3)
		self.Auras["growth-y"] = "UP"      
		self.Auras:SetHeight(16)
		self.Auras.numBuffs = 16
		self.Auras.numDebuffs = 12
		self.Auras.spacing = 1
		self.Auras:SetWidth(width)
		self.Auras.size = self.Auras:GetHeight()
		
		self.Health.Text:SetPoint("CENTER", 0, 0)
		self.Health.Text2:SetPoint("RIGHT", self.Health.Text, "LEFT")
		self:Tag(self.Health.Text, "[nhp]")
		self:Tag(self.Health.Text2, "[power]")
	end  
	if(unit == "pet") then
		self.Auras:SetHeight(self.Health:GetHeight())
		self.Auras:SetWidth(self.Health:GetWidth())
		self.Auras.size = self.Auras:GetHeight()
		
		self.CPoints = SetFontString(self.Health, fontn, 14, "THINOUTLINE")
		self.CPoints:SetPoint("LEFT", self.Health, 2, 0)
		self.CPoints.unit = "pet"
		
		self.Health.Text2:SetPoint("RIGHT", 0, 0)
	end
	if(unit == "targettarget") then
		self.Auras:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 5)
		self.Auras:SetHeight(self.Health:GetHeight())
		self.Auras:SetWidth(smallwidth)
		self.Auras.size = self.Auras:GetHeight()
		self.Auras.num = 10
		self.Auras.numBuffs = 6
		self.Auras.numDebuffs = 6
		self.Auras["growth-x"] = "RIGHT"
		
		self.Health.Text:SetPoint("CENTER", 0, 0)
		self:Tag(self.Health.Text,"[hpshort]")
		self:Tag(self.Name,"[nname]")
	end
	if(unit == "focus") then
		self.Health.Text2:SetPoint("RIGHT",self.Health, 0, 0)
		self:Tag(self.Health.Text2,"[hpshort]")
	end
	if (self:GetParent():GetName():match'^nParty$') then  
		self:Tag(self.Health.Text, "[hpshort]")
		
		self.Buffs:SetPoint("TOPLEFT", self.Power, "BOTTOMLEFT", 0, -4)
		self.Debuffs:SetPoint("LEFT", self, "RIGHT", 5 , 0)
		self.Buffs.initialAnchor = "TOPLEFT"
		self.Debuffs.initialAnchor = "LEFT"
		self.Buffs.num = 7
		self.Debuffs.num = 4
		self.Buffs.size = 14
		self.Debuffs.size = 16
		self.Buffs.spacing = 2
		self.Debuffs.spacing = 2
		
		self.Buffs.filter = "PLAYER|HELPFUL"
		self.Debuffs.filter = "HARMFUL"
		self.Buffs:SetWidth(108)
		self.Buffs:SetHeight(15)		
		self.Debuffs:SetWidth(80)
		self.Debuffs:SetHeight(15)
		self.Buffs["growth-x"] = "RIGHT"
		self.Debuffs["growth-x"] = "RIGHT"
		self.Buffs["growth-y"] = "DOWN"
		self.Debuffs["growth-y"] = "DOWN"
		
		self.outsideRangeAlpha = 0.6
		self.inRangeAlpha = 1.0
		self.Range = true  
	  
		self.Leader = self.Health:CreateTexture(nil, "OVERLAY")
		self.Leader:SetPoint("TOPLEFT", self, 0, 6)
		self.Leader:SetHeight(14)
		self.Leader:SetWidth(14)
		
		self.Threat = self.Health:CreateTexture(nil, "OVERLAY")
		self.Threat:SetHeight(8)
		self.Threat:SetWidth(8)  
		self.Threat:SetTexture([=[Interface\AddOns\oUF_coree\media\indicator]=])
		self.Threat:SetPoint("TOPRIGHT", self.Health, 0, 0)  
	end
	
	if(unit == "player" or unit == "focus") then
		self.Castbar = CreateFrame('StatusBar', unit..'_castBar', self)
		self.Castbar:SetWidth(width)
		self.Castbar:SetHeight(10)
		self.Castbar:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -3)
		self.Castbar:SetStatusBarTexture(texture)
		self.Castbar:SetStatusBarColor(1, 0.4, 0)
		
		self.Castbar.bg = self.Castbar:CreateTexture(nil, 'BACKGROUND')
		self.Castbar.bg:SetPoint('TOP', self.Castbar, 0, 1)
		self.Castbar.bg:SetPoint('LEFT', self.Castbar, -1, 0)
		self.Castbar.bg:SetPoint('RIGHT', self.Castbar, 1, 0)
		self.Castbar.bg:SetPoint('BOTTOM', self.Castbar, 0, -1)
		self.Castbar.bg:SetTexture(texture)
		self.Castbar.bg:SetVertexColor(0, 0, 0, 0.65)
		
		self.Castbar.Time = SetFontString(self.Castbar, fontn, 9, "THINOUTLINE")
		self.Castbar.Time:SetJustifyH('RIGHT')
		self.Castbar.Time:SetPoint('RIGHT', self.Castbar, -2, 0)
		
		self.Castbar.Text = SetFontString(self.Castbar, font2, 9, "THINOUTLINE")
		self.Castbar.Text:SetJustifyH('LEFT')
		self.Castbar.Text:SetPoint('LEFT', self.Castbar, 2, 0)
		self.Castbar.Text:SetPoint('RIGHT', self.Castbar.Time, -1, 0)
		
		self.Castbar.SafeZone = self.Castbar:CreateTexture(nil, 'BORDER')
		self.Castbar.SafeZone:SetTexture(texture)
		self.Castbar.SafeZone:SetVertexColor(1, 0, 0, 0.5)
		self.Castbar.SafeZone:SetPoint('TOPRIGHT')
		self.Castbar.SafeZone:SetPoint('BOTTOMRIGHT')
	end
	
	self.PostCreateAuraIcon = CreateAuraIcon
	self.PostCreateEnchantIcon = CreateAuraIcon
	self.PostUpdateAuraIcon = UpdateAuraIcon
	
	self.OverrideUpdateHealth = updateHealth
	self.OverrideUpdatePower = updatePower
	
	if(unit == "player" or unit == "focus") then
		self:SetAttribute("initial-height", height)
		self:SetAttribute('initial-width', width)      
	end  
	if(unit == "pet" or unit == "targettarget" or unit == "focustarget") then
		self:SetAttribute('initial-height', height)
		self:SetAttribute('initial-width', smallwidth)
	end
	if(unit == "target") then
		self:SetAttribute('initial-height', height)
		self:SetAttribute('initial-width', width)
	end
	if(self:GetParent():GetName():match'nParty') then
		self:SetAttribute('initial-height', height)
		self:SetAttribute('initial-width', width - 86)

	end

	return self
end

oUF:RegisterStyle("coree", styleFunc)
oUF:SetActiveStyle("coree")

oUF:Spawn("player", "nPlayer"):SetPoint("CENTER", UIParent, 0, -306)
oUF:Spawn("target", "nTarget"):SetPoint("CENTER", UIParent, 0, -245)
oUF:Spawn("targettarget", "nToT"):SetPoint("RIGHT", oUF.units.target, "LEFT", -5, 0)
oUF:Spawn("pet", "nPet"):SetPoint("TOPLEFT", oUF.units.player, "BOTTOMLEFT", 0, -5)
oUF:Spawn("focus", "nFocus"):SetPoint("TOP", UIParent, 4, -150)
oUF:Spawn("focustarget", "nFocusTarget"):SetPoint("RIGHT", oUF.units.player,"LEFT",-5, 0)

local party = oUF:Spawn("header", "nParty")
party:SetPoint("LEFT", oUF.units.target, "RIGHT" , 15, 0)
party:SetManyAttributes("showParty", true, "yOffset", 55, "showPlayer", false)
--party:SetAttribute("template", "oUF_coreePPets")

local partyToggle = CreateFrame("Frame")
partyToggle:RegisterEvent("PLAYER_LOGIN")
partyToggle:RegisterEvent("RAID_ROSTER_UPDATE")
partyToggle:RegisterEvent("PARTY_LEADER_CHANGED")
partyToggle:RegisterEvent("PARTY_MEMBER_CHANGED")
partyToggle:SetScript("OnEvent", function(self)
  if(InCombatLockdown()) then
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
  else
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if (partyraid == true and GetNumRaidMembers() <=5 or GetNumRaidMembers() == 0) then
      party:Show()
    else
      party:Hide()
    end
  end
end)

