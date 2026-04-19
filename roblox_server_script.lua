local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_EVENT_NAME = "LocalAIChatBridge"
local LOCAL_ENDPOINT = "http://localhost:5000/chat"
local REQUEST_TIMEOUT = 10

local chatBridge = ReplicatedStorage:FindFirstChild(REMOTE_EVENT_NAME)
if not chatBridge then
    chatBridge = Instance.new("RemoteEvent")
    chatBridge.Name = REMOTE_EVENT_NAME
    chatBridge.Parent = ReplicatedStorage
end

local function sendToClient(player, payload)
    chatBridge:FireClient(player, payload)
end

local function buildError(message)
    return {
        type = "chat_response",
        ok = false,
        error = message,
    }
end

chatBridge.OnServerEvent:Connect(function(player, payload)
    if type(payload) ~= "table" or payload.type ~= "chat_request" then
        return
    end

    local requestId = tostring(payload.id or "")
    local message = tostring(payload.message or ""):sub(1, 1000)
    if message == "" then
        sendToClient(player, {
            type = "chat_response",
            id = requestId,
            ok = false,
            error = "Empty message.",
        })
        return
    end

    local ok, response = pcall(function()
        return HttpService:RequestAsync({
            Url = LOCAL_ENDPOINT,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = HttpService:JSONEncode({
                message = message,
            }),
            Timeout = REQUEST_TIMEOUT,
        })
    end)

    if not ok then
        local errorPayload = buildError("HTTP bridge failed: " .. tostring(response))
        errorPayload.id = requestId
        sendToClient(player, errorPayload)
        return
    end

    if not response.Success then
        sendToClient(player, {
            type = "chat_response",
            id = requestId,
            ok = false,
            error = ("Status %s: %s"):format(tostring(response.StatusCode), tostring(response.Body)),
        })
        return
    end

    local decodedOk, decoded = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)

    if not decodedOk or type(decoded) ~= "table" then
        sendToClient(player, {
            type = "chat_response",
            id = requestId,
            ok = false,
            error = "Invalid JSON from local server.",
        })
        return
    end

    sendToClient(player, {
        type = "chat_response",
        id = requestId,
        ok = true,
        response = tostring(decoded.response or ""),
    })
end)
