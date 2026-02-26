-- WoW API mock layer for busted tests
-- Provides mock implementations of WoW API functions used by CraftingOrderHelper

local MockData = {
    player = { name = "Kaelen", realm = "Sargeras" },
    professions = { [1] = { name = "Leatherworking" }, [2] = { name = "Skinning" } },
    registeredEvents = {},
    itemCounts = {},
    itemNames = {},
    itemIcons = {},
    recipeInfos = {},
    recipeSchematics = {},
    tooltipLines = {},
}

-- Frame mock with chainable method stubs
local frameMT = {
    __index = function(t, k)
        return function() return t end
    end
}
local function mockFrame(frameName)
    local f = setmetatable({
        _scripts = {},
        _name = frameName,
    }, frameMT)
    f.text = setmetatable({}, frameMT)
    f.TitleBg = setmetatable({}, frameMT)
    f.SetScript = function(self, script, handler) self._scripts[script] = handler end
    f.HookScript = function(self, script, handler)
        local old = self._scripts[script]
        self._scripts[script] = function(...)
            if old then old(...) end
            handler(...)
        end
    end
    f.GetName = function(self) return self._name end
    f.RegisterEvent = function(self, event)
        MockData.registeredEvents[event] = true
    end
    f.UnregisterEvent = function(self, event)
        MockData.registeredEvents[event] = nil
    end
    f.RegisterForDrag = function() end
    f.RegisterForClicks = function() end
    f.IsShown = function() return false end
    f.IsVisible = function() return false end
    f.GetWidth = function() return 300 end
    f.GetHeight = function() return 400 end
    f.GetCenter = function() return 400, 300 end
    f.GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end
    f.GetEffectiveScale = function() return 1 end
    return f
end

-- Core WoW frame/UI globals
function CreateFrame(frameType, frameName, parent, template)
    return mockFrame(frameName)
end
UIParent = mockFrame("UIParent")
UIParent.GetScale = function() return 1 end
UIParent.GetEffectiveScale = function() return 1 end

UISpecialFrames = {}
ChatFrame1EditBox = mockFrame("ChatFrame1EditBox")
ChatFrame1EditBox.IsShown = function() return false end

Minimap = mockFrame("Minimap")
Minimap.GetCenter = function() return 400, 300 end
Minimap.GetWidth = function() return 140 end

function GetCursorPosition() return 400, 300 end

-- Dropdown menu API stubs
function UIDropDownMenu_Initialize() end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText() end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton() end

-- GameTooltip mock
GameTooltip = mockFrame("GameTooltip")
GameTooltip.AddLine = function(self, text)
    table.insert(MockData.tooltipLines, text or "")
end
GameTooltip.Show = function() end

-- Font object stubs
GameFontNormalSmall = {}

-- C_Item mock
C_Item = {
    GetItemCount = function(itemID, includeBank, includeUses, includeReagentBank)
        return MockData.itemCounts[itemID] or 0
    end,
    GetItemNameByID = function(itemID)
        return MockData.itemNames[itemID] or ("Item_" .. tostring(itemID))
    end,
    GetItemIconByID = function(itemID)
        return MockData.itemIcons[itemID] or 134400
    end,
    RequestLoadItemDataByID = function() end,
}

-- C_TradeSkillUI mock
C_TradeSkillUI = {
    GetRecipeInfo = function(recipeID)
        return MockData.recipeInfos[recipeID]
    end,
    GetRecipeSchematic = function(recipeID, isRecraft)
        return MockData.recipeSchematics[recipeID]
    end,
}

-- Enum mock
Enum = {
    CraftingReagentType = {
        Basic = 0,
        Optional = 1,
        Finishing = 2,
    },
}

-- Blizzard frame stubs (not loaded by default in tests)
ProfessionsFrame = nil
ProfessionsCustomerOrdersFrame = nil
AuctionHouseFrame = nil

-- Player info
function UnitName(unit)
    return MockData.player.name
end
function GetRealmName() return MockData.player.realm end

-- Profession info
function GetProfessions() return 1, 2, nil, nil, nil end
function GetProfessionInfo(i)
    return MockData.professions[i].name, 0, 100, 100, 0, 0, i, 0, 0, 0, MockData.professions[i].name
end

-- WoW utility functions
function strsplit(delim, str)
    local pos = str:find(delim)
    if pos then return str:sub(1, pos - 1), str:sub(pos + 1) end
    return str, nil
end
function strtrim(str) return str and str:match("^%s*(.-)%s*$") or "" end

-- System stubs
C_Timer = {
    After = function(_, f) f() end,
    NewTimer = function(_, f)
        local timer = { cancelled = false }
        function timer:Cancel() self.cancelled = true end
        f()
        return timer
    end,
}
SlashCmdList = {}

-- C_AddOns mock
C_AddOns = {
    GetAddOnMetadata = function(name, field)
        if field == "Version" then return "test" end
        return nil
    end,
}

-- Expose MockData globally so tests can modify it
_G.MockData = MockData

return MockData
