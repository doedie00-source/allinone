-- gui.lua
-- Professional Cyber Blue UI Controller

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local GUI = {}
GUI.__index = GUI

function GUI.new(deps)
    local self = setmetatable({}, GUI)
    
    self.Config = deps.Config
    self.Utils = deps.Utils
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.TradeManager = deps.TradeManager
    
    self.TabsModules = deps.Tabs or {}
    
    self.ScreenGui = nil
    self.MainFrame = nil
    self.ContentArea = nil
    self.ActiveTabInstance = nil
    self.SidebarButtons = {}
    
    return self
end

function GUI:Initialize()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    _G.ModernGUI = self

    if CoreGui:FindFirstChild(CONFIG.GUI_NAME) then
        pcall(function() CoreGui[CONFIG.GUI_NAME]:Destroy() end)
    end
    
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = CONFIG.GUI_NAME
    self.ScreenGui.Parent = CoreGui
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.ScreenGui.DisplayOrder = 100
    self.ScreenGui.IgnoreGuiInset = true

    self:CreateMiniIcon()
    
    self.MainFrame = Instance.new("Frame", self.ScreenGui)
    self.MainFrame.Name = "MainWindow"
    self.MainFrame.Size = CONFIG.MAIN_WINDOW_SIZE
    self.MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    self.MainFrame.BackgroundColor3 = THEME.MainBg
    self.MainFrame.BackgroundTransparency = THEME.MainTransparency
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.ClipsDescendants = true
    
    self.UIFactory.AddCorner(self.MainFrame, 8)
    self.UIFactory.AddStroke(self.MainFrame, THEME.GlassStroke, 2, 0)
    
    self:CreateTitleBar()
    self:CreateSidebar()
    
    self.ContentArea = Instance.new("Frame", self.MainFrame)
    self.ContentArea.Name = "ContentArea"
    self.ContentArea.Size = UDim2.new(1, -CONFIG.SIDEBAR_WIDTH - 18, 1, -82) 
    self.ContentArea.Position = UDim2.new(0, CONFIG.SIDEBAR_WIDTH + 10, 0, 42)
    self.ContentArea.BackgroundTransparency = 1
    self.ContentArea.BorderSizePixel = 0

    -- Professional Status Bar (Transparent, No Border)
    local StatusBarBg = Instance.new("Frame", self.MainFrame)
    StatusBarBg.Name = "StatusBar"
    StatusBarBg.Size = UDim2.new(1, -16, 0, 28)
    StatusBarBg.Position = UDim2.new(0, 8, 1, -34)
    StatusBarBg.BackgroundColor3 = THEME.GlassBg
    StatusBarBg.BackgroundTransparency = 0.7  -- โปร่งใสมากขึ้น
    StatusBarBg.BorderSizePixel = 0
    StatusBarBg.ZIndex = 100
    
    self.UIFactory.AddCorner(StatusBarBg, 6)
    -- ไม่มีกรอบ (ลบ AddStroke ออก)
    
    -- Status Label (Clean, No Emojis - Enhanced Visibility)
    self.StatusLabel = self.UIFactory.CreateLabel({
        Parent = StatusBarBg,
        Text = "READY",
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        TextColor = THEME.TextWhite,  -- ขาวสดชัด
        TextSize = 12,
        Font = Enum.Font.GothamBold,  -- ตัวหนาขึ้น
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- Info Label (Enhanced Visibility)
    self.InfoLabel = self.UIFactory.CreateLabel({
        Parent = StatusBarBg,
        Text = "",
        Size = UDim2.new(0.4, -12, 1, 0),
        Position = UDim2.new(1, -12, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        TextColor = THEME.AccentBlue,  -- สีฟ้าสว่าง
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Right
    })

    self:SwitchTab("Players")
    self:StartMonitoring()
    self:SetupKeybind()
end

function GUI:CreateMiniIcon()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    self.MiniIcon = self.UIFactory.CreateButton({
        Size = CONFIG.MINI_ICON_SIZE,
        Position = UDim2.new(0, 20, 0.5, -27),
        BgColor = THEME.MainBg,
        Text = "T",
        TextColor = THEME.AccentBlue,
        Font = Enum.Font.GothamBlack,
        TextSize = 26,
        Parent = self.ScreenGui,
        Corner = true,
        CornerRadius = 8,
        OnClick = function() self:ToggleWindow() end
    })
    self.MiniIcon.Visible = false
    self.MiniIcon.Active = true
    self.UIFactory.AddStroke(self.MiniIcon, THEME.AccentBlue, 2, 0)
    self.UIFactory.MakeDraggable(self.MiniIcon, self.MiniIcon)
end

function GUI:CreateTitleBar()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    local titleBar = Instance.new("Frame", self.MainFrame)
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 38)
    titleBar.BackgroundColor3 = THEME.GlassBg
    titleBar.BackgroundTransparency = 0
    titleBar.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(titleBar, 8)
    
    -- Title with Professional Styling
    local titleLabel = self.UIFactory.CreateLabel({
        Parent = titleBar,
        Text = "    UNIVERSAL TRADER",
        Size = UDim2.new(0.5, 0, 1, 0),
        TextColor = THEME.TextWhite,
        TextSize = 13,
        Font = Enum.Font.GothamBlack,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    
    -- Modern Window Controls
    self.UIFactory.CreateButton({
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -34, 0, 4),
        Text = "X",
        BgColor = Color3.fromRGB(255, 60, 60),
        TextColor = THEME.TextWhite,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6,
        Parent = titleBar,
        OnClick = function() self.ScreenGui:Destroy() end
    })
    
    self.UIFactory.CreateButton({
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -68, 0, 4),
        Text = "—",
        BgColor = THEME.BtnDefault,
        TextColor = THEME.TextGray,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6,
        Parent = titleBar,
        OnClick = function() self:ToggleWindow() end
    })
    
    self.UIFactory.MakeDraggable(titleBar, self.MainFrame)
end

function GUI:CreateSidebar()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    local sidebar = Instance.new("Frame", self.MainFrame)
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 1, -82)
    sidebar.Position = UDim2.new(0, 8, 0, 42)
    sidebar.BackgroundColor3 = THEME.GlassBg
    sidebar.BackgroundTransparency = 0
    sidebar.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(sidebar, 8)
    self.UIFactory.AddStroke(sidebar, THEME.GlassStroke, 1.5, 0)
    
    -- Simple Logo
    local logoFrame = Instance.new("Frame", sidebar)
    logoFrame.Size = UDim2.new(1, 0, 0, 50)
    logoFrame.BackgroundTransparency = 1
    
    local logoText = self.UIFactory.CreateLabel({
        Parent = logoFrame,
        
        -- [[ แก้ไขตรงนี้ ]] --
        Text = "v" .. CONFIG.VERSION,
        Size = UDim2.new(1, 0, 1, 0),
        TextColor = THEME.AccentBlue,
        TextSize = 20,               
        Font = Enum.Font.GothamBlack
        ---------------------
    })
    
    -- Separator Line
    local separator = Instance.new("Frame", sidebar)
    separator.Size = UDim2.new(1, -16, 0, 1)
    separator.Position = UDim2.new(0, 8, 0, 54)
    separator.BackgroundColor3 = THEME.GlassStroke
    separator.BackgroundTransparency = 0.3
    separator.BorderSizePixel = 0
    
    -- Tab Buttons Container
    local btnContainer = Instance.new("Frame", sidebar)
    btnContainer.Size = UDim2.new(1, -12, 1, -68)
    btnContainer.Position = UDim2.new(0, 6, 0, 62)
    btnContainer.BackgroundTransparency = 1
    
    local layout = Instance.new("UIListLayout", btnContainer)
    layout.Padding = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    self:CreateSidebarButton(btnContainer, "Players", "PLAYERS")
    self:CreateSidebarButton(btnContainer, "Dupe", "DUPE")
    self:CreateSidebarButton(btnContainer, "AutoCrates", "AUTO")
end

function GUI:CreateSidebarButton(parent, tabName, text)
    local THEME = self.Config.THEME
    
    local btn = self.UIFactory.CreateButton({
        Parent = parent,
        Text = text,
        Size = UDim2.new(1, 0, 0, 38),
        BgColor = THEME.BtnMainTab,
        TextColor = THEME.TextGray,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6,
        OnClick = function()
            self:SwitchTab(tabName)
        end
    })
    
    -- Add subtle border
    self.UIFactory.AddStroke(btn, THEME.GlassStroke, 1, 0.7)
    
    self.SidebarButtons[tabName] = btn
end

function GUI:SwitchTab(tabName)
    local THEME = self.Config.THEME
    
    if tabName == "Players" and self.Utils.IsTradeActive() then
        tabName = "Inventory"
        if self.StatusLabel then
            self.StateManager:SetStatus("TRADE ACTIVE", THEME.Warning, self.StatusLabel)
        end
    end
    
    self.StateManager.currentMainTab = tabName
    
    for name, btn in pairs(self.SidebarButtons) do
        local isSelected = (name == tabName)
        local targetColor = isSelected and THEME.BtnMainTabSelected or THEME.BtnMainTab
        local targetTextColor = isSelected and THEME.TextWhite or THEME.TextGray
        
        TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundColor3 = targetColor
        }):Play()
        TweenService:Create(btn, TweenInfo.new(0.2), {
            TextColor3 = targetTextColor
        }):Play()
    end
    
    for _, child in pairs(self.ContentArea:GetChildren()) do
        child:Destroy()
    end
    self.ActiveTabInstance = nil

    if self.InfoLabel then 
        self.InfoLabel.Text = "" 
    end
    
    local success, err = pcall(function()
        if tabName == "Players" and self.TabsModules.Players then
            local tab = self.TabsModules.Players.new({
                UIFactory = self.UIFactory,
                StateManager = self.StateManager,
                TradeManager = self.TradeManager,
                Utils = self.Utils,
                Config = self.Config,
                StatusLabel = self.StatusLabel,
                InfoLabel = self.InfoLabel
            })
            tab:Init(self.ContentArea)
            self.ActiveTabInstance = tab
            
        elseif tabName == "Dupe" and self.TabsModules.Dupe then
            local tab = self.TabsModules.Dupe.new({
                UIFactory = self.UIFactory,
                StateManager = self.StateManager,
                InventoryManager = self.InventoryManager,
                TradeManager = self.TradeManager,
                Utils = self.Utils,
                Config = self.Config,
                StatusLabel = self.StatusLabel,
                ScreenGui = self.ScreenGui,
                InfoLabel = self.InfoLabel
            })
            tab:Init(self.ContentArea)
            self.ActiveTabInstance = tab
        
        elseif tabName == "AutoCrates" and self.TabsModules.AutoCrates then
            local tab = self.TabsModules.AutoCrates.new({
                UIFactory = self.UIFactory,
                StateManager = self.StateManager,
                InventoryManager = self.InventoryManager,
                Utils = self.Utils,
                Config = self.Config,
                StatusLabel = self.StatusLabel,
                InfoLabel = self.InfoLabel
            })
            tab:Init(self.ContentArea)
            self.ActiveTabInstance = tab
        
        elseif tabName == "Inventory" and self.TabsModules.Inventory then
            local tab = self.TabsModules.Inventory.new({
                UIFactory = self.UIFactory,
                StateManager = self.StateManager,
                InventoryManager = self.InventoryManager,
                TradeManager = self.TradeManager,
                Utils = self.Utils,
                Config = self.Config,
                StatusLabel = self.StatusLabel
            })
            tab:Init(self.ContentArea)
            self.ActiveTabInstance = tab    
        end
    end)

    if not success then
        warn("Failed to load tab " .. tostring(tabName) .. ": " .. tostring(err))
        self.StatusLabel.Text = "ERROR LOADING TAB: " .. tabName
    end
end

function GUI:ToggleWindow()
    if self.MainFrame.Visible then
        self.MainFrame.Visible = false
        self.MiniIcon.Visible = true
    else
        self.MainFrame.Visible = true
        self.MiniIcon.Visible = false
    end
end

function GUI:SetupKeybind()
    local CONFIG = self.Config.CONFIG
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == CONFIG.TOGGLE_KEY then
            self:ToggleWindow()
        end
    end)
end

function GUI:StartMonitoring()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    task.spawn(function()
        local missingCounter = 0
        
        while self.ScreenGui and self.ScreenGui.Parent do
            local isTradeActive = self.Utils.IsTradeActive() -- เช็คสถานะเทรด

            -- ✅ ส่วนที่เพิ่ม: ถ้าเทรดเปิดอยู่ แต่ยังอยู่ที่หน้า Players ให้สลับไป Inventory ทันที
            if isTradeActive and self.StateManager.currentMainTab == "Players" then
                self:SwitchTab("Inventory")
                if self.StatusLabel then
                    self.StateManager:SetStatus("TRADE ACTIVE", THEME.Success, self.StatusLabel)
                end
            end

            -- อัปเดตสถานะปุ่มในหน้า Players (Locked/Trade)
            if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance and self.ActiveTabInstance.UpdateButtonStates then
                pcall(function() self.ActiveTabInstance:UpdateButtonStates() end)
            end

            -- Logic เดิมสำหรับนับเวลาปิดเทรด
            if isTradeActive then
                missingCounter = 0
            else
                missingCounter = missingCounter + 1
            end
            
            -- ระบบ Reset เมื่อปิดหน้าเทรด
            if missingCounter > CONFIG.TRADE_RESET_THRESHOLD then
                self.TradeManager.IsProcessing = false
                
                if next(self.StateManager.itemsInTrade) ~= nil or self.StateManager.currentMainTab == "Inventory" then
                    local wasInInventory = (self.StateManager.currentMainTab == "Inventory")
                    self.StateManager:ResetTrade()
                    
                    if self.StatusLabel then
                        self.StateManager:SetStatus("TRADE CLOSED - RESET", THEME.TextGray, self.StatusLabel)
                    end
                    
                    -- ถ้าเคยอยู่ในหน้า Inventory ให้เด้งกลับไปหน้า Players
                    if wasInInventory then
                        task.wait(0.2)
                        self:SwitchTab("Players")
                    end
                    missingCounter = 0
                end
            end
            
            task.wait(CONFIG.BUTTON_CHECK_INTERVAL)
        end
    end)
    
    Players.PlayerAdded:Connect(function()
        if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance and self.ActiveTabInstance.RefreshList then
            pcall(function() self.ActiveTabInstance:RefreshList() end)
        end
    end)
    
    Players.PlayerRemoving:Connect(function()
        if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance and self.ActiveTabInstance.RefreshList then
            pcall(function() self.ActiveTabInstance:RefreshList() end)
        end
    end)
end

return GUI
