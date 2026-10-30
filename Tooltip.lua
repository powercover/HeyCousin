local _, HC = ...

HC.Tooltip = {}

local Tooltip = HC.Tooltip
local Utils = HC.Utils
local Theme = HC.Theme
local Crest = HC.Crest
local Names = HC.Names
local Kin = HC.Kin
local L = HC.L
local C = Theme.C

-- Tooltips that already have the family's lines (a refresh runs the post-call again). Kept here,
-- not as a field on the game's tooltip: the addon writes nothing on Blizzard's frames.
local added = setmetatable({}, { __mode = "k" })

-- A relative's tooltip gets the family line ("Family: Ashbrook (cousin)") and how often you met.
local function AddLines(tooltip)
    if tooltip ~= GameTooltip or added[tooltip] then
        return
    end
    if type(tooltip.IsForbidden) == "function" and tooltip:IsForbidden() then
        return
    end
    if type(HeyCousinDB) ~= "table" or HeyCousinDB.tooltipLine == false then
        return
    end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or not Utils.IsUsableString(unit) or Utils.Call(UnitIsPlayer, unit) ~= true then
        return
    end
    local me = Utils.Call(UnitIsUnit, unit, "player") == true
    local first, surname
    if me or HC.TestMode.active then
        -- in test mode only your own tooltip has the made-up family
        if not me then
            return
        end
        first, surname = Names.Me()
    else
        first, surname = Names.Unit(unit)
    end
    local house, mine = Kin.House()
    if not first or not house or not Names.Same(surname, mine) then
        return
    end
    local relative = not me and house.relatives[first]
    if not me and not relative then
        -- seen this moment: the radar takes them in
        HC.Radar.Look(unit, true)
        relative = house.relatives[first]
    end
    added[tooltip] = true
    local sheep = relative and Kin.IsBlackSheep(relative)
    local role = me and L["you"] or sheep and L["black sheep"] or L["cousin"]
    local color = sheep and C.enemy or C.near
    tooltip:AddLine(Crest.ChatIcon(house.crest, sheep) .. " " .. string.format(L["Family: %s (%s)"], mine, role),
        color[1], color[2], color[3])
    local met = relative and relative.met or 0
    if met > 0 then
        tooltip:AddLine(met == 1 and L["Met once"] or string.format(L["Met %d times"], met), C.text3[1], C.text3[2],
            C.text3[3])
    end
    tooltip:Show()
end

function Tooltip.Start()
    if Tooltip.started or not GameTooltip then
        return
    end
    Tooltip.started = true
    GameTooltip:HookScript("OnTooltipCleared", function(self)
        added[self] = nil
    end)
    local protected = Utils.Protect("tooltip", AddLines)
    if TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall) == "function" and Enum
        and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, protected)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", protected)
    end
end
