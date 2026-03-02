--[[
    CraftOrderList - Visual shopping list for crafting materials
    Shows what you need, what you have, and lets you search the AH directly.
]]

local addonName, COL = ...

-- ============================================================================
-- Keybindings (COH-015) — globals set at file-load time, before any event fires
-- ============================================================================
BINDING_HEADER_CRAFTORDERLIST = "Craft Order List"
BINDING_NAME_COLTOGGLEMAIN    = "Toggle Materials List"
BINDING_NAME_COLSEARCHNEXT    = "Search Next Material"

function COL_ToggleFrame()        COL:ToggleFrame()        end
function COL_SearchNextMaterial() COL:SearchNextMaterial() end

-- ============================================================================
-- Namespace & State
-- ============================================================================
COL.materialList   = {}
COL.recipeName     = ""
COL.mainFrame      = nil
COL.rows           = {}
COL.buttonsCreated = {}
COL.recentRecipes  = {}   -- COH-008: { { id, name }, ... } newest first, max 5
COL.searchIndex    = 0    -- cursor for Search Next cycling (1-indexed into materialList)
COL.settings = {
    qualityFilter = 0,
    hideCompleted = false,
    sortBy        = "name",
    craftCount    = 1,
    framePos      = nil,
    minimapHidden    = false,   -- COH-017
    ahAutoDock       = true,    -- COH-018
    autoOpenOnRecipe  = true,   -- auto-open COL when a recipe is selected
    autoCloseOnRecipe = false,  -- auto-close COL when the recipe window closes
}

-- COH-009: one-shot completion notification flag (reset on each new list load)
local completionNotified = false

local MAX_ITEMS = 40
local QUALITY_ICONS = {
    [0] = "Any",
    [1] = CreateAtlasMarkup("Professions-Icon-Quality-Tier1-Small", 20, 20),
    [2] = CreateAtlasMarkup("Professions-Icon-Quality-Tier2", 20, 20),
    [3] = CreateAtlasMarkup("Professions-Icon-Quality-Tier3-Small", 20, 20),
}
local COLORS = {
    have    = {0.2, 1,   0.2},
    partial = {1,   1,   0.2},
    need    = {1,   0.3, 0.3},
    header  = {1,   0.82,  0},
    text    = {1,   1,   1  },
    dim     = {0.5, 0.5, 0.5},
}

-- ============================================================================
-- Utility
-- ============================================================================

local function GetItemCountByQuality(itemID)
    return C_Item.GetItemCount(itemID, true, false, true) or 0
end

local function GetOwnedForMaterial(mat)
    if not mat.reagents then return 0 end
    local filter = COL.settings.qualityFilter

    if filter > 0 then
        local r = mat.reagents[filter]
        if r and r.itemID then
            return GetItemCountByQuality(r.itemID)
        end
    end

    local total = 0
    for i = 1, #mat.reagents do
        if mat.reagents[i] and mat.reagents[i].itemID then
            total = total + GetItemCountByQuality(mat.reagents[i].itemID)
        end
    end
    return total
end

local function GetSearchName(mat)
    local quality = COL.settings.qualityFilter

    if quality > 0 and mat.reagents then
        local r = mat.reagents[quality]
        if r and r.itemID then
            local name = C_Item.GetItemNameByID(r.itemID)
            if name and name ~= "" and name ~= "Loading..." then
                return name
            end
        end
    end

    local name = mat.name
    if not name or name == "Loading..." or name == "Unknown" then
        if mat.reagents and mat.reagents[1] and mat.reagents[1].itemID then
            C_Item.RequestLoadItemDataByID(mat.reagents[1].itemID)
        end
        return nil
    end
    return name
end

local function GetNeeded(mat)
    return mat.needed * COL.settings.craftCount
end

-- COH-011/COH-013: Reagent source classification (shared utility)
local SOURCE = {
    GATHERED = "Gathered",
    CRAFTED  = "Crafted",
    VENDOR   = "Vendor",
    OTHER    = "Other",
}

local SOURCE_SORT_ORDER = {
    [SOURCE.GATHERED] = 1,
    [SOURCE.CRAFTED]  = 2,
    [SOURCE.VENDOR]   = 3,
    [SOURCE.OTHER]    = 4,
}

local SUBTYPE_SOURCE_MAP = {
    -- Herbalism
    ["Herb"]            = SOURCE.GATHERED,
    ["草药"]            = SOURCE.GATHERED,   -- zhCN/zhTW
    -- Mining
    ["Metal & Stone"]   = SOURCE.GATHERED,
    ["金属和矿石"]      = SOURCE.GATHERED,   -- zhCN
    ["金屬及石頭"]      = SOURCE.GATHERED,   -- zhTW
    -- Skinning / Leatherworking inputs
    ["Leather"]         = SOURCE.GATHERED,
    ["皮革"]            = SOURCE.GATHERED,   -- zhCN/zhTW
    ["Cloth"]           = SOURCE.GATHERED,
    ["布料"]            = SOURCE.GATHERED,   -- zhCN/zhTW
    -- Misc gathered
    ["Elemental"]       = SOURCE.GATHERED,
    ["元素"]            = SOURCE.GATHERED,   -- zhCN/zhTW
    ["Fish"]            = SOURCE.GATHERED,
    ["鱼"]              = SOURCE.GATHERED,   -- zhCN
    ["魚"]              = SOURCE.GATHERED,   -- zhTW
    ["Meat"]            = SOURCE.GATHERED,
    ["肉类"]            = SOURCE.GATHERED,   -- zhCN
    ["肉類"]            = SOURCE.GATHERED,   -- zhTW
    ["Cooking"]         = SOURCE.GATHERED,
    ["烹饪材料"]        = SOURCE.GATHERED,   -- zhCN
    ["烹飪材料"]        = SOURCE.GATHERED,   -- zhTW
    -- Crafted by professions
    ["Parts"]           = SOURCE.CRAFTED,
    ["零件"]            = SOURCE.CRAFTED,    -- zhCN/zhTW
    ["Jewelcrafting"]   = SOURCE.CRAFTED,
    ["珠宝"]            = SOURCE.CRAFTED,    -- zhCN
    ["珠寶"]            = SOURCE.CRAFTED,    -- zhTW
    ["Enchanting"]      = SOURCE.CRAFTED,
    ["附魔"]            = SOURCE.CRAFTED,    -- zhCN/zhTW
    ["Devices"]         = SOURCE.CRAFTED,
    ["装置"]            = SOURCE.CRAFTED,    -- zhCN
    ["裝置"]            = SOURCE.CRAFTED,    -- zhTW
    ["Reagents"]        = SOURCE.CRAFTED,
    ["试剂"]            = SOURCE.CRAFTED,    -- zhCN
    ["試劑"]            = SOURCE.CRAFTED,    -- zhTW
    ["Alchemy"]         = SOURCE.CRAFTED,
    ["炼金"]            = SOURCE.CRAFTED,    -- zhCN
    ["鍊金"]            = SOURCE.CRAFTED,    -- zhTW
    ["Inscription"]     = SOURCE.CRAFTED,
    ["铭文"]            = SOURCE.CRAFTED,    -- zhCN
    ["銘文"]            = SOURCE.CRAFTED,    -- zhTW
    ["Leatherworking"]  = SOURCE.CRAFTED,
    ["皮甲制作"]        = SOURCE.CRAFTED,    -- zhCN
    ["皮甲製作"]        = SOURCE.CRAFTED,    -- zhTW
    ["Mining"]          = SOURCE.CRAFTED,
    ["采矿"]            = SOURCE.CRAFTED,    -- zhCN
    ["採礦"]            = SOURCE.CRAFTED,    -- zhTW
    ["Blacksmithing"]   = SOURCE.CRAFTED,
    ["锻造"]            = SOURCE.CRAFTED,    -- zhCN
    ["鍛造"]            = SOURCE.CRAFTED,    -- zhTW
    ["Tailoring"]       = SOURCE.CRAFTED,
    ["裁缝"]            = SOURCE.CRAFTED,    -- zhCN
    ["裁縫"]            = SOURCE.CRAFTED,    -- zhTW
    ["Engineering"]     = SOURCE.CRAFTED,
    ["工程学"]          = SOURCE.CRAFTED,    -- zhCN
    ["工程學"]          = SOURCE.CRAFTED,    -- zhTW
    -- Vendor
    ["Junk"]            = SOURCE.VENDOR,
    ["垃圾"]            = SOURCE.VENDOR,     -- zhCN/zhTW
    -- Fallback
    ["Miscellaneous"]   = SOURCE.OTHER,
    ["杂项"]            = SOURCE.OTHER,      -- zhCN
    ["雜項"]            = SOURCE.OTHER,      -- zhTW
    ["Trade Goods"]     = SOURCE.OTHER,
    ["商业物品"]        = SOURCE.OTHER,      -- zhCN
    ["商業物品"]        = SOURCE.OTHER,      -- zhTW
}

local function GetReagentSource(itemID)
    if not itemID or itemID == 0 then return SOURCE.OTHER end
    local _, _, subType = C_Item.GetItemInfoInstant(itemID)
    if subType then
        return SUBTYPE_SOURCE_MAP[subType] or SOURCE.OTHER
    end
    return SOURCE.OTHER
end

-- COH-014: Substitution helpers
local function GetTotalAcrossAllTiers(mat)
    if not mat.reagents then return 0 end
    local total = 0
    for i = 1, #mat.reagents do
        if mat.reagents[i] and mat.reagents[i].itemID then
            total = total + GetItemCountByQuality(mat.reagents[i].itemID)
        end
    end
    return total
end

local function HasSubstitution(mat)
    local filter = COL.settings.qualityFilter
    if filter == 0 then return false end
    local r = mat.reagents and mat.reagents[filter]
    if not r or not r.itemID then return false end
    local needed = GetNeeded(mat)
    if GetItemCountByQuality(r.itemID) >= needed then return false end
    return GetTotalAcrossAllTiers(mat) >= needed
end

local function SortMaterials()
    local sortBy = COL.settings.sortBy
    table.sort(COL.materialList, function(a, b)
        if sortBy == "name" then
            return (a.name or "") < (b.name or "")
        elseif sortBy == "needed" then
            return GetNeeded(a) > GetNeeded(b)
        elseif sortBy == "status" then
            local aDone = (GetOwnedForMaterial(a) >= GetNeeded(a)) and 1 or 0
            local bDone = (GetOwnedForMaterial(b) >= GetNeeded(b)) and 1 or 0
            if aDone ~= bDone then return aDone < bDone end
            return (a.name or "") < (b.name or "")
        elseif sortBy == "source" then
            -- COH-013: Group by acquisition source, alpha tiebreak within group
            local aID  = a.reagents and a.reagents[1] and a.reagents[1].itemID
            local bID  = b.reagents and b.reagents[1] and b.reagents[1].itemID
            local aOrd = SOURCE_SORT_ORDER[GetReagentSource(aID)] or 4
            local bOrd = SOURCE_SORT_ORDER[GetReagentSource(bID)] or 4
            if aOrd ~= bOrd then return aOrd < bOrd end
            return (a.name or "") < (b.name or "")
        end
        return false
    end)
end

-- ============================================================================
-- Material List Building
-- ============================================================================

-- COH-008: Add or promote a recipe entry in the recent list (max 5, no dupes)
local function AddToRecentRecipes(recipeID, name)
    for i = #COL.recentRecipes, 1, -1 do
        if COL.recentRecipes[i].id == recipeID then
            table.remove(COL.recentRecipes, i)
        end
    end
    table.insert(COL.recentRecipes, 1, { id = recipeID, name = name })
    if #COL.recentRecipes > 5 then
        table.remove(COL.recentRecipes)
    end
end

local function BuildMaterialList(recipeID, addToExisting)
    if not addToExisting then
        COL.materialList = {}
        COL.searchIndex  = 0         -- restart Search Next cycle for new list
        completionNotified = false   -- COH-009: reset notification for new list
    end

    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if not recipeInfo then return false end

    if not addToExisting then
        COL.recipeName = recipeInfo.name or "Unknown"
        AddToRecentRecipes(recipeID, COL.recipeName)   -- COH-008
    else
        COL.recipeName = "Multiple Recipes"
    end

    local recipeSchematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
    if not recipeSchematic or not recipeSchematic.reagentSlotSchematics then
        return false
    end

    local existingByName   = {}
    local existingByItemID = {}
    for i, mat in ipairs(COL.materialList) do
        existingByName[mat.name] = i
        if mat.reagents and mat.reagents[1] and mat.reagents[1].itemID then
            existingByItemID[mat.reagents[1].itemID] = i
        end
    end

    for _, reagentSlot in ipairs(recipeSchematic.reagentSlotSchematics) do
        if reagentSlot.reagents and reagentSlot.reagentType == Enum.CraftingReagentType.Basic
            and reagentSlot.quantityRequired and reagentSlot.quantityRequired > 0 then
            local firstReagent = reagentSlot.reagents[1]
            if firstReagent and firstReagent.itemID then
                local itemName = C_Item.GetItemNameByID(firstReagent.itemID)
                local itemIcon = C_Item.GetItemIconByID(firstReagent.itemID)

                if not itemName then
                    C_Item.RequestLoadItemDataByID(firstReagent.itemID)
                    itemName = "Loading..."
                end

                local displayName = itemName:gsub(" %|A.-|a$", "")

                local existingIdx = existingByItemID[firstReagent.itemID]
                    or (displayName ~= "Loading..." and existingByName[displayName])

                if existingIdx then
                    COL.materialList[existingIdx].needed = COL.materialList[existingIdx].needed + reagentSlot.quantityRequired
                elseif #COL.materialList < MAX_ITEMS then
                    table.insert(COL.materialList, {
                        name        = displayName,
                        icon        = itemIcon or 134400,
                        needed      = reagentSlot.quantityRequired,
                        reagents    = reagentSlot.reagents,
                        manualCheck = false,
                    })
                    existingByName[displayName]              = #COL.materialList
                    existingByItemID[firstReagent.itemID]    = #COL.materialList
                end
            end
        end
    end

    SortMaterials()
    return #COL.materialList > 0
end

-- ============================================================================
-- Progress Helpers
-- ============================================================================

local function GetProgressInfo()
    local total      = #COL.materialList
    local complete   = 0
    local totalNeeded = 0
    local totalOwned  = 0

    for _, mat in ipairs(COL.materialList) do
        local needed = GetNeeded(mat)
        local owned  = GetOwnedForMaterial(mat)
        totalNeeded = totalNeeded + needed
        totalOwned  = totalOwned + math.min(owned, needed)
        if owned >= needed then
            complete = complete + 1
        end
    end

    return total, complete, totalNeeded, totalOwned
end

-- ============================================================================
-- Helpers
-- ============================================================================

-- Returns the recipe ID currently shown in any open professions/order window.
-- Only reads from a window that is currently visible; stale transactions linger
-- on hidden frames and would return the wrong recipe ID.
local function GetCurrentRecipeID()
    if ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame:IsShown()
       and ProfessionsCustomerOrdersFrame.Form
       and ProfessionsCustomerOrdersFrame.Form.transaction then
        return ProfessionsCustomerOrdersFrame.Form.transaction.recipeID
    end
    if ProfessionsFrame and ProfessionsFrame:IsShown()
       and ProfessionsFrame.CraftingPage
       and ProfessionsFrame.CraftingPage.SchematicForm
       and ProfessionsFrame.CraftingPage.SchematicForm.transaction then
        return ProfessionsFrame.CraftingPage.SchematicForm.transaction.recipeID
    end
    return nil
end

-- ============================================================================
-- Main Frame UI
-- ============================================================================

local function CreateMainFrame()
    if COL.mainFrame then return COL.mainFrame end

    -- COH-008: Recent row added at y=-68; all controls below shift down 34px. Frame 460->494.
    -- COH-016/018: Frame widened to 400px to fit 6 bottom buttons (Export + Import).
    -- Get Materials button (7th): Frame widened to 500px; 7 buttons × ~66px avg + 6×4 gaps = 484px usable.
    local frame = CreateFrame("Frame", "COL_MainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(540, 494)
    frame:SetPoint("CENTER", UIParent, "CENTER", 400, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        COL.settings.framePos = { point, relPoint, x, y }
    end)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 1)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    -- Solid background fill to guarantee opacity
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT",     4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    bg:SetColorTexture(0.1, 0.1, 0.1, 1)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT",  4, -4)
    titleBar:SetPoint("TOPRIGHT", -4, -4)
    titleBar:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    titleBar:SetBackdropColor(0.2, 0.2, 0.2, 1)

    local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(20, 20)
    titleIcon:SetPoint("LEFT", 6, 0)
    titleIcon:SetTexture("Interface\\AddOns\\CraftOrderList\\Icon")

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleIcon, "RIGHT", 4, 0)
    title:SetText("Craft Order List")
    title:SetTextColor(unpack(COLORS.header))

    local version = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("RIGHT", -106, 0)
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or ""))
    version:SetTextColor(0.5, 0.5, 0.5)

    -- COH-018: Settings button in title bar
    local settingsBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    settingsBtn:SetSize(68, 22)
    settingsBtn:SetPoint("RIGHT", titleBar, "RIGHT", -34, 0)
    settingsBtn:SetText("Settings")
    settingsBtn:SetScript("OnClick", function()
        if COL.settingsFrame then
            if COL.settingsFrame:IsShown() then
                COL.settingsFrame:Hide()
            else
                COL.settingsFrame:Show()
            end
        end
    end)

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Recipe name (y ~ -38, unchanged)
    local recipeName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recipeName:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 8, -6)
    recipeName:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    recipeName:SetHeight(14)
    recipeName:SetJustifyH("LEFT")
    frame.recipeName = recipeName

    -- COH-008: Recent Recipes row (y = -68)
    local recentLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recentLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -68)
    recentLabel:SetText("Recent:")
    recentLabel:SetTextColor(0.7, 0.7, 0.7)

    local recentDropdown = CreateFrame("Frame", "COL_RecentDropdown", frame, "UIDropDownMenuTemplate")
    recentDropdown:SetPoint("LEFT", recentLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(recentDropdown, 155)
    UIDropDownMenu_SetText(recentDropdown, "Select recipe...")
    UIDropDownMenu_Initialize(recentDropdown, function(self, level)
        if #COL.recentRecipes == 0 then
            local info    = UIDropDownMenu_CreateInfo()
            info.text     = "No recent recipes"
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
            return
        end
        for _, entry in ipairs(COL.recentRecipes) do
            local info  = UIDropDownMenu_CreateInfo()
            info.text   = entry.name
            info.value  = entry.id
            info.func   = function()
                UIDropDownMenu_SetText(recentDropdown, entry.name)
                if BuildMaterialList(entry.id, false) then
                    COL:UpdateMainFrame()
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    frame.recentDropdown = recentDropdown

    -- Controls row 1 (y = -100, shifted from -66 by COH-008)
    local qualityLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    qualityLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -100)
    qualityLabel:SetText("Quality:")
    qualityLabel:SetTextColor(0.7, 0.7, 0.7)

    local qualityDropdown = CreateFrame("Frame", "COL_QualityDropdown", frame, "UIDropDownMenuTemplate")
    qualityDropdown:SetPoint("LEFT", qualityLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(qualityDropdown, 65)
    UIDropDownMenu_SetText(qualityDropdown, QUALITY_ICONS[0])
    local qdText = qualityDropdown.Text or _G[qualityDropdown:GetName() .. "Text"]
    if qdText then
        qdText:ClearAllPoints()
        qdText:SetPoint("CENTER", qualityDropdown, "CENTER", -8, 1)
        qdText:SetJustifyH("CENTER")
    end
    UIDropDownMenu_Initialize(qualityDropdown, function(self, level)
        for i = 0, 3 do
            local info     = UIDropDownMenu_CreateInfo()
            info.text      = QUALITY_ICONS[i]
            info.value     = i
            info.justifyH  = "CENTER"
            info.func      = function()
                COL.settings.qualityFilter = i
                UIDropDownMenu_SetText(qualityDropdown, QUALITY_ICONS[i])
                COL:UpdateMainFrame()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    frame.qualityDropdown = qualityDropdown

    local sortLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sortLabel:SetPoint("LEFT", qualityLabel, "LEFT", 155, 0)
    sortLabel:SetText("Sort:")
    sortLabel:SetTextColor(0.7, 0.7, 0.7)

    -- COH-013: Added "Source" option to the sort dropdown
    local SORT_LABELS = { name = "Name", needed = "Amount", status = "Completion", source = "Source" }

    local sortDropdown = CreateFrame("Frame", "COL_SortDropdown", frame, "UIDropDownMenuTemplate")
    sortDropdown:SetPoint("LEFT", sortLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(sortDropdown, 95)
    UIDropDownMenu_SetText(sortDropdown, SORT_LABELS[COL.settings.sortBy] or "Name")
    UIDropDownMenu_Initialize(sortDropdown, function(self, level)
        local options = {
            { "name",   "Name"       },
            { "needed", "Amount"     },
            { "status", "Completion" },
            { "source", "Source"     },   -- COH-013
        }
        for _, opt in ipairs(options) do
            local info  = UIDropDownMenu_CreateInfo()
            info.text   = opt[2]
            info.value  = opt[1]
            info.func   = function()
                COL.settings.sortBy = opt[1]
                UIDropDownMenu_SetText(sortDropdown, opt[2])
                SortMaterials()
                COL:UpdateMainFrame()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    frame.SORT_LABELS = SORT_LABELS

    -- Controls row 2 (y = -126, shifted from -92 by COH-008)
    local hideCheck = CreateFrame("CheckButton", "COL_HideCompleted", frame, "UICheckButtonTemplate")
    hideCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -126)
    hideCheck:SetSize(24, 24)
    hideCheck.text:SetText("Hide Done")
    hideCheck:SetScript("OnClick", function(self)
        COL.settings.hideCompleted = self:GetChecked()
        COL:UpdateMainFrame()
    end)
    hideCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Hide Done", 1, 1, 1)
        GameTooltip:AddLine("Hide materials you already have enough of.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    hideCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local craftLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    craftLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -68, -131)  -- shifted from -97
    craftLabel:SetText("Craft amount:")
    craftLabel:SetTextColor(0.7, 0.7, 0.7)

    local craftDown = CreateFrame("Button", nil, frame)
    craftDown:SetSize(16, 16)
    craftDown:SetPoint("LEFT", craftLabel, "RIGHT", 4, 0)
    craftDown:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    craftDown:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    craftDown:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local craftValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    craftValue:SetPoint("LEFT", craftDown, "RIGHT", 2, 0)
    craftValue:SetWidth(22)
    craftValue:SetJustifyH("CENTER")
    craftValue:SetText("1")
    craftValue:SetTextColor(1, 1, 1)
    frame.craftValue = craftValue

    local craftUp = CreateFrame("Button", nil, frame)
    craftUp:SetSize(16, 16)
    craftUp:SetPoint("LEFT", craftValue, "RIGHT", 2, 0)
    craftUp:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    craftUp:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    craftUp:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local function UpdateCraftCount(val)
        if val < 1   then val = 1   end
        if val > 999 then val = 999 end
        COL.settings.craftCount = val
        craftValue:SetText(tostring(val))
        COL:UpdateMainFrame()
    end

    craftDown:SetScript("OnClick", function() UpdateCraftCount(COL.settings.craftCount - 1) end)
    craftUp:SetScript("OnClick",   function() UpdateCraftCount(COL.settings.craftCount + 1) end)

    -- Progress bar (y = -154, shifted from -120 by COH-008)
    local progressBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    progressBg:SetHeight(14)
    progressBg:SetPoint("TOPLEFT", 8, -154)
    progressBg:SetPoint("RIGHT", -8, 0)
    progressBg:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    progressBg:SetBackdropColor(0.15, 0.15, 0.15, 1)

    local progressBar = progressBg:CreateTexture(nil, "ARTWORK")
    progressBar:SetPoint("TOPLEFT",    1, -1)
    progressBar:SetPoint("BOTTOMLEFT", 1,  1)
    progressBar:SetWidth(1)
    progressBar:SetColorTexture(0.2, 0.8, 0.2, 0.8)
    frame.progressBar = progressBar
    frame.progressBg  = progressBg

    local progressText = progressBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("CENTER", 0, 0)
    progressText:SetTextColor(1, 1, 1)
    frame.progressText = progressText

    -- Scroll frame (y = -172, shifted from -138 by COH-008)
    local scrollFrame = CreateFrame("ScrollFrame", "COL_ScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     8, -172)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 60)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(504)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    frame.content     = content
    frame.scrollFrame = scrollFrame

    -- Summary line
    local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summary:SetPoint("BOTTOMLEFT", 8,  36)
    summary:SetPoint("RIGHT",     -8,   0)
    summary:SetJustifyH("LEFT")
    summary:SetTextColor(0.7, 0.7, 0.7)
    frame.summary = summary

    -- Bottom buttons — width is auto-sized to text + 16px padding so every button
    -- has the same internal spacing regardless of label length.
    local function SizeBtn(btn)
        local fs = btn:GetFontString()
        if fs then btn:SetWidth(fs:GetStringWidth() + 16) end
    end

    -- Get Materials button: loads the recipe currently open in the crafting window
    local getMatsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    getMatsBtn:SetHeight(22)
    getMatsBtn:SetPoint("BOTTOMLEFT", 8, 8)
    getMatsBtn:SetText("Get Materials")
    SizeBtn(getMatsBtn)
    getMatsBtn:SetScript("OnClick", function()
        local recipeID = GetCurrentRecipeID()
        if recipeID then
            local addToExisting = #COL.materialList > 0
            if BuildMaterialList(recipeID, addToExisting) then
                COL:UpdateMainFrame()
                if addToExisting then
                    print("|cFFFFCC00COL:|r Added to material list.")
                else
                    print("|cFFFFCC00COL:|r Material list ready!")
                end
            else
                print("|cFFFFCC00COL:|r No basic materials found.")
            end
        else
            print("|cFFFFCC00COL:|r No recipe selected in the crafting window.")
        end
    end)
    getMatsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Get Materials", 1, 1, 1)
        GameTooltip:AddLine("Load the recipe currently open in the crafting window.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    getMatsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local searchNextBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    searchNextBtn:SetHeight(22)
    searchNextBtn:SetPoint("LEFT", getMatsBtn, "RIGHT", 4, 0)
    searchNextBtn:SetText("Search Next")
    SizeBtn(searchNextBtn)
    searchNextBtn:SetScript("OnClick", function() COL:SearchNextMaterial() end)
    searchNextBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Search Next Material", 1, 1, 1)
        GameTooltip:AddLine("Searches the AH for the next material you still need.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    searchNextBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.searchNextBtn = searchNextBtn

    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetHeight(22)
    clearBtn:SetPoint("LEFT", searchNextBtn, "RIGHT", 4, 0)
    clearBtn:SetText("Clear")
    SizeBtn(clearBtn)
    clearBtn.confirmPending = false
    clearBtn:SetScript("OnClick", function(self)
        if self.confirmPending then
            COL.materialList   = {}
            COL.recipeName     = ""
            COL.searchIndex    = 0
            completionNotified = false   -- COH-009
            COL:UpdateMainFrame()
            self.confirmPending = false
            self:SetText("Clear")
            SizeBtn(self)
        else
            self.confirmPending = true
            self:SetText("Confirm?")
            SizeBtn(self)
            C_Timer.After(3, function()
                if self.confirmPending then
                    self.confirmPending = false
                    self:SetText("Clear")
                    SizeBtn(self)
                end
            end)
        end
    end)
    clearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Clear List", 1, 1, 1)
        GameTooltip:AddLine("Remove all materials from the shopping list.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    clearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local uncheckBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    uncheckBtn:SetHeight(22)
    uncheckBtn:SetPoint("LEFT", clearBtn, "RIGHT", 4, 0)
    uncheckBtn:SetText("Reset")
    SizeBtn(uncheckBtn)
    uncheckBtn:SetScript("OnClick", function()
        for _, mat in ipairs(COL.materialList) do
            mat.manualCheck = false
        end
        COL.searchIndex = 0
        COL:UpdateMainFrame()
    end)
    uncheckBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Reset", 1, 1, 1)
        GameTooltip:AddLine("Unmark all manually checked items and restart the Search Next cycle.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    uncheckBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    copyBtn:SetHeight(22)
    copyBtn:SetPoint("LEFT", uncheckBtn, "RIGHT", 4, 0)
    copyBtn:SetText("Copy")
    SizeBtn(copyBtn)
    copyBtn:SetScript("OnClick", function() COL:CopyListToChat() end)
    copyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Copy to Chat", 1, 1, 1)
        GameTooltip:AddLine("Copy missing materials to chat or clipboard.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    copyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- COH-010/016: Export + Import buttons
    local exportBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    exportBtn:SetHeight(22)
    exportBtn:SetPoint("LEFT", copyBtn, "RIGHT", 4, 0)
    exportBtn:SetText("Export")
    SizeBtn(exportBtn)
    exportBtn:SetScript("OnClick", function() COL:ExportList() end)
    exportBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Export List", 1, 1, 1)
        GameTooltip:AddLine("Copies a shareable export string (Ctrl+C).", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    exportBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- COH-016: Import button
    local importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    importBtn:SetHeight(22)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 4, 0)
    importBtn:SetText("Import")
    SizeBtn(importBtn)
    importBtn:SetScript("OnClick", function() COL:ShowImportDialog() end)
    importBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Import List", 1, 1, 1)
        GameTooltip:AddLine("Restore a material list from an export string.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    importBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Remove from UISpecialFrames when hidden so stale escape registrations don't linger
    frame:SetScript("OnHide", function()
        for i, name in ipairs(UISpecialFrames) do
            if name == "COL_MainFrame" then
                tremove(UISpecialFrames, i)
                return
            end
        end
    end)

    frame:Hide()
    COL.mainFrame = frame
    return frame
end

-- ============================================================================
-- Settings Panel (COH-018)
-- ============================================================================

local function CreateSettingsPanel()
    local sf = CreateFrame("Frame", "COL_SettingsFrame", COL.mainFrame, "BackdropTemplate")
    sf:SetSize(220, 142)
    sf:SetPoint("TOPLEFT", COL.mainFrame, "TOPRIGHT", 5, 0)
    sf:SetFrameStrata("HIGH")
    sf:SetClampedToScreen(true)
    sf:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    sf:SetBackdropColor(0.1, 0.1, 0.1, 1)
    sf:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    local sfBg = sf:CreateTexture(nil, "BACKGROUND")
    sfBg:SetPoint("TOPLEFT",     4, -4)
    sfBg:SetPoint("BOTTOMRIGHT", -4,  4)
    sfBg:SetColorTexture(0.1, 0.1, 0.1, 1)

    local sfTitle = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sfTitle:SetPoint("TOPLEFT", 10, -8)
    sfTitle:SetText("Settings")
    sfTitle:SetTextColor(1, 0.82, 0)

    local sfClose = CreateFrame("Button", nil, sf, "UIPanelCloseButton")
    sfClose:SetPoint("TOPRIGHT", 4, 4)
    sfClose:SetScript("OnClick", function() sf:Hide() end)

    -- COH-017: Hide minimap button toggle
    local hideMapCheck = CreateFrame("CheckButton", "COL_HideMinimapCheck", sf, "UICheckButtonTemplate")
    hideMapCheck:SetSize(24, 24)
    hideMapCheck:SetPoint("TOPLEFT", sf, "TOPLEFT", 8, -26)
    hideMapCheck.text:SetText("Hide minimap button")
    hideMapCheck.text:SetTextColor(0.7, 0.7, 0.7)
    hideMapCheck:SetScript("OnClick", function(self)
        COL.settings.minimapHidden = self:GetChecked()
        if COL.minimapButton then
            if COL.settings.minimapHidden then
                COL.minimapButton:Hide()
            else
                COL.minimapButton:Show()
            end
        end
    end)

    -- COH-018: Auto-dock to AH toggle
    local ahDockCheck = CreateFrame("CheckButton", "COL_AHDockCheck", sf, "UICheckButtonTemplate")
    ahDockCheck:SetSize(24, 24)
    ahDockCheck:SetPoint("TOPLEFT", sf, "TOPLEFT", 8, -52)
    ahDockCheck.text:SetText("Auto-dock to AH")
    ahDockCheck.text:SetTextColor(0.7, 0.7, 0.7)
    ahDockCheck:SetScript("OnClick", function(self)
        COL.settings.ahAutoDock = self:GetChecked()
    end)

    -- Auto-load selected recipe toggle
    local autoLoadCheck = CreateFrame("CheckButton", "COL_AutoLoadCheck", sf, "UICheckButtonTemplate")
    autoLoadCheck:SetSize(24, 24)
    autoLoadCheck:SetPoint("TOPLEFT", sf, "TOPLEFT", 8, -78)
    autoLoadCheck.text:SetText("Auto-load selected recipe")
    autoLoadCheck.text:SetTextColor(0.7, 0.7, 0.7)
    autoLoadCheck:SetScript("OnClick", function(self)
        COL.settings.autoOpenOnRecipe = self:GetChecked()
    end)

    -- Auto-close with recipe window toggle
    local autoCloseCheck = CreateFrame("CheckButton", "COL_AutoCloseCheck", sf, "UICheckButtonTemplate")
    autoCloseCheck:SetSize(24, 24)
    autoCloseCheck:SetPoint("TOPLEFT", sf, "TOPLEFT", 8, -104)
    autoCloseCheck.text:SetText("Close with recipe window")
    autoCloseCheck.text:SetTextColor(0.7, 0.7, 0.7)
    autoCloseCheck:SetScript("OnClick", function(self)
        COL.settings.autoCloseOnRecipe = self:GetChecked()
    end)

    sf:Hide()
    COL.settingsFrame = sf
end

-- ============================================================================
-- Material Rows
-- ============================================================================

local function CreateMaterialRow(parent, index)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(32)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * 34))
    row:SetPoint("RIGHT", 0, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.1)
    row.highlight:Hide()

    -- COH-011 + COH-012 + COH-014: merged tooltip handler
    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
        if self.itemID then
            local mat = COL.materialList[self.matIndex]

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)

            -- COH-012: Quality breakdown (only when multiple tiers exist)
            if mat and mat.reagents and #mat.reagents > 1 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Quality tiers:", 1, 1, 1)
                for i = 1, 3 do
                    local r = mat.reagents[i]
                    if r and r.itemID then
                        local tierName  = C_Item.GetItemNameByID(r.itemID) or "Loading..."
                        local tierOwned = GetItemCountByQuality(r.itemID)
                        GameTooltip:AddLine(
                            QUALITY_ICONS[i] .. " " .. tierName .. " (" .. tierOwned .. " owned)",
                            0.8, 0.8, 0.8
                        )
                    end
                end
            end

            -- COH-011: Reagent source
            if mat then
                local baseID = mat.reagents and mat.reagents[1] and mat.reagents[1].itemID
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Source: " .. GetReagentSource(baseID), 0.7, 0.7, 0.7)
            end

            -- COH-014: Substitution hint
            if mat and HasSubstitution(mat) then
                local filter = COL.settings.qualityFilter
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Substitution available:", 1, 0.7, 0)
                for i = 1, 3 do
                    if i ~= filter and mat.reagents and mat.reagents[i] and mat.reagents[i].itemID then
                        local tierOwned = GetItemCountByQuality(mat.reagents[i].itemID)
                        if tierOwned > 0 then
                            local tierName = C_Item.GetItemNameByID(mat.reagents[i].itemID) or "Loading..."
                            GameTooltip:AddLine(
                                QUALITY_ICONS[i] .. " " .. tierName .. ": " .. tierOwned .. " owned",
                                0.8, 0.8, 0.8
                            )
                        end
                    end
                end
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Right-click to toggle checkmark", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip:Hide()
    end)

    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.matIndex then
            local mat = COL.materialList[self.matIndex]
            if mat then
                mat.manualCheck = not mat.manualCheck
                COL:UpdateMainFrame()
            end
        end
    end)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 2, 0)
    row.icon = icon

    local checkmark = row:CreateTexture(nil, "OVERLAY")
    checkmark:SetSize(18, 18)
    checkmark:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 4, -4)
    checkmark:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    checkmark:Hide()
    row.checkmark = checkmark

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    name:SetPoint("RIGHT", -158, 0)   -- shortened by 13px to leave room for subIcon
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = name

    -- COH-014: substitution indicator (amber "~" sits between name and count)
    -- Name ends at RIGHT -158; subIcon RIGHT -145 (12px wide) gives a clean 1px gap.
    -- Count starts at RIGHT -140 — 5px gap between subIcon and count.
    local subIcon = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subIcon:SetPoint("RIGHT", row, "RIGHT", -145, 0)
    subIcon:SetWidth(12)
    subIcon:SetJustifyH("CENTER")
    subIcon:SetText("~")
    subIcon:SetTextColor(1, 0.7, 0)
    subIcon:Hide()
    row.subIcon = subIcon

    local count = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    count:SetPoint("RIGHT", -90, 0)
    count:SetWidth(50)
    count:SetJustifyH("RIGHT")
    row.count = count

    local searchBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    searchBtn:SetSize(80, 22)
    searchBtn:SetPoint("RIGHT", -4, 0)
    searchBtn:SetText("Search AH")
    searchBtn:SetScript("OnClick", function()
        local mat = COL.materialList[row.matIndex]
        if mat then
            local searchName = GetSearchName(mat)
            if not searchName then
                print("|cFFFFCC00COL:|r Item data still loading, try again in a moment.")
                return
            end
            COL:SearchAuctionHouse(searchName)
            COL:UpdateMainFrame()
        end
    end)
    row.searchBtn = searchBtn

    return row
end

-- ============================================================================
-- Frame Updates
-- ============================================================================

function COL:UpdateMainFrame()
    local frame = COL.mainFrame
    if not frame then return end

    frame.recipeName:SetText(COL.recipeName ~= "" and COL.recipeName or "No recipe selected")

    for _, row in ipairs(COL.rows) do
        row:Hide()
    end

    -- Progress
    local total, complete, totalNeeded, totalOwned = GetProgressInfo()
    if total > 0 then
        local pct      = totalOwned / totalNeeded
        local barWidth = math.max(1, (frame.progressBg:GetWidth() - 2) * pct)
        frame.progressBar:SetWidth(barWidth)

        if pct >= 1 then
            frame.progressBar:SetColorTexture(0.2, 0.8, 0.2, 0.8)
        elseif pct >= 0.5 then
            frame.progressBar:SetColorTexture(1, 1, 0.2, 0.8)
        else
            frame.progressBar:SetColorTexture(1, 0.3, 0.3, 0.8)
        end

        frame.progressText:SetText(string.format("%d/%d materials complete", complete, total))
        frame.progressBg:Show()

        -- COH-009: one-shot all-materials-ready notification
        if not completionNotified and totalOwned >= totalNeeded then
            completionNotified = true
            print("|cFFFFCC00COL:|r |cFF33FF33All materials gathered for " .. COL.recipeName .. "!|r")
            if UIErrorsFrame then
                UIErrorsFrame:AddMessage(
                    "Materials ready: " .. COL.recipeName,
                    0.2, 1.0, 0.2, 1.0, 3
                )
            end
        end
    else
        frame.progressBg:Hide()
    end

    -- Build rows
    local content  = frame.content
    local rowIndex = 0

    for i, mat in ipairs(COL.materialList) do
        local needed     = GetNeeded(mat)
        local owned      = GetOwnedForMaterial(mat)
        local isComplete = owned >= needed

        if not (COL.settings.hideCompleted and isComplete) then
            rowIndex = rowIndex + 1

            local row = COL.rows[rowIndex]
            if not row then
                row = CreateMaterialRow(content, rowIndex)
                COL.rows[rowIndex] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * 34))
            row:SetPoint("RIGHT", 0, 0)

            if not row.icon or not row.name or not row.count or not row.searchBtn then
                break
            end

            local displayID = mat.reagents and mat.reagents[1] and mat.reagents[1].itemID
            if COL.settings.qualityFilter > 0 and mat.reagents and mat.reagents[COL.settings.qualityFilter] then
                displayID = mat.reagents[COL.settings.qualityFilter].itemID
            end

            row.itemID   = displayID
            row.matIndex = i
            row.icon:SetTexture(displayID and C_Item.GetItemIconByID(displayID) or mat.icon)
            row.name:SetText(mat.name or "Unknown")

            local color
            if isComplete then
                color = COLORS.have
            elseif owned > 0 then
                color = COLORS.partial
            else
                color = COLORS.need
            end

            row.count:SetText(string.format("%d/%d", owned, needed))
            row.count:SetTextColor(unpack(color))
            row.name:SetTextColor(unpack(color))

            if mat.manualCheck or isComplete then
                row.checkmark:Show()
            else
                row.checkmark:Hide()
            end

            -- COH-014: show/hide substitution indicator
            if row.subIcon then
                if HasSubstitution(mat) then
                    row.subIcon:Show()
                else
                    row.subIcon:Hide()
                end
            end

            row:Show()
        end
    end

    content:SetHeight(math.max(1, rowIndex * 34))

    -- Summary line
    if total > 0 then
        local missing     = total - complete
        local hiddenCount = COL.settings.hideCompleted and complete or 0
        if missing == 0 then
            frame.summary:SetText("All materials collected!")
            frame.summary:SetTextColor(unpack(COLORS.have))
        elseif hiddenCount > 0 then
            frame.summary:SetText(string.format(
                "Still need %d material%s (%d hidden)", missing, missing == 1 and "" or "s", hiddenCount
            ))
            frame.summary:SetTextColor(0.7, 0.7, 0.7)
        else
            frame.summary:SetText(string.format(
                "Still need %d material%s", missing, missing == 1 and "" or "s"
            ))
            frame.summary:SetTextColor(0.7, 0.7, 0.7)
        end
    else
        frame.summary:SetText("Click 'Get Materials' in a recipe window to load the list")
        frame.summary:SetTextColor(unpack(COLORS.dim))
    end

    -- Craft count display
    if frame.craftValue then
        frame.craftValue:SetText(tostring(COL.settings.craftCount))
    end
end

-- ============================================================================
-- Auction House Integration
-- ============================================================================

function COL:SearchAuctionHouse(itemName)
    if not itemName then return end
    itemName = itemName:gsub("^%d+%s+", "")

    if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
        local searchBar = AuctionHouseFrame.SearchBar
        if searchBar and searchBar.SearchBox then
            -- Set text without HighlightText() — calling HighlightText() focuses the
            -- EditBox which fires WoW's internal debounce timer, causing a second search
            -- query a few seconds later. On the Auctioneer mount this disrupts the NPC
            -- interaction and dismounts the player. Just set the text and click once.
            searchBar.SearchBox:SetText(itemName)
            if searchBar.SearchButton and searchBar.SearchButton:IsEnabled() then
                searchBar.SearchButton:Click()
            end
        else
            print("|cFFFFCC00COL:|r Search bar not available.")
        end
    else
        print("|cFFFFCC00COL:|r Open the Auction House to search.")
    end
end

function COL:SearchNextMaterial()
    local n = #COL.materialList
    if n == 0 then
        print("|cFFFFCC00COL:|r No materials in list.")
        return
    end

    -- Cycle from current position, wrapping around.
    -- Skips only items the player already owns enough of.
    for offset = 1, n do
        local i   = (COL.searchIndex + offset - 1) % n + 1
        local mat = COL.materialList[i]
        if GetOwnedForMaterial(mat) < GetNeeded(mat) then
            local searchName = GetSearchName(mat)
            if searchName then
                COL:SearchAuctionHouse(searchName)
                COL.searchIndex = i
                COL:UpdateMainFrame()
                return
            end
        end
    end

    print("|cFFFFCC00COL:|r You have all materials!")
end

function COL:CopyListToChat()
    if #COL.materialList == 0 then
        print("|cFFFFCC00COL:|r No materials in list.")
        return
    end

    local parts = {}
    for _, mat in ipairs(COL.materialList) do
        local needed = GetNeeded(mat)
        local owned  = GetOwnedForMaterial(mat)
        local need   = needed - owned
        if need > 0 then
            table.insert(parts, need .. "x " .. mat.name)
        end
    end

    if #parts == 0 then
        print("|cFFFFCC00COL:|r You have all materials!")
        return
    end

    local text = "Need: " .. table.concat(parts, ", ")

    local chatBox = ChatFrame1EditBox
    if chatBox and chatBox:IsShown() then
        chatBox:Insert(text)
        print("|cFFFFCC00COL:|r Pasted into chat.")
        return
    end

    if not COL.editBox then
        local eb = CreateFrame("EditBox", "COL_CopyBox", UIParent, "InputBoxTemplate")
        eb:SetSize(400, 30)
        eb:SetPoint("TOP", 0, -100)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function(self) self:Hide() end)
        eb:SetScript("OnEnterPressed",  function(self) self:Hide() end)
        eb:Hide()
        COL.editBox = eb
    end

    COL.editBox:SetText(text)
    COL.editBox:Show()
    COL.editBox:HighlightText()
    COL.editBox:SetFocus()
    print("|cFFFFCC00COL:|r Press Ctrl+C to copy, then Escape to close.")
end

-- COH-010: Export the current list as a reimportable string
function COL:ExportList()
    if #COL.materialList == 0 then
        print("|cFFFFCC00COL:|r No materials to export.")
        return
    end

    local parts = { "COL1", COL.recipeName }
    for _, mat in ipairs(COL.materialList) do
        local itemID = (mat.reagents and mat.reagents[1] and mat.reagents[1].itemID) or 0
        table.insert(parts, mat.name .. ":" .. mat.needed .. ":" .. itemID)
    end
    local exportStr = table.concat(parts, "|")

    if not COL.editBox then
        local eb = CreateFrame("EditBox", "COL_CopyBox", UIParent, "InputBoxTemplate")
        eb:SetSize(400, 30)
        eb:SetPoint("TOP", 0, -100)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function(self) self:Hide() end)
        eb:Hide()
        COL.editBox = eb
    end

    COL.editBox:SetScript("OnEnterPressed", function(self) self:Hide() end)
    COL.editBox:SetText(exportStr)
    COL.editBox:Show()
    COL.editBox:HighlightText()
    COL.editBox:SetFocus()
    print("|cFFFFCC00COL:|r Press Ctrl+C to copy, then Escape to close.")
end

-- COH-016: Show the import EditBox (empty, ready for paste)
function COL:ShowImportDialog()
    if not COL.editBox then
        local eb = CreateFrame("EditBox", "COL_CopyBox", UIParent, "InputBoxTemplate")
        eb:SetSize(400, 30)
        eb:SetPoint("TOP", 0, -100)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function(self) self:Hide() end)
        eb:Hide()
        COL.editBox = eb
    end
    COL.editBox:SetText("")
    COL.editBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText():trim()
        if text ~= "" then COL:ImportList(text) end
        self:Hide()
    end)
    COL.editBox:Show()
    COL.editBox:SetFocus()
    print("|cFFFFCC00COL:|r Paste your export string and press Enter.")
end

-- COH-010: Import a list from an export string
function COL:ImportList(exportStr)
    if not exportStr or exportStr == "" then
        print("|cFFFFCC00COL:|r Usage: /col import <export string>")
        return
    end

    local parts = {}
    for part in exportStr:gmatch("[^|]+") do
        table.insert(parts, part)
    end

    if parts[1] ~= "COL1" then
        print("|cFFFFCC00COL:|r Invalid export string (must start with COL1).")
        return
    end

    local recipeName = parts[2] or "Imported"
    local newList    = {}

    for i = 3, #parts do
        local name, needed, itemID = parts[i]:match("^(.+):(%d+):(%d+)$")
        if name and needed and itemID then
            local id = tonumber(itemID)
            table.insert(newList, {
                name        = name,
                icon        = (id and id > 0 and C_Item.GetItemIconByID(id)) or 134400,
                needed      = tonumber(needed),
                reagents    = (id and id > 0) and { { itemID = id } } or {},
                manualCheck = false,
            })
        end
    end

    if #newList == 0 then
        print("|cFFFFCC00COL:|r No valid materials found in export string.")
        return
    end

    COL.materialList   = newList
    COL.recipeName     = recipeName
    COL.searchIndex    = 0
    completionNotified = false   -- COH-009
    COL:ShowFrame()
    COL:UpdateMainFrame()
    print("|cFFFFCC00COL:|r Imported " .. #newList .. " materials for " .. recipeName .. ".")
end

-- ============================================================================
-- Frame Visibility
-- ============================================================================

function COL:ToggleFrame()
    local frame = COL.mainFrame or CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        COL:UpdateMainFrame()
    end
end

function COL:ShowFrame()
    local frame = COL.mainFrame or CreateMainFrame()
    frame:Show()
    COL:UpdateMainFrame()
end

function COL:DockToAuctionHouse()
    if not COL.mainFrame or not AuctionHouseFrame then return end
    if not COL.settings.ahAutoDock then return end   -- COH-018
    if COL.settings.framePos then return end

    COL.mainFrame:ClearAllPoints()
    COL.mainFrame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 5, 0)
end

function COL:DockToProfessionsFrame()
    if not COL.mainFrame or not ProfessionsFrame then return end
    if not COL.settings.autoOpenOnRecipe then return end
    -- Always snap next to the frame when auto-open is active; no framePos guard.
    COL.mainFrame:ClearAllPoints()
    COL.mainFrame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 5, 0)
end

function COL:DockToCraftingOrdersFrame()
    if not COL.mainFrame or not ProfessionsCustomerOrdersFrame then return end
    if not COL.settings.autoOpenOnRecipe then return end
    COL.mainFrame:ClearAllPoints()
    COL.mainFrame:SetPoint("TOPLEFT", ProfessionsCustomerOrdersFrame, "TOPRIGHT", 5, 0)
end

-- Transiently register COL_MainFrame in UISpecialFrames so the next Escape press
-- closes it. Called when a recipe window closes while COL is still visible.
local function RegisterCOLForEscape()
    if not COL.mainFrame or not COL.mainFrame:IsShown() then return end
    for _, name in ipairs(UISpecialFrames) do
        if name == "COL_MainFrame" then return end
    end
    tinsert(UISpecialFrames, "COL_MainFrame")
end

local function UnregisterCOLFromEscape()
    for i, name in ipairs(UISpecialFrames) do
        if name == "COL_MainFrame" then
            tremove(UISpecialFrames, i)
            return
        end
    end
end

-- Called when either recipe window closes (used by both TRADE_SKILL_CLOSE and
-- ProfessionsCustomerOrdersFrame OnHide).
local function OnRecipeWindowClosed()
    if not COL.mainFrame or not COL.mainFrame:IsShown() then return end
    if COL.settings.autoCloseOnRecipe then
        COL.mainFrame:Hide()
    else
        -- Let the next Escape press close COL without requiring the mouse.
        RegisterCOLForEscape()
    end
end

-- ============================================================================
-- Minimap Button
-- ============================================================================

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "COL_MinimapButton", Minimap)
    btn:SetSize(36, 36)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForDrag("LeftButton")

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(56, 56)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", 0, 0)

    local iconBg = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    iconBg:SetSize(28, 28)
    iconBg:SetPoint("CENTER", overlay, "TOPLEFT", 18, -18)
    iconBg:SetColorTexture(0, 0, 0, 1)

    local bgMask = btn:CreateMaskTexture()
    bgMask:SetSize(28, 28)
    bgMask:SetPoint("CENTER", overlay, "TOPLEFT", 18, -18)
    bgMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    iconBg:AddMaskTexture(bgMask)

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(28, 28)
    icon:SetPoint("CENTER", overlay, "TOPLEFT", 18, -18)
    icon:SetTexture("Interface\\AddOns\\CraftOrderList\\Icon")

    local mask = btn:CreateMaskTexture()
    mask:SetSize(28, 28)
    mask:SetPoint("CENTER", overlay, "TOPLEFT", 18, -18)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(28, 28)
    highlight:SetPoint("CENTER", overlay, "TOPLEFT", 18, -18)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    btn.icon = icon

    local angle = COL.settings.minimapAngle or 220
    local function UpdatePosition()
        local rad = math.rad(angle)
        local x   = math.cos(rad) * 80
        local y   = math.sin(rad) * 80
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    btn:SetScript("OnDragStart", function(self) self.dragging = true  end)
    btn:SetScript("OnDragStop",  function(self) self.dragging = false end)
    btn:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale  = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        angle  = math.deg(math.atan2(cy - my, cx - mx))
        COL.settings.minimapAngle = angle
        UpdatePosition()
    end)

    btn:SetScript("OnClick", function() COL:ToggleFrame() end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Craft Order List", 1, 0.82, 0)
        GameTooltip:AddLine("Click to toggle materials list.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Drag to reposition.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
    COL.minimapButton = btn
    if COL.settings.minimapHidden then btn:Hide() end   -- COH-017
end

-- ============================================================================
-- Integration Buttons
-- ============================================================================

local function CreateGetMaterialsButton(parent, getRecipeFunc)
    local parentName = parent:GetName() or ("COL_Anon_" .. tostring(parent))
    local buttonName = parentName .. "_COL_Btn"

    if COL.buttonsCreated[buttonName] then return COL.buttonsCreated[buttonName] end

    local btn = CreateFrame("Button", buttonName, parent, "UIPanelButtonTemplate")
    btn:SetSize(130, 22)
    btn:SetText("Get Materials List")
    btn:SetScript("OnClick", function()
        local recipeID = getRecipeFunc()
        if recipeID then
            local addToExisting = #COL.materialList > 0
            if BuildMaterialList(recipeID, addToExisting) then
                COL:ShowFrame()
                if addToExisting then
                    print("|cFFFFCC00COL:|r Added to material list.")
                else
                    print("|cFFFFCC00COL:|r Material list ready!")
                end
            else
                print("|cFFFFCC00COL:|r No basic materials found.")
            end
        else
            print("|cFFFFCC00COL:|r No recipe selected.")
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Get Materials List", 1, 1, 1)
        if #COL.materialList > 0 then
            GameTooltip:AddLine("Adds to existing list", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("Creates new shopping list", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    COL.buttonsCreated[buttonName] = btn
    return btn
end

local function SetupProfessionsButton()
    if not ProfessionsFrame or not ProfessionsFrame.CraftingPage then return end
    local craftingPage = ProfessionsFrame.CraftingPage

    local btn = CreateGetMaterialsButton(craftingPage, function()
        if craftingPage.SchematicForm and craftingPage.SchematicForm.transaction then
            return craftingPage.SchematicForm.transaction.recipeID
        end
        return nil
    end)

    if btn then
        if craftingPage.CreateAllButton then
            btn:SetPoint("RIGHT", craftingPage.CreateAllButton, "LEFT", -5, 0)
        elseif craftingPage.CreateButton then
            btn:SetPoint("RIGHT", craftingPage.CreateButton, "LEFT", -5, 0)
        else
            btn:SetPoint("BOTTOMLEFT", craftingPage, "BOTTOMLEFT", 10, 10)
        end
    end
end

-- Hooks SchematicForm.Init so that selecting a recipe can auto-open COL.
-- Safe to call multiple times; installs the hook only once.
local recipeHookInstalled = false
local function HookRecipeSelection()
    if recipeHookInstalled then return end
    if not ProfessionsFrame or not ProfessionsFrame.CraftingPage
       or not ProfessionsFrame.CraftingPage.SchematicForm then return end
    recipeHookInstalled = true
    hooksecurefunc(ProfessionsFrame.CraftingPage.SchematicForm, "Init", function(self, transaction)
        if not COL.settings.autoOpenOnRecipe then return end
        if not transaction then return end
        if transaction.recipeID then
            -- Show and dock only; user manually loads materials with Get Materials.
            COL:ShowFrame()
            COL:DockToProfessionsFrame()
        end
    end)
end

-- Hooks the customer crafting-order form for auto-open.
-- Tries Form.Init (same RecipeInfo pattern as SchematicForm).
-- Falls back to OnShow of the whole window if Init is unavailable.
-- Also handles the race condition where the frame is already visible when the hook is installed.
local craftingOrderHookInstalled = false
local function HookCraftingOrderWindow()
    if craftingOrderHookInstalled then return end
    if not ProfessionsCustomerOrdersFrame then return end
    craftingOrderHookInstalled = true

    -- Hook recipe selection for per-recipe granularity (if Form.Init is available)
    local form = ProfessionsCustomerOrdersFrame.Form
    if form and form.Init then
        hooksecurefunc(form, "Init", function(self, transaction)
            if not COL.settings.autoOpenOnRecipe then return end
            if not transaction then return end
            if transaction.recipeID then
                -- Show and dock only; user manually loads materials with Get Materials.
                COL:ShowFrame()
                COL:DockToCraftingOrdersFrame()
            end
        end)
    end

    -- Always hook OnShow so COL re-docks every time the window is opened or reopened.
    -- This mirrors how TRADE_SKILL_SHOW handles the normal crafting window.
    ProfessionsCustomerOrdersFrame:HookScript("OnShow", function()
        if not COL.settings.autoOpenOnRecipe then return end
        COL:ShowFrame()
        COL:DockToCraftingOrdersFrame()
    end)

    -- Hook OnHide so closing this window triggers auto-close or escape registration,
    -- mirroring the TRADE_SKILL_CLOSE handler used for the professions crafting window.
    -- Deferred via C_Timer.After(0) so it fires on the next frame update, AFTER the
    -- current Escape key event is fully processed — otherwise OnHide fires synchronously
    -- mid-Escape and COL ends up added to UISpecialFrames in the same pass that just
    -- closed this window, causing both windows to close on a single Escape press.
    ProfessionsCustomerOrdersFrame:HookScript("OnHide", function()
        C_Timer.After(0, OnRecipeWindowClosed)
    end)

    -- Race condition guard: frame may already be visible by the time we install the hook
    if ProfessionsCustomerOrdersFrame:IsShown() and COL.settings.autoOpenOnRecipe then
        COL:ShowFrame()
        COL:DockToCraftingOrdersFrame()
    end
end

local function SetupCraftingOrderButton()
    if not ProfessionsCustomerOrdersFrame then return end
    local frame      = ProfessionsCustomerOrdersFrame
    local buttonName = "COL_CraftingOrderButton"

    if COL.buttonsCreated[buttonName] then return end

    local btn = CreateFrame("Button", buttonName, frame, "UIPanelButtonTemplate")
    btn:SetSize(130, 22)
    btn:SetText("Get Materials List")
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(100)

    local function GetRecipeID()
        if frame.Form and frame.Form.transaction then
            return frame.Form.transaction.recipeID
        end
        return nil
    end

    btn:SetScript("OnClick", function()
        local recipeID = GetRecipeID()
        if recipeID then
            local addToExisting = #COL.materialList > 0
            if BuildMaterialList(recipeID, addToExisting) then
                COL:ShowFrame()
                if addToExisting then
                    print("|cFFFFCC00COL:|r Added to material list.")
                else
                    print("|cFFFFCC00COL:|r Material list ready!")
                end
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Get Materials List", 1, 1, 1)
        if #COL.materialList > 0 then
            GameTooltip:AddLine("Adds to existing list", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("Creates new shopping list", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function PositionButton()
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 5)
    end

    local function UpdateVisibility()
        -- Fall back to the parent frame's own visibility when Form is absent or
        -- has a different structure (e.g. zhCN/zhTW client builds).
        if frame:IsVisible() and (not frame.Form or frame.Form:IsVisible()) then
            PositionButton()
            btn:Show()
        else
            btn:Hide()
        end
    end

    frame:HookScript("OnShow", function() C_Timer.After(0.1, UpdateVisibility) end)
    frame:HookScript("OnHide", function() btn:Hide() end)
    if frame.Form then
        frame.Form:HookScript("OnShow", function() C_Timer.After(0.1, UpdateVisibility) end)
    end

    C_Timer.After(0.2, UpdateVisibility)
    COL.buttonsCreated[buttonName] = true
end

local function SetupAuctionHouseToggle()
    if not AuctionHouseFrame then return end
    local buttonName = "COL_AHToggleButton"
    if COL.buttonsCreated[buttonName] then return end

    local btn = CreateFrame("Button", buttonName, AuctionHouseFrame, "UIPanelButtonTemplate")
    btn:SetSize(100, 22)
    btn:SetText("Materials")

    local searchBar = AuctionHouseFrame.SearchBar
    if searchBar and searchBar.FavoritesSearchButton then
        btn:SetPoint("RIGHT", searchBar.FavoritesSearchButton, "LEFT", -5, 0)
    elseif searchBar then
        btn:SetPoint("RIGHT", searchBar, "RIGHT", -30, 0)
    else
        btn:SetPoint("TOPRIGHT", AuctionHouseFrame, "TOPRIGHT", -60, -30)
    end

    btn:SetScript("OnClick", function() COL:ToggleFrame() end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Craft Order List", 1, 1, 1)
        GameTooltip:AddLine("Toggle your crafting materials shopping list.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    COL.buttonsCreated[buttonName] = btn
end

-- ============================================================================
-- Saved Variables
-- ============================================================================

local function LoadSettings()
    if not COL_SavedData then return end

    if COL_SavedData.settings then
        for k, v in pairs(COL_SavedData.settings) do
            COL.settings[k] = v
        end
    end

    -- Validate loaded settings
    COL.settings.craftCount     = math.max(1, math.min(999, tonumber(COL.settings.craftCount) or 1))
    COL.settings.qualityFilter  = tonumber(COL.settings.qualityFilter) or 0
    if COL.settings.qualityFilter < 0 or COL.settings.qualityFilter > 3 then
        COL.settings.qualityFilter = 0
    end
    local validSorts = { name = true, needed = true, status = true, source = true }   -- COH-013
    if not validSorts[COL.settings.sortBy] then
        COL.settings.sortBy = "name"
    end
    if type(COL.settings.hideCompleted) ~= "boolean" then
        COL.settings.hideCompleted = false
    end
    if type(COL.settings.minimapHidden)    ~= "boolean" then COL.settings.minimapHidden    = false end
    if type(COL.settings.ahAutoDock)       ~= "boolean" then COL.settings.ahAutoDock       = true  end
    if type(COL.settings.autoOpenOnRecipe)  ~= "boolean" then COL.settings.autoOpenOnRecipe  = true  end
    if type(COL.settings.autoCloseOnRecipe) ~= "boolean" then COL.settings.autoCloseOnRecipe = false end

    if COL_SavedData.materialList and #COL_SavedData.materialList > 0 then
        COL.materialList = COL_SavedData.materialList
        COL.recipeName   = COL_SavedData.recipeName or ""
    end

    -- COH-008: load recent recipes
    if COL_SavedData.recentRecipes then
        COL.recentRecipes = COL_SavedData.recentRecipes
    end
end

local function SaveSettings()
    COL_SavedData = {
        settings = {
            qualityFilter  = COL.settings.qualityFilter,
            hideCompleted  = COL.settings.hideCompleted,
            sortBy         = COL.settings.sortBy,
            craftCount     = COL.settings.craftCount,
            framePos       = COL.settings.framePos,
            minimapAngle   = COL.settings.minimapAngle,
            minimapHidden    = COL.settings.minimapHidden,
            ahAutoDock       = COL.settings.ahAutoDock,
            autoOpenOnRecipe  = COL.settings.autoOpenOnRecipe,
            autoCloseOnRecipe = COL.settings.autoCloseOnRecipe,
        },
        materialList  = COL.materialList,
        recipeName    = COL.recipeName,
        recentRecipes = COL.recentRecipes,   -- COH-008
    }
end

local function ApplySettings()
    if not COL.mainFrame then return end

    local qf = COL.settings.qualityFilter
    UIDropDownMenu_SetText(COL_QualityDropdown, QUALITY_ICONS[qf])
    COL_HideCompleted:SetChecked(COL.settings.hideCompleted)

    if COL.mainFrame.SORT_LABELS then
        UIDropDownMenu_SetText(COL_SortDropdown, COL.mainFrame.SORT_LABELS[COL.settings.sortBy] or "Name")
    end

    if COL.mainFrame.craftValue then
        COL.mainFrame.craftValue:SetText(tostring(COL.settings.craftCount))
    end

    if COL.settings.framePos then
        local pos = COL.settings.framePos
        COL.mainFrame:ClearAllPoints()
        COL.mainFrame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end

    -- COH-017/018: sync settings panel checkboxes
    if COL_HideMinimapCheck then
        COL_HideMinimapCheck:SetChecked(COL.settings.minimapHidden)
    end
    if COL_AHDockCheck then
        COL_AHDockCheck:SetChecked(COL.settings.ahAutoDock)
    end
    if COL_AutoLoadCheck then
        COL_AutoLoadCheck:SetChecked(COL.settings.autoOpenOnRecipe)
    end
    if COL_AutoCloseCheck then
        COL_AutoCloseCheck:SetChecked(COL.settings.autoCloseOnRecipe)
    end
    -- COH-017: apply minimap visibility
    if COL.minimapButton then
        if COL.settings.minimapHidden then
            COL.minimapButton:Hide()
        else
            COL.minimapButton:Show()
        end
    end
end

-- ============================================================================
-- Event Handling
-- ============================================================================

local bagUpdatePending = false
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_CLOSE")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("CRAFTINGORDERS_CAN_REQUEST")
eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
eventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            LoadSettings()
            CreateMainFrame()
            CreateMinimapButton()
            CreateSettingsPanel()   -- COH-018
            ApplySettings()
            COL:UpdateMainFrame()
            print("|cFFFFCC00CraftOrderList|r loaded. /col to toggle.")
        elseif loadedAddon == "Blizzard_Professions" then
            C_Timer.After(0.1, SetupProfessionsButton)
            C_Timer.After(0.1, HookRecipeSelection)
        elseif loadedAddon == "Blizzard_ProfessionsCustomerOrders" then
            C_Timer.After(0.1, SetupCraftingOrderButton)
            C_Timer.After(0.1, HookCraftingOrderWindow)
        elseif loadedAddon == "Blizzard_AuctionHouseUI" then
            C_Timer.After(0.1, SetupAuctionHouseToggle)
        end

    elseif event == "TRADE_SKILL_SHOW" then
        SetupProfessionsButton()
        HookRecipeSelection()
        if COL.settings.autoOpenOnRecipe and #COL.materialList > 0 then
            COL:ShowFrame()
            COL:DockToProfessionsFrame()
        end

    elseif event == "TRADE_SKILL_CLOSE" then
        OnRecipeWindowClosed()

    elseif event == "AUCTION_HOUSE_SHOW" then
        SetupAuctionHouseToggle()
        if #COL.materialList > 0 then
            COL:ShowFrame()
            COL:DockToAuctionHouse()
        end

    elseif event == "CRAFTINGORDERS_CAN_REQUEST" then
        C_Timer.After(0.2, SetupCraftingOrderButton)
        C_Timer.After(0.2, HookCraftingOrderWindow)

    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED"
        or event == "MAIL_INBOX_UPDATE" or event == "TRADE_ACCEPT_UPDATE" then
        if COL.mainFrame and COL.mainFrame:IsShown() and not bagUpdatePending then
            bagUpdatePending = true
            C_Timer.After(0.3, function()
                bagUpdatePending = false
                if COL.mainFrame and COL.mainFrame:IsShown() then
                    COL:UpdateMainFrame()
                end
            end)
        end

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = ...
        if not itemID then return end

        for _, mat in ipairs(COL.materialList) do
            if mat.reagents and mat.reagents[1] and mat.reagents[1].itemID == itemID then
                local name = C_Item.GetItemNameByID(itemID)
                if name and name ~= "" then
                    mat.name = name:gsub(" %|A.-|a$", "")
                end
            end
        end

        if COL.mainFrame and COL.mainFrame:IsShown() then
            COL:UpdateMainFrame()
        end

    elseif event == "PLAYER_LOGOUT" then
        SaveSettings()
    end
end)

-- ============================================================================
-- Slash Commands
-- ============================================================================

SLASH_COL1 = "/col"
SLASH_COL2 = "/craftorderlist"
SlashCmdList["COL"] = function(msg)
    msg = (msg or ""):trim()
    local lmsg = msg:lower()
    if lmsg == "" then
        COL:ToggleFrame()
    elseif lmsg == "show" then
        COL:ShowFrame()
    elseif lmsg == "hide" then
        if COL.mainFrame then COL.mainFrame:Hide() end
    elseif lmsg == "clear" then
        COL.materialList   = {}
        COL.recipeName     = ""
        COL.searchIndex    = 0
        completionNotified = false   -- COH-009
        COL:UpdateMainFrame()
        print("|cFFFFCC00COL:|r List cleared.")
    elseif lmsg == "reset" then
        COL.settings.framePos = nil
        if COL.mainFrame then
            COL.mainFrame:ClearAllPoints()
            COL.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 400, 0)
        end
        print("|cFFFFCC00COL:|r Window position reset.")
    elseif lmsg:sub(1, 7) == "import " then
        COL:ImportList(msg:sub(8))   -- COH-010: pass original case
    elseif lmsg == "minimap" then   -- COH-017
        COL.settings.minimapHidden = not COL.settings.minimapHidden
        if COL.minimapButton then
            if COL.settings.minimapHidden then
                COL.minimapButton:Hide()
            else
                COL.minimapButton:Show()
            end
        end
        if COL_HideMinimapCheck then
            COL_HideMinimapCheck:SetChecked(COL.settings.minimapHidden)
        end
        print("|cFFFFCC00COL:|r Minimap button " .. (COL.settings.minimapHidden and "hidden." or "shown."))
    elseif lmsg == "help" then
        print("|cFFFFCC00Craft Order List commands:|r")
        print("  /col — Toggle the materials window")
        print("  /col show — Show the materials window")
        print("  /col hide — Hide the materials window")
        print("  /col clear — Clear the shopping list")
        print("  /col reset — Reset window position")
        print("  /col minimap — Toggle minimap button visibility")
        print("  /col import <string> — Restore a material list from export")
        print("  /col help — Show this help message")
    else
        print("|cFFFFCC00COL:|r Unknown command '" .. lmsg .. "'. Type /col help for options.")
    end
end
