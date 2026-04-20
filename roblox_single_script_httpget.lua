local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local API_BASE_URL = "https://roblox-ukrainian-ai.onrender.com"
local CHAT_ENDPOINT = API_BASE_URL .. "/chat_text?message="

local TOPBAR_HEIGHT = 44
local WINDOW_PADDING = 12
local MIN_WINDOW_SIZE = Vector2.new(420, 300)
local DEFAULT_WINDOW_SIZE = Vector2.new(560, 430)
local REOPEN_BUTTON_SIZE = Vector2.new(72, 36)
local SCREEN_MARGIN = 10
local MESSAGE_FONT = Enum.Font.Code
local MESSAGE_TEXT_SIZE = 16
local MESSAGE_MAX_WIDTH_SCALE = 0.72
local MAX_CHAT_MESSAGES = 60
local THEME = {
    window_bg = Color3.fromRGB(34, 35, 39),
    window_bg_alt = Color3.fromRGB(28, 29, 33),
    window_stroke = Color3.fromRGB(92, 96, 104),
    topbar_bg = Color3.fromRGB(43, 44, 49),
    topbar_bg_alt = Color3.fromRGB(35, 36, 41),
    panel_bg = Color3.fromRGB(39, 40, 45),
    panel_bg_alt = Color3.fromRGB(33, 34, 39),
    panel_stroke = Color3.fromRGB(68, 71, 78),
    composer_bg = Color3.fromRGB(42, 43, 48),
    composer_bg_alt = Color3.fromRGB(36, 37, 42),
    input_bg = Color3.fromRGB(51, 53, 59),
    input_stroke = Color3.fromRGB(86, 89, 97),
    button_bg = Color3.fromRGB(71, 74, 81),
    button_bg_pressed = Color3.fromRGB(56, 58, 64),
    send_bg = Color3.fromRGB(104, 109, 118),
    send_bg_busy = Color3.fromRGB(79, 82, 89),
    chip_bg = Color3.fromRGB(48, 50, 56),
    chip_bg_active = Color3.fromRGB(71, 74, 81),
    chip_stroke = Color3.fromRGB(84, 88, 96),
    text_primary = Color3.fromRGB(241, 243, 247),
    text_secondary = Color3.fromRGB(176, 180, 188),
    text_muted = Color3.fromRGB(136, 140, 149),
    text_soft = Color3.fromRGB(207, 211, 219),
    assistant_bubble = Color3.fromRGB(48, 50, 56),
    user_bubble = Color3.fromRGB(74, 77, 85),
    bubble_stroke = Color3.fromRGB(92, 96, 104),
    ready = Color3.fromRGB(133, 189, 144),
    sending = Color3.fromRGB(214, 186, 114),
    error = Color3.fromRGB(204, 112, 112),
    scrollbar = Color3.fromRGB(102, 107, 117),
    reopen_bg = Color3.fromRGB(88, 92, 100),
    close_bg = Color3.fromRGB(126, 86, 86),
}

local function decodeUnicodeEscapes(value)
    return (value:gsub("\\u(%x%x%x%x)", function(hex)
        return utf8.char(tonumber(hex, 16))
    end))
end

local function urlEncode(value)
    return (
        tostring(value)
            :gsub("\n", "\r\n")
            :gsub("([^%w%-_%.~ ])", function(char)
                return string.format("%%%02X", string.byte(char))
            end)
            :gsub(" ", "%%20")
    )
end

local function clamp(number, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, number))
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function addGradient(target, colorA, colorB, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colorA),
        ColorSequenceKeypoint.new(1, colorB),
    })
    gradient.Rotation = rotation or 90
    gradient.Parent = target
    return gradient
end

local TEXT = {
    title = decodeUnicodeEscapes("\\u041e\\u043d\\u043b\\u0430\\u0439\\u043d AI \\u0447\\u0430\\u0442"),
    subtitle = decodeUnicodeEscapes("\\u041f\\u0435\\u0440\\u0435\\u0442\\u044f\\u0433\\u0443\\u0439, \\u0437\\u043c\\u0456\\u043d\\u044e\\u0439 \\u0440\\u043e\\u0437\\u043c\\u0456\\u0440, \\u0441\\u043f\\u0456\\u043b\\u043a\\u0443\\u0439\\u0441\\u044f."),
    placeholder = decodeUnicodeEscapes("\\u041d\\u0430\\u043f\\u0438\\u0448\\u0456\\u0442\\u044c \\u043f\\u043e\\u0432\\u0456\\u0434\\u043e\\u043c\\u043b\\u0435\\u043d\\u043d\\u044f..."),
    send = decodeUnicodeEscapes("\\u041d\\u0430\\u0434\\u0456\\u0441\\u043b\\u0430\\u0442\\u0438"),
    clear = decodeUnicodeEscapes("\\u041e\\u0447\\u0438\\u0441\\u0442"),
    web = decodeUnicodeEscapes("\\u0412\\u0435\\u0431"),
    web_on = decodeUnicodeEscapes("\\u0412\\u0435\\u0431: ON"),
    web_off = decodeUnicodeEscapes("\\u0412\\u0435\\u0431: OFF"),
    ready = decodeUnicodeEscapes("\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441: \\u0433\\u043e\\u0442\\u043e\\u0432\\u043e"),
    sending = decodeUnicodeEscapes("\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441: \\u0437\\u0430\\u043f\\u0438\\u0442 \\u0432\\u0456\\u0434\\u043f\\u0440\\u0430\\u0432\\u043b\\u0435\\u043d\\u043e"),
    received = decodeUnicodeEscapes("\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441: \\u0432\\u0456\\u0434\\u043f\\u043e\\u0432\\u0456\\u0434\\u044c \\u043e\\u0442\\u0440\\u0438\\u043c\\u0430\\u043d\\u043e"),
    request_error = decodeUnicodeEscapes("\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441: \\u043f\\u043e\\u043c\\u0438\\u043b\\u043a\\u0430 \\u0437\\u0430\\u043f\\u0438\\u0442\\u0443"),
    welcome = decodeUnicodeEscapes("\\u0412\\u0456\\u0442\\u0430\\u044e! \\u0422\\u0435\\u043f\\u0435\\u0440 \\u0446\\u0435 \\u043f\\u043e\\u0432\\u043d\\u043e\\u0446\\u0456\\u043d\\u043d\\u0435 \\u0447\\u0430\\u0442-\\u0432\\u0456\\u043a\\u043d\\u043e. \\u042f \\u043c\\u043e\\u0436\\u0443 \\u043f\\u043e\\u044f\\u0441\\u043d\\u044e\\u0432\\u0430\\u0442\\u0438 \\u0442\\u0435\\u043c\\u0438, \\u043f\\u0438\\u0441\\u0430\\u0442\\u0438 Lua/Python \\u0456 \\u0448\\u0443\\u043a\\u0430\\u0442\\u0438 \\u0456\\u043d\\u0444\\u043e\\u0440\\u043c\\u0430\\u0446\\u0456\\u044e \\u043e\\u043d\\u043b\\u0430\\u0439\\u043d."),
    empty_message = decodeUnicodeEscapes("\\u0412\\u0432\\u0435\\u0434\\u0456\\u0442\\u044c \\u0442\\u0435\\u043a\\u0441\\u0442 \\u043f\\u0435\\u0440\\u0435\\u0434 \\u0432\\u0456\\u0434\\u043f\\u0440\\u0430\\u0432\\u043a\\u043e\\u044e."),
    bridge_error = decodeUnicodeEscapes("\\u041d\\u0435 \\u0432\\u0434\\u0430\\u043b\\u043e\\u0441\\u044f \\u043e\\u0442\\u0440\\u0438\\u043c\\u0430\\u0442\\u0438 \\u0432\\u0456\\u0434\\u043f\\u043e\\u0432\\u0456\\u0434\\u044c \\u0432\\u0456\\u0434 \\u043e\\u043d\\u043b\\u0430\\u0439\\u043d API."),
    bridge_error_prefix = decodeUnicodeEscapes("\\u0414\\u0435\\u0442\\u0430\\u043b\\u0456 \\u043f\\u043e\\u043c\\u0438\\u043b\\u043a\\u0438: "),
    thinking = decodeUnicodeEscapes("\\u0414\\u0443\\u043c\\u0430\\u044e..."),
    busy = decodeUnicodeEscapes("\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441: AI \\u0449\\u0435 \\u0434\\u0443\\u043c\\u0430\\u0454"),
    assistant = "AI",
    you = decodeUnicodeEscapes("\\u0412\\u0438"),
    reopen = "AI",
    quick_explain = decodeUnicodeEscapes("\\u041f\\u043e\\u044f\\u0441\\u043d\\u0438"),
    quick_lua = "Lua",
    quick_web = decodeUnicodeEscapes("\\u0412\\u0435\\u0431"),
    quick_fix = decodeUnicodeEscapes("\\u0424\\u0456\\u043a\\u0441"),
}

local QUICK_ACTIONS = {
    {
        label = TEXT.quick_explain,
        text = decodeUnicodeEscapes("\\u041f\\u043e\\u044f\\u0441\\u043d\\u0438 \\u043a\\u043e\\u0440\\u043e\\u0442\\u043a\\u043e: "),
        web = false,
    },
    {
        label = TEXT.quick_lua,
        text = decodeUnicodeEscapes("\\u041d\\u0430\\u043f\\u0438\\u0448\\u0438 Lua \\u043f\\u0440\\u0438\\u043a\\u043b\\u0430\\u0434 \\u0434\\u043b\\u044f: "),
        web = false,
    },
    {
        label = TEXT.quick_web,
        text = decodeUnicodeEscapes("\\u0417\\u043d\\u0430\\u0439\\u0434\\u0438 \\u0432 \\u0456\\u043d\\u0442\\u0435\\u0440\\u043d\\u0435\\u0442\\u0456: "),
        web = true,
    },
    {
        label = TEXT.quick_fix,
        text = decodeUnicodeEscapes("\\u0414\\u043e\\u043f\\u043e\\u043c\\u043e\\u0436\\u0438 \\u0437\\u043d\\u0430\\u0439\\u0442\\u0438 \\u043f\\u043e\\u043c\\u0438\\u043b\\u043a\\u0443 \\u0432 \\u043a\\u043e\\u0434\\u0456: "),
        web = false,
    },
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function getViewportSize()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1280, 720)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OnlineAIChatGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 50
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Window"
frame.BackgroundColor3 = THEME.window_bg
frame.BorderSizePixel = 0
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 16)
frameCorner.Parent = frame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = THEME.window_stroke
frameStroke.Thickness = 1.4
frameStroke.Parent = frame

addGradient(frame, THEME.window_bg, THEME.window_bg_alt, 90)

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT)
topBar.Active = true
topBar.BackgroundColor3 = THEME.topbar_bg
topBar.BorderSizePixel = 0
topBar.Parent = frame

local topBarCorner = Instance.new("UICorner")
topBarCorner.CornerRadius = UDim.new(0, 16)
topBarCorner.Parent = topBar

local topBarFill = Instance.new("Frame")
topBarFill.Size = UDim2.new(1, 0, 0, 18)
topBarFill.Position = UDim2.new(0, 0, 1, -18)
topBarFill.BackgroundColor3 = topBar.BackgroundColor3
topBarFill.BorderSizePixel = 0
topBarFill.Parent = topBar

addGradient(topBar, THEME.topbar_bg, THEME.topbar_bg_alt, 90)

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Position = UDim2.fromOffset(14, 4)
titleLabel.Size = UDim2.new(1, -180, 0, 20)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = TEXT.title
titleLabel.TextColor3 = THEME.text_primary
titleLabel.TextSize = 19
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.Position = UDim2.fromOffset(14, 22)
subtitleLabel.Size = UDim2.new(1, -180, 0, 16)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.Text = TEXT.subtitle
subtitleLabel.TextColor3 = THEME.text_muted
subtitleLabel.TextSize = 12
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.Parent = topBar

local topButtons = Instance.new("Frame")
topButtons.Name = "TopButtons"
topButtons.AnchorPoint = Vector2.new(1, 0.5)
topButtons.Position = UDim2.new(1, -10, 0.5, 0)
topButtons.Size = UDim2.fromOffset(120, 28)
topButtons.BackgroundTransparency = 1
topButtons.Parent = topBar

local topButtonsLayout = Instance.new("UIListLayout")
topButtonsLayout.FillDirection = Enum.FillDirection.Horizontal
topButtonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
topButtonsLayout.Padding = UDim.new(0, 6)
topButtonsLayout.Parent = topButtons

local function createTopButton(name, text, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.fromOffset(32, 28)
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.TextColor3 = THEME.text_primary
    button.TextSize = 14
    button.Parent = topButtons

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    return button
end

local minimizeButton = createTopButton("MinimizeButton", "_", THEME.button_bg)
local maximizeButton = createTopButton("MaximizeButton", "[]", THEME.button_bg)
local closeButton = createTopButton("CloseButton", "X", THEME.close_bg)

local body = Instance.new("Frame")
body.Name = "Body"
body.Position = UDim2.fromOffset(0, TOPBAR_HEIGHT)
body.Size = UDim2.new(1, 0, 1, -TOPBAR_HEIGHT)
body.BackgroundTransparency = 1
body.Parent = frame

local bodyPadding = Instance.new("UIPadding")
bodyPadding.PaddingTop = UDim.new(0, WINDOW_PADDING)
bodyPadding.PaddingBottom = UDim.new(0, WINDOW_PADDING)
bodyPadding.PaddingLeft = UDim.new(0, WINDOW_PADDING)
bodyPadding.PaddingRight = UDim.new(0, WINDOW_PADDING)
bodyPadding.Parent = body

local statusBar = Instance.new("Frame")
statusBar.Name = "StatusBar"
statusBar.Size = UDim2.new(1, 0, 0, 24)
statusBar.BackgroundTransparency = 1
statusBar.Parent = body

local statusDot = Instance.new("Frame")
statusDot.Name = "StatusDot"
statusDot.Size = UDim2.fromOffset(8, 8)
statusDot.Position = UDim2.fromOffset(0, 8)
statusDot.BackgroundColor3 = THEME.ready
statusDot.BorderSizePixel = 0
statusDot.Parent = statusBar

local statusDotCorner = Instance.new("UICorner")
statusDotCorner.CornerRadius = UDim.new(1, 0)
statusDotCorner.Parent = statusDot

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Position = UDim2.fromOffset(16, 0)
statusLabel.Size = UDim2.new(1, -120, 1, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = TEXT.ready
statusLabel.TextColor3 = THEME.text_secondary
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = statusBar

local modeBadge = Instance.new("TextLabel")
modeBadge.Name = "ModeBadge"
modeBadge.AnchorPoint = Vector2.new(1, 0.5)
modeBadge.Position = UDim2.new(1, 0, 0.5, 0)
modeBadge.Size = UDim2.fromOffset(96, 24)
modeBadge.BackgroundColor3 = THEME.chip_bg
modeBadge.BorderSizePixel = 0
modeBadge.Font = Enum.Font.GothamBold
modeBadge.Text = TEXT.web_off
modeBadge.TextColor3 = THEME.text_soft
modeBadge.TextSize = 13
modeBadge.Parent = statusBar

local modeBadgeCorner = Instance.new("UICorner")
modeBadgeCorner.CornerRadius = UDim.new(0, 9)
modeBadgeCorner.Parent = modeBadge

local modeBadgeStroke = Instance.new("UIStroke")
modeBadgeStroke.Color = THEME.chip_stroke
modeBadgeStroke.Thickness = 1
modeBadgeStroke.Parent = modeBadge

local quickActionsScroll = Instance.new("ScrollingFrame")
quickActionsScroll.Name = "QuickActionsScroll"
quickActionsScroll.Position = UDim2.fromOffset(0, 30)
quickActionsScroll.Size = UDim2.new(1, 0, 0, 30)
quickActionsScroll.Active = true
quickActionsScroll.BackgroundTransparency = 1
quickActionsScroll.BorderSizePixel = 0
quickActionsScroll.CanvasSize = UDim2.fromOffset(0, 0)
quickActionsScroll.ScrollBarThickness = 0
quickActionsScroll.ScrollingDirection = Enum.ScrollingDirection.X
quickActionsScroll.Parent = body

local quickActionsContent = Instance.new("Frame")
quickActionsContent.Name = "QuickActionsContent"
quickActionsContent.AutomaticSize = Enum.AutomaticSize.X
quickActionsContent.Size = UDim2.new(0, 0, 1, 0)
quickActionsContent.BackgroundTransparency = 1
quickActionsContent.Parent = quickActionsScroll

local quickActionsLayout = Instance.new("UIListLayout")
quickActionsLayout.FillDirection = Enum.FillDirection.Horizontal
quickActionsLayout.Padding = UDim.new(0, 8)
quickActionsLayout.Parent = quickActionsContent

local messagesScroll = Instance.new("ScrollingFrame")
messagesScroll.Name = "MessagesScroll"
messagesScroll.Position = UDim2.fromOffset(0, 68)
messagesScroll.Size = UDim2.new(1, 0, 1, -146)
messagesScroll.Active = true
messagesScroll.BackgroundColor3 = THEME.panel_bg
messagesScroll.BorderSizePixel = 0
messagesScroll.ScrollBarThickness = 6
messagesScroll.ScrollBarImageColor3 = THEME.scrollbar
messagesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
messagesScroll.ScrollingDirection = Enum.ScrollingDirection.Y
messagesScroll.Parent = body

local messagesCorner = Instance.new("UICorner")
messagesCorner.CornerRadius = UDim.new(0, 14)
messagesCorner.Parent = messagesScroll

local messagesStroke = Instance.new("UIStroke")
messagesStroke.Color = THEME.panel_stroke
messagesStroke.Thickness = 1
messagesStroke.Parent = messagesScroll

addGradient(messagesScroll, THEME.panel_bg, THEME.panel_bg_alt, 90)

local messagesContent = Instance.new("Frame")
messagesContent.Name = "MessagesContent"
messagesContent.Size = UDim2.new(1, -12, 0, 0)
messagesContent.AutomaticSize = Enum.AutomaticSize.Y
messagesContent.BackgroundTransparency = 1
messagesContent.Parent = messagesScroll

local messagesPadding = Instance.new("UIPadding")
messagesPadding.PaddingTop = UDim.new(0, 12)
messagesPadding.PaddingBottom = UDim.new(0, 12)
messagesPadding.PaddingLeft = UDim.new(0, 10)
messagesPadding.PaddingRight = UDim.new(0, 10)
messagesPadding.Parent = messagesContent

local messagesLayout = Instance.new("UIListLayout")
messagesLayout.Padding = UDim.new(0, 10)
messagesLayout.Parent = messagesContent

local composer = Instance.new("Frame")
composer.Name = "Composer"
composer.AnchorPoint = Vector2.new(0, 1)
composer.Position = UDim2.new(0, 0, 1, 0)
composer.Size = UDim2.new(1, 0, 0, 68)
composer.BackgroundColor3 = THEME.composer_bg
composer.BorderSizePixel = 0
composer.Parent = body

local composerCorner = Instance.new("UICorner")
composerCorner.CornerRadius = UDim.new(0, 14)
composerCorner.Parent = composer

local composerStroke = Instance.new("UIStroke")
composerStroke.Color = THEME.panel_stroke
composerStroke.Thickness = 1
composerStroke.Parent = composer

addGradient(composer, THEME.composer_bg, THEME.composer_bg_alt, 90)

local clearButton = Instance.new("TextButton")
clearButton.Name = "ClearButton"
clearButton.Position = UDim2.fromOffset(10, 13)
clearButton.Size = UDim2.fromOffset(60, 42)
clearButton.BackgroundColor3 = THEME.button_bg
clearButton.BorderSizePixel = 0
clearButton.Font = Enum.Font.GothamBold
clearButton.Text = TEXT.clear
clearButton.TextColor3 = THEME.text_primary
clearButton.TextSize = 14
clearButton.Parent = composer

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 10)
clearCorner.Parent = clearButton

local clearStroke = Instance.new("UIStroke")
clearStroke.Color = THEME.panel_stroke
clearStroke.Thickness = 1
clearStroke.Parent = clearButton

addGradient(clearButton, THEME.button_bg, THEME.button_bg_pressed, 90)

local webToggleButton = Instance.new("TextButton")
webToggleButton.Name = "WebToggleButton"
webToggleButton.Position = UDim2.fromOffset(76, 13)
webToggleButton.Size = UDim2.fromOffset(60, 42)
webToggleButton.BackgroundColor3 = THEME.button_bg
webToggleButton.BorderSizePixel = 0
webToggleButton.Font = Enum.Font.GothamBold
webToggleButton.Text = TEXT.web
webToggleButton.TextColor3 = THEME.text_primary
webToggleButton.TextSize = 14
webToggleButton.Parent = composer

local webCorner = Instance.new("UICorner")
webCorner.CornerRadius = UDim.new(0, 10)
webCorner.Parent = webToggleButton

local webStroke = Instance.new("UIStroke")
webStroke.Color = THEME.panel_stroke
webStroke.Thickness = 1
webStroke.Parent = webToggleButton

addGradient(webToggleButton, THEME.button_bg, THEME.button_bg_pressed, 90)

local sendButton = Instance.new("TextButton")
sendButton.Name = "SendButton"
sendButton.AnchorPoint = Vector2.new(1, 0)
sendButton.Position = UDim2.new(1, -10, 0, 13)
sendButton.Size = UDim2.fromOffset(100, 42)
sendButton.BackgroundColor3 = THEME.send_bg
sendButton.BorderSizePixel = 0
sendButton.Font = Enum.Font.GothamBold
sendButton.Text = TEXT.send
sendButton.TextColor3 = THEME.text_primary
sendButton.TextSize = 15
sendButton.Parent = composer

local sendCorner = Instance.new("UICorner")
sendCorner.CornerRadius = UDim.new(0, 10)
sendCorner.Parent = sendButton

local sendStroke = Instance.new("UIStroke")
sendStroke.Color = THEME.window_stroke
sendStroke.Thickness = 1
sendStroke.Parent = sendButton

addGradient(sendButton, THEME.send_bg, THEME.button_bg, 90)

local inputBox = Instance.new("TextBox")
inputBox.Name = "InputBox"
inputBox.Position = UDim2.fromOffset(142, 13)
inputBox.Size = UDim2.new(1, -252, 0, 42)
inputBox.BackgroundColor3 = THEME.input_bg
inputBox.BorderSizePixel = 0
inputBox.ClearTextOnFocus = false
inputBox.Font = Enum.Font.Code
inputBox.PlaceholderText = TEXT.placeholder
inputBox.Text = ""
inputBox.TextColor3 = THEME.text_primary
inputBox.PlaceholderColor3 = THEME.text_muted
inputBox.TextSize = 16
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.Parent = composer

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 10)
inputCorner.Parent = inputBox

local inputPadding = Instance.new("UIPadding")
inputPadding.PaddingLeft = UDim.new(0, 12)
inputPadding.PaddingRight = UDim.new(0, 12)
inputPadding.Parent = inputBox

local inputStroke = Instance.new("UIStroke")
inputStroke.Color = THEME.input_stroke
inputStroke.Thickness = 1
inputStroke.Parent = inputBox

local resizeHandle = Instance.new("TextButton")
resizeHandle.Name = "ResizeHandle"
resizeHandle.AnchorPoint = Vector2.new(1, 1)
resizeHandle.Position = UDim2.new(1, -8, 1, -8)
resizeHandle.Size = UDim2.fromOffset(18, 18)
resizeHandle.Active = true
resizeHandle.BackgroundColor3 = THEME.button_bg_pressed
resizeHandle.BorderSizePixel = 0
resizeHandle.Font = Enum.Font.Code
resizeHandle.Text = "//"
resizeHandle.TextColor3 = THEME.text_muted
resizeHandle.TextSize = 12
resizeHandle.Parent = frame

local resizeCorner = Instance.new("UICorner")
resizeCorner.CornerRadius = UDim.new(0, 5)
resizeCorner.Parent = resizeHandle

local reopenButton = Instance.new("TextButton")
reopenButton.Name = "ReopenButton"
reopenButton.Visible = false
reopenButton.Size = UDim2.fromOffset(REOPEN_BUTTON_SIZE.X, REOPEN_BUTTON_SIZE.Y)
reopenButton.BackgroundColor3 = THEME.reopen_bg
reopenButton.BorderSizePixel = 0
reopenButton.Font = Enum.Font.GothamBold
reopenButton.Text = TEXT.reopen
reopenButton.TextColor3 = THEME.text_primary
reopenButton.TextSize = 18
reopenButton.Parent = screenGui

local reopenCorner = Instance.new("UICorner")
reopenCorner.CornerRadius = UDim.new(0, 10)
reopenCorner.Parent = reopenButton

local reopenStroke = Instance.new("UIStroke")
reopenStroke.Color = THEME.window_stroke
reopenStroke.Thickness = 1
reopenStroke.Parent = reopenButton

addGradient(reopenButton, THEME.reopen_bg, THEME.button_bg_pressed, 90)

local windowSize = Vector2.new(DEFAULT_WINDOW_SIZE.X, DEFAULT_WINDOW_SIZE.Y)
local windowPosition
local minimized = false
local hidden = false
local maximized = false
local restoreState = nil
local forceWebSearch = false
local isBusy = false
local dragInput = nil
local dragStart = nil
local dragStartPosition = nil
local resizeInput = nil
local resizeStart = nil
local resizeStartSize = nil
local chatMessages = {}
local quickActionButtons = {}

local function getTimeStamp()
    local ok, stamp = pcall(function()
        return os.date("%H:%M")
    end)
    if ok and type(stamp) == "string" then
        return stamp
    end
    return ""
end

local function updateQuickActionsCanvas()
    quickActionsScroll.CanvasSize = UDim2.fromOffset(quickActionsLayout.AbsoluteContentSize.X, 0)
end

local function createQuickActionButton(action)
    local labelWidth = TextService:GetTextSize(action.label, 13, Enum.Font.GothamSemibold, Vector2.new(220, 24)).X + 24
    local button = Instance.new("TextButton")
    button.Name = "QuickActionButton"
    button.Size = UDim2.fromOffset(labelWidth, 30)
    button.BackgroundColor3 = THEME.chip_bg
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamSemibold
    button.Text = action.label
    button.TextColor3 = THEME.text_soft
    button.TextSize = 13
    button.Parent = quickActionsContent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.chip_stroke
    stroke.Thickness = 1
    stroke.Parent = button

    addGradient(button, THEME.chip_bg, THEME.button_bg_pressed, 90)

    button.MouseButton1Click:Connect(function()
        if isBusy then
            return
        end
        forceWebSearch = action.web == true
        updateModeBadge()
        inputBox.Text = action.text
        inputBox:CaptureFocus()
        pcall(function()
            inputBox.CursorPosition = #inputBox.Text + 1
        end)
    end)

    quickActionButtons[#quickActionButtons + 1] = button
end

for _, action in ipairs(QUICK_ACTIONS) do
    createQuickActionButton(action)
end

quickActionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateQuickActionsCanvas)
task.defer(updateQuickActionsCanvas)

local function updateModeBadge()
    modeBadge.Text = forceWebSearch and TEXT.web_on or TEXT.web_off
    modeBadge.BackgroundColor3 = forceWebSearch and THEME.chip_bg_active or THEME.chip_bg
    webToggleButton.BackgroundColor3 = forceWebSearch and THEME.chip_bg_active or THEME.button_bg
end

local function updateReopenButtonPosition()
    local viewport = getViewportSize()
    reopenButton.Position = UDim2.fromOffset(
        viewport.X - REOPEN_BUTTON_SIZE.X - SCREEN_MARGIN,
        viewport.Y - REOPEN_BUTTON_SIZE.Y - SCREEN_MARGIN
    )
end

local function getWindowRect()
    local viewport = getViewportSize()
    if maximized then
        return Vector2.new(SCREEN_MARGIN, SCREEN_MARGIN), Vector2.new(
            viewport.X - (SCREEN_MARGIN * 2),
            viewport.Y - (SCREEN_MARGIN * 2)
        )
    end

    if not windowPosition then
        windowPosition = Vector2.new(
            math.floor((viewport.X - windowSize.X) * 0.5),
            math.floor((viewport.Y - windowSize.Y) * 0.5)
        )
    end

    local width = windowSize.X
    local height = minimized and TOPBAR_HEIGHT or windowSize.Y
    local maxX = math.max(SCREEN_MARGIN, viewport.X - width - SCREEN_MARGIN)
    local maxY = math.max(SCREEN_MARGIN, viewport.Y - height - SCREEN_MARGIN)
    windowPosition = Vector2.new(
        clamp(windowPosition.X, SCREEN_MARGIN, maxX),
        clamp(windowPosition.Y, SCREEN_MARGIN, maxY)
    )
    return windowPosition, Vector2.new(width, height)
end

local function getMessagesWidth()
    local width = messagesScroll.AbsoluteSize.X
    if width <= 0 then
        width = windowSize.X - (WINDOW_PADDING * 2) - 24
    end
    return math.max(280, width)
end

local function scrollToBottom()
    task.defer(function()
        local canvasHeight = math.max(0, messagesLayout.AbsoluteContentSize.Y + 24)
        messagesScroll.CanvasSize = UDim2.fromOffset(0, canvasHeight)
        local maxY = math.max(0, canvasHeight - messagesScroll.AbsoluteSize.Y)
        messagesScroll.CanvasPosition = Vector2.new(0, maxY)
    end)
end

local function clearMessageRows()
    for _, child in ipairs(messagesContent:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function renderMessages(shouldScroll)
    clearMessageRows()

    local availableWidth = getMessagesWidth()
    local maxBubbleWidth = math.floor(availableWidth * MESSAGE_MAX_WIDTH_SCALE)

    for _, message in ipairs(chatMessages) do
        local row = Instance.new("Frame")
        row.Name = "MessageRow"
        row.Size = UDim2.new(1, 0, 0, 0)
        row.BackgroundTransparency = 1
        row.Parent = messagesContent

        local senderText = message.role == "user" and TEXT.you or TEXT.assistant
        local bubbleColor = message.role == "user"
            and THEME.user_bubble
            or THEME.assistant_bubble
        local senderColor = message.role == "user"
            and THEME.text_primary
            or THEME.text_soft
        local messageColor = message.pending
            and THEME.text_secondary
            or THEME.text_primary
        local headerText = senderText
        if message.stamp and message.stamp ~= "" then
            headerText = headerText .. " | " .. message.stamp
        end

        local textBounds = TextService:GetTextSize(
            message.text,
            MESSAGE_TEXT_SIZE,
            MESSAGE_FONT,
            Vector2.new(maxBubbleWidth - 22, 10000)
        )
        local bubbleWidth = clamp(textBounds.X + 22, 170, maxBubbleWidth)
        local bubbleHeight = textBounds.Y + 38

        local bubble = Instance.new("Frame")
        bubble.Name = "Bubble"
        bubble.Size = UDim2.fromOffset(bubbleWidth, bubbleHeight)
        bubble.Position = message.role == "user"
            and UDim2.new(1, -bubbleWidth, 0, 0)
            or UDim2.fromOffset(0, 0)
        bubble.BackgroundColor3 = bubbleColor
        bubble.BorderSizePixel = 0
        bubble.Parent = row

        local bubbleCorner = Instance.new("UICorner")
        bubbleCorner.CornerRadius = UDim.new(0, 12)
        bubbleCorner.Parent = bubble

        local bubbleStroke = Instance.new("UIStroke")
        bubbleStroke.Color = THEME.bubble_stroke
        bubbleStroke.Thickness = 1
        bubbleStroke.Transparency = message.role == "user" and 0.15 or 0.35
        bubbleStroke.Parent = bubble

        local senderLabel = Instance.new("TextLabel")
        senderLabel.Name = "SenderLabel"
        senderLabel.Position = UDim2.fromOffset(10, 6)
        senderLabel.Size = UDim2.new(1, -20, 0, 12)
        senderLabel.BackgroundTransparency = 1
        senderLabel.Font = Enum.Font.GothamBold
        senderLabel.Text = headerText
        senderLabel.TextColor3 = senderColor
        senderLabel.TextSize = 11
        senderLabel.TextXAlignment = Enum.TextXAlignment.Left
        senderLabel.Parent = bubble

        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "MessageText"
        textLabel.Position = UDim2.fromOffset(10, 20)
        textLabel.Size = UDim2.fromOffset(bubbleWidth - 20, textBounds.Y + 2)
        textLabel.BackgroundTransparency = 1
        textLabel.Font = MESSAGE_FONT
        textLabel.Text = message.text
        textLabel.TextColor3 = messageColor
        textLabel.TextSize = MESSAGE_TEXT_SIZE
        textLabel.TextWrapped = true
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.TextYAlignment = Enum.TextYAlignment.Top
        textLabel.Parent = bubble

        row.Size = UDim2.new(1, 0, 0, bubbleHeight)
    end

    if shouldScroll then
        scrollToBottom()
    else
        task.defer(function()
            local canvasHeight = math.max(0, messagesLayout.AbsoluteContentSize.Y + 24)
            messagesScroll.CanvasSize = UDim2.fromOffset(0, canvasHeight)
        end)
    end
end

local function pushMessage(role, text, pending)
    chatMessages[#chatMessages + 1] = {
        role = role,
        text = text,
        pending = pending == true,
        stamp = getTimeStamp(),
    }
    while #chatMessages > MAX_CHAT_MESSAGES do
        table.remove(chatMessages, 1)
    end
    renderMessages(true)
    return #chatMessages
end

local function updateMessage(index, text, pending)
    local message = chatMessages[index]
    if not message then
        return
    end
    message.text = text
    message.pending = pending == true
    renderMessages(true)
end

local function resetChat()
    chatMessages = {}
    pushMessage("assistant", TEXT.welcome, false)
end

local function setBusy(isBusy)
    isBusy = isBusy == true
    sendButton.BackgroundColor3 = isBusy and THEME.send_bg_busy or THEME.send_bg
    sendButton.Active = not isBusy
    sendButton.AutoButtonColor = not isBusy
    sendButton.Text = isBusy and "..." or TEXT.send
    clearButton.BackgroundColor3 = isBusy and THEME.button_bg_pressed or THEME.button_bg
    clearButton.Active = not isBusy
    clearButton.AutoButtonColor = not isBusy
    webToggleButton.Active = not isBusy
    webToggleButton.AutoButtonColor = not isBusy
    for _, button in ipairs(quickActionButtons) do
        button.Active = not isBusy
        button.AutoButtonColor = not isBusy
        button.BackgroundColor3 = isBusy and THEME.button_bg_pressed or THEME.chip_bg
    end
    if isBusy then
        statusLabel.Text = TEXT.sending
        statusDot.BackgroundColor3 = THEME.sending
    elseif statusLabel.Text == TEXT.sending or statusLabel.Text == TEXT.busy then
        statusLabel.Text = TEXT.ready
        statusDot.BackgroundColor3 = THEME.ready
    end
end

local function buildRequestUrl(message)
    local url = CHAT_ENDPOINT .. urlEncode(message)
    if forceWebSearch then
        url = url .. "&web=1"
    end
    return url
end

local function applyWindowState(shouldRerender)
    updateReopenButtonPosition()

    if hidden then
        frame.Visible = false
        reopenButton.Visible = true
        return
    end

    local position, size = getWindowRect()
    frame.Visible = true
    reopenButton.Visible = false
    frame.Position = UDim2.fromOffset(position.X, position.Y)
    frame.Size = UDim2.fromOffset(size.X, size.Y)
    body.Visible = not minimized
    resizeHandle.Visible = not minimized and not maximized
    minimizeButton.Text = minimized and "+" or "_"
    maximizeButton.Text = maximized and "<>" or "[]"
    if shouldRerender then
        renderMessages(false)
    end
end

local function hideWindow()
    hidden = true
    applyWindowState(false)
end

local function showWindow()
    hidden = false
    applyWindowState(true)
    inputBox:CaptureFocus()
end

local function toggleMinimize()
    minimized = not minimized
    if minimized then
        maximized = false
    end
    applyWindowState(true)
end

local function toggleMaximize()
    if maximized then
        maximized = false
        if restoreState then
            windowPosition = restoreState.position
            windowSize = restoreState.size
        end
    else
        restoreState = {
            position = windowPosition,
            size = Vector2.new(windowSize.X, windowSize.Y),
        }
        maximized = true
        minimized = false
    end
    applyWindowState(true)
end

local function sendMessage()
    if isBusy then
        statusLabel.Text = TEXT.busy
        statusDot.BackgroundColor3 = THEME.sending
        return
    end

    local message = trim(inputBox.Text or "")
    if message == "" then
        statusLabel.Text = TEXT.request_error
        statusDot.BackgroundColor3 = THEME.error
        pushMessage("assistant", TEXT.empty_message, false)
        return
    end

    local requestUrl = buildRequestUrl(message)
    inputBox.Text = ""
    pushMessage("user", message, false)
    local pendingIndex = pushMessage("assistant", TEXT.thinking, true)
    isBusy = true
    setBusy(true)

    task.spawn(function()
        local ok, result = pcall(function()
            return game:HttpGet(requestUrl)
        end)

        if not ok then
            statusLabel.Text = TEXT.request_error
            statusDot.BackgroundColor3 = THEME.error
            updateMessage(pendingIndex, TEXT.bridge_error .. "\n\n" .. TEXT.bridge_error_prefix .. tostring(result), false)
            isBusy = false
            setBusy(false)
            if not hidden and not minimized then
                task.defer(function()
                    inputBox:CaptureFocus()
                end)
            end
            return
        end

        updateMessage(pendingIndex, result ~= "" and result or TEXT.bridge_error, false)
        statusLabel.Text = TEXT.received
        statusDot.BackgroundColor3 = THEME.ready
        isBusy = false
        setBusy(false)
        if not hidden and not minimized then
            task.defer(function()
                inputBox:CaptureFocus()
            end)
        end
    end)
end

local viewport = getViewportSize()
windowPosition = Vector2.new(
    math.floor((viewport.X - windowSize.X) * 0.5),
    math.floor((viewport.Y - windowSize.Y) * 0.5)
)
updateModeBadge()
resetChat()
applyWindowState(true)

topBar.InputBegan:Connect(function(input)
    if hidden or maximized then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local controlsStartX = topBar.AbsolutePosition.X + topBar.AbsoluteSize.X - topButtons.AbsoluteSize.X - 20
        if input.Position.X >= controlsStartX then
            return
        end
        dragInput = input
        dragStart = input.Position
        dragStartPosition = frame.AbsolutePosition

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragInput = nil
                dragStart = nil
                dragStartPosition = nil
            end
        end)
    end
end)

resizeHandle.InputBegan:Connect(function(input)
    if hidden or minimized or maximized then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizeInput = input
        resizeStart = input.Position
        resizeStartSize = Vector2.new(windowSize.X, windowSize.Y)

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizeInput = nil
                resizeStart = nil
                resizeStartSize = nil
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragInput and dragStart and dragStartPosition and input == dragInput then
        local delta = input.Position - dragStart
        windowPosition = Vector2.new(dragStartPosition.X + delta.X, dragStartPosition.Y + delta.Y)
        applyWindowState(false)
        return
    end

    if resizeInput and resizeStart and resizeStartSize and input == resizeInput then
        local viewportSize = getViewportSize()
        local framePos = frame.AbsolutePosition
        local maxWidth = math.max(MIN_WINDOW_SIZE.X, viewportSize.X - framePos.X - SCREEN_MARGIN)
        local maxHeight = math.max(MIN_WINDOW_SIZE.Y, viewportSize.Y - framePos.Y - SCREEN_MARGIN)
        local delta = input.Position - resizeStart
        windowSize = Vector2.new(
            clamp(resizeStartSize.X + delta.X, MIN_WINDOW_SIZE.X, maxWidth),
            clamp(resizeStartSize.Y + delta.Y, MIN_WINDOW_SIZE.Y, maxHeight)
        )
        applyWindowState(true)
    end
end)

closeButton.MouseButton1Click:Connect(hideWindow)
reopenButton.MouseButton1Click:Connect(showWindow)
minimizeButton.MouseButton1Click:Connect(toggleMinimize)
maximizeButton.MouseButton1Click:Connect(toggleMaximize)

sendButton.MouseButton1Click:Connect(sendMessage)
clearButton.MouseButton1Click:Connect(function()
    statusLabel.Text = TEXT.ready
    statusDot.BackgroundColor3 = THEME.ready
    resetChat()
end)
webToggleButton.MouseButton1Click:Connect(function()
    forceWebSearch = not forceWebSearch
    updateModeBadge()
end)

inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        sendMessage()
    end
end)

messagesScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    task.defer(function()
        renderMessages(false)
    end)
end)

local cameraViewportConnection

local function bindCamera(camera)
    if cameraViewportConnection then
        cameraViewportConnection:Disconnect()
        cameraViewportConnection = nil
    end
    if camera then
        cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            applyWindowState(true)
        end)
    end
end

bindCamera(workspace.CurrentCamera)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    bindCamera(workspace.CurrentCamera)
    task.defer(function()
        applyWindowState(true)
    end)
end)
