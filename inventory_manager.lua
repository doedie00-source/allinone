-- inventory_manager.lua
-- Inventory Manager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local InventoryManager = {}

function InventoryManager.GetPlayerData()
    local ReplicaListener = Knit.GetController("ReplicaListener")
    local replica = ReplicaListener:GetReplica()
    if not replica then return nil end
    return replica.Data
end

function InventoryManager.HasItem(service, tier, playerData)
    if not playerData or not playerData.ItemsService then return false end
    local itemsInventory = playerData.ItemsService.Inventory
    if not itemsInventory then return false end
    local serviceData = itemsInventory[service]
    if not serviceData then return false end
    local amount = serviceData[tostring(tier)] or serviceData[tonumber(tier)] or 0
    return amount > 0
end

return InventoryManager
