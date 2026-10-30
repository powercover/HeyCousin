local _, HC = ...

HC.Gear = {}

local Gear = HC.Gear
local Utils = HC.Utils
local Kin = HC.Kin

-- A cousin's gear, from a quiet look at them up close: the game's inspect, as its Inspect window
-- uses. Once a meeting, out of a fight, one look every few seconds, and never while you inspect
-- someone yourself (the Inspect window would show them instead).
-- The slots, in the order a meeting keeps them: head, neck, shoulders, back, chest, wrists, hands,
-- waist, legs, feet, two rings, two trinkets, the weapons.
Gear.SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
local GAP, WAIT = 4, 5

local frame = CreateFrame("Frame")
local asked -- { guid, first, at }: the look the game hasn't answered yet
local lastAsk = -GAP

local function Inspecting()
    return InspectFrame ~= nil and InspectFrame:IsShown()
end

-- Looks at `unit`, the relative `first`, when the game allows it now.
function Gear.Look(unit, first)
    local now = GetTime()
    if (asked and now - asked.at < WAIT) or now - lastAsk < GAP or Utils.Call(InCombatLockdown) or Inspecting() then
        return
    end
    if type(NotifyInspect) ~= "function" or Utils.Call(CanInspect, unit) ~= true
        or Utils.Call(CheckInteractDistance, unit, 1) == false then
        return
    end
    local guid = Utils.Call(UnitGUID, unit)
    if not Utils.IsUsableString(guid) then
        return
    end
    asked, lastAsk = { guid = guid, first = first, at = now }, now
    frame:RegisterEvent("INSPECT_READY")
    pcall(NotifyInspect, unit)
end

frame:SetScript("OnEvent", Utils.Protect("gear", function(_, _, guid)
    if not asked or guid ~= asked.guid then
        return
    end
    local first = asked.first
    asked = nil
    frame:UnregisterEvent("INSPECT_READY")
    local unit = Utils.Call(UnitTokenFromGUID, guid)
    if Utils.IsUsableString(unit) then
        local items, any = {}, false
        for index, slot in ipairs(Gear.SLOTS) do
            local id = Utils.Call(GetInventoryItemID, unit, slot)
            items[index] = Utils.IsUsableNumber(id) and id or 0
            any = any or items[index] > 0
        end
        if any then
            Kin.SawGear(first, items, C_PaperDollInfo and Utils.Call(C_PaperDollInfo.GetInspectItemLevel, unit))
        end
    end
    if not Inspecting() and type(ClearInspectPlayer) == "function" then
        pcall(ClearInspectPlayer)
    end
end))

-- An item's icon (a file id), or nil.
function Gear.Icon(id)
    if not Utils.IsUsableNumber(id) or id <= 0 then
        return nil
    end
    local icon = C_Item and Utils.Call(C_Item.GetItemIconByID, id)
    if not icon and type(GetItemIcon) == "function" then
        icon = Utils.Call(GetItemIcon, id)
    end
    return icon
end
