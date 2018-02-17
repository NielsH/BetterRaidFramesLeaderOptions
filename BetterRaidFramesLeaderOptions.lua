-----------------------------------------------------------------------------------------------
-- Client Lua Script for BetterRaidFramesLeaderOptions
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local BetterRaidFramesLeaderOptions = {}

local ktIdToClassSprite = {
  [GameLib.CodeEnumClass.Warrior]      = "Icon_Windows_UI_CRB_Warrior",
  [GameLib.CodeEnumClass.Engineer]     = "Icon_Windows_UI_CRB_Engineer",
  [GameLib.CodeEnumClass.Esper]        = "Icon_Windows_UI_CRB_Esper",
  [GameLib.CodeEnumClass.Spellslinger] = "Icon_Windows_UI_CRB_Spellslinger",
  [GameLib.CodeEnumClass.Stalker]      = "Icon_Windows_UI_CRB_Stalker",
  [GameLib.CodeEnumClass.Medic]        = "Icon_Windows_UI_CRB_Medic",
}

local ktIdToClassTooltip = {
  [GameLib.CodeEnumClass.Warrior]      = "CRB_Warrior",
  [GameLib.CodeEnumClass.Engineer]     = "CRB_Engineer",
  [GameLib.CodeEnumClass.Esper]        = "CRB_Esper",
  [GameLib.CodeEnumClass.Spellslinger] = "CRB_Spellslinger",
  [GameLib.CodeEnumClass.Stalker]      = "CRB_Stalker",
  [GameLib.CodeEnumClass.Medic]        = "CRB_Medic",
}

function BetterRaidFramesLeaderOptions:new(o)
    o                     = o or {}
    setmetatable(o, self)
    self.__index          = self
    return o
end

function BetterRaidFramesLeaderOptions:Init()
    Apollo.RegisterAddon(self)
end

function BetterRaidFramesLeaderOptions:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("BetterRaidFramesLeaderOptions.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function BetterRaidFramesLeaderOptions:OnDocumentReady()
  if self.xmlDoc == nil then
    return
  end
  Apollo.RegisterEventHandler("GenericEvent_Raid_ToggleLeaderOptions" , "Initialize"            , self)
  Apollo.RegisterEventHandler("Group_Remove"                          , "OnDestroyAndRedrawAll" , self) -- Kicked , or someone else leaves (yourself leaving is Group_Leave)

  Apollo.RegisterTimerHandler("RaidBuildTimer"                        , "BuildList"             , self)
  Apollo.CreateTimer("RaidBuildTimer", 1, true)
  Apollo.StopTimer("RaidBuildTimer")
end

function BetterRaidFramesLeaderOptions:AddWindowManagement()
  Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "Raid Management" })
end


function BetterRaidFramesLeaderOptions:Initialize(bShow)
  if self.wndMain and self.wndMain:IsValid() then
    self.wndMain:Destroy()
    self.wndMain = nil
  end

  if not bShow then
    return
  end

  self.wndMain = Apollo.LoadForm(self.xmlDoc, "BetterRaidFramesLeaderOptionsForm", nil, self)
  self.wndMain:SetSizingMinimum(self.wndMain:GetWidth(), self.wndMain:GetHeight())
  self.wndMain:SetSizingMaximum(self.wndMain:GetWidth(), 1000)

  self:AddWindowManagement()

  Apollo.StartTimer("RaidBuildTimer")
  self:BuildList()
end

function BetterRaidFramesLeaderOptions:BuildList()
  if not GroupLib.InRaid() then
    if self.wndMain and self.wndMain:IsValid() then
      self.wndMain:Destroy()
      self.wndMain = nil
    end
    return
  end

  if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then
    return
  end
  
  local kfnSortMembers = function (a, b)
    if not a or not b or not a:FindChild("RaidMemberName") or not b:FindChild("RaidMemberName") then return false end
    local strMyName
    local myUnit = GameLib.GetPlayerUnit()
    if myUnit then strMyName = myUnit:GetName() else return false end

    local strMyName = GameLib.GetPlayerUnit():GetName()
    local strMemberA = a:FindChild("RaidMemberName"):GetText()
    local strMemberB = b:FindChild("RaidMemberName"):GetText()

    if not strMyName or not strMemberA or not strMemberB then return false end
    if strMemberA == strMyName then return true end if strMemberB == strMyName then return false end
    
    return strMemberA < strMemberB
  end

  local bAmILeader = GroupLib.AmILeader()
  for nIdx = 1, GroupLib.GetMemberCount() do
    local tMemberData = GroupLib.GetGroupMember(nIdx)
    local wndRaidMember = self:FactoryProduce(self.wndMain:FindChild("OptionsMemberContainer"), "OptionsMember", nIdx)
    wndRaidMember:FindChild("KickBtn"):SetData(nIdx)
    wndRaidMember:FindChild("SetDPSBtn"):SetData(nIdx)
    wndRaidMember:FindChild("SetHealBtn"):SetData(nIdx)
    wndRaidMember:FindChild("SetTankBtn"):SetData(nIdx)
    wndRaidMember:FindChild("SetMainTankBtn"):SetData(nIdx)
    wndRaidMember:FindChild("SetMainAssistBtn"):SetData(nIdx)
    wndRaidMember:FindChild("SetRaidAssistBtn"):SetData(nIdx)
    wndRaidMember:FindChild("RaidMemberName"):SetText(tMemberData.strCharacterName)
    wndRaidMember:FindChild("RaidMemberClassIcon"):SetSprite(ktIdToClassSprite[tMemberData.eClassId])
    wndRaidMember:FindChild("RaidMemberClassIcon"):SetTooltip(Apollo.GetString(ktIdToClassTooltip[tMemberData.eClassId]))

    if tMemberData.bIsLeader then
      self.wndMain:FindChild("LockAllRolesBtn"):SetCheck(tMemberData.bRoleLocked)
      local wndLeaderAttachment = self:FactoryProduce(wndRaidMember, "OptionsMemberRaidLeader", "OptionsMemberRaidLeader")
      local bHasText = string.len(wndLeaderAttachment:FindChild("SetRaidLeaderEditBox"):GetText()) > 0
      wndLeaderAttachment:FindChild("SetRaidLeaderConfirmImage"):Show(bHasText)
      wndLeaderAttachment:FindChild("SetRaidLeaderConfirmBtn"):Enable(bHasText)
      wndLeaderAttachment:FindChild("SetRaidLeaderConfirmBtn"):SetData(wndLeaderAttachment)
      wndLeaderAttachment:FindChild("SetRaidLeaderPopupBtn"):AttachWindow(wndLeaderAttachment:FindChild("SetRaidLeaderPopup"))
    end

    wndRaidMember:FindChild("SetMainTankBtn"):Show(not tMemberData.bIsLeader)
    wndRaidMember:FindChild("SetMainAssistBtn"):Show(not tMemberData.bIsLeader)
    wndRaidMember:FindChild("SetRaidAssistBtn"):Show(not tMemberData.bIsLeader)
    wndRaidMember:FindChild("SetRaidAssistBtn"):Enable(bAmILeader)
    wndRaidMember:FindChild("SetMainTankBtn"):SetCheck(tMemberData.bMainTank)
    wndRaidMember:FindChild("SetMainAssistBtn"):SetCheck(tMemberData.bMainAssist)
    wndRaidMember:FindChild("SetRaidAssistBtn"):SetCheck(tMemberData.bRaidAssistant)

    wndRaidMember:FindChild("SetDPSBtn"):SetCheck(tMemberData.bDPS)
    wndRaidMember:FindChild("SetTankBtn"):SetCheck(tMemberData.bTank)
    wndRaidMember:FindChild("SetHealBtn"):SetCheck(tMemberData.bHealer)
  end

  self.wndMain:FindChild("OptionsMemberContainer"):ArrangeChildrenVert(0, kfnSortMembers)
  self.wndMain:FindChild("LockAllRolesBtn"):SetTooltip(Apollo.GetString(self.wndMain:FindChild("LockAllRolesBtn"):IsChecked() and "RaidFrame_UnlockRoles" or "RaidFrame_LockRoles"))
end

-----------------------------------------------------------------------------------------------
-- UI Togglers
-----------------------------------------------------------------------------------------------

function BetterRaidFramesLeaderOptions:OnConfigSetAsDPSCheck(wndHandler, wndControl)
  if wndHandler == wndControl then
    GroupLib.SetRoleDPS(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
  end
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsDPSUncheck(wndHandler, wndControl)
  if wndHandler == wndControl then
    GroupLib.SetRoleDPS(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
  end
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsHealCheck(wndHandler, wndControl)
  if wndHandler == wndControl then
    GroupLib.SetRoleHealer(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
  end
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsHealUncheck(wndHandler, wndControl)
  if wndHandler == wndControl then
    GroupLib.SetRoleHealer(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
  end
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsTankCheck(wndHandler, wndControl) -- SetTankBtn
  if wndHandler == wndControl then
    GroupLib.SetRoleTank(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
  end
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsTankUncheck(wndHandler, wndControl) -- SetTankBtn
  if wndHandler == wndControl then
    GroupLib.SetRoleTank(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
  end
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsMainTankCheck(wndHandler, wndControl)
  GroupLib.SetMainTank(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsMainTankUncheck(wndHandler, wndControl)
  GroupLib.SetMainTank(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsRaidAssistCheck(wndHandler, wndControl)
  GroupLib.SetRaidAssistant(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsRaidAssistUncheck(wndHandler, wndControl)
  GroupLib.SetRaidAssistant(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsMainAssistCheck(wndHandler, wndControl)
  GroupLib.SetMainAssist(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
end

function BetterRaidFramesLeaderOptions:OnConfigSetAsMainAssistUncheck(wndHandler, wndControl)
  GroupLib.SetMainAssist(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
end

function BetterRaidFramesLeaderOptions:OnKickBtn(wndHandler, wndControl)
  GroupLib.Kick(wndHandler:GetData(), "")
end

function BetterRaidFramesLeaderOptions:OnLockAllRolesCheck(wndHandler, wndControl)
  for nIdx = 1, GroupLib.GetMemberCount() do
    GroupLib.SetRoleLocked(nIdx, true)
  end
end

function BetterRaidFramesLeaderOptions:OnLockAllRolesUncheck(wndHandler, wndControl)
  for nIdx = 1, GroupLib.GetMemberCount() do
    GroupLib.SetRoleLocked(nIdx, false)
  end
end

-----------------------------------------------------------------------------------------------
-- Change Leader Edit Box
-----------------------------------------------------------------------------------------------

function BetterRaidFramesLeaderOptions:OnSetRaidLeaderConfirmBtn(wndHandler, wndControl)
  local wndParent = wndHandler:GetData()
  local strInput = tostring(wndParent:FindChild("SetRaidLeaderEditBox"):GetText())
  wndParent:FindChild("SetRaidLeaderPopupBtn"):SetCheck(false)

  if not strInput then
    return
  end

  for nIdx = 1, GroupLib.GetMemberCount() do
    local tMemberData = GroupLib.GetGroupMember(nIdx)
    if tMemberData.strCharacterName:lower() == strInput:lower() then
      GroupLib.Promote(nIdx, "")
      self:OnOptionsCloseBtn()
      return
    end
  end

  -- Fail
  wndParent:FindChild("SetRaidLeaderEditBox"):SetText("")
  ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Party, Apollo.GetString("RaidFrame_PromotionFailed"), "")
end

function BetterRaidFramesLeaderOptions:OnOptionsCloseBtn() -- Also OnSetRaidLeaderConfirmBtn
  if self.wndMain and self.wndMain:IsValid() then
    self.wndMain:Destroy()
    self.wndMain = nil
    Event_FireGenericEvent("GenericEvent_Raid_UncheckLeaderOptions")
  end
  Apollo.StopTimer("RaidBuildTimer")
end

function BetterRaidFramesLeaderOptions:OnDestroyAndRedrawAll() -- Group_MemberFlagsChanged
  if self.wndMain and self.wndMain:IsValid() then
    self.wndMain:FindChild("OptionsMemberContainer"):DestroyChildren()
    self:BuildList()
  end
end

function BetterRaidFramesLeaderOptions:FactoryProduce(wndParent, strFormName, tObject)
  local wndNew = wndParent:FindChildByUserData(tObject)
  if not wndNew then
    wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
    wndNew:SetData(tObject)
  end
  return wndNew
end

local BetterRaidFramesLeaderOptionsInst = BetterRaidFramesLeaderOptions:new()
BetterRaidFramesLeaderOptionsInst:Init()

