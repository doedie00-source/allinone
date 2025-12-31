-- config.lua
-- Professional Cyber Blue Theme Configuration

local CONFIG = {
    VERSION = "7.4",
    GUI_NAME = "Trade",
    
    -- Window Settings
    MAIN_WINDOW_SIZE = UDim2.new(0, 750, 0, 480),
    SIDEBAR_WIDTH = 110,
    MINI_ICON_SIZE = UDim2.new(0, 50, 0, 50),
    
    -- Timing
    STATUS_RESET_DELAY = 4,
    BUTTON_CHECK_INTERVAL = 0.5,
    TRADE_RESET_THRESHOLD = 3,
    
    -- UI Spacing
    CORNER_RADIUS = 10,
    LIST_PADDING = 4,
    BUTTON_PADDING = 5,
    CARD_PADDING = 6,
    
    -- Keybind
    TOGGLE_KEY = Enum.KeyCode.T,
}

-- Professional Cyber Blue Theme (No Emojis)
local THEME = {
    -- Base: Deep Navy (Dark Blue Background - Professional)
    MainBg = Color3.fromRGB(10, 13, 20),            -- Deep Navy Blue (Almost Black)
    MainTransparency = 0,                           -- Solid
    PanelBg = Color3.fromRGB(15, 20, 30),           -- Secondary Background
    PanelTransparency = 0,
    
    -- Glass/Containers (Electric Blue Borders - Signature Look)
    GlassBg = Color3.fromRGB(20, 25, 40),           -- Container Background
    GlassTransparency = 0,                          
    GlassStroke = Color3.fromRGB(0, 100, 200),      -- **Electric Blue Border** (Key Visual)
    
    -- Text (White and Blue)
    TextWhite = Color3.fromRGB(240, 250, 255),      -- Pure White with Blue tint
    TextGray = Color3.fromRGB(140, 160, 190),       -- Gray Blue
    TextDim = Color3.fromRGB(80, 100, 130),         -- Dim Gray
    
    -- Buttons (System Style)
    BtnDefault = Color3.fromRGB(25, 35, 55),        -- Default Button Dark Blue
    BtnHover = Color3.fromRGB(0, 80, 160),          -- Hover Dark Cyan
    BtnSelected = Color3.fromRGB(0, 120, 220),      -- Selected Bright Cyan
    
    BtnMainTab = Color3.fromRGB(18, 22, 35),        -- Sidebar Tab
    BtnMainTabSelected = Color3.fromRGB(0, 120, 220), -- Selected Tab Bright Cyan
    BtnDupe = Color3.fromRGB(0, 120, 220),          -- Primary Action Button
    BtnDisabled = Color3.fromRGB(12, 15, 20),       -- Disabled State
    TextDisabled = Color3.fromRGB(60, 70, 90),
    
    -- Status Colors (Neon - High Visibility)
    Success = Color3.fromRGB(0, 255, 180),          -- Cyber Green (Mint)
    Fail = Color3.fromRGB(255, 60, 60),             -- Bright Red
    Warning = Color3.fromRGB(255, 200, 50),         -- Yellow
    Info = Color3.fromRGB(0, 180, 255),             -- Cyan Blue
    
    -- Item Status
    ItemInv = Color3.fromRGB(0, 255, 180),          -- Available (Green)
    ItemEquip = Color3.fromRGB(255, 60, 60),        -- Equipped (Red)
    PlayerBtn = Color3.fromRGB(30, 40, 60),
    DupeReady = Color3.fromRGB(0, 255, 180),
    
    -- Cards (Cyber Style)
    CardBg = Color3.fromRGB(20, 28, 45),            -- Card Background Dark Blue
    CardStrokeSelected = Color3.fromRGB(0, 160, 255), -- Cyan Glow Border
    CardStrokeLocked = Color3.fromRGB(200, 50, 50),
    CrateSelected = Color3.fromRGB(0, 160, 255),
    
    -- Accent Colors
    StarColor = Color3.fromRGB(255, 215, 0),
    AccentBlue = Color3.fromRGB(0, 140, 255),
}

local DUPE_RECIPES = {
    Items = {
        -- [SCROLLS]
        {Name = "Dark Scroll", Tier = 5, RequiredTiers = {3, 4, 6}, Service = "Scrolls", Image = "83561916475671"},
        
        -- [TICKETS]
        {Name = "Void Ticket", Tier = 3, RequiredTiers = {4, 5, 6}, Service = "Tickets", Image = "85868652778541"},
        {Name = "Summer Ticket", Tier = 4, RequiredTiers = {3, 5, 6}, Service = "Tickets", Image = "104675798190180"},
        {Name = "Eternal Ticket", Tier = 5, RequiredTiers = {3, 4, 6}, Service = "Tickets", Image = "130196431947308"},
        {Name = "Arcade Ticket", Tier = 6, RequiredTiers = {3, 4, 5}, Service = "Tickets", Image = "104884644514614"},
        
        -- [POTIONS]
        {Name = "White Strawberry", Tier = 1, RequiredTiers = {2}, Service = "Strawberry", Image = "79066822879876"},
        {Name = "Mega Luck Potion", Tier = 3, RequiredTiers = {1, 2}, Service = "Luck Potion", Image = "131175270021637"},
        {Name = "Mega Wins Potion", Tier = 3, RequiredTiers = {1, 2}, Service = "Wins Potion", Image = "77652691143188"},
        {Name = "Mega Exp Potion", Tier = 3, RequiredTiers = {1, 2}, Service = "Exp Potion", Image = "72861583354784"},
    },
    Crates = {},
    Pets = {}
}

local HIDDEN_LISTS = {
    Accessories = {"Ghost", "Pumpkin Head", "Tri Tooth", "Tri Foot", "Tri Eyes", "Tri Ton"},
    Pets = {"I.N.D.E.X", "Spooksy", "Spooplet", "Lordfang", "Batkin", "Flame", "Mega Flame", "Turbo Flame", "Ultra Flame", "I2Pet", "Present", "Polar Bear"},
    Crates = {"i2Perfect Crate" }
}

return {
    CONFIG = CONFIG,
    THEME = THEME,
    DUPE_RECIPES = DUPE_RECIPES,
    HIDDEN_LISTS = HIDDEN_LISTS
}
