local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local API_BASE_URL = "https://roblox-ukrainian-ai.onrender.com"
local CHAT_ENDPOINT = API_BASE_URL .. "/chat_text?message="

local TOPBAR_HEIGHT = 42
local MIN_WINDOW_SIZE = Vector2.new(380, 250)
local DEFAULT_WINDOW_SIZE = Vector2.new(520, 360)
local REOPEN_BUTTON_SIZE = Vector2.new(66, 34)

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

local TEXT = {
    title = decodeUnicodeEscapes("\\u041e\\u043d\\u043b\\u0430\\u0439\\u043d AI \\u043f\\u043e\\u043c\\u0456\\u0447\\u043d\\u0438\\u043a"),
    placeholder = decodeUnicodeEscapes("\\u041d\\u0430\\u043f\\u0438\\u0448\\u0456\\u0442\\u044c \\u0437\\u0430\\u043f\\u0438\\u0442 \\u0443\\u043a\\u0440\\u0430\\u0457\\u043d\\u0441\\u044c\\u043a\\u043e\\u044e..."),
    send = decodeUnicodeEscapes("\\u041d\\u0430\\u0434\\u0456\\u0441\\u043b\\u0430\\u0442\\u0438"),
    ready = decodeUnicodeEscapes("\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441: \\u0433\\u043e\\u0442\\u043e\\u0432\\u043e"),
    sending = decodeUnicodeEscapes("\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441: \\u0437\\u0430\\u043f\\u0438\\u0442 \\u0432\\u0456\\u0434\\u043f\\u0440\\u0430\\u0432\\u043b\\u0435\\u043d\\u043e"),
    received = decodeUnicodeEscapes("\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441: \\u0432\\u0456\\u0434\\u043f\\u043e\\u0432\\u0456\\u0434\\u044c \\u043e\\u0442\\u0440\\u0438\\u043c\\u0430\\u043d\\u043e"),
    request_error = decodeUnicodeEscapes("\\u0421\\u0442\\u0430\\u0442\\u0443\\u0441: \\u043f\\u043e\\u043c\\u0438\\u043b\\u043a\\u0430 \\u0437\\u0430\\u043f\\u0438\\u0442\\u0443"),
    initial_response = decodeUnicodeEscapes("\\u0422\\u0443\\u0442 \\u0437'\\u044f\\u0432\\u0438\\u0442\\u044c\\u0441\\u044f \\u0432\\u0456\\u0434\\u043f\\u043e\\u0432\\u0456\\u0434\\u044c \\u0432\\u0456\\u0434 \\u043e\\u043d\\u043b\\u0430\\u0439\\u043d API."),
    empty_message = decodeUnicodeEscapes("\\u0412\\u0432\\u0435\\u0434\\u0456\\u0442\\u044c \\u043f\\u043e\\u0432\\u0456\\u0434\\u043e\\u043c\\u043b\\u0435\\u043d\\u043d\\u044f \\u043f\\u0435\\u0440\\u0435\\u0434 \\u0432\\u0456\\u0434\\u043f\\u0440\\u0430\\u0432\\u043a\\u043e\\u044e."),
    bridge_error = decodeUnicodeEscapes("\\u041d\\u0435 \\u0432\\u0434\\u0430\\u043b\\u043e\\u0441\\u044f \\u043e\\u0442\\u0440\\u0438\\u043c\\u0430\\u0442\\u0438 \\u0432\\u0456\\u0434\\u043f\\u043e\\u0432\\u0456\\u0434\\u044c \\u0432\\u0456\\u0434 \\u043e\\u043d\\u043b\\u0430\\u0439\\u043d API."),
    bridge_error_prefix = decodeUnicodeEscapes("\\u0414\\u0435\\u0442\\u0430\\u043b\\u0456 \\u043f\\u043e\\u043c\\u0438\\u043b\\u043a\\u0438: "),
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
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 14)
frameCorner.Parent = frame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(75, 160, 255)
frameStroke.Thickness = 1.5
frameStroke.Parent = frame

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT)
topBar.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
topBar.BorderSizePixel = 0
topBar.Active = true
topBar.Parent = frame

local topBarCorner = Instance.new("UICorner")
topBarCorner.CornerRadius = UDim.new(0, 14)
topBarCorner.Parent = topBar

local topBarMask = Instance.new("Frame")
topBarMask.Size = UDim2.new(1, 0, 0, 14)
topBarMask.Position = UDim2.new(0, 0, 1, -14)
topBarMask.BackgroundColor3 = topBar.BackgroundColor3
topBarMask.BorderSizePixel = 0
topBarMask.Parent = topBar

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -132, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = TEXT.title
title.TextColor3 = Color3.fromRGB(240, 244, 255)
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local controlsFrame = Instance.new("Frame")
controlsFrame.Name = "ControlsFrame"
controlsFrame.AnchorPoint = Vector2.new(1, 0.5)
controlsFrame.Position = UDim2.new(1, -10, 0.5, 0)
controlsFrame.Size = UDim2.new(0, 110, 0, 26)
controlsFrame.BackgroundTransparency = 1
controlsFrame.Parent = topBar

local controlsLayout = Instance.new("UIListLayout")
controlsLayout.FillDirection = Enum.FillDirection.Horizontal
controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
controlsLayout.Padding = UDim.new(0, 6)
controlsLayout.Parent = controlsFrame

local function createTitleButton(name, text, width, bgColor)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, width, 1, 0)
    button.AutoButtonColor = true
    button.BackgroundColor3 = bgColor
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 15
    button.Parent = controlsFrame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = button

    return button
end

local minimizeButton = createTitleButton("MinimizeButton", "_", 32, Color3.fromRGB(56, 62, 75))
local closeButton = createTitleButton("CloseButton", "X", 32, Color3.fromRGB(185, 73, 73))

local bodyFrame = Instance.new("Frame")
bodyFrame.Name = "BodyFrame"
bodyFrame.Position = UDim2.new(0, 0, 0, TOPBAR_HEIGHT)
bodyFrame.Size = UDim2.new(1, 0, 1, -TOPBAR_HEIGHT)
bodyFrame.BackgroundTransparency = 1
bodyFrame.Parent = frame

local bodyPadding = Instance.new("UIPadding")
bodyPadding.PaddingTop = UDim.new(0, 12)
bodyPadding.PaddingBottom = UDim.new(0, 12)
bodyPadding.PaddingLeft = UDim.new(0, 12)
bodyPadding.PaddingRight = UDim.new(0, 12)
bodyPadding.Parent = bodyFrame

local inputBox = Instance.new("TextBox")
inputBox.Name = "InputBox"
inputBox.Size = UDim2.new(1, 0, 0, 46)
inputBox.Position = UDim2.new(0, 0, 0, 0)
inputBox.BackgroundColor3 = Color3.fromRGB(39, 44, 54)
inputBox.ClearTextOnFocus = false
inputBox.Font = Enum.Font.Code
inputBox.PlaceholderText = TEXT.placeholder
inputBox.Text = ""
inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
inputBox.PlaceholderColor3 = Color3.fromRGB(150, 156, 170)
inputBox.TextSize = 18
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.Parent = bodyFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 10)
inputCorner.Parent = inputBox

local inputPadding = Instance.new("UIPadding")
inputPadding.PaddingLeft = UDim.new(0, 10)
inputPadding.PaddingRight = UDim.new(0, 10)
inputPadding.Parent = inputBox

local actionRow = Instance.new("Frame")
actionRow.Name = "ActionRow"
actionRow.Size = UDim2.new(1, 0, 0, 40)
actionRow.Position = UDim2.new(0, 0, 0, 58)
actionRow.BackgroundTransparency = 1
actionRow.Parent = bodyFrame

local sendButton = Instance.new("TextButton")
sendButton.Name = "SendButton"
sendButton.AnchorPoint = Vector2.new(1, 0)
sendButton.Position = UDim2.new(1, 0, 0, 0)
sendButton.Size = UDim2.new(0, 112, 1, 0)
sendButton.BackgroundColor3 = Color3.fromRGB(75, 160, 255)
sendButton.BorderSizePixel = 0
sendButton.Font = Enum.Font.GothamBold
sendButton.Text = TEXT.send
sendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sendButton.TextSize = 18
sendButton.Parent = actionRow

local sendButtonCorner = Instance.new("UICorner")
sendButtonCorner.CornerRadius = UDim.new(0, 10)
sendButtonCorner.Parent = sendButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -126, 1, 0)
statusLabel.Position = UDim2.new(0, 0, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = TEXT.ready
statusLabel.TextColor3 = Color3.fromRGB(165, 196, 255)
statusLabel.TextSize = 15
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = actionRow

local responseScroll = Instance.new("ScrollingFrame")
responseScroll.Name = "ResponseScroll"
responseScroll.Position = UDim2.new(0, 0, 0, 110)
responseScroll.Size = UDim2.new(1, 0, 1, -110)
responseScroll.BackgroundColor3 = Color3.fromRGB(32, 36, 45)
responseScroll.BorderSizePixel = 0
responseScroll.Active = true
responseScroll.ScrollBarThickness = 6
responseScroll.ScrollingDirection = Enum.ScrollingDirection.Y
responseScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
responseScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
responseScroll.Parent = bodyFrame

local responseCorner = Instance.new("UICorner")
responseCorner.CornerRadius = UDim.new(0, 10)
responseCorner.Parent = responseScroll

local responsePadding = Instance.new("UIPadding")
responsePadding.PaddingTop = UDim.new(0, 10)
responsePadding.PaddingBottom = UDim.new(0, 10)
responsePadding.PaddingLeft = UDim.new(0, 10)
responsePadding.PaddingRight = UDim.new(0, 10)
responsePadding.Parent = responseScroll

local responseText = Instance.new("TextLabel")
responseText.Name = "ResponseText"
responseText.Size = UDim2.new(1, -6, 0, 0)
responseText.AutomaticSize = Enum.AutomaticSize.Y
responseText.BackgroundTransparency = 1
responseText.Font = Enum.Font.Code
responseText.Text = TEXT.initial_response
responseText.TextColor3 = Color3.fromRGB(232, 236, 246)
responseText.TextSize = 16
responseText.TextWrapped = true
responseText.TextXAlignment = Enum.TextXAlignment.Left
responseText.TextYAlignment = Enum.TextYAlignment.Top
responseText.Parent = responseScroll

local resizeHandle = Instance.new("TextButton")
resizeHandle.Name = "ResizeHandle"
resizeHandle.AnchorPoint = Vector2.new(1, 1)
resizeHandle.Position = UDim2.new(1, -8, 1, -8)
resizeHandle.Size = UDim2.new(0, 18, 0, 18)
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
local minimized = false
local hidden = false
local dragInput = nil
local dragStart = nil
local dragStartPosition = nil
local resizeInput = nil
local resizeStart = nil
local resizeStartSize = nil

local function updateReopenButtonPosition()
    local viewport = getViewportSize()
    reopenButton.Position = UDim2.fromOffset(
        viewport.X - REOPEN_BUTTON_SIZE.X - 16,
        viewport.Y - REOPEN_BUTTON_SIZE.Y - 18
    )
end

local function getFrameHeight()
    if minimized then
        return TOPBAR_HEIGHT
    end
    return windowSize.Y
end

local function clampFramePosition(targetX, targetY)
    local viewport = getViewportSize()
    local width = frame.AbsoluteSize.X > 0 and frame.AbsoluteSize.X or windowSize.X
    local height = frame.AbsoluteSize.Y > 0 and frame.AbsoluteSize.Y or getFrameHeight()
    local maxX = math.max(8, viewport.X - width - 8)
    local maxY = math.max(8, viewport.Y - height - 8)
    return clamp(targetX, 8, maxX), clamp(targetY, 8, maxY)
end

local function applyWindowSize()
    local width = windowSize.X
    local height = minimized and TOPBAR_HEIGHT or windowSize.Y
    frame.Size = UDim2.fromOffset(width, height)
    bodyFrame.Visible = not minimized
    resizeHandle.Visible = not minimized
    minimizeButton.Text = minimized and "+" or "_"

    local currentPos = frame.AbsolutePosition
    local clampedX, clampedY = clampFramePosition(currentPos.X, currentPos.Y)
    frame.Position = UDim2.fromOffset(clampedX, clampedY)
end

local function setResponse(text)
    responseText.Text = text
    responseScroll.CanvasPosition = Vector2.new(0, 0)
end

local function setBusy(isBusy)
    sendButton.Active = not isBusy
    sendButton.AutoButtonColor = not isBusy
    sendButton.Text = isBusy and "..." or TEXT.send
    statusLabel.Text = isBusy and TEXT.sending or TEXT.ready
end

local function hideWindow()
    hidden = true
    frame.Visible = false
    reopenButton.Visible = true
end

local function showWindow()
    hidden = false
    frame.Visible = true
    reopenButton.Visible = false
    applyWindowSize()
end

local function sendMessage()
    local message = inputBox.Text or ""
    if message:gsub("%s+", "") == "" then
        setResponse(TEXT.empty_message)
        return
    end

    setBusy(true)

    local ok, result = pcall(function()
        return game:HttpGet(CHAT_ENDPOINT .. urlEncode(message))
    end)

    if not ok then
        setBusy(false)
        statusLabel.Text = TEXT.request_error
        setResponse(TEXT.bridge_error .. "\n\n" .. TEXT.bridge_error_prefix .. tostring(result))
        return
    end

    setResponse(result ~= "" and result or TEXT.bridge_error)
    statusLabel.Text = TEXT.received
    setBusy(false)
end

local viewport = getViewportSize()
frame.Position = UDim2.fromOffset(
    math.floor((viewport.X - windowSize.X) * 0.5),
    math.floor((viewport.Y - windowSize.Y) * 0.5)
)
applyWindowSize()
updateReopenButtonPosition()

topBar.InputBegan:Connect(function(input)
    if hidden then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
        local newX = dragStartPosition.X + delta.X
        local newY = dragStartPosition.Y + delta.Y
        local clampedX, clampedY = clampFramePosition(newX, newY)
        frame.Position = UDim2.fromOffset(clampedX, clampedY)
        return
    end

    if resizeInput and resizeStart and resizeStartSize and input == resizeInput then
        local viewportSize = getViewportSize()
        local framePos = frame.AbsolutePosition
        local maxWidth = math.max(MIN_WINDOW_SIZE.X, viewportSize.X - framePos.X - 8)
        local maxHeight = math.max(MIN_WINDOW_SIZE.Y, viewportSize.Y - framePos.Y - 8)
        local delta = input.Position - resizeStart
        windowSize = Vector2.new(
            clamp(resizeStartSize.X + delta.X, MIN_WINDOW_SIZE.X, maxWidth),
            clamp(resizeStartSize.Y + delta.Y, MIN_WINDOW_SIZE.Y, maxHeight)
        )
        applyWindowSize()
    end
end)

closeButton.MouseButton1Click:Connect(hideWindow)

reopenButton.MouseButton1Click:Connect(function()
    showWindow()
    inputBox:CaptureFocus()
end)

minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    applyWindowSize()
end)

sendButton.MouseButton1Click:Connect(sendMessage)

inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        sendMessage()
    end
end)

local function refreshBounds()
    if hidden then
        updateReopenButtonPosition()
        return
    end

    updateReopenButtonPosition()
    applyWindowSize()
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.defer(refreshBounds)
end)

UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(function()
    task.defer(refreshBounds)
end)
