-- tabs/scroll_tab.lua
-- Dark Scroll Auto Forge Tab (Fixed Overlap & Compact UI)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local function SafeRequire(path)
    local success, result = pcall(function() return require(path) end)
    return success and result or {}
end

local AccessoryInfo = SafeRequire(ReplicatedStorage.GameInfo.AccessoryInfo)

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReplicaController = Knit.GetController("ReplicaListener")
local ForgeRemote = ReplicatedStorage.Packages.Knit.Services.ForgeService.RF.Forge

local ScrollTab = {}
ScrollTab.__index = ScrollTab

function ScrollTab.new(deps)
    local self = setmetatable({}, ScrollTab)
    
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.Utils = deps.Utils
    self.Config = deps.Config
    self.StatusLabel = deps.StatusLabel
    self.InfoLabel = deps.InfoLabel
    
    self.Container = nil
    self.AccessoryList = nil
    self.SelectedItems = {}
    self.AccessoryCards = {}
    self.IsForging = false
    self.ShouldStop = false
    self.CurrentForgingItem = nil
    self.NeedsUpdate = false
    self.LockOverlay = nil
    
    self.TargetSettings = {
        Damage = 40,
        MaxHealth = 35,
        Exp = 35
    }
    
    self.FORGE_DELAY = 0.5
    self.ORDERED_STATS = {"Damage", "MaxHealth", "Exp"}
    
    return self
end

function ScrollTab:Init(parent)
    local THEME = self.Config.THEME
    
    -- Header
    local header = Instance.new("Frame", parent)
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundTransparency = 1
    
    self.UIFactory.CreateLabel({
        Parent = header,
        Text = "  DARK SCROLL FORGE",
        Size = UDim2.new(1, -8, 0, 28),
        Position = UDim2.new(0, 8, 0, 0),
        TextColor = THEME.TextWhite,
        TextSize = 14,
        Font = Enum.Font.GothamBlack,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    self.UIFactory.CreateLabel({
        Parent = header,
        Text = "Smart auto forge system - All stats must reach target",
        Size = UDim2.new(1, -8, 0, 16),
        Position = UDim2.new(0, 8, 0, 28),
        TextColor = THEME.TextDim,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- Toolbar Settings
    self:CreateToolbar(header)
    
    -- Accessory List
    self.AccessoryList = self.UIFactory.CreateScrollingFrame({
        Parent = parent,
        Size = UDim2.new(1, 0, 1, -52),
        Position = UDim2.new(0, 0, 0, 50),
        UseGrid = true
    })
    
    local padding = Instance.new("UIPadding", self.AccessoryList)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 75)
    
    local layout = self.AccessoryList:FindFirstChild("UIGridLayout")
    if layout then
        layout.CellSize = UDim2.new(0, 92, 0, 115)
        layout.CellPadding = UDim2.new(0, 8, 0, 8)
    end
    
    self:CreateFloatingButtons(parent)
    self:CreateLockOverlay(parent)
    self:StartMonitoring()
    self:RefreshAccessoryList()
end

function ScrollTab:CreateToolbar(parent)
    local THEME = self.Config.THEME
    
    local toolbar = self.UIFactory.CreateFrame({
        Parent = parent,
        Size = UDim2.new(0, 360, 0, 30), 
        Position = UDim2.new(1, -368, 0, 8), 
        BgColor = THEME.CardBg,
        Corner = true,
        Stroke = true
    })
    
    local statConfigs = {
        {key = "Damage", name = "DMG", color = THEME.TextWhite, pos = 6},
        {key = "MaxHealth", name = "HP", color = THEME.TextWhite, pos = 100},
        {key = "Exp", name = "XP", color = THEME.TextWhite, pos = 194}
    }
    
    for _, cfg in ipairs(statConfigs) do
        self:CreateStatControl(toolbar, cfg.key, cfg.name, cfg.color, cfg.pos)
    end
    
    -- เส้นขีด
    self.UIFactory.CreateLabel({
        Parent = toolbar,
        Text = "|",
        Size = UDim2.new(0, 8, 0, 20),
        Position = UDim2.new(0, 284, 0, 5),
        TextColor = THEME.GlassStroke or Color3.fromRGB(255, 255, 255),
        TextTransparency = 0.6,
        TextSize = 20,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Center
    })

    -- Scrolls Counter (ชิดเส้นขีด!)
    self.ScrollCounter = self.UIFactory.CreateLabel({
        Parent = toolbar,
        Text = "0 Scrolls",
        Size = UDim2.new(1, -294, 0, 16), -- 294 → 360 = 66px
        Position = UDim2.new(0, 294, 0, 2), -- เริ่มทันทีหลังเส้นขีด
        TextColor = THEME.TextWhite,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Right
    })
    
    -- Selected Counter
    self.SelectedCounter = self.UIFactory.CreateLabel({
        Parent = toolbar,
        Text = "0 Selected",
        Size = UDim2.new(1, -294, 0, 14),
        Position = UDim2.new(0, 294, 0, 14),
        TextColor = THEME.AccentBlue,
        TextSize = 9,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Right
    })
end

function ScrollTab:CreateStatControl(parent, statKey, displayName, color, xPos)
    local THEME = self.Config.THEME
    
    -- Label ชื่อ (DMG, HP, XP)
    self.UIFactory.CreateLabel({
        Parent = parent,
        Text = displayName,
        Size = UDim2.new(0, 23, 0, 16),
        Position = UDim2.new(0, xPos, 0, 7),
        TextColor = color,
        TextSize = 9,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- [แก้ไข] เปลี่ยนเป็น TextLabel (ไม่ให้พิมพ์เองแล้ว)
    local valueBox = Instance.new("TextLabel", parent)
    valueBox.Size = UDim2.new(0, 30, 0, 16)
    valueBox.Position = UDim2.new(0, xPos + 25, 0, 7)
    valueBox.BackgroundColor3 = THEME.BtnDefault
    valueBox.Text = tostring(self.TargetSettings[statKey]) .. "%"
    valueBox.TextColor3 = THEME.TextWhite
    valueBox.TextSize = 9
    valueBox.Font = Enum.Font.GothamBold
    valueBox.TextXAlignment = Enum.TextXAlignment.Center
    valueBox.BorderSizePixel = 0
    self.UIFactory.AddCorner(valueBox, 4)
    
    -- [ลบ] ส่วน FocusLost ออกไปเลย เพราะพิมพ์ไม่ได้แล้ว
    
    -- ปุ่ม + (สูงสุด 40)
    local plusBtn = self.UIFactory.CreateButton({
        Parent = parent,
        Size = UDim2.new(0, 15, 0, 16),
        Position = UDim2.new(0, xPos + 57, 0, 7),
        Text = "+",
        BgColor = THEME.AccentBlue,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        OnClick = function()
            if self.TargetSettings[statKey] < 40 then
                self.TargetSettings[statKey] = self.TargetSettings[statKey] + 5
                valueBox.Text = self.TargetSettings[statKey] .. "%"
                self.NeedsUpdate = true
            end
        end
    })
    
    -- ปุ่ม - (ต่ำสุด 30)
    local minusBtn = self.UIFactory.CreateButton({
        Parent = parent,
        Size = UDim2.new(0, 15, 0, 16),
        Position = UDim2.new(0, xPos + 74, 0, 7),
        Text = "-",
        BgColor = Color3.fromRGB(120, 50, 50),
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        OnClick = function()
            if self.TargetSettings[statKey] > 30 then
                self.TargetSettings[statKey] = self.TargetSettings[statKey] - 5
                valueBox.Text = self.TargetSettings[statKey] .. "%"
                self.NeedsUpdate = true
            end
        end
    })
end

function ScrollTab:CreateFloatingButtons(parent)
    local THEME = self.Config.THEME
    
    local spacing = 6
    local btnWidth = 110
    local btnHeight = 32
    local startX = -8
    
    self.SelectAllBtn = self.UIFactory.CreateButton({
        Size = UDim2.new(0, btnWidth, 0, btnHeight),
        Position = UDim2.new(1, startX - btnWidth, 1, -38),
        Text = "SELECT ALL",
        BgColor = THEME.CardBg,
        TextColor = THEME.TextWhite,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        Parent = parent,
        OnClick = function() self:ToggleSelectAll() end
    })
    self.SelectAllBtn.ZIndex = 101
    self.SelectAllBtnStroke = self.UIFactory.AddStroke(self.SelectAllBtn, THEME.AccentBlue, 1.5, 0.4)
    
    self.StartBtn = self.UIFactory.CreateButton({
        Size = UDim2.new(0, btnWidth + 10, 0, btnHeight),
        Position = UDim2.new(1, startX - btnWidth*2 - spacing - 10, 1, -38),
        Text = "START FORGE",
        BgColor = THEME.CardBg,
        TextColor = THEME.TextWhite,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        Parent = parent,
        OnClick = function() self:ToggleForge() end
    })
    self.StartBtn.ZIndex = 101
    self.StartBtnStroke = self.UIFactory.AddStroke(self.StartBtn, THEME.AccentBlue, 1.5, 0.4)
end

function ScrollTab:CreateLockOverlay(parent)
    local THEME = self.Config.THEME
    
    self.LockOverlay = Instance.new("Frame", parent)
    self.LockOverlay.Name = "LockOverlay"
    self.LockOverlay.Size = UDim2.new(1, 0, 1, -52)
    self.LockOverlay.Position = UDim2.new(0, 0, 0, 50)
    self.LockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    self.LockOverlay.BackgroundTransparency = 0.6
    self.LockOverlay.BorderSizePixel = 0
    self.LockOverlay.ZIndex = 1000
    self.LockOverlay.Visible = false
    
    self.LockLabel = self.UIFactory.CreateLabel({
        Parent = self.LockOverlay,
        Text = "[FORGING]\nProcessing...",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        TextColor = THEME.TextWhite,
        TextSize = 14,
        Font = Enum.Font.GothamBold
    })
    self.LockLabel.ZIndex = 1001
    self.LockLabel.TextWrapped = true
end

function ScrollTab:ToggleForge()
    if self.IsForging then
        self:StopForge()
    else
        self:StartForge()
    end
end

-- [Safety Check] เพิ่มการเช็ค Scrolls เพื่อกัน Error Nil
function ScrollTab:StartForge()
    local THEME = self.Config.THEME
    local replica = ReplicaController:GetReplica()
    if not replica or not replica.Data then return end
    
    local inv = replica.Data.ItemsService.Inventory
    local scrolls = (inv.Scrolls and inv.Scrolls["5"]) or 0
    
    if scrolls <= 0 then
        self.StateManager:SetStatus("No Dark Scrolls!", THEME.Fail, self.StatusLabel)
        return
    end
    
    local itemsToForge = {}
    for guid, _ in pairs(self.SelectedItems) do
        table.insert(itemsToForge, guid)
    end
    
    if #itemsToForge == 0 then
        self.StateManager:SetStatus("Select items first", THEME.Warning, self.StatusLabel)
        return
    end
    
    self.IsForging = true
    self.ShouldStop = false
    
    self.StartBtn.Text = "STOP FORGE"
    self.StartBtn.TextColor3 = THEME.TextWhite
    self.StartBtnStroke.Color = THEME.Fail
    
    if self.LockOverlay then
        self.LockOverlay.Visible = true
        if self.LockLabel then
            self.LockLabel.Text = "[STARTING]\nPreparing..."
        end
    end
    
    self.SelectAllBtn.TextTransparency = 0.6
    
    task.spawn(function()
        self:ProcessForging(itemsToForge, replica)
    end)
end

function ScrollTab:ProcessForging(itemsToForge, replica)
    local THEME = self.Config.THEME
    local totalForged = 0
    
    for i, guid in ipairs(itemsToForge) do
        if self.ShouldStop then break end
        
        self.CurrentForgingItem = guid
        self.NeedsUpdate = true
        
        local accessories = replica.Data.AccessoryService.Accessories
        local info = accessories[guid]
        
        if not info then
            self.CurrentForgingItem = nil
            continue
        end
        
        self.StateManager:SetStatus(
            string.format("Forging %s (%d/%d)", info.Name, i, #itemsToForge),
            THEME.AccentBlue,
            self.StatusLabel
        )
        
        local attempts = 0
        while self.IsForging and not self:IsItemReachedTarget(info) do
            local inv = replica.Data.ItemsService.Inventory
            local currentScrolls = (inv.Scrolls and inv.Scrolls["5"]) or 0
            
            if currentScrolls <= 0 then
                self.StateManager:SetStatus("Out of Scrolls!", THEME.Fail, self.StatusLabel)
                self.IsForging = false
                break
            end
            
            attempts = attempts + 1
            pcall(function() 
                ForgeRemote:InvokeServer(guid, 5) 
            end)
            
            totalForged = totalForged + 1
            
            if self.LockLabel then
                self.LockLabel.Text = string.format(
                    "[FORGING] %s\n\nItem: %d / %d\nTotal: %d\nAttempts: %d",
                    info.Name, i, #itemsToForge, totalForged, attempts
                )
            end
            
            task.wait(self.FORGE_DELAY)
            
            info = replica.Data.AccessoryService.Accessories[guid]
            if not info then break end
            
            self.NeedsUpdate = true
        end
        
        if not self.IsForging then break end
        
        if self:IsItemReachedTarget(info) then
            self.SelectedItems[guid] = nil
            self.StateManager:SetStatus(
                string.format("%s complete!", info.Name),
                THEME.Success,
                self.StatusLabel
            )
        end
        
        self.CurrentForgingItem = nil
        self.NeedsUpdate = true
        task.wait(0.5)
    end
    
    if self.ShouldStop then
        self.StateManager:SetStatus(
            string.format("Stopped! Total: %d", totalForged),
            THEME.Warning,
            self.StatusLabel
        )
    else
        self.StateManager:SetStatus(
            string.format("Complete! Total: %d", totalForged),
            THEME.Success,
            self.StatusLabel
        )
    end
    
    self:ResetButton()
    task.wait(1)
    self:RefreshAccessoryList()
end

function ScrollTab:StopForge()
    self.ShouldStop = true
    self.StartBtn.Text = "STOPPING..."
    self.StartBtnStroke.Color = self.Config.THEME.Fail
end

function ScrollTab:ResetButton()
    local THEME = self.Config.THEME
    
    self.IsForging = false
    self.ShouldStop = false
    
    self.StartBtn.Text = "START FORGE"
    self.StartBtn.TextColor3 = THEME.TextWhite
    self.StartBtnStroke.Color = THEME.AccentBlue
    
    if self.LockOverlay then
        self.LockOverlay.Visible = false
    end
    
    self.SelectAllBtn.TextTransparency = 0
    self:UpdateSelectButton()
end

function ScrollTab:IsItemReachedTarget(info)
    if not info.Scroll or not info.Scroll.Upgrades then
        return false
    end
    
    local upgrades = info.Scroll.Upgrades
    
    for statKey, targetValue in pairs(self.TargetSettings) do
        local currentValue = (upgrades[statKey] or 0) * 100
        if currentValue < targetValue then
            return false
        end
    end
    
    return true
end

function ScrollTab:RefreshAccessoryList()
    for _, child in pairs(self.AccessoryList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    self.AccessoryCards = {}
    
    local replica = ReplicaController:GetReplica()
    if not replica or not replica.Data then return end
    
    local inv = replica.Data.ItemsService.Inventory
    local scrolls = (inv.Scrolls and inv.Scrolls["5"]) or 0
    self.ScrollCounter.Text = scrolls .. " Scrolls"
    
    local selectedCount = 0
    for _ in pairs(self.SelectedItems) do selectedCount = selectedCount + 1 end
    self.SelectedCounter.Text = selectedCount .. " Selected"
    
    local accessories = replica.Data.AccessoryService.Accessories
    
    for guid, info in pairs(accessories) do
        local baseData = AccessoryInfo[info.Name]
        if baseData then
            self:CreateAccessoryCard(guid, info, baseData)
        end
    end
    
    self:UpdateInfoLabel()
end

function ScrollTab:CreateAccessoryCard(guid, info, baseData)
    local THEME = self.Config.THEME
    local reachedTarget = self:IsItemReachedTarget(info)
    local isCurrentForging = (self.CurrentForgingItem == guid)
    local isSelected = self.SelectedItems[guid]
    
    local Card = self.UIFactory.CreateFrame({
        Parent = self.AccessoryList,
        Size = UDim2.new(0, 92, 0, 115),
        BgColor = isCurrentForging and Color3.fromRGB(80, 50, 120) or THEME.CardBg,
        Corner = true,
        Stroke = true,
        StrokeColor = isCurrentForging and Color3.fromRGB(255, 150, 255) or
                     (isSelected and THEME.AccentBlue or THEME.GlassStroke),
        StrokeThickness = isSelected and 2 or 1
    })
    
    local icon = Instance.new("ImageLabel", Card)
    icon.Size = UDim2.new(0, 50, 0, 50)
    icon.Position = UDim2.new(0.5, -25, 0, 6)
    icon.Image = "rbxassetid://" .. (baseData.Image or "")
    icon.BackgroundColor3 = THEME.BtnDefault
    icon.BorderSizePixel = 0
    self.UIFactory.AddCorner(icon, 8)
    
    if reachedTarget then
        self.UIFactory.CreateLabel({
            Parent = Card,
            Text = "✅",
            Size = UDim2.new(0, 18, 0, 18),
            Position = UDim2.new(1, -20, 0, 2),
            TextSize = 12
        })
    elseif isCurrentForging then
        self.UIFactory.CreateLabel({
            Parent = Card,
            Text = "⚙️",
            Size = UDim2.new(0, 18, 0, 18),
            Position = UDim2.new(1, -20, 0, 2),
            TextSize = 12
        })
    end
    
    if info.Evolution and tonumber(info.Evolution) > 0 then
        local starContainer = Instance.new("Frame", Card)
        starContainer.Size = UDim2.new(1, 0, 0, 12)
        starContainer.Position = UDim2.new(0, 0, 0, 58)
        starContainer.BackgroundTransparency = 1
        
        local layout = Instance.new("UIListLayout", starContainer)
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Padding = UDim.new(0, -2)

        for i = 1, math.min(tonumber(info.Evolution), 3) do
            local s = Instance.new("ImageLabel", starContainer)
            s.Size = UDim2.new(0, 10, 0, 10)
            s.BackgroundTransparency = 1
            s.Image = "rbxassetid://3926305904"
            s.ImageColor3 = THEME.StarColor or Color3.fromRGB(255, 215, 0)
        end
    end
    
    local nameLbl = self.UIFactory.CreateLabel({
        Parent = Card,
        Text = info.Name,
        Size = UDim2.new(1, -8, 0, 14),
        Position = UDim2.new(0, 4, 0, 72),
        TextSize = 8,
        Font = Enum.Font.GothamBold,
        TextColor = THEME.TextWhite
    })
    nameLbl.TextWrapped = true
    
    if info.Scroll and info.Scroll.Upgrades then
        local statsContainer = Instance.new("Frame", Card)
        statsContainer.Size = UDim2.new(1, -8, 0, 24)
        statsContainer.Position = UDim2.new(0, 4, 1, -28)
        statsContainer.BackgroundTransparency = 1
        
        local yPos = 0
        for _, statKey in ipairs(self.ORDERED_STATS) do
            local val = info.Scroll.Upgrades[statKey]
            if val then
                local currentPercent = val * 100
                local targetPercent = self.TargetSettings[statKey]
                local statReached = currentPercent >= targetPercent
                
                local colorMap = {
                    Damage = THEME.Fail,
                    MaxHealth = THEME.Success,
                    Exp = THEME.Warning
                }
                
                local nameMap = {
                    Damage = "DMG",
                    MaxHealth = "HP",
                    Exp = "XP"
                }
                
                local statLabel = self.UIFactory.CreateLabel({
                    Parent = statsContainer,
                    Text = string.format("%s +%d%%", nameMap[statKey], currentPercent) .. (statReached and " ✓" or ""),
                    Size = UDim2.new(1, 0, 0, 8),
                    Position = UDim2.new(0, 0, 0, yPos),
                    TextSize = 7,
                    Font = Enum.Font.GothamBold,
                    TextColor = statReached and colorMap[statKey] or THEME.TextDim,
                    TextXAlign = Enum.TextXAlignment.Left
                })
                
                yPos = yPos + 8
            end
        end
    else
        self.UIFactory.CreateLabel({
            Parent = Card,
            Text = "NO SCROLL",
            Size = UDim2.new(1, -8, 0, 20),
            Position = UDim2.new(0, 4, 1, -24),
            TextSize = 7,
            Font = Enum.Font.GothamBold,
            TextColor = THEME.TextDim
        })
    end
    
    local btn = Instance.new("TextButton", Card)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 2
    
    btn.MouseButton1Click:Connect(function()
        if self.IsForging then return end
        
        self.SelectedItems[guid] = not self.SelectedItems[guid] or nil
        self.NeedsUpdate = true
    end)
    
    self.AccessoryCards[guid] = Card
end

function ScrollTab:ToggleSelectAll()
    if self.IsForging then return end
    
    if self:AreAllSelected() then
        self:DeselectAll()
    else
        self:SelectAll()
    end
    self:UpdateSelectButton()
end

function ScrollTab:AreAllSelected()
    local totalCards = 0
    for _ in pairs(self.AccessoryCards) do totalCards = totalCards + 1 end
    
    local selectedCount = 0
    for _ in pairs(self.SelectedItems) do selectedCount = selectedCount + 1 end
    
    return totalCards > 0 and totalCards == selectedCount
end

function ScrollTab:SelectAll()
    for guid, _ in pairs(self.AccessoryCards) do
        self.SelectedItems[guid] = true
    end
    self.NeedsUpdate = true
end

function ScrollTab:DeselectAll()
    self.SelectedItems = {}
    self.NeedsUpdate = true
end

function ScrollTab:UpdateSelectButton()
    local THEME = self.Config.THEME
    
    self.SelectAllBtn.BackgroundColor3 = THEME.CardBg
    self.SelectAllBtn.TextColor3 = THEME.TextWhite
    
    if self:AreAllSelected() then
        self.SelectAllBtn.Text = "UNSELECT ALL"
        self.SelectAllBtnStroke.Color = THEME.Fail
    else
        self.SelectAllBtn.Text = "SELECT ALL"
        self.SelectAllBtnStroke.Color = THEME.AccentBlue
    end
    
    if self.IsForging then
        self.SelectAllBtn.TextTransparency = 0.6
        self.SelectAllBtnStroke.Transparency = 0.8
    else
        self.SelectAllBtn.TextTransparency = 0
        self.SelectAllBtnStroke.Transparency = 0.4
    end
end

function ScrollTab:UpdateInfoLabel()
    if not self.InfoLabel then return end
    
    local count = 0
    for _ in pairs(self.SelectedItems) do count = count + 1 end
    
    if count > 0 then
        self.InfoLabel.Text = string.format("Selected: %d accessories", count)
        self.InfoLabel.TextColor3 = self.Config.THEME.AccentBlue
    else
        self.InfoLabel.Text = ""
    end
end

function ScrollTab:StartMonitoring()
    local replica = ReplicaController:GetReplica()
    if replica then
        replica:ListenToChange({"ItemsService", "Inventory"}, function() 
            self.NeedsUpdate = true 
        end)
        replica:ListenToChange({"AccessoryService", "Accessories"}, function() 
            self.NeedsUpdate = true 
        end)
    end
    
    RunService.Heartbeat:Connect(function()
        if self.NeedsUpdate then
            self.NeedsUpdate = false
            self:RefreshAccessoryList()
            self:UpdateSelectButton()
        end
    end)
end

return ScrollTab