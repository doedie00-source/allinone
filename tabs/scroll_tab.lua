-- tabs/scroll_tab.lua
-- Dark Scroll Auto Forge Tab (Integrated with Modular System)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Load Info Modules
local function SafeRequire(path)
    local success, result = pcall(function() return require(path) end)
    return success and result or {}
end

local AccessoryInfo = SafeRequire(ReplicatedStorage.GameInfo.AccessoryInfo)
local ItemsInfo = SafeRequire(ReplicatedStorage.GameInfo.ItemsInfo)

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
    self.IsForging = false
    self.CurrentForgingItem = nil
    self.NeedsUpdate = false
    
    -- Target Settings (All stats must reach target)
    self.TargetSettings = {
        Damage = 35,
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
    header.Size = UDim2.new(1, 0, 0, 140)
    header.BackgroundTransparency = 1
    
    self.UIFactory.CreateLabel({
        Parent = header,
        Text = "  DARK SCROLL FORGE",
        Size = UDim2.new(1, -8, 0, 24),
        Position = UDim2.new(0, 8, 0, 0),
        TextColor = THEME.TextWhite,
        TextSize = 14,
        Font = Enum.Font.GothamBlack,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    self.UIFactory.CreateLabel({
        Parent = header,
        Text = "Smart auto forge system - All stats must reach target",
        Size = UDim2.new(1, -8, 0, 14),
        Position = UDim2.new(0, 8, 0, 22),
        TextColor = THEME.TextDim,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- Counters
    self.ScrollCounter = self.UIFactory.CreateLabel({
        Parent = header,
        Text = "0 Scrolls",
        Size = UDim2.new(0, 140, 0, 20),
        Position = UDim2.new(1, -148, 0, 0),
        TextColor = THEME.Success,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Right
    })
    
    self.SelectedCounter = self.UIFactory.CreateLabel({
        Parent = header,
        Text = "0 Selected",
        Size = UDim2.new(0, 140, 0, 16),
        Position = UDim2.new(1, -148, 0, 20),
        TextColor = THEME.Warning,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Right
    })
    
    -- Settings Panel
    self:CreateSettingsPanel(header)
    
    -- Status Panel
    local statusPanel = self.UIFactory.CreateFrame({
        Parent = header,
        Size = UDim2.new(1, 0, 0, 35),
        Position = UDim2.new(0, 0, 0, 105),
        BgColor = THEME.CardBg,
        Corner = true,
        Stroke = true
    })
    
    self.LocalStatusLabel = self.UIFactory.CreateLabel({
        Parent = statusPanel,
        Text = "Ready to forge...",
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        TextColor = THEME.TextGray,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- Accessory List
    self.AccessoryList = self.UIFactory.CreateScrollingFrame({
        Parent = parent,
        Size = UDim2.new(1, 0, 1, -190),
        Position = UDim2.new(0, 0, 0, 145),
        UseGrid = false
    })
    
    local padding = Instance.new("UIPadding", self.AccessoryList)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    
    -- Control Buttons
    self:CreateControlButtons(parent)
    
    -- Start monitoring
    self:StartMonitoring()
    self:RefreshAccessoryList()
end

function ScrollTab:CreateSettingsPanel(parent)
    local THEME = self.Config.THEME
    
    local panel = self.UIFactory.CreateFrame({
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 65),
        Position = UDim2.new(0, 0, 0, 38),
        BgColor = THEME.CardBg,
        Corner = true,
        Stroke = true
    })
    
    self.UIFactory.CreateLabel({
        Parent = panel,
        Text = "  TARGET SETTINGS (Max 40%)",
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 10, 0, 5),
        TextColor = THEME.TextWhite,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    local statConfigs = {
        {key = "Damage", name = "DMG", color = THEME.Fail, pos = 10},
        {key = "MaxHealth", name = "HP", color = THEME.Success, pos = 205},
        {key = "Exp", name = "XP", color = THEME.Warning, pos = 400}
    }
    
    for _, cfg in ipairs(statConfigs) do
        self:CreateStatControl(panel, cfg.key, cfg.name, cfg.color, cfg.pos)
    end
end

function ScrollTab:CreateStatControl(parent, statKey, displayName, color, xPos)
    local THEME = self.Config.THEME
    
    local container = self.UIFactory.CreateFrame({
        Parent = parent,
        Size = UDim2.new(0, 180, 0, 38),
        Position = UDim2.new(0, xPos, 0, 25),
        BgColor = THEME.GlassBg,
        Corner = true
    })
    
    self.UIFactory.CreateLabel({
        Parent = container,
        Text = displayName,
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(0, 8, 0, 9),
        TextColor = color,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    local valueBox = Instance.new("TextBox", container)
    valueBox.Size = UDim2.new(0, 60, 0, 24)
    valueBox.Position = UDim2.new(0, 50, 0, 7)
    valueBox.BackgroundColor3 = THEME.BtnDefault
    valueBox.Text = tostring(self.TargetSettings[statKey]) .. "%"
    valueBox.TextColor3 = THEME.TextWhite
    valueBox.TextSize = 12
    valueBox.Font = Enum.Font.GothamBold
    valueBox.TextXAlignment = Enum.TextXAlignment.Center
    valueBox.BorderSizePixel = 0
    self.UIFactory.AddCorner(valueBox, 6)
    
    valueBox.FocusLost:Connect(function()
        local num = tonumber(valueBox.Text:gsub("%%", ""))
        if num and num >= 0 and num <= 40 then
            self.TargetSettings[statKey] = num
            valueBox.Text = num .. "%"
            self.NeedsUpdate = true
        else
            valueBox.Text = self.TargetSettings[statKey] .. "%"
        end
    end)
    
    local plusBtn = self.UIFactory.CreateButton({
        Parent = container,
        Size = UDim2.new(0, 28, 0, 24),
        Position = UDim2.new(0, 115, 0, 7),
        Text = "+",
        BgColor = Color3.fromRGB(50, 120, 50),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        OnClick = function()
            if self.TargetSettings[statKey] < 40 then
                self.TargetSettings[statKey] = math.min(40, self.TargetSettings[statKey] + 5)
                valueBox.Text = self.TargetSettings[statKey] .. "%"
                self.NeedsUpdate = true
            end
        end
    })
    
    local minusBtn = self.UIFactory.CreateButton({
        Parent = container,
        Size = UDim2.new(0, 28, 0, 24),
        Position = UDim2.new(0, 147, 0, 7),
        Text = "-",
        BgColor = Color3.fromRGB(120, 50, 50),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        OnClick = function()
            if self.TargetSettings[statKey] > 0 then
                self.TargetSettings[statKey] = math.max(0, self.TargetSettings[statKey] - 5)
                valueBox.Text = self.TargetSettings[statKey] .. "%"
                self.NeedsUpdate = true
            end
        end
    })
end

function ScrollTab:CreateControlButtons(parent)
    local THEME = self.Config.THEME
    
    local btnContainer = Instance.new("Frame", parent)
    btnContainer.Size = UDim2.new(1, 0, 0, 40)
    btnContainer.Position = UDim2.new(0, 0, 1, -45)
    btnContainer.BackgroundTransparency = 1
    
    self.StartBtn = self.UIFactory.CreateButton({
        Parent = btnContainer,
        Size = UDim2.new(0, 250, 0, 38),
        Position = UDim2.new(0.5, -125, 0, 0),
        Text = "START SMART FORGE",
        BgColor = THEME.AccentBlue,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        OnClick = function() self:ToggleForge() end
    })
    self.UIFactory.AddStroke(self.StartBtn, THEME.GlassStroke, 2, 0)
end

function ScrollTab:ToggleForge()
    if self.IsForging then
        self:StopForge()
    else
        self:StartForge()
    end
end

function ScrollTab:StartForge()
    local THEME = self.Config.THEME
    local replica = ReplicaController:GetReplica()
    if not replica or not replica.Data then return end
    
    local scrolls = replica.Data.ItemsService.Inventory.Scrolls["5"] or 0
    if scrolls <= 0 then
        self:SetLocalStatus("No Dark Scrolls available!", THEME.Fail)
        return
    end
    
    local itemsToForge = {}
    for guid, _ in pairs(self.SelectedItems) do
        table.insert(itemsToForge, guid)
    end
    
    if #itemsToForge == 0 then
        self:SetLocalStatus("Please select items to forge", THEME.Warning)
        return
    end
    
    self.IsForging = true
    self.StartBtn.Text = "STOP FORGE"
    self.StartBtn.BackgroundColor3 = THEME.Fail
    
    task.spawn(function()
        for i, guid in ipairs(itemsToForge) do
            if not self.IsForging then break end
            
            self.CurrentForgingItem = guid
            self.NeedsUpdate = true
            
            local accessories = replica.Data.AccessoryService.Accessories
            local info = accessories[guid]
            
            if not info then
                self.CurrentForgingItem = nil
                continue
            end
            
            self:SetLocalStatus(string.format("Forging %s (%d/%d)", info.Name, i, #itemsToForge), THEME.Warning)
            
            while self.IsForging and not self:IsItemReachedTarget(info) do
                if (replica.Data.ItemsService.Inventory.Scrolls["5"] or 0) <= 0 then
                    self:SetLocalStatus("Out of Dark Scrolls!", THEME.Fail)
                    self.IsForging = false
                    break
                end
                
                pcall(function() 
                    ForgeRemote:InvokeServer(guid, 5) 
                end)
                
                task.wait(self.FORGE_DELAY)
                
                info = replica.Data.AccessoryService.Accessories[guid]
                if not info then break end
                
                self.NeedsUpdate = true
            end
            
            if not self.IsForging then break end
            
            if self:IsItemReachedTarget(info) then
                self.SelectedItems[guid] = nil
                self:SetLocalStatus(string.format("%s complete! All stats reached target!", info.Name), THEME.Success)
            end
            
            self.CurrentForgingItem = nil
            self.NeedsUpdate = true
            task.wait(0.5)
        end
        
        self:StopForge()
        self:SetLocalStatus("Forge completed!", THEME.Success)
    end)
end

function ScrollTab:StopForge()
    local THEME = self.Config.THEME
    self.IsForging = false
    self.CurrentForgingItem = nil
    self.StartBtn.Text = "START SMART FORGE"
    self.StartBtn.BackgroundColor3 = THEME.AccentBlue
    self.NeedsUpdate = true
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
    
    local replica = ReplicaController:GetReplica()
    if not replica or not replica.Data then return end
    
    local scrolls = replica.Data.ItemsService.Inventory.Scrolls["5"] or 0
    self.ScrollCounter.Text = scrolls .. " Scrolls"
    
    local selectedCount = 0
    for _ in pairs(self.SelectedItems) do selectedCount = selectedCount + 1 end
    self.SelectedCounter.Text = selectedCount .. " Selected"
    
    local accessories = replica.Data.AccessoryService.Accessories
    local count = 0
    
    for guid, info in pairs(accessories) do
        local baseData = AccessoryInfo[info.Name]
        if not baseData then continue end
        
        count = count + 1
        self:CreateAccessoryCard(guid, info, baseData)
    end
    
    self.AccessoryList.CanvasSize = UDim2.new(0, 0, 0, count * 83)
end

function ScrollTab:CreateAccessoryCard(guid, info, baseData)
    local THEME = self.Config.THEME
    local reachedTarget = self:IsItemReachedTarget(info)
    local isCurrentForging = (self.CurrentForgingItem == guid)
    local isSelected = self.SelectedItems[guid]
    
    local card = self.UIFactory.CreateFrame({
        Parent = self.AccessoryList,
        Size = UDim2.new(1, -10, 0, 75),
        BgColor = isCurrentForging and Color3.fromRGB(80, 50, 120) or 
                  (reachedTarget and Color3.fromRGB(40, 80, 40) or 
                  (isSelected and THEME.CardBg or THEME.GlassBg)),
        Corner = true,
        Stroke = true,
        StrokeColor = isCurrentForging and Color3.fromRGB(255, 150, 255) or
                     (reachedTarget and THEME.Success or
                     (isSelected and THEME.AccentBlue or THEME.GlassStroke)),
        StrokeThickness = isSelected and 2 or 1
    })
    
    -- Icon
    local icon = Instance.new("ImageLabel", card)
    icon.Size = UDim2.new(0, 60, 0, 60)
    icon.Position = UDim2.new(0, 8, 0, 7)
    icon.Image = "rbxassetid://" .. (baseData.Image or "")
    icon.BackgroundColor3 = THEME.BtnDefault
    icon.BorderSizePixel = 0
    self.UIFactory.AddCorner(icon, 8)
    
    -- Name
    self.UIFactory.CreateLabel({
        Parent = card,
        Text = info.Name,
        Size = UDim2.new(0, 220, 0, 25),
        Position = UDim2.new(0, 75, 0, 5),
        TextColor = THEME.TextWhite,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- Stats Container
    local statsContainer = Instance.new("Frame", card)
    statsContainer.Size = UDim2.new(0, 510, 0, 32)
    statsContainer.Position = UDim2.new(0, 75, 0, 33)
    statsContainer.BackgroundTransparency = 1
    
    local statsLayout = Instance.new("UIListLayout", statsContainer)
    statsLayout.FillDirection = Enum.FillDirection.Horizontal
    statsLayout.Padding = UDim.new(0, 10)
    
    if info.Scroll and info.Scroll.Upgrades then
        for _, statKey in ipairs(self.ORDERED_STATS) do
            local val = info.Scroll.Upgrades[statKey]
            if val then
                local currentPercent = val * 100
                local targetPercent = self.TargetSettings[statKey]
                local statReached = currentPercent >= targetPercent
                
                self:CreateStatDisplay(statsContainer, statKey, currentPercent, statReached)
            end
        end
    else
        local noScroll = self.UIFactory.CreateFrame({
            Parent = statsContainer,
            Size = UDim2.new(0, 140, 1, 0),
            BgColor = Color3.fromRGB(50, 40, 40),
            Corner = true
        })
        
        self.UIFactory.CreateLabel({
            Parent = noScroll,
            Text = "NO DARK SCROLL",
            Size = UDim2.new(1, 0, 1, 0),
            TextSize = 10,
            TextColor = THEME.TextDim,
            Font = Enum.Font.GothamBold
        })
    end
    
    -- Status Icon
    if reachedTarget then
        self.UIFactory.CreateLabel({
            Parent = card,
            Text = "✅",
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -35, 0, 5),
            TextSize = 20
        })
    elseif isCurrentForging then
        self.UIFactory.CreateLabel({
            Parent = card,
            Text = "⚙️",
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -35, 0, 5),
            TextSize = 20
        })
    end
    
    -- Click Button
    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 2
    
    btn.MouseButton1Click:Connect(function()
        self.SelectedItems[guid] = not self.SelectedItems[guid] or nil
        self.NeedsUpdate = true
    end)
end

function ScrollTab:CreateStatDisplay(parent, statKey, currentPercent, reached)
    local THEME = self.Config.THEME
    
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
    
    local box = self.UIFactory.CreateFrame({
        Parent = parent,
        Size = UDim2.new(0, 105, 1, 0),
        BgColor = reached and Color3.fromRGB(40, 80, 45) or THEME.BtnDefault,
        Corner = true
    })
    
    local text = string.format("%s +%d%%", nameMap[statKey], currentPercent)
    if reached then text = text .. " ✓" end
    
    self.UIFactory.CreateLabel({
        Parent = box,
        Text = text,
        Size = UDim2.new(1, -6, 1, 0),
        Position = UDim2.new(0, 3, 0, 0),
        TextColor = colorMap[statKey],
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
end

function ScrollTab:SetLocalStatus(text, color)
    local THEME = self.Config.THEME
    self.LocalStatusLabel.Text = text
    self.LocalStatusLabel.TextColor3 = color or THEME.TextGray
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
        end
    end)
end

return ScrollTab
