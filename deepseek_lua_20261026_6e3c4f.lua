--[[
    ═══════════════════════════════════════════════════════════════
    ██╗   ██╗ ██████╗ ██╗   ██╗██████╗ ███████╗
    ██║   ██║██╔═══██╗██║   ██║██╔══██╗██╔════╝
    ██║   ██║██║   ██║██║   ██║██████╔╝█████╗  
    ╚██╗ ██╔╝██║   ██║██║   ██║██╔══██╗██╔══╝  
     ╚████╔╝ ╚██████╔╝╚██████╔╝██║  ██║███████╗
      ╚═══╝   ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝
    ═══════════════════════════════════════════════════════════════
    EXCLUSIVE UI MENU - Full Features
    Discord | Auto Farm | ESP | Combat | Teleport | Utility
    ═══════════════════════════════════════════════════════════════
]]

--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local ContextActionService = game:GetService("ContextActionService")

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

--// CONFIG & STATE
local Config = {
    -- Movement
    WalkSpeed = 16,
    JumpPower = 50,
    FlySpeed = 100,
    -- Combat
    AimbotEnabled = false,
    AimbotSmoothness = 0.15,
    AimbotFOV = 150,
    AimbotPart = "Head",
    -- Visual
    ESPEnabled = false,
    ESPBox = true,
    ESPName = true,
    ESPHealth = true,
    ESPDistance = true,
    ESPTracer = false,
    ESPTeamCheck = true,
    FullBright = false,
    -- Farm
    AutoFarm = false,
    AutoClick = false,
    -- Teleport
    SavedPositions = {},
    -- Misc
    AntiAFK = true,
    FPSBoost = false,
    Noclip = false,
    InfiniteJump = false,
}

local Toggles = {} -- internal state refs
local Connections = {}
local ESPCache = {}

--// NOTIFICATION SYSTEM
local function Notify(title, text, duration)
    duration = duration or 3
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "System"),
            Text = tostring(text or ""),
            Duration = duration,
            Icon = "rbxassetid://7072725342"
        })
    end)
end

--// CLEANUP OLD
if CoreGui:FindFirstChild("VourdsHub") then
    CoreGui.VourdsHub:Destroy()
end

--// MAIN GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VourdsHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = CoreGui

--// THEME
local Theme = {
    Background     = Color3.fromRGB(15, 15, 20),
    Secondary      = Color3.fromRGB(22, 22, 30),
    Tertiary       = Color3.fromRGB(30, 30, 42),
    Accent         = Color3.fromRGB(138, 43, 226),
    AccentHover    = Color3.fromRGB(158, 63, 246),
    Success        = Color3.fromRGB(0, 200, 100),
    Danger         = Color3.fromRGB(220, 60, 60),
    Warning        = Color3.fromRGB(240, 180, 40),
    Text           = Color3.fromRGB(240, 240, 250),
    TextDim        = Color3.fromRGB(150, 150, 170),
    Stroke         = Color3.fromRGB(45, 45, 60),
}

local Fonts = {
    Bold = Enum.Font.GothamBold,
    Medium = Enum.Font.GothamMedium,
    Regular = Enum.Font.Gotham,
}

--// UTILITY FUNCTIONS
local function Create(className, props)
    local obj = Instance.new(className)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            obj[k] = v
        end
    end
    if props.Parent then obj.Parent = props.Parent end
    return obj
end

local function Corner(parent, radius)
    return Create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function Stroke(parent, color, thickness)
    return Create("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end

local function Padding(parent, amount)
    return Create("UIPadding", {
        PaddingTop = UDim.new(0, amount),
        PaddingBottom = UDim.new(0, amount),
        PaddingLeft = UDim.new(0, amount),
        PaddingRight = UDim.new(0, amount),
        Parent = parent
    })
end

local function Tween(obj, time, props, style)
    local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

--// DRAG LOGIC
local function MakeDraggable(frame, dragPart)
    dragPart = dragPart or frame
    local dragging, dragInput, dragStart, startPos

    dragPart.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragPart.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

--// OPEN/CLOSE BUTTON (Floating)
local ToggleBtn = Create("TextButton", {
    Name = "ToggleButton",
    Parent = ScreenGui,
    Size = UDim2.new(0, 56, 0, 56),
    Position = UDim2.new(0, 20, 0.5, -28),
    BackgroundColor3 = Theme.Accent,
    Text = "V",
    TextColor3 = Color3.new(1,1,1),
    Font = Fonts.Bold,
    TextSize = 24,
    AutoButtonColor = false,
    BorderSizePixel = 0,
})
Corner(ToggleBtn, 28)
Stroke(ToggleBtn, Theme.AccentHover, 2)
local btnShadow = Create("ImageLabel", {
    Parent = ToggleBtn,
    Size = UDim2.new(1, 8, 1, 8),
    Position = UDim2.new(0, -4, 0, -4),
    BackgroundTransparency = 1,
    Image = "rbxassetid://5028857472",
    ImageColor3 = Theme.Accent,
    ImageTransparency = 0.5,
    ZIndex = 0,
})

ToggleBtn.MouseEnter:Connect(function()
    Tween(ToggleBtn, 0.2, { Size = UDim2.new(0, 64, 0, 64), Position = UDim2.new(0, 16, 0.5, -32) })
end)
ToggleBtn.MouseLeave:Connect(function()
    Tween(ToggleBtn, 0.2, { Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, 20, 0.5, -28) })
end)

--// MAIN WINDOW
local Main = Create("Frame", {
    Name = "Main",
    Parent = ScreenGui,
    Size = UDim2.new(0, 620, 0, 420),
    Position = UDim2.new(0.5, -310, 0.5, -210),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    Visible = false,
    ClipsDescendants = true,
})
Corner(Main, 12)
Stroke(Main, Theme.Accent, 1.5)
local mainShadow = Create("ImageLabel", {
    Parent = Main,
    Size = UDim2.new(1, 40, 1, 40),
    Position = UDim2.new(0, -20, 0, -20),
    BackgroundTransparency = 1,
    Image = "rbxassetid://5028857472",
    ImageColor3 = Color3.new(0,0,0),
    ImageTransparency = 0.4,
    ZIndex = -1,
})

-- Top Bar
local TopBar = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = Theme.Secondary,
    BorderSizePixel = 0,
})
Corner(TopBar, 12)
Create("Frame", {
    Parent = TopBar,
    Size = UDim2.new(1, 0, 0.5, 0),
    Position = UDim2.new(0, 0, 0.5, 0),
    BackgroundColor3 = Theme.Secondary,
    BorderSizePixel = 0,
})

local Logo = Create("TextLabel", {
    Parent = TopBar,
    Size = UDim2.new(0, 200, 1, 0),
    Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    Text = "⚡ VOURDS HUB",
    TextColor3 = Theme.Accent,
    Font = Fonts.Bold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local Version = Create("TextLabel", {
    Parent = TopBar,
    Size = UDim2.new(0, 100, 1, 0),
    Position = UDim2.new(0, 140, 0, 0),
    BackgroundTransparency = 1,
    Text = "v1.0",
    TextColor3 = Theme.TextDim,
    Font = Fonts.Medium,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local MinimizeBtn = Create("TextButton", {
    Parent = TopBar,
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -70, 0.5, -15),
    BackgroundColor3 = Theme.Tertiary,
    Text = "—",
    TextColor3 = Theme.Text,
    Font = Fonts.Bold,
    TextSize = 14,
    AutoButtonColor = false,
    BorderSizePixel = 0,
})
Corner(MinimizeBtn, 6)
MinimizeBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)

local CloseBtn = Create("TextButton", {
    Parent = TopBar,
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -34, 0.5, -15),
    BackgroundColor3 = Theme.Danger,
    Text = "✕",
    TextColor3 = Color3.new(1,1,1),
    Font = Fonts.Bold,
    TextSize = 13,
    AutoButtonColor = false,
    BorderSizePixel = 0,
})
Corner(CloseBtn, 6)
CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)

-- Sidebar
local Sidebar = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(0, 140, 1, -44),
    Position = UDim2.new(0, 0, 0, 44),
    BackgroundColor3 = Theme.Secondary,
    BorderSizePixel = 0,
})
Create("Frame", {
    Parent = Sidebar,
    Size = UDim2.new(0, 1, 1, 0),
    Position = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = Theme.Stroke,
    BorderSizePixel = 0,
})

-- Content Area
local Content = Create("Frame", {
    Parent = Main,
    Size = UDim2.new(1, -140, 1, -44),
    Position = UDim2.new(0, 140, 0, 44),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
})

--// TAB SYSTEM
local Tabs = {}
local CurrentTab = nil

local function CreateTab(name, icon)
    local Btn = Create("TextButton", {
        Parent = Sidebar,
        Size = UDim2.new(1, -12, 0, 36),
        Position = UDim2.new(0, 6, 0, #Tabs * 42 + 8),
        BackgroundColor3 = Theme.Secondary,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
    })
    Corner(Btn, 6)

    local Icon = Create("TextLabel", {
        Parent = Btn,
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = icon or "●",
        TextColor3 = Theme.TextDim,
        Font = Fonts.Medium,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local Label = Create("TextLabel", {
        Parent = Btn,
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 34, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = Theme.TextDim,
        Font = Fonts.Medium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local Indicator = Create("Frame", {
        Parent = Btn,
        Size = UDim2.new(0, 3, 0.6, 0),
        Position = UDim2.new(0, 0, 0.2, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    })
    Corner(Indicator, 2)
    Indicator.Visible = false

    local Page = Create("ScrollingFrame", {
        Parent = Content,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    })
    Padding(Page, 12)

    local Tab = { Button = Btn, Page = Page, Indicator = Indicator, Icon = Icon, Label = Label, Name = name, Elements = 0 }
    table.insert(Tabs, Tab)

    Btn.MouseEnter:Connect(function()
        if CurrentTab ~= Tab then
            Tween(Btn, 0.15, { BackgroundColor3 = Theme.Tertiary })
        end
    end)
    Btn.MouseLeave:Connect(function()
        if CurrentTab ~= Tab then
            Tween(Btn, 0.15, { BackgroundColor3 = Theme.Secondary })
        end
    end)

    Btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(Tabs) do
            t.Page.Visible = false
            t.Indicator.Visible = false
            Tween(t.Button, 0.15, { BackgroundColor3 = Theme.Secondary })
            Tween(t.Label, 0.15, { TextColor3 = Theme.TextDim })
            Tween(t.Icon, 0.15, { TextColor3 = Theme.TextDim })
        end
        Page.Visible = true
        Indicator.Visible = true
        Tween(Btn, 0.15, { BackgroundColor3 = Theme.Tertiary })
        Tween(Label, 0.15, { TextColor3 = Theme.Text })
        Tween(Icon, 0.15, { TextColor3 = Theme.Accent })
        CurrentTab = Tab
    end)

    return Tab
end

--// ELEMENT BUILDERS
local function AddSection(tab, title)
    tab.Elements = tab.Elements + 1
    local Section = Create("TextLabel", {
        Parent = tab.Page,
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.new(0, 0, 0, (tab.Elements - 1) * 30),
        BackgroundTransparency = 1,
        Text = "  " .. title:upper(),
        TextColor3 = Theme.Accent,
        Font = Fonts.Bold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    return Section
end

local function OffsetY(tab, y)
    return UDim2.new(0, 0, 0, y)
end

local function AddToggle(tab, text, default, callback)
    tab.Elements = tab.Elements + 1
    local yPos = (tab.Elements - 1) * 34

    local Container = Create("Frame", {
        Parent = tab.Page,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, yPos),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
    })
    Corner(Container, 6)
    Stroke(Container, Theme.Stroke, 1)

    local Label = Create("TextLabel", {
        Parent = Container,
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Fonts.Medium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local Switch = Create("Frame", {
        Parent = Container,
        Size = UDim2.new(0, 42, 0, 20),
        Position = UDim2.new(1, -54, 0.5, -10),
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
    })
    Corner(Switch, 10)

    local Knob = Create("Frame", {
        Parent = Switch,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = Theme.TextDim,
        BorderSizePixel = 0,
    })
    Corner(Knob, 8)

    local state = default or false
    local function UpdateState(animate)
        if state then
            Tween(Switch, 0.2, { BackgroundColor3 = Theme.Accent })
            Tween(Knob, 0.2, { Position = UDim2.new(1, -18, 0.5, -8), BackgroundColor3 = Color3.new(1,1,1) })
        else
            Tween(Switch, 0.2, { BackgroundColor3 = Theme.Tertiary })
            Tween(Knob, 0.2, { Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = Theme.TextDim })
        end
    end
    UpdateState(false)

    local ClickArea = Create("TextButton", {
        Parent = Container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    })
    ClickArea.MouseButton1Click:Connect(function()
        state = not state
        UpdateState(true)
        if callback then pcall(callback, state) end
    end)

    Container.MouseEnter:Connect(function() Tween(Container, 0.15, { BackgroundColor3 = Theme.Tertiary }) end)
    Container.MouseLeave:Connect(function() Tween(Container, 0.15, { BackgroundColor3 = Theme.Secondary }) end)

    return { Set = function(v) state = v; UpdateState(true); if callback then pcall(callback, v) end end, Get = function() return state end }
end

local function AddSlider(tab, text, min, max, default, callback)
    tab.Elements = tab.Elements + 1
    local yPos = (tab.Elements - 1) * 54

    local Container = Create("Frame", {
        Parent = tab.Page,
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.new(0, 0, 0, yPos),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
    })
    Corner(Container, 6)
    Stroke(Container, Theme.Stroke, 1)

    local Label = Create("TextLabel", {
        Parent = Container,
        Size = UDim2.new(1, -80, 0, 20),
        Position = UDim2.new(0, 12, 0, 4),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Fonts.Medium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local ValueLabel = Create("TextLabel", {
        Parent = Container,
        Size = UDim2.new(0, 60, 0, 20),
        Position = UDim2.new(1, -72, 0, 4),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = Theme.Accent,
        Font = Fonts.Bold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local BarBg = Create("Frame", {
        Parent = Container,
        Size = UDim2.new(1, -24, 0, 8),
        Position = UDim2.new(0, 12, 0, 30),
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
    })
    Corner(BarBg, 4)

    local BarFill = Create("Frame", {
        Parent = BarBg,
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    })
    Corner(BarFill, 4)

    local Knob = Create("Frame", {
        Parent = BarBg,
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7),
        BackgroundColor3 = Color3.new(1,1,1),
        BorderSizePixel = 0,
    })
    Corner(Knob, 7)
    Stroke(Knob, Theme.Accent, 2)

    local value = default
    local dragging = false

    local function SetValueFromX(x)
        local rel = math.clamp((x - BarBg.AbsolutePosition.X) / BarBg.AbsoluteSize.X, 0, 1)
        value = math.floor((min + (max - min) * rel) * 100 + 0.5) / 100
        BarFill.Size = UDim2.new(rel, 0, 1, 0)
        Knob.Position = UDim2.new(rel, -7, 0.5, -7)
        ValueLabel.Text = tostring(value)
        if callback then pcall(callback, value) end
    end

    local ClickArea = Create("TextButton", {
        Parent = BarBg,
        Size = UDim2.new(1, 0, 3, 0),
        Position = UDim2.new(0, 0, -1, 0),
        BackgroundTransparency = 1,
        Text = "",
    })

    ClickArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            SetValueFromX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            SetValueFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return { Set = function(v) value = v; SetValueFromX(BarBg.AbsolutePosition.X + BarBg.AbsoluteSize.X * ((v - min)/(max - min))) end, Get = function() return value end }
end

local function AddButton(tab, text, callback)
    tab.Elements = tab.Elements + 1
    local yPos = (tab.Elements - 1) * 34

    local Btn = Create("TextButton", {
        Parent = tab.Page,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, yPos),
        BackgroundColor3 = Theme.Tertiary,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Fonts.Medium,
        TextSize = 12,
        AutoButtonColor = false,
        BorderSizePixel = 0,
    })
    Corner(Btn, 6)
    Stroke(Btn, Theme.Accent, 1)

    Btn.MouseEnter:Connect(function() Tween(Btn, 0.15, { BackgroundColor3 = Theme.Accent, TextColor3 = Color3.new(1,1,1) }) end)
    Btn.MouseLeave:Connect(function() Tween(Btn, 0.15, { BackgroundColor3 = Theme.Tertiary, TextColor3 = Theme.Text }) end)
    Btn.MouseButton1Click:Connect(function()
        if callback then pcall(callback) end
    end)

    return Btn
end

local function AddTextbox(tab, placeholder, default, callback)
    tab.Elements = tab.Elements + 1
    local yPos = (tab.Elements - 1) * 34

    local Container = Create("Frame", {
        Parent = tab.Page,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, yPos),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
    })
    Corner(Container, 6)
    Stroke(Container, Theme.Stroke, 1)

    local Box = Create("TextBox", {
        Parent = Container,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = default or "",
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.Text,
        Font = Fonts.Medium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    })

    Box.FocusLost:Connect(function()
        if callback then pcall(callback, Box.Text) end
    end)

    return Box
end

local function AddDropdown(tab, text, options, default, callback)
    tab.Elements = tab.Elements + 1
    local yPos = (tab.Elements - 1) * 34

    local Container = Create("Frame", {
        Parent = tab.Page,
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, yPos),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    Corner(Container, 6)
    Stroke(Container, Theme.Stroke, 1)

    local Label = Create("TextLabel", {
        Parent = Container,
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = text .. ": " .. tostring(default or (options[1] or "")),
        TextColor3 = Theme.Text,
        Font = Fonts.Medium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local Arrow = Create("TextLabel", {
        Parent = Container,
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(1, -30, 0, 0),
        BackgroundTransparency = 1,
        Text = "▼",
        TextColor3 = Theme.Accent,
        Font = Fonts.Bold,
        TextSize = 10,
    })

    local Btn = Create("TextButton", {
        Parent = Container,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "",
    })

    local expanded = false
    local currentValue = default or (options[1] or "")

    local OptionsFrame = Create("Frame", {
        Parent = Container,
        Size = UDim2.new(1, -20, 0, #options * 26),
        Position = UDim2.new(0, 10, 0, 34),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Visible = false,
    })
    Corner(OptionsFrame, 4)

    local optLayout = Create("UIListLayout", { Parent = OptionsFrame, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
    Padding(OptionsFrame, 4)

    for _, opt in ipairs(options) do
        local OptBtn = Create("TextButton", {
            Parent = OptionsFrame,
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Theme.Secondary,
            Text = tostring(opt),
            TextColor3 = Theme.Text,
            Font = Fonts.Medium,
            TextSize = 11,
            AutoButtonColor = false,
            BorderSizePixel = 0,
        })
        Corner(OptBtn, 4)
        OptBtn.MouseEnter:Connect(function() Tween(OptBtn, 0.1, { BackgroundColor3 = Theme.Accent }) end)
        OptBtn.MouseLeave:Connect(function() Tween(OptBtn, 0.1, { BackgroundColor3 = Theme.Secondary }) end)
        OptBtn.MouseButton1Click:Connect(function()
            currentValue = opt
            Label.Text = text .. ": " .. tostring(opt)
            expanded = false
            OptionsFrame.Visible = false
            Tween(Container, 0.2, { Size = UDim2.new(1, 0, 0, 30) })
            Arrow.Text = "▼"
            if callback then pcall(callback, opt) end
        end)
    end

    Btn.MouseButton1Click:Connect(function()
        expanded = not expanded
        if expanded then
            OptionsFrame.Visible = true
            Tween(Container, 0.2, { Size = UDim2.new(1, 0, 0, 30 + #options * 26 + 8) })
            Arrow.Text = "▲"
        else
            OptionsFrame.Visible = false
            Tween(Container, 0.2, { Size = UDim2.new(1, 0, 0, 30) })
            Arrow.Text = "▼"
        end
    end)

    return { Get = function() return currentValue end }
end

local function AddLabel(tab, text, color)
    tab.Elements = tab.Elements + 1
    local yPos = (tab.Elements - 1) * 22
    local Lbl = Create("TextLabel", {
        Parent = tab.Page,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0, yPos),
        BackgroundTransparency = 1,
        Text = "• " .. text,
        TextColor3 = color or Theme.TextDim,
        Font = Fonts.Medium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    return Lbl
end

--// ═══════════════════════════════════════
--// TAB CREATION
--// ═══════════════════════════════════════

local TabHome      = CreateTab("Home", "⌂")
local TabMovement  = CreateTab("Movement", "✦")
local TabCombat    = CreateTab("Combat", "⚔")
local TabVisuals   = CreateTab("Visuals", "◉")
local TabFarm      = CreateTab("Farm", "⚙")
local TabTeleport  = CreateTab("Teleport", "➤")
local TabPlayer    = CreateTab("Player", "☺")
local TabMisc      = CreateTab("Misc", "≡")
local TabSettings  = CreateTab("Settings", "⚙")

-- ═══════════════ HOME TAB ═══════════════
AddSection(TabHome, "Welcome")
local WelcomeLabel = AddLabel(TabHome, "Welcome to Vourds Hub", Theme.Accent)
local WelcomeLabel2 = AddLabel(TabHome, "Exclusive premium menu")
AddSection(TabHome, "Quick Actions")
AddButton(TabHome, "🎮 Rejoin Server", function()
    TeleportService:Teleport(game.PlaceId, LP)
end)
AddButton(TabHome, "🔄 Server Hop", function()
    pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"))
        for _, s in ipairs(servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
                break
            end
        end
    end)
end)
AddButton(TabHome, "📋 Copy Discord", function()
    pcall(function() setclipboard("https://discord.gg/vourds") end)
    Notify("Discord", "Link copied to clipboard!")
end)
AddButton(TabHome, "🛡️ Anti AFK", function()
    Notify("Anti-AFK", "Already active by default!")
end)
AddSection(TabHome, "Information")
AddLabel(TabHome, "Toggle Menu: Right Shift")
AddLabel(TabHome, "Version: 1.0 Premium")
AddLabel(TabHome, "Status: ✓ Loaded")

-- ═══════════════ MOVEMENT TAB ═══════════════
AddSection(TabMovement, "Speed")
AddSlider(TabMovement, "Walk Speed", 16, 500, 16, function(v)
    Config.WalkSpeed = v
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end
end)
AddSlider(TabMovement, "Jump Power", 50, 500, 50, function(v)
    Config.JumpPower = v
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = v
        end
    end
end)
AddSection(TabMovement, "Flight")
local FlyToggle, FlySpeedSlider, FlyConn
FlyToggle = AddToggle(TabMovement, "Fly", false, function(v)
    Config.FlyEnabled = v
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if v then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "FlyVelocity"
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = hrp
        local bg = Instance.new("BodyGyro")
        bg.Name = "FlyGyro"
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.P = 1000
        bg.Parent = hrp
        hum.PlatformStand = true

        FlyConn = RunService.RenderStepped:Connect(function()
            if not Config.FlyEnabled then return end
            local cam = workspace.CurrentCamera
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
            bv.Velocity = move * Config.FlySpeed
            bg.CFrame = cam.CFrame
        end)
    else
        if FlyConn then FlyConn:Disconnect() end
        hum.PlatformStand = false
        local bv = hrp:FindFirstChild("FlyVelocity") if bv then bv:Destroy() end
        local bg = hrp:FindFirstChild("FlyGyro") if bg then bg:Destroy() end
    end
end)
FlySpeedSlider = AddSlider(TabMovement, "Fly Speed", 10, 500, 100, function(v) Config.FlySpeed = v end)
AddSection(TabMovement, "Other")
AddToggle(TabMovement, "Noclip", false, function(v)
    Config.Noclip = v
end)
AddToggle(TabMovement, "Infinite Jump", false, function(v)
    Config.InfiniteJump = v
end)
AddToggle(TabMovement, "No Fall Damage", false, function(v) Config.NoFallDamage = v end)

-- Noclip loop
RunService.Stepped:Connect(function()
    if Config.Noclip then
        local char = LP.Character
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end
end)

-- Infinite jump
UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        local char = LP.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState("Jumping") end
        end
    end
end)

-- ═══════════════ COMBAT TAB ═══════════════
AddSection(TabCombat, "Aimbot")
AddToggle(TabCombat, "Enable Aimbot", false, function(v) Config.AimbotEnabled = v end)
AddSlider(TabCombat, "Smoothness", 0.01, 1, 0.15, function(v) Config.AimbotSmoothness = v end)
AddSlider(TabCombat, "FOV", 50, 500, 150, function(v) Config.AimbotFOV = v end)
AddDropdown(TabCombat, "Target Part", {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}, "Head", function(v) Config.AimbotPart = v end)
AddToggle(TabCombat, "Team Check", true, function(v) Config.ESPSteamCheck = v; Config.AimbotTeamCheck = v end)
AddSection(TabCombat, "Combat")
AddToggle(TabCombat, "Auto Clicker", false, function(v) Config.AutoClick = v end)
AddSlider(TabCombat, "Click Delay (s)", 0.01, 1, 0.1, function(v) Config.ClickDelay = v end)
AddToggle(TabCombat, "Kill Aura", false, function(v) Config.KillAura = v end)

-- Aimbot logic
local FOVCircle
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 2
    FOVCircle.Color = Theme.Accent
    FOVCircle.Transparency = 0.7
    FOVCircle.Filled = false
end)

RunService.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Radius = Config.AimbotFOV
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Visible = Config.AimbotEnabled
    end

    if not Config.AimbotEnabled then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    local closest, closestDist = nil, Config.AimbotFOV
    local cam = workspace.CurrentCamera

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local part = plr.Character:FindFirstChild(Config.AimbotPart)
            if part then
                local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local mousePos = UserInputService:GetMouseLocation()
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = part
                    end
                end
            end
        end
    end

    if closest then
        cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, closest.Position), Config.AimbotSmoothness)
    end
end)

-- Auto Clicker
task.spawn(function()
    while true do
        if Config.AutoClick then
            pcall(function()
                local VIM = game:GetService("VirtualInputManager")
                VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 1)
                VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 1)
            end)
            task.wait(Config.ClickDelay or 0.1)
        else
            task.wait(0.1)
        end
    end
end)

-- ═══════════════ VISUALS TAB ═══════════════
AddSection(TabVisuals, "Player ESP")
AddToggle(TabVisuals, "Enable ESP", false, function(v) Config.ESPEnabled = v; if not v then ClearESP() end end)
AddToggle(TabVisuals, "Box", true, function(v) Config.ESPBox = v end)
AddToggle(TabVisuals, "Name", true, function(v) Config.ESPName = v end)
AddToggle(TabVisuals, "Health", true, function(v) Config.ESPHealth = v end)
AddToggle(TabVisuals, "Distance", true, function(v) Config.ESPDistance = v end)
AddToggle(TabVisuals, "Tracer", false, function(v) Config.ESPTracer = v end)
AddSection(TabVisuals, "World")
AddToggle(TabVisuals, "Fullbright", false, function(v)
    Config.FullBright = v
    if v then
        Lighting.Ambient = Color3.new(1,1,1)
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.Brightness = 3
        Lighting.FogEnd = 100000
    else
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Brightness = 2
    end
end)
AddToggle(TabVisuals, "Remove Fog", false, function(v)
    if v then Lighting.FogEnd = 100000 else Lighting.FogEnd = 1000 end
end)
AddButton(TabVisuals, "Clear All ESP", function() ClearESP() end)

-- ESP system
function ClearESP()
    for _, obj in pairs(ESPCache) do
        pcall(function() obj:Destroy() end)
    end
    ESPCache = {}
end

local function CreateESP(plr)
    if plr == LP then return end
    if ESPCache[plr] then return end
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Color = Theme.Accent
    box.Filled = false
    box.Transparency = 1
    local name = Drawing.new("Text")
    name.Size = 14
    name.Center = true
    name.Outline = true
    name.Color = Color3.new(1,1,1)
    name.Transparency = 1
    local health = Drawing.new("Text")
    health.Size = 12
    health.Center = false
    health.Outline = true
    health.Color = Color3.new(0,1,0)
    health.Transparency = 1
    local distance = Drawing.new("Text")
    distance.Size = 12
    distance.Center = true
    distance.Outline = true
    distance.Color = Color3.new(1,1,1)
    distance.Transparency = 1
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Color = Theme.Accent
    tracer.Transparency = 1

    ESPCache[plr] = {Box = box, Name = name, Health = health, Distance = distance, Tracer = tracer}
end

local function RemoveESP(plr)
    local cache = ESPCache[plr]
    if cache then
        for _, obj in pairs(cache) do
            pcall(function() obj:Remove() end)
        end
        ESPCache[plr] = nil
    end
end

local function UpdateESP()
    if not Config.ESPEnabled then
        for _, cache in pairs(ESPCache) do
            for _, obj in pairs(cache) do
                pcall(function() obj.Visible = false end)
            end
        end
        return
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                if not ESPCache[plr] then CreateESP(plr) end
                local cache = ESPCache[plr]
                if not cache then continue end
                local pos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(hrp.Position)

                if onScreen and hum.Health > 0 then
                    local headPos = workspace.CurrentCamera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                    local footPos = workspace.CurrentCamera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                    local height = math.abs(headPos.Y - footPos.Y)
                    local width = height / 2

                    if Config.ESPBox then
                        cache.Box.Visible = true
                        cache.Box.Size = Vector2.new(width, height)
                        cache.Box.Position = Vector2.new(pos.X - width/2, pos.Y - height/2)
                    else
                        cache.Box.Visible = false
                    end

                    if Config.ESPName then
                        cache.Name.Visible = true
                        cache.Name.Text = plr.Name
                        cache.Name.Position = Vector2.new(pos.X, pos.Y - height/2 - 18)
                    else
                        cache.Name.Visible = false
                    end

                    if Config.ESPHealth then
                        cache.Health.Visible = true
                        cache.Health.Text = string.format("%d HP", math.floor(hum.Health))
                        cache.Health.Color = Color3.fromRGB(255 * (1 - hum.Health/hum.MaxHealth), 255 * (hum.Health/hum.MaxHealth), 0)
                        cache.Health.Position = Vector2.new(pos.X + width/2 + 4, pos.Y - 10)
                    else
                        cache.Health.Visible = false
                    end

                    if Config.ESPDistance then
                        cache.Distance.Visible = true
                        local dist = (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and (LP.Character.HumanoidRootPart.Position - hrp.Position).Magnitude) or 0
                        cache.Distance.Text = string.format("[%d studs]", math.floor(dist))
                        cache.Distance.Position = Vector2.new(pos.X, pos.Y + height/2 + 4)
                    else
                        cache.Distance.Visible = false
                    end

                    if Config.ESPTracer then
                        cache.Tracer.Visible = true
                        cache.Tracer.From = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y)
                        cache.Tracer.To = Vector2.new(pos.X, pos.Y)
                    else
                        cache.Tracer.Visible = false
                    end
                else
                    cache.Box.Visible = false
                    cache.Name.Visible = false
                    cache.Health.Visible = false
                    cache.Distance.Visible = false
                    cache.Tracer.Visible = false
                end
            end
        end
    end
end

RunService.RenderStepped:Connect(UpdateESP)

-- ═══════════════ FARM TAB ═══════════════
AddSection(TabFarm, "Auto Farm")
AddToggle(TabFarm, "Auto Farm", false, function(v) Config.AutoFarm = v end)
AddSlider(TabFarm, "Farm Range", 5, 200, 50, function(v) Config.FarmRange = v end)
AddButton(TabFarm, "Farm Nearest NPC", function()
    local closest, dist = nil, math.huge
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            if obj ~= char then
                local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
                if root then
                    local d = (hrp.Position - root.Position).Magnitude
                    if d < dist then dist = d; closest = root end
                end
            end
        end
    end

    if closest then
        hrp.CFrame = closest.CFrame + Vector3.new(0, 3, 0)
        Notify("Farm", "Teleported to target!")
    else
        Notify("Farm", "No target found")
    end
end)
AddSection(TabFarm, "Auto Farm Loop")
task.spawn(function()
    while true do
        if Config.AutoFarm then
            local char = LP.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local closest, dist = nil, Config.FarmRange or 50
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and obj ~= char then
                            local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
                            if root then
                                local d = (hrp.Position - root.Position).Magnitude
                                if d < dist then dist = d; closest = root end
                            end
                        end
                    end
                    if closest then
                        hrp.CFrame = closest.CFrame + Vector3.new(0, 3, 0)
                    end
                end
            end
            task.wait(0.1)
        else
            task.wait(0.5)
        end
    end
end)

-- ═══════════════ TELEPORT TAB ═══════════════
AddSection(TabTeleport, "Quick Actions")
AddButton(TabTeleport, "📍 Save Current Position", function()
    local char = LP.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local pos = char.HumanoidRootPart.CFrame
        table.insert(Config.SavedPositions, {Name = "Pos_" .. #Config.SavedPositions + 1, CFrame = pos})
        Notify("Teleport", "Saved position #" .. #Config.SavedPositions)
    end
end)
AddButton(TabTeleport, "🔙 Teleport to Last Saved", function()
    if #Config.SavedPositions > 0 then
        local char = LP.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = Config.SavedPositions[#Config.SavedPositions].CFrame
            Notify("Teleport", "Teleported to last position")
        end
    end
end)
AddSection(TabTeleport, "Coordinate Teleport")
local TXBox = AddTextbox(TabTeleport, "X Coordinate", "0", function() end)
local TYBox = AddTextbox(TabTeleport, "Y Coordinate", "0", function() end)
local TZBox = AddTextbox(TabTeleport, "Z Coordinate", "0", function() end)
AddButton(TabTeleport, "🎯 Teleport to Coordinates", function()
    local x = tonumber(TXBox.Text) or 0
    local y = tonumber(TYBox.Text) or 0
    local z = tonumber(TZBox.Text) or 0
    local char = LP.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
        Notify("Teleport", string.format("Teleported to (%.1f, %.1f, %.1f)", x, y, z))
    end
end)
AddSection(TabTeleport, "Players")
AddButton(TabTeleport, "🌐 Teleport to Random Player", function()
    local others = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(others, p)
        end
    end
    if #others > 0 then
        local target = others[math.random(1, #others)]
        local char = LP.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
            Notify("Teleport", "Teleported to " .. target.Name)
        end
    else
        Notify("Teleport", "No other players found")
    end
end)

-- ═══════════════ PLAYER TAB ═══════════════
AddSection(TabPlayer, "Character")
AddButton(TabPlayer, "❤️ Full Heal", function()
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = hum.MaxHealth; Notify("Player", "Healed!") end
    end
end)
AddButton(TabPlayer, "💀 Reset Character", function()
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
end)
AddButton(TabPlayer, "🧹 Remove Accessories", function()
    local char = LP.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Accessory") or obj:IsA("Hat") then obj:Destroy() end
        end
        Notify("Player", "Accessories removed")
    end
end)
AddSection(TabPlayer, "Info")
local PlayerNameLabel = AddLabel(TabPlayer, "Username: " .. LP.Name, Theme.Accent)
local UserIdLabel = AddLabel(TabPlayer, "UserId: " .. LP.UserId)
local AccountAgeLabel = AddLabel(TabPlayer, "Account Age: " .. (LP.AccountAge or 0) .. " days")

-- ═══════════════ MISC TAB ═══════════════
AddSection(TabMisc, "Utility")
AddToggle(TabMisc, "Anti-AFK", true, function(v) Config.AntiAFK = v end)
AddToggle(TabMisc, "Auto Reconnect", false, function(v) Config.AutoReconnect = v end)
AddButton(TabMisc, "🔇 Mute Game Sounds", function()
    pcall(function()
        for _, s in ipairs(Lighting:GetChildren()) do
            if s:IsA("Sound") then s.Volume = 0 end
        end
        Notify("Misc", "Game sounds muted")
    end)
end)
AddButton(TabMisc, "🗑️ Clear Workspace Lag", function()
    pcall(function()
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                obj.Enabled = false
            end
        end
        Notify("Misc", "Lag reduced")
    end)
end)
AddSection(TabMisc, "Server")
local JobIdBox = AddTextbox(TabMisc, "Job ID", "", function() end)
AddButton(TabMisc, "➡️ Join Job ID", function()
    if JobIdBox.Text and JobIdBox.Text ~= "" then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, JobIdBox.Text, LP)
        end)
    else
        Notify("Misc", "Please enter Job ID")
    end
end)
AddSection(TabMisc, "FPS")
AddToggle(TabMisc, "FPS Boost", false, function(v)
    Config.FPSBoost = v
    pcall(function()
        if v then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.CastShadow = false
                    obj.Reflectance = 0
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                end
            end
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
        end
    end)
end)

-- Anti AFK
LP.Idled:Connect(function()
    if Config.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- ═══════════════ SETTINGS TAB ═══════════════
AddSection(TabSettings, "Menu")
AddSlider(TabSettings, "UI Transparency", 0, 1, 0, function(v)
    Main.BackgroundTransparency = v
end)
AddSlider(TabSettings, "Accent Hue", 0, 360, 270, function(v)
    local c = Color3.fromHSV(v/360, 0.85, 0.9)
    Theme.Accent = c
    Tween(ToggleBtn, 0.2, {BackgroundColor3 = c})
end)
AddSection(TabSettings, "Config")
AddButton(TabSettings, "📤 Export Config", function()
    local data = HttpService:JSONEncode(Config)
    pcall(function() setclipboard(data) end)
    Notify("Config", "Config copied to clipboard!")
end)
AddButton(TabSettings, "🔄 Reset Config", function()
    for k, v in pairs(Config) do
        if type(v) == "boolean" then Config[k] = false end
    end
    Notify("Config", "Config reset (rejoin to apply)")
end)
AddSection(TabSettings, "Info")
AddLabel(TabSettings, "Vourds Hub v1.0", Theme.Accent)
AddLabel(TabSettings, "Made with ❤️ for Master")
AddLabel(TabSettings, "Toggle Menu: Right Shift")

-- // TOGGLE MENU KEYBIND
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
        if Main.Visible then
            Main.Size = UDim2.new(0, 0, 0, 0)
            Tween(Main, 0.25, {Size = UDim2.new(0, 620, 0, 420)})
        end
    end
end)

ToggleBtn.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
    if Main.Visible then
        Main.Size = UDim2.new(0, 0, 0, 0)
        Tween(Main, 0.25, {Size = UDim2.new(0, 620, 0, 420)})
    end
end)

-- Drag main window
MakeDraggable(Main, TopBar)

-- Init default tab
TabHome.Button.MouseButton1Click:Fire()
-- Manually set initial selected
for _, t in ipairs(Tabs) do
    t.Page.Visible = false
end
TabHome.Page.Visible = true
TabHome.Indicator.Visible = true
TabHome.Button.BackgroundColor3 = Theme.Tertiary
TabHome.Label.TextColor3 = Theme.Text
TabHome.Icon.TextColor3 = Theme.Accent
CurrentTab = TabHome

-- Character setup
local function SetupCharacter(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = Config.WalkSpeed
    hum.UseJumpPower = true
    hum.JumpPower = Config.JumpPower
end
if LP.Character then SetupCharacter(LP.Character) end
LP.CharacterAdded:Connect(SetupCharacter)

Notify("Vourds Hub", "Loaded successfully! Press Right Shift to toggle menu.", 5)
print("[Vourds Hub] Loaded - Press Right Shift to open menu")