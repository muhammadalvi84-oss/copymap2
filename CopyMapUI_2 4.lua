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
    Size = UDim2.fromOffset(250, 34), BackgroundColor3 = T.Field, BorderSizePixel = 0,
}, header)
corner(pill, 17)
stroke(pill, T.Line, 1)

local tabCopy = button(pill, {
    Text = "COPY MAP", Size = UDim2.new(0.5, -5, 1, -6), Position = UDim2.fromOffset(3, 3),
    BackgroundColor3 = T.Accent, TextSize = 10,
})
corner(tabCopy, 14)
local tabImport = button(pill, {
    Text = "IMPORT MAP", Size = UDim2.new(0.5, -5, 1, -6), Position = UDim2.new(0.5, 2, 0, 3),
    BackgroundColor3 = T.Field, TextColor3 = T.Muted, TextSize = 10,
})
corner(tabImport, 14)

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
    local isCopy = name == "copy"
    copyPage.Visible = isCopy
    importPage.Visible = not isCopy
    tabCopy.BackgroundColor3 = isCopy and T.Accent or T.Field
    tabCopy.TextColor3 = isCopy and T.Text or T.Muted
    tabImport.BackgroundColor3 = isCopy and T.Field or T.Accent
    tabImport.TextColor3 = isCopy and T.Muted or T.Text
    tabCopy:SetAttribute("NoHover", true)
    tabImport:SetAttribute("NoHover", true)
end
tabCopy.MouseButton1Click:Connect(function() showTab("copy") end)
tabImport.MouseButton1Click:Connect(function() showTab("import") end)
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

    -- 1) kumpulkan service yang dipilih (buang yang tidak valid / kosong)
    UI.SetProgress(5, "Menyiapkan...", "Mengumpulkan service")
    local instances, totalItems, empty = {}, 0, {}
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

task.spawn(scan)

UI.Gui = gui
return UI
