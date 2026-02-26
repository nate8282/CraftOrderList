-- Busted test suite for CraftingOrderHelper

describe("CraftingOrderHelper", function()
    local MockData
    local COH

    setup(function()
        MockData = _G.MockData
        dofile("CraftingOrderHelper.lua")
    end)

    before_each(function()
        COH_SavedData = nil
        MockData.itemCounts = {}
        MockData.itemNames = {}
        MockData.recipeInfos = {}
        MockData.recipeSchematics = {}
    end)

    describe("initialization", function()
        it("should register expected events", function()
            assert.is_true(MockData.registeredEvents["ADDON_LOADED"])
            assert.is_true(MockData.registeredEvents["BAG_UPDATE"])
            assert.is_true(MockData.registeredEvents["PLAYER_LOGOUT"])
        end)

        it("should register slash commands", function()
            assert.is_not_nil(SlashCmdList["COH"])
        end)
    end)

    describe("slash commands", function()
        it("should handle /coh clear", function()
            SlashCmdList["COH"]("clear")
            -- Should not error
        end)

        it("should handle /coh reset", function()
            SlashCmdList["COH"]("reset")
            -- Should not error
        end)

        it("should handle /coh show", function()
            SlashCmdList["COH"]("show")
        end)

        it("should handle /coh hide", function()
            SlashCmdList["COH"]("hide")
        end)
    end)
end)
