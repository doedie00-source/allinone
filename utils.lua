-- utils.lua
-- Utility Functions

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Utils = {}

function Utils.IsTradeActive()
    local Windows = LocalPlayer.PlayerGui:FindFirstChild("Windows")
    if not Windows then return false end
    local activeWindows = {"TradingFrame", "AreYouSure", "AreYouSureSecret", "AmountSelector"}
    for _, winName in ipairs(activeWindows) do
        local frame = Windows:FindFirstChild(winName)
        if frame and frame.Visible then return true end
    end
    return false
end

function Utils.CheckIsEquipped(guid, name, category, allData)
    if category == "Secrets" then
        return (allData.MonsterService.EquippedMonster == name)
    end
    if not guid then return false end
    if category == "Pets" then
        for _, eqGuid in pairs(allData.PetsService.EquippedPets or {}) do
            if eqGuid == guid then return true end
        end
    elseif category == "Accessories" then
        for _, eqGuid in pairs(allData.AccessoryService.EquippedAccessories or {}) do
            if eqGuid == guid then return true end
        end
    end
    return false
end

function Utils.GetItemDetails(info, category)
    if type(info) ~= "table" then return "" end
    local details = ""
    if category == "Pets" then
        local evo = tonumber(info.Evolution)
        if evo and evo > 0 then details = details .. " " .. string.rep("⭐", evo) end
        if info.Level then details = details .. " Lv." .. info.Level end
    elseif category == "Accessories" then
        if info.Scroll and info.Scroll.Name then
            details = details .. " [" .. info.Scroll.Name .. "]"
        end
    end
    if info.Shiny or info.Golden then details = details .. " [✨]" end
    return details
end

function Utils.SanitizeNumberInput(textBox, maxValue, minValue)
    local connection
    connection = textBox:GetPropertyChangedSignal("Text"):Connect(function()
        local txt = textBox.Text
        if txt == "" then return end
        local numStr = txt:gsub("%D", "")
        if numStr == "" then
            textBox.Text = tostring(minValue or 1)
            return
        end
        if txt ~= numStr then
            textBox.Text = numStr
            return
        end
        local n = tonumber(numStr)
        if n then
            if minValue and n < minValue then
                textBox.Text = tostring(minValue)
                return
            end
            if maxValue and n > maxValue then
                textBox.Text = tostring(maxValue)
                return
            end
        end
    end)
    return connection
end

return Utils
