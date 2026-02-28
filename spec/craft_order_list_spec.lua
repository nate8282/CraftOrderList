-- Busted test suite for CraftOrderList

describe("CraftOrderList", function()
    local MockData
    local COL = {}

    setup(function()
        MockData = _G.MockData
        loadfile("CraftOrderList.lua")("CraftOrderList", COL)
    end)

    before_each(function()
        COL_SavedData = nil
        -- Reset namespace state
        COL.materialList   = {}
        COL.recipeName     = ""
        COL.recentRecipes  = {}
        COL.mainFrame      = nil
        COL.rows           = {}
        COL.settings = {
            qualityFilter = 0,
            hideCompleted = false,
            sortBy        = "name",
            craftCount    = 1,
            framePos      = nil,
        }
        -- Reset mock data
        MockData.itemCounts       = {}
        MockData.itemNames        = {}
        MockData.recipeInfos      = {}
        MockData.recipeSchematics = {}
        MockData.itemInfoInstant  = {}
    end)

    -- ============================================================================
    -- Initialization
    -- ============================================================================
    describe("initialization", function()
        it("should register expected events", function()
            assert.is_true(MockData.registeredEvents["ADDON_LOADED"])
            assert.is_true(MockData.registeredEvents["BAG_UPDATE"])
            assert.is_true(MockData.registeredEvents["PLAYER_LOGOUT"])
        end)

        it("should register slash commands", function()
            assert.is_not_nil(SlashCmdList["COL"])
        end)
    end)

    -- ============================================================================
    -- Slash Commands
    -- ============================================================================
    describe("slash commands", function()
        it("should handle /col clear", function()
            SlashCmdList["COL"]("clear")
        end)

        it("should handle /col reset", function()
            SlashCmdList["COL"]("reset")
        end)

        it("should handle /col show", function()
            SlashCmdList["COL"]("show")
        end)

        it("should handle /col hide", function()
            SlashCmdList["COL"]("hide")
        end)
    end)

    -- ============================================================================
    -- COH-015: Keyboard shortcuts / keybinding globals
    -- ============================================================================
    describe("keybindings (COH-015)", function()
        it("should set BINDING_HEADER at file-load time", function()
            assert.is_string(BINDING_HEADER_CRAFTORDERLIST)
            assert.is_truthy(#BINDING_HEADER_CRAFTORDERLIST > 0)
        end)

        it("should set BINDING_NAME globals for both actions", function()
            assert.is_string(BINDING_NAME_COLTOGGLEMAIN)
            assert.is_string(BINDING_NAME_COLSEARCHNEXT)
        end)

        it("should expose COL_ToggleFrame as a callable global", function()
            assert.is_function(COL_ToggleFrame)
            assert.has_no.errors(function() COL_ToggleFrame() end)
        end)

        it("should expose COL_SearchNextMaterial as a callable global", function()
            assert.is_function(COL_SearchNextMaterial)
            assert.has_no.errors(function() COL_SearchNextMaterial() end)
        end)
    end)

    -- ============================================================================
    -- COH-008: Recent recipes list
    -- ============================================================================
    describe("recent recipes (COH-008)", function()
        it("should initialize recentRecipes as an empty table", function()
            assert.is_table(COL.recentRecipes)
            assert.equals(0, #COL.recentRecipes)
        end)

        it("should store recipe entries as tables with id and name fields", function()
            COL.recentRecipes = {
                { id = 101, name = "Iron Sword" },
                { id = 202, name = "Steel Shield" },
            }
            assert.equals(2, #COL.recentRecipes)
            assert.equals(101, COL.recentRecipes[1].id)
            assert.equals("Iron Sword", COL.recentRecipes[1].name)
            assert.equals(202, COL.recentRecipes[2].id)
        end)
    end)

    -- ============================================================================
    -- COH-010: Export / Import
    -- ============================================================================
    describe("export/import (COH-010)", function()
        it("should import a valid COL1 export string via slash command", function()
            SlashCmdList["COL"]("import COL1|Sword of Power|Iron Bar:5:12359|Coal:3:0")
            assert.equals(2, #COL.materialList)
            assert.equals("Iron Bar", COL.materialList[1].name)
            assert.equals(5, COL.materialList[1].needed)
            assert.equals("Coal", COL.materialList[2].name)
            assert.equals(3, COL.materialList[2].needed)
            assert.equals("Sword of Power", COL.recipeName)
        end)

        it("should preserve itemID in material reagents after import", function()
            SlashCmdList["COL"]("import COL1|TestRecipe|Ore:10:12360")
            assert.equals(1, #COL.materialList)
            assert.equals(12360, COL.materialList[1].reagents[1].itemID)
        end)

        it("should handle itemID=0 with empty reagents table", function()
            SlashCmdList["COL"]("import COL1|TestRecipe|Unknown Mat:2:0")
            assert.equals(1, #COL.materialList)
            assert.is_table(COL.materialList[1].reagents)
        end)

        it("should reject an invalid export string (wrong header)", function()
            COL.materialList = {}
            SlashCmdList["COL"]("import INVALID|stuff")
            assert.equals(0, #COL.materialList)
        end)

        it("should reject a missing import argument", function()
            COL.materialList = {}
            SlashCmdList["COL"]("import ")
            assert.equals(0, #COL.materialList)
        end)

        it("should preserve case of recipe and material names on import", function()
            SlashCmdList["COL"]("import COL1|Grand Staff of Fire|Arcane Dust:8:22447")
            assert.equals("Grand Staff of Fire", COL.recipeName)
            assert.equals("Arcane Dust", COL.materialList[1].name)
        end)

        it("should round-trip through ExportList and ImportList", function()
            COL.materialList = {
                {
                    name     = "Iron Bar",
                    needed   = 5,
                    reagents = { { itemID = 12359 } },
                    searched = false, manualCheck = false,
                },
            }
            COL.recipeName = "Iron Sword"

            -- Capture the export string by temporarily overriding editBox
            local captured = nil
            COL.editBox = {
                SetText       = function(_, s) captured = s end,
                Show          = function() end,
                HighlightText = function() end,
                SetFocus      = function() end,
            }
            COL:ExportList()

            assert.is_string(captured)
            assert.equals("COL1", captured:match("^([^|]+)"))

            -- Import it back
            COL.materialList = {}
            SlashCmdList["COL"]("import " .. captured)
            assert.equals(1, #COL.materialList)
            assert.equals("Iron Bar", COL.materialList[1].name)
            assert.equals(5, COL.materialList[1].needed)
        end)
    end)

    -- ============================================================================
    -- COH-011 / COH-013: Source sort option
    -- ============================================================================
    describe("source sort (COH-013)", function()
        it("should accept 'source' as a valid sortBy setting", function()
            COL.settings.sortBy = "source"
            -- LoadSettings validates sortBy; "source" should pass validation
            COL_SavedData = {
                settings = { sortBy = "source", qualityFilter = 0, hideCompleted = false, craftCount = 1 },
            }
            -- Simulate loading saved data
            assert.has_no.errors(function()
                SlashCmdList["COL"]("show")
            end)
            -- sortBy should still be "source" (valid)
            assert.equals("source", COL.settings.sortBy)
        end)

        it("should not error when UpdateMainFrame is called with source sort active", function()
            -- Import a list (creates frame as side effect), then set source sort
            SlashCmdList["COL"]("import COL1|TestRecipe|Iron Bar:5:12359|Herb:3:765")
            MockData.itemInfoInstant = {
                [12359] = { id = 12359, itemType = "Trade Goods", subType = "Metal & Stone" },
                [765]   = { id = 765,   itemType = "Trade Goods", subType = "Herb"          },
            }
            COL.settings.sortBy = "source"
            assert.has_no.errors(function() COL:UpdateMainFrame() end)
        end)
    end)

    -- ============================================================================
    -- COH-014: Material substitution suggestions
    -- ============================================================================
    describe("substitution suggestions (COH-014)", function()
        it("should not error on UpdateMainFrame with quality filter 0", function()
            -- Import creates the frame, then test with no filter
            SlashCmdList["COL"]("import COL1|TestRecipe|Iron Bar:5:12359")
            COL.settings.qualityFilter = 0
            MockData.itemCounts = { [12359] = 10 }
            assert.has_no.errors(function() COL:UpdateMainFrame() end)
        end)

        it("should not error when filter tier has 0 but total covers need", function()
            -- Import creates the frame
            SlashCmdList["COL"]("import COL1|TestRecipe|Iron Bar:3:12359")
            -- Manually update reagents to simulate multi-tier
            COL.materialList[1].reagents = {
                { itemID = 101 },  -- tier 1: have 5
                { itemID = 102 },  -- tier 2: have 0 (selected)
                { itemID = 103 },  -- tier 3: have 0
            }
            COL.settings.qualityFilter = 2
            MockData.itemCounts = { [101] = 5, [102] = 0, [103] = 0 }
            assert.has_no.errors(function() COL:UpdateMainFrame() end)
        end)
    end)

    -- ============================================================================
    -- COH-009: Completion notification
    -- ============================================================================
    describe("completion notification (COH-009)", function()
        it("should not error when all materials are fully owned", function()
            -- Import creates the frame
            SlashCmdList["COL"]("import COL1|TestRecipe|Iron Bar:5:12359")
            MockData.itemCounts = { [12359] = 10 }
            assert.has_no.errors(function() COL:UpdateMainFrame() end)
        end)

        it("should reset on /col clear without error", function()
            assert.has_no.errors(function()
                SlashCmdList["COL"]("clear")
            end)
        end)
    end)
end)
