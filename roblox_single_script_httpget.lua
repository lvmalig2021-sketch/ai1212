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
frame.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 16)
frameCorner.Parent = frame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(73, 152, 255)
frameStroke.Thickness = 1.4
frameStroke.Parent = frame

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT)
topBar.Active = true
topBar.BackgroundColor3 = Color3.fromRGB(18, 21, 27)
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

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Position = UDim2.fromOffset(14, 4)
titleLabel.Size = UDim2.new(1, -180, 0, 20)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = TEXT.title
titleLabel.TextColor3 = Color3.fromRGB(244, 247, 255)
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
subtitleLabel.TextColor3 = Color3.fromRGB(132, 142, 160)
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
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    button.Parent = topButtons

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    return button
end

local minimizeButton = createTopButton("MinimizeButton", "_", Color3.fromRGB(55, 61, 74))
local maximizeButton = createTopButton("MaximizeButton", "[]", Color3.fromRGB(55, 61, 74))
local closeButton = createTopButton("CloseButton", "X", Color3.fromRGB(186, 72, 72))

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
statusDot.BackgroundColor3 = Color3.fromRGB(78, 201, 126)
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
statusLabel.TextColor3 = Color3.fromRGB(166, 196, 255)
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = statusBar

local modeBadge = Instance.new("TextLabel")
modeBadge.Name = "ModeBadge"
modeBadge.AnchorPoint = Vector2.new(1, 0.5)
modeBadge.Position = UDim2.new(1, 0, 0.5, 0)
modeBadge.Size = UDim2.fromOffset(96, 24)
modeBadge.BackgroundColor3 = Color3.fromRGB(36, 44, 58)
modeBadge.BorderSizePixel = 0
modeBadge.Font = Enum.Font.GothamBold
modeBadge.Text = TEXT.web_off
modeBadge.TextColor3 = Color3.fromRGB(208, 216, 232)
modeBadge.TextSize = 13
modeBadge.Parent = statusBar

local modeBadgeCorner = Instance.new("UICorner")
modeBadgeCorner.CornerRadius = UDim.new(0, 9)
modeBadgeCorner.Parent = modeBadge

local messagesScroll = Instance.new("ScrollingFrame")
messagesScroll.Name = "MessagesScroll"
messagesScroll.Position = UDim2.fromOffset(0, 30)
messagesScroll.Size = UDim2.new(1, 0, 1, -104)
messagesScroll.Active = true
messagesScroll.BackgroundColor3 = Color3.fromRGB(29, 33, 41)
messagesScroll.BorderSizePixel = 0
messagesScroll.ScrollBarThickness = 6
messagesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
messagesScroll.ScrollingDirection = Enum.ScrollingDirection.Y
messagesScroll.Parent = body

local messagesCorner = Instance.new("UICorner")
messagesCorner.CornerRadius = UDim.new(0, 14)
messagesCorner.Parent = messagesScroll

local messagesStroke = Instance.new("UIStroke")
messagesStroke.Color = Color3.fromRGB(42, 50, 65)
messagesStroke.Thickness = 1
messagesStroke.Parent = messagesScroll

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
composer.Size = UDim2.new(1, 0, 0, 62)
composer.BackgroundColor3 = Color3.fromRGB(25, 30, 38)
composer.BorderSizePixel = 0
composer.Parent = body

local composerCorner = Instance.new("UICorner")
composerCorner.CornerRadius = UDim.new(0, 14)
composerCorner.Parent = composer

local composerStroke = Instance.new("UIStroke")
composerStroke.Color = Color3.fromRGB(46, 53, 68)
composerStroke.Thickness = 1
composerStroke.Parent = composer

local clearButton = Instance.new("TextButton")
clearButton.Name = "ClearButton"
clearButton.Position = UDim2.fromOffset(10, 10)
clearButton.Size = UDim2.fromOffset(60, 42)
clearButton.BackgroundColor3 = Color3.fromRGB(50, 58, 73)
clearButton.BorderSizePixel = 0
clearButton.Font = Enum.Font.GothamBold
clearButton.Text = TEXT.clear
clearButton.TextColor3 = Color3.fromRGB(240, 244, 255)
clearButton.TextSize = 14
clearButton.Parent = composer

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 10)
clearCorner.Parent = clearButton

local webToggleButton = Instance.new("TextButton")
webToggleButton.Name = "WebToggleButton"
webToggleButton.Position = UDim2.fromOffset(76, 10)
webToggleButton.Size = UDim2.fromOffset(60, 42)
webToggleButton.BackgroundColor3 = Color3.fromRGB(46, 58, 78)
webToggleButton.BorderSizePixel = 0
webToggleButton.Font = Enum.Font.GothamBold
webToggleButton.Text = TEXT.web
webToggleButton.TextColor3 = Color3.fromRGB(240, 244, 255)
webToggleButton.TextSize = 14
webToggleButton.Parent = composer

local webCorner = Instance.new("UICorner")
webCorner.CornerRadius = UDim.new(0, 10)
webCorner.Parent = webToggleButton

local sendButton = Instance.new("TextButton")
sendButton.Name = "SendButton"
sendButton.AnchorPoint = Vector2.new(1, 0)
sendButton.Position = UDim2.new(1, -10, 0, 10)
sendButton.Size = UDim2.fromOffset(100, 42)
sendButton.BackgroundColor3 = Color3.fromRGB(75, 160, 255)
sendButton.BorderSizePixel = 0
sendButton.Font = Enum.Font.GothamBold
sendButton.Text = TEXT.send
sendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sendButton.TextSize = 15
sendButton.Parent = composer

local sendCorner = Instance.new("UICorner")
sendCorner.CornerRadius = UDim.new(0, 10)
sendCorner.Parent = sendButton

local inputBox = Instance.new("TextBox")
inputBox.Name = "InputBox"
inputBox.Position = UDim2.fromOffset(142, 10)
inputBox.Size = UDim2.new(1, -252, 0, 42)
inputBox.BackgroundColor3 = Color3.fromRGB(35, 41, 52)
inputBox.BorderSizePixel = 0
inputBox.ClearTextOnFocus = false
inputBox.Font = Enum.Font.Code
inputBox.PlaceholderText = TEXT.placeholder
inputBox.Text = ""
inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
inputBox.PlaceholderColor3 = Color3.fromRGB(145, 153, 168)
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

local resizeHandle = Instance.new("TextButton")
resizeHandle.Name = "ResizeHandle"
resizeHandle.AnchorPoint = Vector2.new(1, 1)
resizeHandle.Position = UDim2.new(1, -8, 1, -8)
resizeHandle.Size = UDim2.fromOffset(18, 18)
resizeHandle.Active = true
resizeHandle.BackgroundColor3 = Color3.fromRGB(48, 54, 66)
resizeHandle.BorderSizePixel = 0
resizeHandle.Font = Enum.Font.Code
resizeHandle.Text = "//"
resizeHandle.TextColor3 = Color3.fromRGB(170, 176, 190)
resizeHandle.TextSize = 12
resizeHandle.Parent = frame

local resizeCorner = Instance.new("UICorner")
resizeCorner.CornerRadius = UDim.new(0, 5)
resizeCorner.Parent = resizeHandle

local reopenButton = Instance.new("TextButton")
reopenButton.Name = "ReopenButton"
reopenButton.Visible = false
reopenButton.Size = UDim2.fromOffset(REOPEN_BUTTON_SIZE.X, REOPEN_BUTTON_SIZE.Y)
reopenButton.BackgroundColor3 = Color3.fromRGB(75, 160, 255)
reopenButton.BorderSizePixel = 0
reopenButton.Font = Enum.Font.GothamBold
reopenButton.Text = TEXT.reopen
reopenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
reopenButton.TextSize = 18
reopenButton.Parent = screenGui

local reopenCorner = Instance.new("UICorner")
reopenCorner.CornerRadius = UDim.new(0, 10)
reopenCorner.Parent = reopenButton

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

local function getTimeStamp()
    local ok, stamp = pcall(function()
        return os.date("%H:%M")
    end)
    if ok and type(stamp) == "string" then
        return stamp
    end
    return ""
end

local function updateModeBadge()
    modeBadge.Text = forceWebSearch and TEXT.web_on or TEXT.web_off
    modeBadge.BackgroundColor3 = forceWebSearch and Color3.fromRGB(38, 78, 60) or Color3.fromRGB(36, 44, 58)
    webToggleButton.BackgroundColor3 = forceWebSearch and Color3.fromRGB(48, 115, 82) or Color3.fromRGB(46, 58, 78)
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
            and Color3.fromRGB(62, 110, 186)
            or Color3.fromRGB(42, 47, 57)
        local senderColor = message.role == "user"
            and Color3.fromRGB(221, 234, 255)
            or Color3.fromRGB(165, 196, 255)
        local messageColor = message.pending
            and Color3.fromRGB(190, 200, 214)
            or Color3.fromRGB(236, 240, 248)
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
    sendButton.BackgroundColor3 = isBusy and Color3.fromRGB(92, 114, 145) or Color3.fromRGB(75, 160, 255)
    sendButton.Active = not isBusy
    sendButton.AutoButtonColor = not isBusy
    sendButton.Text = isBusy and "..." or TEXT.send
    clearButton.BackgroundColor3 = isBusy and Color3.fromRGB(40, 46, 57) or Color3.fromRGB(50, 58, 73)
    clearButton.Active = not isBusy
    clearButton.AutoButtonColor = not isBusy
    webToggleButton.Active = not isBusy
    webToggleButton.AutoButtonColor = not isBusy
    if isBusy then
        statusLabel.Text = TEXT.sending
        statusDot.BackgroundColor3 = Color3.fromRGB(255, 195, 84)
    elseif statusLabel.Text == TEXT.sending or statusLabel.Text == TEXT.busy then
        statusLabel.Text = TEXT.ready
        statusDot.BackgroundColor3 = Color3.fromRGB(78, 201, 126)
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
        statusDot.BackgroundColor3 = Color3.fromRGB(255, 195, 84)
        return
    end

    local message = trim(inputBox.Text or "")
    if message == "" then
        statusLabel.Text = TEXT.request_error
        statusDot.BackgroundColor3 = Color3.fromRGB(227, 101, 101)
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
            statusDot.BackgroundColor3 = Color3.fromRGB(227, 101, 101)
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
        statusDot.BackgroundColor3 = Color3.fromRGB(78, 201, 126)
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
    statusDot.BackgroundColor3 = Color3.fromRGB(78, 201, 126)
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
