--[[
    COPY MAP UI  |  BY MHMMDALVI
    Hanya GUI (tampilan + interaksi). Logika copy/import dipasang lewat:
        UI.OnCopy   = function(services, fileName) ... end
        UI.OnImport = function(path, opts) ... end   -- sudah terpasang (RBXL biner)
        UI.OnScan   = function() ... end   -- opsional
    Update progress dari logika kamu:
        UI.Begin()
        UI.SetProgress(persen, "judul status", "keterangan")
        UI.SetProgress(100, "Selesai", "File tersimpan")
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

---------------------------------------------------------------------
-- THEME
---------------------------------------------------------------------
local T = {
    Window   = Color3.fromRGB(247, 241, 228),
    Panel    = Color3.fromRGB(241, 233, 216),
    Card     = Color3.fromRGB(252, 247, 237),
    Field    = Color3.fromRGB(236, 228, 210),
    Line     = Color3.fromRGB(214, 203, 178),
    Accent   = Color3.fromRGB(255, 184, 28),
    AccentLn = Color3.fromRGB(240, 170, 40),
    Text     = Color3.fromRGB(28, 24, 18),
    Muted    = Color3.fromRGB(135, 125, 108),
    Title    = Color3.fromRGB(176, 92, 200),
    Ok       = Color3.fromRGB(80, 170, 100),
    Bad      = Color3.fromRGB(210, 80, 70),
}

local SERVICES = {
    "Workspace", "Players", "Lighting", "MaterialService",
    "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage",
    "StarterGui", "StarterPack", "StarterPlayer", "Teams",
    "SoundService", "Chat", "TextChatService", "LocalizationService",
}

---------------------------------------------------------------------
-- HELPER
---------------------------------------------------------------------
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end

local function corner(p, r)
    return new("UICorner", {CornerRadius = UDim.new(0, r)}, p)
end

local function stroke(p, color, thick, trans)
    return new("UIStroke", {
        Color = color, Thickness = thick or 1, Transparency = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
end

local function label(parent, props)
    local d = {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    }
    for k, v in pairs(props) do d[k] = v end
    return new("TextLabel", d, parent)
end

local function button(parent, props)
    local d = {
        AutoButtonColor = false, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = T.Text,
        BackgroundColor3 = T.Card, Text = "",
    }
    for k, v in pairs(props) do d[k] = v end
    local b = new("TextButton", d, parent)
    local base = b.BackgroundColor3
    b.MouseEnter:Connect(function()
        if b:GetAttribute("NoHover") then return end
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.35)}):Play()
    end)
    b.MouseLeave:Connect(function()
        if b:GetAttribute("NoHover") then return end
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = base}):Play()
    end)
    return b
end

local function fmt(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return (out:gsub("^%.", ""))
end

local function mmss(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%02d:%02d", sec // 60, sec % 60)
end

---------------------------------------------------------------------
-- PARENT GUI
---------------------------------------------------------------------
local ok, host = pcall(function()
    return (gethui and gethui()) or game:GetService("CoreGui")
end)
if not ok or not host then
    host = Players.LocalPlayer:WaitForChild("PlayerGui")
end
local old = host:FindFirstChild("CopyMapUI")
if old then old:Destroy() end

local UI = {}
local gui = new("ScreenGui", {
    Name = "CopyMapUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, host)

local WIN_W, WIN_H = 760, 440
local main = new("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(WIN_W, WIN_H),
    BackgroundColor3 = T.Window, BorderSizePixel = 0,
}, gui)
corner(main, 18)
stroke(main, T.Line, 1.5)

local scale = new("UIScale", {}, main)
local function fitScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    scale.Scale = math.min(1, (vp.X * 0.94) / WIN_W, (vp.Y * 0.94) / WIN_H)
end
fitScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)
end

---------------------------------------------------------------------
-- DRAG
---------------------------------------------------------------------
local function makeDraggable(handle)
    local dragging, startInput, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, i.Position, main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = (i.Position - startInput) / scale.Scale
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

---------------------------------------------------------------------
-- HEADER
---------------------------------------------------------------------
local header = new("Frame", {
    Name = "Header", Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1,
}, main)
makeDraggable(header)

local logo = new("Frame", {
    Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(26, 22),
    BackgroundColor3 = T.Accent, Rotation = 45, BorderSizePixel = 0,
}, header)
corner(logo, 3)

label(header, {
    Text = "COPY MAP BY MHMMDALVI", Font = Enum.Font.GothamBold, TextSize = 11,
    TextColor3 = T.Title, Position = UDim2.fromOffset(48, 14), Size = UDim2.fromOffset(240, 28),
})

-- tab pill
local pill = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
    Size = UDim2.fromOffset(300, 34), BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, header)
corner(pill, 17)
stroke(pill, T.Line, 1)

local tabCopy = button(pill, {
    Text = "COPY MAP", Size = UDim2.new(1 / 3, -4, 1, -6), Position = UDim2.fromOffset(3, 3),
    BackgroundColor3 = T.Accent, TextSize = 9,
})
corner(tabCopy, 14)
local tabImport = button(pill, {
    Text = "IMPORT MAP", Size = UDim2.new(1 / 3, -4, 1, -6), Position = UDim2.new(1 / 3, 1, 0, 3),
    BackgroundColor3 = T.Field, TextColor3 = T.Muted, TextSize = 9,
})
corner(tabImport, 14)
local tabImage = button(pill, {
    Text = "IMAGE 3D", Size = UDim2.new(1 / 3, -4, 1, -6), Position = UDim2.new(2 / 3, 1, 0, 3),
    BackgroundColor3 = T.Field, TextColor3 = T.Muted, TextSize = 9,
})
corner(tabImage, 14)

-- tombol kanan
local function roundIcon(text, x)
    local b = button(header, {
        Text = text, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, x, 0, 9),
        BackgroundColor3 = T.Panel, TextSize = 16, Font = Enum.Font.GothamBold,
    })
    corner(b, 20)
    stroke(b, T.Line, 1)
    return b
end
local btnClose    = roundIcon("X", -52)
local btnMove     = roundIcon("+", -100)   -- juga bisa dipakai untuk drag
local btnSettings = roundIcon("*", -148)
btnClose.TextSize = 14
makeDraggable(btnMove)
btnClose.MouseButton1Click:Connect(function() gui:Destroy() end)

---------------------------------------------------------------------
-- PAGE: COPY MAP
---------------------------------------------------------------------
local copyPage = new("Frame", {
    Name = "CopyPage", Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58),
    BackgroundTransparency = 1,
}, main)

-- judul kolom
label(copyPage, {
    Text = "SERVICE STUDIO", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(16, 4), Size = UDim2.fromOffset(180, 20),
})
local lblSelected = label(copyPage, {
    Text = "0 dipilih", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(204, 4), Size = UDim2.fromOffset(98, 20),
})
label(copyPage, {
    Text = "COPY MAP", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(316, 4), Size = UDim2.fromOffset(120, 20),
})
label(copyPage, {
    Text = "FILE.RBXL  ·  SAMA DENGAN STUDIO", TextSize = 8, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(436, 4), Size = UDim2.fromOffset(310, 20),
})

-- ===== panel kiri =====
local left = new("Frame", {
    Position = UDim2.fromOffset(14, 30), Size = UDim2.fromOffset(290, 340),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, copyPage)
corner(left, 14)
stroke(left, T.Line, 1)

local btnRow = new("Frame", {
    Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 32), BackgroundTransparency = 1,
}, left)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, btnRow)

local function smallBtn(text, order)
    local b = button(btnRow, {
        Text = text, Size = UDim2.new(1 / 3, -6, 1, 0), BackgroundColor3 = T.Field,
        TextSize = 8, LayoutOrder = order,
    })
    corner(b, 10)
    stroke(b, T.Line, 1)
    return b
end
local btnAll   = smallBtn("PILIH SEMUA", 1)
local btnNone  = smallBtn("KOSONGKAN", 2)
local btnScan  = smallBtn("SCAN ULANG", 3)

local list = new("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 1, -60),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = T.AccentLn, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, left)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, list)
new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4)}, list)

-- ===== panel kanan =====
local stats = new("Frame", {
    Position = UDim2.fromOffset(316, 30), Size = UDim2.fromOffset(430, 112),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, copyPage)
corner(stats, 14)
stroke(stats, T.Line, 1)

local function statCard(title, x, y)
    local c = new("Frame", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(203, 44),
        BackgroundColor3 = T.Field, BorderSizePixel = 0,
    }, stats)
    corner(c, 10)
    stroke(c, T.Line, 1, 0.3)
    label(c, {Text = title, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 12)})
    return label(c, {Text = "0", Font = Enum.Font.GothamBold, TextSize = 13,
        Position = UDim2.fromOffset(12, 21), Size = UDim2.new(1, -24, 0, 18)})
end
local valService = statCard("SERVICE", 8, 8)
local valItem    = statCard("ITEM", 219, 8)
local valScript  = statCard("SCRIPT", 8, 60)
local valFormat  = statCard("FORMAT", 219, 60)
valFormat.Text = "RBXL  ·  Binary"

-- nama file
local nameBox = new("Frame", {
    Position = UDim2.fromOffset(316, 150), Size = UDim2.fromOffset(430, 62),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, copyPage)
corner(nameBox, 14)
stroke(nameBox, T.Line, 1)
label(nameBox, {Text = "NAMA FILE  ·  OTOMATIS (EXPERIENCE)", Font = Enum.Font.GothamBold, TextSize = 8,
    TextColor3 = T.Muted, Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(250, 12)})
local lblFileOut = label(nameBox, {Text = "Studio Lite.rbxl", TextSize = 8, TextColor3 = T.AccentLn,
    TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -172, 0, 7), Size = UDim2.fromOffset(160, 12)})

local nameField = new("Frame", {
    Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 28),
    BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, nameBox)
corner(nameField, 8)
stroke(nameField, T.Line, 1)
local nameInput = new("TextBox", {
    Size = UDim2.new(1, -112, 1, 0), Position = UDim2.fromOffset(10, 0),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
    TextColor3 = T.Text, PlaceholderText = "Studio Lite", PlaceholderColor3 = T.Muted,
    Text = "", TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
}, nameField)
local btnAutoName = button(nameField, {
    Text = "NAMA MAP", Size = UDim2.fromOffset(92, 20), AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -4, 0.5, 0), BackgroundColor3 = T.Card, TextSize = 8,
})
corner(btnAutoName, 7)

local function currentFileName()
    local n = nameInput.Text:gsub("[\\/:*?\"<>|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if n == "" then n = "Studio Lite" end
    return n
end
local function refreshFileLabel()
    lblFileOut.Text = currentFileName() .. ".rbxl"
end
nameInput:GetPropertyChangedSignal("Text"):Connect(refreshFileLabel)
btnAutoName.MouseButton1Click:Connect(function()
    local nm = "Studio Lite"
    pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        if info and info.Name then nm = info.Name end
    end)
    nameInput.Text = nm
end)
refreshFileLabel()

-- progress
local progBox = new("Frame", {
    Position = UDim2.fromOffset(316, 220), Size = UDim2.fromOffset(430, 98),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, copyPage)
corner(progBox, 14)
stroke(progBox, T.Line, 1)
local progTitle = label(progBox, {Text = "Siap copy map", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 16)})
local progSub = label(progBox, {Text = "Pilih service lalu tekan COPY MAP", TextSize = 9, TextColor3 = T.Muted,
    Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 14)})
local barBg = new("Frame", {
    Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 14),
    BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, progBox)
corner(barBg, 7)
stroke(barBg, T.Line, 1)
local barFill = new("Frame", {
    Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
}, barBg)
corner(barFill, 7)
local lblPct = label(progBox, {Text = "0%", Font = Enum.Font.GothamBold, TextSize = 9,
    Position = UDim2.fromOffset(14, 74), Size = UDim2.fromOffset(100, 14)})
local lblTime = label(progBox, {Text = "00:00", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.new(1, -114, 0, 74), Size = UDim2.fromOffset(100, 14)})

local btnCopy = button(copyPage, {
    Text = "COPY MAP", Position = UDim2.fromOffset(316, 326), Size = UDim2.fromOffset(430, 44),
    BackgroundColor3 = T.Accent, TextSize = 12,
})
corner(btnCopy, 12)

---------------------------------------------------------------------
-- PAGE: IMPORT MAP
---------------------------------------------------------------------
local importPage = new("Frame", {
    Name = "ImportPage", Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58),
    BackgroundTransparency = 1, Visible = false,
}, main)

local imagePage = new("Frame", {
    Name = "ImagePage", Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58),
    BackgroundTransparency = 1, Visible = false,
}, main)

label(importPage, {
    Text = "FILE MAP", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(16, 4), Size = UDim2.fromOffset(180, 20),
})
local lblFileCount = label(importPage, {
    Text = "0 file", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(204, 4), Size = UDim2.fromOffset(98, 20),
})
label(importPage, {
    Text = "IMPORT MAP", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(316, 4), Size = UDim2.fromOffset(120, 20),
})
label(importPage, {
    Text = "RBXL / RBXM  ·  BINARY", TextSize = 8, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.fromOffset(436, 4), Size = UDim2.fromOffset(310, 20),
})

-- ===== panel kiri: daftar file =====
local impLeft = new("Frame", {
    Position = UDim2.fromOffset(14, 30), Size = UDim2.fromOffset(290, 340),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, importPage)
corner(impLeft, 14)
stroke(impLeft, T.Line, 1)

local btnRefresh = button(impLeft, {
    Text = "MUAT ULANG DAFTAR", Position = UDim2.fromOffset(12, 12),
    Size = UDim2.new(1, -24, 0, 32), BackgroundColor3 = T.Field, TextSize = 8,
})
corner(btnRefresh, 10)
stroke(btnRefresh, T.Line, 1)

local impList = new("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 1, -60),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = T.AccentLn, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, impLeft)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, impList)
new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4)}, impList)

-- ===== panel kanan =====
local impInfo = new("Frame", {
    Position = UDim2.fromOffset(316, 30), Size = UDim2.fromOffset(430, 112),
    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
}, importPage)
corner(impInfo, 14)
stroke(impInfo, T.Line, 1)

local function infoCard(title, x, y)
    local c = new("Frame", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(203, 44),
        BackgroundColor3 = T.Field, BorderSizePixel = 0,
    }, impInfo)
    corner(c, 10)
    stroke(c, T.Line, 1, 0.3)
    label(c, {Text = title, Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 12)})
    return label(c, {Text = "-", Font = Enum.Font.GothamBold, TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(12, 21), Size = UDim2.new(1, -24, 0, 18)})
end
local valFile = infoCard("FILE", 8, 8)
local valSize = infoCard("UKURAN", 219, 8)
local valInst = infoCard("INSTANCE DIBUAT", 8, 60)
local valStat = infoCard("STATUS", 219, 60)
valStat.Text = "Belum dipilih"

local optBox = new("Frame", {
    Position = UDim2.fromOffset(316, 150), Size = UDim2.fromOffset(430, 62),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, importPage)
corner(optBox, 14)
stroke(optBox, T.Line, 1)

local function toggleRow(text, y, default)
    local state = default
    label(optBox, {Text = text, TextSize = 9, Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -80, 0, 20)})
    local sw = button(optBox, {
        Text = "", Size = UDim2.fromOffset(38, 18), AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, y + 1), BackgroundColor3 = default and T.Accent or T.Field,
    })
    sw:SetAttribute("NoHover", true)
    corner(sw, 9)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0, BackgroundColor3 = T.Text,
        Position = default and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
    }, sw)
    corner(knob, 6)
    sw.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(sw, TweenInfo.new(0.12), {BackgroundColor3 = state and T.Accent or T.Field}):Play()
        TweenService:Create(knob, TweenInfo.new(0.12), {
            Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
        }):Play()
    end)
    return function() return state end
end
local getStudioMode = toggleRow("Mode Studio Lite (part di-anchor + atribut SL_)", 8, true)
local getSvcProps   = toggleRow("Terapkan properti service (Lighting dll)", 33, false)

local impProg = new("Frame", {
    Position = UDim2.fromOffset(316, 220), Size = UDim2.fromOffset(430, 98),
    BackgroundColor3 = T.Card, BorderSizePixel = 0,
}, importPage)
corner(impProg, 14)
stroke(impProg, T.Line, 1)
local impTitle = label(impProg, {Text = "Siap import map", Font = Enum.Font.GothamBold, TextSize = 11,
    Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 16)})
local impSub = label(impProg, {Text = "Pilih file di daftar lalu tekan IMPORT MAP", TextSize = 9, TextColor3 = T.Muted,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 14)})
local impBarBg = new("Frame", {
    Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 14),
    BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, impProg)
corner(impBarBg, 7)
stroke(impBarBg, T.Line, 1)
local impBar = new("Frame", {
    Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
}, impBarBg)
corner(impBar, 7)
local impPct = label(impProg, {Text = "0%", Font = Enum.Font.GothamBold, TextSize = 9,
    Position = UDim2.fromOffset(14, 74), Size = UDim2.fromOffset(100, 14)})
local impTime = label(impProg, {Text = "00:00", TextSize = 9, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Right,
    Position = UDim2.new(1, -114, 0, 74), Size = UDim2.fromOffset(100, 14)})

local btnImport = button(importPage, {
    Text = "IMPORT MAP", Position = UDim2.fromOffset(316, 326), Size = UDim2.fromOffset(430, 44),
    BackgroundColor3 = T.Accent, TextSize = 12,
})
corner(btnImport, 12)

local function showTab(name)
    local pagesByName = {copy = copyPage, import = importPage, image = imagePage}
    local tabsByName = {copy = tabCopy, import = tabImport, image = tabImage}
    for k, pg in pairs(pagesByName) do
        local on = k == name
        pg.Visible = on
        tabsByName[k].BackgroundColor3 = on and T.Accent or T.Field
        tabsByName[k].TextColor3 = on and T.Text or T.Muted
        tabsByName[k]:SetAttribute("NoHover", true)
    end
end
tabCopy.MouseButton1Click:Connect(function() showTab("copy") end)
tabImport.MouseButton1Click:Connect(function() showTab("import") end)
tabImage.MouseButton1Click:Connect(function() showTab("image") end)
showTab("copy")

---------------------------------------------------------------------
-- DAFTAR SERVICE
---------------------------------------------------------------------
local cards, selected, info = {}, {}, {}

local function updateSummary()
    local n, items, scripts = 0, 0, 0
    for _, name in ipairs(SERVICES) do
        if selected[name] then
            n += 1
            local i = info[name]
            if i then items += i.items; scripts += i.scripts end
        end
    end
    lblSelected.Text = n .. " dipilih"
    valService.Text = n .. " / " .. #SERVICES
    valItem.Text = fmt(items)
    valScript.Text = fmt(scripts)
end

local function paintCard(name)
    local c = cards[name]
    if not c then return end
    local on = selected[name]
    TweenService:Create(c.stroke, TweenInfo.new(0.12), {
        Color = on and T.Accent or T.Line, Thickness = on and 1.6 or 1,
    }):Play()
    c.circle.BackgroundColor3 = on and T.Accent or T.Field
    c.dot.Visible = on
end

local function setSelected(name, v)
    selected[name] = v and true or false
    paintCard(name)
    updateSummary()
end

for idx, name in ipairs(SERVICES) do
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = idx,
    }, list)
    corner(card, 12)
    local st = stroke(card, T.Line, 1)
    label(card, {Text = name, Font = Enum.Font.GothamBold, TextSize = 12,
        Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -80, 0, 18)})
    local sub = label(card, {Text = "memindai...", TextSize = 9, TextColor3 = T.Muted,
        Position = UDim2.fromOffset(18, 33), Size = UDim2.new(1, -80, 0, 14)})
    local circle = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(34, 34), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
    }, card)
    corner(circle, 17)
    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(9, 9), BackgroundColor3 = T.Text, BorderSizePixel = 0,
    }, circle)
    corner(dot, 5)
    local hit = new("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3,
    }, card)
    hit.MouseButton1Click:Connect(function() setSelected(name, not selected[name]) end)

    cards[name] = {frame = card, stroke = st, sub = sub, circle = circle, dot = dot}
    selected[name] = true
    paintCard(name)
end

local scanning = false
local function scan()
    if scanning then return end
    scanning = true
    for _, name in ipairs(SERVICES) do
        local items, scripts = 0, 0
        local okS, svc = pcall(game.GetService, game, name)
        if okS and svc then
            local okD, desc = pcall(svc.GetDescendants, svc)
            if okD then
                items = #desc
                for _, d in ipairs(desc) do
                    if d:IsA("LuaSourceContainer") then scripts += 1 end
                end
            end
        end
        info[name] = {items = items, scripts = scripts}
        local c = cards[name]
        if c and c.frame.Parent then
            c.sub.Text = items > 0 and (fmt(items) .. " item") or "kosong"
            if name == "Workspace" and items > 0 and workspace.StreamingEnabled then
                c.sub.Text = fmt(items) .. " item (streaming)"
            end
        end
        updateSummary()
        task.wait()
    end
    scanning = false
end

btnAll.MouseButton1Click:Connect(function()
    for _, n in ipairs(SERVICES) do selected[n] = true; paintCard(n) end
    updateSummary()
end)
btnNone.MouseButton1Click:Connect(function()
    for _, n in ipairs(SERVICES) do selected[n] = false; paintCard(n) end
    updateSummary()
end)
btnScan.MouseButton1Click:Connect(function()
    if UI.OnScan then task.spawn(UI.OnScan) end
    task.spawn(scan)
end)

---------------------------------------------------------------------
-- PROGRESS API
---------------------------------------------------------------------
local running, t0 = false, 0

function UI.Begin()
    running, t0 = true, os.clock()
    task.spawn(function()
        while running and gui.Parent do
            lblTime.Text = mmss(os.clock() - t0)
            task.wait(0.25)
        end
    end)
end

function UI.SetProgress(pct, title, sub)
    pct = math.clamp(pct or 0, 0, 100)
    TweenService:Create(barFill, TweenInfo.new(0.2), {Size = UDim2.fromScale(pct / 100, 1)}):Play()
    lblPct.Text = math.floor(pct) .. "%"
    if title then progTitle.Text = title end
    if sub then progSub.Text = sub end
    if pct >= 100 then
        running = false
        lblTime.Text = mmss(os.clock() - t0)
    end
end

function UI.GetSelected()
    local out = {}
    for _, n in ipairs(SERVICES) do
        if selected[n] then table.insert(out, n) end
    end
    return out
end

function UI.GetFileName()
    return currentFileName()
end

---------------------------------------------------------------------
-- TOMBOL AKSI
---------------------------------------------------------------------
btnCopy.MouseButton1Click:Connect(function()
    local picked = UI.GetSelected()
    if #picked == 0 then
        progTitle.Text = "Belum ada service dipilih"
        progSub.Text = "Pilih minimal satu service dulu"
        return
    end
    if not UI.OnCopy then
        progTitle.Text = "Fungsi copy belum dipasang"
        progSub.Text = "Isi UI.OnCopy dengan logika copy kamu"
        return
    end
    UI.SetProgress(0, "Memulai copy...", #picked .. " service dipilih")
    UI.Begin()
    task.spawn(UI.OnCopy, picked, UI.GetFileName())
end)

btnSettings.MouseButton1Click:Connect(function()
    -- tempat untuk menu pengaturan kamu
end)

---------------------------------------------------------------------
-- FITUR: COPY MAP (memakai saveinstance dari executor)
---------------------------------------------------------------------
local SAVER_NAMES = {"saveinstance", "save_instance", "SaveInstance", "savegame", "save_game"}

local function findNativeSaver()
    local envs = {}
    pcall(function() if getgenv then envs[#envs + 1] = getgenv() end end)
    pcall(function() if getfenv then envs[#envs + 1] = getfenv(0) end end)
    pcall(function() envs[#envs + 1] = _G end)
    pcall(function() if shared then envs[#envs + 1] = shared end end)
    pcall(function() if syn then envs[#envs + 1] = syn end end)
    pcall(function() if fluxus then envs[#envs + 1] = fluxus end end)
    for _, env in ipairs(envs) do
        for _, n in ipairs(SAVER_NAMES) do
            local okG, f = pcall(function() return env[n] end)
            if okG and type(f) == "function" then return f end
        end
    end
    return nil
end

-- Cadangan: Universal Syn SaveInstance (script open-source, dimuat dari GitHub).
-- Butuh HttpGet + loadstring + writefile di executor.
local cachedUniversal
local function loadUniversalSaver()
    if cachedUniversal then return cachedUniversal end
    local okL, f = pcall(function()
        local src = game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau", true)
        return loadstring(src, "saveinstance")()
    end)
    if okL and type(f) == "function" then
        cachedUniversal = f
        return f
    end
    return nil
end

local function getSaver()
    return findNativeSaver() or loadUniversalSaver()
end

local function fileExists(p)
    local okF, r = pcall(function() return isfile and isfile(p) end)
    return okF and r == true
end

local busy = false

local function isValidInstance(inst)
    local okV, v = pcall(function()
        return typeof(inst) == "Instance" and inst.Parent == game
    end)
    return okV and v == true
end

local function shortErr(e, n)
    local s = tostring(e):gsub("%s+", " ")
    return s:sub(1, n or 110)
end

-- Map dengan StreamingEnabled hanya memuat area di sekitar pemain.
-- Fungsi ini "mengunjungi" grid titik di sekitar pemain supaya server mengirim bagian map lain.
UI.StreamRadius     = 2048   -- jarak (stud) dari posisi pemain yang dijelajahi
UI.StreamStep       = 512    -- jarak antar titik
UI.StreamMaxSeconds = 150    -- batas waktu total

local function countWorkspace()
    local okD, d = pcall(workspace.GetDescendants, workspace)
    return okD and #d or 0
end

local function preloadStreaming(onStep)
    local okE, enabled = pcall(function() return workspace.StreamingEnabled end)
    if not (okE and enabled) then return false, 0 end
    local lp = Players.LocalPlayer
    if not lp then return false, 0 end

    local center = Vector3.zero
    local ch = lp.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if hrp then
        center = hrp.Position
    elseif workspace.CurrentCamera then
        center = workspace.CurrentCamera.CFrame.Position
    end

    local R, step = UI.StreamRadius, UI.StreamStep
    local pts = {}
    for x = -R, R, step do
        for z = -R, R, step do
            pts[#pts + 1] = center + Vector3.new(x, 0, z)
        end
    end
    table.sort(pts, function(a, b) return (a - center).Magnitude < (b - center).Magnitude end)

    local t0 = os.clock()
    for i, pos in ipairs(pts) do
        if not gui.Parent or os.clock() - t0 > UI.StreamMaxSeconds then break end
        pcall(function() lp:RequestStreamAroundAsync(pos, 1.5) end)
        if onStep then onStep(i, #pts) end
    end
    task.wait(0.5)
    return true, #pts
end

UI.OnCopy = function(services, fileName)
    if busy then return end
    busy = true
    barFill.BackgroundColor3 = T.Accent

    local function fail(title, sub)
        running = false
        barFill.BackgroundColor3 = T.Bad
        UI.SetProgress(100, title, sub)
        lblPct.Text = "GAGAL"
        busy = false
    end

    local saver = getSaver()
    if type(saver) ~= "function" then
        return fail("Executor tidak didukung",
            "saveinstance tidak ada & gagal dimuat (butuh HttpGet/loadstring). Pakai executor lain")
    end
    UI.SetProgress(3, "Menyiapkan...", "Fungsi saveinstance siap")

    -- 0) map streaming: muat area dulu supaya Workspace tidak kosong
    local streamed, streamNote = false, nil
    if table.find(services, "Workspace") then
        local before = countWorkspace()
        local okP, did = pcall(preloadStreaming, function(i, total)
            UI.SetProgress(3 + 7 * (i / total), "Memuat area map (streaming)...", i .. " / " .. total .. " titik")
        end)
        if okP and did then
            streamed = true
            local after = countWorkspace()
            info.Workspace = info.Workspace or {items = 0, scripts = 0}
            info.Workspace.items = after
            local sc = 0
            local okD, d = pcall(workspace.GetDescendants, workspace)
            for _, inst in ipairs(okD and d or {}) do
                if inst:IsA("LuaSourceContainer") then sc += 1 end
            end
            info.Workspace.scripts = sc
            streamNote = "streaming: " .. fmt(before) .. " -> " .. fmt(after) .. " item"
            pcall(warn, "[CopyMap] " .. streamNote)
        end
    end

    -- 1) kumpulkan service yang dipilih (buang yang tidak valid / kosong)
    UI.SetProgress(5, "Menyiapkan...", "Mengumpulkan service")
    local instances, totalItems, empty = {}, 0, {}
    local totalScripts = 0
    for _, name in ipairs(services) do
        local okS, svc = pcall(game.GetService, game, name)
        if okS and isValidInstance(svc) then
            local count = info[name] and info[name].items
            if count == nil then
                local okD, d = pcall(svc.GetDescendants, svc)
                count = okD and #d or 0
            end
            if count > 0 then
                table.insert(instances, svc)
                totalItems += count
                totalScripts += (info[name] and info[name].scripts) or 0
            else
                table.insert(empty, name)
            end
        else
            table.insert(empty, name)
        end
    end
    if #instances == 0 then
        return fail("Instance tidak ditemukan",
            "Service yang dipilih kosong / tidak bisa diakses. Pilih Workspace lalu SCAN ULANG")
    end

    -- 2) jalankan saveinstance (urutan percobaan dari yang paling lengkap)
    local path = fileName .. ".rbxl"
    local finished, saved, wholeGame = false, false, false
    local errs = {}

    task.spawn(function()
        local attempts = {
            {whole = false, run = function()
                return saver({
                    FileName = path, Mode = "invalid", ExtraInstances = instances,
                    Decompile = true, DecompileTimeout = 30, ReadMe = false,
                    ShutdownWhenDone = false, ShowStatus = false,
                })
            end},
            -- sebagian executor menambah ekstensi sendiri
            {whole = false, run = function()
                return saver({
                    FileName = fileName, Mode = "invalid", ExtraInstances = instances,
                    Decompile = true, ReadMe = false,
                })
            end},
            -- opsi minimal untuk executor yang menolak opsi tak dikenal
            {whole = false, run = function()
                return saver({FileName = path, ExtraInstances = instances})
            end},
            {whole = true, run = function() return saver(path) end},
            {whole = true, run = function() return saver() end},
        }
        for i, a in ipairs(attempts) do
            local okRun, e = pcall(a.run)
            if okRun then
                saved, wholeGame = true, a.whole
                break
            end
            errs[#errs + 1] = shortErr(e, 200)
            pcall(warn, ("[CopyMap] percobaan %d gagal: %s"):format(i, tostring(e)))
        end
        finished = true
    end)

    -- 3) saveinstance tidak memberi progress asli, jadi bar ini hanya estimasi
    local est = math.max(8, totalItems / 400)
    local started = os.clock()
    local note = "Estimasi, tergantung ukuran map dan executor"
    while not finished and gui.Parent do
        local p = 10 + 80 * (1 - math.exp(-(os.clock() - started) / est))
        UI.SetProgress(p, "Menyimpan map...", note)
        task.wait(0.3)
    end
    if not gui.Parent then busy = false return end

    -- 4) hasil
    if not saved then
        -- tampilkan error percobaan PERTAMA (paling relevan), bukan yang terakhir
        return fail("Gagal menyimpan", shortErr(errs[1] or "unknown", 110))
    end

    local sub = fileExists(path) and (path .. " tersimpan di folder workspace executor")
        or "Selesai, cek folder workspace executor"
    if wholeGame then
        sub = "Executor tidak mendukung pilihan service, seluruh game disimpan. " .. sub
    elseif #empty > 0 then
        sub = #empty .. " service kosong dilewati. " .. sub
    end
    if streamNote then sub = sub .. " [" .. streamNote .. "]" end
    if totalScripts > 0 then
        if type(decompile) ~= "function" then
            sub = sub .. " | " .. totalScripts .. " script TANPA isi (executor tidak punya decompile)"
        else
            sub = sub .. " | " .. totalScripts .. " script (hanya Local/Module; Script server tidak ada di client)"
        end
    end
    UI.SetProgress(100, "Copy map selesai", sub)
    busy = false
end

---------------------------------------------------------------------
-- FITUR: IMPORT MAP (parser RBXL / RBXM biner)
---------------------------------------------------------------------
local InsertService = game:GetService("InsertService")

-- id rotasi CFrame biner -> R00,R01,R02,R10,R11,R12,R20,R21,R22
local ROT = {
    [0x02] = {1,0,0, 0,1,0, 0,0,1},    [0x03] = {1,0,0, 0,0,-1, 0,1,0},
    [0x05] = {1,0,0, 0,-1,0, 0,0,-1},  [0x06] = {1,0,0, 0,0,1, 0,-1,0},
    [0x07] = {0,1,0, 1,0,0, 0,0,-1},   [0x09] = {0,0,1, 1,0,0, 0,1,0},
    [0x0A] = {0,-1,0, 1,0,0, 0,0,1},   [0x0C] = {0,0,-1, 1,0,0, 0,-1,0},
    [0x0D] = {0,1,0, 0,0,1, 1,0,0},    [0x0E] = {0,0,-1, 0,1,0, 1,0,0},
    [0x10] = {0,-1,0, 0,0,-1, 1,0,0},  [0x11] = {0,0,1, 0,-1,0, 1,0,0},
    [0x14] = {-1,0,0, 0,1,0, 0,0,-1},  [0x15] = {-1,0,0, 0,0,1, 0,1,0},
    [0x17] = {-1,0,0, 0,-1,0, 0,0,1},  [0x18] = {-1,0,0, 0,0,-1, 0,-1,0},
    [0x19] = {0,1,0, -1,0,0, 0,0,1},   [0x1B] = {0,0,-1, -1,0,0, 0,1,0},
    [0x1C] = {0,-1,0, -1,0,0, 0,0,-1}, [0x1E] = {0,0,1, -1,0,0, 0,-1,0},
    [0x1F] = {0,1,0, 0,0,-1, -1,0,0},  [0x20] = {0,0,1, 0,1,0, -1,0,0},
    [0x22] = {0,-1,0, 0,0,1, -1,0,0},  [0x23] = {0,0,-1, 0,-1,0, -1,0,0},
}

-- nama properti di file -> nama properti API
local ALIAS = {size = "Size", shape = "Shape", Color3uint8 = "Color"}
local SKIP_PROP = {
    formFactorRaw = true, Attributes = true, AttributesSerialize = true, Tags = true,
    MaterialVariantSerialized = true, UniqueId = true, HistoryId = true, SourceAssetId = true,
    ScriptGuid = true, LinkedSource = true, SecurityCapabilities = true, Capabilities = true,
    DefinesCapabilities = true, NeedsPivotMigration = true, Parent = true,
}
local SKIP_CLASS = {Camera = true, Terrain = true}

-- bisa kamu ubah dari luar
UI.ImportSkipServices = {Players = true}          -- isi service ini tidak diimport
UI.ImportSkipNames = {StudioLiteFolder = true}    -- folder bawaan Studio Lite jangan digandakan
UI.ResolveMesh = nil                              -- opsional: function(meshId) return MeshPart end

---------------------------------------------------------------------
-- LZ4 (pakai bawaan executor kalau ada, kalau tidak pakai Luau murni)
---------------------------------------------------------------------
local function lz4pure(src, outSize)
    local out, ip, op, n = table.create(outSize), 1, 0, #src
    local byte, work = string.byte, 0
    while ip <= n do
        local token = byte(src, ip); ip += 1
        local lit = token // 16
        if lit == 15 then
            local b
            repeat b = byte(src, ip); ip += 1; lit += b until b ~= 255
        end
        for i = 0, lit - 1 do out[op + 1 + i] = byte(src, ip + i) end
        ip += lit; op += lit
        if ip > n then break end
        local offset = byte(src, ip) + byte(src, ip + 1) * 256; ip += 2
        local ml = token % 16
        if ml == 15 then
            local b
            repeat b = byte(src, ip); ip += 1; ml += b until b ~= 255
        end
        ml += 4
        local from = op - offset
        for i = 1, ml do out[op + i] = out[from + i] end
        op += ml
        work += lit + ml
        if work > 400000 then work = 0; task.wait() end
    end
    local parts = {}
    for i = 1, op, 4000 do
        local okC, piece = pcall(function()
            return string.char(table.unpack(out, i, math.min(i + 3999, op)))
        end)
        if not okC then
            local h = {}
            for k = 1, math.min(4, #src) do h[k] = string.format("%02X", byte(src, k)) end
            error("Chunk bukan LZ4 valid (awal data: " .. table.concat(h, " ") .. ")", 0)
        end
        parts[#parts + 1] = piece
    end
    return table.concat(parts)
end

local function lz4(src, outSize)
    local env = (getgenv and getgenv()) or {}
    local fn = env.lz4decompress or lz4decompress
    if type(fn) == "function" then
        local okL, res = pcall(fn, src, outSize)
        if okL and type(res) == "string" and #res == outSize then return res end
    end
    return lz4pure(src, outSize)
end

-- chunk bisa dikompres LZ4 (lama) atau ZSTD (magic 28 B5 2F FD)
local ZSTD_MAGIC = "\40\181\47\253"
local function decompress(src, outSize)
    if src:sub(1, 4) == ZSTD_MAGIC then
        local env = (getgenv and getgenv()) or {}
        local fn = env.zstddecompress or zstddecompress
        if type(fn) ~= "function" then
            error("File memakai kompresi ZSTD, executor tidak punya zstddecompress", 0)
        end
        local okZ, res = pcall(fn, src, outSize)
        if not (okZ and type(res) == "string" and #res == outSize) then
            okZ, res = pcall(fn, src)
        end
        if okZ and type(res) == "string" and #res == outSize then return res end
        error("zstddecompress executor gagal / ukuran tidak cocok", 0)
    end
    return lz4(src, outSize)
end

---------------------------------------------------------------------
-- PEMBACA BINER
---------------------------------------------------------------------
local function zz(u)
    if u % 2 == 0 then return u / 2 end
    return -(u + 1) / 2
end

-- float yang disimpan dengan bit tanda dipindah ke posisi terendah
local function unrot(u)
    local bits = (u // 2) + (u % 2) * 2147483648
    local sign = bits >= 2147483648 and -1 or 1
    local e = (bits // 8388608) % 256
    local m = bits % 8388608
    if e == 0 then return sign * m * 2 ^ -149 end
    if e == 255 then return m == 0 and sign * math.huge or 0 end
    return sign * (1 + m / 8388608) * 2 ^ (e - 127)
end

local function newReader(s)
    local r = {p = 1}
    local byte = string.byte
    function r.u8() local v = byte(s, r.p); r.p += 1; return v end
    function r.u32() local v = string.unpack("<I4", s, r.p); r.p += 4; return v end
    function r.i16() local v = string.unpack("<i2", s, r.p); r.p += 2; return v end
    function r.f32() local v = string.unpack("<f", s, r.p); r.p += 4; return v end
    function r.f64() local v = string.unpack("<d", s, r.p); r.p += 8; return v end
    function r.str()
        local n = r.u32()
        local v = s:sub(r.p, r.p + n - 1)
        r.p += n
        return v
    end
    function r.inter(n, size)
        local out, base = table.create(n), r.p
        if size == 4 then
            for i = 1, n do
                local o = base + i - 1
                out[i] = byte(s, o) * 16777216 + byte(s, o + n) * 65536 + byte(s, o + 2 * n) * 256 + byte(s, o + 3 * n)
            end
        else
            for i = 1, n do
                local o, v = base + i - 1, 0
                for j = 0, 7 do v = v * 256 + byte(s, o + j * n) end
                out[i] = v
            end
        end
        r.p = base + n * size
        return out
    end
    function r.uints(n) return r.inter(n, 4) end
    function r.ints(n)
        local a = r.inter(n, 4)
        for i = 1, n do a[i] = zz(a[i]) end
        return a
    end
    function r.ints64(n)
        local a = r.inter(n, 8)
        for i = 1, n do a[i] = zz(a[i]) end
        return a
    end
    function r.floats(n)
        local a = r.inter(n, 4)
        for i = 1, n do a[i] = unrot(a[i]) end
        return a
    end
    function r.refs(n)
        local a, acc = r.ints(n), 0
        for i = 1, n do acc += a[i]; a[i] = acc end
        return a
    end
    function r.bytesArr(n)
        local a = table.create(n)
        for i = 1, n do a[i] = byte(s, r.p + i - 1) end
        r.p += n
        return a
    end
    return r
end

---------------------------------------------------------------------
-- DECODER TIPE PROPERTI (id tipe -> function(reader, jumlah) -> array nilai)
---------------------------------------------------------------------
local function try(f, ...)
    local okT, v = pcall(f, ...)
    if okT then return v end
    return nil
end

local D = {}
D[0x01] = function(r, n)
    local t = table.create(n)
    for i = 1, n do t[i] = r.str() end
    return t
end
D[0x02] = function(r, n)
    local t = table.create(n)
    for i = 1, n do t[i] = r.u8() ~= 0 end
    return t
end
D[0x03] = function(r, n) return r.ints(n) end
D[0x04] = function(r, n) return r.floats(n) end
D[0x05] = function(r, n)
    local t = table.create(n)
    for i = 1, n do t[i] = r.f64() end
    return t
end
D[0x06] = function(r, n)
    local sc = r.floats(n)
    local of = r.ints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = UDim.new(sc[i], of[i]) end
    return t
end
D[0x07] = function(r, n)
    local sx = r.floats(n)
    local sy = r.floats(n)
    local ox = r.ints(n)
    local oy = r.ints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = UDim2.new(sx[i], ox[i], sy[i], oy[i]) end
    return t
end
D[0x0B] = function(r, n)
    local a = r.uints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = try(BrickColor.new, a[i]) end
    return t
end
D[0x0C] = function(r, n)
    local cr = r.floats(n)
    local cg = r.floats(n)
    local cb = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Color3.new(cr[i], cg[i], cb[i]) end
    return t
end
D[0x0D] = function(r, n)
    local x = r.floats(n)
    local y = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Vector2.new(x[i], y[i]) end
    return t
end
D[0x0E] = function(r, n)
    local x = r.floats(n)
    local y = r.floats(n)
    local z = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Vector3.new(x[i], y[i], z[i]) end
    return t
end
D[0x10] = function(r, n)
    local rots = table.create(n)
    for i = 1, n do
        local id = r.u8()
        if id == 0 then
            local m = table.create(9)
            for j = 1, 9 do m[j] = r.f32() end
            rots[i] = m
        else
            rots[i] = ROT[id] or ROT[0x02]
        end
    end
    local x = r.floats(n)
    local y = r.floats(n)
    local z = r.floats(n)
    local t = table.create(n)
    for i = 1, n do
        local m = rots[i]
        t[i] = try(CFrame.new, x[i], y[i], z[i], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
    end
    return t
end
D[0x12] = function(r, n)
    local a = r.uints(n)
    local t = table.create(n)
    for i = 1, n do t[i] = {enum = a[i]} end
    return t
end
D[0x14] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local x = r.i16()
        local y = r.i16()
        local z = r.i16()
        t[i] = Vector3int16.new(x, y, z)
    end
    return t
end
D[0x15] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local k = r.u32()
        local kp = {}
        for j = 1, k do
            local tm = r.f32()
            local v = r.f32()
            local env = r.f32()
            kp[j] = NumberSequenceKeypoint.new(tm, v, env)
        end
        t[i] = try(NumberSequence.new, kp)
    end
    return t
end
D[0x16] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local k = r.u32()
        local kp = {}
        for j = 1, k do
            local tm = r.f32()
            local cr, cg, cb = r.f32(), r.f32(), r.f32()
            r.f32()
            kp[j] = ColorSequenceKeypoint.new(tm, Color3.new(cr, cg, cb))
        end
        t[i] = try(ColorSequence.new, kp)
    end
    return t
end
D[0x17] = function(r, n)
    local t = table.create(n)
    for i = 1, n do
        local mn = r.f32()
        local mx = r.f32()
        t[i] = NumberRange.new(mn, mx)
    end
    return t
end
D[0x18] = function(r, n)
    local x0 = r.floats(n)
    local y0 = r.floats(n)
    local x1 = r.floats(n)
    local y1 = r.floats(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Rect.new(x0[i], y0[i], x1[i], y1[i]) end
    return t
end
D[0x1A] = function(r, n)
    local cr = r.bytesArr(n)
    local cg = r.bytesArr(n)
    local cb = r.bytesArr(n)
    local t = table.create(n)
    for i = 1, n do t[i] = Color3.fromRGB(cr[i], cg[i], cb[i]) end
    return t
end
D[0x1B] = function(r, n) return r.ints64(n) end

---------------------------------------------------------------------
-- BANTUAN SET PROPERTI
---------------------------------------------------------------------
local enumCache = {}
local function enumItem(enumType, value)
    local map = enumCache[enumType]
    if not map then
        map = {}
        for _, it in ipairs(enumType:GetEnumItems()) do map[it.Value] = it end
        enumCache[enumType] = map
    end
    return map[value]
end

local function setValue(inst, name, val)
    name = ALIAS[name] or name
    if SKIP_PROP[name] or val == nil then return end
    if type(val) == "table" and val.enum then
        local okR, cur = pcall(function() return inst[name] end)
        if okR and typeof(cur) == "EnumItem" then
            local it = enumItem(cur.EnumType, val.enum)
            if it then pcall(function() inst[name] = it end) end
        end
        return
    end
    local okS = pcall(function() inst[name] = val end)
    if not okS and name == "Source" and type(sethiddenproperty) == "function" then
        pcall(sethiddenproperty, inst, "Source", val)
    end
end

local meshCache = {}
local function makeMeshPart(id)
    if meshCache[id] ~= nil then
        return meshCache[id] and meshCache[id]:Clone() or nil
    end
    local okM, mp = pcall(function()
        return InsertService:CreateMeshPartAsync(id, Enum.CollisionFidelity.Default, Enum.RenderFidelity.Automatic)
    end)
    if not (okM and mp) and UI.ResolveMesh then
        local ok2, res = pcall(UI.ResolveMesh, id)
        if ok2 and typeof(res) == "Instance" then mp, okM = res, true end
    end
    meshCache[id] = (okM and mp) and mp or false
    return meshCache[id] and meshCache[id]:Clone() or nil
end

---------------------------------------------------------------------
-- IMPORTER UTAMA
---------------------------------------------------------------------
local function importRbx(data, opts, report)
    local head = data:sub(1, 8)
    if head == "<roblox " then
        error("Format XML (.rbxlx/.rbxmx) belum didukung, simpan sebagai .rbxl biner", 0)
    end
    if data:sub(1, 14) ~= "<roblox!\137\255\r\n\26\n" then
        error("Bukan file RBXL/RBXM biner", 0)
    end

    local total = #data
    local rd = newReader(data)
    rd.p = 21
    local totalInst = rd.u32()
    rd.p = 33

    local classes, objs, isSvc, deferred, pending = {}, {}, {}, {}, {}
    local parentData
    local stat = {created = 0, skipped = 0, meshFallback = 0, skippedClasses = {}}
    local lastYield = os.clock()
    local function tick()
        if os.clock() - lastYield > 0.03 then task.wait(); lastYield = os.clock() end
    end

    local function apply(ref, name, val)
        local d = deferred[ref]
        if d then d.props[name] = val return end
        local inst = objs[ref]
        if not inst then return end
        if isSvc[ref] and not opts.serviceProps then return end
        setValue(inst, name, val)
    end

    -- 1) baca chunk satu per satu
    while rd.p <= total - 15 do
        local cname = data:sub(rd.p, rd.p + 3)
        rd.p += 4
        local clen = rd.u32()
        local ulen = rd.u32()
        rd.p += 4
        local payload
        if clen == 0 then
            payload = data:sub(rd.p, rd.p + ulen - 1)
            rd.p += ulen
        else
            payload = decompress(data:sub(rd.p, rd.p + clen - 1), ulen)
            rd.p += clen
        end
        if cname == "END\0" then break end

        local cr = newReader(payload)
        if cname == "INST" then
            local id = cr.u32()
            local className = cr.str()
            local hasService = cr.u8()
            local n = cr.u32()
            local refs = cr.refs(n)
            classes[id] = {name = className, refs = refs}
            for _, ref in ipairs(refs) do
                if hasService == 1 then
                    local okS, svc = pcall(game.GetService, game, className)
                    isSvc[ref] = true
                    objs[ref] = (okS and svc and not UI.ImportSkipServices[className]) and svc or false
                elseif SKIP_CLASS[className] then
                    objs[ref] = false
                    stat.skipped += 1
                elseif className == "MeshPart" then
                    objs[ref] = false
                    deferred[ref] = {props = {}}
                else
                    local okI, inst = pcall(Instance.new, className)
                    if okI and inst then
                        objs[ref] = inst
                        stat.created += 1
                    else
                        objs[ref] = false
                        stat.skipped += 1
                        stat.skippedClasses[className] = (stat.skippedClasses[className] or 0) + 1
                    end
                end
            end
        elseif cname == "PROP" then
            local cls = classes[cr.u32()]
            local pname = cr.str()
            local tid = cr.u8()
            if cls then
                local n = #cls.refs
                if tid == 0x13 then
                    local okR, targets = pcall(cr.refs, n)
                    if okR then
                        for i = 1, n do pending[#pending + 1] = {cls.refs[i], pname, targets[i]} end
                    end
                elseif D[tid] then
                    local okD, vals = pcall(D[tid], cr, n)
                    if okD and vals then
                        for i = 1, n do apply(cls.refs[i], pname, vals[i]) end
                    end
                end
            end
        elseif cname == "PRNT" then
            cr.u8()
            local n = cr.u32()
            local childs = cr.refs(n)
            local parents = cr.refs(n)
            parentData = {childs, parents, n}
        end
        report(5 + 60 * (rd.p / total), "Membaca map...", "Memproses data (" .. fmt(totalInst) .. " instance di file)")
        tick()
    end
    if not parentData then error("Struktur file tidak lengkap (PRNT tidak ditemukan)", 0) end

    -- 2) bangun MeshPart yang tertunda
    local meshRefs = {}
    for ref in pairs(deferred) do meshRefs[#meshRefs + 1] = ref end
    for i, ref in ipairs(meshRefs) do
        local d = deferred[ref]
        local id = d.props.MeshId
        local inst
        if type(id) == "string" and id ~= "" then inst = makeMeshPart(id) end
        if inst then
            stat.created += 1
        else
            inst = Instance.new("Part")
            stat.meshFallback += 1
        end
        objs[ref] = inst
        for k, v in pairs(d.props) do
            if k ~= "MeshId" then setValue(inst, k, v) end
        end
        report(65 + 15 * (i / #meshRefs), "Memuat mesh...", i .. " / " .. #meshRefs)
        tick()
    end

    -- 3) properti referensi (Part0, Part1, PrimaryPart, dll)
    for _, pr in ipairs(pending) do
        local inst, target = objs[pr[1]], objs[pr[3]]
        if inst and target and not isSvc[pr[1]] then
            pcall(function() inst[pr[2]] = target end)
        end
    end

    -- 4) mode Studio Lite: anchor + simpan nilai asli di atribut SL_
    if opts.studioMode then
        for ref, inst in pairs(objs) do
            if inst and not isSvc[ref] and inst:IsA("BasePart") then
                pcall(function()
                    if inst:GetAttribute("SL_Anchored") == nil then
                        inst:SetAttribute("SL_Anchored", inst.Anchored)
                        inst:SetAttribute("SL_CanCollide", inst.CanCollide)
                    end
                    inst.Anchored = true
                end)
            end
        end
    end

    -- 5) susun hierarki: bagian dalam dulu, baru ditempel ke service
    local childs, parents, n = parentData[1], parentData[2], parentData[3]
    for i = 1, n do
        local cRef, pRef = childs[i], parents[i]
        local c = objs[cRef]
        if c and not isSvc[cRef] and pRef ~= -1 and not isSvc[pRef] then
            local p = objs[pRef]
            if p then pcall(function() c.Parent = p end) end
        end
        if i % 500 == 0 then
            report(80 + 10 * (i / n), "Menyusun hierarki...", fmt(i) .. " / " .. fmt(n))
            tick()
        end
    end
    local attached = 0
    for i = 1, n do
        local cRef, pRef = childs[i], parents[i]
        local c = objs[cRef]
        if c and not isSvc[cRef] and (pRef == -1 or isSvc[pRef]) then
            local p = (pRef == -1) and workspace or objs[pRef]
            if p and not UI.ImportSkipNames[c.Name] then
                if pcall(function() c.Parent = p end) then attached += 1 end
            end
        end
        if i % 500 == 0 then
            report(90 + 10 * (i / n), "Menempel ke game...", fmt(i) .. " / " .. fmt(n))
            tick()
        end
    end
    stat.attached = attached
    return stat
end

---------------------------------------------------------------------
-- IMPORT VIA GetObjects (cara utama; parser biner di atas jadi cadangan)
---------------------------------------------------------------------
local function assetCandidates(path)
    local c, seen = {}, {}
    local function add(x)
        if x and x ~= "" and not seen[x] then seen[x] = true; c[#c + 1] = x end
    end
    local p = path:gsub("\\", "/")
    add(p)
    for _, pre in ipairs({"workspace/", "Delta/workspace/", "delta/workspace/",
        "Android/Delta/workspace/", "/sdcard/Delta/workspace/", "/sdcard/Android/Delta/workspace/"}) do
        if p:sub(1, #pre):lower() == pre:lower() then add(p:sub(#pre + 1)) end
    end
    add(p:match("[^/]+$"))
    return c
end

local function importViaAsset(path, opts, report)
    local getAsset = getcustomasset or getsynasset
    if type(getAsset) ~= "function" then
        return nil, "getcustomasset tidak tersedia"
    end
    local lastErr = "GetObjects tidak mengembalikan apa-apa"
    local objects
    for _, cand in ipairs(assetCandidates(path)) do
        local okA, asset = pcall(getAsset, cand)
        if okA and asset then
            local okO, res = pcall(function() return game:GetObjects(asset) end)
            if okO and type(res) == "table" and #res > 0 then
                objects = res
                break
            end
            lastErr = okO and lastErr or tostring(res)
        else
            lastErr = tostring(asset)
        end
    end
    if not objects then return nil, lastErr end

    -- periksa isi sebelum menempel: harus ada part / script
    local nParts, nScripts, summary = 0, 0, {}
    for _, obj in ipairs(objects) do
        local okD, d = pcall(obj.GetDescendants, obj)
        d = okD and d or {}
        for _, inst in ipairs(d) do
            if inst:IsA("BasePart") then nParts += 1
            elseif inst:IsA("LuaSourceContainer") then nScripts += 1 end
        end
        summary[#summary + 1] = obj.ClassName .. "=" .. (#d + 1)
    end
    local summaryTxt = table.concat(summary, ", ")
    pcall(warn, ("[CopyMap] GetObjects: %d part, %d script | %s"):format(nParts, nScripts, summaryTxt))
    if nParts == 0 and nScripts == 0 then
        return nil, "GetObjects tanpa part/script (" .. summaryTxt .. ")"
    end

    local stat = {created = 0, skipped = 0, meshFallback = 0, attached = 0,
        parts = nParts, scripts = nScripts}
    report(40, "Menempelkan ke game...", fmt(#objects) .. " objek level atas")

    local function place(inst, parent)
        if UI.ImportSkipNames[inst.Name] then stat.skipped += 1 return end
        if pcall(function() inst.Parent = parent end) then stat.attached += 1 else stat.skipped += 1 end
    end

    local lastYield = os.clock()
    for i, obj in ipairs(objects) do
        -- hasil GetObjects dari .rbxl biasanya berupa kontainer bernama service
        local okS, svc = pcall(game.GetService, game, obj.ClassName)
        if okS and svc then
            if not UI.ImportSkipServices[obj.ClassName] then
                for _, ch in ipairs(obj:GetChildren()) do place(ch, svc) end
            end
        else
            place(obj, workspace)
        end
        if os.clock() - lastYield > 0.03 then
            report(40 + 50 * (i / #objects), "Menempelkan ke game...", fmt(i) .. " / " .. fmt(#objects))
            task.wait(); lastYield = os.clock()
        end
    end

    local count = 0
    for _, obj in ipairs(objects) do
        count += 1
        local okD, d = pcall(obj.GetDescendants, obj)
        if okD then count += #d end
    end
    stat.created = count

    if opts.studioMode then
        report(92, "Mode Studio Lite...", "Anchor part")
        for _, obj in ipairs(objects) do
            local okD, d = pcall(obj.GetDescendants, obj)
            for _, inst in ipairs(okD and d or {}) do
                if inst:IsA("BasePart") then
                    pcall(function()
                        if inst:GetAttribute("SL_Anchored") == nil then
                            inst:SetAttribute("SL_Anchored", inst.Anchored)
                            inst:SetAttribute("SL_CanCollide", inst.CanCollide)
                        end
                        inst.Anchored = true
                    end)
                end
            end
        end
    end
    return stat
end

---------------------------------------------------------------------
-- DAFTAR FILE + TOMBOL IMPORT
---------------------------------------------------------------------
local impBusy, impRunning, impT0 = false, false, 0
local selectedFile
local impCards = {}

local function fileBase(p)
    return ((p:gsub("\\", "/")):match("[^/]+$")) or p
end

local function impReport(pct, title, sub)
    pct = math.clamp(pct or 0, 0, 100)
    TweenService:Create(impBar, TweenInfo.new(0.2), {Size = UDim2.fromScale(pct / 100, 1)}):Play()
    impPct.Text = math.floor(pct) .. "%"
    if title then impTitle.Text = title end
    if sub then impSub.Text = sub end
    if pct >= 100 then
        impRunning = false
        impTime.Text = mmss(os.clock() - impT0)
    end
end

local function impBegin()
    impRunning, impT0 = true, os.clock()
    task.spawn(function()
        while impRunning and gui.Parent do
            impTime.Text = mmss(os.clock() - impT0)
            task.wait(0.25)
        end
    end)
end

local function findMapFiles()
    local seen, out = {}, {}
    if type(listfiles) ~= "function" then return out end
    for _, dir in ipairs({"", ".", "workspace"}) do
        local okL, files = pcall(listfiles, dir)
        if okL and type(files) == "table" then
            for _, p in ipairs(files) do
                local low = p:lower()
                local key = fileBase(low)
                if (low:match("%.rbxl$") or low:match("%.rbxm$")) and not seen[key] then
                    seen[key] = true
                    out[#out + 1] = p
                end
            end
        end
    end
    table.sort(out, function(a, b) return fileBase(a):lower() < fileBase(b):lower() end)
    return out
end

local function paintFiles()
    for _, c in ipairs(impCards) do
        if c.path then
            local on = c.path == selectedFile
            c.stroke.Color = on and T.Accent or T.Line
            c.stroke.Thickness = on and 1.6 or 1
            c.circle.BackgroundColor3 = on and T.Accent or T.Field
            c.dot.Visible = on
        end
    end
end

local function selectFile(p)
    selectedFile = p
    valFile.Text = fileBase(p)
    valSize.Text = "-"
    valInst.Text = "-"
    valStat.Text = "Siap import"
    paintFiles()
end

local function refreshFiles()
    for _, c in ipairs(impCards) do c.frame:Destroy() end
    impCards = {}
    local files = findMapFiles()
    lblFileCount.Text = #files .. " file"
    if #files == 0 then
        local lbl = label(impList, {
            Text = "Belum ada file .rbxl di folder workspace executor.\nCopy map dulu, lalu tekan MUAT ULANG.",
            TextSize = 9, TextColor3 = T.Muted, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 60),
        })
        impCards[1] = {frame = lbl}
        return
    end
    for idx, p in ipairs(files) do
        local card = new("Frame", {
            Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = idx,
        }, impList)
        corner(card, 12)
        local st = stroke(card, T.Line, 1)
        label(card, {Text = fileBase(p), Font = Enum.Font.GothamBold, TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(16, 9), Size = UDim2.new(1, -66, 0, 18)})
        label(card, {Text = p:lower():match("%.rbxm$") and "Model biner (.rbxm)" or "Place biner (.rbxl)",
            TextSize = 9, TextColor3 = T.Muted,
            Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -66, 0, 14)})
        local circle = new("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(28, 28), BackgroundColor3 = T.Field, BorderSizePixel = 0,
        }, card)
        corner(circle, 14)
        local dot = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(8, 8), BackgroundColor3 = T.Text, BorderSizePixel = 0, Visible = false,
        }, circle)
        corner(dot, 4)
        local hit = new("TextButton", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3,
        }, card)
        hit.MouseButton1Click:Connect(function() selectFile(p) end)
        impCards[#impCards + 1] = {frame = card, stroke = st, circle = circle, dot = dot, path = p}
    end
    -- pertahankan pilihan lama kalau filenya masih ada
    local still = false
    for _, p in ipairs(files) do if p == selectedFile then still = true end end
    if still then paintFiles() elseif #files == 1 then selectFile(files[1]) else selectedFile = nil end
end

UI.OnImport = function(path, opts)
    if impBusy then return end
    impBusy = true
    impBar.BackgroundColor3 = T.Accent

    local function fail(title, sub)
        impRunning = false
        impBar.BackgroundColor3 = T.Bad
        impReport(100, title, sub)
        impPct.Text = "GAGAL"
        valStat.Text = "Gagal"
        impBusy = false
    end

    if type(readfile) ~= "function" then
        return fail("Executor tidak didukung", "Fungsi readfile tidak ditemukan")
    end
    valStat.Text = "Membaca..."
    impReport(2, "Membaca file...", fileBase(path))
    local okR, data = pcall(readfile, path)
    if not okR or type(data) ~= "string" or #data == 0 then
        return fail("File tidak bisa dibaca", tostring(data):sub(1, 70))
    end
    valSize.Text = string.format("%.2f MB", #data / 1048576)

    impReport(10, "Mencoba import (GetObjects)...", fileBase(path))
    local res, assetErr = importViaAsset(path, opts or {}, impReport)
    if not res then
        pcall(warn, "[CopyMap] GetObjects gagal: " .. tostring(assetErr))
        impReport(12, "Cadangan: parser biner...", tostring(assetErr):sub(1, 60))
        local okI, r2 = pcall(importRbx, data, opts or {}, impReport)
        if not okI then
            pcall(warn, "[CopyMap] Parser biner gagal: " .. tostring(r2))
            return fail("Import gagal",
                "GetObjects: " .. tostring(assetErr):sub(1, 40) .. " | Parser: " .. (tostring(r2):gsub("^[^:]*:%d+: ", "")):sub(1, 70))
        end
        res = r2
    end

    valInst.Text = fmt(res.created)
    valStat.Text = "Selesai"
    local sub = fmt(res.created) .. " instance dibuat"
    if res.meshFallback > 0 then
        sub ..= ", " .. res.meshFallback .. " mesh jadi Part biasa"
    end
    if res.skipped > 0 then
        sub ..= ", " .. res.skipped .. " dilewati"
    end
    if res.parts then
        sub ..= " (" .. res.parts .. " part, " .. res.scripts .. " script)"
    end
    impReport(100, "Import selesai", sub)
    impBusy = false
end

btnImport.MouseButton1Click:Connect(function()
    if impBusy then return end
    if not selectedFile then
        impTitle.Text = "Belum ada file dipilih"
        impSub.Text = "Pilih file di daftar sebelah kiri"
        return
    end
    if not UI.OnImport then return end
    impReport(0, "Memulai import...", fileBase(selectedFile))
    impBegin()
    task.spawn(UI.OnImport, selectedFile, {studioMode = getStudioMode(), serviceProps = getSvcProps()})
end)

btnRefresh.MouseButton1Click:Connect(refreshFiles)
tabImport.MouseButton1Click:Connect(refreshFiles)
pcall(refreshFiles)

---------------------------------------------------------------------
-- FITUR: IMAGE 3D  (gambar -> 1 Model berisi Part berwarna)
-- Dipindah dari plugin "NX Image 3D". Model hanya dibuat di sisi client
-- (terlihat olehmu saja). Sumber: Asset ID atau file png/jpg di folder workspace executor.
---------------------------------------------------------------------
local function buildImageTab()
    local AssetService = game:GetService("AssetService")

    local MAX_PARTS, MAX_COLS, RELIEF_STEPS = 8000, 256, 6
    local LEVELS = {
        {name = "PENUH", n = 256}, {name = "16", n = 16}, {name = "8", n = 8}, {name = "4", n = 4},
    }
    local MODES = {"RATA", "RELIEF", "TERBALIK"}
    local MODE_DESC = {
        "RATA: semua sel sama tebal, seperti stiker 3D.",
        "RELIEF: bagian terang lebih tebal, bagian gelap lebih tipis.",
        "TERBALIK: bagian gelap lebih tebal, bagian terang lebih tipis.",
    }
    local SHAPES = {"KOTAK", "BOLA"}
    local BG_MODES = {"LATAR: TRANSPARAN SAJA", "LATAR: BUANG PUTIH", "LATAR: BUANG HITAM"}
    local MATERIALS = {"Plastic", "SmoothPlastic", "Neon", "Metal", "Wood", "Marble", "Granite", "Concrete", "Brick", "Glass"}

    local state = {
        cols = 96, cell = 1, depth = 1,
        levelsIndex = 1, modeIndex = 1, shapeIndex = 1, bgIndex = 1, materialIndex = 1,
        straight = false, crop = true, alphaCut = 25,
    }

    local page = imagePage

    ---------------------------------------------------------------
    -- UI: panel kiri (sumber gambar)
    ---------------------------------------------------------------
    local left = new("Frame", {
        Position = UDim2.fromOffset(14, 30), Size = UDim2.fromOffset(290, 340),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0,
    }, page)
    corner(left, 14)
    stroke(left, T.Line, 1)

    local idBox = new("TextBox", {
        Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -96, 0, 30),
        BackgroundColor3 = T.Field, BorderSizePixel = 0, Text = "",
        PlaceholderText = "Asset ID gambar", PlaceholderColor3 = T.Muted,
        TextColor3 = T.Text, TextSize = 10, Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
    }, left)
    corner(idBox, 10)
    stroke(idBox, T.Line, 1)
    new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6)}, idBox)

    local btnLoadId = button(left, {
        Text = "MUAT", Position = UDim2.new(1, -78, 0, 12), Size = UDim2.fromOffset(66, 30),
        BackgroundColor3 = T.Accent, TextSize = 9,
    })
    corner(btnLoadId, 10)

    local btnRefreshImg = button(left, {
        Text = "MUAT ULANG DAFTAR FILE", Position = UDim2.fromOffset(12, 50),
        Size = UDim2.new(1, -24, 0, 28), BackgroundColor3 = T.Field, TextSize = 8,
    })
    corner(btnRefreshImg, 10)
    stroke(btnRefreshImg, T.Line, 1)

    local imgList = new("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 86), Size = UDim2.new(1, -16, 1, -94),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.AccentLn, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, left)
    new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, imgList)
    new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4)}, imgList)

    ---------------------------------------------------------------
    -- UI: panel kanan (preview, pengaturan, tombol buat)
    ---------------------------------------------------------------
    local previewFrame = new("Frame", {
        Position = UDim2.fromOffset(316, 30), Size = UDim2.fromOffset(430, 124),
        BackgroundColor3 = Color3.fromRGB(84, 88, 98), BorderSizePixel = 0, ClipsDescendants = true,
    }, page)
    corner(previewFrame, 14)
    stroke(previewFrame, T.Line, 1)

    local previewImg = new("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -16, 1, -16), BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit, Visible = false,
    }, previewFrame)
    pcall(function() previewImg.ResampleMode = Enum.ResamplerMode.Pixelated end)

    local previewNote = label(previewFrame, {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -24, 0, 32), Text = "Muat gambar dulu (Asset ID atau pilih file).",
        TextColor3 = Color3.new(1, 1, 1), TextSize = 10, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local infoLbl = label(page, {
        Position = UDim2.fromOffset(316, 158), Size = UDim2.fromOffset(430, 14),
        Text = "Belum ada gambar.", TextSize = 9, TextColor3 = T.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- tab kecil: UKURAN | MODE | WARNA | TAMPILAN
    local TAB_NAMES = {"UKURAN", "MODE", "WARNA", "TAMPILAN"}
    local miniBar = new("Frame", {
        Position = UDim2.fromOffset(316, 176), Size = UDim2.fromOffset(430, 26),
        BackgroundColor3 = T.Field, BorderSizePixel = 0,
    }, page)
    corner(miniBar, 13)
    stroke(miniBar, T.Line, 1)

    local pages, miniBtns = {}, {}
    local function showMini(idx)
        for i, pg in ipairs(pages) do
            pg.Visible = i == idx
            miniBtns[i].BackgroundColor3 = i == idx and T.Accent or T.Field
            miniBtns[i].TextColor3 = i == idx and T.Text or T.Muted
        end
    end
    for i, name in ipairs(TAB_NAMES) do
        local b = new("TextButton", {
            Text = name, Size = UDim2.new(1 / #TAB_NAMES, -4, 1, -4),
            Position = UDim2.new((i - 1) / #TAB_NAMES, 2, 0, 2),
            BackgroundColor3 = T.Field, BorderSizePixel = 0, AutoButtonColor = false,
            Font = Enum.Font.GothamBold, TextSize = 8, TextColor3 = T.Muted,
        }, miniBar)
        corner(b, 11)
        miniBtns[i] = b
        local holder = new("Frame", {
            Position = UDim2.fromOffset(316, 206), Size = UDim2.fromOffset(430, 94),
            BackgroundColor3 = T.Card, BorderSizePixel = 0, Visible = false,
        }, page)
        corner(holder, 12)
        stroke(holder, T.Line, 1)
        local inner = new("Frame", {
            Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 1, -16), BackgroundTransparency = 1,
        }, holder)
        pages[i] = holder
        b.MouseButton1Click:Connect(function() showMini(i) end)
    end
    local function innerOf(i) return pages[i]:FindFirstChildOfClass("Frame") end

    local imgStatus = label(page, {
        Position = UDim2.fromOffset(316, 304), Size = UDim2.fromOffset(430, 16),
        Text = "Siap.", TextSize = 9, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Center,
    })
    local function setStatus(msg, color)
        imgStatus.Text = msg
        imgStatus.TextColor3 = color or T.Muted
    end

    local btnBuild = button(page, {
        Text = "BUAT GAMBAR 3D", Position = UDim2.fromOffset(316, 326), Size = UDim2.fromOffset(430, 44),
        BackgroundColor3 = T.Accent, TextSize = 12,
    })
    corner(btnBuild, 12)

    ---------------------------------------------------------------
    -- Helper UI kecil
    ---------------------------------------------------------------
    local function chipRow(parent, names, y, getIndex, onPick)
        local chips, n = {}, #names
        local function paint()
            for i, c in ipairs(chips) do
                local on = i == getIndex()
                c.BackgroundColor3 = on and T.Accent or T.Field
                c.TextColor3 = on and T.Text or T.Muted
            end
        end
        for i, name in ipairs(names) do
            local c = new("TextButton", {
                Text = name, Size = UDim2.new(1 / n, -6, 0, 26), Position = UDim2.new((i - 1) / n, 3, 0, y),
                BackgroundColor3 = T.Field, BorderSizePixel = 0, AutoButtonColor = false,
                Font = Enum.Font.GothamBold, TextSize = 9,
            }, parent)
            corner(c, 13)
            chips[i] = c
            c.MouseButton1Click:Connect(function() onPick(i); paint() end)
        end
        paint()
        return paint
    end

    local function toggleBtn(parent, x, y, wScale, wOff)
        local b = new("TextButton", {
            Position = UDim2.new(x, 3, 0, y), Size = UDim2.new(wScale, wOff, 0, 26),
            BackgroundColor3 = T.Field, BorderSizePixel = 0, AutoButtonColor = false,
            Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = T.Text,
        }, parent)
        corner(b, 13)
        return b
    end

    local function field(parent, caption, default, xScale, wScale)
        local holder = new("Frame", {
            Position = UDim2.new(xScale, 0, 0, 0), Size = UDim2.new(wScale, -6, 0, 42),
            BackgroundTransparency = 1,
        }, parent)
        label(holder, {Text = caption, TextSize = 8, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 12)})
        local box = new("TextBox", {
            Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = T.Field, BorderSizePixel = 0, Text = tostring(default),
            TextColor3 = T.Text, TextSize = 11, Font = Enum.Font.GothamBold, ClearTextOnFocus = false,
        }, holder)
        corner(box, 10)
        stroke(box, T.Line, 1)
        return box
    end

    ---------------------------------------------------------------
    -- Pipeline gambar: baca pixel -> sel -> grid warna -> kotak
    ---------------------------------------------------------------
    local source, cells, grid = nil, nil, nil   -- source = {w, h, buf, bbox}
    local cellsDirty = true
    local previewEI = nil

    local lastYield = os.clock()
    local function tick()
        if os.clock() - lastYield > 0.03 then task.wait(); lastYield = os.clock() end
    end

    local function findBounds(buf, w, h)
        local minX, minY, maxX, maxY = w, h, -1, -1
        for y = 0, h - 1 do
            local rowStart = y * w * 4
            for x = 0, w - 1 do
                if buffer.readu8(buf, rowStart + x * 4 + 3) >= 16 then
                    if x < minX then minX = x end
                    if x > maxX then maxX = x end
                    if y < minY then minY = y end
                    maxY = y
                end
            end
            if y % 16 == 0 then tick() end
        end
        if maxX < 0 then return nil end
        return {minX, minY, maxX + 1, maxY + 1}
    end

    local function readEditable(ei)
        local size = ei.Size
        local w, h = size.X, size.Y
        local buf
        local okB, res = pcall(function() return ei:ReadPixelsBuffer(Vector2.zero, size) end)
        if okB and res then
            buf = res
        else
            local okP, px = pcall(function() return ei:ReadPixels(Vector2.zero, size) end)
            if not (okP and type(px) == "table") then
                error("ReadPixels gagal: " .. tostring(res), 0)
            end
            buf = buffer.create(w * h * 4)
            for i = 1, w * h * 4 do
                buffer.writeu8(buf, i - 1, math.clamp(math.floor((px[i] or 0) * 255 + 0.5), 0, 255))
                if i % 20000 == 0 then tick() end
            end
        end
        return {w = w, h = h, buf = buf, bbox = findBounds(buf, w, h)}
    end

    local function createEditable(uri)
        local ok, ei = pcall(function() return AssetService:CreateEditableImageAsync(Content.fromUri(uri)) end)
        if ok and ei then return ei end
        local ok2, ei2 = pcall(function() return AssetService:CreateEditableImageAsync(uri) end)
        if ok2 and ei2 then return ei2 end
        return nil, tostring(ei)
    end

    local function tryLoadUri(uri)
        if type(buffer) ~= "table" then return nil, "Executor tidak punya library buffer" end
        local ei, err = createEditable(uri)
        if not ei then return nil, err end
        local ok2, data = pcall(readEditable, ei)
        pcall(function() ei:Destroy() end)
        if not ok2 then return nil, tostring(data) end
        return data
    end

    local function loadFromId(idText)
        local id = tostring(idText):match("%d+")
        if not id then return nil, "Asset ID tidak valid." end
        local data, err = tryLoadUri("rbxassetid://" .. id)
        if data then return data end
        -- mungkin itu ID Decal: ambil ID gambarnya
        local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
        if ok and type(objs) == "table" and objs[1] then
            local texture = ""
            for _, o in ipairs(objs) do
                local d = o:IsA("Decal") and o or o:FindFirstChildWhichIsA("Decal", true)
                if d then texture = d.Texture break end
            end
            for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
            local imageId = tostring(texture):match("%d+")
            if imageId and imageId ~= id then
                local data2, err2 = tryLoadUri("rbxassetid://" .. imageId)
                if data2 then return data2 end
                err = err2
            end
        end
        return nil, err
    end

    local function loadFromFile(path)
        local getAsset = getcustomasset or getsynasset
        if type(getAsset) ~= "function" then return nil, "getcustomasset tidak tersedia" end
        local lastErr = "file tidak bisa dibuka"
        for _, cand in ipairs(assetCandidates(path)) do
            local okA, asset = pcall(getAsset, cand)
            if okA and asset then
                local data, err = tryLoadUri(asset)
                if data then return data end
                lastErr = err
            else
                lastErr = tostring(asset)
            end
        end
        return nil, lastErr
    end

    local function resample()
        cells = nil
        if not source then return end
        local sw, buf = source.w, source.buf
        local x0, y0, x1, y1 = 0, 0, source.w, source.h
        if state.crop and source.bbox then
            x0, y0, x1, y1 = source.bbox[1], source.bbox[2], source.bbox[3], source.bbox[4]
        end
        local rw, rh = x1 - x0, y1 - y0
        local cols = state.cols
        local rows = math.max(1, math.floor(cols * rh / rw + 0.5))
        local total = cols * rows
        local SR, SG, SB = table.create(total, 0), table.create(total, 0), table.create(total, 0)
        local SA, CN = table.create(total, 0), table.create(total, 0)
        local step = math.max(1, math.ceil(math.sqrt(rw * rh / 1500000)))
        local colOf = {}
        for x = 0, rw - 1, step do
            colOf[x] = math.min(cols - 1, math.floor(x * cols / rw))
        end
        for y = 0, rh - 1, step do
            local cy = math.min(rows - 1, math.floor(y * rows / rh))
            local rowBase = cy * cols + 1
            local o0 = ((y0 + y) * sw + x0) * 4
            for x = 0, rw - 1, step do
                local idx = rowBase + colOf[x]
                local o = o0 + x * 4
                local a = buffer.readu8(buf, o + 3)
                SA[idx] += a
                CN[idx] += 1
                if a > 0 then
                    SR[idx] += buffer.readu8(buf, o) * a
                    SG[idx] += buffer.readu8(buf, o + 1) * a
                    SB[idx] += buffer.readu8(buf, o + 2) * a
                end
            end
            if y % 8 == 0 then tick() end
        end
        local R, G, B, A = {}, {}, {}, {}
        for idx = 1, total do
            local sa, cn = SA[idx], CN[idx]
            if sa > 0 then
                R[idx], G[idx], B[idx] = SR[idx] / sa, SG[idx] / sa, SB[idx] / sa
            else
                R[idx], G[idx], B[idx] = 0, 0, 0
            end
            A[idx] = cn > 0 and sa / cn or 0
        end
        cells = {cols = cols, rows = rows, r = R, g = G, b = B, a = A}
    end

    local function quantize(v, n)
        if n >= 256 then return math.clamp(math.floor(v + 0.5), 0, 255) end
        return math.clamp(math.floor(math.floor(v / 255 * (n - 1) + 0.5) / (n - 1) * 255 + 0.5), 0, 255)
    end

    local function computeGrid()
        grid = nil
        if not cells then return end
        local cols, rows = cells.cols, cells.rows
        local n = LEVELS[state.levelsIndex].n
        local keys, colors, depths = {}, {}, {}
        local filled = 0
        for idx = 1, cols * rows do
            local r, g, b = cells.r[idx], cells.g[idx], cells.b[idx]
            local lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
            local skip = cells.a[idx] < state.alphaCut * 2.55
            if not skip and state.bgIndex == 2 and lum > 0.93 then skip = true end
            if not skip and state.bgIndex == 3 and lum < 0.07 then skip = true end
            if skip then
                keys[idx] = 0
            else
                local packed = quantize(r, n) * 65536 + quantize(g, n) * 256 + quantize(b, n)
                local d = RELIEF_STEPS
                if state.modeIndex == 2 then
                    d = math.max(1, math.floor(lum * RELIEF_STEPS + 0.5))
                elseif state.modeIndex == 3 then
                    d = math.max(1, math.floor((1 - lum) * RELIEF_STEPS + 0.5))
                end
                keys[idx] = packed * 16 + d
                colors[idx] = packed
                depths[idx] = d
                filled += 1
            end
            if idx % 4000 == 0 then tick() end
        end
        grid = {cols = cols, rows = rows, key = keys, color = colors, depth = depths, filled = filled}
    end

    -- gabungkan sel yang sama (warna + tebal) jadi kotak besar supaya part sedikit
    local function buildRects()
        local rects = {}
        if not grid then return rects end
        local cols, rows = grid.cols, grid.rows
        local merge = state.shapeIndex == 1
        local open = {}
        for y = 0, rows - 1 do
            local nextOpen = {}
            local x = 0
            while x < cols do
                local startIdx = y * cols + x + 1
                local k = grid.key[startIdx]
                if k ~= 0 then
                    local start = x
                    while merge and x < cols - 1 and grid.key[y * cols + x + 2] == k do
                        x += 1
                    end
                    local sig = start .. "," .. x .. "," .. k
                    local prev = merge and open[sig] or nil
                    if prev then
                        prev.h += 1
                        nextOpen[sig] = prev
                    else
                        local rect = {
                            x = start, y = y, w = x - start + 1, h = 1,
                            color = grid.color[startIdx], depth = grid.depth[startIdx],
                        }
                        table.insert(rects, rect)
                        nextOpen[sig] = rect
                    end
                end
                x += 1
            end
            open = nextOpen
            if y % 8 == 0 then tick() end
        end
        return rects
    end

    local function drawPreview()
        if not grid then
            previewImg.Visible = false
            previewNote.Visible = true
            return
        end
        local cols, rows = grid.cols, grid.rows
        local ok = pcall(function()
            if previewEI == nil or previewEI.Size ~= Vector2.new(cols, rows) then
                if previewEI then previewEI:Destroy() end
                previewEI = AssetService:CreateEditableImage({Size = Vector2.new(cols, rows)})
                previewImg.ImageContent = Content.fromObject(previewEI)
            end
            local buf = buffer.create(cols * rows * 4)
            for idx = 1, cols * rows do
                if grid.key[idx] ~= 0 then
                    local c = grid.color[idx]
                    local shade = 1
                    if state.modeIndex ~= 1 then
                        shade = 0.45 + 0.55 * grid.depth[idx] / RELIEF_STEPS
                    end
                    local o = (idx - 1) * 4
                    buffer.writeu8(buf, o, math.floor(math.floor(c / 65536) % 256 * shade))
                    buffer.writeu8(buf, o + 1, math.floor(math.floor(c / 256) % 256 * shade))
                    buffer.writeu8(buf, o + 2, math.floor(c % 256 * shade))
                    buffer.writeu8(buf, o + 3, 255)
                end
                if idx % 4000 == 0 then tick() end
            end
            previewEI:WritePixelsBuffer(Vector2.zero, Vector2.new(cols, rows), buf)
        end)
        previewImg.Visible = ok
        previewNote.Visible = not ok
        if not ok then
            previewNote.Text = "Preview tidak tersedia di executor ini, tombol BUAT tetap bisa dipakai."
        end
    end

    local refreshing, rerun = false, false
    local function refresh()
        if refreshing then rerun = true return end
        refreshing = true
        repeat
            rerun = false
            local okR, errR = pcall(function()
                if cellsDirty then
                    resample()
                    cellsDirty = false
                end
                computeGrid()
                drawPreview()
                if grid then
                    local rects = buildRects()
                    local over = #rects > MAX_PARTS
                    infoLbl.Text = ("%d x %d sel  |  %d part%s"):format(grid.cols, grid.rows, #rects, over and " (kebanyakan!)" or "")
                    infoLbl.TextColor3 = over and T.Bad or T.Muted
                else
                    infoLbl.Text = "Belum ada gambar."
                    infoLbl.TextColor3 = T.Muted
                end
            end)
            if not okR then setStatus("Error: " .. tostring(errR):sub(1, 70), T.Bad) end
        until not rerun
        refreshing = false
    end
    local function queueRefresh() task.spawn(refresh) end

    ---------------------------------------------------------------
    -- Isi tab pengaturan
    ---------------------------------------------------------------
    -- UKURAN
    local pUkuran = innerOf(1)
    local colsBox  = field(pUkuran, "LEBAR (SEL)", state.cols, 0, 1 / 3)
    local cellBox  = field(pUkuran, "UKURAN SEL (STUDS)", state.cell, 1 / 3, 1 / 3)
    local depthBox = field(pUkuran, "TEBAL (STUDS)", state.depth, 2 / 3, 1 / 3)
    colsBox.FocusLost:Connect(function()
        state.cols = math.clamp(math.floor(tonumber(colsBox.Text) or state.cols), 4, MAX_COLS)
        colsBox.Text = tostring(state.cols)
        cellsDirty = true
        queueRefresh()
    end)
    cellBox.FocusLost:Connect(function()
        state.cell = math.clamp(tonumber(cellBox.Text) or state.cell, 0.05, 20)
        cellBox.Text = tostring(state.cell)
    end)
    depthBox.FocusLost:Connect(function()
        state.depth = math.clamp(tonumber(depthBox.Text) or state.depth, 0.05, 50)
        depthBox.Text = tostring(state.depth)
    end)
    local cropBtn = toggleBtn(pUkuran, 0, 48, 1, -6)
    local function paintCrop()
        cropBtn.Text = state.crop and "POTONG AREA KOSONG: ON" or "POTONG AREA KOSONG: OFF"
        cropBtn.BackgroundColor3 = state.crop and T.Accent or T.Field
        cropBtn.TextColor3 = state.crop and T.Text or T.Muted
    end
    paintCrop()
    cropBtn.MouseButton1Click:Connect(function()
        state.crop = not state.crop
        paintCrop()
        cellsDirty = true
        queueRefresh()
    end)

    -- MODE + BENTUK
    local pMode = innerOf(2)
    local modeDesc
    chipRow(pMode, MODES, 0, function() return state.modeIndex end, function(i)
        state.modeIndex = i
        modeDesc.Text = MODE_DESC[i]
        queueRefresh()
    end)
    chipRow(pMode, SHAPES, 32, function() return state.shapeIndex end, function(i)
        state.shapeIndex = i
        queueRefresh()
    end)
    modeDesc = label(pMode, {
        Position = UDim2.fromOffset(3, 62), Size = UDim2.new(1, -6, 0, 12),
        Text = MODE_DESC[state.modeIndex], TextSize = 8, TextColor3 = T.Muted,
    })

    -- WARNA
    local pWarna = innerOf(3)
    local levelNames = {}
    for i, lv in ipairs(LEVELS) do levelNames[i] = lv.name end
    chipRow(pWarna, levelNames, 0, function() return state.levelsIndex end, function(i)
        state.levelsIndex = i
        queueRefresh()
    end)
    local bgBtn = toggleBtn(pWarna, 0, 32, 0.6, -6)
    bgBtn.Text = BG_MODES[state.bgIndex]
    bgBtn.MouseButton1Click:Connect(function()
        state.bgIndex = state.bgIndex % #BG_MODES + 1
        bgBtn.Text = BG_MODES[state.bgIndex]
        queueRefresh()
    end)
    local alphaHolder = new("Frame", {
        Position = UDim2.new(0.6, 3, 0, 32), Size = UDim2.new(0.4, -6, 0, 26), BackgroundTransparency = 1,
    }, pWarna)
    label(alphaHolder, {Text = "AMBANG %", TextSize = 8, TextColor3 = T.Muted, Size = UDim2.new(0.5, 0, 1, 0)})
    local alphaBox = new("TextBox", {
        Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundColor3 = T.Field, BorderSizePixel = 0, Text = tostring(state.alphaCut),
        TextColor3 = T.Text, TextSize = 10, Font = Enum.Font.GothamBold, ClearTextOnFocus = false,
    }, alphaHolder)
    corner(alphaBox, 10)
    stroke(alphaBox, T.Line, 1)
    alphaBox.FocusLost:Connect(function()
        state.alphaCut = math.clamp(tonumber(alphaBox.Text) or state.alphaCut, 1, 95)
        alphaBox.Text = tostring(state.alphaCut)
        queueRefresh()
    end)

    -- TAMPILAN
    local pLook = innerOf(4)
    local matBtn = toggleBtn(pLook, 0, 0, 0.6, -6)
    local straightBtn = toggleBtn(pLook, 0.6, 0, 0.4, -6)
    local function paintLook()
        matBtn.Text = "MATERIAL: " .. MATERIALS[state.materialIndex]:upper()
        straightBtn.Text = state.straight and "LURUS: ON" or "LURUS: OFF"
        straightBtn.BackgroundColor3 = state.straight and T.Accent or T.Field
        straightBtn.TextColor3 = state.straight and T.Text or T.Muted
    end
    paintLook()
    matBtn.MouseButton1Click:Connect(function()
        state.materialIndex = state.materialIndex % #MATERIALS + 1
        paintLook()
    end)
    straightBtn.MouseButton1Click:Connect(function()
        state.straight = not state.straight
        paintLook()
    end)
    label(pLook, {
        Position = UDim2.fromOffset(3, 34), Size = UDim2.new(1, -6, 0, 36),
        Text = "LURUS ON = gambar ikut sumbu dunia. OFF = menghadap kamera saat dibuat. Model hanya terlihat olehmu (client).",
        TextSize = 8, TextColor3 = T.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
    })
    showMini(1)

    ---------------------------------------------------------------
    -- Sumber gambar: Asset ID + daftar file
    ---------------------------------------------------------------
    local function applySource(data, err)
        if not data then
            source, cells, grid = nil, nil, nil
            previewNote.Text = "Gagal memuat gambar."
            previewNote.Visible = true
            previewImg.Visible = false
            infoLbl.Text = "Belum ada gambar."
            setStatus("Gagal: " .. tostring(err):sub(1, 90), T.Bad)
            return
        end
        source = data
        cellsDirty = true
        setStatus(("Gambar dimuat (%d x %d px)."):format(data.w, data.h), T.Ok)
        refresh()
    end

    local function loadId()
        setStatus("Memuat gambar...", T.Muted)
        local okL, data, err = pcall(loadFromId, idBox.Text)
        if not okL then data, err = nil, data end
        applySource(data, err)
    end
    btnLoadId.MouseButton1Click:Connect(function() task.spawn(loadId) end)
    idBox.FocusLost:Connect(function(enter) if enter then task.spawn(loadId) end end)

    local imgItems, selectedImg = {}, nil
    local function paintImgs()
        for _, it in ipairs(imgItems) do
            if it.path then
                local on = it.path == selectedImg
                it.stroke.Color = on and T.Accent or T.Line
                it.stroke.Thickness = on and 1.6 or 1
            end
        end
    end

    local function findImageFiles()
        local seen, out = {}, {}
        if type(listfiles) ~= "function" then return out end
        for _, dir in ipairs({"", ".", "workspace"}) do
            local okL, files = pcall(listfiles, dir)
            if okL and type(files) == "table" then
                for _, p in ipairs(files) do
                    local low = p:lower()
                    local key = fileBase(low)
                    if (low:match("%.png$") or low:match("%.jpe?g$")) and not seen[key] then
                        seen[key] = true
                        out[#out + 1] = p
                    end
                end
            end
        end
        table.sort(out, function(a, b) return fileBase(a):lower() < fileBase(b):lower() end)
        return out
    end

    local function refreshImgFiles()
        for _, it in ipairs(imgItems) do it.frame:Destroy() end
        imgItems = {}
        local files = findImageFiles()
        if #files == 0 then
            local lbl = label(imgList, {
                Text = "Belum ada gambar .png/.jpg di folder workspace executor.\nPakai Asset ID, atau taruh gambar di folder itu lalu MUAT ULANG.",
                TextSize = 8, TextColor3 = T.Muted, TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 60),
            })
            imgItems[1] = {frame = lbl}
            return
        end
        for idx, p in ipairs(files) do
            local card = new("Frame", {
                Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = idx,
            }, imgList)
            corner(card, 10)
            local st = stroke(card, T.Line, 1)
            label(card, {
                Text = fileBase(p), Font = Enum.Font.GothamBold, TextSize = 9,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0),
            })
            local hit = new("TextButton", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3,
            }, card)
            hit.MouseButton1Click:Connect(function()
                selectedImg = p
                paintImgs()
                task.spawn(function()
                    setStatus("Memuat file...", T.Muted)
                    local okL, data, err = pcall(loadFromFile, p)
                    if not okL then data, err = nil, data end
                    applySource(data, err)
                end)
            end)
            imgItems[#imgItems + 1] = {frame = card, stroke = st, path = p}
        end
        paintImgs()
    end
    btnRefreshImg.MouseButton1Click:Connect(refreshImgFiles)
    tabImage.MouseButton1Click:Connect(refreshImgFiles)
    pcall(refreshImgFiles)

    ---------------------------------------------------------------
    -- Buat model 3D
    ---------------------------------------------------------------
    local building = false
    local function buildImage()
        if building then return end
        if not grid or grid.filled == 0 then
            setStatus("Muat gambar dulu (atau semua sel terbuang).", T.Bad)
            return
        end
        local rects = buildRects()
        if #rects > MAX_PARTS then
            setStatus(("Terlalu banyak (%d part, maks %d). Kecilkan lebar/warna."):format(#rects, MAX_PARTS), T.Bad)
            return
        end
        building = true

        local cols, rows = grid.cols, grid.rows
        local cell, depth = state.cell, state.depth
        local isBall = state.shapeIndex == 2

        local camera = workspace.CurrentCamera
        local camCF = camera and camera.CFrame or CFrame.new(0, 10, 30)
        local dist = math.max(25, cols * cell * 0.8)
        local position = camCF.Position + camCF.LookVector * dist
        local base = state.straight and CFrame.new(position)
            or CFrame.fromMatrix(position, camCF.RightVector, camCF.UpVector)

        local model = Instance.new("Model")
        model.Name = ("NXImage_%dx%d"):format(cols, rows)
        local material = Enum.Material[MATERIALS[state.materialIndex]]
        for i, r in ipairs(rects) do
            local thickness = depth * r.depth / RELIEF_STEPS
            local x = (r.x + r.w / 2 - cols / 2) * cell
            local y = (rows / 2 - (r.y + r.h / 2)) * cell
            local part = Instance.new("Part")
            part.Name = "Pixel"
            part.Anchored = true
            local z
            if isBall then
                local diameter = cell * 0.95
                part.Shape = Enum.PartType.Ball
                part.Size = Vector3.new(diameter, diameter, diameter)
                z = math.max(thickness - diameter / 2, diameter / 2)
            else
                part.Size = Vector3.new(r.w * cell, r.h * cell, thickness)
                z = thickness / 2
            end
            part.CFrame = base * CFrame.new(x, y, z)
            part.Material = material
            part.Color = Color3.fromRGB(math.floor(r.color / 65536) % 256, math.floor(r.color / 256) % 256, r.color % 256)
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
            part.Parent = model
            if i % 250 == 0 then
                setStatus(("Membuat part... %d / %d"):format(i, #rects), T.Muted)
                task.wait()
            end
        end
        model.Parent = workspace
        setStatus(("Jadi: %d part (%d x %d sel)."):format(#rects, cols, rows), T.Ok)
        building = false
    end
    btnBuild.MouseButton1Click:Connect(function()
        task.spawn(function()
            local okB, errB = pcall(buildImage)
            if not okB then
                building = false
                setStatus("Gagal: " .. tostring(errB):sub(1, 80), T.Bad)
            end
        end)
    end)
end

buildImageTab()

task.spawn(scan)

UI.Gui = gui
return UI
