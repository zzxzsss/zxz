-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- Configuration
local Player = Players.LocalPlayer


local ZlexConfig = loadstring(game:HttpGet("https://pandadevelopment.net/virtual/file/cb9abaea16cbea7c"))()

-- Get settings from module
local Identifier = ZlexConfig:GetIdentifier()
local DISCORD_INVITE = ZlexConfig.DISCORD_INVITE
local ACCENT_COLOR = ZlexConfig.ACCENT_COLOR
local DARK_BG = ZlexConfig.DARK_BG
local SECONDARY_BG = ZlexConfig.SECONDARY_BG

-- Hardware ID (HWID)
local function getHWID()
    if gethwid then
        return tostring(gethwid())
    elseif get_hwid then
        return tostring(get_hwid())
    elseif HWID then
        return tostring(HWID)
    else
        return tostring(Player.UserId)
    end
end

local UserID_HWID = getHWID()

-- UI Variables
local screenGui, mainFrame, keyInput, statusLabel

-- Update status label
local function updateStatus(text, color)
    if statusLabel then
        statusLabel.Text = text
        statusLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    end
end

-- HTTP Request Handler (supports multiple executors)
local function httpRequest(options)
    local request = syn and syn.request or http and http.request or http_request or (request ~= nil and request) or httprequest or (fluxus and fluxus.request)

    if request then
        return request(options)
    end

    local success, response = pcall(function()
        return HttpService:RequestAsync(options)
    end)

    if success then
        return response
    end

    return nil
end

-- Copy to clipboard
local function copyToClipboard(text)
    if setclipboard then
        setclipboard(text)
        return true
    elseif toclipboard then
        toclipboard(text)
        return true
    end
    return false
end

-- Key log webhook
local KEY_LOG_WEBHOOK = "https://discord.com/api/webhooks/1452334222164361226/VpkFVrPxhTfBp4jaV87QjgLp2EFAPYARPehLOTlZ8pQxNoIXh61YBopv0Xn9Wj941QtO"

local function logKeyAttempt(key, isValid, reason)
    pcall(function()
        local gameName = "Unknown"
        local currentGame = ZlexConfig:GetCurrentGame()
        if currentGame then
            gameName = currentGame.name
        end

        local embedColor = isValid and 3066993 or 15158332
        local statusText = isValid and "Valid Key" or "Invalid Key"

        local payload = {
            embeds = {{
                title = "Key Log - Zlex Hub",
                color = embedColor,
                fields = {
                    {name = "Status", value = statusText, inline = true},
                    {name = "Key Used", value = "||" .. tostring(key) .. "||", inline = true},
                    {name = "Game", value = gameName, inline = true},
                    {name = "Player", value = Player.Name .. " (" .. tostring(Player.UserId) .. ")", inline = true},
                    {name = "HWID", value = "||" .. UserID_HWID .. "||", inline = true},
                    {name = "Reason", value = tostring(reason), inline = false}
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }

        httpRequest({
            Url = KEY_LOG_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

-- Validate Key using Panda Development V2 endpoint
function ValidateKey(key, serviceId, hwid)
    if not HttpService then
        warn("[Zlex Hub] HttpService not available.")
        return false, "HttpService not available"
    end

    local validationUrl = "https://pandadevelopment.net/v2_validation?key=" .. tostring(key) .. "&service=" .. tostring(serviceId) .. "&hwid=" .. tostring(hwid)

    local success, response = pcall(function()
        return httpRequest({
            Url = validationUrl,
            Method = "GET"
        })
    end)

    if success and response then
        if response.Success or response.StatusCode == 200 then
            local decodeSuccess, jsonData = pcall(function()
                return HttpService:JSONDecode(response.Body)
            end)

            if decodeSuccess and jsonData then
                if jsonData["V2_Authentication"] == "success" then
                    print("[Zlex Hub] Authenticated successfully.")
                    logKeyAttempt(key, true, "Authenticated via Panda API")
                    return true, "Authenticated"
                else
                    local reason = jsonData["reason"] or "Unknown reason"
                    print("[Zlex Hub] Authentication failed. Reason: " .. reason)
                    logKeyAttempt(key, false, "Panda API: " .. reason)
                    return false, "Authentication failed: " .. reason
                end
            else
                warn("[Zlex Hub] Failed to decode JSON response.")
                return false, "JSON decode error"
            end
        else
            warn("[Zlex Hub] HTTP request was not successful. Code: " .. tostring(response.StatusCode))
            return false, "HTTP request failed"
        end
    else
        warn("[Zlex Hub] Request failed. Error: " .. tostring(response))
        return false, "Request error"
    end
end

-- Validate Discord preset key (simple string match - no API call)
function ValidateDiscordKey(inputKey)
    local discordKey = ZlexConfig:GetDiscordKey()
    if inputKey == discordKey then
        print("[Zlex Hub] Discord key validated successfully.")
        logKeyAttempt(inputKey, true, "Discord key matched")
        return true, "Discord key valid"
    else
        print("[Zlex Hub] Invalid Discord key.")
        logKeyAttempt(inputKey, false, "Discord key mismatch")
        return false, "Invalid Discord key"
    end
end

-- ===== HWID WHITELIST & BAN LIST MODULE =====
local HwidManager = {
    Whitelist = {
        ["06972cc0-6633-11ee-8d4c-806e6f6e6963"] = {enabled = true, expiresAt = os.time() + (90 * 24 * 60 * 60), note = "this for memifyx"},
        ["36979f40-f192-11ef-ba6c-806e6f6e6963"] = {enabled = true, expiresAt = os.time() + (90 * 24 * 60 * 60), note = "this is for gu3l_outsideee"},
        ["5b543c75-c51d-11f0-8f60-806e6f6e6963"] = {enabled = true, expiresAt = os.time() + (90 * 24 * 60 * 60), note = "ktro"},
    },
    BanList = {
        -- Format: ["banned_hwid_here"] = "reason for ban"
        -- Add HWIDs here to block them from accessing
    },
    WhitelistEnabled = false,  -- Set to true to enable whitelist mode (only listed HWIDs allowed)
    BanListEnabled = false      -- Set to true to enable ban list checking
}

function HwidManager:IsWhitelisted(hwid)
    if not self.WhitelistEnabled then
        return true  -- Whitelist disabled, allow all
    end
    
    local entry = self.Whitelist[hwid]
    if not entry or not entry.enabled then
        return false
    end
    
    -- Check if whitelist entry has expired
    if entry.expiresAt and os.time() > entry.expiresAt then
        return false  -- Expired
    end
    
    return true
end

function HwidManager:IsPremium(hwid)
    local entry = self.Whitelist[hwid]
    if not entry or not entry.enabled then
        return false
    end
    
    -- Check if whitelist entry has expired
    if entry.expiresAt and os.time() > entry.expiresAt then
        return false  -- Expired
    end
    
    return true
end

function HwidManager:GetPremiumNote(hwid)
    local entry = self.Whitelist[hwid]
    if entry then
        return entry.note or "Premium User"
    end
    return nil
end

function HwidManager:GetWhitelistStatus(hwid)
    local entry = self.Whitelist[hwid]
    if not entry then
        return "not_whitelisted"
    end
    
    if not entry.enabled then
        return "disabled"
    end
    
    if entry.expiresAt and os.time() > entry.expiresAt then
        return "expired"
    end
    
    return "active"
end

function HwidManager:GetExpirationTime(hwid)
    local entry = self.Whitelist[hwid]
    if entry and entry.expiresAt then
        return entry.expiresAt
    end
    return nil
end

function HwidManager:IsBanned(hwid)
    if not self.BanListEnabled then
        return false  -- Ban list disabled
    end
    return self.BanList[hwid] ~= nil
end

function HwidManager:GetBanReason(hwid)
    return self.BanList[hwid] or "No reason provided"
end

function HwidManager:AddToWhitelist(hwid, expirationDays)
    local expiresAt = 9999999999  -- Lifetime by default
    
    if expirationDays and expirationDays > 0 then
        expiresAt = os.time() + (expirationDays * 24 * 60 * 60)
    end
    
    self.Whitelist[hwid] = {enabled = true, expiresAt = expiresAt}
    print("[Zlex Hub] Added HWID to whitelist: " .. hwid .. " | Expires in " .. (expirationDays or "unlimited") .. " days")
    logKeyAttempt(hwid, true, "HWID whitelisted | Expires: " .. os.date("%Y-%m-%d %H:%M:%S", expiresAt))
    
    self:SendWhitelistWebhook(hwid, "added", expiresAt)
end

function HwidManager:RemoveFromWhitelist(hwid)
    self.Whitelist[hwid] = nil
    print("[Zlex Hub] Removed HWID from whitelist: " .. hwid)
    self:SendWhitelistWebhook(hwid, "removed", nil)
end

function HwidManager:SendWhitelistWebhook(hwid, action, expiresAt)
    pcall(function()
        local actionText = action == "added" and "✅ Added to Whitelist" or action == "removed" and "❌ Removed from Whitelist" or "⚠️ Whitelist Updated"
        local expirationText = "Lifetime"
        local embedColor = 3066993
        
        if action == "removed" then
            embedColor = 15158332
        elseif expiresAt and expiresAt < 9999999999 then
            local daysLeft = math.floor((expiresAt - os.time()) / (24 * 60 * 60))
            expirationText = daysLeft > 0 and daysLeft .. " days" or "Expired"
        end
        
        local payload = {
            embeds = {{
                title = "Whitelist Manager - Zlex Hub",
                color = embedColor,
                fields = {
                    {name = "Action", value = actionText, inline = true},
                    {name = "HWID", value = "||" .. hwid .. "||", inline = false},
                    {name = "Expires", value = expirationText, inline = true},
                    {name = "Timestamp", value = os.date("%Y-%m-%d %H:%M:%S"), inline = true},
                },
                footer = { text = "Zlex Hub Whitelist System" }
            }}
        }
        
        httpRequest({
            Url = KEY_LOG_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

function HwidManager:AddToBanList(hwid, reason)
    local banReason = reason or "Unauthorized access"
    self.BanList[hwid] = banReason
    print("[Zlex Hub] Added HWID to ban list: " .. hwid .. " | Reason: " .. banReason)
    logKeyAttempt(hwid, false, "HWID banned - " .. banReason)
end

function HwidManager:RemoveFromBanList(hwid)
    self.BanList[hwid] = nil
    print("[Zlex Hub] Removed HWID from ban list: " .. hwid)
end

function HwidManager:CheckHwid(hwid)
    -- Check if HWID is banned
    if self:IsBanned(hwid) then
        return false, "HWID is banned: " .. self:GetBanReason(hwid)
    end
    
    -- Check if HWID is whitelisted (if whitelist is enabled)
    if self.WhitelistEnabled then
        if not self:IsWhitelisted(hwid) then
            local status = self:GetWhitelistStatus(hwid)
            if status == "expired" then
                return false, "Whitelist access has expired"
            else
                return false, "HWID is not whitelisted"
            end
        end
    end
    
    return true, "HWID check passed"
end

-- Get Key Link using Panda Development endpoint
function GetKeyLink(serviceId, hwid)
    return "https://pandadevelopment.net/getkey?service=" .. tostring(serviceId) .. "&hwid=" .. tostring(hwid)
end

-- Create UI
local function createUI()
    local isDiscordMode = ZlexConfig:IsDiscordMode()

    -- Screen GUI
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ZlexHubKeySystem"
    screenGui.Parent = Player:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Main Background
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "Background"
    mainFrame.Size = UDim2.new(0, 380, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = DARK_BG
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.AutomaticSize = Enum.AutomaticSize.Y
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 16)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = ACCENT_COLOR
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.7
    mainStroke.Parent = mainFrame

    -- Top accent bar
    local accentBar = Instance.new("Frame")
    accentBar.Name = "AccentBar"
    accentBar.Size = UDim2.new(1, 0, 0, 3)
    accentBar.Position = UDim2.new(0, 0, 0, 0)
    accentBar.BackgroundColor3 = ACCENT_COLOR
    accentBar.BorderSizePixel = 0
    accentBar.Parent = mainFrame

    local accentGradient = Instance.new("UIGradient")
    accentGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(139, 48, 48)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 70, 70)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 48, 48))
    })
    accentGradient.Parent = accentBar

    -- Content container
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, 0, 1, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame

    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingTop = UDim.new(0, 20)
    contentPadding.PaddingBottom = UDim.new(0, 20)
    contentPadding.PaddingLeft = UDim.new(0, 20)
    contentPadding.PaddingRight = UDim.new(0, 20)
    contentPadding.Parent = contentFrame

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 12)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = contentFrame

    -- Header
    local headerFrame = Instance.new("Frame")
    headerFrame.Name = "Header"
    headerFrame.Size = UDim2.new(1, 0, 0, 24)
    headerFrame.BackgroundTransparency = 1
    headerFrame.LayoutOrder = 0
    headerFrame.Parent = contentFrame

    local headerLayout = Instance.new("UIListLayout")
    headerLayout.Padding = UDim.new(0, 10)
    headerLayout.FillDirection = Enum.FillDirection.Horizontal
    headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    headerLayout.Parent = headerFrame

    local keyIcon = Instance.new("ImageLabel")
    keyIcon.Size = UDim2.new(0, 20, 0, 20)
    keyIcon.BackgroundTransparency = 1
    keyIcon.Image = "rbxassetid://7072718362"
    keyIcon.ImageColor3 = ACCENT_COLOR
    keyIcon.Parent = headerFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 0, 0, 24)
    titleLabel.AutomaticSize = Enum.AutomaticSize.X
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "ZLEX HUB"
    titleLabel.TextColor3 = ACCENT_COLOR
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = headerFrame

    -- Welcome text
    local welcomeFrame = Instance.new("Frame")
    welcomeFrame.Name = "WelcomeFrame"
    welcomeFrame.Size = UDim2.new(1, 0, 0, 0)
    welcomeFrame.AutomaticSize = Enum.AutomaticSize.Y
    welcomeFrame.BackgroundTransparency = 1
    welcomeFrame.LayoutOrder = 1
    welcomeFrame.Parent = contentFrame

    local welcomeText = Instance.new("TextLabel")
    welcomeText.Name = "Welcome"
    welcomeText.Size = UDim2.new(1, 0, 0, 0)
    welcomeText.AutomaticSize = Enum.AutomaticSize.Y
    welcomeText.BackgroundTransparency = 1
    welcomeText.Text = "WELCOME TO\n<font color='rgb(139, 48, 48)'>Zlex Hub</font>"
    welcomeText.TextColor3 = Color3.fromRGB(255, 255, 255)
    welcomeText.TextSize = 26
    welcomeText.Font = Enum.Font.GothamBlack
    welcomeText.TextWrapped = true
    welcomeText.RichText = true
    welcomeText.TextXAlignment = Enum.TextXAlignment.Left
    welcomeText.Parent = welcomeFrame

    -- Key input section
    local keyFrame = Instance.new("Frame")
    keyFrame.Name = "KeyFrame"
    keyFrame.Size = UDim2.new(1, 0, 0, 0)
    keyFrame.AutomaticSize = Enum.AutomaticSize.Y
    keyFrame.BackgroundTransparency = 1
    keyFrame.LayoutOrder = 2
    keyFrame.Parent = contentFrame

    local keyLayout = Instance.new("UIListLayout")
    keyLayout.Padding = UDim.new(0, 8)
    keyLayout.Parent = keyFrame

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(1, 0, 0, 18)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Text = isDiscordMode and "Discord Key" or "License Key"
    keyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    keyLabel.TextSize = 12
    keyLabel.Font = Enum.Font.GothamMedium
    keyLabel.TextXAlignment = Enum.TextXAlignment.Left
    keyLabel.Parent = keyFrame

    -- Key input box
    local keyBox = Instance.new("Frame")
    keyBox.Name = "KeyBox"
    keyBox.Size = UDim2.new(1, 0, 0, 42)
    keyBox.BackgroundColor3 = SECONDARY_BG
    keyBox.LayoutOrder = 1
    keyBox.Parent = keyFrame

    local keyBoxCorner = Instance.new("UICorner")
    keyBoxCorner.CornerRadius = UDim.new(0, 8)
    keyBoxCorner.Parent = keyBox

    local keyBoxStroke = Instance.new("UIStroke")
    keyBoxStroke.Color = ACCENT_COLOR
    keyBoxStroke.Thickness = 1.5
    keyBoxStroke.Transparency = 0.6
    keyBoxStroke.Parent = keyBox

    local keyBoxPadding = Instance.new("UIPadding")
    keyBoxPadding.PaddingLeft = UDim.new(0, 14)
    keyBoxPadding.PaddingRight = UDim.new(0, 14)
    keyBoxPadding.Parent = keyBox

    keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(1, 0, 1, 0)
    keyInput.BackgroundTransparency = 1
    keyInput.Text = ""
    keyInput.PlaceholderText = isDiscordMode and "Enter Discord key from server..." or "Enter your license key..."
    keyInput.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyInput.TextSize = 13
    keyInput.Font = Enum.Font.GothamMedium
    keyInput.TextXAlignment = Enum.TextXAlignment.Left
    keyInput.ClearTextOnFocus = false
    keyInput.Parent = keyBox

    -- Status label
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = isDiscordMode and "Get key from our Discord server" or ""
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.LayoutOrder = 2
    statusLabel.Parent = keyFrame

    -- Buttons section
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ButtonFrame"
    buttonFrame.Size = UDim2.new(1, 0, 0, 0)
    buttonFrame.AutomaticSize = Enum.AutomaticSize.Y
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.LayoutOrder = 3
    buttonFrame.Parent = contentFrame

    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.Padding = UDim.new(0, 10)
    buttonLayout.Parent = buttonFrame

    -- Redeem button
    local redeemButton = Instance.new("Frame")
    redeemButton.Name = "RedeemButton"
    redeemButton.Size = UDim2.new(1, 0, 0, 42)
    redeemButton.BackgroundColor3 = ACCENT_COLOR
    redeemButton.Parent = buttonFrame

    local redeemCorner = Instance.new("UICorner")
    redeemCorner.CornerRadius = UDim.new(0, 8)
    redeemCorner.Parent = redeemButton

    local redeemGradient = Instance.new("UIGradient")
    redeemGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(139, 48, 48)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 35, 35))
    })
    redeemGradient.Rotation = 90
    redeemGradient.Parent = redeemButton

    local redeemText = Instance.new("TextLabel")
    redeemText.Size = UDim2.new(1, 0, 1, 0)
    redeemText.BackgroundTransparency = 1
    redeemText.Text = "REDEEM KEY"
    redeemText.TextColor3 = Color3.fromRGB(255, 255, 255)
    redeemText.TextSize = 13
    redeemText.Font = Enum.Font.GothamBold
    redeemText.Parent = redeemButton

    local redeemClick = Instance.new("TextButton")
    redeemClick.Name = "Click"
    redeemClick.Size = UDim2.new(1, 0, 1, 0)
    redeemClick.BackgroundTransparency = 1
    redeemClick.Text = ""
    redeemClick.Parent = redeemButton

    -- Get Key / Join Discord button
    local getKeyButton = Instance.new("Frame")
    getKeyButton.Name = "GetKeyButton"
    getKeyButton.Size = UDim2.new(1, 0, 0, 42)
    getKeyButton.BackgroundColor3 = SECONDARY_BG
    getKeyButton.LayoutOrder = 1
    getKeyButton.Parent = buttonFrame

    local getKeyCorner = Instance.new("UICorner")
    getKeyCorner.CornerRadius = UDim.new(0, 8)
    getKeyCorner.Parent = getKeyButton

    local getKeyStroke = Instance.new("UIStroke")
    getKeyStroke.Color = ACCENT_COLOR
    getKeyStroke.Thickness = 1.5
    getKeyStroke.Transparency = 0.5
    getKeyStroke.Parent = getKeyButton

    local getKeyText = Instance.new("TextLabel")
    getKeyText.Size = UDim2.new(1, 0, 1, 0)
    getKeyText.BackgroundTransparency = 1
    getKeyText.Text = isDiscordMode and "JOIN DISCORD" or "GET KEY"
    getKeyText.TextColor3 = ACCENT_COLOR
    getKeyText.TextSize = 13
    getKeyText.Font = Enum.Font.GothamBold
    getKeyText.Parent = getKeyButton

    local getKeyClick = Instance.new("TextButton")
    getKeyClick.Name = "Click"
    getKeyClick.Size = UDim2.new(1, 0, 1, 0)
    getKeyClick.BackgroundTransparency = 1
    getKeyClick.Text = ""
    getKeyClick.Parent = getKeyButton

    -- Separator
    local separator = Instance.new("Frame")
    separator.Name = "Separator"
    separator.Size = UDim2.new(1, 0, 0, 1)
    separator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    separator.BackgroundTransparency = 0.9
    separator.BorderSizePixel = 0
    separator.LayoutOrder = 2
    separator.Parent = buttonFrame

    -- Credit
    local creditLabel = Instance.new("TextLabel")
    creditLabel.Size = UDim2.new(1, 0, 0, 16)
    creditLabel.BackgroundTransparency = 1
    creditLabel.Text = "Powered by Zlex Hub"
    creditLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
    creditLabel.TextSize = 10
    creditLabel.Font = Enum.Font.Gotham
    creditLabel.LayoutOrder = 3
    creditLabel.Parent = buttonFrame

    -- Opening animation
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.BackgroundTransparency = 1

    local openTween = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 380, 0, 0),
        BackgroundTransparency = 0.05
    })
    openTween:Play()

    -- Button hover effects
    local function addHoverEffect(button, isAccent)
        local originalColor = isAccent and ACCENT_COLOR or SECONDARY_BG
        local hoverColor = isAccent and Color3.fromRGB(170, 60, 60) or Color3.fromRGB(35, 35, 35)

        button.MouseEnter:Connect(function()
            TweenService:Create(button.Parent, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
        end)

        button.MouseLeave:Connect(function()
            TweenService:Create(button.Parent, TweenInfo.new(0.2), {BackgroundColor3 = originalColor}):Play()
        end)
    end

    addHoverEffect(redeemClick, true)
    addHoverEffect(getKeyClick, false)

    return redeemClick, getKeyClick
end

-- Handle key validation (handles both Discord and Panda modes)
local function handleKeyValidation(key)
    updateStatus("Verifying key...", Color3.fromRGB(255, 200, 0))

    -- Check HWID status first
    local hwidValid, hwidMessage = HwidManager:CheckHwid(UserID_HWID)
    if not hwidValid then
        updateStatus(hwidMessage, Color3.fromRGB(255, 100, 100))
        print("[Zlex Hub] HWID Check Failed: " .. hwidMessage)
        return
    end

    local isValid, message

    if ZlexConfig:IsDiscordMode() then
        -- Discord mode: simple key match
        isValid, message = ValidateDiscordKey(key)
    else
        -- Panda mode: API validation
        isValid, message = ValidateKey(key, Identifier, UserID_HWID)
    end

    if isValid then
        -- Check if game is supported
        local scriptUrl, gameName = ZlexConfig:GetCurrentGameScript()

        if not scriptUrl then
            updateStatus("Game not supported yet!", Color3.fromRGB(255, 100, 100))
            print("[Zlex Hub] This game is not supported yet.")
            return
        end

        updateStatus("Success! Loading " .. gameName .. "...", ACCENT_COLOR)

        -- Save key for future use
        if writefile then
            pcall(function()
                writefile("zlex_hub_key.txt", key)
            end)
        end

        task.wait(1.5)

        -- Clean up UI and load main script
        if screenGui and mainFrame then
            local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, 0),
                BackgroundTransparency = 1
            })
            closeTween:Play()
            closeTween.Completed:Wait()
            screenGui:Destroy()
        elseif screenGui then
            screenGui:Destroy()
        end

        loadstring(game:HttpGet(scriptUrl))()
    else
        updateStatus(message or "Invalid key!", Color3.fromRGB(255, 100, 100))
    end
end

-- Check for saved key
local function checkSavedKey()
    if isfile and isfile("zlex_hub_key.txt") then
        local savedKey = readfile("zlex_hub_key.txt")
        if savedKey and savedKey ~= "" then
            -- Check HWID status first
            local hwidValid, hwidMessage = HwidManager:CheckHwid(UserID_HWID)
            if not hwidValid then
                print("[Zlex Hub] HWID Check Failed: " .. hwidMessage)
                if delfile then
                    pcall(function() delfile("zlex_hub_key.txt") end)
                end
                return false
            end

            local isValid, message

            if ZlexConfig:IsDiscordMode() then
                isValid, message = ValidateDiscordKey(savedKey)
            else
                isValid, message = ValidateKey(savedKey, Identifier, UserID_HWID)
            end

            if isValid then
                -- Check if game is supported
                local scriptUrl, gameName = ZlexConfig:GetCurrentGameScript()
                if scriptUrl then
                    loadstring(game:HttpGet(scriptUrl))()
                    return true
                else
                    print("[Zlex Hub] Game not supported yet.")
                    -- Don't return true, show the UI
                end
            else
                if delfile then
                    pcall(function() delfile("zlex_hub_key.txt") end)
                end
            end
        end
    end
    return false
end

-- Main execution
print("[Zlex Hub] Mode: " .. (ZlexConfig:IsDiscordMode() and "Discord Preset Key" or "Individual Keys"))
print("[Zlex Hub] Service: " .. Identifier)
print("[Zlex Hub] HWID: " .. UserID_HWID)

-- CHECK PREMIUM WHITELIST FIRST (skip key system for premium users)
if HwidManager:IsPremium(UserID_HWID) then
    local premiumNote = HwidManager:GetPremiumNote(UserID_HWID)
    print("[Zlex Hub] ✓ PREMIUM USER DETECTED: " .. (premiumNote or "Loading..."))
    
    local currentGame = ZlexConfig:GetCurrentGame()
    if currentGame then
        print("[Zlex Hub] Detected Game: " .. currentGame.name)
        local scriptUrl = currentGame.scriptUrl
        if scriptUrl then
            print("[Zlex Hub] Loading premium script...")
            loadstring(game:HttpGet(scriptUrl))()
            return
        else
            print("[Zlex Hub] ⚠️ Game found but no script URL available")
        end
    else
        print("[Zlex Hub] Game not in database, skipping premium load")
    end
end

-- Check HWID status
local hwidValid, hwidMessage = HwidManager:CheckHwid(UserID_HWID)
print("[Zlex Hub] HWID Status: " .. (hwidValid and "Valid ✓" or "Invalid ✗ - " .. hwidMessage))
if not hwidValid then
    print("[Zlex Hub] WARNING: This HWID is not authorized to access the hub!")
end

-- Check for current game
local currentGame = ZlexConfig:GetCurrentGame()
if currentGame then
    print("[Zlex Hub] Detected Game: " .. currentGame.name)
else
    print("[Zlex Hub] Game not in database, using default script")
end

if not checkSavedKey() then
    local redeemClick, getKeyClick = createUI()

    redeemClick.MouseButton1Click:Connect(function()
        local key = keyInput.Text:gsub("^%s*(.-)%s*$", "%1")
        if key == "" then
            updateStatus("Please enter a key", Color3.fromRGB(241, 196, 15))
            return
        end
        handleKeyValidation(key)
    end)

    getKeyClick.MouseButton1Click:Connect(function()
        if ZlexConfig:IsDiscordMode() then
            -- Discord mode: copy Discord invite
            if copyToClipboard(DISCORD_INVITE) then
                updateStatus("Discord invite copied!", Color3.fromRGB(88, 101, 242))
            else
                updateStatus("Join: " .. DISCORD_INVITE, Color3.fromRGB(88, 101, 242))
            end
        else
            -- Panda mode: copy getkey link
            local keyLink = GetKeyLink(Identifier, UserID_HWID)
            if copyToClipboard(keyLink) then
                updateStatus("Key link copied to clipboard!", ACCENT_COLOR)
            else
                updateStatus("Visit: " .. keyLink, ACCENT_COLOR)
            end
        end
    end)

    keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed and keyInput.Text ~= "" then
            handleKeyValidation(keyInput.Text:gsub("^%s*(.-)%s*$", "%1"))
        end
    end)
end

