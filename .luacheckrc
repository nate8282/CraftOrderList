std = "lua51"
max_line_length = false

exclude_files = {
    "Libs/**",
    "libs/**",
    ".release/**",
    ".luacheckrc",
}

ignore = {
    "11./SLASH_.*",     -- Slash command globals (SLASH_COH1, etc.)
    "11./BINDING_.*",   -- Keybinding globals
    "212",              -- Unused arguments (WoW callbacks have fixed signatures)
    "432",              -- Shadowing upvalue 'self' (intentional in WoW SetScript callbacks and method defs)
}

-- Globals the addon WRITES to
globals = {
    "COH_SavedData",
    "SlashCmdList",
    "UISpecialFrames",
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
        "strsplit", "strtrim",
        "C_Timer", "C_AddOns", "SlashCmdList",
        "COH_SavedData", "MockData",
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
        "strsplit", "strtrim",
        "C_Timer", "C_AddOns", "SlashCmdList",
        "COH_SavedData",
    },
    ignore = { "211", "212", "213", "311" },
    read_globals = { "dofile", "setmetatable", "os" },
}
