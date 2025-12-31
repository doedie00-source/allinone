-- tabs/dupe_tab.lua
-- Dupe Tab Module - FIXED POPUP OVERLAP

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReplicaListener = Knit.GetController("ReplicaListener")

local SuccessLoadCrates, CratesInfo = pcall(function() 
    return require(ReplicatedStorage.GameInfo.CratesInfo) 
end)
if not SuccessLoadCrates then CratesInfo = {} end

local SuccessLoadPets, PetsInfo = pcall(function() 
    return require(ReplicatedStorage.GameInfo.PetsInfo) 
end)
if not SuccessLoadPets then PetsInfo = {} end

local DupeTab = {}
DupeTab.__index = DupeTab

function DupeTab.new(deps)
    local self = setmetatable({}, DupeTab)
    
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.TradeManager = deps.TradeManager
    self.Utils = deps.Utils
    self.Config = deps.Config
    self.StatusLabel = deps.StatusLabel
    self.InfoLabel = deps.InfoLabel
    self.ScreenGui = deps.ScreenGui
    
    self.Container = nil
    self.SubTabButtons = {}
    self.CurrentSubTab = "Items"
    self.FloatingButtons = {} 
    self.TooltipRef = nil
    
    -- ✅ เพิ่ม flag ป้องกัน popup ซ้อนทับ
    self.isPopupOpen = false
    self.currentPopup = nil
    
    return self
end

function DupeTab:Init(parent)
    local THEME = self.Config.THEME
    
    local header = Instance.new("Frame", parent)
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 72)
    header.BackgroundTransparency = 1
    
    local title = self.UIFactory.CreateLabel({
        Parent = header,
        Text = "  DUPE SYSTEM",
        Size = UDim2.new(1, -8, 0, 26),
        Position = UDim2.new(0, 8, 0, 0),
        TextColor = THEME.TextWhite,
        TextSize = 14,
        Font = Enum.Font.GothamBlack,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    local subtitle = self.UIFactory.CreateLabel({
        Parent = header,
        Text = "Dupe items, crates, and pets using trade exploit",
        Size = UDim2.new(1, -8, 0, 16),
        Position = UDim2.new(0, 8, 0, 24),
        TextColor = THEME.TextDim,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- ==========================================
    -- ✅ ปรับปรุงปุ่มขวาบน (ใช้สไตล์ CardBg + Stroke)
    -- ==========================================
    local ctrlContainer = Instance.new("Frame", header)
    ctrlContainer.Size = UDim2.new(0, 200, 0, 32)
    ctrlContainer.Position = UDim2.new(1, -8, 0, 2)
    ctrlContainer.AnchorPoint = Vector2.new(1, 0)
    ctrlContainer.BackgroundTransparency = 1
    
    local ctrlLayout = Instance.new("UIListLayout", ctrlContainer)
    ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
    ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    ctrlLayout.Padding = UDim.new(0, 8)

    -- ปุ่ม Cancel (สไตล์เดียวกับ Delete Pet)
    local btnCancel = self.UIFactory.CreateButton({
        Parent = ctrlContainer,
        Text = "CANCEL",
        Size = UDim2.new(0, 80, 0, 28),
        BgColor = THEME.CardBg,     -- พื้นหลังสีเข้ม
        TextColor = THEME.TextWhite,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6,
        OnClick = function()
            self.TradeManager.ActionCancelTrade(self.StatusLabel, self.StateManager, self.Utils)
        end
    })
    -- ใส่ขอบสีแดง
    self.UIFactory.AddStroke(btnCancel, THEME.Fail, 1.5, 0.4)


    -- ==========================================

    local tabsContainer = Instance.new("Frame", header)
    tabsContainer.Size = UDim2.new(1, -8, 0, 32)
    tabsContainer.Position = UDim2.new(0, 8, 0, 42)
    tabsContainer.BackgroundTransparency = 1
    
    local tabsLayout = Instance.new("UIListLayout", tabsContainer)
    tabsLayout.FillDirection = Enum.FillDirection.Horizontal
    tabsLayout.Padding = UDim.new(0, 6)
    
    self:CreateSubTab(tabsContainer, "Items", "ITEMS")
    self:CreateSubTab(tabsContainer, "Crates", "CRATES")
    self:CreateSubTab(tabsContainer, "Pets", "PETS")
    
    self.Container = self.UIFactory.CreateScrollingFrame({
        Parent = parent,
        Size = UDim2.new(1, 0, 1, -76),
        Position = UDim2.new(0, 0, 0, 74)
    })
    
    self:CreateFloatingButtons(parent)
    self:SwitchSubTab("Items")
end

function DupeTab:CreateFloatingButtons(parent)
    local THEME = self.Config.THEME
    
    local spacing = 6
    local btnWidth = 90
    local btnHeight = 32
    local startX = -8 
    

    self.FloatingButtons.BtnDupePet = self.UIFactory.CreateButton({
        Size = UDim2.new(0, btnWidth, 0, btnHeight),
        Position = UDim2.new(1, startX - btnWidth, 1, -38),
        Text = "DUPE",
        BgColor = THEME.CardBg, -- ✅ ใช้พื้นหลังสี Card

        TextColor = THEME.TextWhite,
        TextSize = 12,          -- ✅ ขนาด 12 ตัวหนา
        Font = Enum.Font.GothamBold,
        Parent = parent,
        OnClick = function() self:OnDupePets() end
    })
    self.FloatingButtons.BtnDupePet.ZIndex = 101
    self.FloatingButtons.BtnDupePet.Visible = false
    self.UIFactory.AddStroke(self.FloatingButtons.BtnDupePet, THEME.AccentBlue, 1.5, 0.4)
    

    self.FloatingButtons.BtnEvoPet = self.UIFactory.CreateButton({
        Size = UDim2.new(0, btnWidth + 15, 0, btnHeight),
        Position = UDim2.new(1, startX - btnWidth*2 - spacing - 15, 1, -38),
        Text = "EVOLVE",
        BgColor = THEME.CardBg, -- ✅ ใช้พื้นหลังสี Card
        TextColor = THEME.TextWhite,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        Parent = parent,
        OnClick = function() self:OnEvolvePets() end
    })
    self.FloatingButtons.BtnEvoPet.ZIndex = 101
    self.FloatingButtons.BtnEvoPet.Visible = false

    self.UIFactory.AddStroke(self.FloatingButtons.BtnEvoPet, THEME.AccentBlue, 1.5, 0.4)
    

    self.FloatingButtons.BtnDeletePet = self.UIFactory.CreateButton({
        Size = UDim2.new(0, btnWidth, 0, btnHeight),
        Position = UDim2.new(1, startX - btnWidth*3 - spacing*2 - 15, 1, -38),
        Text = "DELETE",
        BgColor = THEME.CardBg, -- ✅ ใช้พื้นหลังสี Card
        TextColor = THEME.TextWhite,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        Parent = parent,
        OnClick = function() self:OnDeletePets() end
    })
    self.FloatingButtons.BtnDeletePet.ZIndex = 101
    self.FloatingButtons.BtnDeletePet.Visible = false

    self.UIFactory.AddStroke(self.FloatingButtons.BtnDeletePet, THEME.Fail, 1.5, 0.4)
    
    self.FloatingButtons.BtnAddAll1k = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 140, 0, btnHeight),
        Position = UDim2.new(1, -148, 1, -38),
        Text = "ADD ALL",
        BgColor = THEME.CardBg, -- ✅ ใช้พื้นหลังสี Card
        TextColor = THEME.TextWhite,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        Parent = parent
    })
    if self.FloatingButtons.BtnAddAll1k then
        self.FloatingButtons.BtnAddAll1k.ZIndex = 101
        self.FloatingButtons.BtnAddAll1k.Visible = false

        self.UIFactory.AddStroke(self.FloatingButtons.BtnAddAll1k, THEME.AccentBlue, 1.5, 0.4)
    end
end

function DupeTab:CreateSubTab(parent, name, text)
    local THEME = self.Config.THEME
    
    local btn = self.UIFactory.CreateButton({
        Parent = parent,
        Text = text,
        Size = UDim2.new(0, 95, 0, 32),
        BgColor = THEME.BtnDefault,
        TextColor = THEME.TextGray,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6,
        OnClick = function()
            self:SwitchSubTab(name)
        end
    })
    
    self.SubTabButtons[name] = btn
end

function DupeTab:SwitchSubTab(name)
    local THEME = self.Config.THEME
    
    self.CurrentSubTab = name
    self.StateManager.currentDupeTab = name

    for tabName, btn in pairs(self.SubTabButtons) do
        local isSelected = (tabName == name)
        btn.BackgroundColor3 = isSelected and THEME.AccentBlue or THEME.BtnDefault
        btn.TextColor3 = isSelected and THEME.TextWhite or THEME.TextGray
    end
    

    if name == "Pets" then
        if self.FloatingButtons.BtnDeletePet then self.FloatingButtons.BtnDeletePet.Visible = true end
        if self.FloatingButtons.BtnEvoPet then self.FloatingButtons.BtnEvoPet.Visible = true end
        if self.FloatingButtons.BtnDupePet then self.FloatingButtons.BtnDupePet.Visible = true end
        if self.FloatingButtons.BtnAddAll1k then self.FloatingButtons.BtnAddAll1k.Visible = false end
    elseif name == "Crates" then
        if self.FloatingButtons.BtnDeletePet then self.FloatingButtons.BtnDeletePet.Visible = false end
        if self.FloatingButtons.BtnEvoPet then self.FloatingButtons.BtnEvoPet.Visible = false end
        if self.FloatingButtons.BtnDupePet then self.FloatingButtons.BtnDupePet.Visible = false end
        if self.FloatingButtons.BtnAddAll1k then self.FloatingButtons.BtnAddAll1k.Visible = true end
    else  -- Items
        for _, btn in pairs(self.FloatingButtons) do
            if btn then btn.Visible = false end
        end
    end
    
    -- Update Info Label
    if self.InfoLabel then
        if name == "Items" then
            self.InfoLabel.Text = "⚠️ LIMITS: Scrolls ~150 | Tickets ~10K | Potions ~2K"
        else
            self.InfoLabel.Text = ""
        end
    end
    
    self:RefreshInventory()
end

function DupeTab:RefreshInventory()
    -- Clear container
    for _, child in pairs(self.Container:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
    
    -- Render Content
    if self.CurrentSubTab == "Items" then
        self:RenderItemDupeGrid()
    elseif self.CurrentSubTab == "Crates" then
        self:RenderCrateGrid()
    elseif self.CurrentSubTab == "Pets" then
        self:RenderPetDupeGrid()
    end
end

function DupeTab:UpdateStatusWarning()
    if self.CurrentSubTab == "Items" and self.InfoLabel then
        self.InfoLabel.Text = "⚠️ LIMITS: Scrolls ~150 | Tickets ~10K | Potions ~2K"
    elseif self.InfoLabel then
        self.InfoLabel.Text = ""
    end
end

-- ============================ RENDERING ============================

function DupeTab:RenderItemDupeGrid()
    local THEME = self.Config.THEME
    local DUPE_RECIPES = self.Config.DUPE_RECIPES
    
    self.Container.ScrollBarThickness = 4
    self.Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.Container.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    if self.Container:FindFirstChild("UIListLayout") then
        self.Container.UIListLayout:Destroy()
    end
    
    local padding = self.Container:FindFirstChild("UIPadding") or Instance.new("UIPadding", self.Container)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 12)
    
    local layout = self.Container:FindFirstChild("UIGridLayout") or Instance.new("UIGridLayout", self.Container)
    layout.CellPadding = UDim2.new(0, 6, 0, 6)
    layout.CellSize = UDim2.new(0, 92, 0, 115)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local recipes = DUPE_RECIPES.Items or {}
    local playerData = self.InventoryManager.GetPlayerData()
    
    self:UpdateStatusWarning()
    
    for _, recipe in ipairs(recipes) do
        self:CreateItemCard(recipe, playerData)
    end
end

function DupeTab:CreateItemCard(recipe, playerData)
    local THEME = self.Config.THEME
    local serviceName = recipe.Service
    
    local function checkHasItem(svc, t)
        if not playerData or not playerData.ItemsService or not playerData.ItemsService.Inventory then 
            return false 
        end
        local category = playerData.ItemsService.Inventory[svc]
        if not category then return false end
        local amount = category[tostring(t)] or category[tonumber(t)] or 0
        return amount > 0
    end
    
    local isOwned = checkHasItem(serviceName, recipe.Tier)
    
    local totalNeeded, foundCount = 0, 0
    local isPotion = (serviceName == "Strawberry" or serviceName:find("Potion"))
    
    if isPotion then
        for _, tier in ipairs(recipe.RequiredTiers) do
            if tonumber(tier) ~= tonumber(recipe.Tier) then
                totalNeeded = totalNeeded + 1
                if checkHasItem(serviceName, tier) then
                    foundCount = foundCount + 1
                end
            end
        end
    else
        totalNeeded = 2
        for _, tier in ipairs(recipe.RequiredTiers) do
            local tNum = tonumber(tier)
            if tNum > 2 and tNum ~= tonumber(recipe.Tier) then
                if checkHasItem(serviceName, tNum) then
                    foundCount = foundCount + 1
                end
            end
        end
    end
    
    local isReady = (not isOwned) and (foundCount >= totalNeeded)
    
    local Card = Instance.new("Frame", self.Container)
    Card.Name = recipe.Name
    Card.BackgroundColor3 = THEME.CardBg
    Card.BackgroundTransparency = 0.2
    Card.BorderSizePixel = 0
    self.UIFactory.AddCorner(Card, 10)
    
    local strokeColor = THEME.GlassStroke
    local statusText = ""
    
    if isOwned then
        strokeColor = THEME.Fail
        statusText = "<font color='#ff5555' size='9'>(OWNED)</font>"
    elseif isReady then
        strokeColor = THEME.AccentBlue
        statusText = "<font color='#00ffaa' size='10'>✓ READY</font>"
    else
        strokeColor = THEME.Warning
        statusText = string.format("<font color='#ffcc33' size='9'>Missing: %d/%d</font>", foundCount, totalNeeded)
    end
    
    self.UIFactory.AddStroke(Card, strokeColor, 1.5, 0.4)
    
    local Image = Instance.new("ImageLabel", Card)
    Image.BackgroundTransparency = 1
    Image.Position = UDim2.new(0.5, -32, 0, 10)
    Image.Size = UDim2.new(0, 64, 0, 64)
    Image.Image = "rbxassetid://" .. (recipe.Image or "0")
    Image.ScaleType = Enum.ScaleType.Fit
    if isOwned then Image.ImageColor3 = Color3.fromRGB(80, 80, 80) end
    
    local NameLbl = Instance.new("TextLabel", Card)
    NameLbl.BackgroundTransparency = 1
    NameLbl.Position = UDim2.new(0, 4, 0, 78)
    NameLbl.Size = UDim2.new(1, -8, 0, 48)
    NameLbl.Font = Enum.Font.GothamBold
    NameLbl.TextSize = 10
    NameLbl.TextWrapped = true
    NameLbl.TextYAlignment = Enum.TextYAlignment.Top
    NameLbl.RichText = true
    NameLbl.Text = recipe.Name .. "\n" .. statusText
    NameLbl.TextColor3 = isOwned and Color3.fromRGB(120, 120, 120) or THEME.TextWhite
    
    local ClickBtn = Instance.new("TextButton", Card)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.Text = ""
    
    ClickBtn.MouseButton1Click:Connect(function()
        -- ✅ ป้องกันการคลิกซ้ำขณะ popup เปิดอยู่
        if self.isPopupOpen then return end
        
        if self.TradeManager.IsProcessing then return end
        
        if not self.Utils.IsTradeActive() then
            self.StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, self.StatusLabel)
            return
        end
        
        if isOwned then
            self.StateManager:SetStatus("❌ Already Owned (Limit 1)", THEME.Fail, self.StatusLabel)
            return
        end
        
        if not isReady then
            self.StateManager:SetStatus(string.format("⚠️ Missing Ingredients (%d/%d)", foundCount, totalNeeded), THEME.Warning, self.StatusLabel)
            return
        end
        
        local startVal, currentMax = 99, 100
        if serviceName == "Scrolls" then
            startVal, currentMax = 99, 500
        elseif serviceName == "Tickets" then
            startVal, currentMax = 5000, 10000
        else
            startVal, currentMax = 500, 1000
        end
        
        self:ShowQuantityPopup({Default = startVal, Max = currentMax}, function(quantity)
            self.TradeManager.ExecuteMagicDupe(recipe, self.StatusLabel, quantity, self.StateManager, self.Utils, self.InventoryManager)
        end)
    end)
end

function DupeTab:RenderCrateGrid()
    local THEME = self.Config.THEME
    
    self.Container.ScrollBarThickness = 4
    self.Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.Container.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    if self.Container:FindFirstChild("UIListLayout") then
        self.Container.UIListLayout:Destroy()
    end
    
    local padding = self.Container:FindFirstChild("UIPadding") or Instance.new("UIPadding", self.Container)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 12)
    
    local layout = self.Container:FindFirstChild("UIGridLayout") or Instance.new("UIGridLayout", self.Container)
    layout.CellPadding = UDim2.new(0, 6, 0, 6)
    layout.CellSize = UDim2.new(0, 88, 0, 102)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local replica = ReplicaListener:GetReplica()
    local playerData = replica and replica.Data
    local inventoryCrates = (playerData and playerData.CratesService and playerData.CratesService.Crates) or {}
    
    local cratesList = {}
    for internalId, info in pairs(CratesInfo) do
        if type(info) == "table" then
            local displayName = info.Name or internalId
            if displayName ~= "KeKa Crate" then
                table.insert(cratesList, {
                    DisplayName = displayName,
                    InternalID = internalId,
                    Image = info.Image or "0"
                })
            end
        end
    end
    table.sort(cratesList, function(a, b) return a.DisplayName < b.DisplayName end)
    
    if self.AddAllConn then self.AddAllConn:Disconnect() end
    if self.FloatingButtons.BtnAddAll1k then
        self.AddAllConn = self.FloatingButtons.BtnAddAll1k.MouseButton1Click:Connect(function()
            if self.isPopupOpen then return end
            
            self:ShowQuantityPopup({Default = 1000, Max = 1000}, function(qty)
                self:OnAddAllCrates(cratesList, inventoryCrates, qty)
            end)
        end)
    end
    
    for _, crate in ipairs(cratesList) do
        self:CreateCrateCard(crate, inventoryCrates)
    end
end

function DupeTab:CreateCrateCard(crate, inventoryCrates)
    local THEME = self.Config.THEME
    
    local amountInInv = inventoryCrates[crate.DisplayName] or inventoryCrates[crate.InternalID]
    local isOwnedInSystem = (amountInInv ~= nil)
    local isSelected = self.StateManager.selectedCrates[crate.DisplayName] ~= nil
    local isInTrade = self.StateManager:IsInTrade(crate.DisplayName)
    local shouldHighlight = isSelected or isInTrade
    
    local Card = Instance.new("Frame", self.Container)
    Card.Name = crate.DisplayName
    Card.BackgroundColor3 = THEME.CardBg
    Card.BackgroundTransparency = 0.2
    Card.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(Card, 10)
    
    if isOwnedInSystem then
        self.UIFactory.AddStroke(Card, THEME.Fail, 2, 0.3)
    elseif shouldHighlight then
        self.UIFactory.AddStroke(Card, THEME.CrateSelected, 2, 0.3)
    end

    
    local Image = Instance.new("ImageLabel", Card)
    Image.BackgroundTransparency = 1
    Image.Position = UDim2.new(0.5, -30, 0, 10)
    Image.Size = UDim2.new(0, 60, 0, 60)
    Image.ImageTransparency = 0
    local imgId = tostring(crate.Image)
    if not imgId:find("rbxassetid://") then imgId = "rbxassetid://" .. imgId end
    Image.Image = imgId
    Image.ScaleType = Enum.ScaleType.Fit
    
    local NameLbl = Instance.new("TextLabel", Card)
    NameLbl.BackgroundTransparency = 1
    NameLbl.Position = UDim2.new(0, 4, 0, 72)
    NameLbl.Size = UDim2.new(1, -8, 0, 38)
    NameLbl.Font = Enum.Font.GothamMedium
    NameLbl.TextSize = 9
    NameLbl.TextWrapped = true
    NameLbl.TextYAlignment = Enum.TextYAlignment.Top
    NameLbl.RichText = true
    
    if shouldHighlight then
        local amt = self.StateManager.selectedCrates[crate.DisplayName] or
                    (self.StateManager.itemsInTrade[crate.DisplayName] and self.StateManager.itemsInTrade[crate.DisplayName].Amount) or 0
        NameLbl.Text = crate.DisplayName .. "\n<font color='#43B581'>[x" .. amt .. "]</font>"
        NameLbl.TextColor3 = THEME.CrateSelected
    elseif isOwnedInSystem then
        NameLbl.Text = crate.DisplayName .. "\n<font color='#ff5555'>(OWNED)</font>"
        NameLbl.TextColor3 = Color3.fromRGB(120, 120, 120)
    else
        NameLbl.Text = crate.DisplayName
        NameLbl.TextColor3 = THEME.TextWhite
    end
    
    local ClickBtn = Instance.new("TextButton", Card)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.Text = ""
    
    ClickBtn.MouseButton1Click:Connect(function()
        -- ✅ ป้องกันการคลิกซ้ำขณะ popup เปิดอยู่
        if self.isPopupOpen then return end
        
        self:OnCrateCardClick(crate, isOwnedInSystem)
    end)
end

function DupeTab:OnCrateCardClick(crate, isOwnedInSystem)
    local THEME = self.Config.THEME
    
    if not self.Utils.IsTradeActive() then
        self.StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, self.StatusLabel)
        return
    end
    
    if isOwnedInSystem then
        self.StateManager:SetStatus("🚫 Locked: You already own this crate", THEME.Fail, self.StatusLabel)
        return
    end
    
    local isAlreadyAdded = self.StateManager.selectedCrates[crate.DisplayName] or self.StateManager:IsInTrade(crate.DisplayName)
    
    if isAlreadyAdded then
        local oldAmount = self.StateManager.selectedCrates[crate.DisplayName] or
                        (self.StateManager.itemsInTrade[crate.DisplayName] and self.StateManager.itemsInTrade[crate.DisplayName].Amount) or 1000
        self.StateManager:ToggleCrateSelection(crate.DisplayName, nil)
        self.TradeManager.SendTradeSignal("Remove", {
            Name = crate.DisplayName,
            Service = "CratesService",
            Category = "Crates"
        }, oldAmount, self.StatusLabel, self.StateManager, self.Utils)
        self:RefreshInventory()
    else
        self:ShowQuantityPopup({Default = 1000, Max = 9999}, function(qty)
            self.StateManager:ToggleCrateSelection(crate.DisplayName, qty)
            self.TradeManager.SendTradeSignal("Add", {
                Name = crate.DisplayName,
                Service = "CratesService",
                Category = "Crates"
            }, qty, self.StatusLabel, self.StateManager, self.Utils)
            self:RefreshInventory()
        end)
    end
end

function DupeTab:OnAddAllCrates(cratesList, inventoryCrates, quantity)
    local THEME = self.Config.THEME
    
    if not self.Utils.IsTradeActive() then
        self.StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, self.StatusLabel)
        return
    end
    
    if self.FloatingButtons.BtnAddAll1k then
        self.FloatingButtons.BtnAddAll1k.Active = false
        self.FloatingButtons.BtnAddAll1k.Text = "ADDING..."
    end
    self.StateManager:SetStatus("🚀 Adding missing crates (" .. quantity .. ")...", THEME.AccentBlue, self.StatusLabel)

    
    task.spawn(function()
        local addedCount = 0
        
        for i, crate in ipairs(cratesList) do
            local amountInInv = inventoryCrates[crate.DisplayName] or inventoryCrates[crate.InternalID]
            
            local isAlreadySelected = self.StateManager.selectedCrates[crate.DisplayName] 
                                      or self.StateManager:IsInTrade(crate.DisplayName)
            
            if amountInInv == nil and not isAlreadySelected then
                
                self.StateManager.selectedCrates[crate.DisplayName] = quantity

                self.TradeManager.SendTradeSignal("Add", {
                    Name = crate.DisplayName,
                    Service = "CratesService",
                    Category = "Crates"
                }, quantity, self.StatusLabel, self.StateManager, self.Utils)
                
                addedCount = addedCount + 1
                
                if addedCount % 5 == 0 then
                    self:RefreshInventory()
                end
                
                task.wait(0.05)
            end
        end
        
        if addedCount > 0 then
            self.StateManager:SetStatus("✅ Added " .. addedCount .. " new types!", THEME.Success, self.StatusLabel)
        else
            self.StateManager:SetStatus("✨ Nothing new to add", THEME.TextGray, self.StatusLabel)
        end
        
        if self.FloatingButtons.BtnAddAll1k then
            self.FloatingButtons.BtnAddAll1k.Active = true
            self.FloatingButtons.BtnAddAll1k.Text = "ADD ALL"
        end
        
        self:RefreshInventory()
    end)
end

function DupeTab:RenderPetDupeGrid()
    local THEME = self.Config.THEME
    
    local ALLOWED_PETS = {
        ["Meowrrior"] = true,
        ["Batkin"] = true,
        ["Xmastree"] = true,
        ["Malame"] = true,
        ["Meowl"] = true,
        ["Medus"] = true,
        ["Flame"] = true,
        ["Mega Flame"] = true,
        ["Turbo Flame"] = true,
        ["Ultra Flame"] = true,
        ["I2Pet"] = true
    }
    
    if not self.TooltipRef then
        local tip = Instance.new("TextLabel", self.ScreenGui)
        tip.Name = "GlobalTooltip"
        tip.Size = UDim2.new(0, 250, 0, 30)
        tip.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        tip.TextColor3 = THEME.TextWhite
        tip.TextSize = 11
        tip.Font = Enum.Font.Code
        tip.ZIndex = 300
        tip.Visible = false
        
        self.UIFactory.AddStroke(tip, THEME.AccentBlue, 1, 0.5)
        self.UIFactory.AddCorner(tip, 6)
        self.TooltipRef = tip
        
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and self.TooltipRef.Visible then
                self.TooltipRef.Position = UDim2.new(0, input.Position.X + 15, 0, input.Position.Y + 15)
            end
        end)
    end
    
    self.Container.ScrollBarThickness = 4
    self.Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.Container.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    if self.Container:FindFirstChild("UIListLayout") then
        self.Container.UIListLayout:Destroy()
    end
    
    local padding = self.Container:FindFirstChild("UIPadding") or Instance.new("UIPadding", self.Container)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 12)
    
    local layout = self.Container:FindFirstChild("UIGridLayout") or Instance.new("UIGridLayout", self.Container)
    layout.CellSize = UDim2.new(0, 92, 0, 110)
    layout.CellPadding = UDim2.new(0, 6, 0, 6)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local replica = ReplicaListener:GetReplica()
    local MyPetsData = replica and replica.Data.PetsService and replica.Data.PetsService.Pets
    local rawEquipped = replica and replica.Data.PetsService and replica.Data.PetsService.EquippedPets or {}
    local EquippedUUIDs = {}
    for _, uuid in pairs(rawEquipped) do EquippedUUIDs[uuid] = true end
    
    if not MyPetsData then return end
    
    local sortedPets = {}
    for uuid, data in pairs(MyPetsData) do
        if data.Name and ALLOWED_PETS[data.Name] then
            data.UUID = uuid
            table.insert(sortedPets, data)
        end
    end
    
    table.sort(sortedPets, function(a, b)
        local aEq = EquippedUUIDs[a.UUID] or false
        local bEq = EquippedUUIDs[b.UUID] or false
        if aEq ~= bEq then return aEq end
        local aEvo = a.Evolution or 0
        local bEvo = b.Evolution or 0
        if aEvo ~= bEvo then return aEvo > bEvo end
        return (a.Name or "") < (b.Name or "")
    end)
    
    for _, petData in ipairs(sortedPets) do
        self:CreatePetCard(petData, EquippedUUIDs, replica.Data)
    end
    
    self:UpdateEvoButtonState()
end

function DupeTab:CreatePetCard(petData, EquippedUUIDs, allData)
    local THEME = self.Config.THEME
    
    local uuid = petData.UUID
    local petName = petData.Name or "Unknown"
    local evolution = petData.Evolution or 0
    local isEquipped = EquippedUUIDs[uuid] == true
    local isLocked = isEquipped
    
    local imageId = "rbxassetid://0"
    if PetsInfo[petName] and PetsInfo[petName].Image then
        imageId = "rbxassetid://" .. tostring(PetsInfo[petName].Image)
    end
    
    local Card = Instance.new("Frame", self.Container)
    Card.Name = uuid
    Card.BackgroundColor3 = THEME.CardBg
    Card.BackgroundTransparency = 0.2
    Card.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(Card, 10)
    
    local Stroke = Instance.new("UIStroke", Card)
    Stroke.Thickness = 2
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Enabled = false
    
    local OrderBadge = Instance.new("TextLabel", Card)
    OrderBadge.Name = "OrderBadge"
    OrderBadge.Size = UDim2.new(0, 26, 0, 26)
    OrderBadge.Position = UDim2.new(1, -30, 0, 4)
    OrderBadge.BackgroundColor3 = THEME.AccentBlue
    OrderBadge.TextColor3 = THEME.TextWhite
    OrderBadge.Font = Enum.Font.GothamBold
    OrderBadge.TextSize = 14
    OrderBadge.Visible = false
    OrderBadge.ZIndex = 10
    OrderBadge.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(OrderBadge, 100)
    self.UIFactory.AddStroke(OrderBadge, THEME.TextWhite, 1, 0.5)
    
    local function UpdateState()
        local orderNum = self.StateManager.selectedPets[uuid]
        local isSelected = (orderNum ~= nil)
        
        if isLocked then
            Stroke.Color = THEME.CardStrokeLocked
            Stroke.Enabled = true
            OrderBadge.Visible = false
        elseif isSelected then
            Stroke.Color = THEME.CardStrokeSelected
            Stroke.Enabled = true
            OrderBadge.Text = tostring(orderNum)
            OrderBadge.Visible = true
        else
            Stroke.Enabled = false
            OrderBadge.Visible = false
        end
    end
    UpdateState()
    
    local ClickBtn = Instance.new("TextButton", Card)
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    ClickBtn.ZIndex = 5
    
    ClickBtn.MouseButton1Click:Connect(function()
        if isLocked then return end
        self.StateManager:TogglePetSelection(uuid)
        UpdateState()
        
        for _, otherCard in pairs(self.Container:GetChildren()) do
            if otherCard:IsA("Frame") and otherCard:FindFirstChild("OrderBadge") then
                local otherUUID = otherCard.Name
                local otherOrder = self.StateManager.selectedPets[otherUUID]
                local badge = otherCard.OrderBadge
                local otherStroke = otherCard:FindFirstChild("UIStroke")
                
                if otherOrder then
                    badge.Text = tostring(otherOrder)
                    badge.Visible = true
                    if otherStroke then
                        otherStroke.Enabled = true
                        otherStroke.Color = THEME.CardStrokeSelected
                    end
                else
                    badge.Visible = false
                    if not self.Utils.CheckIsEquipped(otherUUID, nil, "Pets", allData) then
                        if otherStroke then otherStroke.Enabled = false end
                    end
                end
            end
        end
        self:UpdateEvoButtonState()
    end)
    
    if isEquipped then
        local EqTag = Instance.new("TextLabel", Card)
        EqTag.Text = "EQUIP"
        EqTag.Size = UDim2.new(0, 40, 0, 10)
        EqTag.Position = UDim2.new(1, -42, 0, 5)
        EqTag.BackgroundTransparency = 1
        EqTag.TextColor3 = THEME.CardStrokeLocked
        EqTag.Font = Enum.Font.GothamBlack
        EqTag.TextSize = 7
        EqTag.TextXAlignment = Enum.TextXAlignment.Right
        EqTag.ZIndex = 4
    end
    
    if evolution > 0 then
        local StarContainer = Instance.new("Frame", Card)
        StarContainer.Size = UDim2.new(0, 40, 0, 20)
        StarContainer.Position = UDim2.new(0, 4, 0, 4)
        StarContainer.BackgroundTransparency = 1
        StarContainer.ZIndex = 5
        
        local List = Instance.new("UIListLayout", StarContainer)
        List.FillDirection = Enum.FillDirection.Horizontal
        List.Padding = UDim.new(0, -3)
        
        for i = 1, evolution do
            local Star = Instance.new("ImageLabel", StarContainer)
            Star.Size = UDim2.new(0, 14, 0, 14)
            Star.BackgroundTransparency = 1
            Star.Image = "rbxassetid://3926305904"
            Star.ImageRectOffset = Vector2.new(116, 4)
            Star.ImageRectSize = Vector2.new(24, 24)
            Star.ImageColor3 = THEME.StarColor
            Star.ZIndex = 6
        end
    end
    
    local Viewport = Instance.new("ImageLabel", Card)
    Viewport.Size = UDim2.new(0, 68, 0, 68)
    Viewport.Position = UDim2.new(0.5, -34, 0, 18)
    Viewport.BackgroundTransparency = 1
    Viewport.Image = imageId
    Viewport.ScaleType = Enum.ScaleType.Fit
    Viewport.ZIndex = 2
    
    local NameLbl = Instance.new("TextLabel", Card)
    NameLbl.Text = petName
    NameLbl.Size = UDim2.new(1, -4, 0, 20)
    NameLbl.Position = UDim2.new(0, 2, 0, 88)
    NameLbl.BackgroundTransparency = 1
    NameLbl.TextColor3 = THEME.TextWhite
    NameLbl.Font = Enum.Font.GothamBold
    NameLbl.TextSize = 10
    NameLbl.TextWrapped = true
    
    local shortID = uuid:sub(1, 4) .. ".." .. uuid:sub(#uuid - 3, #uuid)
    local UUIDDisplay = Instance.new("TextLabel", Card)
    UUIDDisplay.Text = shortID
    UUIDDisplay.Size = UDim2.new(1, -8, 0, 16)
    UUIDDisplay.Position = UDim2.new(0, 4, 1, -20)
    UUIDDisplay.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    UUIDDisplay.TextColor3 = THEME.TextWhite
    UUIDDisplay.Font = Enum.Font.Code
    UUIDDisplay.TextSize = 9
    UUIDDisplay.ZIndex = 3
    UUIDDisplay.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(UUIDDisplay, 4)
    self.UIFactory.AddStroke(UUIDDisplay, THEME.GlassStroke, 1, 0.6)
    
    local HoverTrigger = Instance.new("TextButton", UUIDDisplay)
    HoverTrigger.Text = ""
    HoverTrigger.BackgroundTransparency = 1
    HoverTrigger.Size = UDim2.new(1, 0, 1, 0)
    HoverTrigger.ZIndex = 10
    
    HoverTrigger.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(uuid)
            local originalText = shortID
            UUIDDisplay.Text = "COPIED!"
            UUIDDisplay.TextColor3 = THEME.Success
            self.StateManager:SetStatus("✅ Copied UUID to clipboard!", THEME.Success, self.StatusLabel)
            task.delay(1, function()
                if UUIDDisplay and UUIDDisplay.Parent then
                    UUIDDisplay.Text = originalText
                    UUIDDisplay.TextColor3 = THEME.TextWhite
                end
            end)
        else
            self.StateManager:SetStatus("⚠️ Executor doesn't support clipboard", THEME.Warning, self.StatusLabel)
        end
    end)
    
    HoverTrigger.MouseEnter:Connect(function()
        if self.TooltipRef then
            self.TooltipRef.Text = " UUID: " .. uuid .. " "
            self.TooltipRef.Visible = true
            if UUIDDisplay:FindFirstChild("UIStroke") then
                UUIDDisplay.UIStroke.Color = THEME.AccentBlue
            end
        end
    end)
    
    HoverTrigger.MouseLeave:Connect(function()
        if self.TooltipRef then
            self.TooltipRef.Visible = false
            if UUIDDisplay:FindFirstChild("UIStroke") then
                UUIDDisplay.UIStroke.Color = THEME.GlassStroke
            end
        end
    end)
end

function DupeTab:OnDeletePets()
    local THEME = self.Config.THEME
    
    if self.Utils.IsTradeActive() then
        self.StateManager:SetStatus("🔒 Close Trade first!", THEME.Fail, self.StatusLabel)
        return
    end
    
    local count = 0
    for _ in pairs(self.StateManager.selectedPets) do count = count + 1 end
    if count == 0 then return end
    
    self:ShowConfirm("Delete " .. count .. " Pets?", function()
        self.TradeManager.DeleteSelectedPets(self.StatusLabel, function()
            task.wait(0.5)
            self.StateManager.selectedPets = {}
            self:RefreshInventory()
        end, self.StateManager, self.Utils)
    end)
end

function DupeTab:OnEvolvePets()
    if self.FloatingButtons.BtnEvoPet and self.FloatingButtons.BtnEvoPet:GetAttribute("IsValid") then
        self.TradeManager.ExecuteEvolution(self.StatusLabel, function()
            task.wait(0.6)
            self:RefreshInventory()
            self:UpdateEvoButtonState()
        end, self.StateManager)
    end
end

function DupeTab:OnDupePets()
    self.TradeManager.ExecutePetDupe(self.StatusLabel, self.StateManager, self.Utils)
end

function DupeTab:UpdateEvoButtonState()
    if not self.FloatingButtons.BtnEvoPet then return end
    
    local THEME = self.Config.THEME
    local replica = ReplicaListener:GetReplica()
    local myPets = replica and replica.Data.PetsService and replica.Data.PetsService.Pets or {}
    
    -- ดึงข้อมูลสัตว์เลี้ยงที่เลือกมาเรียงลำดับตาม Order 1-9
    local selectedList = {}
    for uuid, order in pairs(self.StateManager.selectedPets) do
        if myPets[uuid] then
            table.insert(selectedList, {
                Data = myPets[uuid],
                Order = order
            })
        end
    end
    table.sort(selectedList, function(a, b) return a.Order < b.Order end)
    
    local count = #selectedList
    local btnText = "EVOLVE (" .. count .. ")"
    local isValid = false
    
    -- ====================================================
    -- ตรวจสอบเงื่อนไข
    -- ====================================================
    if count == 0 then
        btnText = "SELECT PETS"
        
    elseif count == 3 then
        -- เงื่อนไขปกติ: 3 ตัว, ชื่อเหมือน, Evo เท่ากัน
        local firstPet = selectedList[1].Data
        local allSameName = true
        local allSameEvo = true
        local notMaxLevel = true
        
        for i = 2, count do
            local p = selectedList[i].Data
            if p.Name ~= firstPet.Name then allSameName = false end
            if (p.Evolution or 0) ~= (firstPet.Evolution or 0) then allSameEvo = false end
        end
        
        if (firstPet.Evolution or 0) >= 2 then notMaxLevel = false end
        
        if not allSameName then btnText = "❌ NAME MISMATCH"
        elseif not allSameEvo then btnText = "❌ EVO MISMATCH"
        elseif not notMaxLevel then btnText = "🚫 MAX LEVEL"
        else
            btnText = "✅ EVOLVE (Normal)"
            isValid = true
        end
        
    elseif count == 9 then
        -- เงื่อนไขพิเศษ: 9 ตัว, ชื่อเหมือน, ต้อง Evo 0 ทั้งหมด
        local firstPet = selectedList[1].Data
        local allSameName = true
        local allEvoZero = true
        
        for i = 1, count do
            local p = selectedList[i].Data
            if p.Name ~= firstPet.Name then allSameName = false end
            if (p.Evolution or 0) ~= 0 then allEvoZero = false end
        end
        
        if not allSameName then
            btnText = "❌ NAME MISMATCH"
        elseif not allEvoZero then
            btnText = "❌ MUST BE EVO 0"
        else
            btnText = "FASTEVO 2"
            isValid = true
        end
        
    else
        -- ถ้าเลือกจำนวนอื่นที่ไม่ใช่ 3 หรือ 9
        btnText = "SELECT 3 OR 9 (" .. count .. ")"
    end
    
    -- ====================================================
    -- อัปเดตหน้าตาปุ่ม
    -- ====================================================
    self.FloatingButtons.BtnEvoPet.Text = btnText
    
    if isValid then
        self.FloatingButtons.BtnEvoPet.BackgroundColor3 = (count == 9) and THEME.BtnDupe or THEME.CardBg 
        self.FloatingButtons.BtnEvoPet.AutoButtonColor = true
        self.FloatingButtons.BtnEvoPet.TextTransparency = 0
        self.FloatingButtons.BtnEvoPet.TextColor3 = THEME.TextWhite
        
        if self.FloatingButtons.BtnEvoPet:FindFirstChild("UIStroke") then
            self.FloatingButtons.BtnEvoPet.UIStroke.Color = (count == 9) and Color3.fromRGB(255, 200, 0) or THEME.AccentBlue
            self.FloatingButtons.BtnEvoPet.UIStroke.Thickness = 1.5
            self.FloatingButtons.BtnEvoPet.UIStroke.Transparency = 0.4
        end
    else
        self.FloatingButtons.BtnEvoPet.BackgroundColor3 = THEME.CardBg
        self.FloatingButtons.BtnEvoPet.AutoButtonColor = false
        self.FloatingButtons.BtnEvoPet.TextTransparency = 0.5
        self.FloatingButtons.BtnEvoPet.TextColor3 = Color3.fromRGB(150, 150, 150)
        
        if self.FloatingButtons.BtnEvoPet:FindFirstChild("UIStroke") then
            self.FloatingButtons.BtnEvoPet.UIStroke.Color = Color3.fromRGB(80, 80, 80)
            self.FloatingButtons.BtnEvoPet.UIStroke.Thickness = 1
            self.FloatingButtons.BtnEvoPet.UIStroke.Transparency = 0.7
        end
    end
    
    self.FloatingButtons.BtnEvoPet:SetAttribute("IsValid", isValid)
end


function DupeTab:ShowQuantityPopup(itemData, onConfirm)
    -- ป้องกันเปิด popup ซ้ำ
    if self.isPopupOpen then return end
    
    -- ปิด popup เก่า (ถ้ามี)
    if self.currentPopup and self.currentPopup.Parent then
        self.currentPopup:Destroy()
        self.currentPopup = nil
    end
    
    local THEME = self.Config.THEME
    
    -- ✅ ตั้ง flag ว่า popup กำลังเปิด
    self.isPopupOpen = true
    
    local PopupFrame = Instance.new("Frame", self.ScreenGui)
    PopupFrame.Size = UDim2.new(1, 0, 1, 0)
    PopupFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    PopupFrame.BackgroundTransparency = 0.3
    PopupFrame.ZIndex = 3000
    PopupFrame.BorderSizePixel = 0
    
    -- ✅ เก็บ reference ของ popup ปัจจุบัน
    self.currentPopup = PopupFrame
    
    local popupBox = Instance.new("Frame", PopupFrame)
    popupBox.Size = UDim2.new(0, 240, 0, 150)
    popupBox.Position = UDim2.new(0.5, -120, 0.5, -75)
    popupBox.BackgroundColor3 = THEME.GlassBg
    popupBox.ZIndex = 3001
    popupBox.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(popupBox, 10)
    self.UIFactory.AddStroke(popupBox, THEME.AccentBlue, 2, 0)
    
    local titleLabel = self.UIFactory.CreateLabel({
        Parent = popupBox,
        Text = "ENTER AMOUNT",
        Size = UDim2.new(1, 0, 0, 38),
        TextColor = THEME.TextWhite,
        Font = Enum.Font.GothamBold,
        TextSize = 13
    })
    titleLabel.ZIndex = 3002
    
    local input = Instance.new("TextBox", popupBox)
    input.Size = UDim2.new(0.85, 0, 0, 34)
    input.Position = UDim2.new(0.075, 0, 0.35, 0)
    input.Text = tostring(itemData.Default or 1)
    input.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    input.TextColor3 = THEME.TextWhite
    input.Font = Enum.Font.Code
    input.TextSize = 15
    input.ClearTextOnFocus = false
    input.ZIndex = 3002
    input.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(input, 6)
    self.UIFactory.AddStroke(input, THEME.GlassStroke, 1, 0.5)
    
    local maxValue = itemData.Max or 999999
    local inputConn = self.Utils.SanitizeNumberInput(input, maxValue)
    
    -- ✅ ฟังก์ชันปิด popup พร้อมล้างค่า flag
    local function ClosePopup()
        if inputConn then inputConn:Disconnect() end
        if PopupFrame and PopupFrame.Parent then
            PopupFrame:Destroy()
        end
        self.isPopupOpen = false
        self.currentPopup = nil
    end
    
    local confirmBtn = self.UIFactory.CreateButton({
        Size = UDim2.new(0.85, 0, 0, 34),
        Position = UDim2.new(0.075, 0, 0.7, 0),
        Text = "CONFIRM",
        BgColor = THEME.AccentBlue,
        CornerRadius = 6,
        Parent = popupBox
    })
    confirmBtn.ZIndex = 3002
    
    local closeBtn = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -30, 0, 4),
        Text = "X",
        BgColor = THEME.Fail,
        CornerRadius = 6,
        Parent = popupBox
    })
    closeBtn.ZIndex = 3002
    
    -- ✅ ใช้ฟังก์ชัน ClosePopup แทน
    closeBtn.MouseButton1Click:Connect(ClosePopup)
    
    confirmBtn.MouseButton1Click:Connect(function()
        local quantity = tonumber(input.Text)
        if quantity and quantity > 0 and quantity <= maxValue then
            ClosePopup()
            onConfirm(quantity)
        end
    end)
end

-- ✅ แก้ไข ShowConfirm - ป้องกัน confirm ซ้อนทับ
function DupeTab:ShowConfirm(text, onYes)
    -- ป้องกันเปิด confirm ซ้ำขณะมี popup อยู่แล้ว
    if self.isPopupOpen then return end
    
    local THEME = self.Config.THEME
    
    -- ✅ ตั้ง flag
    self.isPopupOpen = true
    
    local ConfirmOverlay = Instance.new("Frame", self.ScreenGui)
    ConfirmOverlay.Size = UDim2.new(1, 0, 1, 0)
    ConfirmOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
    ConfirmOverlay.BackgroundTransparency = 0.15
    ConfirmOverlay.ZIndex = 2000
    ConfirmOverlay.BorderSizePixel = 0
    
    -- ✅ เก็บ reference
    self.currentPopup = ConfirmOverlay
    
    local box = Instance.new("Frame", ConfirmOverlay)
    box.Size = UDim2.new(0, 310, 0, 155)
    box.Position = UDim2.new(0.5, -155, 0.5, -77.5)
    box.BackgroundColor3 = THEME.GlassBg
    box.ZIndex = 2001
    box.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(box, 10)
    self.UIFactory.AddStroke(box, THEME.Fail, 2, 0)
    
    local titleLabel = self.UIFactory.CreateLabel({
        Parent = box,
        Text = text,
        Size = UDim2.new(1, 0, 0, 48),
        Position = UDim2.new(0, 0, 0, 8),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor = THEME.Fail
    })
    titleLabel.ZIndex = 2002
    
    local subLabel = self.UIFactory.CreateLabel({
        Parent = box,
        Text = "Are you sure? This cannot be undone!",
        Size = UDim2.new(1, -16, 0, 36),
        Position = UDim2.new(0, 8, 0, 50),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor = THEME.TextGray
    })
    subLabel.ZIndex = 2002
    subLabel.TextWrapped = true
    
    local btnContainer = Instance.new("Frame", box)
    btnContainer.Size = UDim2.new(1, 0, 0, 42)
    btnContainer.Position = UDim2.new(0, 0, 1, -50)
    btnContainer.BackgroundTransparency = 1
    btnContainer.ZIndex = 2002
    
    local layout = Instance.new("UIListLayout", btnContainer)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 10)
    
    -- ✅ ฟังก์ชันปิด confirm
    local function CloseConfirm()
        if ConfirmOverlay and ConfirmOverlay.Parent then
            ConfirmOverlay:Destroy()
        end
        self.isPopupOpen = false
        self.currentPopup = nil
    end
    
    local cancelBtn = self.UIFactory.CreateButton({
        Text = "CANCEL",
        Size = UDim2.new(0, 100, 0, 34),
        BgColor = THEME.BtnDefault,
        Parent = btnContainer,
        OnClick = CloseConfirm
    })
    cancelBtn.ZIndex = 2003
    
    local yesBtn = self.UIFactory.CreateButton({
        Text = "YES, DELETE",
        Size = UDim2.new(0, 120, 0, 34),
        BgColor = THEME.Fail,
        Parent = btnContainer,
        OnClick = function()
            CloseConfirm()
            onYes()
        end
    })
    yesBtn.ZIndex = 2003
end

return DupeTab
