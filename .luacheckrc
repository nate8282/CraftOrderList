std = "lua51"
max_line_length = false

exclude_files = {
    "Libs/**",
    "libs/**",
    ".release/**",
    ".luacheckrc",
}

ignore = {
    "11./SLASH_.*",     -- Slash command globals (SLASH_COL1, etc.)
    "11./BINDING_.*",   -- Keybinding globals
    "212",              -- Unused arguments (WoW callbacks have fixed signatures)
    "432",              -- Shadowing upvalue 'self' (intentional in WoW SetScript callbacks and method defs)
}

-- Globals the addon WRITES to
globals = {
    "COL_SavedData",
    "SlashCmdList",
    "UISpecialFrames",
    -- COH-015: keybinding display strings and global wrappers
    "BINDING_HEADER_CRAFTORDERLIST",
    "BINDING_NAME_COLTOGGLEMAIN",
    "BINDING_NAME_COLSEARCHNEXT",
    "COL_ToggleFrame",
    "COL_SearchNextMaterial",
}

-- WoW API functions the addon READS (organized by category)
read_globals = {
    -- Frame system
    "CreateFrame",
    "UIParent",
    "ChatFrame1EditBox",

    -- Item API
    "C_Item",

    -- Trade Skill / Professions API
    "C_TradeSkillUI",
    "ProfessionsFrame",
    "ProfessionsCustomerOrdersFrame",

    -- Auction House
    "AuctionHouseFrame",

    -- Enum
    "Enum",

    -- Tooltip
    "GameTooltip",

    -- Minimap
    "Minimap",
    "GetCursorPosition",

    -- Font objects
    "GameFontNormalSmall",

    -- Named frames (created by CreateFrame with a global name)
    "COL_QualityDropdown",
    "COL_SortDropdown",
    "COL_HideCompleted",
    "COL_RecentDropdown",   -- COH-008
    -- COH-009: screen notification frame
    "UIErrorsFrame",

    -- Dropdown API
    "UIDropDownMenu_Initialize",
    "UIDropDownMenu_SetWidth",
    "UIDropDownMenu_SetText",
    "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_AddButton",

    -- Addon metadata
    "C_AddOns",

    -- Utility
    "C_Timer",
    "CreateAtlasMarkup",
    "strsplit",
    "strtrim",
}

-- Busted test files mock the entire WoW API as globals
files["spec/**"] = {
    globals = {
        "CreateFrame", "UIParent", "UISpecialFrames",
        "ChatFrame1EditBox",
        "C_Item", "C_TradeSkillUI",
        "ProfessionsFrame", "ProfessionsCustomerOrdersFrame",
        "AuctionHouseFrame",
        "Enum", "GameTooltip",
        "Minimap", "GetCursorPosition",
        "GameFontNormalSmall",
        "UIDropDownMenu_Initialize", "UIDropDownMenu_SetWidth",
        "UIDropDownMenu_SetText", "UIDropDownMenu_CreateInfo",
        "UIDropDownMenu_AddButton",
        "strsplit", "strtrim", "CreateAtlasMarkup",
        "C_Timer", "C_AddOns", "SlashCmdList",
        "COL_SavedData", "MockData",
        -- COH-008/009/015: new globals set by addon at load time
        "UIErrorsFrame",
        "COL_RecentDropdown",
        "COL_ToggleFrame",
        "COL_SearchNextMaterial",
        "BINDING_HEADER_CRAFTORDERLIST",
        "BINDING_NAME_COLTOGGLEMAIN",
        "BINDING_NAME_COLSEARCHNEXT",
    },
    ignore = {
        "211",  -- Unused local variable (mock data)
        "212",  -- Unused argument (mock signatures)
        "213",  -- Unused loop variable
    },
    read_globals = {
        "dofile", "setmetatable", "os",
        -- Busted globals
        "describe", "it", "setup", "teardown",
        "before_each", "after_each",
        "assert", "spy", "stub", "mock", "match",
        "insulate", "expose",
    },
}

-- Legacy test files (custom runner)
files["tests/**"] = {
    globals = {
        "CreateFrame", "UIParent", "UISpecialFrames",
        "ChatFrame1EditBox",
        "C_Item", "C_TradeSkillUI",
        "ProfessionsFrame", "ProfessionsCustomerOrdersFrame",
        "AuctionHouseFrame",
        "Enum", "GameTooltip",
        "Minimap", "GetCursorPosition",
        "GameFontNormalSmall",
        "UIDropDownMenu_Initialize", "UIDropDownMenu_SetWidth",
        "UIDropDownMenu_SetText", "UIDropDownMenu_CreateInfo",
        "UIDropDownMenu_AddButton",
        "strsplit", "strtrim", "CreateAtlasMarkup",
        "C_Timer", "C_AddOns", "SlashCmdList",
        "COL_SavedData",
        -- COH-008/009/015: new globals set by addon at load time
        "UIErrorsFrame",
        "COL_RecentDropdown",
        "COL_ToggleFrame",
        "COL_SearchNextMaterial",
        "BINDING_HEADER_CRAFTORDERLIST",
        "BINDING_NAME_COLTOGGLEMAIN",
        "BINDING_NAME_COLSEARCHNEXT",
    },
    ignore = { "211", "212", "213", "311" },
    read_globals = { "dofile", "setmetatable", "os" },
}
