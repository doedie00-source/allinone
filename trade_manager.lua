-- trade_manager.lua
-- Trade Manager (CORE LOGIC - PRESERVED)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)
local TradeController = Knit.GetController("TradeController")
local TradingService = Knit.GetService("TradingService")
local ReplicaListener = Knit.GetController("ReplicaListener")

-- Load Game Info
local SuccessLoadCrates, CratesInfo = pcall(function() 
    return require(ReplicatedStorage.GameInfo.CratesInfo) 
end)
if not SuccessLoadCrates then CratesInfo = {} end

local SuccessLoadPets, PetsInfo = pcall(function() 
    return require(ReplicatedStorage.GameInfo.PetsInfo) 
end)
if not SuccessLoadPets then PetsInfo = {} end

local TradeManager = {}
TradeManager.IsProcessing = false 
TradeManager.CratesInfo = CratesInfo
TradeManager.PetsInfo = PetsInfo

function TradeManager.ForceTradeWith(targetPlayer, statusLabel, StateManager, Utils)
    if not targetPlayer then return end
    if TradeManager.IsProcessing or Utils.IsTradeActive() then return end
    
    TradeManager.IsProcessing = true
    
    -- ใช้ค่าจาก StateManager's Config
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        PlayerBtn = Color3.fromRGB(255, 170, 0),
        Success = Color3.fromRGB(85, 255, 127),
        ItemEquip = Color3.fromRGB(255, 80, 80)
    }
    
    StateManager:SetStatus("🚀 Requesting trade...", THEME.PlayerBtn, statusLabel)
    
    TradingService:InitializeNewTrade(targetPlayer.UserId):andThen(function(result)
        TradeManager.IsProcessing = false
        
        if result then
            pcall(function() 
                TradeController:OnTradeRequestAccepted(targetPlayer.UserId) 
            end)
            
            if debug and debug.setupvalue then
                pcall(function()
                    local func = TradeController.AddToTradeData
                    debug.setupvalue(func, 4, LocalPlayer.UserId)
                end)
            end
            
            StateManager:SetStatus("✅ Request sent!", THEME.Success, statusLabel)
        else
            StateManager:SetStatus("❌ Failed (Cooldown/Busy).", THEME.ItemEquip, statusLabel)
        end
    end)
end

function TradeManager.SendTradeSignal(action, itemData, amount, statusLabel, StateManager, Utils, callbacks)
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        ItemEquip = Color3.fromRGB(255, 80, 80),
        ItemInv = Color3.fromRGB(100, 255, 140),
        BtnDupe = Color3.fromRGB(170, 0, 255)
    }
    
    if not Utils.IsTradeActive() then
        StateManager:SetStatus("⚠️ Trade Menu NOT open!", THEME.ItemEquip, statusLabel)
        return
    end
    
    local isDupeMode = (StateManager.currentMainTab == "Dupe")
    
    local success, fakeBtn = pcall(function()
        local btn = Instance.new("ImageButton")
        local uniqueId = itemData.Guid or (itemData.Name .. "_" .. tick())
        btn.Name = "TradeItem_" .. uniqueId
        btn.Visible = false
        btn.Size = UDim2.new(0, 100, 0, 100)
        btn.BackgroundTransparency = 1
        
        btn:SetAttribute("Service", itemData.Service)
        btn:SetAttribute("Index", itemData.Name)
        btn:SetAttribute("Quantity", amount)
        btn:SetAttribute("IsEquipped", false)
        
        -- ✅ FIX: รองรับ Crates
        if itemData.Category == "Crates" then
            btn:SetAttribute("ItemName", itemData.Name)
            btn:SetAttribute("Name", itemData.Name)
            btn:SetAttribute("Amount", amount)
            btn:SetAttribute("Service", "CratesService")
            btn:SetAttribute("IsFakeDupe", true)
        end
        
        -- ✅ FIX: รองรับ Monster ที่ไม่มี UUID (MonstersUnlocked)
        if itemData.Category == "Secrets" then
            if itemData.ElementData then
                btn:SetAttribute("ElementData", itemData.ElementData)
            end
            
            -- ถ้ามี Guid (SavedMonsters) ให้ใส่
            if itemData.Guid then
                btn:SetAttribute("Guid", tostring(itemData.Guid))
            end
        elseif itemData.Guid and itemData.Category ~= "Crates" then
            -- กรณีปกติ (Pets, Accessories)
            btn:SetAttribute("Guid", tostring(itemData.Guid))
        end
        
        -- ใส่ข้อมูลเพิ่มเติม
        if itemData.RawInfo then
            if itemData.RawInfo.Evolution then 
                btn:SetAttribute("Evolution", itemData.RawInfo.Evolution) 
            end
            if itemData.RawInfo.Shiny then 
                btn:SetAttribute("Shiny", true) 
            end
            if itemData.RawInfo.Golden then 
                btn:SetAttribute("Golden", true) 
            end
        end
        
        game:GetService("CollectionService"):AddTag(btn, "Tradeable")
        btn.Parent = LocalPlayer:WaitForChild("PlayerGui")
        return btn
    end)
    
    if not success or not fakeBtn then
        StateManager:SetStatus("❌ Failed to create signal!", THEME.ItemEquip, statusLabel)
        return
    end
    
    pcall(function()
        local key = itemData.Guid or itemData.Name
        
        if action == "Add" then
            TradeController:AddToTradeData(fakeBtn, amount)
            
            -- ✅ เพิ่มบรรทัดนี้: เก็บ Amount เข้าไปใน itemData
            itemData.Amount = amount
            
            StateManager:AddToTrade(key, itemData)
            
            local modePrefix = isDupeMode and "✨ Dupe: " or "✅ Added: "
            StateManager:SetStatus(modePrefix .. itemData.Name, THEME.ItemInv, statusLabel)
            
        elseif action == "Remove" then
            TradeController:RemoveFromTradeData(fakeBtn, amount)
            StateManager:RemoveFromTrade(key)
            StateManager:SetStatus("🗑️ Removed: " .. itemData.Name, THEME.ItemEquip, statusLabel)
        end
    end)
    
    task.delay(0.5, function() 
        if fakeBtn and fakeBtn.Parent then 
            fakeBtn:Destroy() 
        end 
    end)
    
    if callbacks then
        if callbacks.RefreshInventory then 
            callbacks.RefreshInventory() 
        end
    end
end

function TradeManager.GetGameTradeId()
    local success, tradeId = pcall(function()
        if debug and debug.getupvalues then
            local upvalues = debug.getupvalues(TradeController.AddToTradeData)
            for i, v in pairs(upvalues) do
                if type(v) == "number" and v > 1000 then 
                    return v 
                end
            end
        end
    end)
    return (success and tradeId) or nil
end

function TradeManager.ExecuteMagicDupe(recipe, statusLabel, amount, StateManager, Utils, InventoryManager)
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        Fail = Color3.fromRGB(255, 85, 85),
        PlayerBtn = Color3.fromRGB(255, 170, 0),
        BtnDupe = Color3.fromRGB(170, 0, 255),
        Success = Color3.fromRGB(85, 255, 127)
    }
    
    if TradeManager.IsProcessing or not Utils.IsTradeActive() then
        if not Utils.IsTradeActive() then
            StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, statusLabel)
        end
        return
    end
    
    local replica = ReplicaListener:GetReplica()
    local playerData = replica and replica.Data
    if not playerData or not playerData.ItemsService then
        StateManager:SetStatus("❌ Data Error!", THEME.Fail, statusLabel)
        return
    end
    
    local targetTier = tonumber(recipe.Tier)
    local serviceName = recipe.Service
    local itemsInv = playerData.ItemsService.Inventory
    local serviceData = itemsInv and itemsInv[serviceName]
    
    if serviceData then
        local ownedAmt = serviceData[tostring(targetTier)] or serviceData[targetTier] or 0
        if ownedAmt > 0 then
            StateManager:SetStatus("❌ Owned: You already have this!", THEME.Fail, statusLabel)
            return
        end
    end
    
    local realTradeId = TradeManager.GetGameTradeId()
    if not realTradeId then
        local targetIds = {LocalPlayer.UserId}
        pcall(function()
            local TradingFrame = LocalPlayer.PlayerGui.Windows:FindFirstChild("TradingFrame")
            if TradingFrame then
                for _, v in pairs(TradingFrame:GetDescendants()) do
                    if v:IsA("TextLabel") and v.Visible and #v.Text > 2 then
                        for _, p in pairs(game.Players:GetPlayers()) do
                            if p ~= LocalPlayer and (v.Text:find(p.Name) or v.Text:find(p.DisplayName)) then
                                table.insert(targetIds, p.UserId)
                                break
                            end
                        end
                    end
                end
            end
        end)
        realTradeId = targetIds
    end
    
    local tradingService = ReplicatedStorage.Packages.Knit.Services.TradingService
    local remote = tradingService.RF:FindFirstChild("UpdateTradeOffer")
    
    local function sendUpdate(payload)
        local data = {
            MonsterService = {}, 
            CratesService = {}, 
            Currencies = {},
            PetsService = {}, 
            AccessoryService = {},
            ItemsService = { [serviceName] = payload }
        }
        
        if type(realTradeId) == "table" then
            for _, id in pairs(realTradeId) do
                task.spawn(function() 
                    pcall(function() 
                        remote:InvokeServer(id, data) 
                    end) 
                end)
            end
        else
            pcall(function() 
                remote:InvokeServer(realTradeId, data) 
            end)
        end
    end
    
    TradeManager.IsProcessing = true
    local WAIT_TIME = 1.3
    
    task.spawn(function()
        if recipe.Name == "White Strawberry" then
            StateManager:SetStatus("⏳ Step 1: Baiting (T2 x2)...", THEME.PlayerBtn, statusLabel)
            sendUpdate({ [2] = 2 })
            task.wait(WAIT_TIME)
            StateManager:SetStatus("🧪 Step 2: Injecting (T1 x" .. amount .. ")...", THEME.BtnDupe, statusLabel)
            sendUpdate({ amount, 1 })
        elseif string.find(string.lower(recipe.Service), "potion") or string.find(string.lower(recipe.Name), "potion") then
            -- ✅ แก้ไข: ส่งทีเดียวจบแบบ Array ตามที่ต้องการ
            sendUpdate({1, 1, amount})
            StateManager:SetStatus("✅ Potion Dupe Sent!", THEME.Success, statusLabel)
            TradeManager.IsProcessing = false
            return -- จบการทำงานตรงนี้เลย ไม่ไหลไปหา else
        else
            local availableBaits = {}
            if serviceData then
                for _, reqTier in ipairs(recipe.RequiredTiers) do
                    local tNum = tonumber(reqTier)
                    if tNum > 2 and tNum ~= targetTier then
                        local amt = serviceData[tostring(tNum)] or serviceData[tNum] or 0
                        if amt > 0 then 
                            table.insert(availableBaits, tNum) 
                        end
                    end
                end
            end
            table.sort(availableBaits, function(a, b) return a > b end)
            
            if #availableBaits < 2 then
                StateManager:SetStatus("❌ Need 2 Baits (T3+)", THEME.Fail, statusLabel)
                TradeManager.IsProcessing = false
                return
            end
            
            local t1, t2 = availableBaits[1], availableBaits[2]
            StateManager:SetStatus("⏳ 1/4: Place T" .. t1, THEME.PlayerBtn, statusLabel)
            sendUpdate({ [t1] = 1 })
            task.wait(WAIT_TIME)
            StateManager:SetStatus("⏳ 2/4: Add T" .. t2, THEME.PlayerBtn, statusLabel)
            sendUpdate({ [t1] = 1, [t2] = 1 })
            task.wait(WAIT_TIME)
            StateManager:SetStatus("✨ 3/4: SWAP to Target", THEME.BtnDupe, statusLabel)
            sendUpdate({ [targetTier] = amount, [t2] = 1 })
            task.wait(WAIT_TIME + 0.2)
            StateManager:SetStatus("🔥 4/4: Finishing...", THEME.Success, statusLabel)
            sendUpdate({ [targetTier] = amount })
        end
        
        StateManager:SetStatus("✅ Execution Complete!", THEME.Success, statusLabel)
        TradeManager.IsProcessing = false
    end)
end

function TradeManager.ExecutePetDupe(statusLabel, StateManager, Utils)
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        Fail = Color3.fromRGB(255, 85, 85),
        BtnDupe = Color3.fromRGB(170, 0, 255),
        Success = Color3.fromRGB(85, 255, 127)
    }
    
    if TradeManager.IsProcessing then return end
    if not Utils.IsTradeActive() then
        StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, statusLabel)
        return
    end
    
    local replica = ReplicaListener:GetReplica()
    local myPets = replica.Data.PetsService.Pets
    
    local selectedUUIDs = {}
    local hasEvo2 = false
    
    for uuid, selected in pairs(StateManager.selectedPets) do
        if selected then
            local petData = myPets[uuid]
            if petData and (petData.Evolution or 0) >= 2 then
                hasEvo2 = true
                break
            end
            table.insert(selectedUUIDs, uuid)
        end
    end
    
    if hasEvo2 then
        StateManager:SetStatus("❌ Cannot Dupe Evo 2 pets! (Unselect them)", THEME.Fail, statusLabel)
        return
    end
    
    if #selectedUUIDs == 0 then
        StateManager:SetStatus("⚠️ Select pets (Evo 0-1) to dupe!", THEME.Fail, statusLabel)
        return
    end
    
    if not replica or not replica.Data then
        StateManager:SetStatus("❌ Data Error!", THEME.Fail, statusLabel)
        return
    end
    
    local playerData = replica.Data
    local availableBaitCrates = {}
    
    for internalId, info in pairs(CratesInfo) do
        if type(info) == "table" then
            local displayName = info.Name or internalId
            local hasNameKey = (playerData.CratesService.Crates[displayName] ~= nil)
            local hasIdKey = (playerData.CratesService.Crates[internalId] ~= nil)
            
            if not hasNameKey and not hasIdKey and displayName ~= "KeKa Crate" then
                table.insert(availableBaitCrates, displayName)
            end
        end
    end
    
    if #availableBaitCrates == 0 then
        StateManager:SetStatus("❌ No 'Pure Nil' crates found!", THEME.Fail, statusLabel)
        TradeManager.IsProcessing = false
        return
    end
    
    local baitCrateName = availableBaitCrates[math.random(1, #availableBaitCrates)]
    
    local petPayload = {}
    for _, uuid in ipairs(selectedUUIDs) do
        local petData = myPets[uuid]
        if petData then
            petPayload[uuid] = {
                Name = petData.Name,
                Evolution = 2
            }
        end
    end
    
    local realTradeId = TradeManager.GetGameTradeId()
    if not realTradeId then
        for _, p in pairs(game.Players:GetPlayers()) do
            if p ~= LocalPlayer then
                realTradeId = p.UserId
                break
            end
        end
    end
    
    if not realTradeId then
        StateManager:SetStatus("❌ Trade ID not found!", THEME.Fail, statusLabel)
        return
    end
    
    TradeManager.IsProcessing = true
    StateManager:SetStatus("✨ Executing Pet Dupe...", THEME.BtnDupe, statusLabel)
    
    local remote = ReplicatedStorage.Packages.Knit.Services.TradingService.RF:FindFirstChild("UpdateTradeOffer")
    
    task.spawn(function()
        local data = {
            MonsterService = {},
            CratesService = {
                [baitCrateName] = 10
            },
            Currencies = {},
            PetsService = petPayload,
            ItemsService = {},
            AccessoryService = {}
        }
        
        local success, err = pcall(function()
            return remote:InvokeServer(realTradeId, data)
        end)
        
        if success then
            StateManager:SetStatus("✅ Dupe Success (Evo 2 Applied)!", THEME.Success, statusLabel)
        else
            StateManager:SetStatus("❌ Dupe Failed: Server Error", THEME.Fail, statusLabel)
        end
        
        task.wait(1)
        TradeManager.IsProcessing = false
    end)
end

function TradeManager.DeleteSelectedPets(statusLabel, callback, StateManager, Utils)
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        Fail = Color3.fromRGB(255, 85, 85),
        Success = Color3.fromRGB(85, 255, 127)
    }
    
    if Utils.IsTradeActive() then
        StateManager:SetStatus("⚠️ Close trade menu before deleting!", THEME.Fail, statusLabel)
        return
    end
    
    local selectedUUIDs = {}
    for uuid, selected in pairs(StateManager.selectedPets) do
        if selected then 
            table.insert(selectedUUIDs, uuid) 
        end
    end
    
    if #selectedUUIDs == 0 then return end
    
    StateManager:SetStatus("🗑️ Deleting pets...", THEME.Fail, statusLabel)
    
    local success, err = pcall(function()
        local Remote = ReplicatedStorage.Packages.Knit.Services.PetsService.RF.Delete
        return Remote:InvokeServer(selectedUUIDs)
    end)
    
    if success then
        StateManager.selectedPets = {}
        StateManager:SetStatus("✅ Deleted successfully!", THEME.Success, statusLabel)
        if callback then callback() end
    else
        StateManager:SetStatus("❌ Delete failed: " .. tostring(err), THEME.Fail, statusLabel)
    end
end

function TradeManager.ExecuteEvolution(statusLabel, callback, StateManager)
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        BtnSelected = Color3.fromRGB(0, 140, 255),
        Success = Color3.fromRGB(85, 255, 127),
        Fail = Color3.fromRGB(255, 85, 85),
        Warning = Color3.fromRGB(255, 200, 0)
    }
    
    -- 1. เตรียมข้อมูล UUID ตามลำดับการเลือก (1-9)
    local selectedItems = {}
    for uuid, order in pairs(StateManager.selectedPets) do
        table.insert(selectedItems, {UUID = uuid, Order = order})
    end
    
    table.sort(selectedItems, function(a, b) 
        return a.Order < b.Order 
    end)
    
    local sortedUUIDs = {}
    for _, item in ipairs(selectedItems) do
        table.insert(sortedUUIDs, item.UUID)
    end
    
    local count = #sortedUUIDs
    local PetServiceRF = ReplicatedStorage.Packages.Knit.Services.PetsService.RF.Evolve
    
    -- ==========================================
    -- กรณี: เลือก 9 ตัว (สูตรพิเศษ Evo 0 -> Evo 2)
    -- ==========================================
    if count == 9 then
        StateManager:SetStatus("🚀 Starting Fast Evo (9 Pets)...", THEME.BtnSelected, statusLabel)
        
        task.spawn(function()
            -- Step 1: 1, 2, 3 -> ได้ 1 (Evo 1)
            StateManager:SetStatus("⏳ Step 1/4: Evolving Group A...", THEME.BtnSelected, statusLabel)
            local group1 = {sortedUUIDs[1], sortedUUIDs[2], sortedUUIDs[3]}
            PetServiceRF:InvokeServer(group1)
            task.wait(0.8) -- รอ Server ประมวลผล
            
            -- Step 2: 4, 5, 6 -> ได้ 4 (Evo 1)
            StateManager:SetStatus("⏳ Step 2/4: Evolving Group B...", THEME.BtnSelected, statusLabel)
            local group2 = {sortedUUIDs[4], sortedUUIDs[5], sortedUUIDs[6]}
            PetServiceRF:InvokeServer(group2)
            task.wait(0.8)
            
            -- Step 3: 7, 8, 9 -> ได้ 7 (Evo 1)
            StateManager:SetStatus("⏳ Step 3/4: Evolving Group C...", THEME.BtnSelected, statusLabel)
            local group3 = {sortedUUIDs[7], sortedUUIDs[8], sortedUUIDs[9]}
            PetServiceRF:InvokeServer(group3)
            task.wait(0.8)
            
            -- Step 4: เอาตัวรอด (1, 4, 7) มารวมกัน -> ได้ 1 (Evo 2)
            StateManager:SetStatus("✨ Step 4/4: Final Fusion (Max)...", THEME.Warning, statusLabel)
            local finalGroup = {sortedUUIDs[1], sortedUUIDs[4], sortedUUIDs[7]}
            local success, err = pcall(function()
                return PetServiceRF:InvokeServer(finalGroup)
            end)
            
            if success then
                StateManager:SetStatus("✅ Fast Evo Complete (Evo 2)!", THEME.Success, statusLabel)
                StateManager.selectedPets = {} -- ล้างการเลือก
                if callback then callback() end
            else
                StateManager:SetStatus("❌ Final Step Failed: " .. tostring(err), THEME.Fail, statusLabel)
            end
        end)
        
        return -- จบการทำงานสำหรับเคส 9 ตัว
    end

    -- ==========================================
    -- กรณีปกติ (3 ตัว)
    -- ==========================================
    if count ~= 3 then
        StateManager:SetStatus("❌ Logic Error: Need 3 or 9 pets", THEME.Fail, statusLabel)
        return
    end

    StateManager:SetStatus("🧬 Evolving Pets (Normal)...", THEME.BtnSelected, statusLabel)
    
    local success, err = pcall(function()
        return PetServiceRF:InvokeServer(sortedUUIDs)
    end)
    
    if success then
        StateManager:SetStatus("✅ Evolution Success!", THEME.Success, statusLabel)
        StateManager.selectedPets = {}
        if callback then callback() end
    else
        StateManager:SetStatus("❌ Evo Failed: " .. tostring(err), THEME.Fail, statusLabel)
    end
end

function TradeManager.ActionConfirmTrade(statusLabel, StateManager, Utils)
    -- ปิดการทำงานไว้ก่อน
    do return end 
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        Success = Color3.fromRGB(85, 255, 127),
        Fail = Color3.fromRGB(255, 85, 85),
        Warning = Color3.fromRGB(255, 200, 0)
    }
    
    if TradeManager.IsProcessing then return end
    
    if not Utils.IsTradeActive() then
        StateManager:SetStatus("⚠️ Trade not active!", THEME.Fail, statusLabel)
        return
    end

    local targetId = TradeManager.GetGameTradeId()
    if not targetId then
        StateManager:SetStatus("❌ Target ID not found!", THEME.Fail, statusLabel)
        return
    end

    TradeManager.IsProcessing = true
    
    task.spawn(function()
        local Remote = ReplicatedStorage.Packages.Knit.Services.TradingService.RF:FindFirstChild("ToggleTradeAccept")
        
        if not Remote then
            StateManager:SetStatus("❌ Remote not found!", THEME.Fail, statusLabel)
            TradeManager.IsProcessing = false
            return
        end

        StateManager:SetStatus("🚀 Instant Confirm...", THEME.Warning, statusLabel)

        -- ยิงเปรี้ยงเดียวจบ (true, true)
        local success, err = pcall(function()
            return Remote:InvokeServer(targetId, true, true)
        end)

        if success then
            StateManager:SetStatus("✅ Confirmed!", THEME.Success, statusLabel)
        else
            StateManager:SetStatus("❌ Failed: " .. tostring(err), THEME.Fail, statusLabel)
        end
        
        task.wait(0.5)
        TradeManager.IsProcessing = false
    end)
    -- ... (โค้ดที่เหลือจะถูกข้ามไป)
end

function TradeManager.ActionCancelTrade(statusLabel, StateManager, Utils)
    local THEME = StateManager.Config and StateManager.Config.THEME
    
    if TradeManager.IsProcessing then return end

    if not Utils.IsTradeActive() then
        StateManager:SetStatus("⚠️ Trade not active!", THEME.Fail, statusLabel)
        return
    end

    local targetId = TradeManager.GetGameTradeId()
    -- ถ้าหา ID ไม่เจอ ก็ให้พยายามปิด UI ไปเลย เพื่อกันค้าง
    if not targetId then
        -- StateManager:SetStatus("❌ Target ID not found!", THEME.Fail, statusLabel)
        -- return
    end

    TradeManager.IsProcessing = true
    StateManager:SetStatus("⏳ Cancelling...", THEME.Fail, statusLabel)

    task.spawn(function()
        -- 1. ยิง Remote ไปบอก Server ว่ายกเลิก (Logic เดิม)
        local success, err = pcall(function()
            local Remote = ReplicatedStorage.Packages.Knit.Services.TradingService.RF:FindFirstChild("CancelTrade")
            if Remote and targetId then
                return Remote:InvokeServer(targetId)
            end
            return false
        end)

        -- 2. [เพิ่มใหม่] บังคับปิด UI ของเกม (Native UI) ทันที
        pcall(function()
            -- วิธีที่ 1: สั่งผ่าน WindowController (วิธีที่สะอาดที่สุดตามโค้ดเกม)
            local WindowController = Knit.GetController("WindowController")
            if WindowController then
                WindowController:SetCurrentWindow(nil) -- สั่งให้ไม่มีหน้าต่างใดเปิดอยู่
            end
            
            -- วิธีที่ 2: Force Hide Frame (เผื่อวิธีแรกไม่ได้ผล)
            local TradingFrame = LocalPlayer.PlayerGui.Windows:FindFirstChild("TradingFrame")
            if TradingFrame then
                TradingFrame.Visible = false
            end
            
            -- วิธีที่ 3: สั่ง CleanUp ตัว TradeController (เผื่อเคลียร์ข้อมูลค้าง)
            local TC = Knit.GetController("TradeController")
            if TC and TC.CleanUp then
                TC:CleanUp()
            end
        end)

        if success then
            StateManager:SetStatus("🗑️ Trade Cancelled!", THEME.Success, statusLabel)
            StateManager:ResetTrade() -- ล้างข้อมูล Trade ใน UI ของเรา
        else
            -- ถึง Server จะ Fail แต่เราก็ปิดหน้าต่างไปแล้วเพื่อกันบัค
            StateManager:SetStatus("⚠️ Cancelled (Force Close)", THEME.Warning, statusLabel)
            StateManager:ResetTrade()
        end

        task.wait(0.5)
        TradeManager.IsProcessing = false
    end)
end

return TradeManager
