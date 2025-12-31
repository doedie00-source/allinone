-- ui_factory.lua
local UserInputService = game:GetService("UserInputService")
local UIFactory = {}
UIFactory.Config = nil -- จะถูกตั้งค่าจาก main.lua

function UIFactory.CreateButton(props)
    local Config = UIFactory.Config
    local THEME = Config.THEME
    local CONFIG = Config.CONFIG
    
    local btn = Instance.new("TextButton")
    btn.Size = props.Size or UDim2.new(0, 100, 0, 30)
    btn.Position = props.Position or UDim2.new(0, 0, 0, 0)
    btn.Text = props.Text or ""
    btn.BackgroundColor3 = props.BgColor or THEME.BtnDefault
    btn.BackgroundTransparency = props.BgTransparency or 0
    btn.TextColor3 = props.TextColor or THEME.TextWhite
    btn.Font = props.Font or Enum.Font.Gotham
    btn.TextSize = props.TextSize or 12
    btn.TextXAlignment = props.TextXAlign or Enum.TextXAlignment.Center
    btn.Parent = props.Parent
    
    if props.Corner ~= false then
        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, props.CornerRadius or CONFIG.CORNER_RADIUS)
    end
    if props.OnClick then btn.MouseButton1Click:Connect(props.OnClick) end
    return btn
end

function UIFactory.CreateLabel(props)
    local Config = UIFactory.Config
    local THEME = Config.THEME
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = props.Size or UDim2.new(1, 0, 0, 30)
    lbl.Position = props.Position or UDim2.new(0, 0, 0, 0)
    lbl.Text = props.Text or ""
    lbl.BackgroundTransparency = props.BgTransparency or 1
    lbl.TextColor3 = props.TextColor or THEME.TextWhite
    lbl.Font = props.Font or Enum.Font.Gotham
    lbl.TextSize = props.TextSize or 12
    lbl.TextXAlignment = props.TextXAlign or Enum.TextXAlignment.Center
    lbl.Parent = props.Parent
    return lbl
end

function UIFactory.CreateFrame(props)
    local Config = UIFactory.Config
    local THEME = Config.THEME
    local CONFIG = Config.CONFIG
    
    local frame = Instance.new("Frame")
    frame.Size = props.Size or UDim2.new(1, 0, 1, 0)
    frame.Position = props.Position or UDim2.new(0, 0, 0, 0)
    frame.BackgroundColor3 = props.BgColor or THEME.PanelBg
    frame.BackgroundTransparency = props.BgTransparency or THEME.PanelTransparency
    frame.Parent = props.Parent
    if props.Corner ~= false then
        local corner = Instance.new("UICorner", frame)
        corner.CornerRadius = UDim.new(0, props.CornerRadius or CONFIG.CORNER_RADIUS)
    end
    if props.Stroke then
        local stroke = Instance.new("UIStroke", frame)
        stroke.Color = props.StrokeColor or Color3.fromRGB(60, 60, 70)
        stroke.Thickness = props.StrokeThickness or 1.5
        stroke.Transparency = props.StrokeTransparency or 0.4
    end
    return frame
end

function UIFactory.CreateScrollingFrame(props)
    local Config = UIFactory.Config
    local CONFIG = Config.CONFIG
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = props.Size or UDim2.new(1, -10, 1, -35)
    scroll.Position = props.Position or UDim2.new(0, 5, 0, 30)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = props.ScrollBarThickness or 3
    scroll.Parent = props.Parent
    
    if props.UseGrid then
        local layout = Instance.new("UIGridLayout", scroll)
        layout.CellPadding = UDim2.new(0, 5, 0, 5)
        layout.CellSize = UDim2.new(0, 90, 0, 110)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    else
        local layout = Instance.new("UIListLayout", scroll)
        layout.Padding = UDim.new(0, props.Padding or CONFIG.LIST_PADDING)
        layout.HorizontalAlignment = props.HAlign or Enum.HorizontalAlignment.Center
    end
    
    return scroll
end

function UIFactory.AddCorner(instance, radius)
    local Config = UIFactory.Config
    local CONFIG = Config.CONFIG
    local corner = Instance.new("UICorner", instance)
    corner.CornerRadius = UDim.new(0, radius or CONFIG.CORNER_RADIUS)
    return corner
end

function UIFactory.AddStroke(instance, color, thickness, transparency)
    local stroke = Instance.new("UIStroke", instance)
    stroke.Color = color or Color3.fromRGB(60, 60, 70)
    stroke.Thickness = thickness or 1.5
    stroke.Transparency = transparency or 0.4
    return stroke
end

function UIFactory.MakeDraggable(topBar, object)
    local dragging, dragInput, dragStart, startPosition
    local function update(input)
        local delta = input.Position - dragStart
        object.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = object.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)
end

return UIFactory
