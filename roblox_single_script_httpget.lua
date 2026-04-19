local Players = game:GetService("Players")

local API_BASE_URL = "https://roblox-ukrainian-ai.onrender.com"
local CHAT_ENDPOINT = API_BASE_URL .. "/chat_text?message="

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
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OnlineAIChatGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 480, 0, 300)
frame.Position = UDim2.new(0.5, -240, 0.5, -150)
frame.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(75, 160, 255)
stroke.Thickness = 1.5
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -24, 0, 30)
title.Position = UDim2.new(0, 12, 0, 12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = TEXT.title
title.TextColor3 = Color3.fromRGB(240, 244, 255)
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local inputBox = Instance.new("TextBox")
inputBox.Name = "InputBox"
inputBox.Size = UDim2.new(1, -24, 0, 46)
inputBox.Position = UDim2.new(0, 12, 0, 54)
inputBox.BackgroundColor3 = Color3.fromRGB(39, 44, 54)
inputBox.ClearTextOnFocus = false
inputBox.Font = Enum.Font.Code
inputBox.PlaceholderText = TEXT.placeholder
inputBox.Text = ""
inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
inputBox.PlaceholderColor3 = Color3.fromRGB(150, 156, 170)
inputBox.TextSize = 18
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.Parent = frame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 10)
inputCorner.Parent = inputBox

local sendButton = Instance.new("TextButton")
sendButton.Name = "SendButton"
sendButton.Size = UDim2.new(0, 110, 0, 40)
sendButton.Position = UDim2.new(1, -122, 0, 112)
sendButton.BackgroundColor3 = Color3.fromRGB(75, 160, 255)
sendButton.Font = Enum.Font.GothamBold
sendButton.Text = TEXT.send
sendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sendButton.TextSize = 18
sendButton.Parent = frame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 10)
buttonCorner.Parent = sendButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -146, 0, 24)
statusLabel.Position = UDim2.new(0, 12, 0, 120)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = TEXT.ready
statusLabel.TextColor3 = Color3.fromRGB(165, 196, 255)
statusLabel.TextSize = 15
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

local responseLabel = Instance.new("TextLabel")
responseLabel.Name = "ResponseLabel"
responseLabel.Size = UDim2.new(1, -24, 0, 126)
responseLabel.Position = UDim2.new(0, 12, 0, 160)
responseLabel.BackgroundColor3 = Color3.fromRGB(32, 36, 45)
responseLabel.Font = Enum.Font.Code
responseLabel.Text = TEXT.initial_response
responseLabel.TextColor3 = Color3.fromRGB(232, 236, 246)
responseLabel.TextSize = 16
responseLabel.TextWrapped = true
responseLabel.TextXAlignment = Enum.TextXAlignment.Left
responseLabel.TextYAlignment = Enum.TextYAlignment.Top
responseLabel.Parent = frame

local responseCorner = Instance.new("UICorner")
responseCorner.CornerRadius = UDim.new(0, 10)
responseCorner.Parent = responseLabel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = responseLabel

local function setBusy(isBusy)
    sendButton.Active = not isBusy
    sendButton.AutoButtonColor = not isBusy
    sendButton.Text = isBusy and "..." or TEXT.send
    statusLabel.Text = isBusy and TEXT.sending or TEXT.ready
end

local function setResponse(text)
    responseLabel.Text = text
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

sendButton.MouseButton1Click:Connect(sendMessage)

inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        sendMessage()
    end
end)
