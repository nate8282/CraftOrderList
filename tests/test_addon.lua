-- Legacy unit tests for CraftingOrderHelper
-- Run: lua5.3 tests/test_addon.lua

-- Lua 5.3 compat: WoW uses Lua 5.1 where unpack is a global
if not unpack then unpack = table.unpack end

local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS: " .. name)
    else
        failed = failed + 1
        print("  FAIL: " .. name .. " — " .. tostring(err))
    end
end

local function assertEqual(a, b) assert(a == b, "Expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function assertNotNil(a) assert(a ~= nil, "Expected non-nil") end
local function assertTrue(a) assert(a, "Expected true") end

-- Frame mock (returns callable+indexable sub-objects for chaining)
local frameMT
frameMT = {
    __index = function(t, k)
        local child = setmetatable({}, {
            __call = function() return t end,
            __index = function(_, k2)
                return function() return t end
            end,
        })
        rawset(t, k, child)
        return child
    end,
    __call = function(t) return t end,
}
local function mockFrame(name)
    local f = setmetatable({
        _scripts = {},
        _name = name,
    }, frameMT)
    f.text = setmetatable({}, frameMT)
    f.TitleBg = setmetatable({}, frameMT)
    f.SetScript = function(self, s, h) self._scripts[s] = h end
    f.HookScript = function(self, s, h)
        local old = self._scripts[s]
        self._scripts[s] = function(...)
            if old then old(...) end
            h(...)
        end
    end
    f.GetName = function(self) return self._name end
    f.RegisterEvent = function() end
    f.UnregisterEvent = function() end
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

-- Mock WoW API
CreateFrame = function(t, n, p, tmpl) return mockFrame(n) end
UIParent = mockFrame("UIParent")
UIParent.GetScale = function() return 1 end
UIParent.GetEffectiveScale = function() return 1 end
UISpecialFrames = {}
ChatFrame1EditBox = mockFrame("ChatFrame1EditBox")
ChatFrame1EditBox.IsShown = function() return false end
Minimap = mockFrame("Minimap")
Minimap.GetCenter = function() return 400, 300 end
Minimap.GetWidth = function() return 140 end
GetCursorPosition = function() return 400, 300 end
GameTooltip = mockFrame("GameTooltip")
GameTooltip.AddLine = function() end
GameTooltip.Show = function() end
GameFontNormalSmall = {}
SlashCmdList = {}
C_Timer = { After = function(_, f) f() end }
C_AddOns = { GetAddOnMetadata = function(_, f) if f == "Version" then return "test" end return nil end }
C_Item = {
    GetItemCount = function() return 0 end,
    GetItemNameByID = function(id) return "TestItem" end,
    GetItemIconByID = function() return 134400 end,
    RequestLoadItemDataByID = function() end,
}
C_TradeSkillUI = {
    GetRecipeInfo = function() return nil end,
    GetRecipeSchematic = function() return nil end,
}
Enum = { CraftingReagentType = { Basic = 0, Optional = 1, Finishing = 2 } }
UIDropDownMenu_Initialize = function() end
UIDropDownMenu_SetWidth = function() end
UIDropDownMenu_SetText = function() end
UIDropDownMenu_CreateInfo = function() return {} end
UIDropDownMenu_AddButton = function() end
UnitName = function() return "TestPlayer" end
GetRealmName = function() return "TestRealm" end
function strsplit(d, s) local p = s:find(d); if p then return s:sub(1, p-1), s:sub(p+1) end; return s, nil end
function strtrim(s) return s and s:match("^%s*(.-)%s*$") or "" end
string.trim = function(s) return strtrim(s) end
function CreateAtlasMarkup(atlas, height, width)
    return "|A:" .. atlas .. ":" .. (height or 0) .. ":" .. (width or 0) .. "|a"
end

-- Load addon (pass addon name and namespace table, simulating WoW's vararg loader)
print("Loading CraftingOrderHelper...")
loadfile("CraftingOrderHelper.lua")("CraftingOrderHelper", {})

print("\n=== CraftingOrderHelper Tests ===\n")

test("slash command registered", function()
    assertNotNil(SlashCmdList["COH"])
end)

test("/coh clear does not error", function()
    SlashCmdList["COH"]("clear")
end)

test("/coh reset does not error", function()
    SlashCmdList["COH"]("reset")
end)

test("/coh show does not error", function()
    SlashCmdList["COH"]("show")
end)

test("/coh toggle does not error", function()
    SlashCmdList["COH"]("")
end)

test("strsplit works correctly", function()
    local a, b = strsplit("-", "Kaelen-Sargeras")
    assertEqual(a, "Kaelen")
    assertEqual(b, "Sargeras")
end)

test("strtrim trims whitespace", function()
    assertEqual(strtrim("  hello  "), "hello")
    assertEqual(strtrim(""), "")
end)

-- Summary
print(string.format("\n=== Results: %d passed, %d failed ===", passed, failed))
if failed > 0 then os.exit(1) end
