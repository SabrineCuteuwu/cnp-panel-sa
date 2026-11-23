-- =====================================================================
-- CNP PANEL by Sabrine uwu
-- TikTok : @sbrine._glossygal
-- Cheap price
-- =====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local bp = player:WaitForChild("Backpack")
local mouse = player:GetMouse()

-- ===== VIEWPORT / MOBILE DETECT =====
local function getViewport()
    local cam = Workspace.CurrentCamera
    return (cam and cam.ViewportSize) or Vector2.new(1280, 720)
end

local isMobile = UserInputService.TouchEnabled and (
    not UserInputService.KeyboardEnabled
    or not UserInputService.MouseEnabled
    or getViewport().X < 900
)

local function fitW(w) return isMobile and math.min(w, math.max(180, getViewport().X - 24)) or w end
local function fitH(h) return isMobile and math.min(h, math.max(180, getViewport().Y - 70)) or h end

-- ===== DESTROY OLD GUIS =====
for _, n in ipairs({
    "CNP_Panel", "C4_Modern_Menu", "Fog_Panel", "Fog_Icon", "ListUserPanel",
    "Old2023ChatGui", "CNP_MicGui", "CNP_SpeedHUD", "SLPanel", "SLIcon",
    "SLCross", "CNP_Crosshair", "CNP_CrosshairPanel", "CNP_CrosshairIcon",
    "CNP_Fly", "CNP_KeyGate", "CNP_GearPanel", "CNP_BeamPanel", "CNP_GearFloat",
    "QuickEquipBarGui",
}) do
    local g = pg:FindFirstChild(n)
    if g then g:Destroy() end
end

pcall(function() RunService:UnbindFromRenderStep("CNP_ChatBubblePositions") end)
pcall(function() RunService:UnbindFromRenderStep("CNP_ChatMicPosition") end)
pcall(function() RunService:UnbindFromRenderStep("CNP_CamOffset") end)
pcall(function() RunService:UnbindFromRenderStep("CNP_Shiftlock2023") end)

-- =====================================================================
-- UNIFIED DRAG SYSTEM
-- =====================================================================
local Drag = { obj = nil, startPos = nil, startObjPos = nil, moved = false, threshold = 4 }

UserInputService.InputChanged:Connect(function(input)
    if not Drag.obj then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
       and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = input.Position - Drag.startPos
    if d.Magnitude > Drag.threshold then Drag.moved = true end
    Drag.obj.Position = UDim2.new(
        Drag.startObjPos.X.Scale, Drag.startObjPos.X.Offset + d.X,
        Drag.startObjPos.Y.Scale, Drag.startObjPos.Y.Offset + d.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        Drag.obj = nil
    end
end)

local function beginDrag(obj, input, threshold)
    Drag.obj = obj
    Drag.startPos = input.Position
    Drag.startObjPos = obj.Position
    Drag.moved = false
    Drag.threshold = threshold or 4
end

local function makeDraggable(frame, handle, threshold)
    handle = handle or frame
    handle.Active = true
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            beginDrag(frame, input, threshold)
        end
    end)
end

-- =====================================================================
-- CONFIG
-- =====================================================================
local SOUND_ID = "rbxassetid://6968135315" -- gun equip sound

local TARGET_TOOL_NAME = "Gun"
local SPEED_SAFE_TOOLS = {
    ["Gun"] = true, ["gun"] = true, ["GUN"] = true,
    ["Knife"] = true, ["knife"] = true, ["KNIFE"] = true,
}
local COOLDOWN_DURATION = 2
local BASE_SPEED = 16
-- SPEED (after unlock):  no flick = 45  |  flick = slider value  |  shake hard = even higher
local SPEED_VALUE = 110       -- slider 80..300 : stable default while flicking
local FLICK_SENS = 1.8
local STRAFE_MULT = 1.12      -- A/D while flicking feeds a little more into the shake
local FORWARD_MULT = 1.05
local SPEEDCFG = {
    -- tuned for stable walk / less rubberband (NO AI XMAS 2023)
    noFlick = 42,        -- base air speed when unlocked, not flicking
    flickFullAt = 5.5,   -- need clearer flick before full slider speed
    overAt = 26,         -- hard-shake region starts later
    overshoot = 0.18,    -- soft extra on hard shake (was 0.40)
    hardCap = 260,       -- hard ceiling — stable, no wild spikes
    upTime = 0.14,       -- slower rise → less jitter
    downTime = 0.32,     -- softer release
    hold = 0.16,         -- hold flick a bit longer for smooth shake
}
function SPEEDCFG.target(boost)
    local V = SPEED_VALUE
    local base = math.min(SPEEDCFG.noFlick, V)
    local t = math.clamp((boost - 1.5) / (SPEEDCFG.flickFullAt - 1.5), 0, 1)
    t = t * t * (3 - 2 * t)                       -- smoothstep: no sudden jump
    local sp = base + (V - base) * t
    if boost > SPEEDCFG.flickFullAt then
        local o = math.clamp((boost - SPEEDCFG.flickFullAt) / (SPEEDCFG.overAt - SPEEDCFG.flickFullAt), 0, 1)
        o = 1 - (1 - o) * (1 - o)                 -- climbs fast, then saturates
        sp = sp + V * SPEEDCFG.overshoot * o
    end
    return math.clamp(sp, 0, SPEEDCFG.hardCap)
end
-- gear (carpets, coils, bomb, hair dryer, waterbow, fly...) must NOT trigger speed / flick
SPEEDCFG.gear = {
    ["rainbow carpet"] = true, ["blood carpet"] = true, ["cinnamoroll carpet"] = true,
    ["flying carpet"] = true, ["hairdryer"] = true, ["hair dryer"] = true,
    ["waterbow"] = true, ["bomb"] = true,
    ["speedcoil"] = true, ["speed coil"] = true, ["gravitycoil"] = true, ["gravity coil"] = true,
    ["dualgravitycoil"] = true, ["dual gravity coil"] = true,
    ["zoewar coil"] = true, ["fake bomb"] = true, ["crossbow of the sea"] = true,
}
function SPEEDCFG.gearActive(char, tool)
    if tool and SPEEDCFG.gear[string.lower(tool.Name)] then return true end
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        for _, c in ipairs(root:GetChildren()) do
            if (c:IsA("BodyMover") or c:IsA("LinearVelocity") or c:IsA("VectorForce")
                or c:IsA("AlignPosition")) and c.Name ~= "CNP_ClimbLaunch" then
                return true
            end
        end
    end
    return false
end
-- Detect Speed Coil tools (CNP built-in + Gears Mmv "Zoewar Coil") so WalkSpeed is not clamped to 16
function SPEEDCFG.speedCoilWalk(tool)
    if not tool then
        if coilSpeedBoost and coilActiveSpeed and coilActiveSpeed > BASE_SPEED + 0.5 then
            return coilActiveSpeed
        end
        return nil
    end
    local n = string.lower(tool.Name or "")
    local coilType = nil
    pcall(function() coilType = tool:GetAttribute("CoilType") end)
    if coilType == "Speed" then
        return (coilActiveSpeed and coilActiveSpeed > BASE_SPEED + 0.5) and coilActiveSpeed or 32
    end
    if n == "speedcoil" or n == "speed coil" then
        return (coilActiveSpeed and coilActiveSpeed > BASE_SPEED + 0.5) and coilActiveSpeed or 34
    end
    -- Zoewar Coil from Gears Mmv can be Speed or Gravity
    if n == "zoewar coil" and coilType ~= "Gravity" then
        -- if attribute missing, treat as speed only when coilSpeedBoost already set
        if coilSpeedBoost and coilActiveSpeed and coilActiveSpeed > BASE_SPEED + 0.5 then
            return coilActiveSpeed
        end
        if coilType == "Speed" then return 32 end
    end
    if coilSpeedBoost and coilActiveSpeed and coilActiveSpeed > BASE_SPEED + 0.5 then
        return coilActiveSpeed
    end
    return nil
end
-- critically damped smoothing (Unity SmoothDamp): no overshoot, no stair-stepping
function SPEEDCFG.damp(cur, target, vel, smoothTime, dt)
    smoothTime = math.max(0.0001, smoothTime)
    local omega = 2 / smoothTime
    local x = omega * dt
    local e = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
    local change = cur - target
    local temp = (vel + omega * change) * dt
    vel = (vel - omega * temp) * e
    local out = target + (change + temp) * e
    if (target - cur > 0) == (out > target) then
        out = target
        vel = 0
    end
    return out, vel
end
local SPEED_LERP_DOWN = 9
local MOUSE_SMOOTH = 0.58
local EMOTE_MIN_LENGTH = 1.5
CNP_DEBUG_ANIM = false  -- prints animation ids in the console while testing speed unlock
CNP_SEEN_ANIM = {}
local SPEED_ANIMATION_IDS = {
    ["15610015346"] = true,
    ["14353423348"] = true,
    ["79867635155472"] = true,
    ["107481557610007"] = true,
    ["15609995579"] = true,    -- ybjump
    ["14352343065"] = true,    -- freespirit
    ["96806611330323"] = true, -- Animation1 (plays with every emote; remove if speed unlocks without emoting)
}

-- speedMode: "speed" = flat speed no flick needed | "flick" = old unlock+flick logic
local speedMode = "speed"

-- Climb launch (only when speed on) — rebalanced
local LAUNCH_SPEED = 145
local LAUNCH_FLICK = 195
local LAUNCH_MAX = 230
local climbLaunched = false

local actionSound = Instance.new("Sound")
actionSound.SoundId = SOUND_ID
actionSound.Volume = 0.3
actionSound.Parent = SoundService

-- =====================================================================
-- STATE
-- =====================================================================
local noReloadActive = false
local autoEquipActive = false
local enableOldShiftLock = false
local enableOldCamera = false -- removed from UI
local oldAnimActive = false
local speedEnabled = false
local coilSpeedBoost = false
local coilActiveSpeed = 16
local muteSheriffActive = false
local oldBubbleChatActive = false
local micActive = false
local antiflingActive = false

local speedHumanoid
local memorizedTool = nil
local memorizedToolName = nil
local isEmoting = false

local Config = {
    Cooldown = 2,
    CanUse = true,
    BombColor = Color3.fromRGB(255, 180, 50),
    ToolName = "Gold C4 Bomb",
    BombAmount = 1,
}
local CurrentDroppedBomb = nil
local ActiveTools = {}

-- =====================================================================
-- 2. CAMERA / SHIFT LOCK
-- =====================================================================
local cameraOffsetY = 0.5
local shiftLockBaseY = 1.5
local shiftLockX = 2
local shiftLockZ = 0

local camRP = RaycastParams.new()
camRP.FilterType = Enum.RaycastFilterType.Exclude

-- Hide Roblox default shiftlock / mouselock icons (lightweight)
local function hideDefaultShiftIcons()
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or getViewport()
    local center = vp / 2
    local function nuke(v)
        pcall(function()
            if v:IsA("ImageLabel") or v:IsA("ImageButton") then
                v.ImageTransparency = 1
            end
            if v:IsA("GuiObject") then
                v.Visible = false
            end
        end)
    end
    local function looksLock(n)
        n = string.lower(n or "")
        return n:find("mouselock", 1, true)
            or n:find("shiftlock", 1, true)
            or n:find("mouse_lock", 1, true)
            or n:find("shift_lock", 1, true)
            or n:find("mouseicon", 1, true)
            or n:find("lockicon", 1, true)
    end
    local function isOursGui(sn)
        return sn:sub(1, 4) == "CNP_" or sn == "Fog_Panel" or sn == "Fog_Icon"
            or sn == "C4_Modern_Menu" or sn == "ListUserPanel"
            or sn == "Old2023ChatGui"
    end
    local function scan(root)
        for _, sg in ipairs(root:GetChildren()) do
            if sg:IsA("ScreenGui") and not isOursGui(sg.Name) then
                for _, d in ipairs(sg:GetDescendants()) do
                    if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                        if looksLock(d.Name) or looksLock(sg.Name) then
                            nuke(d)
                        end
                    end
                end
            end
        end
    end
    scan(pg)
    pcall(function() scan(game:GetService("CoreGui")) end)
end

-- Shiftlock 2023: only CameraOffset XYZ while locked (PC safe)
local SHIFTLOCK_2023_OFFSET = Vector3.new(1.75, 0, 0)
local SHIFTLOCK_BIND = "CNP_Shiftlock2023"
local _slWasLocked = false

pcall(function() RunService:UnbindFromRenderStep(SHIFTLOCK_BIND) end)
pcall(function() RunService:UnbindFromRenderStep("CNP_CamOffset") end)

RunService:BindToRenderStep(SHIFTLOCK_BIND, Enum.RenderPriority.Camera.Value + 1, function()
    if not enableOldShiftLock then
        if _slWasLocked then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.CameraOffset == SHIFTLOCK_2023_OFFSET then
                hum.CameraOffset = Vector3.zero
            end
            _slWasLocked = false
        end
        return
    end

    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
    if locked then
        -- only write classic XYZ offset; do not touch other systems
        if hum.CameraOffset ~= SHIFTLOCK_2023_OFFSET then
            hum.CameraOffset = SHIFTLOCK_2023_OFFSET
        end
        _slWasLocked = true
    elseif _slWasLocked then
        -- unlock edge: clear only our offset
        if hum.CameraOffset == SHIFTLOCK_2023_OFFSET then
            hum.CameraOffset = Vector3.zero
        end
        _slWasLocked = false
    end
end)

-- =====================================================================
-- 3. SPEED (Mobile Flick & Strafe Boost)
-- =====================================================================
local FLICK_DEAD_PC     = 130
local FLICK_REF_PC      = 520
local FLICK_DEAD_MOBILE = 30
local FLICK_REF_MOBILE  = 150
local FLICK_A, FLICK_B, FLICK_C = 28, 12, 4

local function flickCurve(x)
    if x <= 0 then return 0 end
    return FLICK_A * x + FLICK_B * x * x + FLICK_C * x * x * x
end

local speedConnections = {}
local isUnlocked = false
local emotePlayedFirst = false
local lastCamYaw = nil
local flickBoost = 0
local smoothMouseRate = 0
local renderFlickTarget = 0
local landSlideUntil = 0
local smoothWalkSpeed = BASE_SPEED
local landBrakeUntil = 0
local jumpStack = 0
local prevInAir = false
local SPD = { vel = 0, hold = 0 }

local function speedDisconnectAll()
    for _, c in ipairs(speedConnections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    for i = #speedConnections, 1, -1 do speedConnections[i] = nil end
    isUnlocked = false
    emotePlayedFirst = false
end

local function checkIsEmoting(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:FindFirstChild("Animator")
    if not animator then return false end
    local char = humanoid.Parent
    local holdingTool = char and char:FindFirstChildOfClass("Tool")
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local anim = track.Animation
        if anim and track.IsPlaying then
            local id = tostring(anim.AnimationId):match("%d+")
            if id and SPEED_ANIMATION_IDS[id] then
                return true
            end
            -- fallback: any long emote-priority animation while NOT holding a tool
            -- (emote hub emotes have many different ids, so the id list alone misses them)
            if not holdingTool
                and (track.Priority == Enum.AnimationPriority.Action4
                    or track.Priority == Enum.AnimationPriority.Action3)
                and track.Length > EMOTE_MIN_LENGTH then
                return true
            end
            -- debug: print ids of animations that did not unlock (set CNP_DEBUG_ANIM = true)
            if CNP_DEBUG_ANIM and id and not CNP_SEEN_ANIM[id] then
                CNP_SEEN_ANIM[id] = true
                print("[CNP] anim id:", id, "priority:", tostring(track.Priority), "len:", track.Length)
            end
        end
    end
    return false
end

local function isGunOrKnife(tool)
    if not tool then return false end
    local n = string.lower(tool.Name)
    return n == "gun" or n == "knife"
end

-- speed allowed after unlock (emote + any tool): empty hand OR any tool
local function canSpeedWithTool(tool)
    return isUnlocked and true or false
end

local function speedResetUnlock()
    isUnlocked = false
    emotePlayedFirst = false
    memorizedTool = nil
    memorizedToolName = nil
    flickBoost = 0
    lastCamYaw = nil
    smoothMouseRate = 0
    smoothWalkSpeed = BASE_SPEED
    landBrakeUntil = 0
    renderFlickTarget = 0
    jumpStack = 0
    prevInAir = false
    SPD.vel = 0
    SPD.hold = 0
    if speedHumanoid and speedHumanoid.Parent then
        if speedHumanoid.WalkSpeed > BASE_SPEED then
            speedHumanoid.WalkSpeed = BASE_SPEED
        end
    end
end

local function isSafeSpeedTool(tool)
    -- Sau unlock chi giu speed khi: tay khong HOAC Gun/Knife
    -- Cam bat ky tool khac (ke ca tool vua dung de unlock) → mat speed
    if not tool then return true end
    if SPEED_SAFE_TOOLS[tool.Name] then return true end
    return false
end

-- Anti-fling when jumping into walls
local function dampWallFling(root, char)
    if not root or not char then return end
    -- while speed glitch is on, do not kill velocity (causes rubberband)
    if speedEnabled then return end
    local v = root.AssemblyLinearVelocity
    local horiz = Vector3.new(v.X, 0, v.Z)
    if horiz.Magnitude < 55 then return end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { char }
    local origin = root.Position
    local d = horiz.Unit
    local hit = Workspace:Raycast(origin, d * 1.6, rp)
    if not hit then return end
    local n = hit.Normal
    local into = horiz:Dot(Vector3.new(-n.X, 0, -n.Z))
    if into <= 8 then return end
    local nn = Vector3.new(-n.X, 0, -n.Z)
    if nn.Magnitude < 0.05 then return end
    local nv = horiz - nn.Unit * (into * 0.55)
    local flingCap = math.max(180, SPEED_VALUE * (1 + SPEEDCFG.overshoot) * 1.25)
    if nv.Magnitude > flingCap then
        nv = nv.Unit * flingCap
    end
    root.AssemblyLinearVelocity = Vector3.new(nv.X, v.Y, nv.Z)
end

local function speedSetupCharacter(char)
    speedDisconnectAll()
    speedHumanoid = char:WaitForChild("Humanoid", 10)
    if not speedHumanoid then return end
    task.wait()
    speedResetUnlock()

    table.insert(speedConnections, RunService.RenderStepped:Connect(function(rdt)
        local cam = Workspace.CurrentCamera
        local dts = math.max(rdt, 1/240)
        local x = 0
        if not isMobile then
            local md = UserInputService:GetMouseDelta()
            local rawRate = math.sqrt(md.X * md.X + md.Y * md.Y) / dts
            if rawRate > 4000 then rawRate = smoothMouseRate end
            smoothMouseRate = smoothMouseRate + (rawRate - smoothMouseRate)
                * math.clamp(MOUSE_SMOOTH + rdt * 2, 0.05, 1)
            if smoothMouseRate > FLICK_DEAD_PC then
                x = math.max(x, (smoothMouseRate - FLICK_DEAD_PC) / FLICK_REF_PC)
            end
        end
        if cam then
            local look = cam.CFrame.LookVector
            local yaw = math.deg(math.atan2(-look.X, -look.Z))
            if lastCamYaw then
                local d = math.abs(((yaw - lastCamYaw + 180) % 360) - 180)
                local rate = d / dts
                if isMobile then
                    if rate > 2500 then rate = smoothMouseRate end
                    smoothMouseRate = smoothMouseRate + (rate - smoothMouseRate)
                        * math.clamp(0.32 + rdt * 2, 0.05, 0.7)
                    rate = smoothMouseRate
                    if rate > FLICK_DEAD_MOBILE then
                        x = math.max(x, (rate - FLICK_DEAD_MOBILE) / FLICK_REF_MOBILE)
                    end
                elseif rate > FLICK_DEAD_MOBILE * 3 then
                    x = math.max(x, (rate - FLICK_DEAD_MOBILE * 3) / (FLICK_REF_MOBILE * 3))
                end
            end
            lastCamYaw = yaw
        end
        renderFlickTarget = flickCurve(x * FLICK_SENS)
    end))

    local emoteCheckAccum = 0
    table.insert(speedConnections, RunService.Heartbeat:Connect(function(dt)
        if not speedHumanoid or not speedHumanoid.Parent or speedHumanoid.Health <= 0 then return end


        if speedHumanoid.PlatformStand or speedHumanoid.Sit then return end
        local state = speedHumanoid:GetState()
        if state == Enum.HumanoidStateType.Seated
           or state == Enum.HumanoidStateType.PlatformStanding then return end

        if state == Enum.HumanoidStateType.Climbing then
            if speedHumanoid.WalkSpeed > BASE_SPEED + 0.5 then
                speedHumanoid.WalkSpeed = BASE_SPEED
                smoothWalkSpeed = BASE_SPEED
            end
            return
        end

        local currentTool = char:FindFirstChildOfClass("Tool")
        local inAir = state == Enum.HumanoidStateType.Jumping
            or state == Enum.HumanoidStateType.Freefall
            or state == Enum.HumanoidStateType.FallingDown

        local root = char:FindFirstChild("HumanoidRootPart")
        local now = os.clock()

        -- no emote / tool condition: speed is active as soon as the toggle is on
        if speedEnabled and not isUnlocked then
            isUnlocked = true
        end

        local speedOk = speedEnabled and canSpeedWithTool(currentTool)
            and not SPEEDCFG.gearActive(char, currentTool)

        if speedOk then
            if inAir then
                landSlideUntil = 0
                -- flick strength: fast attack, short hold, smooth release
                do
                    local target = renderFlickTarget
                    local k = math.clamp(dt * 60, 0, 4)
                    if target > flickBoost then
                        flickBoost = flickBoost + (target - flickBoost) * (1 - 0.5 ^ k)
                        SPD.hold = now + SPEEDCFG.hold
                    elseif now > SPD.hold then
                        flickBoost = math.max(target, flickBoost * math.exp(-dt * 4.8))
                        if flickBoost < 0.2 then flickBoost = 0 end
                    end
                end

                local keyA = UserInputService:IsKeyDown(Enum.KeyCode.A)
                local keyD = UserInputService:IsKeyDown(Enum.KeyCode.D)
                local keyW = UserInputService:IsKeyDown(Enum.KeyCode.W)
                if not (keyA or keyD or keyW) then
                    local mdir = speedHumanoid.MoveDirection
                    local cam = Workspace.CurrentCamera
                    if cam and mdir.Magnitude > 0.1 then
                        local lv = cam.CFrame:VectorToObjectSpace(mdir)
                        if math.abs(lv.X) > 0.25 then keyA = true; keyD = true end
                        if lv.Z < -0.25 then keyW = true end
                    end
                end

                local boost = flickBoost
                local keyMul = 1
                if (keyA or keyD) and boost > 1.5 then
                    keyMul = keyMul * (STRAFE_MULT + math.clamp(boost / 60, 0, 0.3))
                end
                if keyW and boost > 1.5 then
                    keyMul = keyMul * FORWARD_MULT
                end
                boost = boost * keyMul
                prevInAir = true

                -- no flick -> 45 | flick -> slider value | hard shake -> higher
                local desired = SPEEDCFG.target(boost)
                local tConst = (desired > smoothWalkSpeed) and SPEEDCFG.upTime or SPEEDCFG.downTime
                smoothWalkSpeed, SPD.vel = SPEEDCFG.damp(smoothWalkSpeed, desired, SPD.vel, tConst, dt)
                if math.abs(speedHumanoid.WalkSpeed - smoothWalkSpeed) > 0.08 then
                    speedHumanoid.WalkSpeed = smoothWalkSpeed
                end

                -- air assist (wall-safe): pulls horizontal velocity toward the speed, never slows you down
                -- mild air boost only (no hard rewrite → less rubberband)
                if root and smoothWalkSpeed > BASE_SPEED + 8 then
                    local md = speedHumanoid.MoveDirection
                    if md.Magnitude > 0.2 then
                        local dir = Vector3.new(md.X, 0, md.Z)
                        if dir.Magnitude > 0.05 then
                            dir = dir.Unit
                            local v = root.AssemblyLinearVelocity
                            local cur = Vector3.new(v.X, 0, v.Z)
                            local along = cur:Dot(dir)
                            if along < smoothWalkSpeed * 0.88 then
                                local add = dir * ((smoothWalkSpeed - math.max(along, 0)) * math.clamp(dt * 3.2, 0, 0.20))
                                local nv = cur + add
                                -- soft cap horizontal so assist never overshoots hard
                                local hmag = math.sqrt(nv.X * nv.X + nv.Z * nv.Z)
                                local cap = smoothWalkSpeed * 1.05
                                if hmag > cap and hmag > 0.01 then
                                    local s = cap / hmag
                                    nv = Vector3.new(nv.X * s, 0, nv.Z * s)
                                end
                                root.AssemblyLinearVelocity = Vector3.new(nv.X, v.Y, nv.Z)
                            end
                        end
                    end
                end
                dampWallFling(root, char)
            else
                -- On ground (keep Speed Coil walk speed if equipped)
                lastCamYaw = nil
                flickBoost = 0
                smoothMouseRate = 0
                landSlideUntil = 0
                prevInAir = false
                jumpStack = 0

                local coilSp = SPEEDCFG.speedCoilWalk(currentTool)
                local groundTarget = coilSp or BASE_SPEED
                smoothWalkSpeed, SPD.vel = SPEEDCFG.damp(smoothWalkSpeed, groundTarget, SPD.vel, 0.20, dt)
                if math.abs(speedHumanoid.WalkSpeed - smoothWalkSpeed) > 0.05 then
                    speedHumanoid.WalkSpeed = math.max(groundTarget, smoothWalkSpeed)
                end

                -- very soft ground slide (avoid yank back while speed glitch)
                if root and not speedEnabled then
                    local v = root.AssemblyLinearVelocity
                    local hx, hz = v.X, v.Z
                    local mag = math.sqrt(hx * hx + hz * hz)
                    local cap = BASE_SPEED + 40
                    if mag > cap then
                        local f = math.exp(-2.0 * dt)
                        local nh = math.max(cap, mag * f)
                        local sc = nh / mag
                        root.AssemblyLinearVelocity = Vector3.new(hx * sc, v.Y, hz * sc)
                    end
                end
                dampWallFling(root, char)
            end
        else
            if flickBoost ~= 0 or lastCamYaw then
                flickBoost = 0
                lastCamYaw = nil
                smoothMouseRate = 0
            end
            landSlideUntil = 0
            SPD.vel = 0
            -- Speed Coil (built-in or Gears Mmv): never clamp back to 16
            local coilSp = SPEEDCFG.speedCoilWalk(currentTool)
            if coilSp then
                if math.abs(speedHumanoid.WalkSpeed - coilSp) > 0.5 then
                    speedHumanoid.WalkSpeed = coilSp
                end
                smoothWalkSpeed = coilSp
            else
                smoothWalkSpeed = smoothWalkSpeed + (BASE_SPEED - smoothWalkSpeed)
                    * (1 - math.exp(-SPEED_LERP_DOWN * dt))
                if speedHumanoid.WalkSpeed > BASE_SPEED + 0.4 then
                    speedHumanoid.WalkSpeed = math.max(BASE_SPEED, smoothWalkSpeed)
                end
            end
        end
    end))

    table.insert(speedConnections, char.ChildAdded:Connect(function(child)
        if not child:IsA("Tool") then return end
        if not speedEnabled then return end
        -- remember any tool after emote; unlock sticks
        if emotePlayedFirst or isEmoting then
            memorizedTool = child
            memorizedToolName = child.Name
            isUnlocked = true
        elseif isUnlocked then
            memorizedTool = child
        end
    end))

    table.insert(speedConnections, speedHumanoid.Died:Connect(function()
        speedResetUnlock()
        speedHumanoid = nil
        climbLaunched = false
    end))
end

-- =====================================================================
-- CLIMB LAUNCH (integrated with speed)
-- no speed -> none | speed on (no flick) ~145-170 | speed + flick ~195-225
-- =====================================================================
local function doClimbLaunch()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    if hum:GetState() ~= Enum.HumanoidStateType.Climbing then return end
    if climbLaunched then return end

    climbLaunched = true

    -- only launch when speed is on; max ~230
    if not speedEnabled then
        climbLaunched = false
        return
    end
    local power = LAUNCH_SPEED + math.random(0, 25)
    local flicking = (renderFlickTarget and renderFlickTarget > 6)
        or (flickBoost and flickBoost > 6)
    if flicking then
        power = LAUNCH_FLICK + math.random(0, 30)
    end
    power = math.clamp(power, 120, LAUNCH_MAX)

    local bv = Instance.new("BodyVelocity")
    bv.Name = "CNP_ClimbLaunch"
    bv.Velocity = Vector3.new(0, power, 0)
    bv.MaxForce = Vector3.new(0, math.huge, 0)
    bv.Parent = root

    task.delay(0.28, function()
        if bv and bv.Parent then bv:Destroy() end
    end)

    -- Reset flag when leaving climb
    task.spawn(function()
        while hum and hum.Parent and hum:GetState() == Enum.HumanoidStateType.Climbing do
            task.wait(0.1)
        end
        climbLaunched = false
    end)
end

UserInputService.JumpRequest:Connect(function()
    doClimbLaunch()
end)

-- Mobile fallback: TouchGui JumpButton
task.spawn(function()
    local PlayerGui = player:WaitForChild("PlayerGui")
    local TouchGui = PlayerGui:WaitForChild("TouchGui", 10)
    if TouchGui then
        local TouchControlFrame = TouchGui:WaitForChild("TouchControlFrame", 5)
        if TouchControlFrame then
            local JumpButton = TouchControlFrame:WaitForChild("JumpButton", 5)
            if JumpButton then
                JumpButton.MouseButton1Down:Connect(function()
                    doClimbLaunch()
                end)
            end
        end
    end
end)

-- =====================================================================
-- 4. GUN SYSTEM
-- =====================================================================
local function setupGunSystem(character)
    if not character then return end
    local humanoid = character:WaitForChild("Humanoid", 10); if not humanoid then return end
    local animator = humanoid:WaitForChild("Animator", 10); if not animator then return end
    local lastUnequippedTime = 0
    animator.AnimationPlayed:Connect(function(track)
        if not noReloadActive then return end
        local tool = character:FindFirstChildOfClass("Tool")
        if (tool and tool.Name == TARGET_TOOL_NAME
            or (os.clock() - lastUnequippedTime) <= COOLDOWN_DURATION)
            and track.Priority == Enum.AnimationPriority.Action then
            track:Stop()
        end
    end)
    character.ChildAdded:Connect(function(c)
        if c:IsA("Tool") and c.Name == TARGET_TOOL_NAME then
            actionSound:Play()
            if autoEquipActive then humanoid:EquipTool(c) end
        end
    end)
    character.ChildRemoved:Connect(function(c)
        if c:IsA("Tool") and c.Name == TARGET_TOOL_NAME then
            actionSound:Play()
            lastUnequippedTime = os.clock()
        end
    end)
end

-- =====================================================================
-- 5. CHAT BUBBLES
-- =====================================================================
local LS = {
    Font = Enum.Font.BuilderSansMedium,
    TextColor = Color3.fromRGB(25, 25, 25),
    MinWidth = 40, MinHeight = 30,
    CornerRadius = 4,
    MaxBubbles = 3, BubbleTime = 10, OldBubbleTime = 5, FadeTime = 0.5,
    NewBubbleTransparency = 0, OldBubbleTransparency = 0.4,
    HeadGap = 0.45,
    MaxDistance = 100, FarDistance = 40, ScaleStart = 15, MinScale = 0.6,
    Gap = 4,
    TextSize = 18, MaxWidth = 300,
    TailSize = 24, TailProtrusion = 22,
    TailOffsetX = 0, TailOffsetY = -6, TailOffsetZ = 0,
    -- Local XYZ on head: X = left/right, Y = up, Z = back/forward
    -- (+Z = behind head, -Z = in front of face)
    -- Stack like reference pic: mic on top, chat under it (above head)
    ChatOffset = Vector3.new(0, 0.45, 0),
    MicOffset  = Vector3.new(0, 1.5, 0),
    MicCornerRadius = 7, MicHeight = 1.5, MicTailSize = 10,
    MicDecal = "rbxasset://textures/ui/VoiceChat/Muted.png",
    MicX = 0, MicY = 0, MicSize = 32,
}
LS.Padding_X = 10
LS.Padding_Y = 4

local chatGui = nil
local chatConnections = {}
local playerBubbles = {}
local micGui = nil
local micFrame = nil

local function getHead(plr)
    local c = plr.Character
    return c and c:FindFirstChild("Head")
end

local function getBubbleSize(text)
    local innerMax = LS.MaxWidth - (LS.Padding_X * 2)
    local bounds = TextService:GetTextSize(text, LS.TextSize, LS.Font, Vector2.new(innerMax, 10000))
    local w = math.clamp(bounds.X + (LS.Padding_X * 2), LS.MinWidth, LS.MaxWidth)
    local h = math.max(bounds.Y + (LS.Padding_Y * 2), LS.MinHeight)
    return math.ceil(w), math.ceil(h)
end

local function cancelTimer(bubble)
    if bubble and bubble.timer then
        pcall(task.cancel, bubble.timer)
        bubble.timer = nil
    end
end

local function getContainer(plr)
    return chatGui and chatGui:FindFirstChild("P" .. tostring(plr.UserId))
end

local function clearPlayerGui(plr)
    local c = getContainer(plr)
    if c then c:Destroy() end
end

local function createTail(parent, yOffset, zIndex)
    local tailHolder = Instance.new("Frame")
    tailHolder.Name = "TailHolder"
    tailHolder.Size = UDim2.fromOffset(LS.TailSize, LS.TailProtrusion)
    tailHolder.AnchorPoint = Vector2.new(0.5, 0)
    tailHolder.Position = UDim2.new(0.5, LS.TailOffsetX, 0, yOffset + LS.TailOffsetY)
    tailHolder.BackgroundTransparency = 1
    tailHolder.ClipsDescendants = true
    tailHolder.ZIndex = zIndex + LS.TailOffsetZ
    tailHolder.Parent = parent

    local diamond = Instance.new("Frame")
    diamond.Name = "Diamond"
    diamond.Size = UDim2.fromOffset(LS.TailSize, LS.TailSize)
    diamond.AnchorPoint = Vector2.new(0.5, 0.5)
    diamond.Position = UDim2.new(0.5, 0, 0, 0)
    diamond.Rotation = 45
    diamond.BackgroundColor3 = Color3.new(1, 1, 1)
    diamond.BackgroundTransparency = LS.NewBubbleTransparency
    diamond.BorderSizePixel = 0
    diamond.ZIndex = tailHolder.ZIndex
    diamond.Parent = tailHolder
    Instance.new("UICorner", diamond).CornerRadius = UDim.new(0, 2)

    return tailHolder, diamond
end

local function createFarBubble(container)
    local w, h = 46, 30
    local far = Instance.new("Frame")
    far.Name = "Far"; far.AnchorPoint = Vector2.new(0.5, 1); far.Position = UDim2.new(0.5, 0, 1, 0)
    far.Size = UDim2.fromOffset(w, h + LS.TailProtrusion)
    far.BackgroundTransparency = 1; far.Visible = false; far.Parent = container

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(w, h)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.BorderSizePixel = 0; frame.ZIndex = 2; frame.Parent = far
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, LS.CornerRadius)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1
    label.Text = "..."; label.Font = LS.Font; label.TextSize = 22
    label.TextColor3 = LS.TextColor; label.ZIndex = 3; label.Parent = frame

    createTail(far, h, 1)
end

local function rebuildBubbles(plr)
    if not chatGui then return end
    local data = playerBubbles[plr]
    clearPlayerGui(plr)
    if not data or #data == 0 then return end

    local totalHeight, maxWidth = 0, 0
    for _, b in ipairs(data) do
        b.width, b.height = getBubbleSize(b.text)
        totalHeight = totalHeight + b.height
        maxWidth = math.max(maxWidth, b.width)
    end
    totalHeight = totalHeight + (LS.Gap * math.max(#data - 1, 0))

    local container = Instance.new("Frame")
    container.Name = "P" .. tostring(plr.UserId)
    container.Size = UDim2.fromOffset(math.max(maxWidth, 46), totalHeight + LS.TailProtrusion)
    container.AnchorPoint = Vector2.new(0.5, 1)
    container.Position = UDim2.new(0.5, 0, 1, 0)
    container.BackgroundTransparency = 1; container.BorderSizePixel = 0
    container.Visible = false; container.Parent = chatGui

    local uiScale = Instance.new("UIScale"); uiScale.Name = "DistanceScale"; uiScale.Parent = container
    createFarBubble(container)

    local stack = Instance.new("Frame")
    stack.Name = "Stack"; stack.Size = UDim2.fromScale(1, 1); stack.BackgroundTransparency = 1; stack.Parent = container
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, LS.Gap); layout.Parent = stack

    for index, b in ipairs(data) do
        local age = #data - index
        local wrapper = Instance.new("Frame")
        wrapper.Name = "Row"
        wrapper.Size = UDim2.fromOffset(b.width, b.height + (age == 0 and LS.TailProtrusion or 0))
        wrapper.LayoutOrder = index; wrapper.BackgroundTransparency = 1
        wrapper.BorderSizePixel = 0; wrapper.Parent = stack

        local frame = Instance.new("Frame")
        frame.Name = "Bubble"; frame.Size = UDim2.fromOffset(b.width, b.height)
        frame.BackgroundColor3 = Color3.new(1, 1, 1)
        frame.BackgroundTransparency = LS.NewBubbleTransparency
        frame.BorderSizePixel = 0; frame.ZIndex = 2
        frame:SetAttribute("BubbleID", b.id); frame.Parent = wrapper
        b.frame = frame
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, LS.CornerRadius)

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, LS.Padding_Y); pad.PaddingBottom = UDim.new(0, LS.Padding_Y)
        pad.PaddingLeft = UDim.new(0, LS.Padding_X); pad.PaddingRight = UDim.new(0, LS.Padding_X)
        pad.Parent = frame

        local label = Instance.new("TextLabel")
        label.Name = "Message"; label.BackgroundTransparency = 1; label.BorderSizePixel = 0
        label.Size = UDim2.fromScale(1, 1); label.Text = b.text; label.Font = LS.Font
        label.TextSize = LS.TextSize; label.TextColor3 = LS.TextColor
        label.TextWrapped = true; label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center; label.ZIndex = 3; label.Parent = frame

        if age >= 1 then
            local overlay = Instance.new("Frame")
            overlay.Name = "WhiteOverlay"; overlay.Size = UDim2.fromScale(1, 1)
            overlay.BackgroundColor3 = Color3.new(1, 1, 1)
            overlay.BackgroundTransparency = LS.OldBubbleTransparency
            overlay.BorderSizePixel = 0; overlay.ZIndex = 5; overlay.Parent = frame
            Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, LS.CornerRadius)
            label.TextTransparency = LS.OldBubbleTransparency
        end

        if age == 0 then
            b.tailHolder, b.tailDiamond = createTail(wrapper, b.height, 1)
        end
    end
end

local function removeBubble(plr, bubble)
    local data = playerBubbles[plr]
    if not data or bubble.removing then return end
    bubble.removing = true
    bubble.timer = nil

    local container = getContainer(plr)
    local stack = container and container:FindFirstChild("Stack")
    if stack then
        for _, wrapper in ipairs(stack:GetChildren()) do
            if wrapper:IsA("Frame") and wrapper.Name == "Row" then
                local frame = wrapper:FindFirstChild("Bubble")
                if frame and frame:GetAttribute("BubbleID") == bubble.id then
                    local info = TweenInfo.new(LS.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
                    local label = frame:FindFirstChild("Message")
                    if label then TweenService:Create(label, info, { TextTransparency = 1 }):Play() end
                    local overlay = frame:FindFirstChild("WhiteOverlay")
                    if overlay then TweenService:Create(overlay, info, { BackgroundTransparency = 1 }):Play() end
                    local th = wrapper:FindFirstChild("TailHolder")
                    local tailDiamond = th and th:FindFirstChild("Diamond")
                    if tailDiamond then TweenService:Create(tailDiamond, info, { BackgroundTransparency = 1 }):Play() end
                    break
                end
            end
        end
    end

    task.wait(LS.FadeTime)

    data = playerBubbles[plr]
    if not data then return end
    for i = #data, 1, -1 do
        if data[i] == bubble then table.remove(data, i); break end
    end
    if #data == 0 then
        playerBubbles[plr] = nil
        clearPlayerGui(plr)
    else
        rebuildBubbles(plr)
    end
end

local function addBubble(plr, text)
    playerBubbles[plr] = playerBubbles[plr] or {}
    local data = playerBubbles[plr]

    for _, old in ipairs(data) do
        if not old.removing then
            cancelTimer(old)
            old.timer = task.delay(LS.OldBubbleTime, function()
                if not old.removing then removeBubble(plr, old) end
            end)
        end
    end

    local bubble = {
        id = tostring(os.clock()) .. "_" .. tostring(math.random(100000, 999999)),
        text = tostring(text), width = 0, height = 0,
        timer = nil, frame = nil, removing = false,
    }
    table.insert(data, bubble)
    while #data > LS.MaxBubbles do
        local removed = table.remove(data, 1)
        cancelTimer(removed)
    end
    rebuildBubbles(plr)
    bubble.timer = task.delay(LS.BubbleTime, function()
        if not bubble.removing then removeBubble(plr, bubble) end
    end)
end

local function destroyOldChat()
    pcall(function() RunService:UnbindFromRenderStep("CNP_ChatBubblePositions") end)
    for _, c in ipairs(chatConnections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    for i = #chatConnections, 1, -1 do chatConnections[i] = nil end
    for _, data in pairs(playerBubbles) do
        for _, b in ipairs(data) do cancelTimer(b) end
    end
    for k in pairs(playerBubbles) do playerBubbles[k] = nil end
    if chatGui then chatGui:Destroy(); chatGui = nil end
    pcall(function() TextChatService.BubbleChatConfiguration.Enabled = true end)
end

local function initOldChat()
    if chatGui then return end
    pcall(function() TextChatService.BubbleChatConfiguration.Enabled = false end)

    local previous = pg:FindFirstChild("Old2023ChatGui")
    if previous then previous:Destroy() end

    chatGui = Instance.new("ScreenGui")
    chatGui.Name = "Old2023ChatGui"
    chatGui.ResetOnSpawn = false
    chatGui.IgnoreGuiInset = true
    chatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    chatGui.DisplayOrder = 10 -- chat behind mic
    chatGui.Parent = pg

    table.insert(chatConnections, TextChatService.MessageReceived:Connect(function(message)
        if not message.TextSource then return end
        local plr = Players:GetPlayerByUserId(message.TextSource.UserId)
        if plr then addBubble(plr, message.Text) end
    end))

    table.insert(chatConnections, Players.PlayerRemoving:Connect(function(plr)
        playerBubbles[plr] = nil
        clearPlayerGui(plr)
    end))

    local bubbleRP = RaycastParams.new()
    bubbleRP.FilterType = Enum.RaycastFilterType.Exclude
    bubbleRP.IgnoreWater = true
    RunService:BindToRenderStep("CNP_ChatBubblePositions",
        Enum.RenderPriority.Camera.Value + 5, function()
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local cameraPos = camera.CFrame.Position
        local vp = camera.ViewportSize
        local margin = 200

        for plr, data in pairs(playerBubbles) do
            local container = getContainer(plr)
            if container and #data > 0 then
                local head = getHead(plr)
                if not head then
                    container.Visible = false
                else
                    -- use head CFrame so shiftlock / CameraOffset stays accurate
                    local headPos = head.CFrame.Position
                    local distance = (cameraPos - headPos).Magnitude
                    local visibleThroughWall = true
                    if distance <= LS.MaxDistance then
                        local filter = { camera }
                        if plr.Character then table.insert(filter, plr.Character) end
                        if player.Character then table.insert(filter, player.Character) end
                        bubbleRP.FilterDescendantsInstances = filter
                        local direction = headPos - cameraPos
                        local hit = Workspace:Raycast(cameraPos, direction, bubbleRP)
                        if hit then
                            visibleThroughWall = false
                        end
                    end

                    if distance > LS.MaxDistance or not visibleThroughWall then
                        container.Visible = false
                    else
                        -- local XYZ on head (ChatOffset): Y height, -Z in front
                        local worldPos = head.CFrame:PointToWorldSpace(
                            Vector3.new(LS.ChatOffset.X, head.Size.Y / 2 + LS.ChatOffset.Y, LS.ChatOffset.Z)
                        )
                        local sp, onScreen = camera:WorldToViewportPoint(worldPos)
                        if sp.Z > 0 and sp.X > -margin and sp.X < vp.X + margin
                           and sp.Y > -margin and sp.Y < vp.Y + margin then
                            container.Visible = true
                            -- floor to whole pixels — reduces shiftlock “lệch” jitter
                            container.Position = UDim2.fromOffset(
                                math.floor(sp.X + 0.5),
                                math.floor(sp.Y + 0.5)
                            )
                            local t = (distance - LS.ScaleStart) / (LS.MaxDistance - LS.ScaleStart)
                            local scale = math.clamp(1 - t * (1 - LS.MinScale), LS.MinScale, 1)
                            local us = container:FindFirstChild("DistanceScale")
                            if us then us.Scale = scale end
                            local isFar = distance > LS.FarDistance
                            local stack = container:FindFirstChild("Stack")
                            local far = container:FindFirstChild("Far")
                            if stack then stack.Visible = not isFar end
                            if far then far.Visible = isFar end
                        else
                            container.Visible = false
                        end
                    end
                end
            end
        end
    end)
end

-- =====================================================================
-- MICROPHONE
-- =====================================================================
local function destroyMic()
    pcall(function() RunService:UnbindFromRenderStep("CNP_ChatMicPosition") end)
    if micGui then micGui:Destroy(); micGui = nil end
    micFrame = nil
end

local function initMic()
    if micGui then return end
    micGui = Instance.new("ScreenGui")
    micGui.Name = "CNP_MicGui"
    micGui.ResetOnSpawn = false
    micGui.IgnoreGuiInset = true
    micGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    micGui.DisplayOrder = 15 -- mic overlay in front of chat bubble
    micGui.Parent = pg

    micFrame = Instance.new("Frame")
    micFrame.Name = "MicBubble"
    micFrame.AnchorPoint = Vector2.new(0.5, 1)
    micFrame.Size = UDim2.fromOffset(LS.MicSize, LS.MicSize)
    micFrame.BackgroundTransparency = 1
    micFrame.ZIndex = 100; micFrame.Visible = false; micFrame.Parent = micGui

    local us = Instance.new("UIScale"); us.Name = "DistanceScale"; us.Parent = micFrame

    local body = Instance.new("Frame")
    body.Name = "Body"; body.Size = UDim2.fromScale(1, 1)
    body.BackgroundColor3 = Color3.new(1, 1, 1)
    body.BorderSizePixel = 0; body.ZIndex = 2; body.Parent = micFrame
    Instance.new("UICorner", body).CornerRadius = UDim.new(0, LS.MicCornerRadius)

    local tail = Instance.new("Frame")
    tail.Name = "Tail"; tail.Size = UDim2.fromOffset(LS.MicTailSize, LS.MicTailSize)
    tail.AnchorPoint = Vector2.new(0.5, 0.5)
    tail.Position = UDim2.new(0.5, 0, 1, -2); tail.Rotation = 45  -- đuôi mic xuống nhẹ
    tail.BackgroundColor3 = Color3.new(1, 1, 1)
    tail.BorderSizePixel = 0; tail.ZIndex = 1; tail.Parent = micFrame
    Instance.new("UICorner", tail).CornerRadius = UDim.new(0, 1)

    local img = Instance.new("ImageLabel")
    img.Name = "MicIcon"; img.Size = UDim2.fromScale(0.65, 0.65)
    img.Position = UDim2.fromScale(0.5, 0.5)
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.BackgroundTransparency = 1; img.Image = LS.MicDecal
    img.ScaleType = Enum.ScaleType.Fit; img.ZIndex = 3; img.Parent = body

    RunService:BindToRenderStep("CNP_ChatMicPosition",
        Enum.RenderPriority.Camera.Value + 6, function()
        local camera = Workspace.CurrentCamera
        if not camera or not micFrame then return end
        local head = getHead(player)
        if not head then micFrame.Visible = false; return end
        local headPos = head.CFrame.Position
        local distance = (camera.CFrame.Position - headPos).Magnitude
        -- same height as chat bubble (shared Y)
        local worldPos = head.CFrame:PointToWorldSpace(
            Vector3.new(LS.MicOffset.X, head.Size.Y / 2 + LS.MicOffset.Y, LS.MicOffset.Z)
        )
        local sp = camera:WorldToViewportPoint(worldPos)
        if sp.Z <= 0 or distance > LS.MaxDistance then micFrame.Visible = false; return end
        local t = (distance - LS.ScaleStart) / (LS.MaxDistance - LS.ScaleStart)
        local scale = math.clamp(1 - t * (1 - LS.MinScale), LS.MinScale, 1)
        micFrame.Visible = true
        local s = micFrame:FindFirstChild("DistanceScale")
        if s then s.Scale = scale end
        micFrame.Position = UDim2.fromOffset(
            math.floor(sp.X + LS.MicX * scale + 0.5),
            math.floor(sp.Y - LS.MicY * scale + 0.5)
        )
    end)
end

-- =====================================================================
-- EMOTES TOOL (manual only - does not auto appear / reappear)
-- =====================================================================
local emoteTool = nil
local emoteHubLoaded = false

local function loadEmoteHub()
    -- Cho phép mở lại hub mỗi lần bấm (không kẹt sau lần load đầu)
    local ok, err = pcall(function()
        if type(loadstring) ~= "function" then error("executor has no loadstring") end
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"
        ))()
    end)
    if ok then
        emoteHubLoaded = true
    else
        emoteHubLoaded = false
        warn("[CNP] Emote hub load failed: ", err)
    end
end

local function GiveEmotesTool()
    -- Only create if not already present in current backpack/character
    local backpack = player:FindFirstChildOfClass("Backpack")
    local char = player.Character
    if backpack and backpack:FindFirstChild("Emotes") then return end
    if char and char:FindFirstChild("Emotes") then return end

    if emoteTool and emoteTool.Parent then
        pcall(function() emoteTool:Destroy() end)
        emoteTool = nil
    end

    backpack = backpack or player:WaitForChild("Backpack", 5)
    if not backpack then return end

    emoteTool = Instance.new("Tool")
    emoteTool.Name = "Emotes"
    emoteTool.ToolTip = "Emotes"
    emoteTool.RequiresHandle = false
    emoteTool.CanBeDropped = false
    -- Emote tool has no function (only an item to hold). Use the "emote hub" button for the hub.
    emoteTool.Parent = backpack
end

-- =====================================================================
-- FOG (simplified - no themes)
-- =====================================================================
local applyGlass, fogGui, fogIconGui
do
local fogToggleBtn
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if not atm then atm = Instance.new("Atmosphere"); atm.Parent = Lighting end
local oL = {
    FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor,
    ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, Brightness = Lighting.Brightness,
}
local oA = { Density = atm.Density, Color = atm.Color, Decay = atm.Decay,
    Haze = atm.Haze, Glare = atm.Glare, Offset = atm.Offset }
local FOG = { enabled = false, color = Color3.fromRGB(255, 0, 0), fogStart = 0, fogEnd = 90 }

local function applyFog()
    if not FOG.enabled then
        Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor =
            oL.FogStart, oL.FogEnd, oL.FogColor
        Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness =
            oL.Ambient, oL.OutdoorAmbient, oL.Brightness
        if oL.ClockTime then pcall(function() Lighting.ClockTime = oL.ClockTime end) end
        if atm and atm.Parent then
            atm.Density, atm.Color, atm.Decay = oA.Density, oA.Color, oA.Decay
            atm.Haze, atm.Glare, atm.Offset = oA.Haze, oA.Glare, oA.Offset
        end
        return
    end
    if not atm or not atm.Parent then
        atm = Instance.new("Atmosphere")
        atm.Parent = Lighting
        oA = { Density = atm.Density, Color = atm.Color, Decay = atm.Decay,
            Haze = atm.Haze, Glare = atm.Glare, Offset = atm.Offset }
    end
    Lighting.FogStart = FOG.fogStart
    Lighting.FogEnd = math.max(FOG.fogEnd, FOG.fogStart + 1)
    Lighting.FogColor = FOG.color
    Lighting.Ambient = FOG.color:Lerp(Color3.fromRGB(210, 220, 230), 0.2)
    Lighting.OutdoorAmbient = FOG.color:Lerp(Color3.fromRGB(220, 230, 240), 0.35)

    -- original-style atmosphere (richer color, classic density)
    local sf = 1 - math.clamp(FOG.fogStart / 200, 0, 0.95)
    local ef = math.clamp(180 / math.max(FOG.fogEnd, 1), 0.2, 3.2)
    atm.Density = math.clamp(0.58 * sf * ef, 0, 1)
    atm.Haze = 1.0
    atm.Glare = 0
    atm.Color, atm.Decay = FOG.color, FOG.color
    Lighting.Ambient = FOG.color:Lerp(Color3.fromRGB(210, 220, 230), 0.2)
    Lighting.OutdoorAmbient = FOG.color:Lerp(Color3.fromRGB(220, 230, 240), 0.35)
end

local colorList = {
    -- original vivid fog colors only (no pastel)
    { Name = "Red",     Color = Color3.fromRGB(255, 0, 0) },
    { Name = "Orange",  Color = Color3.fromRGB(255, 128, 0) },
    { Name = "Yellow",  Color = Color3.fromRGB(255, 255, 0) },
    { Name = "Green",   Color = Color3.fromRGB(0, 255, 0) },
    { Name = "Cyan",    Color = Color3.fromRGB(0, 255, 255) },
    { Name = "Blue",    Color = Color3.fromRGB(0, 0, 255) },
    { Name = "Purple",  Color = Color3.fromRGB(128, 0, 255) },
    { Name = "Magenta", Color = Color3.fromRGB(255, 0, 255) },
    { Name = "Pink",   Color = Color3.fromRGB(255, 183, 197) },
    { Name = "White",   Color = Color3.fromRGB(255, 255, 255) },
    { Name = "Black",   Color = Color3.fromRGB(0, 0, 0) },
}
local currentColorIndex = 1

function applyGlass(f, t)
    f.BackgroundTransparency = math.min(t, 0.08)
    local g = Instance.new("UIGradient", f)
    g.Rotation = 120
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 253, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 242, 252)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 225, 245)),
    })
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.05),
        NumberSequenceKeypoint.new(1, 0.12),
    })
end

fogGui = Instance.new("ScreenGui")
fogGui.Name = "Fog_Panel"; fogGui.ResetOnSpawn = false
fogGui.DisplayOrder = 2147483646; fogGui.Parent = pg; fogGui.Enabled = false

local fogFrame = Instance.new("Frame", fogGui)
do
    local fw, fh = fitW(300), fitH(420)
    fogFrame.Size = UDim2.new(0, fw, 0, fh)
    fogFrame.Position = UDim2.new(0.5, -fw/2, 0.5, -fh/2)
end
fogFrame.BackgroundColor3 = Color3.fromRGB(232, 244, 252)
fogFrame.BorderSizePixel = 0; fogFrame.Active = true
Instance.new("UICorner", fogFrame).CornerRadius = UDim.new(0, 12)
applyGlass(fogFrame, 0.12)

local fogStroke = Instance.new("UIStroke", fogFrame)
fogStroke.Color = Color3.fromRGB(200, 160, 70); fogStroke.Thickness = 2

local fogTop = Instance.new("Frame", fogFrame)
fogTop.Size = UDim2.new(1, 0, 0, 45)
fogTop.BackgroundColor3 = Color3.fromRGB(200, 225, 245)
fogTop.BorderSizePixel = 0
Instance.new("UICorner", fogTop).CornerRadius = UDim.new(0, 12)
fogTop.BackgroundTransparency = 0.3
makeDraggable(fogFrame, fogTop)

local topFix = Instance.new("Frame", fogTop)
topFix.Size = UDim2.new(1, 0, 0, 15)
topFix.Position = UDim2.new(0, 0, 0.5, 0)
topFix.BackgroundColor3 = fogTop.BackgroundColor3
topFix.BackgroundTransparency = 0.3
topFix.BorderSizePixel = 0; topFix.ZIndex = 2

local fogTitle = Instance.new("TextLabel", fogTop)
fogTitle.Size = UDim2.new(1, -70, 1, 0); fogTitle.Position = UDim2.new(0, 15, 0, 0)
fogTitle.BackgroundTransparency = 1; fogTitle.Text = "FOG"
fogTitle.TextColor3 = Color3.fromRGB(240, 200, 100); fogTitle.Font = Enum.Font.FredokaOne
fogTitle.TextSize = 20; fogTitle.TextXAlignment = Enum.TextXAlignment.Left; fogTitle.ZIndex = 3

local sig = Instance.new("TextLabel", fogFrame)
sig.Size = UDim2.new(1, -20, 0, 20); sig.Position = UDim2.new(0, 10, 1, -25)
sig.BackgroundTransparency = 1; sig.Text = "winter"
sig.TextColor3 = Color3.fromRGB(200,140,165); sig.Font = Enum.Font.BuilderSans
sig.TextSize = 10; sig.TextXAlignment = Enum.TextXAlignment.Right

local fogScroll = Instance.new("ScrollingFrame", fogFrame)
fogScroll.Size = UDim2.new(1, -20, 1, -75); fogScroll.Position = UDim2.new(0, 10, 0, 55)
fogScroll.BackgroundTransparency = 1; fogScroll.BorderSizePixel = 0
fogScroll.ScrollBarThickness = 3; fogScroll.ScrollBarImageColor3 = Color3.fromRGB(120,120,126)
fogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
fogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local fogLayout = Instance.new("UIListLayout", fogScroll)
fogLayout.Padding = UDim.new(0, 8); fogLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function fogButton(text)
    local b = Instance.new("TextButton", fogScroll)
    b.Size = UDim2.new(1, 0, 0, 35)
    b.BackgroundColor3 = Color3.fromRGB(210, 230, 248)
    b.BackgroundTransparency = 0.1
    b.Text = text; b.TextColor3 = Color3.fromRGB(100,60,85)
    b.Font = Enum.Font.FredokaOne; b.TextSize = 14; b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local colorBtn = fogButton("[ Red ]")
colorBtn.Activated:Connect(function()
    currentColorIndex = currentColorIndex % #colorList + 1
    local item = colorList[currentColorIndex]
    FOG.color = item.Color
    colorBtn.Text = "[ "..item.Name.." ]"
    if FOG.enabled then applyFog() end
end)

fogToggleBtn = fogButton("Fog: Disabled")
fogToggleBtn.BackgroundColor3 = Color3.fromRGB(240,150,170)
fogToggleBtn.TextColor3 = Color3.new(1,1,1)
fogToggleBtn.Activated:Connect(function()
    FOG.enabled = not FOG.enabled
    fogToggleBtn.Text = FOG.enabled and "Fog: Enabled" or "Fog: Disabled"
    fogToggleBtn.BackgroundColor3 = FOG.enabled and Color3.fromRGB(130,220,160)
        or Color3.fromRGB(240,150,170)
    applyFog()
end)

local function mkSlider(parent, label, mn, mx, dv, callback)
    local c = Instance.new("Frame", parent)
    c.Size = UDim2.new(1, 0, 0, 40); c.BackgroundColor3 = Color3.fromRGB(215, 232, 248)
    c.BorderSizePixel = 0; Instance.new("UICorner", c).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", c)
    lbl.Size = UDim2.new(1, -20, 0, 18); lbl.Position = UDim2.new(0, 10, 0, 2)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(40,40,46)
    lbl.Font = Enum.Font.BuilderSansBold; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = label..": "..dv

    local bar = Instance.new("Frame", c)
    bar.Size = UDim2.new(1, -20, 0, 6); bar.Position = UDim2.new(0, 10, 0, 25)
    bar.BackgroundColor3 = Color3.fromRGB(235,200,215); bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local r = (dv - mn) / (mx - mn)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new(r, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(70, 150, 210)
    fill.BorderSizePixel = 0; Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local kn = Instance.new("Frame", bar)
    kn.Size = UDim2.fromOffset(12, 12); kn.Position = UDim2.new(r, -6, 0.5, -6)
    kn.BackgroundColor3 = Color3.fromRGB(255,250,255); kn.BorderSizePixel = 0
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1, 0)

    local hit = Instance.new("TextButton", bar)
    hit.Size = UDim2.new(1, 0, 2, 15); hit.Position = UDim2.new(0, 0, 0, -5)
    hit.BackgroundTransparency = 1; hit.Text = ""; hit.Active = true

    local dragging = false
    local function update(x)
        local w = math.max(bar.AbsoluteSize.X, 1)
        local pos = math.clamp((x - bar.AbsolutePosition.X) / w, 0, 1)
        local v = math.floor(mn + (mx - mn) * pos + 0.5)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        kn.Position = UDim2.new(pos, -6, 0.5, -6)
        lbl.Text = label..": "..v
        callback(v)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
           or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

mkSlider(fogScroll, "Fog Start", 0, 1000, FOG.fogStart, function(v)
    FOG.fogStart = v
    if FOG.enabled then applyFog() end
end)
mkSlider(fogScroll, "Fog End", 1, 1000, FOG.fogEnd, function(v)
    FOG.fogEnd = v
    if FOG.enabled then applyFog() end
end)

local timeLabel = Instance.new("TextLabel", fogScroll)
timeLabel.Size = UDim2.new(1, 0, 0, 20); timeLabel.BackgroundTransparency = 1
timeLabel.Text = "TIME"; timeLabel.TextColor3 = Color3.fromRGB(40,40,46)
timeLabel.Font = Enum.Font.BuilderSansBold; timeLabel.TextSize = 12
timeLabel.TextXAlignment = Enum.TextXAlignment.Left

local dayBtn = fogButton("Day")
dayBtn.Activated:Connect(function() Lighting.ClockTime = 14; Lighting.Brightness = 2 end)
local nightBtn = fogButton("Night")
nightBtn.Activated:Connect(function() Lighting.ClockTime = 0; Lighting.Brightness = 0.5 end)

fogIconGui = Instance.new("ScreenGui")
fogIconGui.Name = "Fog_Icon"; fogIconGui.ResetOnSpawn = false
fogIconGui.DisplayOrder = 2147483647; fogIconGui.Parent = pg; fogIconGui.Enabled = false

local fogIcon = Instance.new("ImageButton", fogIconGui)
fogIcon.Size = UDim2.fromOffset(50, 50)
fogIcon.Position = UDim2.new(0.03, 0, 0.4, 0)
fogIcon.BackgroundColor3 = Color3.fromRGB(200, 225, 245)
fogIcon.Image = "rbxthumb://type=Asset&id=988116310&w=420&h=420"
fogIcon.ScaleType = Enum.ScaleType.Fit; fogIcon.Active = true
Instance.new("UICorner", fogIcon).CornerRadius = UDim.new(1, 0)
local iconStroke = Instance.new("UIStroke", fogIcon)
iconStroke.Color = Color3.fromRGB(255,150,190); iconStroke.Thickness = 2

do
    local DRAG_PX = 30
    local iDrag, iStart, iPos, iMoved, lastToggle = false, nil, nil, false, 0
    local function togglePanel()
        if os.clock() - lastToggle < 0.25 then return end
        lastToggle = os.clock()
        fogGui.Enabled = not fogGui.Enabled
        if fogGui.Enabled then
            local cam = Workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1000, 600)
            local ap = fogFrame.AbsolutePosition
            if ap.Y > vp.Y - 120 or ap.Y < -20
               or ap.X > vp.X - 60 or ap.X < -fogFrame.AbsoluteSize.X + 60 then
                fogFrame.Position = UDim2.new(0.5, -120, 0.5, -175)
            end
        end
    end
    fogIcon.AutoButtonColor = false
    fogIcon.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            iDrag = true; iMoved = false
            iStart = input.Position; iPos = fogIcon.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if iDrag and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - iStart
            if d.Magnitude > DRAG_PX then iMoved = true end
            if iMoved then
                fogIcon.Position = UDim2.new(iPos.X.Scale, iPos.X.Offset + d.X,
                    iPos.Y.Scale, iPos.Y.Offset + d.Y)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if iDrag and (input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch) then
            iDrag = false
        end
    end)
    fogIcon.Activated:Connect(function()
        if not iMoved then togglePanel() end
    end)
end

-- =====================================================================
-- MUTE SHERIFF KILL SOUND
-- =====================================================================
end -- close FOG block

local TargetSoundName = "Kill"
local TargetSoundId = "rbxassetid://296102734"
local muteSheriffConns = {}

local function MuteSound(sound)
    if not sound or not sound:IsA("Sound") then return end
    if not muteSheriffActive then return end
    if sound.Name == TargetSoundName or sound.SoundId == TargetSoundId then
        sound.Volume = 0
        pcall(function() sound:Stop() end)
    end
end

local function muteSheriffDisconnect()
    for _, c in ipairs(muteSheriffConns) do
        pcall(function() c:Disconnect() end)
    end
    for i = #muteSheriffConns, 1, -1 do muteSheriffConns[i] = nil end
end

local function muteSheriffEnable()
    muteSheriffDisconnect()
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("Sound") then MuteSound(v) end
    end
    table.insert(muteSheriffConns, game.DescendantAdded:Connect(function(obj)
        if not muteSheriffActive then return end
        if obj:IsA("Sound") then
            MuteSound(obj)
            table.insert(muteSheriffConns, obj:GetPropertyChangedSignal("Volume"):Connect(function()
                MuteSound(obj)
            end))
            table.insert(muteSheriffConns, obj:GetPropertyChangedSignal("SoundId"):Connect(function()
                MuteSound(obj)
            end))
            table.insert(muteSheriffConns, obj:GetPropertyChangedSignal("Playing"):Connect(function()
                if obj.Playing then MuteSound(obj) end
            end))
        end
    end))
end

local function muteSheriffDisable()
    muteSheriffActive = false
    muteSheriffDisconnect()
end

-- =====================================================================
-- UI HELPERS
-- =====================================================================
local UI = {
    -- NO AI XMAS 2023 · handcrafted Christmas card palette
    -- deep pine night · cream ink · christmas red · champagne gold
    bg     = Color3.fromRGB(26, 34, 28),
    row    = Color3.fromRGB(36, 46, 38),
    hover  = Color3.fromRGB(46, 58, 48),
    line   = Color3.fromRGB(120, 95, 60),
    text   = Color3.fromRGB(245, 240, 228),
    dim    = Color3.fromRGB(155, 145, 125),
    accent = Color3.fromRGB(155, 42, 48),
    off    = Color3.fromRGB(32, 40, 34),
    gold   = Color3.fromRGB(200, 168, 95),
    cream  = Color3.fromRGB(245, 240, 228),
    pine   = Color3.fromRGB(45, 85, 55),
    font   = Enum.Font.Gotham,          -- clear body
    titleFont = Enum.Font.GothamBold,   -- clear title
    corner = 6,
}

local function softTween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.18,
        Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- subtle press feedback (no particle clutter)
local function xmasClickFX(anchor)
    if not anchor or not anchor:IsA("GuiObject") then return end
    local prev = anchor.BackgroundTransparency
    softTween(anchor, { BackgroundTransparency = math.clamp(prev - 0.08, 0, 1) }, 0.06)
    task.delay(0.08, function()
        if anchor and anchor.Parent then
            softTween(anchor, { BackgroundTransparency = prev }, 0.16)
        end
    end)
end

-- Chi 1 lan click (tranh double bat/tat)
local function bindClick(btn, fn)
    local last = 0
    local function fire()
        local now = tick()
        if now - last < 0.25 then return end
        last = now
        pcall(fn)
    end
    btn.Activated:Connect(fire)
end

function UI.header(parent, order, text)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 22)
    wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = order
    wrap.Parent = parent
    local l = Instance.new("TextLabel", wrap)
    l.Size = UDim2.new(1, -8, 1, 0)
    l.Position = UDim2.new(0, 8, 0, 0)
    l.BackgroundTransparency = 1
    l.Font = UI.titleFont
    l.TextSize = 13
    l.TextColor3 = UI.dim
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Bottom
    l.Text = string.upper(text)
    local tick = Instance.new("Frame", wrap)
    tick.Size = UDim2.new(0, 2, 0, 10)
    tick.Position = UDim2.new(0, 0, 1, -12)
    tick.BackgroundColor3 = UI.accent
    tick.BackgroundTransparency = 0.25
    tick.BorderSizePixel = 0
    return wrap
end

function UI.rowBase(parent, order, text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, isMobile and 32 or 34)
    b.LayoutOrder = order
    b.BackgroundColor3 = UI.row
    b.BackgroundTransparency = 0.12
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.Active = true
    b.Selectable = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, UI.corner)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = UI.line
    stroke.Transparency = 0.55
    stroke.Thickness = 1
    local lbl = Instance.new("TextLabel", b)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.Size = UDim2.new(1, -40, 1, 0)
    lbl.Font = UI.font
    lbl.TextSize = 15
    lbl.TextColor3 = UI.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Text = text
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Active = false
    b.MouseEnter:Connect(function()
        softTween(b, { BackgroundColor3 = UI.hover, BackgroundTransparency = 0.04 }, 0.12)
        softTween(stroke, { Transparency = 0.35 }, 0.12)
    end)
    b.MouseLeave:Connect(function()
        softTween(b, { BackgroundColor3 = UI.row, BackgroundTransparency = 0.12 }, 0.14)
        softTween(stroke, { Transparency = 0.55 }, 0.14)
    end)
    b.Parent = parent
    return b, lbl
end

function UI.toggle(parent, order, text, initial, callback)
    local state = initial and true or false
    local onCol  = UI.accent
    local offCol = UI.off
    local onHover  = Color3.fromRGB(180, 55, 58)
    local offHover = UI.hover

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, isMobile and 30 or 32)
    b.LayoutOrder = order
    b.BackgroundTransparency = 0
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.Active = true
    b.Selectable = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = UI.line
    stroke.Thickness = 1
    stroke.Transparency = 0.5

    local lbl = Instance.new("TextLabel", b)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.Font = UI.font
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Text = text
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Active = false
    lbl.ZIndex = 2

    local function paint()
        b.BackgroundColor3 = state and onCol or offCol
        b.BackgroundTransparency = state and 0.05 or 0.15
        lbl.TextColor3 = state and Color3.fromRGB(250, 246, 242) or UI.dim
        stroke.Transparency = state and 0.35 or 0.55
    end
    paint()

    b.MouseEnter:Connect(function()
        b.BackgroundColor3 = state and onHover or offHover
        b.BackgroundTransparency = 0.02
    end)
    b.MouseLeave:Connect(function()
        paint()
    end)

    local last = 0
    local function toggle()
        local now = tick()
        if now - last < 0.25 then return end
        last = now
        pcall(xmasClickFX, b)
        state = not state
        paint()
        pcall(callback, state)
    end
    b.Activated:Connect(toggle)
    b.Parent = parent
    return b
end

function UI.action(parent, order, text, callback)
    local b, lbl = UI.rowBase(parent, order, text)
    lbl.TextSize = 14
    local arrow = Instance.new("TextLabel", b)
    arrow.BackgroundTransparency = 1
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -12, 0.5, 0)
    arrow.Size = UDim2.fromOffset(16, 18)
    arrow.Font = UI.font
    arrow.TextSize = 17
    arrow.TextYAlignment = Enum.TextYAlignment.Center
    arrow.TextColor3 = UI.dim
    arrow.Text = "›"
    arrow.Active = false
    arrow.ZIndex = 2

    local hit = Instance.new("TextButton", b)
    hit.Size = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 5
    hit.Active = true
    hit.AutoButtonColor = false
    hit.BorderSizePixel = 0

    local last = 0
    local function fire()
        local now = tick()
        if now - last < 0.25 then return end
        last = now
        pcall(xmasClickFX, b)
        softTween(arrow, { TextColor3 = UI.accent }, 0.08)
        task.delay(0.12, function()
            if arrow and arrow.Parent then
                softTween(arrow, { TextColor3 = UI.dim }, 0.2)
            end
        end)
        pcall(callback)
    end
    hit.Activated:Connect(fire)
    return b
end

function UI.switch(parent, order, label, leftText, rightText, initialRight, callback)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, isMobile and 34 or 36)
    wrap.BackgroundColor3 = UI.row
    wrap.BackgroundTransparency = 0.05
    wrap.BorderSizePixel = 0
    Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, UI.corner)
    wrap.LayoutOrder = order; wrap.Parent = parent

    local title = Instance.new("TextLabel", wrap)
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(0.38, 0, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.Font = UI.font; title.TextSize = 16; title.TextColor3 = UI.text
    title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = label

    local seg = Instance.new("Frame", wrap)
    seg.Size = UDim2.new(0.55, -16, 0, 28)
    seg.AnchorPoint = Vector2.new(1, 0.5)
    seg.Position = UDim2.new(1, -10, 0.5, 0)
    seg.BackgroundColor3 = UI.off; seg.BorderSizePixel = 0
    Instance.new("UICorner", seg).CornerRadius = UDim.new(1, 0)

    local function mk(txt, isRight)
        local b = Instance.new("TextButton", seg)
        b.Size = UDim2.new(0.5, -2, 1, -4)
        b.Position = isRight and UDim2.new(0.5, 1, 0, 2) or UDim2.new(0, 2, 0, 2)
        b.BackgroundColor3 = UI.row; b.BackgroundTransparency = 1
        b.Text = txt; b.Font = UI.font; b.TextSize = 14
        b.TextColor3 = UI.dim; b.BorderSizePixel = 0; b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        return b
    end
    local leftBtn = mk(leftText, false)
    local rightBtn = mk(rightText, true)
    local isRight = initialRight and true or false
    local function paint()
        if isRight then
            leftBtn.BackgroundTransparency = 1; leftBtn.TextColor3 = UI.dim
            rightBtn.BackgroundTransparency = 0
            rightBtn.BackgroundColor3 = UI.accent
            rightBtn.TextColor3 = Color3.new(1,1,1)
        else
            rightBtn.BackgroundTransparency = 1; rightBtn.TextColor3 = UI.dim
            leftBtn.BackgroundTransparency = 0
            leftBtn.BackgroundColor3 = UI.accent
            leftBtn.TextColor3 = Color3.new(1,1,1)
        end
    end
    paint()
    bindClick(leftBtn, function()
        if isRight then isRight = false; paint(); callback(false) end
    end)
    bindClick(rightBtn, function()
        if not isRight then isRight = true; paint(); callback(true) end
    end)
    return wrap
end

function UI.separator(parent, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -16, 0, 1)
    f.BackgroundColor3 = UI.line
    f.BackgroundTransparency = 0.55
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.Parent = parent
    return f
end

function UI.slider(parent, order, label, minV, maxV, curV, callback, tall)
    local h = tall and (isMobile and 72 or 78) or (isMobile and 54 or 58)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, h)
    wrap.BackgroundColor3 = UI.row
    wrap.BackgroundTransparency = 0.05
    wrap.BorderSizePixel = 0; wrap.LayoutOrder = order
    Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, UI.corner)
    local st = Instance.new("UIStroke", wrap)
    st.Color = UI.line; st.Transparency = 0.55; st.Thickness = 1
    wrap.Parent = parent

    local lbl = Instance.new("TextLabel", wrap)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -28, 0, tall and 22 or 18)
    lbl.Position = UDim2.new(0, 14, 0, tall and 6 or 4)
    lbl.Font = UI.font; lbl.TextSize = tall and 18 or 16; lbl.TextColor3 = UI.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label .. ": " .. tostring(curV)

    local barH = tall and 10 or 6
    local barY = tall and 40 or 30
    local knS = tall and 18 or 14
    local bar = Instance.new("Frame", wrap)
    bar.Size = UDim2.new(1, -24, 0, barH); bar.Position = UDim2.new(0, 12, 0, barY)
    bar.BackgroundColor3 = UI.off; bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local r = (curV - minV) / math.max(maxV - minV, 1)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new(r, 0, 1, 0)
    fill.BackgroundColor3 = UI.accent; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local kn = Instance.new("Frame", bar)
    kn.Size = UDim2.fromOffset(knS, knS)
    kn.Position = UDim2.new(r, -knS / 2, 0.5, -knS / 2)
    kn.BackgroundColor3 = Color3.fromRGB(236, 232, 226); kn.BorderSizePixel = 0
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1, 0)

    local hit = Instance.new("TextButton", bar)
    hit.Size = UDim2.new(1, 0, 3, 12); hit.Position = UDim2.new(0, 0, 0, -8)
    hit.BackgroundTransparency = 1; hit.Text = ""; hit.Active = true
    local dragging = false
    local function update(x)
        local w = math.max(bar.AbsoluteSize.X, 1)
        local pos = math.clamp((x - bar.AbsolutePosition.X) / w, 0, 1)
        local v = math.floor(minV + (maxV - minV) * pos + 0.5)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        kn.Position = UDim2.new(pos, -knS / 2, 0.5, -knS / 2)
        lbl.Text = label .. ": " .. tostring(v)
        callback(v)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
           or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return wrap
end

-- =====================================================================
-- MAIN PANEL
-- =====================================================================
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "CNP_Panel"; mainGui.ResetOnSpawn = false
mainGui.DisplayOrder = 2147483647
pcall(function() mainGui.OnTopOfCoreBlur = true end)
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mainGui.IgnoreGuiInset = true
pcall(function() mainGui.Parent = game:GetService("CoreGui") end)
if not mainGui.Parent then mainGui.Parent = pg end
mainGui.Enabled = true

local mainFrame = Instance.new("Frame", mainGui)
do
    local vp = getViewport()
    -- bigger panel
    local mw = isMobile and math.clamp(math.floor(vp.X * 0.42), 280, 360) or 400
    local mh = isMobile and math.max(360, math.floor(vp.Y - 30)) or 680
    mainFrame.Size = UDim2.new(0, mw, 0, mh)
    mainFrame.Position = UDim2.new(0.5, -mw / 2, 0.5, -mh / 2)
end
mainFrame.BackgroundColor3 = UI.bg
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.BackgroundTransparency = 0
mainFrame.Active = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
do
    local st = Instance.new("UIStroke", mainFrame)
    st.Color = Color3.fromRGB(120, 95, 60)
    st.Transparency = 0.35
    st.Thickness = 1.5
end
do
    -- christmas red ribbon edge
    local strip = Instance.new("Frame", mainFrame)
    strip.Size = UDim2.new(0, 3, 1, -20)
    strip.Position = UDim2.new(0, 6, 0, 10)
    strip.BackgroundColor3 = UI.accent
    strip.BackgroundTransparency = 0.15
    strip.BorderSizePixel = 0
    strip.ZIndex = 5
    local gold = Instance.new("Frame", strip)
    gold.Size = UDim2.new(1, 0, 0, 8)
    gold.Position = UDim2.new(0, 0, 0, 0)
    gold.BackgroundColor3 = UI.gold
    gold.BackgroundTransparency = 0.25
    gold.BorderSizePixel = 0
end
UI.full = mainFrame.Size

local topBar = Instance.new("TextLabel", mainFrame)
topBar.Size = UDim2.new(1, -40, 0, 34); topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundTransparency = 1; topBar.Text = "CNP made by sabrine"
topBar.TextColor3 = UI.text; topBar.Font = UI.titleFont; topBar.TextSize = 17
topBar.TextXAlignment = Enum.TextXAlignment.Left; topBar.Active = true
topBar.ZIndex = 3
Instance.new("UIPadding", topBar).PaddingLeft = UDim.new(0, 18)


local minBtn = Instance.new("TextButton", mainFrame)
minBtn.Size = UDim2.fromOffset(26, 26); minBtn.Position = UDim2.new(1, -30, 0, 2)
minBtn.BackgroundTransparency = 1; minBtn.TextColor3 = UI.dim
minBtn.Font = UI.font; minBtn.TextSize = 20; minBtn.Text = "-"; minBtn.BorderSizePixel = 0
minBtn.ZIndex = 4; minBtn.Active = true

local titleLine = Instance.new("Frame", mainFrame)
titleLine.Size = UDim2.new(1, -24, 0, 1)
titleLine.Position = UDim2.new(0, 12, 0, 38)
titleLine.BackgroundColor3 = UI.line
titleLine.BackgroundTransparency = 0.5; titleLine.BorderSizePixel = 0

makeDraggable(mainFrame, topBar)

-- winter decor (fall only)
do
    local decor = Instance.new("Frame")
    decor.Name = "Decor"
    decor.Size = UDim2.fromScale(1, 1)
    decor.BackgroundTransparency = 1
    decor.BorderSizePixel = 0
    decor.ClipsDescendants = true
    decor.ZIndex = 8
    decor.Active = false
    decor.Parent = mainFrame
    UI.decor = decor

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 1)
    bar.AnchorPoint = Vector2.new(0, 1)
    bar.Position = UDim2.fromScale(0, 1)
    bar.BorderSizePixel = 0
    bar.BackgroundColor3 = UI.line
    bar.BackgroundTransparency = 0.4
    bar.ZIndex = 1
    bar.Active = false
    bar.Parent = decor

    local rng = Random.new()
    local flakes = {}
    local SNOW_IMG = "rbxassetid://15216668864"
    local N = isMobile and 12 or 18
    for i = 1, N do
        local f = Instance.new("ImageLabel")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ZIndex = 8
        f.Active = false
        f.Image = SNOW_IMG
        f.ScaleType = Enum.ScaleType.Fit
        f.ImageTransparency = rng:NextNumber(0.35, 0.7)
        f.Parent = decor
        local w = rng:NextInteger(8, 16)
        local h = math.max(7, math.floor(w * rng:NextNumber(0.7, 1.05)))
        f.Size = UDim2.fromOffset(w, h)
        f.Rotation = rng:NextNumber(-20, 20)
        local x0 = rng:NextNumber(0.04, 0.96)
        local y0 = -40 - (i % 12) * 28
        f.Position = UDim2.new(x0, 0, 0, y0)
        flakes[i] = {
            f = f, x0 = x0, y = y0,
            speed = rng:NextNumber(28, 70),
            amp = rng:NextNumber(0.008, 0.03),
            freq = rng:NextNumber(0.5, 1.6),
            phase = rng:NextNumber(0, 6.28),
            rot = f.Rotation,
            rotSpeed = rng:NextNumber(-30, 30),
            baseW = w, baseH = h,
            wobble = rng:NextNumber(0.6, 1.4),
        }
    end

    local t0 = 0
    task.spawn(function()
        while decor.Parent do
            local dt = task.wait(isMobile and 0.04 or 0.03)
            if not mainFrame.Parent then break end
            local hgt = mainFrame.AbsoluteSize.Y
            if hgt < 40 then hgt = 420 end
            dt = math.clamp(dt, 0, 0.05)
            t0 = t0 + dt
            for _, pflake in ipairs(flakes) do
                pflake.y = pflake.y + pflake.speed * dt
                if pflake.y > hgt + 20 then
                    pflake.y = -rng:NextNumber(10, 50)
                    pflake.x0 = rng:NextNumber(0.04, 0.96)
                    pflake.speed = rng:NextNumber(28, 70)
                end
                pflake.rot = pflake.rot + pflake.rotSpeed * dt
                local sway = math.sin(t0 * pflake.freq + pflake.phase) * pflake.amp
                pflake.f.Position = UDim2.new(pflake.x0 + sway, 0, 0, pflake.y)
                pflake.f.Rotation = pflake.rot
            end
        end
    end)
end

local scroll = Instance.new("ScrollingFrame", mainFrame)
scroll.Size = UDim2.new(1, -16, 1, -44); scroll.Position = UDim2.new(0, 10, 0, 38)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4; scroll.ScrollBarImageColor3 = UI.line
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ScrollingEnabled = true
scroll.Active = true
scroll.Selectable = false
scroll.ElasticBehavior = Enum.ElasticBehavior.Always
scroll.ClipsDescendants = true
scroll.ZIndex = 2
do
    local lay = Instance.new("UIListLayout", scroll)
    lay.Padding = UDim.new(0, 5); lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        -- dam bao canvas du cao de scroll
        scroll.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 16)
    end)
end
do
    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 2)
end

local isMini = false

-- ===== MOVEMENT =====
UI.header(scroll, 0.5, "movement")
UI.toggle(scroll, 1, "speed", false, function(v)
    speedEnabled = v
    if not v then
        renderFlickTarget = 0
        speedResetUnlock()
        local hum = speedHumanoid or (player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
        if hum and not hum.PlatformStand then
            hum.WalkSpeed = BASE_SPEED
        end
    end
end)

UI.slider(scroll, 1.15, "speed value", 80, 300, SPEED_VALUE, function(v)
    SPEED_VALUE = v
end, true)

-- fly gui → order 2 (later)
-- esp → order 3 (later)
UI.toggle(scroll, 4, "no reload animation", noReloadActive, function(v) noReloadActive = v end)
-- crosshair → order 5 (later)

UI.separator(scroll, 5.5)


-- =====================================================================
-- HOTBAR (for mobile) — quick equip bar
-- =====================================================================
local hotbarActive = false
local hotbarGui = nil
local hotbarConns = {}

local function destroyHotbar()
    for _, c in ipairs(hotbarConns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(hotbarConns)
    if hotbarGui then
        pcall(function() hotbarGui:Destroy() end)
        hotbarGui = nil
    end
    local old = pg:FindFirstChild("QuickEquipBarGui")
    if old then pcall(function() old:Destroy() end) end
    hotbarActive = false
end

local function initHotbar()
    if hotbarGui then return end
    destroyHotbar()
    hotbarActive = true

    local MAX_ITEMS = 8
    local SLOT_SIZE = 50
    local SLOT_GAP = 6
    local PAD = 4

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "QuickEquipBarGui"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 50
    pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
    if not screenGui.Parent then screenGui.Parent = pg end
    hotbarGui = screenGui

    local bar = Instance.new("Frame")
    bar.AnchorPoint = Vector2.new(0.5, 1) -- grow from center-bottom, no jump when width changes
    bar.Size = UDim2.new(0, SLOT_SIZE + PAD * 2, 0, SLOT_SIZE + PAD * 2)
    bar.Position = UDim2.new(0.5, 0, 1, -86)
    bar.BackgroundColor3 = Color3.fromRGB(15, 16, 19)
    bar.BackgroundTransparency = 0.6
    bar.BorderSizePixel = 0
    bar.Active = true
    bar.Parent = screenGui
    makeDraggable(bar, bar)

    local barPad = Instance.new("UIPadding")
    barPad.PaddingTop = UDim.new(0, PAD)
    barPad.PaddingBottom = UDim.new(0, PAD)
    barPad.PaddingLeft = UDim.new(0, PAD)
    barPad.PaddingRight = UDim.new(0, PAD)
    barPad.Parent = bar

    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Padding = UDim.new(0, SLOT_GAP)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = bar

    -- only change SIZE; never reset Position (keeps drag place, no tè le)
    local function updateBarWidth(count)
        local shown = math.max(1, math.clamp(count, 0, MAX_ITEMS))
        local width = shown * SLOT_SIZE + (shown - 1) * SLOT_GAP + PAD * 2
        local height = SLOT_SIZE + PAD * 2
        if bar.Size.X.Offset ~= width or bar.Size.Y.Offset ~= height then
            bar.Size = UDim2.new(0, width, 0, height)
        end
    end

    local function getHumanoid()
        local char = player.Character
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function getToolIcon(tool)
        if tool.TextureId and tool.TextureId ~= "" then
            return tool.TextureId
        end
        local handle = tool:FindFirstChild("Handle")
        if handle then
            local decal = handle:FindFirstChildWhichIsA("Decal", true)
            if decal and decal.Texture ~= "" then
                return decal.Texture
            end
            local mesh = handle:FindFirstChildWhichIsA("SpecialMesh", true)
            if mesh and mesh.TextureId ~= "" then
                return mesh.TextureId
            end
        end
        return "rbxasset://textures/ui/GuiImagePlaceholder.png"
    end

    local refreshToken = 0
    local lastToolSig = ""

    local function collectTools()
        local bag = player:FindFirstChildOfClass("Backpack") or bp
        local tools = {}
        local seen = {}
        -- backpack first = same order as default hotbar / backpack list
        if bag then
            for _, item in ipairs(bag:GetChildren()) do
                if item:IsA("Tool") and not seen[item] then
                    seen[item] = true
                    table.insert(tools, item)
                    if #tools >= MAX_ITEMS then return tools end
                end
            end
        end
        if player.Character then
            for _, item in ipairs(player.Character:GetChildren()) do
                if item:IsA("Tool") and not seen[item] then
                    seen[item] = true
                    table.insert(tools, item)
                    if #tools >= MAX_ITEMS then return tools end
                end
            end
        end
        return tools
    end

    local function refreshButtons()
        if not hotbarActive or not bar.Parent then return end
        refreshToken = refreshToken + 1
        local myToken = refreshToken
        task.defer(function()
            if myToken ~= refreshToken then return end
            if not hotbarActive or not bar.Parent then return end

        local tools = collectTools()

        -- skip rebuild if same tools + equip state (stops flicker / jump)
        local sigParts = {}
        for _, t in ipairs(tools) do
            sigParts[#sigParts + 1] = tostring(t) .. ":" .. tostring(t.Parent == player.Character)
        end
        local sig = table.concat(sigParts, "|")
        if sig == lastToolSig and #bar:GetChildren() > 2 then
            return
        end
        lastToolSig = sig

        for _, child in ipairs(bar:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for idx, tool in ipairs(tools) do
            local isEquipped = (tool.Parent == player.Character)
            local btn = Instance.new("TextButton")
            btn.LayoutOrder = idx
            btn.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
            btn.Text = ""
            btn.AutoButtonColor = true
            btn.BackgroundColor3 = isEquipped
                and Color3.fromRGB(32, 36, 44)
                or Color3.fromRGB(22, 24, 29)
            btn.BackgroundTransparency = isEquipped and 0.62 or 0.78
            btn.BorderSizePixel = 0
            btn.Parent = bar

            if isEquipped then
                local stroke = Instance.new("UIStroke")
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Color = Color3.fromRGB(0, 162, 255)
                stroke.Transparency = 0.05
                stroke.Thickness = 2
                stroke.Parent = btn
            end

            local slotNum = Instance.new("TextLabel")
            slotNum.Size = UDim2.new(0, 14, 0, 14)
            slotNum.Position = UDim2.new(0, 4, 0, 2)
            slotNum.BackgroundTransparency = 1
            slotNum.Text = tostring(idx)
            slotNum.TextColor3 = isEquipped
                and Color3.fromRGB(145, 215, 255)
                or Color3.fromRGB(200, 205, 215)
            slotNum.TextTransparency = isEquipped and 0.05 or 0.3
            slotNum.Font = Enum.Font.GothamBold
            slotNum.TextSize = 11
            slotNum.TextXAlignment = Enum.TextXAlignment.Left
            slotNum.Parent = btn

            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0.76, 0, 0.76, 0)
            icon.Position = UDim2.new(0.12, 0, 0.14, 0)
            icon.BackgroundTransparency = 1
            icon.Image = getToolIcon(tool)
            icon.ScaleType = Enum.ScaleType.Fit
            icon.Parent = btn

            btn.MouseButton1Click:Connect(function()
                local hum = getHumanoid()
                if not hum then return end
                if tool.Parent == player.Character then
                    hum:UnequipTools()
                else
                    hum:EquipTool(tool)
                end
                task.defer(refreshButtons)
            end)
        end

        updateBarWidth(#tools)
        end) -- end deferred debounce
    end

    refreshButtons()

    local function bindBag(bag)
        if not bag then return end
        table.insert(hotbarConns, bag.ChildAdded:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
        table.insert(hotbarConns, bag.ChildRemoved:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
    end
    bindBag(player:FindFirstChildOfClass("Backpack") or bp)

    table.insert(hotbarConns, player.CharacterAdded:Connect(function(char)
        lastToolSig = ""
        table.insert(hotbarConns, char.ChildAdded:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
        table.insert(hotbarConns, char.ChildRemoved:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
        task.wait(0.2)
        bindBag(player:FindFirstChildOfClass("Backpack"))
        refreshButtons()
    end))
    if player.Character then
        table.insert(hotbarConns, player.Character.ChildAdded:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
        table.insert(hotbarConns, player.Character.ChildRemoved:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
    end

    -- poll: show tools as soon as they appear in backpack (no need to equip first)
    task.spawn(function()
        while hotbarActive and hotbarGui and hotbarGui.Parent do
            refreshButtons()
            task.wait(0.35)
        end
    end)
end


-- =====================================================================
-- ANTIFLING (menu toggle — off by default)
-- =====================================================================
local function setAntifling(on)
    antiflingActive = on and true or false
    if not antiflingActive then
        print("[CNP] antifling off (reload character / rejoin to fully clear external script if needed)")
        return
    end
    task.spawn(function()
        local ok, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/sytcal/antifling/main/9999"))()
        end)
        if ok then
            print("[CNP] antifling on")
        else
            antiflingActive = false
            warn("[CNP] antifling load failed: ", err)
        end
    end)
end

-- ===== TOOLS =====
UI.header(scroll, 6.5, "tools")
-- c4 menu → order 7 (later)
UI.action(scroll, 8, "emote hub", function() loadEmoteHub() end)
UI.action(scroll, 8.1, "emote tool", function()
    GiveEmotesTool()
    print("emote tool -> backpack")
end)
UI.action(scroll, 9, "f3x tool", function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(
            "https://scriptblox.com/raw/Universal-Script-F3X-Tool-44387"
        ))()
    end)
    if not ok then warn("[CNP] F3X load loi: " .. tostring(err)) end
end)
UI.action(scroll, 10, "tool grip", function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(
            "https://scriptblox.com/raw/Universal-Script-Tool-grip-script-235304"
        ))()
    end)
    if not ok then warn("[CNP] Tool grip load loi: " .. tostring(err)) end
end)
UI.toggle(scroll, 10.2, "hotbar (for mobile)", false, function(v)
    if v then
        initHotbar()
    else
        destroyHotbar()
    end
end)
UI.separator(scroll, 10.5)

-- ===== VISUAL =====
UI.header(scroll, 11, "visual")
UI.toggle(scroll, 13, "shiftlock 2023", enableOldShiftLock, function(v)
    enableOldShiftLock = v
    if not v then
        _slWasLocked = false
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.CameraOffset == SHIFTLOCK_2023_OFFSET then
            pcall(function() hum.CameraOffset = Vector3.zero end)
        end
    end
end)
UI.toggle(scroll, 14, "fog panel", false, function(v)
    fogIconGui.Enabled = v
    if not v then fogGui.Enabled = false end
end)
UI.toggle(scroll, 14.2, "antifling", false, function(v)
    setAntifling(v)
end)
UI.toggle(scroll, 15, "old chat", oldBubbleChatActive, function(v)
    oldBubbleChatActive = v
    if v then initOldChat() else destroyOldChat() end
end)
UI.toggle(scroll, 15.1, "microphone", micActive, function(v)
    micActive = v
    if v then initMic() else destroyMic() end
end)
UI.toggle(scroll, 16, "sound equip gun", autoEquipActive, function(v) autoEquipActive = v end)
-- Old Notification Kill (PC mode): changes the MM2 kill feed text (PC & mobile)
local oldKillActive = false
local oldKillHooked = false
do
    local replacements = {
        ["Melee Kill!"] = "Melee Kill! + 250",
        ["Throwing Kill!"] = "Throwing Kill! +100",
    }
    local textConns = setmetatable({}, { __mode = "k" }) -- label -> Text listener
    local watchConns = {}                                  -- container listeners

    local function isTextObj(o) return o:IsA("TextLabel") or o:IsA("TextButton") end

    local function handle(obj)
        if not isTextObj(obj) or textConns[obj] then return end
        local n = replacements[obj.Text]
        if n then obj.Text = n end
        textConns[obj] = obj:GetPropertyChangedSignal("Text"):Connect(function()
            if not oldKillActive then return end
            local r = replacements[obj.Text]
            if r then obj.Text = r end
        end)
    end

    local function containers()
        local list = { player:FindFirstChild("PlayerGui"), Workspace }
        pcall(function() table.insert(list, game:GetService("CoreGui")) end)
        if type(gethui) == "function" then
            pcall(function() table.insert(list, gethui()) end)
        end
        return list
    end

    -- Method 1: hook (PC / strong executors, no delay)
    local function installHook()
        if oldKillHooked then return end
        if type(hookmetamethod) ~= "function" then return end
        oldKillHooked = true
        pcall(function()
            local old
            old = hookmetamethod(game, "__newindex", (newcclosure or function(f) return f end)(
                function(self, key, value)
                    if oldKillActive and key == "Text" and typeof(value) == "string"
                       and typeof(self) == "Instance"
                       and (self:IsA("TextLabel") or self:IsA("TextButton")) then
                        value = replacements[value] or value
                    end
                    return old(self, key, value)
                end))
        end)
    end

    -- Method 2: event-driven watcher (mobile / weak executors).
    -- Replaces the old 0.1s GetDescendants loop, which lagged the game.
    local function startWatch()
        for _, c in ipairs(containers()) do
            table.insert(watchConns, c.DescendantAdded:Connect(function(o)
                if oldKillActive then handle(o) end
            end))
            task.spawn(function()
                local ok, list = pcall(function() return c:GetDescendants() end)
                if not ok then return end
                for i, o in ipairs(list) do
                    if not oldKillActive then return end
                    handle(o)
                    if i % 400 == 0 then task.wait() end
                end
            end)
        end
    end

    local function stopWatch()
        for _, c in ipairs(watchConns) do pcall(function() c:Disconnect() end) end
        for i = #watchConns, 1, -1 do watchConns[i] = nil end
        for o, c in pairs(textConns) do
            pcall(function() c:Disconnect() end)
            textConns[o] = nil
        end
    end

    local row = UI.toggle(scroll, 17, "old Notification Kill (PC mode)", false, function(v)
        oldKillActive = v
        if v then
            installHook()
            startWatch()
        else
            stopWatch()
        end
    end)
    local lbl = row:FindFirstChildOfClass("TextLabel")
    if lbl then
        lbl.TextScaled = true
        local c = Instance.new("UITextSizeConstraint", lbl)
        c.MaxTextSize = 16; c.MinTextSize = 8
    end
end

UI.toggle(scroll, 16.1, "mute sheriff kill", false, function(v)
    muteSheriffActive = v
    if v then muteSheriffEnable() else muteSheriffDisable() end
end)

-- =====================================================================
-- CROSSHAIR
-- =====================================================================
do
    local IDS = {
        -- new crosshairs
        135664831329896,
        84061079851935,
        117904815213842,
        -- MouseLockedCursor (Image ids)
        106992068239006, -- green
        111484643328877, -- red
        106528735245531, -- white
        108310581939634, -- magenta
        107297431814947, -- pink
        130093398539862, -- purple
        73309572327512,  -- blue
        111655608294842, -- red 2
        72430341332878,  -- teal
        114300729287839, -- dark
    }
    local X = { built = false, size = 40, enabled = false, cur = IDS[1] }
    local gui, holder, panel, thumbs, setOn, render, cache = nil, nil, nil, {}, nil, nil, {}

    local function mount(g)
        local ok = pcall(function() g.Parent = (gethui and gethui()) or pg end)
        if not ok or not g.Parent then g.Parent = pg end
    end

    local function loadImage(label, id)
        if cache[id] then label.Image = cache[id]; return end
        local cands = {
            "rbxassetid://" .. id,
            "http://www.roblox.com/asset/?id=" .. id,
            "rbxthumb://type=Asset&id=" .. id .. "&w=420&h=420",
        }
        if type(game.GetObjects) == "function" then
            pcall(function()
                local o = game:GetObjects("rbxassetid://" .. id)[1]
                if o and (o:IsA("Decal") or o:IsA("Texture")) and o.Texture ~= "" then
                    table.insert(cands, 1, o.Texture)
                end
            end)
        end
        local CP = game:GetService("ContentProvider")
        for _, c in ipairs(cands) do
            label.Image = c
            local ok = false
            pcall(function()
                CP:PreloadAsync({ label }, function(_, st)
                    if st == Enum.AssetFetchStatus.Success then ok = true end
                end)
            end)
            if ok or label.IsLoaded then cache[id] = c; return end
        end
        label.Image = cands[1]
    end

    local function shiftlockOn()
        -- only true mouse-lock / shiftlock (not camera offset alone)
        return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
    end

    local function isOurs(v)
        local sg = v:FindFirstAncestorOfClass("ScreenGui")
        if not sg then return false end
        local n = sg.Name
        return n:sub(1, 4) == "CNP_" or n == "Fog_Panel" or n == "Fog_Icon"
            or n == "C4_Modern_Menu" or n == "ListUserPanel"
            or n == "Old2023ChatGui" or n == "SLPanel" or n == "SLIcon"
    end

    local hidden = {}
    local function hideObj(v)
        if hidden[v] then return end
        local rec = {}
        pcall(function()
            if v:IsA("ImageLabel") or v:IsA("ImageButton") then
                rec.ImageTransparency = v.ImageTransparency
                v.ImageTransparency = 1
            end
            if v:IsA("GuiObject") then
                rec.Visible = v.Visible
                v.Visible = false
            end
        end)
        hidden[v] = rec
    end
    local function restoreNative()
        for v, rec in pairs(hidden) do
            pcall(function()
                if rec.ImageTransparency ~= nil then v.ImageTransparency = rec.ImageTransparency end
                if rec.Visible ~= nil then v.Visible = rec.Visible end
            end)
        end
        hidden = {}
    end

    local SHIFT_NAME_HINTS = {
        mouselock=true, shiftlock=true, mouse_lock=true, shift_lock=true,
        crosshair=true, reticle=true, retical=true, mouseicon=true,
    }
    local function nameLooksNative(n)
        n = string.lower(n or "")
        for k in pairs(SHIFT_NAME_HINTS) do
            if n:find(k, 1, true) then return true end
        end
        return false
    end

    -- Lightweight: only scan likely containers, not every descendant every frame
    local function sweepNative()
        local roots = { pg }
        pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
        for _, root in ipairs(roots) do
            for _, sg in ipairs(root:GetChildren()) do
                if sg:IsA("ScreenGui") and not isOurs(sg) then
                    local sn = string.lower(sg.Name)
                    local scanDeep = nameLooksNative(sn)
                        or sn:find("player", 1, true)
                        or sn:find("control", 1, true)
                        or sn:find("camera", 1, true)
                    if scanDeep then
                        for _, v in ipairs(sg:GetDescendants()) do
                            if (v:IsA("ImageLabel") or v:IsA("ImageButton")) and not isOurs(v) then
                                if nameLooksNative(v.Name) then
                                    hideObj(v)
                                end
                            end
                        end
                    else
                        -- shallow only
                        for _, v in ipairs(sg:GetChildren()) do
                            if (v:IsA("ImageLabel") or v:IsA("ImageButton")) and nameLooksNative(v.Name) then
                                hideObj(v)
                            end
                        end
                    end
                end
            end
        end
    end
    X.sweep = function()
        sweepNative()
        task.delay(0.5, sweepNative)
    end

    local function build()
        local xgui = Instance.new("ScreenGui")
        xgui.Name = "CNP_Crosshair"; xgui.ResetOnSpawn = false
        xgui.IgnoreGuiInset = true; xgui.DisplayOrder = 998
        mount(xgui)
        holder = Instance.new("Frame", xgui)
        holder.BackgroundTransparency = 1
        holder.AnchorPoint = Vector2.new(.5, .5)
        holder.Position = UDim2.fromScale(.5, .5)
        holder.Size = UDim2.fromOffset(50, 50)
        holder.Active = false; holder.Visible = false
        pcall(function() holder.Interactable = false end)
        local hscale = Instance.new("UIScale", holder)
        local token = 0

        render = function()
            token = token + 1
            local my = token
            for _, c in ipairs(holder:GetChildren()) do
                if c:IsA("ImageLabel") then c:Destroy() end
            end
            -- off / no id → hide crosshair, restore default icons
            if not (X.enabled and X.cur) then
                holder.Visible = false
                restoreNative()
                return
            end
            -- crosshair only while shiftlock is ON
            local locked = shiftlockOn()
            holder.Visible = locked
            if locked then
                X.sweep() -- hide default shiftlock / reticle
            else
                restoreNative()
            end
            hscale.Scale = X.size / 50
            local i = Instance.new("ImageLabel", holder)
            i.Size = UDim2.fromScale(1, 1); i.BackgroundTransparency = 1; i.Active = false
            task.spawn(function() if my == token then loadImage(i, X.cur) end end)
        end

        -- Throttled Heartbeat (was RenderStepped every frame → lag)
        local lastSweep, acc = 0, 0
        local lastWant = false
        RunService.Heartbeat:Connect(function(dt)
            acc = acc + dt
            if acc < 0.08 then return end -- ~12.5 checks / sec
            acc = 0
            local locked = shiftlockOn()
            -- show custom crosshair only when enabled + shiftlocked
            local want = X.enabled and X.cur ~= nil and locked
            if want ~= lastWant then
                lastWant = want
                holder.Visible = want
                if want then
                    -- bật crosshair → mất shiftlock default
                    X.sweep()
                    lastSweep = os.clock()
                else
                    -- tắt shiftlock (hoặc tắt crosshair) → hide crosshair + trả icon gốc
                    restoreNative()
                end
            elseif want then
                local now = os.clock()
                if now - lastSweep > 1.8 then
                    lastSweep = now
                    X.sweep()
                end
            elseif X.enabled and not locked then
                -- shiftlock off: keep crosshair hidden
                if holder.Visible then holder.Visible = false end
            end
        end)

        gui = Instance.new("ScreenGui")
        gui.Name = "CNP_CrosshairPanel"; gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 2147483646
        gui.Enabled = true
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not gui.Parent then gui.Parent = pg end
        X.built = true
        panel = Instance.new("Frame", gui)
        panel.Size = UDim2.new(0, isMobile and 214 or 232,
            0, fitH(isMobile and 400 or 480))
        panel.Position = UDim2.new(0.5, -panel.Size.X.Offset / 2,
            0.5, -panel.Size.Y.Offset / 2)
        panel.BackgroundColor3 = UI.bg; panel.BackgroundTransparency = 0.05
        panel.BorderSizePixel = 0; panel.ClipsDescendants = true
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
        local pst = Instance.new("UIStroke", panel)
        pst.Color = Color3.fromRGB(80, 80, 95)
        pst.Transparency = 0.2; pst.Thickness = 1

        local top = Instance.new("TextLabel", panel)
        top.Size = UDim2.new(1, -36, 0, 32); top.BackgroundTransparency = 1
        top.Text = "crosshair"; top.TextColor3 = UI.text
        top.Font = UI.titleFont; top.TextSize = 15
        top.TextXAlignment = Enum.TextXAlignment.Left; top.Active = true
        Instance.new("UIPadding", top).PaddingLeft = UDim.new(0, 12)

        local closeB = Instance.new("TextButton", panel)
        closeB.Size = UDim2.fromOffset(26, 26)
        closeB.Position = UDim2.new(1, -30, 0, 3)
        closeB.BackgroundTransparency = 1
        closeB.TextColor3 = UI.dim; closeB.Font = UI.font; closeB.TextSize = 16
        closeB.Text = "x"; closeB.BorderSizePixel = 0
        closeB.Activated:Connect(function() gui.Enabled = false end)

        local tl = Instance.new("Frame", panel)
        tl.Size = UDim2.new(1, -24, 0, 1)
        tl.Position = UDim2.new(0, 12, 0, 32)
        tl.BackgroundColor3 = UI.line
        tl.BackgroundTransparency = 0.5; tl.BorderSizePixel = 0

        makeDraggable(panel, top)

        local ps = Instance.new("ScrollingFrame", panel)
        ps.Size = UDim2.new(1, -12, 1, -42); ps.Position = UDim2.new(0, 6, 0, 37)
        ps.BackgroundTransparency = 1; ps.BorderSizePixel = 0
        ps.ScrollBarThickness = 2; ps.ScrollBarImageColor3 = UI.line
        ps.AutomaticCanvasSize = Enum.AutomaticSize.Y
        ps.CanvasSize = UDim2.new()
        ps.ScrollingDirection = Enum.ScrollingDirection.Y
        local lay = Instance.new("UIListLayout", ps)
        lay.Padding = UDim.new(0, 5); lay.SortOrder = Enum.SortOrder.LayoutOrder

        local function paintSel()
            for id, t in pairs(thumbs) do
                local on = X.enabled and id == X.cur
                t.Color = on and UI.accent or UI.line
                t.Thickness = on and 2 or 1
            end
        end

        local gridBox = Instance.new("Frame", ps)
        gridBox.Size = UDim2.new(1, 0, 0, 0)
        gridBox.AutomaticSize = Enum.AutomaticSize.Y
        gridBox.LayoutOrder = 1; gridBox.BackgroundTransparency = 1
        local gl = Instance.new("UIGridLayout", gridBox)
        local cell = isMobile and 62 or 68
        gl.CellSize = UDim2.fromOffset(cell, cell)
        gl.CellPadding = UDim2.fromOffset(5, 5)
        gl.SortOrder = Enum.SortOrder.LayoutOrder

        for n, id in ipairs(IDS) do
            local b = Instance.new("ImageButton", gridBox)
            b.LayoutOrder = n; b.BackgroundColor3 = UI.row
            b.BackgroundTransparency = 0.1; b.BorderSizePixel = 0
            b.AutoButtonColor = false; b.ScaleType = Enum.ScaleType.Fit
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            local st = Instance.new("UIStroke", b)
            st.Thickness = 1; st.Color = UI.line
            thumbs[id] = st
            b.Activated:Connect(function()
                X.cur = id; X.enabled = true
                setOn(true); paintSel(); render()
            end)
            task.spawn(function() loadImage(b, id) end)
        end

        do
            local b, lbl = UI.rowBase(ps, 2, "show crosshair")
            local track = Instance.new("Frame", b)
            track.Size = UDim2.fromOffset(36, 18)
            track.AnchorPoint = Vector2.new(1, 0.5)
            track.Position = UDim2.new(1, -12, 0.5, 0)
            track.BorderSizePixel = 0
            Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
            local knob = Instance.new("Frame", track)
            knob.Size = UDim2.fromOffset(14, 14)
            knob.AnchorPoint = Vector2.new(0, 0.5)
            knob.BorderSizePixel = 0
            knob.BackgroundColor3 = Color3.fromRGB(255, 250, 255)
            Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
            setOn = function(v)
                X.enabled = v and true or false
                track.BackgroundColor3 = X.enabled and UI.accent or UI.off
                knob.Position = X.enabled
                    and UDim2.new(1, -16, 0.5, 0)
                    or UDim2.new(0, 2, 0.5, 0)
                lbl.TextColor3 = X.enabled and UI.text or Color3.fromRGB(150, 130, 145)
            end
            setOn(X.enabled)
            b.Activated:Connect(function()
                setOn(not X.enabled); paintSel(); render()
            end)
        end

        UI.slider(ps, 3, "size", 8, 150, X.size, function(v)
            X.size = v; render()
        end)

        local box = Instance.new("TextBox", ps)
        box.Size = UDim2.new(1, 0, 0, 30); box.LayoutOrder = 5
        box.BackgroundColor3 = UI.row; box.BackgroundTransparency = 0.05
        box.PlaceholderText = "enter image id..."
        box.PlaceholderColor3 = UI.dim
        box.Text = ""; box.ClearTextOnFocus = false
        box.TextColor3 = UI.text; box.Font = UI.font; box.TextSize = 12
        box.TextXAlignment = Enum.TextXAlignment.Left; box.BorderSizePixel = 0
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, UI.corner)
        Instance.new("UIPadding", box).PaddingLeft = UDim.new(0, 10)

        UI.action(ps, 6, "use this id", function()
            local id = tonumber((string.gsub(box.Text, "%D", "")))
            if id then
                X.cur = id; X.enabled = true
                setOn(true); paintSel(); render()
            end
        end)
        paintSel()

        local igui = Instance.new("ScreenGui")
        igui.Name = "CNP_CrosshairIcon"; igui.ResetOnSpawn = false
        igui.DisplayOrder = 2147483646
        mount(igui)
        local icon = Instance.new("TextButton", igui)
        icon.Size = UDim2.fromOffset(64, 40)
        icon.Position = UDim2.new(0.03, 0, 0.4, 0)
        icon.BackgroundColor3 = UI.bg; icon.BackgroundTransparency = 0.05
        icon.Text = "Shiftlock"; icon.TextColor3 = UI.text
        icon.Font = Enum.Font.BuilderSansBold; icon.TextSize = 11
        icon.AutoButtonColor = false; icon.Active = true
        Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 10)
        local ist = Instance.new("UIStroke", icon)
        ist.Color = UI.accent; ist.Thickness = 1.5

        local iDrag, iStart, iPos, iMoved, iLast = false, nil, nil, false, 0
        icon.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
               or i.UserInputType == Enum.UserInputType.Touch then
                iDrag = true; iMoved = false
                iStart = i.Position; iPos = icon.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if iDrag and (i.UserInputType == Enum.UserInputType.MouseMovement
               or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - iStart
                if d.Magnitude > 30 then iMoved = true end
                if iMoved then
                    icon.Position = UDim2.new(iPos.X.Scale, iPos.X.Offset + d.X,
                        iPos.Y.Scale, iPos.Y.Offset + d.Y)
                end
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if iDrag and (i.UserInputType == Enum.UserInputType.MouseButton1
               or i.UserInputType == Enum.UserInputType.Touch) then
                iDrag = false
            end
        end)
        icon.Activated:Connect(function()
            if iMoved or os.clock() - iLast < 0.25 then return end
            iLast = os.clock()
            gui.Enabled = not gui.Enabled
        end)
    end

    UI.action(scroll, 5, "crosshair", function()
        if not X.built then
            local ok, err = pcall(build)
            if not ok then warn("[CNP] crosshair build:", err) end
        end
        if gui then
            gui.Enabled = not gui.Enabled
            if gui.Enabled then
                gui.DisplayOrder = 2147483646
            end
        end
    end)
end



-- =====================================================================
-- SKYBOX (My Melody / Kuromi / Cinna) — sky only, no fog/brightness
-- =====================================================================
do
    local Lighting = game:GetService("Lighting")
    local SKY = {
        MyMelody = {
            Label = "My Melody",
            Bk = 112580788417374, Dn = 76445244290218, Ft = 99465758248467,
            Lf = 81358503463424, Rt = 124512710594732, Up = 99554554083078,
            Sun = 6196665106, Moon = 6444320592,
        },
        Kuromi = {
            Label = "Kuromi",
            Bk = 128347863539302, Dn = 78026197335557, Ft = 92502384929990,
            Lf = 76855314947494, Rt = 76773972098704, Up = 97649794413711,
            Sun = 6196665106, Moon = 6444320592,
        },
        Cinna = {
            Label = "Cinna",
            Bk = 95800443485595, Dn = 82068944590628, Ft = 116297505482359,
            Lf = 93826495998051, Rt = 93237266373246, Up = 90601359299354,
            Sun = 6196665106, Moon = 6444320592,
        },
    }
    local activePreset = nil
    local skyGui, skyFrame = nil, nil

    local function setProp(obj, prop, val)
        pcall(function() obj[prop] = val end)
    end

    local function getSky()
        for _, c in ipairs(Lighting:GetChildren()) do
            if c:IsA("Sky") and c.Name ~= "CNP_Sky" then
                pcall(function() c:Destroy() end)
            end
        end
        local sky = Lighting:FindFirstChild("CNP_Sky")
        if not sky then
            sky = Instance.new("Sky")
            sky.Name = "CNP_Sky"
            sky.Parent = Lighting
        end
        return sky
    end

    local function applySky(preset)
        if not preset then return end
        local sky = getSky()
        -- ONLY Sky instance textures — never Atmosphere / Fog / Ambient
        setProp(sky, "CelestialBodiesShown", true)
        setProp(sky, "SunAngularSize", 11)
        setProp(sky, "MoonAngularSize", 11)
        setProp(sky, "StarCount", 3000)
        local faces = {
            SkyboxBk = preset.Bk, SkyboxDn = preset.Dn, SkyboxFt = preset.Ft,
            SkyboxLf = preset.Lf, SkyboxRt = preset.Rt, SkyboxUp = preset.Up,
            SunTextureId = preset.Sun, MoonTextureId = preset.Moon,
        }
        for prop, id in pairs(faces) do
            if id and id ~= 0 then
                setProp(sky, prop, "rbxassetid://" .. tostring(id))
            end
        end
        -- explicitly do not modify Lighting.Fog* or Atmosphere
    end

    local function openSkyPanel()
        if skyGui and skyGui.Parent then
            skyGui.Enabled = not skyGui.Enabled
            return
        end
        skyGui = Instance.new("ScreenGui")
        skyGui.Name = "CNP_SkyPanel"
        skyGui.ResetOnSpawn = false
        skyGui.DisplayOrder = 2147483645
        skyGui.Parent = pg

        skyFrame = Instance.new("Frame")
        skyFrame.Size = UDim2.fromOffset(isMobile and 260 or 300, 260)
        skyFrame.Position = UDim2.new(0.5, -115, 0.25, 0)
        skyFrame.BackgroundColor3 = UI.bg
        skyFrame.BorderSizePixel = 0
        skyFrame.Active = true
        skyFrame.Parent = skyGui
        Instance.new("UICorner", skyFrame).CornerRadius = UDim.new(0, UI.corner)
        do
            local st = Instance.new("UIStroke", skyFrame)
            st.Color = UI.line
            st.Transparency = 0.3
            st.Thickness = 1.2
        end
        do
            local g = Instance.new("UIGradient", skyFrame)
            g.Rotation = 160
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 253, 255)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(232, 244, 252)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 226, 244)),
            })
        end

        local top = Instance.new("TextLabel", skyFrame)
        top.Size = UDim2.new(1, -36, 0, 30)
        top.Position = UDim2.fromOffset(10, 4)
        top.BackgroundTransparency = 1
        top.Font = UI.titleFont
        top.TextSize = 14
        top.TextColor3 = UI.text
        top.TextXAlignment = Enum.TextXAlignment.Left
        top.Text = "skybox"
        top.Active = true

        local close = Instance.new("TextButton", skyFrame)
        close.Size = UDim2.fromOffset(24, 24)
        close.Position = UDim2.new(1, -28, 0, 6)
        close.BackgroundTransparency = 1
        close.Text = "x"
        close.TextColor3 = UI.dim
        close.Font = UI.font
        close.TextSize = 16
        close.Activated:Connect(function()
            skyGui.Enabled = false
        end)

        local status = Instance.new("TextLabel", skyFrame)
        status.Size = UDim2.new(1, -20, 0, 16)
        status.Position = UDim2.fromOffset(10, 32)
        status.BackgroundTransparency = 1
        status.Font = UI.font
        status.TextSize = 11
        status.TextColor3 = UI.dim
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Text = "pick a sky"

        local function mkBtn(text, y, key, col)
            local b = Instance.new("TextButton", skyFrame)
            b.Size = UDim2.new(1, -20, 0, 34)
            b.Position = UDim2.fromOffset(10, y)
            b.BackgroundColor3 = col
            b.BackgroundTransparency = 0.15
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Text = text
            b.TextColor3 = Color3.fromRGB(255, 255, 255)
            b.Font = UI.font
            b.TextSize = 13
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
            local st = Instance.new("UIStroke", b)
            st.Color = UI.line
            st.Transparency = 0.35
            st.Thickness = 1
            b.Activated:Connect(function()
                activePreset = SKY[key]
                applySky(activePreset)
                status.Text = "on · " .. SKY[key].Label
            end)
        end
        mkBtn("My Melody", 54, "MyMelody", Color3.fromRGB(90, 160, 210))
        mkBtn("Kuromi", 94, "Kuromi", Color3.fromRGB(70, 120, 180))
        mkBtn("Cinna", 134, "Cinna", Color3.fromRGB(100, 175, 220))

        makeDraggable(skyFrame, top)

        -- reapply lightly so map scripts don't wipe sky
        task.spawn(function()
            while skyGui and skyGui.Parent do
                task.wait(2.5)
                if activePreset then
                    applySky(activePreset)
                end
            end
        end)
    end

    UI.action(scroll, 14.5, "skybox", function()
        openSkyPanel()
    end)
end

-- =====================================================================
-- C4 MENU
-- =====================================================================
do
    local function BuildC4()
        local Main = Instance.new("Part")
        Main.Name = "Handle"
        Main.Size = Vector3.new(1.8, 0.7, 1.2)
        Main.Color = Config.BombColor
        Main.Material = Enum.Material.Metal
        Main.CanCollide = true
        return Main
    end

    local function GiveTool()
        local Tool = Instance.new("Tool")
        Tool.Name = Config.ToolName
        Tool.RequiresHandle = true
        Tool.CanBeDropped = false
        Tool.Grip = CFrame.new(0, -0.2, 0.2) * CFrame.Angles(0, math.rad(180), 0)
        local C4Part = BuildC4()
        C4Part.Parent = Tool
        table.insert(ActiveTools, Tool)

        Tool.Activated:Connect(function()
            if not Config.CanUse then return end
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            Config.CanUse = false
            if CurrentDroppedBomb then CurrentDroppedBomb:Destroy() end

            -- Simple drop under feet + throw toward mouse
            local d_handle = BuildC4()
            d_handle.CFrame = hrp.CFrame * CFrame.new(0, -3.2, 0)
            d_handle.Parent = Workspace
            CurrentDroppedBomb = d_handle

            local dir = (mouse.Hit.p - hrp.Position)
            if dir.Magnitude > 0.1 then
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Velocity = dir.Unit * 25 + Vector3.new(0, 10, 0)
                bv.Parent = d_handle
                game:GetService("Debris"):AddItem(bv, 0.1)
            end

            -- Hide hand part during cooldown
            local parts = {}
            for _, p in pairs(Tool:GetChildren()) do
                if p:IsA("BasePart") then
                    parts[p] = p.Transparency
                    p.Transparency = 1
                end
            end

            task.wait(Config.Cooldown)

            if CurrentDroppedBomb then
                CurrentDroppedBomb:Destroy()
                CurrentDroppedBomb = nil
            end
            for p, trans in pairs(parts) do
                if p then p.Transparency = trans end
            end
            Config.CanUse = true
        end)
        Tool.Parent = player:WaitForChild("Backpack")
    end

    local function clearAllBombs()
        for _, tool in ipairs(ActiveTools) do
            if tool and tool.Parent then pcall(function() tool:Destroy() end) end
        end
        for i = #ActiveTools, 1, -1 do ActiveTools[i] = nil end
        local function clean(c)
            if not c then return end
            for _, o in ipairs(c:GetChildren()) do
                if o:IsA("Tool") and o.Name == Config.ToolName then
                    pcall(function() o:Destroy() end)
                end
            end
        end
        clean(player:FindFirstChild("Backpack"))
        clean(player.Character)
        if CurrentDroppedBomb then
            pcall(function() CurrentDroppedBomb:Destroy() end)
            CurrentDroppedBomb = nil
        end
        Config.CanUse = true
    end

    local function refreshAllBombs()
        for _, tool in ipairs(ActiveTools) do
            if tool and tool.Parent then
                local h = tool:FindFirstChild("Handle")
                if h and h:IsA("BasePart") then
                    h.Color = Config.BombColor
                end
            end
        end
        if CurrentDroppedBomb and CurrentDroppedBomb:IsA("BasePart") then
            CurrentDroppedBomb.Color = Config.BombColor
        end
    end

    local c4Gui = Instance.new("ScreenGui")
    c4Gui.Name = "C4_Modern_Menu"; c4Gui.ResetOnSpawn = false
    c4Gui.DisplayOrder = 2147483646; c4Gui.Parent = pg; c4Gui.Enabled = false

    local c4Frame = Instance.new("Frame", c4Gui)
    do
        local ch = fitH(isMobile and 380 or 460)
        local cw = isMobile and 260 or 300
        c4Frame.Size = UDim2.new(0, cw, 0, ch)
        c4Frame.Position = isMobile
            and UDim2.new(0.5, -cw/2 + 40, 0.5, -ch / 2)
            or UDim2.new(0.5, -cw/2 + 50, 0.5, -ch / 2)
    end
    c4Frame.BackgroundColor3 = UI.bg; c4Frame.BorderSizePixel = 0
    c4Frame.ClipsDescendants = true
    applyGlass(c4Frame, 0.2)
    Instance.new("UICorner", c4Frame).CornerRadius = UDim.new(0, 4)
    do
        local st = Instance.new("UIStroke", c4Frame)
        st.Color = UI.line; st.Thickness = 1
    end

    local c4Top = Instance.new("Frame", c4Frame)
    c4Top.Size = UDim2.new(1, 0, 0, 30)
    c4Top.BackgroundTransparency = 1; c4Top.Active = true

    local c4Title = Instance.new("TextLabel", c4Top)
    c4Title.Size = UDim2.new(1, -36, 1, 0); c4Title.BackgroundTransparency = 1
    c4Title.Text = "c4"; c4Title.TextColor3 = UI.text
    c4Title.Font = UI.font; c4Title.TextSize = 14
    c4Title.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UIPadding", c4Title).PaddingLeft = UDim.new(0, 12)

    local c4Close = Instance.new("TextButton", c4Top)
    c4Close.Size = UDim2.fromOffset(26, 26)
    c4Close.Position = UDim2.new(1, -30, 0, 2)
    c4Close.BackgroundTransparency = 1
    c4Close.Text = "x"; c4Close.TextColor3 = UI.dim
    c4Close.Font = UI.font; c4Close.TextSize = 14; c4Close.BorderSizePixel = 0
    c4Close.Activated:Connect(function() c4Gui.Enabled = false end)

    local c4Line = Instance.new("Frame", c4Frame)
    c4Line.Size = UDim2.new(1, 0, 0, 1)
    c4Line.Position = UDim2.new(0, 0, 0, 30)
    c4Line.BackgroundColor3 = UI.line; c4Line.BorderSizePixel = 0

    local c4Scroll = Instance.new("ScrollingFrame", c4Frame)
    c4Scroll.Size = UDim2.new(1, -12, 1, -38)
    c4Scroll.Position = UDim2.new(0, 6, 0, 34)
    c4Scroll.BackgroundTransparency = 1; c4Scroll.BorderSizePixel = 0
    c4Scroll.ScrollBarThickness = 2; c4Scroll.ScrollBarImageColor3 = UI.line
    c4Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    c4Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    do
        local lay = Instance.new("UIListLayout", c4Scroll)
        lay.Padding = UDim.new(0, 5); lay.SortOrder = Enum.SortOrder.LayoutOrder
    end

    local function createC4Input(order, labelText, defaultText)
        local f = Instance.new("Frame", c4Scroll)
        f.Size = UDim2.new(1, 0, 0, 44); f.BackgroundTransparency = 1
        f.LayoutOrder = order
        local lbl = Instance.new("TextLabel", f)
        lbl.Size = UDim2.new(1, 0, 0, 14); lbl.BackgroundTransparency = 1
        lbl.Text = labelText; lbl.TextColor3 = UI.dim
        lbl.Font = UI.font; lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        local box = Instance.new("TextBox", f)
        box.Size = UDim2.new(1, 0, 0, 26); box.Position = UDim2.new(0, 0, 0, 16)
        box.Text = defaultText; box.BackgroundColor3 = UI.row
        box.TextColor3 = UI.text; box.Font = UI.font; box.TextSize = 12
        box.BorderSizePixel = 0; box.ClearTextOnFocus = false
        box.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UIPadding", box).PaddingLeft = UDim.new(0, 8)
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)
        return box
    end

    local function createC4Button(order, text, bg, fg)
        local b = Instance.new("TextButton", c4Scroll)
        b.Size = UDim2.new(1, 0, 0, 28); b.LayoutOrder = order
        b.BackgroundColor3 = bg; b.Text = text; b.TextColor3 = fg
        b.Font = UI.font; b.TextSize = 12; b.BorderSizePixel = 0
        b.AutoButtonColor = true
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
        return b
    end

    local inputCD = createC4Input(1, "cooldown (sec)", tostring(Config.Cooldown))
    local inputAmount = createC4Input(2, "bomb amount", tostring(Config.BombAmount))
    local inputName = createC4Input(3, "tool name", Config.ToolName)

    local colorBtnC4 = createC4Button(4, "bomb color", UI.row, UI.text)
    colorBtnC4.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UIPadding", colorBtnC4).PaddingLeft = UDim.new(0, 10)
    local swatch = Instance.new("Frame", colorBtnC4)
    swatch.Size = UDim2.fromOffset(14, 14)
    swatch.AnchorPoint = Vector2.new(1, 0.5)
    swatch.Position = UDim2.new(1, -10, 0.5, 0)
    swatch.BackgroundColor3 = Config.BombColor; swatch.BorderSizePixel = 0
    Instance.new("UICorner", swatch).CornerRadius = UDim.new(1, 0)

    local c4ColorFrame = Instance.new("Frame", c4Scroll)
    c4ColorFrame.Size = UDim2.new(1, 0, 0, 122); c4ColorFrame.LayoutOrder = 5
    c4ColorFrame.BackgroundColor3 = UI.row; c4ColorFrame.BorderSizePixel = 0
    c4ColorFrame.Visible = false
    Instance.new("UICorner", c4ColorFrame).CornerRadius = UDim.new(0, 3)
    do
        local g = Instance.new("UIGridLayout", c4ColorFrame)
        g.CellSize = UDim2.fromOffset(30, 30)
        g.CellPadding = UDim2.fromOffset(6, 6)
        g.HorizontalAlignment = Enum.HorizontalAlignment.Center
        g.VerticalAlignment = Enum.VerticalAlignment.Center
    end

    local saveBtnC4 = createC4Button(7, "save & create bomb",
        UI.accent, Color3.fromRGB(20, 20, 22))
    local clearBtnC4 = createC4Button(8, "clear bombs",
        UI.row, Color3.fromRGB(235, 120, 120))
    clearBtnC4.Activated:Connect(function()
        clearAllBombs()
        clearBtnC4.Text = "cleared"
        task.delay(1, function() clearBtnC4.Text = "clear bombs" end)
    end)

    local c4Colors = {
        Color3.fromRGB(235, 30, 30), Color3.fromRGB(250, 100, 20),
        Color3.fromRGB(255, 170, 0), Color3.fromRGB(255, 230, 0),
        Color3.fromRGB(170, 220, 20), Color3.fromRGB(70, 200, 70),
        Color3.fromRGB(0, 180, 160), Color3.fromRGB(0, 150, 255),
        Color3.fromRGB(70, 80, 220), Color3.fromRGB(130, 60, 200),
        Color3.fromRGB(220, 50, 180), Color3.fromRGB(240, 50, 100),
        Color3.fromRGB(0, 0, 0),
    }
    for _, c in ipairs(c4Colors) do
        local b = Instance.new("TextButton", c4ColorFrame)
        b.BackgroundColor3 = c; b.Text = ""; b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        b.Activated:Connect(function()
            Config.BombColor = c
            swatch.BackgroundColor3 = c
            c4ColorFrame.Visible = false
            refreshAllBombs()
        end)
    end
    colorBtnC4.Activated:Connect(function()
        c4ColorFrame.Visible = not c4ColorFrame.Visible
    end)

    saveBtnC4.Activated:Connect(function()
        Config.Cooldown = tonumber(inputCD.Text) or 2
        Config.BombAmount = tonumber(inputAmount.Text) or 1
        local nm = inputName.Text
        if not nm or nm == "" then nm = "Gold C4 Bomb" end
        Config.ToolName = nm
        c4Gui.Enabled = false
        clearAllBombs()
        task.wait(0.1)
        for _ = 1, Config.BombAmount do GiveTool() end
    end)

    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        clearAllBombs()
    end)

    makeDraggable(c4Frame, c4Top)

    UI.action(scroll, 7, "c4 menu", function()
        c4Gui.Enabled = not c4Gui.Enabled
    end)
end

-- =====================================================================
-- FLY
-- =====================================================================
do
local flying, flySpeed = false, 80
local flyBV, flyBG, flyAtt, flyConn = nil, nil, nil, nil
local flyUp, flyDown = false, false

local flyGui = Instance.new("ScreenGui")
flyGui.Name = "CNP_Fly"; flyGui.ResetOnSpawn = false
flyGui.DisplayOrder = 2147483646; flyGui.Enabled = false; flyGui.Parent = pg

local flyFrame = Instance.new("Frame", flyGui)
do
    local fw = isMobile and 260 or 300
    local fh = 250
    flyFrame.Size = UDim2.fromOffset(fw, fh)
    flyFrame.Position = UDim2.new(0.5, -fw / 2, 0.12, 0)
end
flyFrame.BackgroundColor3 = UI.bg; flyFrame.BackgroundTransparency = 0.05
flyFrame.BorderSizePixel = 0; flyFrame.Active = true; flyFrame.ClipsDescendants = true
Instance.new("UICorner", flyFrame).CornerRadius = UDim.new(0, 12)
do
    local st = Instance.new("UIStroke", flyFrame)
    st.Color = Color3.fromRGB(80, 80, 95)
    st.Transparency = 0.2; st.Thickness = 1
end

local flyTitle = Instance.new("TextLabel", flyFrame)
flyTitle.Size = UDim2.new(1, -40, 0, 32); flyTitle.BackgroundTransparency = 1
flyTitle.Active = true; flyTitle.Text = "fly"; flyTitle.TextColor3 = UI.text
flyTitle.Font = Enum.Font.BuilderSansBold; flyTitle.TextSize = 15
flyTitle.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UIPadding", flyTitle).PaddingLeft = UDim.new(0, 12)
makeDraggable(flyFrame, flyTitle)

local flyCloseBtn = Instance.new("TextButton", flyFrame)
flyCloseBtn.Size = UDim2.fromOffset(26, 26)
flyCloseBtn.Position = UDim2.new(1, -30, 0, 3)
flyCloseBtn.BackgroundTransparency = 1
flyCloseBtn.Text = "x"; flyCloseBtn.TextColor3 = UI.dim
flyCloseBtn.Font = UI.font; flyCloseBtn.TextSize = 16; flyCloseBtn.BorderSizePixel = 0

local flyLine = Instance.new("Frame", flyFrame)
flyLine.Size = UDim2.new(1, -24, 0, 1)
flyLine.Position = UDim2.new(0, 12, 0, 32)
flyLine.BackgroundColor3 = UI.line
flyLine.BackgroundTransparency = 0.5; flyLine.BorderSizePixel = 0

local flyBody = Instance.new("Frame", flyFrame)
flyBody.Size = UDim2.new(1, -16, 1, -42)
flyBody.Position = UDim2.new(0, 8, 0, 38)
flyBody.BackgroundTransparency = 1
do
    local lay = Instance.new("UIListLayout", flyBody)
    lay.Padding = UDim.new(0, 6); lay.SortOrder = Enum.SortOrder.LayoutOrder
end

local flyToggle = Instance.new("TextButton", flyBody)
flyToggle.Size = UDim2.new(1, 0, 0, 36); flyToggle.LayoutOrder = 1
flyToggle.BackgroundColor3 = UI.row
flyToggle.AutoButtonColor = false; flyToggle.BorderSizePixel = 0
flyToggle.Text = "FLY"; flyToggle.TextColor3 = UI.text
flyToggle.Font = Enum.Font.BuilderSansBold; flyToggle.TextSize = 15
Instance.new("UICorner", flyToggle).CornerRadius = UDim.new(0, UI.corner)
local flyToggleStroke = Instance.new("UIStroke", flyToggle)
flyToggleStroke.Color = UI.line
flyToggleStroke.Transparency = 0.4; flyToggleStroke.Thickness = 1

UI.slider(flyBody, 2, "speed", 10, 300, flySpeed, function(v)
    flySpeed = math.max(10, v)
end)

local flyRow = Instance.new("Frame", flyBody)
flyRow.Size = UDim2.new(1, 0, 0, 34)
flyRow.LayoutOrder = 3; flyRow.BackgroundTransparency = 1

local function flyHoldBtn(text, xs, xo)
    local b = Instance.new("TextButton", flyRow)
    b.Size = UDim2.new(0.5, -3, 1, 0)
    b.Position = UDim2.new(xs, xo, 0, 0)
    b.BackgroundColor3 = UI.row; b.AutoButtonColor = false
    b.BorderSizePixel = 0; b.Text = text; b.TextColor3 = UI.text
    b.Font = UI.font; b.TextSize = 13
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, UI.corner)
    local st = Instance.new("UIStroke", b)
    st.Color = UI.line; st.Transparency = 0.5; st.Thickness = 1
    return b
end
local flyUpBtn = flyHoldBtn("UP", 0, 0)
local flyDownBtn = flyHoldBtn("DOWN", 0.5, 3)

local function holdBtn(btn, setter)
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            setter(true); btn.BackgroundColor3 = UI.hover
        end
    end)
    btn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            setter(false); btn.BackgroundColor3 = UI.row
        end
    end)
end
holdBtn(flyUpBtn, function(v) flyUp = v end)
holdBtn(flyDownBtn, function(v) flyDown = v end)

local flyControls = nil
local function getMoveVector()
    local x = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
        - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
    local z = (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
        - (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
    if x ~= 0 or z ~= 0 then return Vector3.new(x, 0, z) end

    if not flyControls then
        pcall(function()
            local ps = player:FindFirstChild("PlayerScripts")
            if not ps then return end
            local pm = ps:FindFirstChild("PlayerModule")
            if not pm then return end
            local cm = pm:FindFirstChild("ControlModule")
            if cm then flyControls = require(cm) end
        end)
    end
    if flyControls then
        local ok, v = pcall(function() return flyControls:GetMoveVector() end)
        if ok and v and v.Magnitude > 0 then return v end
    end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local cam = Workspace.CurrentCamera
    if hum and cam and hum.MoveDirection.Magnitude > 0.05 then
        local l = cam.CFrame:VectorToObjectSpace(hum.MoveDirection)
        return Vector3.new(l.X, 0, l.Z)
    end
    return Vector3.new(0, 0, 0)
end

local function paintFlyBtn()
    flyToggle.Text = flying and "STOP" or "FLY"
    softTween(flyToggle, { BackgroundColor3 = flying and UI.accent or UI.row }, 0.18)
    flyToggle.TextColor3 = flying and Color3.new(1, 1, 1) or UI.text
end

local function stopFly()
    flying = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then pcall(function() flyBV:Destroy() end); flyBV = nil end
    if flyBG then pcall(function() flyBG:Destroy() end); flyBG = nil end
    if flyAtt then pcall(function() flyAtt:Destroy() end); flyAtt = nil end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        if not speedEnabled then hum.WalkSpeed = BASE_SPEED end
    end
    paintFlyBtn()
end

local function startFly()
    if flying then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    flying = true
    hum.PlatformStand = true
    flyAtt = Instance.new("Attachment")
    flyAtt.Name = "CNP_FlyAtt"
    flyAtt.Parent = root
    flyBV = Instance.new("LinearVelocity")
    flyBV.Name = "CNP_FlyLV"
    flyBV.Attachment0 = flyAtt
    flyBV.MaxForce = 1e5
    flyBV.VectorVelocity = Vector3.zero
    flyBV.RelativeTo = Enum.ActuatorRelativeTo.World
    flyBV.Parent = root
    flyBG = Instance.new("AlignOrientation")
    flyBG.Name = "CNP_FlyAO"
    flyBG.Attachment0 = flyAtt
    flyBG.Mode = Enum.OrientationAlignmentMode.OneAttachment
    flyBG.Responsiveness = 200
    flyBG.MaxTorque = 1e5
    flyBG.Parent = root
    paintFlyBtn()
    local curVel = Vector3.zero
    flyConn = RunService.RenderStepped:Connect(function(dt)
        if not flying or not flyBV or not flyBV.Parent then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local move = getMoveVector()
        local vertical = 0
        if flyUp or UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical = vertical + 1 end
        if flyDown or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vertical = vertical - 1 end
        local dir = cam.CFrame:VectorToWorldSpace(Vector3.new(move.X, 0, move.Z))
            + Vector3.new(0, vertical, 0)
        local want = dir.Magnitude > 0.05 and dir.Unit * flySpeed or Vector3.zero
        curVel = curVel:Lerp(want, 1 - math.exp(-14 * dt))
        flyBV.VectorVelocity = curVel
        if flyBG then
            flyBG.CFrame = CFrame.new(root.Position, root.Position + cam.CFrame.LookVector)
        end
    end)
end

flyToggle.Activated:Connect(function()
    if flying then stopFly() else startFly() end
end)
flyCloseBtn.Activated:Connect(function()
    stopFly(); flyGui.Enabled = false
end)
player.CharacterAdded:Connect(function() stopFly() end)

UI.action(scroll, 2, "fly gui", function()
    flyGui.Enabled = not flyGui.Enabled
    if not flyGui.Enabled then stopFly() end
end)

-- =====================================================================
-- LIST USER
-- =====================================================================
end -- close FLY block

do
local listGui = Instance.new("ScreenGui")
listGui.Name = "ListUserPanel"; listGui.ResetOnSpawn = false
listGui.DisplayOrder = 2147483646; listGui.Parent = pg; listGui.Enabled = false

local NAMES = {
    "riquywz", "fifikamah", "iszaquiho", "totartoor", "caio021213", "jusahxz",
    "erickpontes8087k", "yysnowzxz", "0Axyyhp", "d9rings", "lunapipoka",
    "vyperion_gamer", "xXLok_DBXx", "ydedexzk", "0ysbell", "dgsxtz",
    "MarcosYT224", "miko_yara22", "9dedoslula13", "v1ctorxxzc", "nick23ht",
    "Miguelb2328p", "ilxNyxz", "florwerxz", "peixinkokkj", "XDBerna7",
    "vencedor87", "28kxPuppy", "28kxlucaz", "29kxHar", "pdenadai",
    "43dramalho", "jeremarcospr011", "biel975oi", "nnsochescrivere21", "lokis23162", "yoyok_felipe", "Guhtxk", "dezxql", "samantw540", "dezxql91", "l3nnon_blox", "0_crzxwy", "souruin_nomurder", "doraa2911", "soukaina9999999999", "28kxfrwd",
    "Doumabr", "mm2_davz", "jerehzxs", "leyaldiecoole12", "kwwhhei", "flxyerz", "gb2013q8", "solit9de", "BALA_LOVE0KKJ",
}
local TOTAL = #NAMES
local TOTAL_OK = TOTAL

local function copyToClipboard(text)
    local fn = (type(setclipboard) == "function" and setclipboard)
        or (type(toclipboard) == "function" and toclipboard)
        or (type(writeclipboard) == "function" and writeclipboard)
    if not fn then return false end
    return (pcall(fn, text))
end

local mainList = Instance.new("Frame")
mainList.Size = UDim2.fromOffset(fitW(360), fitH(480))
mainList.Position = UDim2.new(0.5, 0, 0.5, 0)
mainList.AnchorPoint = Vector2.new(0.5, 0.5)
mainList.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
mainList.BorderSizePixel = 0; mainList.Active = true
applyGlass(mainList, 0.2); mainList.Parent = listGui
Instance.new("UICorner", mainList).CornerRadius = UDim.new(0, 8)
local ms = Instance.new("UIStroke", mainList)
ms.Color = Color3.fromRGB(0, 0, 0); ms.Thickness = 2

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
titleBar.BorderSizePixel = 0; titleBar.Parent = mainList
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
makeDraggable(mainList, titleBar)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -46, 1, 0); title.Position = UDim2.new(0, 12, 0, 0)
title.Font = Enum.Font.BuilderSansBold
title.Text = "LIST USER CNP • " .. TOTAL
title.TextColor3 = Color3.fromRGB(255, 255, 255); title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(24, 24); closeBtn.Position = UDim2.new(1, -30, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeBtn.Text = "X"; closeBtn.Font = Enum.Font.BuilderSansBold
closeBtn.TextSize = 12; closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
closeBtn.Activated:Connect(function() listGui.Enabled = false end)

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -20, 0, 25); searchBox.Position = UDim2.new(0, 10, 0, 42)
searchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
searchBox.PlaceholderText = "Search name..."
searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
searchBox.Text = ""; searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBox.Font = Enum.Font.BuilderSans; searchBox.TextSize = 11
searchBox.ClearTextOnFocus = false; searchBox.Parent = mainList
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)

local SCROLL_TOP = 75
local scrollList = Instance.new("ScrollingFrame")
scrollList.Size = UDim2.new(1, -10, 1, -(SCROLL_TOP + 8))
scrollList.Position = UDim2.new(0, 5, 0, SCROLL_TOP)
scrollList.BackgroundTransparency = 1; scrollList.BorderSizePixel = 0
scrollList.ScrollBarThickness = 3
scrollList.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollList.ScrollingDirection = Enum.ScrollingDirection.Y
scrollList.Parent = mainList

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4); layout.Parent = scrollList
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 2); pad.PaddingLeft = UDim.new(0, 2)
pad.PaddingRight = UDim.new(0, 2); pad.Parent = scrollList

local rows = {}
local function createRow(name, order)
    local row = Instance.new("Frame")
    row.Name = name; row.Size = UDim2.new(1, -4, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = scrollList
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", row)
    stroke.Color = Color3.fromRGB(60, 60, 65); stroke.Thickness = 1

    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.fromOffset(28, 28)
    avatar.Position = UDim2.new(0, 5, 0.5, 0)
    avatar.AnchorPoint = Vector2.new(0, 0.5)
    avatar.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    avatar.BorderSizePixel = 0; avatar.Image = ""
    avatar.ScaleType = Enum.ScaleType.Crop; avatar.Parent = row
    Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -100, 1, 0); label.Position = UDim2.new(0, 38, 0, 0)
    label.Font = Enum.Font.BuilderSansBold; label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255); label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd; label.Parent = row

    local hint = Instance.new("TextLabel")
    hint.BackgroundTransparency = 1
    hint.Size = UDim2.fromOffset(50, 38); hint.Position = UDim2.new(1, -55, 0, 0)
    hint.Font = Enum.Font.BuilderSansBold; hint.Text = "COPY"
    hint.TextColor3 = Color3.fromRGB(255, 100, 150); hint.TextSize = 10
    hint.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromScale(1, 1); btn.BackgroundTransparency = 1
    btn.Text = ""; btn.Parent = row
    btn.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12),
            { BackgroundColor3 = Color3.fromRGB(45, 45, 50) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12),
            { BackgroundColor3 = Color3.fromRGB(30, 30, 35) }):Play()
    end)
    btn.Activated:Connect(function()
        local ok = copyToClipboard(name)
        if ok then
            hint.Text = "COPIED"; hint.TextColor3 = Color3.fromRGB(130, 220, 160)
        else
            hint.Text = "FAIL!"; hint.TextColor3 = Color3.fromRGB(220, 50, 50)
        end
        task.delay(1.2, function()
            hint.Text = "COPY"; hint.TextColor3 = Color3.fromRGB(255, 100, 150)
        end)
    end)
    table.insert(rows, { name = name, avatar = avatar, frame = row })
end

for i, n in ipairs(NAMES) do createRow(n, i) end
scrollList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 15)
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 15)
end)

task.spawn(function()
    for i = #rows, 1, -1 do
        local data = rows[i]
        local ok, userId = pcall(function()
            return Players:GetUserIdFromNameAsync(data.name)
        end)
        if not ok or not userId or userId <= 0 then
            data.frame:Destroy()
            table.remove(rows, i)
            TOTAL_OK = TOTAL_OK - 1
            title.Text = ("LIST USER CNP • %d/%d"):format(TOTAL_OK, TOTAL)
        else
            local ok2, img = pcall(function()
                return Players:GetUserThumbnailAsync(userId,
                    Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok2 and img then data.avatar.Image = img end
        end
        task.wait(0.1)
    end
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q = searchBox.Text:lower()
    for _, data in ipairs(rows) do
        if q == "" then
            data.frame.Visible = true
        else
            data.frame.Visible = data.name:lower():find(q, 1, true) ~= nil
        end
    end
end)

UI.action(scroll, 18, "list user cnp", function()
    if listGui then listGui.Enabled = not listGui.Enabled end
end)


-- =====================================================================
-- ESP (Role outline: Knife = red, Gun = blue, others = white)
-- =====================================================================
do
local espActive = false
local ESP_NAME = "CNP_ToolESP"
local ESP_COLORS = {
    Knife = Color3.fromRGB(255, 70, 90),
    Gun = Color3.fromRGB(70, 140, 255),
    None = Color3.fromRGB(255, 255, 255),
}
local espLoopToken = 0

local function espHasTool(plr, toolName)
    local bp = plr:FindFirstChildOfClass("Backpack")
    if bp and bp:FindFirstChild(toolName) then return true end
    local ch = plr.Character
    if ch and ch:FindFirstChild(toolName) then return true end
    return false
end

local function espClear(plr)
    local ch = plr.Character
    local h = ch and ch:FindFirstChild(ESP_NAME)
    if h then h:Destroy() end
end

local function espUpdate(plr)
    if plr == player then return end
    local ch = plr.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not ch or not hum or hum.Health <= 0 then
        espClear(plr)
        return
    end
    local col = ESP_COLORS.None
    if espHasTool(plr, "Knife") then
        col = ESP_COLORS.Knife
    elseif espHasTool(plr, "Gun") then
        col = ESP_COLORS.Gun
    end
    local hl = ch:FindFirstChild(ESP_NAME)
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = ESP_NAME
        hl.Adornee = ch
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 1 -- outline only
        hl.Parent = ch
    end
    hl.OutlineColor = col
    hl.OutlineTransparency = 0
    hl.FillColor = col
end

local function espStop()
    espActive = false
    espLoopToken = espLoopToken + 1
    for _, plr in ipairs(Players:GetPlayers()) do espClear(plr) end
end

local function espStart()
    if espActive then return end
    espActive = true
    espLoopToken = espLoopToken + 1
    local my = espLoopToken
    task.spawn(function()
        while espActive and my == espLoopToken do
            for _, plr in ipairs(Players:GetPlayers()) do
                pcall(espUpdate, plr)
            end
            task.wait(0.5)
        end
    end)
end

UI.toggle(scroll, 3, "esp", false, function(v)
    if v then espStart() else espStop() end
end)
-- order 3 = esp (kept)

end -- close ESP block

end -- close LIST USER block (fix)

-- Minimize
minBtn.Activated:Connect(function()
    isMini = not isMini
    scroll.Visible = not isMini
    if UI.decor then UI.decor.Visible = not isMini end
    minBtn.Text = isMini and "+" or "-"
    local target = isMini
        and UDim2.new(UI.full.X.Scale, UI.full.X.Offset, 0, 31)
        or UI.full
    TweenService:Create(mainFrame,
        TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Size = target }):Play()
end)

-- =====================================================================
-- ADVANCED: KEY GATE + GEAR + BEAM
-- =====================================================================
local TOOLS_KEY = "" -- key system removed
local toolsUnlocked = true

local function CNP_GearSection() -- own function = own 200-local budget
local function getHum()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end


local function carpetReleaseMove(hum)
    if not hum then return end
    pcall(function()
        hum.PlatformStand = false
        hum.Sit = false
        hum.AutoRotate = true
        if hum.WalkSpeed < 1 and not speedEnabled then
            hum.WalkSpeed = BASE_SPEED
        end
    end)
    -- do not force MouseBehavior.Default if user is shiftlocked
    pcall(function()
        if not enableOldShiftLock
            and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
            -- leave as-is
        end
    end)
end

local function createRainbowCarpet()
    local BaseUrl = "http://www.roblox.com/asset/?id="
    local CarpetPieces = {
        { MeshId = 223079795 }, { MeshId = 223079835 },
        { MeshId = 223079888 }, { MeshId = 223079981 },
    }
    local CarpetSize = Vector3.new(3, 0.5, 6.5)
    local CarpetOffset = Vector3.new(0, -1.6, 0.5)
    local CameraSpeed = { X = 70, Z = 105 }
    local Rate = 1 / 10
    local RainbowColors = {
        Color3.new(1, 0, 0), Color3.new(1, 0.5, 0), Color3.new(1, 1, 0), Color3.new(0, 1, 0),
        Color3.new(0, 1, 1), Color3.new(0, 0, 1), Color3.new(0.5, 0, 1),
    }
    local Grips = {
        Normal = CFrame.new(-1.5, 0, 0, 0, 0, -1, -1, 8.90154915e-005, 0, 8.90154915e-005, 1, 0),
        Flying = CFrame.new(-1.5, 0.5, -0.75, -1, 0, -8.99756625e-009, -8.99756625e-009, 8.10000031e-008, 1, 7.28802977e-016, 0.99999994, -8.10000103e-008),
    }
    local old = bp:FindFirstChild("Rainbow Carpet") or (player.Character and player.Character:FindFirstChild("Rainbow Carpet"))
    if old then old:Destroy() end

    local Tool = Instance.new("Tool")
    Tool.Name = "Rainbow Carpet"
    Tool.RequiresHandle = true
    Tool.CanBeDropped = false
    Tool.Grip = Grips.Normal
    Tool.TextureId = "rbxassetid://223080070"

    local Handle = Instance.new("Part")
    Handle.Name = "Handle"; Handle.Size = CarpetSize
    Handle.Transparency = 1; Handle.CanCollide = false; Handle.Massless = true
    Handle.Parent = Tool

    local Roll = Instance.new("Part")
    Roll.Name = "Roll"; Roll.Size = CarpetSize
    Roll.CanCollide = false; Roll.Massless = true
    local RollMesh = Instance.new("SpecialMesh")
    RollMesh.MeshType = Enum.MeshType.FileMesh
    RollMesh.MeshId = BaseUrl .. "223079737"
    RollMesh.Scale = Vector3.new(1.125, 1.125, 1.125)
    RollMesh.TextureId = BaseUrl .. "223080038"
    RollMesh.Parent = Roll
    local RollWeld = Instance.new("Weld")
    RollWeld.Part0 = Handle; RollWeld.Part1 = Roll; RollWeld.Parent = Roll
    Roll.Parent = Tool

    local SitR6 = Instance.new("Animation"); SitR6.AnimationId = "http://www.roblox.com/asset/?id=225279725"; SitR6.Parent = Tool
    local SitR15 = Instance.new("Animation"); SitR15.AnimationId = "rbxassetid://855828754"; SitR15.Parent = Tool

    local Flying, ToolEquipped, Cooldown = false, false, false
    local Character, Humanoid, Root
    local FlightSpin, FlightPower, FlightHold, AnimTrack, FlightConn
    local TrailFolder = Workspace:FindFirstChild("CarpetRainbow") or Instance.new("Folder")
    TrailFolder.Name = "CarpetRainbow"; TrailFolder.Parent = Workspace

    local function CheckIfAlive()
        return Character and Character.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0
            and Root and Root.Parent
    end
    local function CleanUpCarpet()
        for _, v in ipairs(Tool:GetChildren()) do
            if v:IsA("BasePart") and v ~= Handle and v.Name ~= "Roll" then v:Destroy() end
        end
    end
    local function BuildCarpet()
        local n = #CarpetPieces
        for i, v in ipairs(CarpetPieces) do
            local part = Instance.new("Part")
            part.Size = Vector3.new(CarpetSize.X, CarpetSize.Y, CarpetSize.Z / n)
            part.CanCollide = false; part.Massless = true
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. v.MeshId
            mesh.TextureId = BaseUrl .. "223080038"
            mesh.Scale = Vector3.new(1.125, 1.125, 1.125)
            mesh.Parent = part
            local weld = Instance.new("Weld")
            weld.Part0 = Root
            weld.C0 = CFrame.new(CarpetOffset)
            weld.Part1 = part
            local xOff = ((i == 1 or i == n) and -0.005) or 0
            local zOff = (-((CarpetSize.Z / 2) - (part.Size.Z / 2))) + (part.Size.Z * (i - 1))
                + ((i == 2 and 0.245) or (i == 3 and 0.04) or (i == n and 0.28) or 0)
            weld.C1 = CFrame.new(0, xOff, zOff)
            weld.Parent = part
            part.Parent = Tool
        end
    end
    local function PlaySit()
        if not Humanoid then return end
        local anim = (Humanoid.RigType == Enum.HumanoidRigType.R15) and SitR15 or SitR6
        pcall(function()
            local animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid
            if AnimTrack then AnimTrack:Stop() end
            AnimTrack = animator:LoadAnimation(anim)
            AnimTrack:Play()
        end)
    end
    local function StopSit()
        if AnimTrack then pcall(function() AnimTrack:Stop() end); AnimTrack = nil end
    end
    local function CreateRainbow(lastPlace, currentPlace)
        local distance = (lastPlace - currentPlace).Magnitude
        if distance < 0.1 then return end
        local length = distance + 3.5
        local mid = CFrame.new(lastPlace + (currentPlace - lastPlace).Unit * (distance / 2), currentPlace)
        local model = Instance.new("Model")
        for i, color in ipairs(RainbowColors) do
            local p = Instance.new("Part")
            p.Anchored = true; p.CanCollide = false; p.Material = Enum.Material.SmoothPlastic
            p.Reflectance = 0.25; p.Transparency = 0.1
            p.Size = Vector3.new(0.5, 0.5, length)
            p.CFrame = mid * CFrame.new((i - 4) * 0.5, 0, 0)
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. "9856898"; mesh.TextureId = BaseUrl .. "1361097"
            mesh.Scale = p.Size * 2
            mesh.VertexColor = Vector3.new(color.R, color.G, color.B)
            mesh.Parent = p
            local light = Instance.new("PointLight")
            light.Brightness = 8; light.Range = 5; light.Color = color; light.Parent = p
            p.Parent = model
        end
        model.Parent = TrailFolder
        Debris:AddItem(model, 1)
    end
    local ControlsModule
    pcall(function()
        ControlsModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
    end)
    local function GetMoveVector()
        if ControlsModule then
            local ok, v = pcall(function() return ControlsModule:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then return v end
        end
        local md = Humanoid and Humanoid.MoveDirection or Vector3.zero
        local cf = Workspace.CurrentCamera.CFrame
        return Vector3.new(md:Dot(cf.RightVector), 0, -md:Dot(cf.LookVector))
    end
    local function StopFlying()
        Flying = false
        if FlightConn then FlightConn:Disconnect(); FlightConn = nil end
        for _, v in ipairs({ FlightSpin, FlightPower, FlightHold }) do
            if v and v.Parent then pcall(function() v:Destroy() end) end
        end
        FlightSpin, FlightPower, FlightHold = nil, nil, nil
        -- nuke any leftover movers that can freeze movement
        if Root then
            for _, ch in ipairs(Root:GetChildren()) do
                local n = ch.Name
                if n == "FlightSpin" or n == "FlightPower" or n == "FlightHold"
                    or ch:IsA("BodyVelocity") or ch:IsA("BodyPosition") or ch:IsA("BodyGyro") then
                    if n:find("Flight") or n == "FlightSpin" or n == "FlightPower" or n == "FlightHold" then
                        pcall(function() ch:Destroy() end)
                    end
                end
            end
        end
        if CheckIfAlive() then
            pcall(function()
                Root.AssemblyLinearVelocity = Vector3.zero
                Root.AssemblyAngularVelocity = Vector3.zero
            end)
            Humanoid.PlatformStand = false
            Humanoid.AutoRotate = true
            Humanoid.Sit = false
            if not speedEnabled then
                Humanoid.WalkSpeed = BASE_SPEED
            elseif Humanoid.WalkSpeed < 1 then
                Humanoid.WalkSpeed = BASE_SPEED
            end
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.defer(function()
                if Humanoid and Humanoid.Parent then
                    Humanoid.PlatformStand = false
                    if Humanoid.WalkSpeed < 1 then Humanoid.WalkSpeed = BASE_SPEED end
                end
            end)
        end
        StopSit(); Tool.Grip = Grips.Normal; CleanUpCarpet(); Roll.Transparency = 0
    end
    local function StartFlying()
        Flying = true; Roll.Transparency = 1; CleanUpCarpet(); BuildCarpet(); PlaySit()
        Tool.Grip = Grips.Flying
        FlightSpin = Instance.new("BodyGyro")
        FlightSpin.P = 1e6; FlightSpin.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        FlightSpin.CFrame = Root.CFrame; FlightSpin.Parent = Root
        FlightPower = Instance.new("BodyVelocity")
        FlightPower.Velocity = Vector3.zero; FlightPower.P = 10000
        FlightPower.MaxForce = Vector3.zero; FlightPower.Parent = Root
        FlightHold = Instance.new("BodyPosition")
        FlightHold.P = 1e5; FlightHold.MaxForce = Vector3.zero
        FlightHold.Position = Root.Position; FlightHold.Parent = Root
        Humanoid.WalkSpeed = 0; Humanoid.PlatformStand = false; Humanoid.AutoRotate = false
        Root.AssemblyLinearVelocity = Vector3.zero
        FlightConn = RunService.Heartbeat:Connect(function()
            if not (Flying and ToolEquipped and CheckIfAlive()) then StopFlying(); return end
            Humanoid.Jump = false
            local look = Workspace.CurrentCamera.CFrame.LookVector
            local right = Workspace.CurrentCamera.CFrame.RightVector
            local mv = GetMoveVector()
            local push = (look * (-mv.Z) * CameraSpeed.Z) + (right * mv.X * CameraSpeed.X)
            FlightSpin.CFrame = CFrame.new(Vector3.zero, look)
            if push.Magnitude < 1 then
                FlightHold.MaxForce = Vector3.new(FlightHold.P, FlightHold.P, FlightHold.P)
                FlightPower.MaxForce = Vector3.zero
                FlightHold.Position = Root.Position
            else
                FlightHold.MaxForce = Vector3.zero
                FlightPower.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            end
            FlightPower.Velocity = push
        end)
        task.spawn(function()
            local lastPlace
            while Flying and ToolEquipped and CheckIfAlive() do
                local current = (Root.CFrame * CFrame.new(CarpetOffset)).Position
                local vel = Root.AssemblyLinearVelocity
                local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                if lastPlace and speed > 10 then
                    CreateRainbow(lastPlace, current); lastPlace = current
                elseif not lastPlace then
                    lastPlace = current
                end
                task.wait(Rate)
            end
        end)
    end
    Tool.Equipped:Connect(function()
        Character = Tool.Parent
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        Root = Character:FindFirstChild("HumanoidRootPart")
        ToolEquipped = true; Tool.Grip = Grips.Normal
    end)
    Tool.Unequipped:Connect(function()
        ToolEquipped = false
        if Flying then StopFlying() end
        Roll.Transparency = 0
    end)
    Tool.Activated:Connect(function()
        if Cooldown or not CheckIfAlive() then return end
        Cooldown = true
        if Flying then StopFlying() else StartFlying() end
        task.delay(2, function() Cooldown = false end)
    end)
    return Tool
end

local function createBloodCarpet()
    local BaseUrl = "http://www.roblox.com/asset/?id="
    local CarpetIconId = "rbxassetid://72140049013374"
    local CarpetTextureId = "rbxassetid://137578723613004"

    local CarpetPieces = {
        { MeshId = 223079795 }, { MeshId = 223079835 },
        { MeshId = 223079888 }, { MeshId = 223079981 },
    }
    local CarpetSize = Vector3.new(3, 0.5, 6.5)
    local CarpetOffset = Vector3.new(0, -1.6, 0.5)
    local CameraSpeed = { X = 70, Z = 105 }
    local Rate = 1 / 10
    local StripeWidth = 0.32

    local BloodColors = {
        Color3.fromRGB(45, 0, 0),
        Color3.fromRGB(80, 0, 4),
        Color3.fromRGB(120, 0, 8),
        Color3.fromRGB(165, 5, 12),
        Color3.fromRGB(215, 15, 18),
        Color3.fromRGB(255, 35, 35),
        Color3.fromRGB(215, 15, 18),
        Color3.fromRGB(165, 5, 12),
        Color3.fromRGB(120, 0, 8),
        Color3.fromRGB(80, 0, 4),
        Color3.fromRGB(45, 0, 0),
    }

    local CarpetTint = Vector3.new(1, 1, 1)

    local Grips = {
        Normal = CFrame.new(-1.5, 0, 0, 0, 0, -1, -1, 8.90154915e-005, 0, 8.90154915e-005, 1, 0),
        Flying = CFrame.new(-1.5, 0.5, -0.75, -1, 0, -8.99756625e-009, -8.99756625e-009, 8.10000031e-008, 1, 7.28802977e-016, 0.99999994, -8.10000103e-008),
    }

    local bag = getBackpack and getBackpack() or bp
    local char0 = player.Character
    local old = (bag and bag:FindFirstChild("Blood Carpet"))
        or (char0 and char0:FindFirstChild("Blood Carpet"))
    if old then old:Destroy() end

    local Tool = Instance.new("Tool")
    Tool.Name = "Blood Carpet"
    Tool.RequiresHandle = true
    Tool.CanBeDropped = false
    Tool.Grip = Grips.Normal
    Tool.TextureId = CarpetIconId

    local Handle = Instance.new("Part")
    Handle.Name = "Handle"
    Handle.Size = CarpetSize
    Handle.Transparency = 1
    Handle.CanCollide = false
    Handle.Massless = true
    Handle.Parent = Tool

    local Roll = Instance.new("Part")
    Roll.Name = "Roll"
    Roll.Size = CarpetSize
    Roll.CanCollide = false
    Roll.Massless = true

    local RollMesh = Instance.new("SpecialMesh")
    RollMesh.MeshType = Enum.MeshType.FileMesh
    RollMesh.MeshId = BaseUrl .. "223079737"
    RollMesh.Scale = Vector3.new(1.125, 1.125, 1.125)
    RollMesh.TextureId = CarpetTextureId
    RollMesh.VertexColor = CarpetTint
    RollMesh.Parent = Roll

    local RollWeld = Instance.new("Weld")
    RollWeld.Part0 = Handle
    RollWeld.Part1 = Roll
    RollWeld.Parent = Roll
    Roll.Parent = Tool

    local SitR6 = Instance.new("Animation")
    SitR6.AnimationId = "http://www.roblox.com/asset/?id=225279725"
    SitR6.Parent = Tool

    local SitR15 = Instance.new("Animation")
    SitR15.AnimationId = "rbxassetid://855828754"
    SitR15.Parent = Tool

    local Flying, ToolEquipped, Cooldown = false, false, false
    local Character, Humanoid, Root
    local FlightSpin, FlightPower, FlightHold, AnimTrack, FlightConn

    local TrailFolder = Workspace:FindFirstChild("CarpetBlood") or Instance.new("Folder")
    TrailFolder.Name = "CarpetBlood"
    TrailFolder.Parent = Workspace

    local function CheckIfAlive()
        return Character and Character.Parent
            and Humanoid and Humanoid.Parent and Humanoid.Health > 0
            and Root and Root.Parent
    end

    local function CleanUpCarpet()
        for _, v in ipairs(Tool:GetChildren()) do
            if v:IsA("BasePart") and v ~= Handle and v.Name ~= "Roll" then
                v:Destroy()
            end
        end
    end

    local function BuildCarpet()
        local n = #CarpetPieces
        for i, v in ipairs(CarpetPieces) do
            local part = Instance.new("Part")
            part.Size = Vector3.new(CarpetSize.X, CarpetSize.Y, CarpetSize.Z / n)
            part.CanCollide = false
            part.Massless = true

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. v.MeshId
            mesh.TextureId = CarpetTextureId
            mesh.Scale = Vector3.new(1.125, 1.125, 1.125)
            mesh.VertexColor = CarpetTint
            mesh.Parent = part

            local weld = Instance.new("Weld")
            weld.Part0 = Root
            weld.C0 = CFrame.new(CarpetOffset)
            weld.Part1 = part

            local xOff = ((i == 1 or i == n) and -0.005) or 0
            local zOff = (-((CarpetSize.Z / 2) - (part.Size.Z / 2))) + (part.Size.Z * (i - 1))
                + ((i == 2 and 0.245) or (i == 3 and 0.04) or (i == n and 0.28) or 0)
            weld.C1 = CFrame.new(0, xOff, zOff)
            weld.Parent = part
            part.Parent = Tool
        end
    end

    local function PlaySit()
        if not Humanoid then return end
        local anim = (Humanoid.RigType == Enum.HumanoidRigType.R15) and SitR15 or SitR6
        pcall(function()
            local animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid
            if AnimTrack then AnimTrack:Stop() end
            AnimTrack = animator:LoadAnimation(anim)
            AnimTrack:Play()
        end)
    end

    local function StopSit()
        if AnimTrack then
            pcall(function() AnimTrack:Stop() end)
            AnimTrack = nil
        end
    end

    local function CreateBloodTrail(lastPlace, currentPlace)
        local distance = (lastPlace - currentPlace).Magnitude
        if distance < 0.1 then return end

        local length = distance + 3.5
        local mid = CFrame.new(lastPlace + (currentPlace - lastPlace).Unit * (distance / 2), currentPlace)
        local model = Instance.new("Model")
        local centerIndex = (#BloodColors + 1) / 2

        for i, color in ipairs(BloodColors) do
            local p = Instance.new("Part")
            p.Anchored = true
            p.CanCollide = false
            p.Material = Enum.Material.SmoothPlastic
            p.Reflectance = 0.25
            p.Transparency = 0.1
            p.Size = Vector3.new(StripeWidth, 0.5, length)
            p.CFrame = mid * CFrame.new((i - centerIndex) * StripeWidth, 0, 0)

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. "9856898"
            mesh.TextureId = BaseUrl .. "1361097"
            mesh.Scale = Vector3.new(StripeWidth * 2, 1, length * 2)
            mesh.VertexColor = Vector3.new(color.R, color.G, color.B)
            mesh.Parent = p

            local light = Instance.new("PointLight")
            light.Brightness = 4
            light.Range = 5
            light.Color = Color3.fromRGB(180, 0, 10)
            light.Parent = p

            p.Parent = model
        end

        model.Parent = TrailFolder
        Debris:AddItem(model, 1)
    end

    local ControlsModule
    pcall(function()
        ControlsModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
    end)

    local function GetMoveVector()
        if ControlsModule then
            local ok, v = pcall(function() return ControlsModule:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then return v end
        end
        local md = Humanoid and Humanoid.MoveDirection or Vector3.zero
        local cf = Workspace.CurrentCamera.CFrame
        return Vector3.new(md:Dot(cf.RightVector), 0, -md:Dot(cf.LookVector))
    end

    local function StopFlying()
        Flying = false
        if FlightConn then
            FlightConn:Disconnect()
            FlightConn = nil
        end
        for _, v in ipairs({ FlightSpin, FlightPower, FlightHold }) do
            if v and v.Parent then
                pcall(function() v:Destroy() end)
            end
        end
        FlightSpin, FlightPower, FlightHold = nil, nil, nil

        if Root then
            for _, ch in ipairs(Root:GetChildren()) do
                local n = ch.Name
                if (n == "FlightSpin" or n == "FlightPower" or n == "FlightHold") then
                    pcall(function() ch:Destroy() end)
                end
            end
        end

        if CheckIfAlive() then
            pcall(function()
                Root.AssemblyLinearVelocity = Vector3.zero
                Root.AssemblyAngularVelocity = Vector3.zero
            end)
            Humanoid.PlatformStand = false
            Humanoid.AutoRotate = true
            Humanoid.Sit = false
            if not speedEnabled then
                Humanoid.WalkSpeed = BASE_SPEED
            elseif Humanoid.WalkSpeed < 1 then
                Humanoid.WalkSpeed = BASE_SPEED
            end
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.defer(function()
                if Humanoid and Humanoid.Parent then
                    Humanoid.PlatformStand = false
                    if Humanoid.WalkSpeed < 1 then Humanoid.WalkSpeed = BASE_SPEED end
                end
            end)
        end

        StopSit()
        Tool.Grip = Grips.Normal
        CleanUpCarpet()
        Roll.Transparency = 0
    end

    local function StartFlying()
        Flying = true
        Roll.Transparency = 1
        CleanUpCarpet()
        BuildCarpet()
        PlaySit()
        Tool.Grip = Grips.Flying

        FlightSpin = Instance.new("BodyGyro")
        FlightSpin.Name = "FlightSpin"
        FlightSpin.P = 1e6
        FlightSpin.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        FlightSpin.CFrame = Root.CFrame
        FlightSpin.Parent = Root

        FlightPower = Instance.new("BodyVelocity")
        FlightPower.Name = "FlightPower"
        FlightPower.Velocity = Vector3.zero
        FlightPower.P = 10000
        FlightPower.MaxForce = Vector3.zero
        FlightPower.Parent = Root

        FlightHold = Instance.new("BodyPosition")
        FlightHold.Name = "FlightHold"
        FlightHold.P = 1e5
        FlightHold.MaxForce = Vector3.zero
        FlightHold.Position = Root.Position
        FlightHold.Parent = Root

        Humanoid.WalkSpeed = 0
        Humanoid.PlatformStand = false -- keep shiftlock mouse free
        Humanoid.AutoRotate = false
        Root.AssemblyLinearVelocity = Vector3.zero

        FlightConn = RunService.Heartbeat:Connect(function()
            if not (Flying and ToolEquipped and CheckIfAlive()) then
                StopFlying()
                return
            end
            Humanoid.Jump = false
            local look = Workspace.CurrentCamera.CFrame.LookVector
            local right = Workspace.CurrentCamera.CFrame.RightVector
            local mv = GetMoveVector()
            local push = (look * (-mv.Z) * CameraSpeed.Z) + (right * mv.X * CameraSpeed.X)
            FlightSpin.CFrame = CFrame.new(Vector3.zero, look)
            if push.Magnitude < 1 then
                FlightHold.MaxForce = Vector3.new(FlightHold.P, FlightHold.P, FlightHold.P)
                FlightPower.MaxForce = Vector3.zero
                FlightHold.Position = Root.Position
            else
                FlightHold.MaxForce = Vector3.zero
                FlightPower.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            end
            FlightPower.Velocity = push
        end)

        task.spawn(function()
            local lastPlace
            while Flying and ToolEquipped and CheckIfAlive() do
                local current = (Root.CFrame * CFrame.new(CarpetOffset)).Position
                local vel = Root.AssemblyLinearVelocity
                local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                if lastPlace and speed > 10 then
                    CreateBloodTrail(lastPlace, current)
                    lastPlace = current
                elseif not lastPlace then
                    lastPlace = current
                end
                task.wait(Rate)
            end
        end)
    end

    Tool.Equipped:Connect(function()
        Character = Tool.Parent
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        Root = Character:FindFirstChild("HumanoidRootPart")
        ToolEquipped = true
        Tool.Grip = Grips.Normal
    end)

    Tool.Unequipped:Connect(function()
        ToolEquipped = false
        if Flying then StopFlying() end
        Roll.Transparency = 0
    end)

    Tool.Activated:Connect(function()
        if Cooldown or not CheckIfAlive() then return end
        Cooldown = true
        if Flying then StopFlying() else StartFlying() end
        task.delay(2, function() Cooldown = false end)
    end)

    return Tool
end

local function createCinnaCarpet()
    local BaseUrl = "http://www.roblox.com/asset/?id="
    local CarpetIconId = "rbxassetid://104670537921161"
    local CarpetTextureId = "rbxassetid://96331741023084"

    local CarpetPieces = {
        { MeshId = 223079795 }, { MeshId = 223079835 },
        { MeshId = 223079888 }, { MeshId = 223079981 },
    }
    local CarpetSize = Vector3.new(3, 0.5, 6.5)
    local CarpetOffset = Vector3.new(0, -1.6, 0.5)
    local CameraSpeed = { X = 70, Z = 105 }
    local Rate = 1 / 10
    local StripeWidth = 0.32

    local CinnamorollColors = {
        Color3.fromRGB(135, 175, 225),
        Color3.fromRGB(155, 195, 238),
        Color3.fromRGB(180, 218, 248),
        Color3.fromRGB(205, 234, 255),
        Color3.fromRGB(232, 246, 255),
        Color3.fromRGB(255, 252, 250),
        Color3.fromRGB(232, 246, 255),
        Color3.fromRGB(205, 234, 255),
        Color3.fromRGB(180, 218, 248),
        Color3.fromRGB(155, 195, 238),
        Color3.fromRGB(135, 175, 225),
    }

    local CarpetTint = Vector3.new(1, 1, 1)
    local Grips = {
        Normal = CFrame.new(-1.5, 0, 0, 0, 0, -1, -1, 8.90154915e-005, 0, 8.90154915e-005, 1, 0),
        Flying = CFrame.new(-1.5, 0.5, -0.75, -1, 0, -8.99756625e-009, -8.99756625e-009, 8.10000031e-008, 1, 7.28802977e-016, 0.99999994, -8.10000103e-008),
    }

    local bag = getBackpack and getBackpack() or bp
    local char0 = player.Character
    local old = (bag and bag:FindFirstChild("Cinnamoroll Carpet"))
        or (char0 and char0:FindFirstChild("Cinnamoroll Carpet"))
    if old then old:Destroy() end

    local Tool = Instance.new("Tool")
    Tool.Name = "Cinnamoroll Carpet"
    Tool.RequiresHandle = true
    Tool.CanBeDropped = false
    Tool.Grip = Grips.Normal
    Tool.TextureId = CarpetIconId

    local Handle = Instance.new("Part")
    Handle.Name = "Handle"
    Handle.Size = CarpetSize
    Handle.Transparency = 1
    Handle.CanCollide = false
    Handle.Massless = true
    Handle.Parent = Tool

    local Roll = Instance.new("Part")
    Roll.Name = "Roll"
    Roll.Size = CarpetSize
    Roll.CanCollide = false
    Roll.Massless = true

    local RollMesh = Instance.new("SpecialMesh")
    RollMesh.MeshType = Enum.MeshType.FileMesh
    RollMesh.MeshId = BaseUrl .. "223079737"
    RollMesh.Scale = Vector3.new(1.125, 1.125, 1.125)
    RollMesh.TextureId = CarpetTextureId
    RollMesh.VertexColor = CarpetTint
    RollMesh.Parent = Roll

    local RollWeld = Instance.new("Weld")
    RollWeld.Part0 = Handle
    RollWeld.Part1 = Roll
    RollWeld.Parent = Roll
    Roll.Parent = Tool

    local SitR6 = Instance.new("Animation")
    SitR6.AnimationId = "http://www.roblox.com/asset/?id=225279725"
    SitR6.Parent = Tool
    local SitR15 = Instance.new("Animation")
    SitR15.AnimationId = "rbxassetid://855828754"
    SitR15.Parent = Tool

    local Flying, ToolEquipped, Cooldown = false, false, false
    local Character, Humanoid, Root
    local FlightSpin, FlightPower, FlightHold, AnimTrack, FlightConn

    local TrailFolder = Workspace:FindFirstChild("CarpetCinna") or Instance.new("Folder")
    TrailFolder.Name = "CarpetCinna"
    TrailFolder.Parent = Workspace

    local function CheckIfAlive()
        return Character and Character.Parent
            and Humanoid and Humanoid.Parent and Humanoid.Health > 0
            and Root and Root.Parent
    end

    local function CleanUpCarpet()
        for _, v in ipairs(Tool:GetChildren()) do
            if v:IsA("BasePart") and v ~= Handle and v.Name ~= "Roll" then
                v:Destroy()
            end
        end
    end

    local function BuildCarpet()
        local n = #CarpetPieces
        for i, v in ipairs(CarpetPieces) do
            local part = Instance.new("Part")
            part.Size = Vector3.new(CarpetSize.X, CarpetSize.Y, CarpetSize.Z / n)
            part.CanCollide = false
            part.Massless = true
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. v.MeshId
            mesh.TextureId = CarpetTextureId
            mesh.Scale = Vector3.new(1.125, 1.125, 1.125)
            mesh.VertexColor = CarpetTint
            mesh.Parent = part
            local weld = Instance.new("Weld")
            weld.Part0 = Root
            weld.C0 = CFrame.new(CarpetOffset)
            weld.Part1 = part
            local xOff = ((i == 1 or i == n) and -0.005) or 0
            local zOff = (-((CarpetSize.Z / 2) - (part.Size.Z / 2))) + (part.Size.Z * (i - 1))
                + ((i == 2 and 0.245) or (i == 3 and 0.04) or (i == n and 0.28) or 0)
            weld.C1 = CFrame.new(0, xOff, zOff)
            weld.Parent = part
            part.Parent = Tool
        end
    end

    local function PlaySit()
        if not Humanoid then return end
        local anim = (Humanoid.RigType == Enum.HumanoidRigType.R15) and SitR15 or SitR6
        pcall(function()
            local animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid
            if AnimTrack then AnimTrack:Stop() end
            AnimTrack = animator:LoadAnimation(anim)
            AnimTrack:Play()
        end)
    end

    local function StopSit()
        if AnimTrack then pcall(function() AnimTrack:Stop() end); AnimTrack = nil end
    end

    local function CreateCinnamorollTrail(lastPlace, currentPlace)
        local distance = (lastPlace - currentPlace).Magnitude
        if distance < 0.1 then return end
        local length = distance + 3.5
        local mid = CFrame.new(lastPlace + (currentPlace - lastPlace).Unit * (distance / 2), currentPlace)
        local model = Instance.new("Model")
        local centerIndex = (#CinnamorollColors + 1) / 2
        for i, color in ipairs(CinnamorollColors) do
            local p = Instance.new("Part")
            p.Anchored = true
            p.CanCollide = false
            p.Material = Enum.Material.SmoothPlastic
            p.Reflectance = 0.2
            p.Transparency = 0.1
            p.Size = Vector3.new(StripeWidth, 0.5, length)
            p.CFrame = mid * CFrame.new((i - centerIndex) * StripeWidth, 0, 0)
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. "9856898"
            mesh.TextureId = BaseUrl .. "1361097"
            mesh.Scale = Vector3.new(StripeWidth * 2, 1, length * 2)
            mesh.VertexColor = Vector3.new(color.R, color.G, color.B)
            mesh.Parent = p
            local light = Instance.new("PointLight")
            light.Brightness = 4
            light.Range = 5
            light.Color = Color3.fromRGB(185, 222, 255)
            light.Parent = p
            p.Parent = model
        end
        model.Parent = TrailFolder
        Debris:AddItem(model, 1)
    end

    local ControlsModule
    pcall(function()
        ControlsModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
    end)

    local function GetMoveVector()
        if ControlsModule then
            local ok, v = pcall(function() return ControlsModule:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then return v end
        end
        local md = Humanoid and Humanoid.MoveDirection or Vector3.zero
        local cf = Workspace.CurrentCamera.CFrame
        return Vector3.new(md:Dot(cf.RightVector), 0, -md:Dot(cf.LookVector))
    end

    local function StopFlying()
        Flying = false
        if FlightConn then FlightConn:Disconnect(); FlightConn = nil end
        for _, v in ipairs({ FlightSpin, FlightPower, FlightHold }) do
            if v and v.Parent then pcall(function() v:Destroy() end) end
        end
        FlightSpin, FlightPower, FlightHold = nil, nil, nil
        if Root then
            for _, ch in ipairs(Root:GetChildren()) do
                if ch.Name == "FlightSpin" or ch.Name == "FlightPower" or ch.Name == "FlightHold" then
                    pcall(function() ch:Destroy() end)
                end
            end
        end
        if CheckIfAlive() then
            pcall(function()
                Root.AssemblyLinearVelocity = Vector3.zero
                Root.AssemblyAngularVelocity = Vector3.zero
            end)
            Humanoid.PlatformStand = false
            Humanoid.AutoRotate = true
            Humanoid.Sit = false
            if not speedEnabled or Humanoid.WalkSpeed < 1 then
                Humanoid.WalkSpeed = BASE_SPEED
            end
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
        StopSit()
        Tool.Grip = Grips.Normal
        CleanUpCarpet()
        Roll.Transparency = 0
    end

    local function StartFlying()
        Flying = true
        Roll.Transparency = 1
        CleanUpCarpet()
        BuildCarpet()
        PlaySit()
        Tool.Grip = Grips.Flying
        FlightSpin = Instance.new("BodyGyro")
        FlightSpin.Name = "FlightSpin"
        FlightSpin.P = 1e6
        FlightSpin.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        FlightSpin.CFrame = Root.CFrame
        FlightSpin.Parent = Root
        FlightPower = Instance.new("BodyVelocity")
        FlightPower.Name = "FlightPower"
        FlightPower.Velocity = Vector3.zero
        FlightPower.P = 10000
        FlightPower.MaxForce = Vector3.zero
        FlightPower.Parent = Root
        FlightHold = Instance.new("BodyPosition")
        FlightHold.Name = "FlightHold"
        FlightHold.P = 1e5
        FlightHold.MaxForce = Vector3.zero
        FlightHold.Position = Root.Position
        FlightHold.Parent = Root
        Humanoid.WalkSpeed = 0
        Humanoid.PlatformStand = false -- keep shiftlock mouse free
        Humanoid.AutoRotate = false
        Root.AssemblyLinearVelocity = Vector3.zero
        FlightConn = RunService.Heartbeat:Connect(function()
            if not (Flying and ToolEquipped and CheckIfAlive()) then StopFlying(); return end
            Humanoid.Jump = false
            local look = Workspace.CurrentCamera.CFrame.LookVector
            local right = Workspace.CurrentCamera.CFrame.RightVector
            local mv = GetMoveVector()
            local push = (look * (-mv.Z) * CameraSpeed.Z) + (right * mv.X * CameraSpeed.X)
            FlightSpin.CFrame = CFrame.new(Vector3.zero, look)
            if push.Magnitude < 1 then
                FlightHold.MaxForce = Vector3.new(FlightHold.P, FlightHold.P, FlightHold.P)
                FlightPower.MaxForce = Vector3.zero
                FlightHold.Position = Root.Position
            else
                FlightHold.MaxForce = Vector3.zero
                FlightPower.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            end
            FlightPower.Velocity = push
        end)
        task.spawn(function()
            local lastPlace
            while Flying and ToolEquipped and CheckIfAlive() do
                local current = (Root.CFrame * CFrame.new(CarpetOffset)).Position
                local vel = Root.AssemblyLinearVelocity
                local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                if lastPlace and speed > 10 then
                    CreateCinnamorollTrail(lastPlace, current)
                    lastPlace = current
                elseif not lastPlace then
                    lastPlace = current
                end
                task.wait(Rate)
            end
        end)
    end

    Tool.Equipped:Connect(function()
        Character = Tool.Parent
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        Root = Character:FindFirstChild("HumanoidRootPart")
        ToolEquipped = true
        Tool.Grip = Grips.Normal
    end)
    Tool.Unequipped:Connect(function()
        ToolEquipped = false
        if Flying then StopFlying() end
        Roll.Transparency = 0
    end)
    Tool.Activated:Connect(function()
        if Cooldown or not CheckIfAlive() then return end
        Cooldown = true
        if Flying then StopFlying() else StartFlying() end
        task.delay(2, function() Cooldown = false end)
    end)

    return Tool
end

local function createGoldCarpet()
    local BaseUrl = "http://www.roblox.com/asset/?id="
    local CarpetPieces = {
        { MeshId = 223079795 }, { MeshId = 223079835 },
        { MeshId = 223079888 }, { MeshId = 223079981 },
    }
    local CarpetSize = Vector3.new(3, 0.5, 6.5)
    local CameraSpeed = { X = 70, Z = 105 }
    local Rate = 1 / 10
    local RainbowColors = {
        Color3.new(1, 0, 0), Color3.new(1, 0.5, 0), Color3.new(1, 1, 0), Color3.new(0, 1, 0),
        Color3.new(0, 1, 1), Color3.new(0, 0, 1), Color3.new(0.5, 0, 1),
    }
    local Grips = {
        Normal = CFrame.new(-1.5, 0, 0, 0, 0, -1, -1, 8.90154915e-005, 0, 8.90154915e-005, 1, 0),
        Flying = CFrame.new(-1.5, 0.5, -0.75, -1, 0, -8.99756625e-009, -8.99756625e-009, 8.10000031e-008, 1, 7.28802977e-016, 0.99999994, -8.10000103e-008),
    }
    local old = bp:FindFirstChild("Flying Carpet") or (player.Character and player.Character:FindFirstChild("Flying Carpet"))
    if old then old:Destroy() end

    local Tool = Instance.new("Tool")
    Tool.Name = "Flying Carpet"
    Tool.RequiresHandle = true
    Tool.CanBeDropped = false
    Tool.Grip = Grips.Normal
    Tool.TextureId = "rbxassetid://1014109561"

    local Handle = Instance.new("Part")
    Handle.Name = "Handle"; Handle.Size = CarpetSize
    Handle.Transparency = 1; Handle.CanCollide = false; Handle.Massless = true
    Handle.Parent = Tool

    local Roll = Instance.new("Part")
    Roll.Name = "Roll"; Roll.Size = CarpetSize
    Roll.CanCollide = false; Roll.Massless = true
    local RollMesh = Instance.new("SpecialMesh")
    RollMesh.MeshType = Enum.MeshType.FileMesh
    RollMesh.MeshId = BaseUrl .. "223079737"
    RollMesh.Scale = Vector3.new(1.125, 1.125, 1.125)
    RollMesh.TextureId = BaseUrl .. "1014108463"
    RollMesh.Parent = Roll
    local RollWeld = Instance.new("Weld")
    RollWeld.Part0 = Handle; RollWeld.Part1 = Roll; RollWeld.Parent = Roll
    Roll.Parent = Tool

    local SitR6 = Instance.new("Animation"); SitR6.AnimationId = "http://www.roblox.com/asset/?id=225279725"; SitR6.Parent = Tool
    local SitR15 = Instance.new("Animation"); SitR15.AnimationId = "rbxassetid://855828754"; SitR15.Parent = Tool

    local Flying, ToolEquipped, Cooldown = false, false, false
    local Character, Humanoid, Root
    local FlightSpin, FlightPower, FlightHold, AnimTrack, FlightConn
    local TrailFolder = Workspace:FindFirstChild("CarpetRainbow") or Instance.new("Folder")
    TrailFolder.Name = "CarpetRainbow"; TrailFolder.Parent = Workspace

    local function CheckIfAlive()
        return Character and Character.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0
            and Root and Root.Parent
    end
    local function CleanUpCarpet()
        for _, v in ipairs(Tool:GetChildren()) do
            if v:IsA("BasePart") and v ~= Handle and v.Name ~= "Roll" then v:Destroy() end
        end
    end
    local function BuildCarpet()
        local n = #CarpetPieces
        for i, v in ipairs(CarpetPieces) do
            local part = Instance.new("Part")
            part.Size = Vector3.new(CarpetSize.X, CarpetSize.Y, CarpetSize.Z / n)
            part.CanCollide = false; part.Massless = true
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. v.MeshId
            mesh.TextureId = BaseUrl .. "1014108463"
            mesh.Scale = Vector3.new(1.125, 1.125, 1.125)
            mesh.Parent = part
            local weld = Instance.new("Weld")
            weld.Part0 = Handle; weld.Part1 = part
            local xOff = ((i == 1 or i == n) and -0.005) or 0
            local zOff = (-((Handle.Size.Z / 2) - (part.Size.Z / 2))) + (part.Size.Z * (i - 1))
                + ((i == 2 and 0.245) or (i == 3 and 0.04) or (i == n and 0.28) or 0)
            weld.C1 = CFrame.new(0, xOff, zOff)
            weld.Parent = part
            part.Parent = Tool
        end
    end
    local function PlaySit()
        if not Humanoid then return end
        local anim = (Humanoid.RigType == Enum.HumanoidRigType.R15) and SitR15 or SitR6
        pcall(function()
            local animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid
            if AnimTrack then AnimTrack:Stop() end
            AnimTrack = animator:LoadAnimation(anim)
            AnimTrack:Play()
        end)
    end
    local function StopSit()
        if AnimTrack then pcall(function() AnimTrack:Stop() end); AnimTrack = nil end
    end
    local function CreateRainbow(lastPlace, currentPlace)
        local distance = (lastPlace - currentPlace).Magnitude
        if distance < 0.1 then return end
        local length = distance + 3.5
        local mid = CFrame.new(lastPlace + (currentPlace - lastPlace).Unit * (distance / 2), currentPlace)
        local model = Instance.new("Model")
        for i, color in ipairs(RainbowColors) do
            local p = Instance.new("Part")
            p.Anchored = true; p.CanCollide = false; p.Material = Enum.Material.SmoothPlastic
            p.BrickColor = BrickColor.new("Gold")
            p.Reflectance = 0.25; p.Transparency = 0.1
            p.Size = Vector3.new(0.5, 0.5, length)
            p.CFrame = mid * CFrame.new((i - 4) * 0.5, 0, 0)
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. "9856898"; mesh.TextureId = BaseUrl .. "1361097"
            mesh.Scale = p.Size * 2
            mesh.VertexColor = Vector3.new(239/255, 184/255, 56/255)
            mesh.Parent = p
            local light = Instance.new("PointLight")
            light.Brightness = 8; light.Range = 5; light.Color = color; light.Parent = p
            p.Parent = model
        end
        model.Parent = TrailFolder
        Debris:AddItem(model, 1)
    end
    local ControlsModule
    pcall(function()
        ControlsModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
    end)
    local function GetMoveVector()
        if ControlsModule then
            local ok, v = pcall(function() return ControlsModule:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then return v end
        end
        local md = Humanoid and Humanoid.MoveDirection or Vector3.zero
        local cf = Workspace.CurrentCamera.CFrame
        return Vector3.new(md:Dot(cf.RightVector), 0, -md:Dot(cf.LookVector))
    end
    local function StopFlying()
        Flying = false
        if FlightConn then FlightConn:Disconnect(); FlightConn = nil end
        for _, v in ipairs({ FlightSpin, FlightPower, FlightHold }) do
            if v and v.Parent then pcall(function() v:Destroy() end) end
        end
        FlightSpin, FlightPower, FlightHold = nil, nil, nil
        -- nuke any leftover movers that can freeze movement
        if Root then
            for _, ch in ipairs(Root:GetChildren()) do
                local n = ch.Name
                if n == "FlightSpin" or n == "FlightPower" or n == "FlightHold"
                    or ch:IsA("BodyVelocity") or ch:IsA("BodyPosition") or ch:IsA("BodyGyro") then
                    if n:find("Flight") or n == "FlightSpin" or n == "FlightPower" or n == "FlightHold" then
                        pcall(function() ch:Destroy() end)
                    end
                end
            end
        end
        if CheckIfAlive() then
            pcall(function()
                Root.AssemblyLinearVelocity = Vector3.zero
                Root.AssemblyAngularVelocity = Vector3.zero
            end)
            Humanoid.PlatformStand = false
            Humanoid.AutoRotate = true
            Humanoid.Sit = false
            if not speedEnabled then
                Humanoid.WalkSpeed = BASE_SPEED
            elseif Humanoid.WalkSpeed < 1 then
                Humanoid.WalkSpeed = BASE_SPEED
            end
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.defer(function()
                if Humanoid and Humanoid.Parent then
                    Humanoid.PlatformStand = false
                    if Humanoid.WalkSpeed < 1 then Humanoid.WalkSpeed = BASE_SPEED end
                end
            end)
        end
        StopSit(); Tool.Grip = Grips.Normal; CleanUpCarpet(); Roll.Transparency = 0
    end
    local function StartFlying()
        Flying = true; Roll.Transparency = 1; CleanUpCarpet(); BuildCarpet(); PlaySit()
        Tool.Grip = Grips.Flying
        FlightSpin = Instance.new("BodyGyro")
        FlightSpin.P = 1e6; FlightSpin.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        FlightSpin.CFrame = Root.CFrame; FlightSpin.Parent = Root
        FlightPower = Instance.new("BodyVelocity")
        FlightPower.Velocity = Vector3.zero; FlightPower.P = 10000
        FlightPower.MaxForce = Vector3.zero; FlightPower.Parent = Root
        FlightHold = Instance.new("BodyPosition")
        FlightHold.P = 1e5; FlightHold.MaxForce = Vector3.zero
        FlightHold.Position = Root.Position; FlightHold.Parent = Root
        Humanoid.WalkSpeed = 0; Humanoid.PlatformStand = false; Humanoid.AutoRotate = false
        Root.AssemblyLinearVelocity = Vector3.zero
        FlightConn = RunService.Heartbeat:Connect(function()
            if not (Flying and ToolEquipped and CheckIfAlive()) then StopFlying(); return end
            Humanoid.Jump = false
            local look = Workspace.CurrentCamera.CFrame.LookVector
            local right = Workspace.CurrentCamera.CFrame.RightVector
            local mv = GetMoveVector()
            local push = (look * (-mv.Z) * CameraSpeed.Z) + (right * mv.X * CameraSpeed.X)
            FlightSpin.CFrame = CFrame.new(Vector3.zero, look)
            if push.Magnitude < 1 then
                FlightHold.MaxForce = Vector3.new(FlightHold.P, FlightHold.P, FlightHold.P)
                FlightPower.MaxForce = Vector3.zero
                FlightHold.Position = Root.Position
            else
                FlightHold.MaxForce = Vector3.zero
                FlightPower.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            end
            FlightPower.Velocity = push
        end)
        task.spawn(function()
            local lastPlace
            while Flying and ToolEquipped and CheckIfAlive() do
                local current = Handle.Position
                local vel = Root.AssemblyLinearVelocity
                local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                if lastPlace and speed > 10 then
                    CreateRainbow(lastPlace, current); lastPlace = current
                elseif not lastPlace then
                    lastPlace = current
                end
                task.wait(Rate)
            end
        end)
    end
    Tool.Equipped:Connect(function()
        Character = Tool.Parent
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        Root = Character:FindFirstChild("HumanoidRootPart")
        ToolEquipped = true; Tool.Grip = Grips.Normal
    end)
    Tool.Unequipped:Connect(function()
        ToolEquipped = false
        if Flying then StopFlying() end
        Roll.Transparency = 0
    end)
    Tool.Activated:Connect(function()
        if Cooldown or not CheckIfAlive() then return end
        Cooldown = true
        if Flying then StopFlying() else StartFlying() end
        task.delay(2, function() Cooldown = false end)
    end)
    return Tool
end

local function createHairDryer()
    local TOOL_NAME = "HairDryer"
    local MESH_ID = "rbxassetid://11712365"
    local TEXTURE_ID = "rbxassetid://11712384"
    local ICON_ID = "rbxassetid://11716958"
    local SOUND_ID = "rbxassetid://9114743032"
    local POP_SOUND_ID = "rbxassetid://9125402946"
    local PUSH_BACK, PUSH_UP = 90, 110
    local PUSH_SPEED_MULT, PUSH_SMOOTH_IN = 0.45, 8
    local Colors = { "White", "Light stone grey", "Light blue", "Pastel Blue" }
    local Gravity = 196.2

    local bag = getBackpack and getBackpack() or bp
    local char0 = player.Character
    local old = (bag and bag:FindFirstChild(TOOL_NAME))
        or (char0 and char0:FindFirstChild(TOOL_NAME))
    if old then old:Destroy() end

    local Tool = Instance.new("Tool")
    Tool.Name = TOOL_NAME
    Tool.RequiresHandle = true
    Tool.CanBeDropped = false
    Tool.TextureId = ICON_ID
    Tool.Grip = CFrame.new(0.5, 0, -0.8) * CFrame.Angles(0, math.rad(90), math.rad(90))

    -- MeshPart like original (fallback to Part+SpecialMesh)
    local Handle
    local okMesh = pcall(function()
        Handle = Instance.new("MeshPart")
        Handle.Name = "Handle"
        Handle.Size = Vector3.new(1, 1, 1)
        Handle.Transparency = 0
        Handle.CanCollide = false
        Handle.MeshId = MESH_ID
        Handle.TextureID = TEXTURE_ID
        Handle.Parent = Tool
    end)
    if not okMesh or not Handle then
        Handle = Instance.new("Part")
        Handle.Name = "Handle"
        Handle.Size = Vector3.new(1, 1, 1)
        Handle.CanCollide = false
        Handle.Massless = true
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.FileMesh
        m.MeshId = MESH_ID
        m.TextureId = TEXTURE_ID
        m.Parent = Handle
        Handle.Parent = Tool
    end

    local DryerSound = Instance.new("Sound")
    DryerSound.Name = "DryerSound"
    DryerSound.SoundId = SOUND_ID
    DryerSound.Looped = true
    DryerSound.Volume = 1
    DryerSound.Parent = Handle

    local BasePart = Instance.new("Part")
    BasePart.Shape = Enum.PartType.Block
    BasePart.Material = Enum.Material.Plastic
    BasePart.Size = Vector3.new(0.2, 0.2, 0.2)
    BasePart.CanCollide = true
    BasePart.Anchored = false
    local AirBubble = BasePart:Clone()
    AirBubble.Name = "Effect"
    AirBubble.Shape = Enum.PartType.Ball
    AirBubble.Size = Vector3.new(1.4, 1.4, 1.4)
    AirBubble.CanCollide = false
    AirBubble.Massless = true
    AirBubble.CanQuery = false
    AirBubble.CanTouch = true

    local MouseDown, ToolEquipped = false, false
    local Character = player.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local pushBV, currentVel, targetVel = nil, Vector3.new(), Vector3.new()

    local function CheckIfAlive()
        return Character and Character.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0
    end

    -- old-style BodyVelocity push, but lower force + hard cleanup so move is not locked
    local function EnsurePushBV(root)
        if pushBV and pushBV.Parent == root then return pushBV end
        if pushBV then pcall(function() pushBV:Destroy() end) end
        pushBV = Instance.new("BodyVelocity")
        pushBV.Name = "DryerPush"
        pushBV.MaxForce = Vector3.new(4e4, 4e4, 4e4) -- not 1e7 (was locking move)
        pushBV.Velocity = Vector3.new()
        pushBV.Parent = root
        return pushBV
    end

    local function ApplyPush(Direction)
        if not CheckIfAlive() then return end
        local root = Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local backDir = Vector3.new(-Direction.X, 0, -Direction.Z)
        if backDir.Magnitude < 0.01 then
            backDir = Vector3.new()
        else
            backDir = backDir.Unit
        end
        targetVel = Vector3.new(
            backDir.X * PUSH_BACK * PUSH_SPEED_MULT,
            PUSH_UP * PUSH_SPEED_MULT,
            backDir.Z * PUSH_BACK * PUSH_SPEED_MULT
        )
        EnsurePushBV(root)
    end

    local function StopPush()
        targetVel = Vector3.new()
        currentVel = Vector3.new()
        if pushBV then pcall(function() pushBV:Destroy() end) pushBV = nil end
        local root = Character and Character:FindFirstChild("HumanoidRootPart")
        if root then
            for _, c in ipairs(root:GetChildren()) do
                if c.Name == "DryerPush" then pcall(function() c:Destroy() end) end
            end
        end
        if Humanoid then
            pcall(function()
                Humanoid.PlatformStand = false
                Humanoid.AutoRotate = true
                if Humanoid.WalkSpeed < 1 then Humanoid.WalkSpeed = BASE_SPEED end
            end)
        end
    end

    RunService.Heartbeat:Connect(function(dt)
        if not MouseDown then
            if pushBV then StopPush() end
            return
        end
        if not CheckIfAlive() then StopPush() return end
        local root = Character:FindFirstChild("HumanoidRootPart")
        if not root or not pushBV or pushBV.Parent ~= root then return end
        currentVel = currentVel:Lerp(targetVel, math.clamp(dt * PUSH_SMOOTH_IN, 0, 1))
        pushBV.Velocity = currentVel
    end)

    local function setupBubblePop(bubble)
        local popped = false
        local conn
        conn = bubble.Touched:Connect(function(hit)
            if popped then return end
            if not hit:IsA("BasePart") then return end
            if hit.Name == "Effect" then return end
            if Character and hit:IsDescendantOf(Character) then return end
            popped = true
            if conn then conn:Disconnect() end
            pcall(function()
                local pop = Instance.new("Sound")
                pop.SoundId = POP_SOUND_ID
                pop.Volume = 0.5
                pop.Parent = bubble
                pop:Play()
            end)
            task.spawn(function()
                for _ = 1, 5 do
                    if bubble and bubble.Parent then
                        bubble.Size = bubble.Size * 0.7
                        bubble.Transparency = math.min(1, bubble.Transparency + 0.2)
                    end
                    task.wait(0.02)
                end
                if bubble and bubble.Parent then bubble:Destroy() end
            end)
        end)
    end

    local function Fire(Direction)
        if not CheckIfAlive() then return end
        local SpawnPos = Handle.Position + (Direction * 7.5)
        local Force = 80
        local Air = AirBubble:Clone()
        Air.Transparency = math.random() * 0.5
        Air.CFrame = CFrame.new(SpawnPos, SpawnPos + Direction)
        pcall(function() Air.AssemblyLinearVelocity = Direction * Force end)
        Air.BrickColor = BrickColor.new(Colors[math.random(1, #Colors)])
        local Mass = Air:GetMass() * Gravity
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(Mass, Mass, Mass)
        bv.Velocity = Direction * Force
        bv.Parent = Air
        local Creator = Instance.new("ObjectValue")
        Creator.Name = "Creator"
        Creator.Value = player
        Creator.Parent = Air
        setupBubblePop(Air)
        Debris:AddItem(Air, 2.4)
        Air.Parent = Workspace
        -- after a short flight, scatter sideways so bubbles fan out
        task.delay(0.28 + math.random() * 0.12, function()
            if not Air or not Air.Parent then return end
            local side = Vector3.new(math.random() - 0.5, math.random() * 0.4, math.random() - 0.5)
            if side.Magnitude > 0.01 then side = side.Unit end
            local spread = 35 + math.random() * 45
            local newV = Direction * (Force * 0.55) + side * spread
            if bv and bv.Parent then bv.Velocity = newV end
            pcall(function() Air.AssemblyLinearVelocity = newV end)
        end)
    end

    local function GetTargetPosition()
        local camera = Workspace.CurrentCamera
        if not camera then return nil end
        if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
            return camera.CFrame.Position + (camera.CFrame.LookVector * 100)
        end
        local mouse = player:GetMouse()
        if mouse and mouse.Hit then return mouse.Hit.Position end
        local ray = camera:ScreenPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        local params = RaycastParams.new()
        if Character then params.FilterDescendantsInstances = { Character, Tool } end
        params.FilterType = Enum.RaycastFilterType.Exclude
        local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
        return result and result.Position or (ray.Origin + ray.Direction * 50)
    end

    local function StartFiring()
        if MouseDown or not ToolEquipped then return end
        MouseDown = true
        task.spawn(function()
            pcall(function() DryerSound:Play() end)
            local Rate = 1 / 60
            while MouseDown and ToolEquipped and CheckIfAlive() do
                local TargetPos = GetTargetPosition()
                if TargetPos then
                    task.spawn(function()
                        for _ = 1, 1 do
                            if ToolEquipped and MouseDown then
                                local Direction = (TargetPos - Handle.Position)
                                if Direction.Magnitude > 0.05 then
                                    Direction = Direction.Unit
                                    local Offset = Vector3.new(
                                        (math.random() - 0.5) * 0.3,
                                        (math.random() - 0.5) * 0.3,
                                        (math.random() - 0.5) * 0.3
                                    )
                                    Fire((Direction + Offset).Unit)
                                end
                                task.wait(0.1)
                            end
                        end
                    end)
                    local pushDir = (TargetPos - Handle.Position)
                    if pushDir.Magnitude > 0.05 then
                        ApplyPush(pushDir.Unit)
                    end
                end
                task.wait(Rate)
            end
            pcall(function() DryerSound:Stop() end)
        end)
    end

    local function StopFiring()
        MouseDown = false
        StopPush()
    end

    Tool.Equipped:Connect(function()
        Character = Tool.Parent
        Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        if not CheckIfAlive() then return end
        ToolEquipped = true
    end)

    Tool.Unequipped:Connect(function()
        MouseDown = false
        ToolEquipped = false
        pcall(function() DryerSound:Stop() end)
        StopPush()
    end)

    -- PC + mobile hold (only while this tool equipped)
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or not ToolEquipped then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            StartFiring()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if not ToolEquipped then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            StopFiring()
        end
    end)
    pcall(function()
        ContextActionService:BindAction("CNP_HairDryer_" .. tostring(Tool), function(_, state)
            if not ToolEquipped then return Enum.ContextActionResult.Pass end
            if state == Enum.UserInputState.Begin then StartFiring()
            elseif state == Enum.UserInputState.End then StopFiring() end
            return Enum.ContextActionResult.Sink
        end, false, Enum.KeyCode.ButtonR2)
    end)

    return Tool
end

local function createWaterBow()
    local t = Instance.new("Tool")
    t.Name = "WaterBow"
    t.RequiresHandle = true
    t.CanBeDropped = false
    t.TextureId = "rbxassetid://235108271"
    local h = Instance.new("Part")
    h.Name = "Handle"
    h.Size = Vector3.new(1, 1, 1)
    h.CanCollide = false
    h.Massless = true
    local wm = Instance.new("SpecialMesh")
    wm.MeshType = Enum.MeshType.FileMesh
    wm.MeshId = "rbxassetid://235107551"
    wm.TextureId = "rbxassetid://235107780"
    wm.Scale = Vector3.new(1, 1, 1)
    wm.Parent = h
    h.Parent = t
    t.Grip = CFrame.new(0, -0.2, 0.5) * CFrame.Angles(0, math.rad(20), 0)
    return t
end

local WATER_RADIUS, WATER_HEIGHT = 12, 9
local JUMP_COOLDOWN, CLICK_COOLDOWN = 0.5, 1
local lastJumpTime, launching, lastWaterClick = 0, false, 0
local currentWater, touchStartPos = nil, nil

local function SpawnWaterBlock()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if currentWater and currentWater.cleanup then currentWater.cleanup() end
    local center = Vector3.new(root.Position.X, root.Position.Y - 2, root.Position.Z)
    Workspace.Terrain:FillBall(center, WATER_RADIUS, Enum.Material.Water)
    currentWater = {
        center = center,
        radius = WATER_RADIUS,
        topY = center.Y + WATER_HEIGHT / 2,
        bottomY = center.Y - WATER_HEIGHT / 2,
    }
    currentWater.cleanup = function()
        pcall(function() Workspace.Terrain:FillBall(center, WATER_RADIUS, Enum.Material.Air) end)
        currentWater = nil
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local char = player.Character
    if not char or not char:FindFirstChild("WaterBow") then return end
    if input.UserInputType == Enum.UserInputType.Touch then
        touchStartPos = input.Position
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        if tick() - lastWaterClick > CLICK_COOLDOWN then
            lastWaterClick = tick()
            SpawnWaterBlock()
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    local char = player.Character
    if not char or not char:FindFirstChild("WaterBow") then return end
    if input.UserInputType == Enum.UserInputType.Touch and touchStartPos then
        local d = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(touchStartPos.X, touchStartPos.Y)).Magnitude
        if d < 15 and tick() - lastWaterClick > CLICK_COOLDOWN then
            lastWaterClick = tick()
            SpawnWaterBlock()
        end
        touchStartPos = nil
    end
end)

local function launchOut()
    if launching or tick() - lastJumpTime < JUMP_COOLDOWN or not currentWater then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    local p, w = root.Position, currentWater
    local dx, dz = p.X - w.center.X, p.Z - w.center.Z
    local dist = math.sqrt(dx * dx + dz * dz)
    if not (dist <= w.radius and p.Y < w.topY and p.Y > w.bottomY - 20) then return end
    local depthY = math.clamp(p.Y, w.bottomY, w.topY)
    local depthRatio = math.clamp((w.topY - depthY) / math.max(w.topY - w.bottomY, 0.01), 0, 1)
    -- higher launch: base 130 surface, deeper up to ~210
    local power = 130 + (90 * depthRatio)
    power = math.clamp(power, 130, 210)
    launching = true
    lastJumpTime = tick()
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Freefall) end)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(0, math.huge, 0) -- only vertical — less fling
    bv.Velocity = Vector3.new(0, power, 0)
    bv.Parent = root
    task.delay(0.15, function() if bv then bv:Destroy() end end)
    task.delay(JUMP_COOLDOWN, function() launching = false end)
end

pcall(function()
    ContextActionService:BindActionAtPriority("WaterLaunch", function(_, state)
        if state == Enum.UserInputState.Begin then launchOut() end
        return Enum.ContextActionResult.Pass
    end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end)

task.spawn(function()
    for _ = 1, 20 do
        local tg = pg:FindFirstChild("TouchGui")
        local jb = tg and tg:FindFirstChild("JumpButton", true)
        if jb and not jb:GetAttribute("CNP_WaterHook") then
            jb:SetAttribute("CNP_WaterHook", true)
            jb.MouseButton1Down:Connect(launchOut)
        end
        task.wait(0.5)
    end
end)

local function getBackpack()
    local bag = player:FindFirstChildOfClass("Backpack")
    if bag then return bag end
    local ok, b = pcall(function() return player:WaitForChild("Backpack", 3) end)
    if ok then return b end
    return nil
end



-- ===== COILS (Speed / Gravity / DualGravity) =====
local COIL_DEFAULT_SPEED = BASE_SPEED
local DUAL_GRAVITY_LOCKED_OFFSET = CFrame.new(-0.3, -1.45, 0.28) -- Y up a bit, Z forward a bit
local coilLoopConn = nil
local coilGravityMult = 1
-- coilActiveSpeed / coilSpeedBoost are outer-scope (STATE)
coilActiveSpeed = COIL_DEFAULT_SPEED
coilSpeedBoost = false
local coilForce = nil
local coilAttachment = nil
local coilWeld = nil

local COIL_CONFIGS = {
    {
        Name = "SpeedCoil",
        TextureId = "rbxassetid://99170415",
        MeshId = "rbxassetid://16606212",
        SkinTextureId = "rbxassetid://99170547",
        SoundId = "rbxassetid://99173388",
        Color = Color3.fromRGB(255, 60, 60),
        WalkSpeed = 34,
        GravityMultiplier = 1,
        Scale = 0.6,
    },
    {
        Name = "GravityCoil",
        TextureId = "rbxassetid://16619617",
        MeshId = "rbxassetid://16606212",
        SkinTextureId = "rbxassetid://16606141",
        SoundId = "rbxassetid://16619553",
        Color = Color3.fromRGB(80, 170, 255),
        WalkSpeed = COIL_DEFAULT_SPEED,
        GravityMultiplier = 0.25,
        Scale = 0.6,
    },
    {
        Name = "DualGravityCoil",
        TextureId = "rbxassetid://150063217",
        MeshId = "rbxassetid://150063131",
        SkinTextureId = "rbxassetid://150063177",
        SoundId = "rbxassetid://16619553",
        Color = Color3.fromRGB(120, 210, 255),
        WalkSpeed = COIL_DEFAULT_SPEED,
        GravityMultiplier = 0.15,
        Scale = 1.35,
        AtFootPositionLockPose = true,
    },
}

local function clearCoilWeld()
    if coilWeld then
        pcall(function() coilWeld:Destroy() end)
        coilWeld = nil
    end
end

local function clearCoilGravityForce()
    if coilForce then
        pcall(function() coilForce:Destroy() end)
        coilForce = nil
    end
    if coilAttachment then
        pcall(function() coilAttachment:Destroy() end)
        coilAttachment = nil
    end
end

local function placeCoilAtFootLockedPose(char, hum, root, handle)
    clearCoilWeld()
    if not char or not hum or not root or not handle then return end
    local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
    if rightHand then
        local grip = rightHand:FindFirstChild("RightGrip")
        if grip then pcall(function() grip:Destroy() end) end
    end
    handle.Anchored = false
    handle.CanCollide = false
    handle.Massless = true
    handle.CFrame = root.CFrame * DUAL_GRAVITY_LOCKED_OFFSET
    local weld = Instance.new("Weld")
    weld.Name = "DualGravityLockedFootWeld"
    weld.Part0 = root
    weld.Part1 = handle
    weld.C0 = DUAL_GRAVITY_LOCKED_OFFSET
    weld.C1 = CFrame.new()
    weld.Parent = handle
    coilWeld = weld
end

local function ensureCoilGravityForce(root)
    if not root then return end
    if not coilAttachment or not coilAttachment.Parent then
        coilAttachment = Instance.new("Attachment")
        coilAttachment.Name = "CoilGravityAttachment"
        coilAttachment.Parent = root
    end
    if not coilForce or not coilForce.Parent then
        coilForce = Instance.new("VectorForce")
        coilForce.Name = "CoilGravityForce"
        coilForce.Attachment0 = coilAttachment
        coilForce.RelativeTo = Enum.ActuatorRelativeTo.World
        coilForce.ApplyAtCenterOfMass = true
        coilForce.Parent = root
    end
    coilForce.Attachment0 = coilAttachment
end

local function stopCoilEffect()
    if coilLoopConn then
        coilLoopConn:Disconnect()
        coilLoopConn = nil
    end
    coilGravityMult = 1
    coilActiveSpeed = COIL_DEFAULT_SPEED
    coilSpeedBoost = false
    clearCoilGravityForce()
    clearCoilWeld()
    local c = player.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hum and not speedEnabled and hum.WalkSpeed ~= BASE_SPEED then
        pcall(function() hum.WalkSpeed = BASE_SPEED end)
    end
end

local function startCoilEffect(cfg, tool)
    stopCoilEffect()
    coilActiveSpeed = cfg.WalkSpeed or COIL_DEFAULT_SPEED
    coilGravityMult = cfg.GravityMultiplier or 1
    -- SpeedCoil must work even when CNP speed is off (speed system was clamping to 16)
    coilSpeedBoost = (coilActiveSpeed > COIL_DEFAULT_SPEED + 0.5)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local handle = tool and tool:FindFirstChild("Handle")
    if hum and coilSpeedBoost then
        pcall(function() hum.WalkSpeed = coilActiveSpeed end)
    end
    if cfg.AtFootPositionLockPose and char and hum and root and handle then
        task.defer(function()
            if tool.Parent == char then
                placeCoilAtFootLockedPose(char, hum, root, handle)
            end
        end)
    end
    coilLoopConn = RunService.Heartbeat:Connect(function()
        local c = player.Character
        local curHum = c and c:FindFirstChildOfClass("Humanoid")
        local curRoot = c and c:FindFirstChild("HumanoidRootPart")
        if not curHum or curHum.Health <= 0 or not curRoot then
            clearCoilGravityForce()
            return
        end
        -- always keep SpeedCoil walk speed (CNP air-speed only overrides while in air + speedOk)
        if coilSpeedBoost and coilActiveSpeed and coilActiveSpeed > BASE_SPEED + 0.5 then
            local st = curHum:GetState()
            local inAir = st == Enum.HumanoidStateType.Jumping
                or st == Enum.HumanoidStateType.Freefall
                or st == Enum.HumanoidStateType.FallingDown
            -- on ground, or CNP speed off: force coil speed
            if (not speedEnabled) or (not inAir) then
                if math.abs(curHum.WalkSpeed - coilActiveSpeed) > 0.25 then
                    curHum.WalkSpeed = coilActiveSpeed
                end
            end
        end
        if cfg.AtFootPositionLockPose and handle and (not coilWeld or not coilWeld.Parent) and tool.Parent == c then
            placeCoilAtFootLockedPose(c, curHum, curRoot, handle)
        end
        if coilGravityMult < 1 then
            ensureCoilGravityForce(curRoot)
            local mass = curRoot.AssemblyMass
            local liftY = mass * Workspace.Gravity * (1 - coilGravityMult)
            coilForce.Force = Vector3.new(0, liftY, 0)
        else
            clearCoilGravityForce()
        end
    end)
end

local function createCoilTool(cfg)
    local bag = getBackpack and getBackpack() or bp
    local char0 = player.Character
    local old = (bag and bag:FindFirstChild(cfg.Name))
        or (char0 and char0:FindFirstChild(cfg.Name))
    if old then old:Destroy() end

    local scale = cfg.Scale or 1
    local tool = Instance.new("Tool")
    tool.Name = cfg.Name
    tool.TextureId = cfg.TextureId
    tool.RequiresHandle = true
    tool.CanBeDropped = false

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1.5 * scale, 1.5 * scale, 1.5 * scale)
    handle.Color = cfg.Color
    handle.Material = Enum.Material.SmoothPlastic
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = cfg.MeshId
    mesh.TextureId = cfg.SkinTextureId
    mesh.Scale = Vector3.new(scale, scale, scale)
    mesh.Parent = handle

    local sound = Instance.new("Sound")
    sound.Name = "EquipSound"
    sound.SoundId = cfg.SoundId
    sound.Volume = 1
    sound.Parent = handle

    tool.Equipped:Connect(function()
        pcall(function() sound:Play() end)
        startCoilEffect(cfg, tool)
    end)
    tool.Unequipped:Connect(function()
        stopCoilEffect()
    end)
    tool.Destroying:Connect(function()
        stopCoilEffect()
    end)

    return tool
end

local function createSpeedCoil()
    return createCoilTool(COIL_CONFIGS[1])
end

-- Watch tools so Gears Mmv Speed Coil also sets coilSpeedBoost (external panel)
do
    local function onTool(tool)
        if not tool or not tool:IsA("Tool") then return end
        if tool:GetAttribute("CNP_SpeedCoilHook") then return end
        local n = string.lower(tool.Name or "")
        local ct = nil
        pcall(function() ct = tool:GetAttribute("CoilType") end)
        local isSpeed = (ct == "Speed") or n == "speedcoil" or n == "speed coil"
            or (n == "zoewar coil" and ct == "Speed")
        if not isSpeed then return end
        tool:SetAttribute("CNP_SpeedCoilHook", true)
        tool.Equipped:Connect(function()
            coilActiveSpeed = 32
            if n == "speedcoil" or n == "speed coil" then coilActiveSpeed = 34 end
            coilSpeedBoost = true
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.WalkSpeed = coilActiveSpeed end) end
        end)
        tool.Unequipped:Connect(function()
            -- only clear if no other speed coil still out
            local char = player.Character
            local still = false
            if char then
                for _, t in ipairs(char:GetChildren()) do
                    if t:IsA("Tool") and t ~= tool then
                        local nn = string.lower(t.Name or "")
                        local ctt = nil
                        pcall(function() ctt = t:GetAttribute("CoilType") end)
                        if ctt == "Speed" or nn == "speedcoil" or nn == "speed coil" then
                            still = true
                            break
                        end
                    end
                end
            end
            if not still then
                coilSpeedBoost = false
                coilActiveSpeed = COIL_DEFAULT_SPEED
                if not speedEnabled then
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum then pcall(function() hum.WalkSpeed = BASE_SPEED end) end
                end
            end
        end)
    end
    local function scanBag(bag)
        if not bag then return end
        for _, t in ipairs(bag:GetChildren()) do
            if t:IsA("Tool") then onTool(t) end
        end
        bag.ChildAdded:Connect(function(ch)
            if ch:IsA("Tool") then onTool(ch) end
        end)
    end
    task.spawn(function()
        local bag = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
        scanBag(bag)
        player.CharacterAdded:Connect(function(char)
            task.wait(0.3)
            scanBag(player:FindFirstChildOfClass("Backpack"))
            for _, t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") then onTool(t) end
            end
            char.ChildAdded:Connect(function(ch)
                if ch:IsA("Tool") then onTool(ch) end
            end)
        end)
        if player.Character then
            for _, t in ipairs(player.Character:GetChildren()) do
                if t:IsA("Tool") then onTool(t) end
            end
            player.Character.ChildAdded:Connect(function(ch)
                if ch:IsA("Tool") then onTool(ch) end
            end)
        end
    end)
end

local function createGravityCoil()
    return createCoilTool(COIL_CONFIGS[2])
end
local function createDualGravityCoil()
    return createCoilTool(COIL_CONFIGS[3])
end

local function createBombSphere()
    local LIFT_SPEED = 55
    local bag = getBackpack and getBackpack() or bp
    local char0 = player.Character
    local old = (bag and bag:FindFirstChild("bomb"))
        or (char0 and char0:FindFirstChild("bomb"))
    if old then old:Destroy() end

    local tool = Instance.new("Tool")
    tool.Name = "bomb"
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.Grip = CFrame.new(0, -0.2, 0.2)

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Shape = Enum.PartType.Ball
    handle.Size = Vector3.new(1.5, 1.5, 1.5)
    handle.Color = Color3.fromRGB(15, 15, 15)
    handle.Material = Enum.Material.SmoothPlastic
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool

    local liftConnection = nil
    local bodyVelocity = nil

    local function stopLift()
        if liftConnection then
            liftConnection:Disconnect()
            liftConnection = nil
        end
        if bodyVelocity then
            pcall(function() bodyVelocity:Destroy() end)
            bodyVelocity = nil
        end
        -- clear leftover on HRP
        local c = player.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("SphereLiftVelocity")
            if bv then pcall(function() bv:Destroy() end) end
        end
    end

    tool.Equipped:Connect(function()
        stopLift()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid or humanoid.Health <= 0 then return end

        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "SphereLiftVelocity"
        bodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
        bodyVelocity.Velocity = Vector3.new(0, LIFT_SPEED, 0)
        bodyVelocity.Parent = hrp

        liftConnection = RunService.Heartbeat:Connect(function()
            if not tool.Parent or tool.Parent ~= char then
                stopLift()
                return
            end
            if humanoid.Health <= 0 then
                stopLift()
                return
            end
            if bodyVelocity and bodyVelocity.Parent then
                bodyVelocity.Velocity = Vector3.new(0, LIFT_SPEED, 0)
            end
        end)
    end)

    tool.Unequipped:Connect(stopLift)
    tool.Destroying:Connect(stopLift)

    return tool
end

local function handleGetTool(name, createFn)
    -- always refresh backpack (respawn replaces the old one)
    local bag = getBackpack()
    if not bag then
        warn("[gear] no backpack")
        return
    end
    bp = bag -- keep global ref fresh

    local t = bag:FindFirstChild(name)
    if not t then
        local c = player.Character
        if c then t = c:FindFirstChild(name) end
    end
    if t then
        if t.Parent ~= bag then
            local ok, err = pcall(function() t.Parent = bag end)
            if not ok then warn("[gear] move failed: ", err) end
        end
        print("[gear] already have " .. name)
        return
    end

    local ok, result = pcall(createFn)
    if not ok then
        warn("[gear] create failed (" .. name .. "): ", result)
        return
    end
    t = result
    if not t then
        warn("[gear] create returned nil: " .. name)
        return
    end
    local ok2, err2 = pcall(function() t.Parent = bag end)
    if not ok2 then
        warn("[gear] parent failed: ", err2)
        return
    end
    print("[gear] got " .. name)
end

local addedGearOff = {} -- gears from Gears Mmv file: name -> { off = fn, tools = {tool=true} }

local function destroyAllCoils()
    for k, e in pairs(addedGearOff) do
        addedGearOff[k] = nil
        if e.off then pcall(e.off) end
        for t in pairs(e.tools) do
            if t and t.Parent then pcall(function() t:Destroy() end) end
        end
    end
    local c = player.Character
    local hm = c and c:FindFirstChildOfClass("Humanoid")
    if hm then pcall(function() hm:UnequipTools() end) end
    do
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if root then
            for _, ch in ipairs(root:GetChildren()) do
                if ch.Name == "DryerPush" then ch:Destroy() end
            end
        end
    end
    pcall(function() stopCoilEffect() end)
    for _, n in ipairs({ "Rainbow Carpet", "Blood Carpet", "Cinnamoroll Carpet", "Flying Carpet", "HairDryer", "WaterBow", "bomb", "SpeedCoil", "GravityCoil", "DualGravityCoil" }) do
        local a = c and c:FindFirstChild(n)
        if a then a:Destroy() end
        local btool = bp:FindFirstChild(n)
        if btool then btool:Destroy() end
    end
    if hm and not speedEnabled then
        pcall(function() hm.WalkSpeed = BASE_SPEED end)
    end
    if currentWater and currentWater.cleanup then currentWater.cleanup() end
end

-- ===== KEY PANEL =====
local keyGui = Instance.new("ScreenGui")
keyGui.Name = "CNP_KeyGate"
keyGui.ResetOnSpawn = false
keyGui.DisplayOrder = 2147483646
keyGui.IgnoreGuiInset = true
keyGui.Enabled = false -- key system removed
pcall(function() keyGui.Parent = game:GetService("CoreGui") end)
if not keyGui.Parent then keyGui.Parent = pg end

local dim = Instance.new("Frame", keyGui)
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(20, 12, 18)
dim.BackgroundTransparency = 0.45
dim.BorderSizePixel = 0
dim.Active = true

local card = Instance.new("Frame", keyGui)
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(isMobile and 300 or 340, 210)
card.BackgroundColor3 = Color3.fromRGB(232, 244, 252)
card.BorderSizePixel = 0
card.Active = true
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)
do
    local st = Instance.new("UIStroke", card)
    st.Color = Color3.fromRGB(255, 160, 195)
    st.Thickness = 1.5
    st.Transparency = 0.2
end

local keyTitle = Instance.new("TextLabel", card)
keyTitle.BackgroundTransparency = 1
keyTitle.Position = UDim2.fromOffset(0, 16)
keyTitle.Size = UDim2.new(1, 0, 0, 26)
keyTitle.Font = UI.titleFont
keyTitle.TextSize = 20
keyTitle.TextColor3 = Color3.fromRGB(40, 100, 150)
keyTitle.Text = "Advanced Unlock"
keyTitle.ZIndex = 2

local keySub = Instance.new("TextLabel", card)
keySub.BackgroundTransparency = 1
keySub.Position = UDim2.fromOffset(18, 44)
keySub.Size = UDim2.new(1, -36, 0, 18)
keySub.Font = UI.font
keySub.TextSize = 12
keySub.TextColor3 = Color3.fromRGB(170, 130, 150)
keySub.TextXAlignment = Enum.TextXAlignment.Left
keySub.Text = "enter key to use CNP panel"
keySub.ZIndex = 2

local boxHold = Instance.new("Frame", card)
boxHold.Position = UDim2.fromOffset(18, 78)
boxHold.Size = UDim2.new(1, -36, 0, 40)
boxHold.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
boxHold.BackgroundTransparency = 0.15
boxHold.BorderSizePixel = 0
boxHold.ZIndex = 2
Instance.new("UICorner", boxHold).CornerRadius = UDim.new(0, 10)

local keyBox = Instance.new("TextBox", boxHold)
keyBox.BackgroundTransparency = 1
keyBox.Size = UDim2.new(1, -16, 1, 0)
keyBox.Position = UDim2.fromOffset(8, 0)
keyBox.Font = UI.font
keyBox.TextSize = 13
keyBox.TextColor3 = Color3.fromRGB(90, 50, 70)
keyBox.PlaceholderColor3 = Color3.fromRGB(190, 160, 175)
keyBox.PlaceholderText = "Enter you key ( Buy with Robux or MM2 Godlys )"
keyBox.Text = ""
keyBox.ClearTextOnFocus = false
keyBox.TextXAlignment = Enum.TextXAlignment.Left
keyBox.ZIndex = 3

local unlockBtn = Instance.new("TextButton", card)
unlockBtn.Position = UDim2.fromOffset(18, 136)
unlockBtn.Size = UDim2.new(1, -36, 0, 40)
unlockBtn.BackgroundColor3 = Color3.fromRGB(70, 150, 210)
unlockBtn.BorderSizePixel = 0
unlockBtn.Font = UI.titleFont
unlockBtn.TextSize = 16
unlockBtn.TextColor3 = Color3.new(1, 1, 1)
unlockBtn.Text = "unlock"
unlockBtn.AutoButtonColor = false
unlockBtn.ZIndex = 2
Instance.new("UICorner", unlockBtn).CornerRadius = UDim.new(0, 10)

local closeKey = Instance.new("TextButton", card)
closeKey.Position = UDim2.new(1, -32, 0, 8)
closeKey.Size = UDim2.fromOffset(24, 24)
closeKey.BackgroundTransparency = 1
closeKey.Font = UI.font
closeKey.TextSize = 18
closeKey.TextColor3 = Color3.fromRGB(200, 150, 170)
closeKey.Text = "x"
closeKey.ZIndex = 3

local function closeKeyPanel()
    -- key system removed
end

local function openKeyPanel()
    -- key system removed
end

-- không đóng khi bấm ra ngoài / nút x — chỉ đóng khi nhập đúng hoặc sai key
closeKey.Visible = false
dim.Active = true

-- ===== GEAR PANEL =====
local gearGui = Instance.new("ScreenGui")
gearGui.Name = "CNP_GearPanel"
gearGui.ResetOnSpawn = false
gearGui.DisplayOrder = 2147483645
gearGui.Enabled = false
gearGui.IgnoreGuiInset = true
gearGui.DisplayOrder = 2147483645
pcall(function() gearGui.Parent = game:GetService("CoreGui") end)
if not gearGui.Parent then gearGui.Parent = pg end

local gearFrame = Instance.new("Frame", gearGui)
do
    local gw = fitW(isMobile and 270 or 300)
    local gh = fitH(isMobile and 380 or 420)
    gearFrame.Size = UDim2.fromOffset(gw, gh)
    gearFrame.Position = UDim2.new(0.5, -gw / 2, 0.5, -gh / 2)
end
gearFrame.BackgroundColor3 = UI.bg
gearFrame.BorderSizePixel = 0
gearFrame.Active = true
gearFrame.ClipsDescendants = true
pcall(function() gearFrame.Modal = false end)
pcall(function() applyGlass(gearFrame, 0.12) end)
Instance.new("UICorner", gearFrame).CornerRadius = UDim.new(0, 14)
do
    local st = Instance.new("UIStroke", gearFrame)
    st.Color = Color3.fromRGB(255, 255, 255)
    st.Thickness = 2
    st.Transparency = 0.05
    local sg = Instance.new("UIGradient", st)
    sg.Rotation = 45
    sg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(215, 50, 60)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 170, 95)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 50, 60)),
    })
end

local gearTop = Instance.new("TextLabel", gearFrame)
gearTop.Size = UDim2.new(1, -40, 0, 36)
gearTop.BackgroundTransparency = 1
gearTop.Active = true
gearTop.Text = "Gear"
gearTop.TextColor3 = Color3.fromRGB(255, 110, 120)
gearTop.Font = UI.titleFont
gearTop.TextSize = 20
gearTop.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UIPadding", gearTop).PaddingLeft = UDim.new(0, 14)
makeDraggable(gearFrame, gearTop)

local gearClose = Instance.new("TextButton", gearFrame)
gearClose.Size = UDim2.fromOffset(26, 26)
gearClose.Position = UDim2.new(1, -30, 0, 5)
gearClose.BackgroundTransparency = 1
gearClose.Text = "x"
gearClose.TextColor3 = UI.dim
gearClose.Font = UI.font
gearClose.TextSize = 18
gearClose.BorderSizePixel = 0
local function closeGearPanel()
    gearGui.Enabled = false
    -- never force MouseBehavior here (keeps PC camera free / shiftlock intact)
end
gearClose.Activated:Connect(closeGearPanel)

do
    local ln = Instance.new("Frame", gearFrame)
    ln.Size = UDim2.new(1, -24, 0, 1)
    ln.Position = UDim2.new(0, 12, 0, 36)
    ln.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ln.BackgroundTransparency = 0.15
    ln.BorderSizePixel = 0
    local lg = Instance.new("UIGradient", ln)
    lg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(215, 50, 60)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 170, 95)),
    })
end

local gearScroll = Instance.new("ScrollingFrame", gearFrame)
gearScroll.Size = UDim2.new(1, -14, 1, -46)
gearScroll.Position = UDim2.new(0, 7, 0, 41)
gearScroll.BackgroundTransparency = 1
gearScroll.BorderSizePixel = 0
gearScroll.ScrollBarThickness = 3
gearScroll.ScrollBarImageColor3 = UI.line
gearScroll.CanvasSize = UDim2.new()
gearScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
gearScroll.ScrollingDirection = Enum.ScrollingDirection.Y
do
    local lay = Instance.new("UIListLayout", gearScroll)
    lay.Padding = UDim.new(0, 5)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
end

-- christmas snow (same as main panel)
do
    local decor = Instance.new("Frame")
    decor.Name = "Decor"
    decor.Size = UDim2.fromScale(1, 1)
    decor.BackgroundTransparency = 1
    decor.BorderSizePixel = 0
    decor.ClipsDescendants = true
    decor.ZIndex = 8
    decor.Active = false
    decor.Parent = gearFrame

    local rng = Random.new()
    local flakes = {}
    local SNOW_IMG = "rbxassetid://15216668864"
    local N = isMobile and 12 or 18
    for i = 1, N do
        local f = Instance.new("ImageLabel")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ZIndex = 8
        f.Active = false
        f.Image = SNOW_IMG
        f.ScaleType = Enum.ScaleType.Fit
        f.ImageTransparency = rng:NextNumber(0.3, 0.65)
        f.Parent = decor
        local w = rng:NextInteger(8, 16)
        local h = math.max(7, math.floor(w * rng:NextNumber(0.7, 1.05)))
        f.Size = UDim2.fromOffset(w, h)
        local x0 = rng:NextNumber(0.04, 0.96)
        local y0 = -40 - (i % 12) * 28
        f.Position = UDim2.new(x0, 0, 0, y0)
        flakes[i] = {
            f = f, x0 = x0, y = y0,
            speed = rng:NextNumber(28, 70),
            amp = rng:NextNumber(0.008, 0.03),
            freq = rng:NextNumber(0.5, 1.6),
            phase = rng:NextNumber(0, 6.28),
            rot = rng:NextNumber(-20, 20),
            rotSpeed = rng:NextNumber(-30, 30),
        }
    end
    local t0 = 0
    task.spawn(function()
        while decor.Parent do
            local dt = task.wait(isMobile and 0.04 or 0.03)
            if gearGui.Enabled then
                local hgt = gearFrame.AbsoluteSize.Y
                if hgt < 40 then hgt = 420 end
                dt = math.clamp(dt, 0, 0.05)
                t0 = t0 + dt
                for _, p in ipairs(flakes) do
                    p.y = p.y + p.speed * dt
                    if p.y > hgt + 20 then
                        p.y = -rng:NextNumber(10, 50)
                        p.x0 = rng:NextNumber(0.04, 0.96)
                        p.speed = rng:NextNumber(28, 70)
                    end
                    p.rot = p.rot + p.rotSpeed * dt
                    p.f.Position = UDim2.new(p.x0 + math.sin(t0 * p.freq + p.phase) * p.amp, 0, 0, p.y)
                    p.f.Rotation = p.rot
                end
            end
        end
    end)
end

-- original gears
UI.action(gearScroll, 1, "rainbow carpet", function()
    handleGetTool("Rainbow Carpet", createRainbowCarpet)
end)
UI.action(gearScroll, 2, "blood carpet", function()
    handleGetTool("Blood Carpet", createBloodCarpet)
end)
UI.action(gearScroll, 3, "cinnamoroll carpet", function()
    handleGetTool("Cinnamoroll Carpet", createCinnaCarpet)
end)
UI.action(gearScroll, 4, "hair dryer", function()
    handleGetTool("HairDryer", createHairDryer)
end)

-- gears from Gears Mmv file
local function installAddedGears(gearScroll, startOrder)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local player = Players.LocalPlayer
    local states = { ["GRAVITY COIL"] = true, ["SPEED COIL"] = true }
    local COIL_MESH_ID = "rbxassetid://16606212"

    local function findCoil(coilType)
        local bag = player:FindFirstChild("Backpack")
        if bag then
            for _, item in ipairs(bag:GetChildren()) do
                if item:IsA("Tool") and item:GetAttribute("CoilType") == coilType then return item end
            end
        end
        if player.Character then
            for _, item in ipairs(player.Character:GetChildren()) do
                if item:IsA("Tool") and item:GetAttribute("CoilType") == coilType then return item end
            end
        end
        return nil
    end

    local function destroyCoilsOfType(coilType)
        local bag = player:FindFirstChild("Backpack")
        if bag then
            for _, item in ipairs(bag:GetChildren()) do
                if item:IsA("Tool") and item:GetAttribute("CoilType") == coilType then item:Destroy() end
            end
        end
        if player.Character then
            for _, item in ipairs(player.Character:GetChildren()) do
                if item:IsA("Tool") and item:GetAttribute("CoilType") == coilType then item:Destroy() end
            end
        end
    end

    local function listTools()
        local set = {}
        local bag = player:FindFirstChildOfClass("Backpack")
        if bag then
            for _, t in ipairs(bag:GetChildren()) do
                if t:IsA("Tool") then set[t] = true end
            end
        end
        local ch = player.Character
        if ch then
            for _, t in ipairs(ch:GetChildren()) do
                if t:IsA("Tool") then set[t] = true end
            end
        end
        return set
    end

    local order = startOrder
    -- onFn tra ve function (de tat) hoac false neu loi
    local function CreateButton(name, onFn)
        order = order + 1
        UI.action(gearScroll, order, string.lower(name), function()
            -- bam lai = gỡ bản cũ rồi lấy lại (không bị trùng / kẹt)
            local prev = addedGearOff[name]
            if prev then
                addedGearOff[name] = nil
                if prev.off then pcall(prev.off) end
                for t in pairs(prev.tools) do
                    if t and t.Parent then pcall(function() t:Destroy() end) end
                end
            end
            local snap = listTools()
            local ok, res = pcall(onFn)
            if not ok then
                warn("[gear] " .. name .. " loi: " .. tostring(res))
                return
            end
            if res == false then return end
            local mine = { off = (type(res) == "function") and res or nil, tools = {} }
            addedGearOff[name] = mine
            local function collect()
                for t in pairs(listTools()) do
                    if not snap[t] then
                        mine.tools[t] = true
                        -- speed / flick system must ignore this gear
                        SPEEDCFG.gear[string.lower(t.Name)] = true
                    end
                end
            end
            collect()
            task.delay(2, function()
                if addedGearOff[name] == mine then collect() end
            end)
        end)
    end

    CreateButton("Gravity Coil", function()
        local GRAVITY_REDUCTION = 0.62
        local GRAVITY_MESH_TEXTURE = "rbxassetid://16606141"
        local GRAVITY_COIL_ICON = "rbxassetid://16619617"
        local GRAVITY_COIL_SOUND = "rbxassetid://16619553"

        local gravityCoilCharacterConnection
        local gravityCoilTool
        local gravityCoilHeartbeat
        local gravityCoilForce
        local gravityCoilHumanoid
        local gravityCoilOldJumpPower
        local gravityCoilOldJumpHeight
        local gravityCoilUseJumpPower

        local function removeGravityCoilEffect()
            if gravityCoilHeartbeat then
                pcall(function() gravityCoilHeartbeat:Disconnect() end)
                gravityCoilHeartbeat = nil
            end
            if gravityCoilForce then
                pcall(function() gravityCoilForce:Destroy() end)
                gravityCoilForce = nil
            end
            if gravityCoilHumanoid and gravityCoilHumanoid.Parent then
                pcall(function()
                    if gravityCoilUseJumpPower then
                        gravityCoilHumanoid.JumpPower = gravityCoilOldJumpPower
                    else
                        gravityCoilHumanoid.JumpHeight = gravityCoilOldJumpHeight
                    end
                end)
            end
            gravityCoilHumanoid = nil
            gravityCoilOldJumpPower = nil
            gravityCoilOldJumpHeight = nil
            gravityCoilUseJumpPower = nil
        end

        local function createGravityCoil()
            local tool = Instance.new("Tool")
            tool.Name = "Zoewar Coil"
            tool.ToolTip = "Jump higher!"
            tool.CanBeDropped = false
            tool.RequiresHandle = true
            tool.TextureId = GRAVITY_COIL_ICON
            tool:SetAttribute("CoilType", "Gravity")

            local handle = Instance.new("Part")
            handle.Name = "Handle"
            handle.Size = Vector3.new(1, 1.2, 2)
            handle.CanCollide = false
            handle.Massless = true
            handle.Parent = tool

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = COIL_MESH_ID
            mesh.TextureId = GRAVITY_MESH_TEXTURE
            mesh.Scale = Vector3.new(0.7, 0.7, 0.7)
            mesh.Parent = handle

            local sound = Instance.new("Sound")
            sound.Name = "CoilSound"
            sound.SoundId = GRAVITY_COIL_SOUND
            sound.Volume = 1
            sound.Parent = handle

            tool.Equipped:Connect(function()
                if not states["GRAVITY COIL"] then return end
                removeGravityCoilEffect()

                local character = player.Character
                if not character then return end
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local root = character:FindFirstChild("HumanoidRootPart")
                if not humanoid or not root then return end

                sound:Play()

                gravityCoilHumanoid = humanoid
                gravityCoilOldJumpPower = humanoid.JumpPower
                gravityCoilOldJumpHeight = humanoid.JumpHeight
                gravityCoilUseJumpPower = humanoid.UseJumpPower

                gravityCoilForce = Instance.new("BodyForce")
                gravityCoilForce.Name = "GravityCoilEffect"
                gravityCoilForce.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * GRAVITY_REDUCTION, 0)
                gravityCoilForce.Parent = root

                if gravityCoilUseJumpPower then
                    humanoid.JumpPower = 60
                else
                    humanoid.JumpHeight = 12
                end

                gravityCoilHeartbeat = RunService.Heartbeat:Connect(function()
                    if not states["GRAVITY COIL"]
                        or tool.Parent ~= character
                        or not character.Parent
                        or not humanoid.Parent
                        or not root.Parent then
                        removeGravityCoilEffect()
                        return
                    end

                    if gravityCoilForce and gravityCoilForce.Parent then
                        gravityCoilForce.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * GRAVITY_REDUCTION, 0)
                    end
                end)
            end)

            tool.Unequipped:Connect(removeGravityCoilEffect)
            return tool
        end

        local function ensureGravityCoil()
            local found = findCoil("Gravity")
            if found then
                gravityCoilTool = found
                return
            end
            local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 10)
            if backpack and states["GRAVITY COIL"] then
                gravityCoilTool = createGravityCoil()
                gravityCoilTool.Parent = backpack
            end
        end

        local function gravityCoilOff()
            if gravityCoilCharacterConnection then
                pcall(function() gravityCoilCharacterConnection:Disconnect() end)
                gravityCoilCharacterConnection = nil
            end
            removeGravityCoilEffect()
            destroyCoilsOfType("Gravity")
            gravityCoilTool = nil
            print("❌ GRAVITY COIL OFF")
        end

        local function gravityCoilOn()
            gravityCoilOff()
            ensureGravityCoil()
            gravityCoilCharacterConnection = player.CharacterAdded:Connect(function()
                task.wait(0.6)
                if states["GRAVITY COIL"] then
                    ensureGravityCoil()
                end
            end)
            print("✅ GRAVITY COIL ON")
        end
    
        -- Chama a função para ativar
        gravityCoilOn()
        return gravityCoilOff
    end)

    -- SPEED COIL (Seu script exato)
    CreateButton("Speed Coil", function()
        local SPEED_COIL_SPEED = 32
        local SPEED_MESH_TEXTURE = "rbxassetid://99170547"
        local SPEED_COIL_ICON = "rbxassetid://99170415"
        local SPEED_COIL_SOUND = "rbxassetid://99173388"

        local speedCoilCharacterConnection
        local speedCoilTool
        local speedCoilOriginalWalkSpeed
        local speedCoilEffectHumanoid

        local function removeSpeedCoilEffect()
            if speedCoilEffectHumanoid and speedCoilEffectHumanoid.Parent and speedCoilOriginalWalkSpeed ~= nil then
                pcall(function()
                    speedCoilEffectHumanoid.WalkSpeed = speedCoilOriginalWalkSpeed
                end)
            end
            speedCoilEffectHumanoid = nil
            speedCoilOriginalWalkSpeed = nil
        end

        local function createSpeedCoil()
            local tool = Instance.new("Tool")
            tool.Name = "Zoewar Coil"
            tool.ToolTip = "Speed Up!"
            tool.CanBeDropped = false
            tool.RequiresHandle = true
            tool.TextureId = SPEED_COIL_ICON
            tool:SetAttribute("CoilType", "Speed")

            local handle = Instance.new("Part")
            handle.Name = "Handle"
            handle.Size = Vector3.new(1, 1.2, 2)
            handle.CanCollide = false
            handle.Massless = true
            handle.Parent = tool

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = COIL_MESH_ID
            mesh.TextureId = SPEED_MESH_TEXTURE
            mesh.Scale = Vector3.new(0.7, 0.7, 0.7)
            mesh.Parent = handle

            local sound = Instance.new("Sound")
            sound.Name = "CoilSound"
            sound.SoundId = SPEED_COIL_SOUND
            sound.Volume = 1
            sound.Parent = handle

            tool.Equipped:Connect(function()
                if not states["SPEED COIL"] then return end
                removeSpeedCoilEffect()
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if not humanoid then return end
                speedCoilEffectHumanoid = humanoid
                speedCoilOriginalWalkSpeed = humanoid.WalkSpeed
                humanoid.WalkSpeed = SPEED_COIL_SPEED
                sound:Play()
            end)

            tool.Unequipped:Connect(removeSpeedCoilEffect)
            return tool
        end

        local function ensureSpeedCoil()
            local found = findCoil("Speed")
            if found then
                speedCoilTool = found
                return
            end
            local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 10)
            if backpack and states["SPEED COIL"] then
                speedCoilTool = createSpeedCoil()
                speedCoilTool.Parent = backpack
            end
        end

        local function speedCoilOff()
            if speedCoilCharacterConnection then
                pcall(function() speedCoilCharacterConnection:Disconnect() end)
                speedCoilCharacterConnection = nil
            end
            removeSpeedCoilEffect()
            destroyCoilsOfType("Speed")
            speedCoilTool = nil
            print("❌ SPEED COIL OFF")
        end

        local function speedCoilOn()
            speedCoilOff()
            ensureSpeedCoil()
            speedCoilCharacterConnection = player.CharacterAdded:Connect(function()
                task.wait(0.6)
                if states["SPEED COIL"] then
                    ensureSpeedCoil()
                end
            end)
            print("✅ SPEED COIL ON")
        end
    
        -- Chama a função para ativar
        speedCoilOn()
        return speedCoilOff
    end)

    -- Golden Magic Carpet (Seu script exato)
    CreateButton("Golden Carpet", function()
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local UserInputService = game:GetService("UserInputService")
        local Debris = game:GetService("Debris")

        local player = Players.LocalPlayer
        local camera = workspace.CurrentCamera
        local backpack = player:WaitForChild("Backpack")

        local gearId = 402305186
        local animId = "rbxassetid://855828754"

        local success, objects = pcall(function()
            return game:GetObjects("rbxassetid://" .. gearId)
        end)

        if success and objects and #objects > 0 then
            local tool = objects[1]

            for _, v in ipairs(tool:GetDescendants()) do
                if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("ModuleScript") then
                    v:Destroy()
                end
            end

            tool.TextureId = "rbxassetid://1014109561"

            local function setupHandle(t)
                local handle = t:FindFirstChild("Handle")
                if handle then
                    handle.Transparency = 0
                    local mesh = handle:FindFirstChildOfClass("SpecialMesh")
                    if not mesh then
                        mesh = Instance.new("SpecialMesh")
                        mesh.Parent = handle
                    end
                    mesh.MeshType = Enum.MeshType.FileMesh
                    mesh.MeshId = "rbxassetid://223079737"
                    mesh.TextureId = "rbxassetid://1014108463"
                    mesh.Scale = Vector3.new(1.4, 1.4, 1.4)
                    mesh.VertexColor = Vector3.new(1, 1, 1)
                end
            end

            setupHandle(tool)

            tool.Parent = backpack

            local GRIP_DOC = CFrame.new(-1.47, 0.35, -1.65, 0, 0, -1, -1, 0, 0, 0, 1, 0)
            local GRIP_NGANG = CFrame.new(-1.5, 0.8, -1.65, -1, 0, 0, 0, 0, 1, 0, 1, 0)
            tool.Grip = GRIP_DOC

            local equipped = false
            local isFlying = false
            local FLY_SPEED = 70

            local bodyVel, bodyGyro
            local lastTrailPos = nil
            local currentAnimTrack = nil

            local GoldenColors = {
                Color3.fromRGB(255, 240, 100),
                Color3.fromRGB(255, 223, 0),
                Color3.fromRGB(255, 215, 0),
                Color3.fromRGB(238, 201, 0),
                Color3.fromRGB(255, 230, 50)
            }

            local function createRainbow(fromPos, toPos)
                local dist = (toPos - fromPos).Magnitude
                if dist < 1 then return end

                local mid = fromPos:Lerp(toPos, 0.5)
                local lookCF = CFrame.lookAt(mid, toPos)

                local model = Instance.new("Model")
                model.Name = "GoldenTrail"

                local partWidth = 0.65
                local height = 0.5

                for i, color in ipairs(GoldenColors) do
                    local p = Instance.new("Part")
                    p.Size = Vector3.new(partWidth, height, dist + 2)
                    p.Anchored = true
                    p.CanCollide = false
                    p.Material = Enum.Material.Neon
                    p.Color = color
                    p.Transparency = 0.02
                    p.CastShadow = false

                    local offsetX = (i - 3) * partWidth
                    p.CFrame = lookCF * CFrame.new(offsetX, -2.2, 0)

                    local light = Instance.new("PointLight")
                    light.Color = color
                    light.Brightness = 15.0
                    light.Range = 18
                    light.Parent = p

                    p.Parent = model
                end

                model.Parent = workspace
                Debris:AddItem(model, 1.5)
            end

            local function cleanupMovers()
                if bodyVel then bodyVel:Destroy() bodyVel = nil end
                if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
            end

            local function stopAnimation()
                if currentAnimTrack then
                    currentAnimTrack:Stop()
                    currentAnimTrack:Destroy()
                    currentAnimTrack = nil
                end
            end

            local function stopFlying()
                isFlying = false
                tool.Grip = GRIP_DOC
                lastTrailPos = nil
                cleanupMovers()
                stopAnimation()

                setupHandle(tool)

                local char = player.Character
                if char then
                    local humanoid = char:FindFirstChild("Humanoid")
                    if humanoid then
                        humanoid.PlatformStand = false
                        humanoid.AutoRotate = true
                    end
                end
            end

            local function startAnimation(humanoid)
                stopAnimation()
                local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 2)
                if animator then
                    local animObj = Instance.new("Animation")
                    animObj.AnimationId = animId
                    currentAnimTrack = animator:LoadAnimation(animObj)
                    currentAnimTrack.Priority = Enum.AnimationPriority.Action
                    currentAnimTrack:Play()
                end
            end

            local function startFlying()
                local char = player.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChild("Humanoid")
                if not hrp or not humanoid then return end

                isFlying = true
                tool.Grip = GRIP_NGANG
                lastTrailPos = hrp.Position

                setupHandle(tool)

                humanoid.PlatformStand = true
                humanoid.AutoRotate = false

                cleanupMovers()
                startAnimation(humanoid)

                bodyVel = Instance.new("BodyVelocity")
                bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bodyVel.Velocity = Vector3.zero
                bodyVel.Parent = hrp

                bodyGyro = Instance.new("BodyGyro")
                bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bodyGyro.P = 12000
                bodyGyro.CFrame = hrp.CFrame
                bodyGyro.Parent = hrp

                hrp.AssemblyLinearVelocity = Vector3.new(0, 25, 0)
            end

            tool.Activated:Connect(function()
                if not equipped then return end
                if isFlying then
                    stopFlying()
                else
                    startFlying()
                end
            end)

            tool.Equipped:Connect(function()
                equipped = true
                tool.Grip = GRIP_DOC
                setupHandle(tool)
            end)

            tool.Unequipped:Connect(function()
                equipped = false
                stopFlying()
            end)

            local function onCharacterAdded(char)
                stopFlying()
                local humanoid = char:WaitForChild("Humanoid", 5)
                if humanoid then
                    humanoid.Died:Connect(stopFlying)
                end
            end

            if player.Character then
                onCharacterAdded(player.Character)
            end
            local carpetCharConn = player.CharacterAdded:Connect(onCharacterAdded)

            local trailCooldown = 0
            local carpetRenderConn = RunService.RenderStepped:Connect(function(dt)
                if not (equipped and isFlying and player.Character) then return end

                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if not hrp or not bodyVel or not bodyGyro then return end

                local camCF = camera.CFrame
                bodyGyro.CFrame = camCF

                local moveDir = Vector3.zero

                if humanoid.MoveDirection.Magnitude > 0.05 then
                    local localMove = camCF:VectorToObjectSpace(humanoid.MoveDirection)
                    moveDir = Vector3.new(localMove.X, 0, localMove.Z)
                end

                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDir = moveDir + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDir = moveDir + Vector3.new(0, -1, 0)
                end

                if humanoid.MoveDirection.Magnitude <= 0.05 then
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Vector3.new(0, 0, -1) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir + Vector3.new(0, 0, 1) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir + Vector3.new(-1, 0, 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Vector3.new(1, 0, 0) end
                end

                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit
                    local flyVector = camCF.RightVector * moveDir.X
                        + Vector3.new(0, 1, 0) * moveDir.Y
                        + camCF.LookVector * -moveDir.Z
                    bodyVel.Velocity = flyVector * FLY_SPEED
                else
                    bodyVel.Velocity = Vector3.zero
                end

                trailCooldown = trailCooldown - dt
                if trailCooldown <= 0 then
                    trailCooldown = 0.05

                    local currentPos = hrp.Position
                    if lastTrailPos then
                        local dist = (currentPos - lastTrailPos).Magnitude
                        if dist > 1.5 then
                            createRainbow(lastTrailPos, currentPos)
                            lastTrailPos = currentPos
                        end
                    else
                        lastTrailPos = currentPos
                    end
                end
            end)

            print("✅ Tapete Perfeito: Brilho Estourado e Tamanho Fixo!")
            return function()
                pcall(stopFlying)
                pcall(function() carpetRenderConn:Disconnect() end)
                pcall(function() carpetCharConn:Disconnect() end)
                pcall(function() tool:Destroy() end)
            end
        else
            warn("Erro ao carregar o Tapete!")
            return false
        end
    end)
    CreateButton("Dual Gravity Coil", function()
        loadstring(game:HttpGet("https://pastefy.app/SQkmjy25/raw"))()
    end)
    CreateButton("Nonmagic Carpet", function()
        loadstring(game:HttpGet("https://pastefy.app/U1zk3Dqt/raw"))()
    end)
    CreateButton("Dark Pegasus", function()
        loadstring(game:HttpGet("https://pastefy.app/MVITXPKt/raw"))()
    end)
    CreateButton("JetPack", function()
        loadstring(game:HttpGet("https://pastefy.app/3I4B1Imu/raw"))()
    end)
    CreateButton("Crossbow of the Sea", function()
        local toolId = 236438668
        local Players = game:GetService("Players")
        local Debris = game:GetService("Debris")
        local UserInputService = game:GetService("UserInputService")
        local RunService = game:GetService("RunService")

        local player = Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid")
        local mouse = player:GetMouse()

        local SHOT_SOUND_ID = "rbxassetid://99204505"
        local HIT_SOUND_ID  = "rbxassetid://58274204"

        local function createWaterExplosion(point)
            local scale = 8 + (4 * math.random(1, 3))
            local terrain = workspace.Terrain

            terrain:FillBall(point, scale, Enum.Material.Water)

            task.delay(7, function()
                terrain:FillBall(point, scale, Enum.Material.Air)
            end)
        end

        local function createArrow()
            local arrow = Instance.new("Part")
            arrow.Name = "SeaArrow"
            arrow.Size = Vector3.new(0.2, 0.2, 2.5)
            arrow.Transparency = 0.25
            arrow.Reflectance = 0.5
            arrow.CanCollide = false
            arrow.Anchored = false
            arrow.Material = Enum.Material.SmoothPlastic
            arrow.BrickColor = BrickColor.new("Cyan")

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshId = "rbxassetid://235107348"
            mesh.TextureId = "rbxassetid://235107780"
            mesh.Scale = Vector3.new(1, 1, 1)
            mesh.Parent = arrow

            local hitSound = Instance.new("Sound")
            hitSound.Name = "Hit"
            hitSound.SoundId = HIT_SOUND_ID
            hitSound.Volume = 1
            hitSound.Parent = arrow

            return arrow
        end

        local success, objects = pcall(function()
            return game:GetObjects("rbxassetid://" .. toolId)
        end)

        if not (success and objects and objects[1] and objects[1]:IsA("Tool")) then
            warn("Không tải được Crossbow of the Sea. Executor không hỗ trợ GetObjects.")
            return false
        end

        local tool = objects[1]
        tool.Name = "Crossbow of the Sea"
        tool.Parent = player.Backpack
        humanoid:EquipTool(tool)

        for _, child in ipairs(tool:GetDescendants()) do
            if child:IsA("Script") or child:IsA("LocalScript") then
                child:Destroy()
            end
        end

        local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
        if handle then
            local shotSound = Instance.new("Sound")
            shotSound.Name = "Shot"
            shotSound.SoundId = SHOT_SOUND_ID
            shotSound.Volume = 0.5
            shotSound.Parent = handle
        end

        local AttackAble = true
        local AttackReloadTime = 1.2
        local ProjectileSpeed = 120

        local activatedConn = tool.Activated:Connect(function()
            if not AttackAble then return end
            AttackAble = false

            if handle and handle:FindFirstChild("Shot") then
                handle.Shot.Pitch = math.random(90, 110) / 100
                handle.Shot:Play()
            end

            local targetPoint = mouse.Hit.Position
            local launchPoint = handle and handle.Position or character.PrimaryPart.Position

            local arrow = createArrow()
            arrow.CFrame = CFrame.new(launchPoint, targetPoint)
            arrow.Velocity = arrow.CFrame.LookVector * ProjectileSpeed
            arrow.Parent = workspace

            local connection
            connection = arrow.Touched:Connect(function(part)
                if part:IsDescendantOf(character) then return end

                createWaterExplosion(arrow.Position)

                if arrow:FindFirstChild("Hit") then
                    arrow.Hit:Play()
                end

                arrow.Anchored = true
                arrow.CanCollide = false
                arrow.Transparency = 1

                if connection then
                    connection:Disconnect()
                end
            end)

            Debris:AddItem(arrow, 8)

            task.delay(AttackReloadTime, function()
                AttackAble = true
            end)
        end)

        local JUMP_POWER = 78
        local BOOST_FRAMES = 8

        local function isInWater()
            local state = humanoid:GetState()
            return state == Enum.HumanoidStateType.Swimming or state == Enum.HumanoidStateType.GettingUp
        end

        local jumpConn = UserInputService.JumpRequest:Connect(function()
            if not isInWater() then return end

            local root = character:FindFirstChild("HumanoidRootPart")
            if not root then return end

            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

            root.AssemblyLinearVelocity = Vector3.new(
                root.AssemblyLinearVelocity.X,
                JUMP_POWER,
                root.AssemblyLinearVelocity.Z
            )

            task.spawn(function()
                for i = 1, BOOST_FRAMES do
                    if not root or not root.Parent then break end
                    if root.AssemblyLinearVelocity.Y < JUMP_POWER * 0.7 then
                        root.AssemblyLinearVelocity = Vector3.new(
                            root.AssemblyLinearVelocity.X,
                            math.max(root.AssemblyLinearVelocity.Y, JUMP_POWER * 0.85),
                            root.AssemblyLinearVelocity.Z
                        )
                    end
                    RunService.Heartbeat:Wait()
                end
            end)
        end)

        print("Crossbow of the Sea + Jump mượt đã sẵn sàng!")
        return function()
            pcall(function() activatedConn:Disconnect() end)
            pcall(function() jumpConn:Disconnect() end)
            pcall(function() tool:Destroy() end)
        end
    end)
    CreateButton("Fake Bomb", function()
        local Player = game.Players.LocalPlayer
        local Mouse = Player:GetMouse()
        local PlayerGui = Player:WaitForChild("PlayerGui")
        local UserInputService = game:GetService("UserInputService")

        local Config = {
            Cooldown = 2,
            CanUse = true,
            JumpPower = 65
        }
        local CurrentDroppedBomb = nil
        local alive, currentTool, charConn = true, nil, nil

        local function GetFuseBomb()
            local success, objects = pcall(function()
                return game:GetObjects("rbxassetid://11563251")
            end)
            if success and objects and objects[1] and objects[1]:IsA("Tool") then
                return objects[1]
            end
            return nil
        end

        local sg = Instance.new("ScreenGui", PlayerGui)
        sg.Name = "C4_Final_Menu"
        sg.ResetOnSpawn = false

        local toggle = Instance.new("TextButton", sg)
        toggle.Size = UDim2.new(0, 60, 0, 40)
        toggle.Position = UDim2.new(0, 10, 0.5, 0)
        toggle.Text = "MENU"
        toggle.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        toggle.Draggable = true

        local frame = Instance.new("Frame", sg)
        frame.Size = UDim2.new(0, 180, 0, 100)
        frame.Position = UDim2.new(0.5, -90, 0.4, 0)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        frame.Visible = false

        local input = Instance.new("TextBox", frame)
        input.Size = UDim2.new(0.8, 0, 0, 30)
        input.Position = UDim2.new(0.1, 0, 0.2, 0)
        input.Text = tostring(Config.Cooldown)
        input.PlaceholderText = "Segundos..."

        local btn = Instance.new("TextButton", frame)
        btn.Size = UDim2.new(0.8, 0, 0, 30)
        btn.Position = UDim2.new(0.1, 0, 0.6, 0)
        btn.Text = "SALVAR"
        btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)

        toggle.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible
        end)

        btn.MouseButton1Click:Connect(function()
            local num = tonumber(input.Text)
            if num and num >= 0 then
                Config.Cooldown = num
            else
                Config.Cooldown = 2
            end
            frame.Visible = false
        end)

        local function GiveTool()
            local Tool = GetFuseBomb()
            if not Tool then
                warn("❌ Falha ao carregar a Fuse Bomb (11563251).")
                return
            end

            Tool.Name = "Fake Bomb"
            currentTool = Tool
            Tool.RequiresHandle = true
            Tool.CanBeDropped = false

            Tool.Grip = CFrame.new(0, -0.15, 0.1) 

            for _, child in ipairs(Tool:GetDescendants()) do
                if child:IsA("Script") or child:IsA("LocalScript") then
                    child:Destroy()
                end
            end

            local handle = Tool:FindFirstChild("Handle")
            if handle then
                handle.Size = handle.Size * 0.6 
                for _, mesh in ipairs(handle:GetDescendants()) do
                    if mesh:IsA("SpecialMesh") or mesh:IsA("Mesh") then
                        mesh.Scale = mesh.Scale * 0.6
                    end
                end
            end

            Tool.Activated:Connect(function()
                if not Config.CanUse then return end
            
                local char = Player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
            
                Config.CanUse = false

                hrp.AssemblyLinearVelocity = Vector3.new(
                    hrp.AssemblyLinearVelocity.X, 
                    Config.JumpPower, 
                    hrp.AssemblyLinearVelocity.Z
                )

                if CurrentDroppedBomb then
                    CurrentDroppedBomb:Destroy()
                end

                local d_handle = Tool:FindFirstChild("Handle")
                if not d_handle then
                    Config.CanUse = true
                    return
                end

                local bombClone = d_handle:Clone()
                bombClone.Name = "DroppedFuseBomb"
            
                bombClone.Size = bombClone.Size * 0.6 
                for _, mesh in ipairs(bombClone:GetDescendants()) do
                    if mesh:IsA("SpecialMesh") or mesh:IsA("Mesh") then
                        mesh.Scale = mesh.Scale * 0.6
                    end
                end

                bombClone.CFrame = hrp.CFrame * CFrame.new(0, -3.2, 0)
                bombClone.Parent = workspace
                CurrentDroppedBomb = bombClone

                game.Debris:AddItem(bombClone, 5)

                local bv = Instance.new("BodyVelocity", bombClone)
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Velocity = ((Mouse.Hit.Position - hrp.Position).Unit * 25) + Vector3.new(0, 10, 0)
                game.Debris:AddItem(bv, 0.1)

                local parts = {}
                if Config.Cooldown > 0 then
                    for _, p in pairs(Tool:GetChildren()) do
                        if p:IsA("BasePart") then
                            parts[p] = p.Transparency
                            p.Transparency = 1
                        end
                    end
                end

                task.wait(Config.Cooldown)

                if Config.Cooldown > 0 then
                    for p, trans in pairs(parts) do
                        if p then
                            p.Transparency = trans
                        end
                    end
                end

                Config.CanUse = true
            end)

            Tool.Parent = Player.Backpack
        end

        charConn = Player.CharacterAdded:Connect(function()
            task.wait(1)
            if alive then GiveTool() end
        end)

        GiveTool()
        return function()
            alive = false
            Config.CanUse = true
            pcall(function() charConn:Disconnect() end)
            pcall(function() if currentTool then currentTool:Destroy() end end)
            pcall(function() if CurrentDroppedBomb then CurrentDroppedBomb:Destroy() end end)
            pcall(function() sg:Destroy() end)
        end
    end)

end
installAddedGears(gearScroll, 10)

UI.action(gearScroll, 100, "clear all tools", function()
    destroyAllCoils()
    print("gear tools cleared")
end)

-- ===== BEAM PANEL (kawaii style, matches main) =====
local beamGui = Instance.new("ScreenGui")
beamGui.Name = "CNP_BeamPanel"
beamGui.ResetOnSpawn = false
beamGui.DisplayOrder = 2147483644
beamGui.Enabled = false
pcall(function() beamGui.Parent = game:GetService("CoreGui") end)
if not beamGui.Parent then beamGui.Parent = pg end

do
    local ORIGINAL_KEY = "GAME ORIGINAL"
    local BeamThickness = 0.26
    local GlowIntensity = 1.0
    local IsGlowEnabled = true
    local NeonEnabled = false
    local CurrentBeamMode = ORIGINAL_KEY
    local Running = true
    local CurrentBeam = nil
    local BaseBrightness = 1
    local OriginalState = nil
    local NeedRestoreOriginal = false
    local NEON_BRIGHTNESS = 2
    local HALO_SCALE = 2.4
    local HALO_TRANSPARENCY = 0.55
    local Halo, HaloSource = nil, nil
    local Connections = {}
    local function Track(c) table.insert(Connections, c); return c end

    local HasBrightness = pcall(function()
        local b = Instance.new("Beam")
        local _ = b.Brightness
        b:Destroy()
    end)
    local function SetBrightness(beam, v)
        if HasBrightness then pcall(function() beam.Brightness = v end) end
    end

    local C = Color3.fromRGB
    local Categories = { "ORIGINAL", "MIX", "COMBO", "WARM", "COOL", "SPACE" }
    local BeamList = {}
    local function P(cat, name, ...) table.insert(BeamList, { cat, name, { ... } }) end
    -- ORIGINAL
    P("ORIGINAL", ORIGINAL_KEY)
    P("ORIGINAL", "Red", C(255,0,0))
    P("ORIGINAL", "Orange", C(255,120,0))
    P("ORIGINAL", "Yellow", C(255,230,0))
    P("ORIGINAL", "Lime", C(130,255,0))
    P("ORIGINAL", "Green", C(0,255,0))
    P("ORIGINAL", "Teal", C(0,220,170))
    P("ORIGINAL", "Cyan", C(0,255,255))
    P("ORIGINAL", "Sky Blue", C(80,180,255))
    P("ORIGINAL", "Blue", C(0,60,255))
    P("ORIGINAL", "Violet", C(130,0,255))
    P("ORIGINAL", "Purple", C(190,0,255))
    P("ORIGINAL", "Magenta", C(255,0,255))
    P("ORIGINAL", "Pink", C(255,183,197))
    P("ORIGINAL", "Hot Pink", C(255,0,110))
    P("ORIGINAL", "White", C(255,255,255))
    -- MIX
    P("MIX", "Bubblegum", C(255,140,200), C(255,200,230), C(140,220,255))
    P("MIX", "Grape", C(60,0,90), C(130,30,190), C(200,120,255))
    P("MIX", "Royal", C(30,30,140), C(80,40,200), C(255,200,40))
    P("MIX", "Rose Gold", C(183,110,121), C(255,190,170), C(255,225,210))
    P("MIX", "Peach", C(255,150,120), C(255,190,150), C(255,225,190))
    P("MIX", "Desert", C(120,60,20), C(210,140,60), C(255,220,140))
    P("MIX", "Silver", C(120,120,130), C(210,210,220), C(255,255,255))
    P("MIX", "Cherry", C(120,0,30), C(220,0,60), C(255,90,120))
    P("MIX", "Forest", C(0,40,10), C(20,110,30), C(110,190,60))
    P("MIX", "Lemon Lime", C(255,250,60), C(160,255,60), C(0,220,80))
    P("MIX", "Sakura", C(255,190,210), C(255,100,170), C(255,0,130), C(255,220,240))
    -- COMBO
    P("COMBO", "Rainbow Hard", C(255,0,0), C(255,127,0), C(255,255,0), C(0,255,0), C(0,180,255), C(0,0,255), C(180,0,255))
    P("COMBO", "Rainbow Roll", C(255,0,0), C(255,120,0), C(255,255,0), C(0,255,0), C(0,255,255), C(0,80,255), C(200,0,255))
    P("COMBO", "Pastel Rainbow", C(255,170,170), C(255,220,150), C(200,255,170), C(150,230,255), C(210,170,255))
    P("COMBO", "Candy", C(255,80,120), C(255,200,60), C(90,230,200), C(140,100,255))
    P("COMBO", "Retro", C(255,0,110), C(255,190,11), C(58,134,255), C(131,56,236))
    P("COMBO", "Plasma", C(255,0,200), C(120,0,255), C(0,160,255), C(0,255,200))
    P("COMBO", "Vaporwave", C(255,113,206), C(1,205,254), C(5,255,161), C(185,103,255))
    P("COMBO", "Aurora", C(0,255,135), C(0,180,255), C(130,60,255), C(255,60,200))
    P("COMBO", "Cotton Candy", C(255,150,210), C(180,150,255), C(100,220,255), C(255,255,255))
    P("COMBO", "Fire & Ice", C(255,40,0), C(255,200,0), C(255,255,255), C(0,200,255), C(0,60,255))
    P("COMBO", "Cyberpunk", C(255,0,100), C(255,0,220), C(0,255,255), C(0,100,255))
    P("COMBO", "Police", C(255,0,0), C(255,255,255), C(0,0,255), C(255,255,255))
    P("COMBO", "Black & White", C(0,0,0), C(255,255,255), C(0,0,0), C(255,255,255))
    P("COMBO", "Gold & Silver", C(255,190,0), C(255,240,150), C(180,180,180), C(255,255,255))
    -- WARM
    P("WARM", "Fire", C(120,0,0), C(255,0,0), C(255,90,0), C(255,220,0))
    P("WARM", "Magma", C(40,0,0), C(150,0,0), C(255,40,0), C(255,150,0))
    P("WARM", "Lava", C(60,0,0), C(200,20,0), C(255,110,0), C(255,230,60))
    P("WARM", "Sunset", C(255,0,80), C(255,70,0), C(255,160,0), C(255,230,100))
    P("WARM", "Sunrise", C(255,94,98), C(255,153,102), C(255,206,84), C(255,250,200))
    P("WARM", "Blood Moon", C(30,0,0), C(100,0,0), C(200,0,0), C(255,40,40))
    -- COOL
    P("COOL", "Ocean Blue", C(0,20,100), C(0,100,255), C(0,220,255), C(100,255,255))
    P("COOL", "Sapphire", C(0,0,70), C(0,50,180), C(0,130,255), C(100,220,255))
    P("COOL", "Ice", C(255,255,255), C(150,240,255), C(0,180,255), C(0,70,255))
    P("COOL", "Teal Wave", C(0,60,70), C(0,160,170), C(90,240,230))
    P("COOL", "Mint", C(0,200,150), C(120,255,210), C(220,255,245))
    P("COOL", "Emerald", C(0,50,30), C(0,130,70), C(0,255,130), C(150,255,200))
    -- SPACE
    P("SPACE", "Galaxy", C(5,0,40), C(60,0,140), C(180,40,255), C(255,120,230), C(255,255,255))
    P("SPACE", "Midnight", C(10,10,50), C(40,30,120), C(90,60,200), C(160,140,255))
    P("SPACE", "Pink Galaxy", C(255,20,147), C(255,105,180), C(190,0,255), C(100,0,180), C(255,0,220))
    P("SPACE", "Purple Haze", C(50,0,100), C(120,0,255), C(200,0,255), C(255,0,180))
    P("SPACE", "Amethyst", C(60,0,100), C(120,0,200), C(190,80,255), C(255,180,255))

    local BeamPresets = {}
    for _, e in ipairs(BeamList) do
        if #e[3] > 0 then BeamPresets[e[2]] = e[3] end
    end

    local function CreateHardSequence(colors)
        local keypoints = {}
        local step = 1 / #colors
        for i, color in ipairs(colors) do
            table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) * step, color))
            if i < #colors then
                table.insert(keypoints, ColorSequenceKeypoint.new(i * step - 0.01, color))
            else
                table.insert(keypoints, ColorSequenceKeypoint.new(1, color))
            end
        end
        return ColorSequence.new(keypoints)
    end
    local function CreateSmoothSequence(colors)
        local n = #colors
        if n == 1 then return ColorSequence.new(colors[1]) end
        local kp = {}
        for i, c in ipairs(colors) do kp[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), c) end
        return ColorSequence.new(kp)
    end
    local SequenceCache = {}
    for name, colors in pairs(BeamPresets) do
        SequenceCache[name] = CreateHardSequence(colors)
    end
    local LastRollOffset, RollSequence = -1, nil
    local function GetRollSequence()
        local base = BeamPresets["Rainbow Roll"]
        local offset = math.floor(tick() * 8) % #base
        if offset ~= LastRollOffset then
            LastRollOffset = offset
            local rolled = {}
            for i = 1, #base do rolled[i] = base[((i + offset - 1) % #base) + 1] end
            RollSequence = CreateHardSequence(rolled)
        end
        return RollSequence
    end

    local function DestroyHalo()
        if Halo then Halo:Destroy(); Halo = nil; HaloSource = nil end
    end
    local function UpdateHalo(beam)
        if not Halo or HaloSource ~= beam or not Halo.Parent then
            DestroyHalo()
            local ok, h = pcall(function() return beam:Clone() end)
            if not ok or not h then return end
            h.Name = "NeonHalo"; h.Parent = beam.Parent
            Halo = h; HaloSource = beam
        end
        Halo.Enabled = beam.Enabled
        Halo.Attachment0 = beam.Attachment0
        Halo.Attachment1 = beam.Attachment1
        Halo.Color = beam.Color
        Halo.Texture = ""
        Halo.Width0 = BeamThickness * HALO_SCALE
        Halo.Width1 = BeamThickness * HALO_SCALE
        Halo.Transparency = NumberSequence.new(HALO_TRANSPARENCY)
        Halo.LightEmission = 1
        Halo.LightInfluence = 0
        SetBrightness(Halo, NEON_BRIGHTNESS)
    end

    local OriginalByBeam = setmetatable({}, { __mode = "k" })

    local function isHaloBeam(b)
        return b == Halo or (b and b.Name == "NeonHalo")
    end

    local function FindAllBeams()
        local list = {}
        local seen = {}
        local function add(obj)
            if obj and obj:IsA("Beam") and not isHaloBeam(obj) and not seen[obj] then
                seen[obj] = true
                list[#list + 1] = obj
            end
        end
        local function addFrom(root)
            if not root then return end
            local ok, descs = pcall(function() return root:GetDescendants() end)
            if ok and descs then
                for _, obj in ipairs(descs) do add(obj) end
            end
            for _, obj in ipairs(root:GetChildren()) do add(obj) end
        end
        -- character / tools
        addFrom(player.Character)
        -- MM2 shot beam often Workspace.Part.Beam
        for _, ch in ipairs(Workspace:GetChildren()) do
            if ch.Name == "Part" then addFrom(ch) end
        end
        return list
    end

    local StyledWidth = setmetatable({}, { __mode = "k" }) -- width applied once

    local function rememberOriginal(beam)
        if OriginalByBeam[beam] then return end
        local st = {
            Color = beam.Color,
            Texture = beam.Texture,
            Width0 = beam.Width0,
            Width1 = beam.Width1,
            LightEmission = beam.LightEmission,
            LightInfluence = beam.LightInfluence,
            Brightness = 1,
        }
        if HasBrightness then
            pcall(function() st.Brightness = beam.Brightness end)
        end
        OriginalByBeam[beam] = st
    end

    -- shot beams live under Workspace (e.g. Workspace.Part.Beam) — color only, never force glow/width
    local function isCharacterBeam(beam)
        local char = player.Character
        return char and beam:IsDescendantOf(char)
    end

    local function applyOneBeam(beam)
        if not beam or not beam.Parent then return end
        if beam.Enabled == false then return end

        rememberOriginal(beam)
        local onChar = player.Character and beam:IsDescendantOf(player.Character)

        -- COLOR every frame (game may overwrite)
        if CurrentBeamMode == ORIGINAL_KEY then
            if NeedRestoreOriginal then
                local ob = OriginalByBeam[beam]
                if ob then
                    pcall(function()
                        beam.Color = ob.Color
                        beam.Texture = ob.Texture
                    end)
                end
            end
        else
            pcall(function()
                beam.Texture = ""
                if CurrentBeamMode == "Rainbow Roll" then
                    beam.Color = GetRollSequence()
                else
                    local seq = SequenceCache[CurrentBeamMode]
                    if seq then
                        beam.Color = seq
                    end
                end
            end)
        end

        -- width/glow: character beams only (shot beams keep native fade)
        if not onChar then return end

        if not StyledWidth[beam] then
            pcall(function()
                beam.Width0 = BeamThickness
                beam.Width1 = BeamThickness
            end)
            StyledWidth[beam] = true
        end

        if NeonEnabled then
            beam.LightEmission = 1
            beam.LightInfluence = 0
            SetBrightness(beam, NEON_BRIGHTNESS)
        elseif IsGlowEnabled then
            beam.LightEmission = GlowIntensity
            beam.LightInfluence = 0
            local ob = OriginalByBeam[beam]
            SetBrightness(beam, (ob and ob.Brightness) or BaseBrightness)
        else
            -- slight emission so solid ColorSequence shows clearly
            beam.LightEmission = 0.35
            beam.LightInfluence = 0.4
            local ob = OriginalByBeam[beam]
            SetBrightness(beam, (ob and ob.Brightness) or BaseBrightness)
        end
    end

    local MainFrame = Instance.new("Frame")
    do
        local bw = fitW(isMobile and 290 or 320)
        local bh = fitH(isMobile and 400 or 440)
        MainFrame.Size = UDim2.fromOffset(bw, bh)
        MainFrame.Position = UDim2.new(0.5, -bw / 2, 0.5, -bh / 2)
    end
    MainFrame.BackgroundColor3 = UI.bg
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = beamGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)
    do
        local g = Instance.new("UIGradient", MainFrame)
        g.Rotation = 155
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 48, 38)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 34, 28)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 24, 26)),
        })
    end
    do
        local st = Instance.new("UIStroke", MainFrame)
        st.Color = Color3.fromRGB(200, 160, 70)
        st.Thickness = 2
        st.Transparency = 0.15
    end

    local TitleBar = Instance.new("Frame", MainFrame)
    TitleBar.Size = UDim2.new(1, 0, 0, 36)
    TitleBar.BackgroundTransparency = 1
    TitleBar.Active = true

    local TitleText = Instance.new("TextLabel", TitleBar)
    TitleText.Size = UDim2.new(1, -56, 1, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "Beam"
    TitleText.TextColor3 = Color3.fromRGB(240, 200, 100)
    TitleText.Font = UI.titleFont
    TitleText.TextSize = 20
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UIPadding", TitleText).PaddingLeft = UDim.new(0, 14)

    local CloseBtn = Instance.new("TextButton", TitleBar)
    CloseBtn.Size = UDim2.fromOffset(26, 26)
    CloseBtn.Position = UDim2.new(1, -30, 0, 5)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Text = "x"
    CloseBtn.TextColor3 = UI.dim
    CloseBtn.Font = UI.font
    CloseBtn.TextSize = 18
    CloseBtn.BorderSizePixel = 0

    makeDraggable(MainFrame, TitleBar)

    do
        local ln = Instance.new("Frame", MainFrame)
        ln.Size = UDim2.new(1, -24, 0, 1)
        ln.Position = UDim2.new(0, 12, 0, 36)
        ln.BackgroundColor3 = UI.line
        ln.BackgroundTransparency = 0.45
        ln.BorderSizePixel = 0
    end

    local Content = Instance.new("Frame", MainFrame)
    Content.Size = UDim2.new(1, -16, 1, -46)
    Content.Position = UDim2.new(0, 8, 0, 42)
    Content.BackgroundTransparency = 1

    local ChipBar = Instance.new("ScrollingFrame", Content)
    ChipBar.Size = UDim2.new(1, 0, 0, 24)
    ChipBar.BackgroundTransparency = 1
    ChipBar.BorderSizePixel = 0
    ChipBar.ScrollBarThickness = 0
    ChipBar.ScrollingDirection = Enum.ScrollingDirection.X
    ChipBar.AutomaticCanvasSize = Enum.AutomaticSize.X
    ChipBar.CanvasSize = UDim2.new()
    local ChipLayout = Instance.new("UIListLayout", ChipBar)
    ChipLayout.FillDirection = Enum.FillDirection.Horizontal
    ChipLayout.Padding = UDim.new(0, 4)
    ChipLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local CatScrolls, CatChips = {}, {}
    local function SelectCategory(cat)
        for c, sc in pairs(CatScrolls) do sc.Visible = (c == cat) end
        for c, chip in pairs(CatChips) do
            chip.BackgroundColor3 = (c == cat) and Color3.fromRGB(180, 45, 50) or Color3.fromRGB(40, 58, 48)
            chip.TextColor3 = (c == cat) and Color3.new(1, 1, 1) or UI.text
        end
    end

    for idx, cat in ipairs(Categories) do
        local sc = Instance.new("ScrollingFrame", Content)
        sc.Size = UDim2.new(1, 0, 0, 150)
        sc.Position = UDim2.new(0, 0, 0, 30)
        sc.BackgroundTransparency = 1
        sc.BorderSizePixel = 0
        sc.ScrollBarThickness = 3
        sc.ScrollBarImageColor3 = UI.line
        sc.CanvasSize = UDim2.new()
        sc.Visible = false
        CatScrolls[cat] = sc
        local grid = Instance.new("UIGridLayout", sc)
        grid.CellSize = UDim2.new(0.48, 0, 0, 28)
        grid.CellPadding = UDim2.fromOffset(5, 5)
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        Track(grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            sc.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 6)
        end))

        local chip = Instance.new("TextButton", ChipBar)
        chip.LayoutOrder = idx
        chip.Size = UDim2.new(0, 0, 1, 0)
        chip.AutomaticSize = Enum.AutomaticSize.X
        chip.BackgroundColor3 = Color3.fromRGB(40, 58, 48)
        chip.Text = cat
        chip.TextColor3 = UI.text
        chip.Font = UI.font
        chip.TextSize = 12
        Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 8)
        local pad = Instance.new("UIPadding", chip)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 8)
        CatChips[cat] = chip
        Track(chip.MouseButton1Click:Connect(function() SelectCategory(cat) end))
    end

    local orderInCat = {}
    for _, entry in ipairs(BeamList) do
        local cat, name, colors = entry[1], entry[2], entry[3]
        orderInCat[cat] = (orderInCat[cat] or 0) + 1
        local btn = Instance.new("TextButton")
        btn.LayoutOrder = orderInCat[cat]
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextStrokeTransparency = 0.4
        btn.Font = UI.font
        btn.TextSize = 12
        btn.AutoButtonColor = true
        btn.Text = name
        btn.Parent = CatScrolls[cat]
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        if #colors > 0 then
            btn.BackgroundColor3 = Color3.new(1, 1, 1)
            local g = Instance.new("UIGradient", btn)
            g.Color = CreateSmoothSequence(colors)
        else
            btn.BackgroundColor3 = Color3.fromRGB(180, 45, 50)
            btn.Text = "★ " .. name
        end
        Track(btn.MouseButton1Click:Connect(function()
            CurrentBeamMode = name
            if name == ORIGINAL_KEY then NeedRestoreOriginal = true end
        end))
    end
    SelectCategory("ORIGINAL")

    local function StyleToggle(btn, text, on, onColor)
        btn.Text = text .. (on and ": ON" or ": OFF")
        btn.BackgroundColor3 = on and onColor or Color3.fromRGB(40, 58, 48)
    end

    NeonEnabled = false -- neon removed

    local GlowToggle = Instance.new("TextButton", Content)
    GlowToggle.Size = UDim2.new(1, 0, 0, 28)
    GlowToggle.Position = UDim2.new(0, 0, 0, 188)
    GlowToggle.TextColor3 = Color3.new(1, 1, 1)
    GlowToggle.Font = UI.font
    GlowToggle.TextSize = 13
    GlowToggle.BorderSizePixel = 0
    Instance.new("UICorner", GlowToggle).CornerRadius = UDim.new(0, 8)
    StyleToggle(GlowToggle, "GLOW", IsGlowEnabled, Color3.fromRGB(180, 45, 50))
    Track(GlowToggle.MouseButton1Click:Connect(function()
        IsGlowEnabled = not IsGlowEnabled
        StyleToggle(GlowToggle, "GLOW", IsGlowEnabled, Color3.fromRGB(180, 45, 50))
    end))

    local BrightLabel = Instance.new("TextLabel", Content)
    BrightLabel.Size = UDim2.new(1, 0, 0, 16)
    BrightLabel.Position = UDim2.new(0, 0, 0, 224)
    BrightLabel.BackgroundTransparency = 1
    BrightLabel.Text = "Brightness: 1.00"
    BrightLabel.TextColor3 = UI.text
    BrightLabel.Font = UI.font
    BrightLabel.TextSize = 13
    BrightLabel.TextXAlignment = Enum.TextXAlignment.Left

    local BrightSlider = Instance.new("TextButton", Content)
    BrightSlider.Size = UDim2.new(1, 0, 0, 16)
    BrightSlider.Position = UDim2.new(0, 0, 0, 242)
    BrightSlider.BackgroundColor3 = Color3.fromRGB(40, 58, 48)
    BrightSlider.Text = ""
    BrightSlider.AutoButtonColor = false
    BrightSlider.BorderSizePixel = 0
    Instance.new("UICorner", BrightSlider).CornerRadius = UDim.new(0, 6)
    local BrightFill = Instance.new("Frame", BrightSlider)
    BrightFill.Size = UDim2.new(1, 0, 1, 0)
    BrightFill.BackgroundColor3 = Color3.fromRGB(200, 160, 70)
    BrightFill.BorderSizePixel = 0
    Instance.new("UICorner", BrightFill).CornerRadius = UDim.new(0, 6)

    local SliderActive = false
    local function UpdateSlider(posX)
        if not SliderActive then return end
        local percent = math.clamp((posX - BrightSlider.AbsolutePosition.X) / math.max(BrightSlider.AbsoluteSize.X, 1), 0, 1)
        BrightFill.Size = UDim2.new(percent, 0, 1, 0)
        GlowIntensity = percent
        BrightLabel.Text = string.format("Brightness: %.2f", GlowIntensity)
    end
    Track(BrightSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            SliderActive = true
            UpdateSlider(input.Position.X)
        end
    end))
    Track(UserInputService.InputChanged:Connect(function(input)
        if SliderActive and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateSlider(input.Position.X)
        end
    end))
    Track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            SliderActive = false
        end
    end))

    Track(CloseBtn.MouseButton1Click:Connect(function()
        beamGui.Enabled = false
    end))

    local beamScanAcc = 0
    local CachedBeams = {}

    Track(RunService.Heartbeat:Connect(function(dt)
        if not Running or not beamGui.Parent then return end
        beamScanAcc = beamScanAcc + (dt or 0.016)
        -- rescan often so new Workspace.Part.Beam / tool beams get color immediately
        if beamScanAcc >= 0.08 or #CachedBeams == 0 then
            beamScanAcc = 0
            CachedBeams = FindAllBeams()
            CurrentBeam = CachedBeams[1]
            if CurrentBeam and HasBrightness then
                pcall(function() BaseBrightness = CurrentBeam.Brightness end)
            end
        end
        if #CachedBeams == 0 then return end

        local restoredThisFrame = false
        for _, beam in ipairs(CachedBeams) do
            if beam and beam.Parent then
                applyOneBeam(beam)
                if CurrentBeamMode == ORIGINAL_KEY then
                    restoredThisFrame = true
                end
            end
        end
        if restoredThisFrame and NeedRestoreOriginal then
            NeedRestoreOriginal = false
        end
        if NeonEnabled and CurrentBeam then
            UpdateHalo(CurrentBeam)
        end
    end))
end

-- ===== ADVANCED BUTTONS (always unlocked — key removed) =====
UI.separator(scroll, 10.02)
UI.header(scroll, 10.03, "advanced")

local gearBtn = UI.action(scroll, 10.05, "Gear", function()
    -- Gear panel = external Gears Mmv (loadstring)
    local function findGearsGui()
        local names = { "GearsMmvPanel", "Gears Mmv Panel" }
        local parents = {}
        pcall(function() table.insert(parents, game:GetService("CoreGui")) end)
        pcall(function() table.insert(parents, player:FindFirstChild("PlayerGui") or pg) end)
        for _, parent in ipairs(parents) do
            if parent then
                for _, n in ipairs(names) do
                    local g = parent:FindFirstChild(n)
                    if g then return g end
                end
                for _, ch in ipairs(parent:GetChildren()) do
                    if ch:IsA("ScreenGui") then
                        local ln = string.lower(ch.Name)
                        if string.find(ln, "gears", 1, true) or string.find(ln, "mmv", 1, true) then
                            return ch
                        end
                    end
                end
            end
        end
        return nil
    end
    local existing = findGearsGui()
    if existing then
        pcall(function() existing:Destroy() end)
        print("[CNP] Gears panel closed")
        return
    end
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/antonioffxslegend-collab/Gears/main/script.lua"))()
    end)
    if ok then
        print("[CNP] Gears Mmv Panel loaded")
    else
        warn("[CNP] Failed to load Gears panel: ", err)
    end
end)

local beamBtn = UI.action(scroll, 10.06, "Beam", function()
    beamGui.Enabled = not beamGui.Enabled
end)

end
CNP_GearSection()

-- =====================================================================
-- CHARACTER HOOK
-- =====================================================================
local function onCharacterAdded(char)
    climbLaunched = false
    speedSetupCharacter(char)
    setupGunSystem(char)
    task.defer(function()
        local bag = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
        if bag then bp = bag end
    end)
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

print(" — made by sabrine")

local BASE_SPEED = 16
-- SPEED (after unlock):  no flick = 45  |  flick = slider value  |  shake hard = even higher
local SPEED_VALUE = 120       -- slider 80..300 : speed while flicking
local FLICK_SENS = 1.8
local STRAFE_MULT = 1.12      -- A/D while flicking feeds a little more into the shake
local FORWARD_MULT = 1.05
local SPEEDCFG = {
    noFlick = 45,        -- speed when unlocked but NOT flicking
    flickFullAt = 4,     -- flick strength where speed == slider value
    overAt = 30,         -- flick strength where the extra "shake" bonus is maxed
    overshoot = 0.40,    -- max extra = slider value * this (hard shake)
    hardCap = 420,       -- never go above this
    upTime = 0.07,       -- seconds to rise  (smaller = snappier)
    downTime = 0.18,     -- seconds to fall  (bigger = smoother)
    hold = 0.10,         -- keep a flick alive this long so shaking back and forth stays smooth
}
function SPEEDCFG.target(boost)
    local V = SPEED_VALUE
    local base = math.min(SPEEDCFG.noFlick, V)
    local t = math.clamp((boost - 1.5) / (SPEEDCFG.flickFullAt - 1.5), 0, 1)
    t = t * t * (3 - 2 * t)                       -- smoothstep: no sudden jump
    local sp = base + (V - base) * t
    if boost > SPEEDCFG.flickFullAt then
        local o = math.clamp((boost - SPEEDCFG.flickFullAt) / (SPEEDCFG.overAt - SPEEDCFG.flickFullAt), 0, 1)
        o = 1 - (1 - o) * (1 - o)                 -- climbs fast, then saturates
        sp = sp + V * SPEEDCFG.overshoot * o
    end
    return math.clamp(sp, 0, SPEEDCFG.hardCap)
end
-- gear (carpets, coils, bomb, hair dryer, waterbow, fly...) must NOT trigger speed / flick
SPEEDCFG.gear = {
    ["rainbow carpet"] = true, ["blood carpet"] = true, ["cinnamoroll carpet"] = true,
    ["flying carpet"] = true, ["hairdryer"] = true, ["waterbow"] = true, ["bomb"] = true,
    ["speedcoil"] = true, ["gravitycoil"] = true, ["dualgravitycoil"] = true,
}
function SPEEDCFG.gearActive(char, tool)
    if tool and SPEEDCFG.gear[string.lower(tool.Name)] then return true end
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        for _, c in ipairs(root:GetChildren()) do
            if (c:IsA("BodyMover") or c:IsA("LinearVelocity") or c:IsA("VectorForce")
                or c:IsA("AlignPosition")) and c.Name ~= "CNP_ClimbLaunch" then
                return true
            end
        end
    end
    return false
end
-- critically damped smoothing (Unity SmoothDamp): no overshoot, no stair-stepping
function SPEEDCFG.damp(cur, target, vel, smoothTime, dt)
    smoothTime = math.max(0.0001, smoothTime)
    local omega = 2 / smoothTime
    local x = omega * dt
    local e = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
    local change = cur - target
    local temp = (vel + omega * change) * dt
    vel = (vel - omega * temp) * e
    local out = target + (change + temp) * e
    if (target - cur > 0) == (out > target) then
        out = target
        vel = 0
    end
    return out, vel
end
local SPEED_LERP_DOWN = 14
local MOUSE_SMOOTH = 0.45
local EMOTE_MIN_LENGTH = 1.5
CNP_DEBUG_ANIM = false  -- prints animation ids in the console while testing speed unlock
CNP_SEEN_ANIM = {}
local SPEED_ANIMATION_IDS = {
    ["15610015346"] = true,
    ["14353423348"] = true,
    ["79867635155472"] = true,
    ["107481557610007"] = true,
    ["15609995579"] = true,    -- ybjump
    ["14352343065"] = true,    -- freespirit
    ["96806611330323"] = true, -- Animation1 (plays with every emote; remove if speed unlocks without emoting)
}

-- speedMode: "speed" = flat speed no flick needed | "flick" = old unlock+flick logic
local speedMode = "speed"

-- Climb launch (only when speed on) — rebalanced
local LAUNCH_SPEED = 145
local LAUNCH_FLICK = 195
local LAUNCH_MAX = 230
local climbLaunched = false

local actionSound = Instance.new("Sound")
actionSound.SoundId = SOUND_ID
actionSound.Volume = 0.3
actionSound.Parent = SoundService

-- =====================================================================
-- STATE
-- =====================================================================
local noReloadActive = false
local autoEquipActive = false
local enableOldShiftLock = false
local enableOldCamera = false -- removed from UI
local oldAnimActive = false
local speedEnabled = false
local coilSpeedBoost = false
local coilActiveSpeed = 16
local muteSheriffActive = false
local oldBubbleChatActive = false
local micActive = false
local antiflingActive = false

local speedHumanoid
local memorizedTool = nil
local memorizedToolName = nil
local isEmoting = false

local Config = {
    Cooldown = 2,
    CanUse = true,
    BombColor = Color3.fromRGB(255, 180, 50),
    ToolName = "Gold C4 Bomb",
    BombAmount = 1,
}
local CurrentDroppedBomb = nil
local ActiveTools = {}

-- =====================================================================
-- 2. CAMERA / SHIFT LOCK
-- =====================================================================
local cameraOffsetY = 0.5
local shiftLockBaseY = 1.5
local shiftLockX = 2
local shiftLockZ = 0

local camRP = RaycastParams.new()
camRP.FilterType = Enum.RaycastFilterType.Exclude

-- Hide Roblox default shiftlock / mouselock icons (lightweight)
local function hideDefaultShiftIcons()
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or getViewport()
    local center = vp / 2
    local function nuke(v)
        pcall(function()
            if v:IsA("ImageLabel") or v:IsA("ImageButton") then
                v.ImageTransparency = 1
            end
            if v:IsA("GuiObject") then
                v.Visible = false
            end
        end)
    end
    local function looksLock(n)
        n = string.lower(n or "")
        return n:find("mouselock", 1, true)
            or n:find("shiftlock", 1, true)
            or n:find("mouse_lock", 1, true)
            or n:find("shift_lock", 1, true)
            or n:find("mouseicon", 1, true)
            or n:find("lockicon", 1, true)
    end
    local function isOursGui(sn)
        return sn:sub(1, 4) == "CNP_" or sn == "Fog_Panel" or sn == "Fog_Icon"
            or sn == "C4_Modern_Menu" or sn == "ListUserPanel"
            or sn == "Old2023ChatGui"
    end
    local function scan(root)
        for _, sg in ipairs(root:GetChildren()) do
            if sg:IsA("ScreenGui") and not isOursGui(sg.Name) then
                for _, d in ipairs(sg:GetDescendants()) do
                    if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                        if looksLock(d.Name) or looksLock(sg.Name) then
                            nuke(d)
                        end
                    end
                end
            end
        end
    end
    scan(pg)
    pcall(function() scan(game:GetService("CoreGui")) end)
end

-- Shiftlock 2023: only CameraOffset XYZ while locked (PC safe)
local SHIFTLOCK_2023_OFFSET = Vector3.new(1.75, 0, 0)
local SHIFTLOCK_BIND = "CNP_Shiftlock2023"
local _slWasLocked = false

pcall(function() RunService:UnbindFromRenderStep(SHIFTLOCK_BIND) end)
pcall(function() RunService:UnbindFromRenderStep("CNP_CamOffset") end)

RunService:BindToRenderStep(SHIFTLOCK_BIND, Enum.RenderPriority.Camera.Value + 1, function()
    if not enableOldShiftLock then
        if _slWasLocked then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.CameraOffset == SHIFTLOCK_2023_OFFSET then
                hum.CameraOffset = Vector3.zero
            end
            _slWasLocked = false
        end
        return
    end

    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
    if locked then
        -- only write classic XYZ offset; do not touch other systems
        if hum.CameraOffset ~= SHIFTLOCK_2023_OFFSET then
            hum.CameraOffset = SHIFTLOCK_2023_OFFSET
        end
        _slWasLocked = true
    elseif _slWasLocked then
        -- unlock edge: clear only our offset
        if hum.CameraOffset == SHIFTLOCK_2023_OFFSET then
            hum.CameraOffset = Vector3.zero
        end
        _slWasLocked = false
    end
end)

-- =====================================================================
-- 3. SPEED (Mobile Flick & Strafe Boost)
-- =====================================================================
local FLICK_DEAD_PC     = 130
local FLICK_REF_PC      = 520
local FLICK_DEAD_MOBILE = 30
local FLICK_REF_MOBILE  = 150
local FLICK_A, FLICK_B, FLICK_C = 28, 12, 4

local function flickCurve(x)
    if x <= 0 then return 0 end
    return FLICK_A * x + FLICK_B * x * x + FLICK_C * x * x * x
end

local speedConnections = {}
local isUnlocked = false
local emotePlayedFirst = false
local lastCamYaw = nil
local flickBoost = 0
local smoothMouseRate = 0
local renderFlickTarget = 0
local landSlideUntil = 0
local smoothWalkSpeed = BASE_SPEED
local landBrakeUntil = 0
local jumpStack = 0
local prevInAir = false
local SPD = { vel = 0, hold = 0 }

local function speedDisconnectAll()
    for _, c in ipairs(speedConnections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    for i = #speedConnections, 1, -1 do speedConnections[i] = nil end
    isUnlocked = false
    emotePlayedFirst = false
end

local function checkIsEmoting(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:FindFirstChild("Animator")
    if not animator then return false end
    local char = humanoid.Parent
    local holdingTool = char and char:FindFirstChildOfClass("Tool")
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local anim = track.Animation
        if anim and track.IsPlaying then
            local id = tostring(anim.AnimationId):match("%d+")
            if id and SPEED_ANIMATION_IDS[id] then
                return true
            end
            -- fallback: any long emote-priority animation while NOT holding a tool
            -- (emote hub emotes have many different ids, so the id list alone misses them)
            if not holdingTool
                and (track.Priority == Enum.AnimationPriority.Action4
                    or track.Priority == Enum.AnimationPriority.Action3)
                and track.Length > EMOTE_MIN_LENGTH then
                return true
            end
            -- debug: print ids of animations that did not unlock (set CNP_DEBUG_ANIM = true)
            if CNP_DEBUG_ANIM and id and not CNP_SEEN_ANIM[id] then
                CNP_SEEN_ANIM[id] = true
                print("[CNP] anim id:", id, "priority:", tostring(track.Priority), "len:", track.Length)
            end
        end
    end
    return false
end

local function isGunOrKnife(tool)
    if not tool then return false end
    local n = string.lower(tool.Name)
    return n == "gun" or n == "knife"
end

-- speed allowed after unlock (emote + any tool): empty hand OR any tool
local function canSpeedWithTool(tool)
    return isUnlocked and true or false
end

local function speedResetUnlock()
    isUnlocked = false
    emotePlayedFirst = false
    memorizedTool = nil
    memorizedToolName = nil
    flickBoost = 0
    lastCamYaw = nil
    smoothMouseRate = 0
    smoothWalkSpeed = BASE_SPEED
    landBrakeUntil = 0
    renderFlickTarget = 0
    jumpStack = 0
    prevInAir = false
    SPD.vel = 0
    SPD.hold = 0
    if speedHumanoid and speedHumanoid.Parent then
        if speedHumanoid.WalkSpeed > BASE_SPEED then
            speedHumanoid.WalkSpeed = BASE_SPEED
        end
    end
end

local function isSafeSpeedTool(tool)
    -- Sau unlock chi giu speed khi: tay khong HOAC Gun/Knife
    -- Cam bat ky tool khac (ke ca tool vua dung de unlock) → mat speed
    if not tool then return true end
    if SPEED_SAFE_TOOLS[tool.Name] then return true end
    return false
end

-- Anti-fling when jumping into walls
local function dampWallFling(root, char)
    if not root or not char then return end
    -- while speed glitch is on, do not kill velocity (causes rubberband)
    if speedEnabled then return end
    local v = root.AssemblyLinearVelocity
    local horiz = Vector3.new(v.X, 0, v.Z)
    if horiz.Magnitude < 55 then return end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { char }
    local origin = root.Position
    local d = horiz.Unit
    local hit = Workspace:Raycast(origin, d * 1.6, rp)
    if not hit then return end
    local n = hit.Normal
    local into = horiz:Dot(Vector3.new(-n.X, 0, -n.Z))
    if into <= 8 then return end
    local nn = Vector3.new(-n.X, 0, -n.Z)
    if nn.Magnitude < 0.05 then return end
    local nv = horiz - nn.Unit * (into * 0.55)
    local flingCap = math.max(180, SPEED_VALUE * (1 + SPEEDCFG.overshoot) * 1.25)
    if nv.Magnitude > flingCap then
        nv = nv.Unit * flingCap
    end
    root.AssemblyLinearVelocity = Vector3.new(nv.X, v.Y, nv.Z)
end

local function speedSetupCharacter(char)
    speedDisconnectAll()
    speedHumanoid = char:WaitForChild("Humanoid", 10)
    if not speedHumanoid then return end
    task.wait()
    speedResetUnlock()

    table.insert(speedConnections, RunService.RenderStepped:Connect(function(rdt)
        local cam = Workspace.CurrentCamera
        local dts = math.max(rdt, 1/240)
        local x = 0
        if not isMobile then
            local md = UserInputService:GetMouseDelta()
            local rawRate = math.sqrt(md.X * md.X + md.Y * md.Y) / dts
            if rawRate > 4000 then rawRate = smoothMouseRate end
            smoothMouseRate = smoothMouseRate + (rawRate - smoothMouseRate)
                * math.clamp(MOUSE_SMOOTH + rdt * 2, 0.05, 1)
            if smoothMouseRate > FLICK_DEAD_PC then
                x = math.max(x, (smoothMouseRate - FLICK_DEAD_PC) / FLICK_REF_PC)
            end
        end
        if cam then
            local look = cam.CFrame.LookVector
            local yaw = math.deg(math.atan2(-look.X, -look.Z))
            if lastCamYaw then
                local d = math.abs(((yaw - lastCamYaw + 180) % 360) - 180)
                local rate = d / dts
                if isMobile then
                    if rate > 2500 then rate = smoothMouseRate end
                    smoothMouseRate = smoothMouseRate + (rate - smoothMouseRate)
                        * math.clamp(0.32 + rdt * 2, 0.05, 0.7)
                    rate = smoothMouseRate
                    if rate > FLICK_DEAD_MOBILE then
                        x = math.max(x, (rate - FLICK_DEAD_MOBILE) / FLICK_REF_MOBILE)
                    end
                elseif rate > FLICK_DEAD_MOBILE * 3 then
                    x = math.max(x, (rate - FLICK_DEAD_MOBILE * 3) / (FLICK_REF_MOBILE * 3))
                end
            end
            lastCamYaw = yaw
        end
        renderFlickTarget = flickCurve(x * FLICK_SENS)
    end))

    local emoteCheckAccum = 0
    table.insert(speedConnections, RunService.Heartbeat:Connect(function(dt)
        if not speedHumanoid or not speedHumanoid.Parent or speedHumanoid.Health <= 0 then return end


        if speedHumanoid.PlatformStand or speedHumanoid.Sit then return end
        local state = speedHumanoid:GetState()
        if state == Enum.HumanoidStateType.Seated
           or state == Enum.HumanoidStateType.PlatformStanding then return end

        if state == Enum.HumanoidStateType.Climbing then
            if speedHumanoid.WalkSpeed > BASE_SPEED + 0.5 then
                speedHumanoid.WalkSpeed = BASE_SPEED
                smoothWalkSpeed = BASE_SPEED
            end
            return
        end

        local currentTool = char:FindFirstChildOfClass("Tool")
        local inAir = state == Enum.HumanoidStateType.Jumping
            or state == Enum.HumanoidStateType.Freefall
            or state == Enum.HumanoidStateType.FallingDown

        local root = char:FindFirstChild("HumanoidRootPart")
        local now = os.clock()

        -- no emote / tool condition: speed is active as soon as the toggle is on
        if speedEnabled and not isUnlocked then
            isUnlocked = true
        end

        local speedOk = speedEnabled and canSpeedWithTool(currentTool)
            and not SPEEDCFG.gearActive(char, currentTool)

        if speedOk then
            if inAir then
                landSlideUntil = 0
                -- flick strength: fast attack, short hold, smooth release
                do
                    local target = renderFlickTarget
                    local k = math.clamp(dt * 60, 0, 4)
                    if target > flickBoost then
                        flickBoost = flickBoost + (target - flickBoost) * (1 - 0.5 ^ k)
                        SPD.hold = now + SPEEDCFG.hold
                    elseif now > SPD.hold then
                        flickBoost = math.max(target, flickBoost * math.exp(-dt * 6.5))
                        if flickBoost < 0.2 then flickBoost = 0 end
                    end
                end

                local keyA = UserInputService:IsKeyDown(Enum.KeyCode.A)
                local keyD = UserInputService:IsKeyDown(Enum.KeyCode.D)
                local keyW = UserInputService:IsKeyDown(Enum.KeyCode.W)
                if not (keyA or keyD or keyW) then
                    local mdir = speedHumanoid.MoveDirection
                    local cam = Workspace.CurrentCamera
                    if cam and mdir.Magnitude > 0.1 then
                        local lv = cam.CFrame:VectorToObjectSpace(mdir)
                        if math.abs(lv.X) > 0.25 then keyA = true; keyD = true end
                        if lv.Z < -0.25 then keyW = true end
                    end
                end

                local boost = flickBoost
                local keyMul = 1
                if (keyA or keyD) and boost > 1.5 then
                    keyMul = keyMul * (STRAFE_MULT + math.clamp(boost / 60, 0, 0.3))
                end
                if keyW and boost > 1.5 then
                    keyMul = keyMul * FORWARD_MULT
                end
                boost = boost * keyMul
                prevInAir = true

                -- no flick -> 45 | flick -> slider value | hard shake -> higher
                local desired = SPEEDCFG.target(boost)
                local tConst = (desired > smoothWalkSpeed) and SPEEDCFG.upTime or SPEEDCFG.downTime
                smoothWalkSpeed, SPD.vel = SPEEDCFG.damp(smoothWalkSpeed, desired, SPD.vel, tConst, dt)
                if math.abs(speedHumanoid.WalkSpeed - smoothWalkSpeed) > 0.02 then
                    speedHumanoid.WalkSpeed = smoothWalkSpeed
                end

                -- air assist (wall-safe): pulls horizontal velocity toward the speed, never slows you down
                -- mild air boost only (no hard rewrite → less rubberband)
                if root and smoothWalkSpeed > BASE_SPEED + 8 then
                    local md = speedHumanoid.MoveDirection
                    if md.Magnitude > 0.2 then
                        local dir = Vector3.new(md.X, 0, md.Z)
                        if dir.Magnitude > 0.05 then
                            dir = dir.Unit
                            local v = root.AssemblyLinearVelocity
                            local cur = Vector3.new(v.X, 0, v.Z)
                            local along = cur:Dot(dir)
                            if along < smoothWalkSpeed * 0.92 then
                                local add = dir * ((smoothWalkSpeed - math.max(along, 0)) * math.clamp(dt * 6, 0, 0.35))
                                local nv = cur + add
                                root.AssemblyLinearVelocity = Vector3.new(nv.X, v.Y, nv.Z)
                            end
                        end
                    end
                end
                dampWallFling(root, char)
            else
                -- On ground
                lastCamYaw = nil
                flickBoost = 0
                smoothMouseRate = 0
                landSlideUntil = 0
                prevInAir = false
                jumpStack = 0

                smoothWalkSpeed, SPD.vel = SPEEDCFG.damp(smoothWalkSpeed, BASE_SPEED, SPD.vel, 0.14, dt)
                if math.abs(speedHumanoid.WalkSpeed - smoothWalkSpeed) > 0.05 then
                    speedHumanoid.WalkSpeed = math.max(BASE_SPEED, smoothWalkSpeed)
                end

                -- very soft ground slide (avoid yank back while speed glitch)
                if root and not speedEnabled then
                    local v = root.AssemblyLinearVelocity
                    local hx, hz = v.X, v.Z
                    local mag = math.sqrt(hx * hx + hz * hz)
                    local cap = BASE_SPEED + 40
                    if mag > cap then
                        local f = math.exp(-2.0 * dt)
                        local nh = math.max(cap, mag * f)
                        local sc = nh / mag
                        root.AssemblyLinearVelocity = Vector3.new(hx * sc, v.Y, hz * sc)
                    end
                end
                dampWallFling(root, char)
            end
        else
            if flickBoost ~= 0 or lastCamYaw then
                flickBoost = 0
                lastCamYaw = nil
                smoothMouseRate = 0
            end
            landSlideUntil = 0
            SPD.vel = 0
            -- if SpeedCoil equipped, don't clamp WalkSpeed back to 16
            if coilSpeedBoost then
                local target = coilActiveSpeed or BASE_SPEED
                if math.abs(speedHumanoid.WalkSpeed - target) > 0.5 then
                    speedHumanoid.WalkSpeed = target
                end
                smoothWalkSpeed = target
            else
                smoothWalkSpeed = smoothWalkSpeed + (BASE_SPEED - smoothWalkSpeed)
                    * (1 - math.exp(-SPEED_LERP_DOWN * dt))
                if speedHumanoid.WalkSpeed > BASE_SPEED + 0.4 then
                    speedHumanoid.WalkSpeed = math.max(BASE_SPEED, smoothWalkSpeed)
                end
            end
        end
    end))

    table.insert(speedConnections, char.ChildAdded:Connect(function(child)
        if not child:IsA("Tool") then return end
        if not speedEnabled then return end
        -- remember any tool after emote; unlock sticks
        if emotePlayedFirst or isEmoting then
            memorizedTool = child
            memorizedToolName = child.Name
            isUnlocked = true
        elseif isUnlocked then
            memorizedTool = child
        end
    end))

    table.insert(speedConnections, speedHumanoid.Died:Connect(function()
        speedResetUnlock()
        speedHumanoid = nil
        climbLaunched = false
    end))
end

-- =====================================================================
-- CLIMB LAUNCH (integrated with speed)
-- no speed -> none | speed on (no flick) ~145-170 | speed + flick ~195-225
-- =====================================================================
local function doClimbLaunch()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    if hum:GetState() ~= Enum.HumanoidStateType.Climbing then return end
    if climbLaunched then return end

    climbLaunched = true

    -- only launch when speed is on; max ~230
    if not speedEnabled then
        climbLaunched = false
        return
    end
    local power = LAUNCH_SPEED + math.random(0, 25)
    local flicking = (renderFlickTarget and renderFlickTarget > 6)
        or (flickBoost and flickBoost > 6)
    if flicking then
        power = LAUNCH_FLICK + math.random(0, 30)
    end
    power = math.clamp(power, 120, LAUNCH_MAX)

    local bv = Instance.new("BodyVelocity")
    bv.Name = "CNP_ClimbLaunch"
    bv.Velocity = Vector3.new(0, power, 0)
    bv.MaxForce = Vector3.new(0, math.huge, 0)
    bv.Parent = root

    task.delay(0.28, function()
        if bv and bv.Parent then bv:Destroy() end
    end)

    -- Reset flag when leaving climb
    task.spawn(function()
        while hum and hum.Parent and hum:GetState() == Enum.HumanoidStateType.Climbing do
            task.wait(0.1)
        end
        climbLaunched = false
    end)
end

UserInputService.JumpRequest:Connect(function()
    doClimbLaunch()
end)

-- Mobile fallback: TouchGui JumpButton
task.spawn(function()
    local PlayerGui = player:WaitForChild("PlayerGui")
    local TouchGui = PlayerGui:WaitForChild("TouchGui", 10)
    if TouchGui then
        local TouchControlFrame = TouchGui:WaitForChild("TouchControlFrame", 5)
        if TouchControlFrame then
            local JumpButton = TouchControlFrame:WaitForChild("JumpButton", 5)
            if JumpButton then
                JumpButton.MouseButton1Down:Connect(function()
                    doClimbLaunch()
                end)
            end
        end
    end
end)

-- =====================================================================
-- 4. GUN SYSTEM
-- =====================================================================
local function setupGunSystem(character)
    if not character then return end
    local humanoid = character:WaitForChild("Humanoid", 10); if not humanoid then return end
    local animator = humanoid:WaitForChild("Animator", 10); if not animator then return end
    local lastUnequippedTime = 0
    animator.AnimationPlayed:Connect(function(track)
        if not noReloadActive then return end
        local tool = character:FindFirstChildOfClass("Tool")
        if (tool and tool.Name == TARGET_TOOL_NAME
            or (os.clock() - lastUnequippedTime) <= COOLDOWN_DURATION)
            and track.Priority == Enum.AnimationPriority.Action then
            track:Stop()
        end
    end)
    character.ChildAdded:Connect(function(c)
        if c:IsA("Tool") and c.Name == TARGET_TOOL_NAME then
            actionSound:Play()
            if autoEquipActive then humanoid:EquipTool(c) end
        end
    end)
    character.ChildRemoved:Connect(function(c)
        if c:IsA("Tool") and c.Name == TARGET_TOOL_NAME then
            actionSound:Play()
            lastUnequippedTime = os.clock()
        end
    end)
end

-- =====================================================================
-- 5. CHAT BUBBLES
-- =====================================================================
local LS = {
    Font = Enum.Font.BuilderSansMedium,
    TextColor = Color3.fromRGB(25, 25, 25),
    MinWidth = 40, MinHeight = 30,
    CornerRadius = 4,
    MaxBubbles = 3, BubbleTime = 10, OldBubbleTime = 5, FadeTime = 0.5,
    NewBubbleTransparency = 0, OldBubbleTransparency = 0.4,
    HeadGap = 0.45,
    MaxDistance = 100, FarDistance = 40, ScaleStart = 15, MinScale = 0.6,
    Gap = 4,
    TextSize = 18, MaxWidth = 300,
    TailSize = 24, TailProtrusion = 22,
    TailOffsetX = 0, TailOffsetY = -6, TailOffsetZ = 0,
    -- Local XYZ on head: X = left/right, Y = up, Z = back/forward
    -- (+Z = behind head, -Z = in front of face)
    -- Stack like reference pic: mic on top, chat under it (above head)
    ChatOffset = Vector3.new(0, 0.45, 0),
    MicOffset  = Vector3.new(0, 1.5, 0),
    MicCornerRadius = 7, MicHeight = 1.5, MicTailSize = 10,
    MicDecal = "rbxasset://textures/ui/VoiceChat/Muted.png",
    MicX = 0, MicY = 0, MicSize = 32,
}
LS.Padding_X = 10
LS.Padding_Y = 4

local chatGui = nil
local chatConnections = {}
local playerBubbles = {}
local micGui = nil
local micFrame = nil

local function getHead(plr)
    local c = plr.Character
    return c and c:FindFirstChild("Head")
end

local function getBubbleSize(text)
    local innerMax = LS.MaxWidth - (LS.Padding_X * 2)
    local bounds = TextService:GetTextSize(text, LS.TextSize, LS.Font, Vector2.new(innerMax, 10000))
    local w = math.clamp(bounds.X + (LS.Padding_X * 2), LS.MinWidth, LS.MaxWidth)
    local h = math.max(bounds.Y + (LS.Padding_Y * 2), LS.MinHeight)
    return math.ceil(w), math.ceil(h)
end

local function cancelTimer(bubble)
    if bubble and bubble.timer then
        pcall(task.cancel, bubble.timer)
        bubble.timer = nil
    end
end

local function getContainer(plr)
    return chatGui and chatGui:FindFirstChild("P" .. tostring(plr.UserId))
end

local function clearPlayerGui(plr)
    local c = getContainer(plr)
    if c then c:Destroy() end
end

local function createTail(parent, yOffset, zIndex)
    local tailHolder = Instance.new("Frame")
    tailHolder.Name = "TailHolder"
    tailHolder.Size = UDim2.fromOffset(LS.TailSize, LS.TailProtrusion)
    tailHolder.AnchorPoint = Vector2.new(0.5, 0)
    tailHolder.Position = UDim2.new(0.5, LS.TailOffsetX, 0, yOffset + LS.TailOffsetY)
    tailHolder.BackgroundTransparency = 1
    tailHolder.ClipsDescendants = true
    tailHolder.ZIndex = zIndex + LS.TailOffsetZ
    tailHolder.Parent = parent

    local diamond = Instance.new("Frame")
    diamond.Name = "Diamond"
    diamond.Size = UDim2.fromOffset(LS.TailSize, LS.TailSize)
    diamond.AnchorPoint = Vector2.new(0.5, 0.5)
    diamond.Position = UDim2.new(0.5, 0, 0, 0)
    diamond.Rotation = 45
    diamond.BackgroundColor3 = Color3.new(1, 1, 1)
    diamond.BackgroundTransparency = LS.NewBubbleTransparency
    diamond.BorderSizePixel = 0
    diamond.ZIndex = tailHolder.ZIndex
    diamond.Parent = tailHolder
    Instance.new("UICorner", diamond).CornerRadius = UDim.new(0, 2)

    return tailHolder, diamond
end

local function createFarBubble(container)
    local w, h = 46, 30
    local far = Instance.new("Frame")
    far.Name = "Far"; far.AnchorPoint = Vector2.new(0.5, 1); far.Position = UDim2.new(0.5, 0, 1, 0)
    far.Size = UDim2.fromOffset(w, h + LS.TailProtrusion)
    far.BackgroundTransparency = 1; far.Visible = false; far.Parent = container

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(w, h)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.BorderSizePixel = 0; frame.ZIndex = 2; frame.Parent = far
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, LS.CornerRadius)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1
    label.Text = "..."; label.Font = LS.Font; label.TextSize = 22
    label.TextColor3 = LS.TextColor; label.ZIndex = 3; label.Parent = frame

    createTail(far, h, 1)
end

local function rebuildBubbles(plr)
    if not chatGui then return end
    local data = playerBubbles[plr]
    clearPlayerGui(plr)
    if not data or #data == 0 then return end

    local totalHeight, maxWidth = 0, 0
    for _, b in ipairs(data) do
        b.width, b.height = getBubbleSize(b.text)
        totalHeight = totalHeight + b.height
        maxWidth = math.max(maxWidth, b.width)
    end
    totalHeight = totalHeight + (LS.Gap * math.max(#data - 1, 0))

    local container = Instance.new("Frame")
    container.Name = "P" .. tostring(plr.UserId)
    container.Size = UDim2.fromOffset(math.max(maxWidth, 46), totalHeight + LS.TailProtrusion)
    container.AnchorPoint = Vector2.new(0.5, 1)
    container.Position = UDim2.new(0.5, 0, 1, 0)
    container.BackgroundTransparency = 1; container.BorderSizePixel = 0
    container.Visible = false; container.Parent = chatGui

    local uiScale = Instance.new("UIScale"); uiScale.Name = "DistanceScale"; uiScale.Parent = container
    createFarBubble(container)

    local stack = Instance.new("Frame")
    stack.Name = "Stack"; stack.Size = UDim2.fromScale(1, 1); stack.BackgroundTransparency = 1; stack.Parent = container
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, LS.Gap); layout.Parent = stack

    for index, b in ipairs(data) do
        local age = #data - index
        local wrapper = Instance.new("Frame")
        wrapper.Name = "Row"
        wrapper.Size = UDim2.fromOffset(b.width, b.height + (age == 0 and LS.TailProtrusion or 0))
        wrapper.LayoutOrder = index; wrapper.BackgroundTransparency = 1
        wrapper.BorderSizePixel = 0; wrapper.Parent = stack

        local frame = Instance.new("Frame")
        frame.Name = "Bubble"; frame.Size = UDim2.fromOffset(b.width, b.height)
        frame.BackgroundColor3 = Color3.new(1, 1, 1)
        frame.BackgroundTransparency = LS.NewBubbleTransparency
        frame.BorderSizePixel = 0; frame.ZIndex = 2
        frame:SetAttribute("BubbleID", b.id); frame.Parent = wrapper
        b.frame = frame
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, LS.CornerRadius)

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, LS.Padding_Y); pad.PaddingBottom = UDim.new(0, LS.Padding_Y)
        pad.PaddingLeft = UDim.new(0, LS.Padding_X); pad.PaddingRight = UDim.new(0, LS.Padding_X)
        pad.Parent = frame

        local label = Instance.new("TextLabel")
        label.Name = "Message"; label.BackgroundTransparency = 1; label.BorderSizePixel = 0
        label.Size = UDim2.fromScale(1, 1); label.Text = b.text; label.Font = LS.Font
        label.TextSize = LS.TextSize; label.TextColor3 = LS.TextColor
        label.TextWrapped = true; label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center; label.ZIndex = 3; label.Parent = frame

        if age >= 1 then
            local overlay = Instance.new("Frame")
            overlay.Name = "WhiteOverlay"; overlay.Size = UDim2.fromScale(1, 1)
            overlay.BackgroundColor3 = Color3.new(1, 1, 1)
            overlay.BackgroundTransparency = LS.OldBubbleTransparency
            overlay.BorderSizePixel = 0; overlay.ZIndex = 5; overlay.Parent = frame
            Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, LS.CornerRadius)
            label.TextTransparency = LS.OldBubbleTransparency
        end

        if age == 0 then
            b.tailHolder, b.tailDiamond = createTail(wrapper, b.height, 1)
        end
    end
end

local function removeBubble(plr, bubble)
    local data = playerBubbles[plr]
    if not data or bubble.removing then return end
    bubble.removing = true
    bubble.timer = nil

    local container = getContainer(plr)
    local stack = container and container:FindFirstChild("Stack")
    if stack then
        for _, wrapper in ipairs(stack:GetChildren()) do
            if wrapper:IsA("Frame") and wrapper.Name == "Row" then
                local frame = wrapper:FindFirstChild("Bubble")
                if frame and frame:GetAttribute("BubbleID") == bubble.id then
                    local info = TweenInfo.new(LS.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
                    local label = frame:FindFirstChild("Message")
                    if label then TweenService:Create(label, info, { TextTransparency = 1 }):Play() end
                    local overlay = frame:FindFirstChild("WhiteOverlay")
                    if overlay then TweenService:Create(overlay, info, { BackgroundTransparency = 1 }):Play() end
                    local th = wrapper:FindFirstChild("TailHolder")
                    local tailDiamond = th and th:FindFirstChild("Diamond")
                    if tailDiamond then TweenService:Create(tailDiamond, info, { BackgroundTransparency = 1 }):Play() end
                    break
                end
            end
        end
    end

    task.wait(LS.FadeTime)

    data = playerBubbles[plr]
    if not data then return end
    for i = #data, 1, -1 do
        if data[i] == bubble then table.remove(data, i); break end
    end
    if #data == 0 then
        playerBubbles[plr] = nil
        clearPlayerGui(plr)
    else
        rebuildBubbles(plr)
    end
end

local function addBubble(plr, text)
    playerBubbles[plr] = playerBubbles[plr] or {}
    local data = playerBubbles[plr]

    for _, old in ipairs(data) do
        if not old.removing then
            cancelTimer(old)
            old.timer = task.delay(LS.OldBubbleTime, function()
                if not old.removing then removeBubble(plr, old) end
            end)
        end
    end

    local bubble = {
        id = tostring(os.clock()) .. "_" .. tostring(math.random(100000, 999999)),
        text = tostring(text), width = 0, height = 0,
        timer = nil, frame = nil, removing = false,
    }
    table.insert(data, bubble)
    while #data > LS.MaxBubbles do
        local removed = table.remove(data, 1)
        cancelTimer(removed)
    end
    rebuildBubbles(plr)
    bubble.timer = task.delay(LS.BubbleTime, function()
        if not bubble.removing then removeBubble(plr, bubble) end
    end)
end

local function destroyOldChat()
    pcall(function() RunService:UnbindFromRenderStep("CNP_ChatBubblePositions") end)
    for _, c in ipairs(chatConnections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    for i = #chatConnections, 1, -1 do chatConnections[i] = nil end
    for _, data in pairs(playerBubbles) do
        for _, b in ipairs(data) do cancelTimer(b) end
    end
    for k in pairs(playerBubbles) do playerBubbles[k] = nil end
    if chatGui then chatGui:Destroy(); chatGui = nil end
    pcall(function() TextChatService.BubbleChatConfiguration.Enabled = true end)
end

local function initOldChat()
    if chatGui then return end
    pcall(function() TextChatService.BubbleChatConfiguration.Enabled = false end)

    local previous = pg:FindFirstChild("Old2023ChatGui")
    if previous then previous:Destroy() end

    chatGui = Instance.new("ScreenGui")
    chatGui.Name = "Old2023ChatGui"
    chatGui.ResetOnSpawn = false
    chatGui.IgnoreGuiInset = true
    chatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    chatGui.DisplayOrder = 10 -- chat behind mic
    chatGui.Parent = pg

    table.insert(chatConnections, TextChatService.MessageReceived:Connect(function(message)
        if not message.TextSource then return end
        local plr = Players:GetPlayerByUserId(message.TextSource.UserId)
        if plr then addBubble(plr, message.Text) end
    end))

    table.insert(chatConnections, Players.PlayerRemoving:Connect(function(plr)
        playerBubbles[plr] = nil
        clearPlayerGui(plr)
    end))

    local bubbleRP = RaycastParams.new()
    bubbleRP.FilterType = Enum.RaycastFilterType.Exclude
    bubbleRP.IgnoreWater = true
    RunService:BindToRenderStep("CNP_ChatBubblePositions",
        Enum.RenderPriority.Camera.Value + 5, function()
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local cameraPos = camera.CFrame.Position
        local vp = camera.ViewportSize
        local margin = 200

        for plr, data in pairs(playerBubbles) do
            local container = getContainer(plr)
            if container and #data > 0 then
                local head = getHead(plr)
                if not head then
                    container.Visible = false
                else
                    -- use head CFrame so shiftlock / CameraOffset stays accurate
                    local headPos = head.CFrame.Position
                    local distance = (cameraPos - headPos).Magnitude
                    local visibleThroughWall = true
                    if distance <= LS.MaxDistance then
                        local filter = { camera }
                        if plr.Character then table.insert(filter, plr.Character) end
                        if player.Character then table.insert(filter, player.Character) end
                        bubbleRP.FilterDescendantsInstances = filter
                        local direction = headPos - cameraPos
                        local hit = Workspace:Raycast(cameraPos, direction, bubbleRP)
                        if hit then
                            visibleThroughWall = false
                        end
                    end

                    if distance > LS.MaxDistance or not visibleThroughWall then
                        container.Visible = false
                    else
                        -- local XYZ on head (ChatOffset): Y height, -Z in front
                        local worldPos = head.CFrame:PointToWorldSpace(
                            Vector3.new(LS.ChatOffset.X, head.Size.Y / 2 + LS.ChatOffset.Y, LS.ChatOffset.Z)
                        )
                        local sp, onScreen = camera:WorldToViewportPoint(worldPos)
                        if sp.Z > 0 and sp.X > -margin and sp.X < vp.X + margin
                           and sp.Y > -margin and sp.Y < vp.Y + margin then
                            container.Visible = true
                            -- floor to whole pixels — reduces shiftlock “lệch” jitter
                            container.Position = UDim2.fromOffset(
                                math.floor(sp.X + 0.5),
                                math.floor(sp.Y + 0.5)
                            )
                            local t = (distance - LS.ScaleStart) / (LS.MaxDistance - LS.ScaleStart)
                            local scale = math.clamp(1 - t * (1 - LS.MinScale), LS.MinScale, 1)
                            local us = container:FindFirstChild("DistanceScale")
                            if us then us.Scale = scale end
                            local isFar = distance > LS.FarDistance
                            local stack = container:FindFirstChild("Stack")
                            local far = container:FindFirstChild("Far")
                            if stack then stack.Visible = not isFar end
                            if far then far.Visible = isFar end
                        else
                            container.Visible = false
                        end
                    end
                end
            end
        end
    end)
end

-- =====================================================================
-- MICROPHONE
-- =====================================================================
local function destroyMic()
    pcall(function() RunService:UnbindFromRenderStep("CNP_ChatMicPosition") end)
    if micGui then micGui:Destroy(); micGui = nil end
    micFrame = nil
end

local function initMic()
    if micGui then return end
    micGui = Instance.new("ScreenGui")
    micGui.Name = "CNP_MicGui"
    micGui.ResetOnSpawn = false
    micGui.IgnoreGuiInset = true
    micGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    micGui.DisplayOrder = 15 -- mic overlay in front of chat bubble
    micGui.Parent = pg

    micFrame = Instance.new("Frame")
    micFrame.Name = "MicBubble"
    micFrame.AnchorPoint = Vector2.new(0.5, 1)
    micFrame.Size = UDim2.fromOffset(LS.MicSize, LS.MicSize)
    micFrame.BackgroundTransparency = 1
    micFrame.ZIndex = 100; micFrame.Visible = false; micFrame.Parent = micGui

    local us = Instance.new("UIScale"); us.Name = "DistanceScale"; us.Parent = micFrame

    local body = Instance.new("Frame")
    body.Name = "Body"; body.Size = UDim2.fromScale(1, 1)
    body.BackgroundColor3 = Color3.new(1, 1, 1)
    body.BorderSizePixel = 0; body.ZIndex = 2; body.Parent = micFrame
    Instance.new("UICorner", body).CornerRadius = UDim.new(0, LS.MicCornerRadius)

    local tail = Instance.new("Frame")
    tail.Name = "Tail"; tail.Size = UDim2.fromOffset(LS.MicTailSize, LS.MicTailSize)
    tail.AnchorPoint = Vector2.new(0.5, 0.5)
    tail.Position = UDim2.new(0.5, 0, 1, 0); tail.Rotation = 45
    tail.BackgroundColor3 = Color3.new(1, 1, 1)
    tail.BorderSizePixel = 0; tail.ZIndex = 1; tail.Parent = micFrame
    Instance.new("UICorner", tail).CornerRadius = UDim.new(0, 1)

    local img = Instance.new("ImageLabel")
    img.Name = "MicIcon"; img.Size = UDim2.fromScale(0.65, 0.65)
    img.Position = UDim2.fromScale(0.5, 0.5)
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.BackgroundTransparency = 1; img.Image = LS.MicDecal
    img.ScaleType = Enum.ScaleType.Fit; img.ZIndex = 3; img.Parent = body

    RunService:BindToRenderStep("CNP_ChatMicPosition",
        Enum.RenderPriority.Camera.Value + 6, function()
        local camera = Workspace.CurrentCamera
        if not camera or not micFrame then return end
        local head = getHead(player)
        if not head then micFrame.Visible = false; return end
        local headPos = head.CFrame.Position
        local distance = (camera.CFrame.Position - headPos).Magnitude
        -- same height as chat bubble (shared Y)
        local worldPos = head.CFrame:PointToWorldSpace(
            Vector3.new(LS.MicOffset.X, head.Size.Y / 2 + LS.MicOffset.Y, LS.MicOffset.Z)
        )
        local sp = camera:WorldToViewportPoint(worldPos)
        if sp.Z <= 0 or distance > LS.MaxDistance then micFrame.Visible = false; return end
        local t = (distance - LS.ScaleStart) / (LS.MaxDistance - LS.ScaleStart)
        local scale = math.clamp(1 - t * (1 - LS.MinScale), LS.MinScale, 1)
        micFrame.Visible = true
        local s = micFrame:FindFirstChild("DistanceScale")
        if s then s.Scale = scale end
        micFrame.Position = UDim2.fromOffset(
            math.floor(sp.X + LS.MicX * scale + 0.5),
            math.floor(sp.Y - LS.MicY * scale + 0.5)
        )
    end)
end

-- =====================================================================
-- EMOTES TOOL (manual only - does not auto appear / reappear)
-- =====================================================================
local emoteTool = nil
local emoteHubLoaded = false

local function loadEmoteHub()
    -- Cho phép mở lại hub mỗi lần bấm (không kẹt sau lần load đầu)
    local ok, err = pcall(function()
        if type(loadstring) ~= "function" then error("executor has no loadstring") end
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"
        ))()
    end)
    if ok then
        emoteHubLoaded = true
    else
        emoteHubLoaded = false
        warn("[CNP] Emote hub load failed: ", err)
    end
end

local function GiveEmotesTool()
    -- Only create if not already present in current backpack/character
    local backpack = player:FindFirstChildOfClass("Backpack")
    local char = player.Character
    if backpack and backpack:FindFirstChild("Emotes") then return end
    if char and char:FindFirstChild("Emotes") then return end

    if emoteTool and emoteTool.Parent then
        pcall(function() emoteTool:Destroy() end)
        emoteTool = nil
    end

    backpack = backpack or player:WaitForChild("Backpack", 5)
    if not backpack then return end

    emoteTool = Instance.new("Tool")
    emoteTool.Name = "Emotes"
    emoteTool.ToolTip = "Emotes"
    emoteTool.RequiresHandle = false
    emoteTool.CanBeDropped = false
    -- Emote tool has no function (only an item to hold). Use the "emote hub" button for the hub.
    emoteTool.Parent = backpack
end

-- =====================================================================
-- FOG (simplified - no themes)
-- =====================================================================
local applyGlass, fogGui, fogIconGui
do
local fogToggleBtn
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if not atm then atm = Instance.new("Atmosphere"); atm.Parent = Lighting end
local oL = {
    FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor,
    ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, Brightness = Lighting.Brightness,
}
local oA = { Density = atm.Density, Color = atm.Color, Decay = atm.Decay,
    Haze = atm.Haze, Glare = atm.Glare, Offset = atm.Offset }
local FOG = { enabled = false, color = Color3.fromRGB(255, 0, 0), fogStart = 0, fogEnd = 90 }

local function applyFog()
    if not FOG.enabled then
        Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor =
            oL.FogStart, oL.FogEnd, oL.FogColor
        Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness =
            oL.Ambient, oL.OutdoorAmbient, oL.Brightness
        if oL.ClockTime then pcall(function() Lighting.ClockTime = oL.ClockTime end) end
        if atm and atm.Parent then
            atm.Density, atm.Color, atm.Decay = oA.Density, oA.Color, oA.Decay
            atm.Haze, atm.Glare, atm.Offset = oA.Haze, oA.Glare, oA.Offset
        end
        return
    end
    if not atm or not atm.Parent then
        atm = Instance.new("Atmosphere")
        atm.Parent = Lighting
        oA = { Density = atm.Density, Color = atm.Color, Decay = atm.Decay,
            Haze = atm.Haze, Glare = atm.Glare, Offset = atm.Offset }
    end
    Lighting.FogStart = FOG.fogStart
    Lighting.FogEnd = math.max(FOG.fogEnd, FOG.fogStart + 1)
    Lighting.FogColor = FOG.color
    Lighting.Ambient = FOG.color:Lerp(Color3.fromRGB(210, 220, 230), 0.2)
    Lighting.OutdoorAmbient = FOG.color:Lerp(Color3.fromRGB(220, 230, 240), 0.35)

    -- original-style atmosphere (richer color, classic density)
    local sf = 1 - math.clamp(FOG.fogStart / 200, 0, 0.95)
    local ef = math.clamp(180 / math.max(FOG.fogEnd, 1), 0.2, 3.2)
    atm.Density = math.clamp(0.58 * sf * ef, 0, 1)
    atm.Haze = 1.0
    atm.Glare = 0
    atm.Color, atm.Decay = FOG.color, FOG.color
    Lighting.Ambient = FOG.color:Lerp(Color3.fromRGB(210, 220, 230), 0.2)
    Lighting.OutdoorAmbient = FOG.color:Lerp(Color3.fromRGB(220, 230, 240), 0.35)
end

local colorList = {
    -- original vivid fog colors only (no pastel)
    { Name = "Red",     Color = Color3.fromRGB(255, 0, 0) },
    { Name = "Orange",  Color = Color3.fromRGB(255, 128, 0) },
    { Name = "Yellow",  Color = Color3.fromRGB(255, 255, 0) },
    { Name = "Green",   Color = Color3.fromRGB(0, 255, 0) },
    { Name = "Cyan",    Color = Color3.fromRGB(0, 255, 255) },
    { Name = "Blue",    Color = Color3.fromRGB(0, 0, 255) },
    { Name = "Purple",  Color = Color3.fromRGB(128, 0, 255) },
    { Name = "Magenta", Color = Color3.fromRGB(255, 0, 255) },
    { Name = "Pink",   Color = Color3.fromRGB(255, 183, 197) },
    { Name = "White",   Color = Color3.fromRGB(255, 255, 255) },
    { Name = "Black",   Color = Color3.fromRGB(0, 0, 0) },
}
local currentColorIndex = 1

function applyGlass(f, t)
    f.BackgroundTransparency = math.min(t, 0.08)
    local g = Instance.new("UIGradient", f)
    g.Rotation = 120
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 253, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 242, 252)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 225, 245)),
    })
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.05),
        NumberSequenceKeypoint.new(1, 0.12),
    })
end

fogGui = Instance.new("ScreenGui")
fogGui.Name = "Fog_Panel"; fogGui.ResetOnSpawn = false
fogGui.DisplayOrder = 2147483646; fogGui.Parent = pg; fogGui.Enabled = false

local fogFrame = Instance.new("Frame", fogGui)
do
    local fw, fh = fitW(300), fitH(420)
    fogFrame.Size = UDim2.new(0, fw, 0, fh)
    fogFrame.Position = UDim2.new(0.5, -fw/2, 0.5, -fh/2)
end
fogFrame.BackgroundColor3 = Color3.fromRGB(232, 244, 252)
fogFrame.BorderSizePixel = 0; fogFrame.Active = true
Instance.new("UICorner", fogFrame).CornerRadius = UDim.new(0, 12)
applyGlass(fogFrame, 0.12)

local fogStroke = Instance.new("UIStroke", fogFrame)
fogStroke.Color = Color3.fromRGB(200, 160, 70); fogStroke.Thickness = 2

local fogTop = Instance.new("Frame", fogFrame)
fogTop.Size = UDim2.new(1, 0, 0, 45)
fogTop.BackgroundColor3 = Color3.fromRGB(200, 225, 245)
fogTop.BorderSizePixel = 0
Instance.new("UICorner", fogTop).CornerRadius = UDim.new(0, 12)
fogTop.BackgroundTransparency = 0.3
makeDraggable(fogFrame, fogTop)

local topFix = Instance.new("Frame", fogTop)
topFix.Size = UDim2.new(1, 0, 0, 15)
topFix.Position = UDim2.new(0, 0, 0.5, 0)
topFix.BackgroundColor3 = fogTop.BackgroundColor3
topFix.BackgroundTransparency = 0.3
topFix.BorderSizePixel = 0; topFix.ZIndex = 2

local fogTitle = Instance.new("TextLabel", fogTop)
fogTitle.Size = UDim2.new(1, -70, 1, 0); fogTitle.Position = UDim2.new(0, 15, 0, 0)
fogTitle.BackgroundTransparency = 1; fogTitle.Text = "FOG"
fogTitle.TextColor3 = Color3.fromRGB(240, 200, 100); fogTitle.Font = Enum.Font.FredokaOne
fogTitle.TextSize = 20; fogTitle.TextXAlignment = Enum.TextXAlignment.Left; fogTitle.ZIndex = 3

local sig = Instance.new("TextLabel", fogFrame)
sig.Size = UDim2.new(1, -20, 0, 20); sig.Position = UDim2.new(0, 10, 1, -25)
sig.BackgroundTransparency = 1; sig.Text = "winter"
sig.TextColor3 = Color3.fromRGB(200,140,165); sig.Font = Enum.Font.BuilderSans
sig.TextSize = 10; sig.TextXAlignment = Enum.TextXAlignment.Right

local fogScroll = Instance.new("ScrollingFrame", fogFrame)
fogScroll.Size = UDim2.new(1, -20, 1, -75); fogScroll.Position = UDim2.new(0, 10, 0, 55)
fogScroll.BackgroundTransparency = 1; fogScroll.BorderSizePixel = 0
fogScroll.ScrollBarThickness = 3; fogScroll.ScrollBarImageColor3 = Color3.fromRGB(120,120,126)
fogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
fogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local fogLayout = Instance.new("UIListLayout", fogScroll)
fogLayout.Padding = UDim.new(0, 8); fogLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function fogButton(text)
    local b = Instance.new("TextButton", fogScroll)
    b.Size = UDim2.new(1, 0, 0, 35)
    b.BackgroundColor3 = Color3.fromRGB(210, 230, 248)
    b.BackgroundTransparency = 0.1
    b.Text = text; b.TextColor3 = Color3.fromRGB(100,60,85)
    b.Font = Enum.Font.FredokaOne; b.TextSize = 14; b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local colorBtn = fogButton("[ Red ]")
colorBtn.Activated:Connect(function()
    currentColorIndex = currentColorIndex % #colorList + 1
    local item = colorList[currentColorIndex]
    FOG.color = item.Color
    colorBtn.Text = "[ "..item.Name.." ]"
    if FOG.enabled then applyFog() end
end)

fogToggleBtn = fogButton("Fog: Disabled")
fogToggleBtn.BackgroundColor3 = Color3.fromRGB(240,150,170)
fogToggleBtn.TextColor3 = Color3.new(1,1,1)
fogToggleBtn.Activated:Connect(function()
    FOG.enabled = not FOG.enabled
    fogToggleBtn.Text = FOG.enabled and "Fog: Enabled" or "Fog: Disabled"
    fogToggleBtn.BackgroundColor3 = FOG.enabled and Color3.fromRGB(130,220,160)
        or Color3.fromRGB(240,150,170)
    applyFog()
end)

local function mkSlider(parent, label, mn, mx, dv, callback)
    local c = Instance.new("Frame", parent)
    c.Size = UDim2.new(1, 0, 0, 40); c.BackgroundColor3 = Color3.fromRGB(215, 232, 248)
    c.BorderSizePixel = 0; Instance.new("UICorner", c).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel", c)
    lbl.Size = UDim2.new(1, -20, 0, 18); lbl.Position = UDim2.new(0, 10, 0, 2)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(40,40,46)
    lbl.Font = Enum.Font.BuilderSansBold; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = label..": "..dv

    local bar = Instance.new("Frame", c)
    bar.Size = UDim2.new(1, -20, 0, 6); bar.Position = UDim2.new(0, 10, 0, 25)
    bar.BackgroundColor3 = Color3.fromRGB(235,200,215); bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local r = (dv - mn) / (mx - mn)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new(r, 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(70, 150, 210)
    fill.BorderSizePixel = 0; Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local kn = Instance.new("Frame", bar)
    kn.Size = UDim2.fromOffset(12, 12); kn.Position = UDim2.new(r, -6, 0.5, -6)
    kn.BackgroundColor3 = Color3.fromRGB(255,250,255); kn.BorderSizePixel = 0
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1, 0)

    local hit = Instance.new("TextButton", bar)
    hit.Size = UDim2.new(1, 0, 2, 15); hit.Position = UDim2.new(0, 0, 0, -5)
    hit.BackgroundTransparency = 1; hit.Text = ""; hit.Active = true

    local dragging = false
    local function update(x)
        local w = math.max(bar.AbsoluteSize.X, 1)
        local pos = math.clamp((x - bar.AbsolutePosition.X) / w, 0, 1)
        local v = math.floor(mn + (mx - mn) * pos + 0.5)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        kn.Position = UDim2.new(pos, -6, 0.5, -6)
        lbl.Text = label..": "..v
        callback(v)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
           or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

mkSlider(fogScroll, "Fog Start", 0, 1000, FOG.fogStart, function(v)
    FOG.fogStart = v
    if FOG.enabled then applyFog() end
end)
mkSlider(fogScroll, "Fog End", 1, 1000, FOG.fogEnd, function(v)
    FOG.fogEnd = v
    if FOG.enabled then applyFog() end
end)

local timeLabel = Instance.new("TextLabel", fogScroll)
timeLabel.Size = UDim2.new(1, 0, 0, 20); timeLabel.BackgroundTransparency = 1
timeLabel.Text = "TIME"; timeLabel.TextColor3 = Color3.fromRGB(40,40,46)
timeLabel.Font = Enum.Font.BuilderSansBold; timeLabel.TextSize = 12
timeLabel.TextXAlignment = Enum.TextXAlignment.Left

local dayBtn = fogButton("Day")
dayBtn.Activated:Connect(function() Lighting.ClockTime = 14; Lighting.Brightness = 2 end)
local nightBtn = fogButton("Night")
nightBtn.Activated:Connect(function() Lighting.ClockTime = 0; Lighting.Brightness = 0.5 end)

fogIconGui = Instance.new("ScreenGui")
fogIconGui.Name = "Fog_Icon"; fogIconGui.ResetOnSpawn = false
fogIconGui.DisplayOrder = 2147483647; fogIconGui.Parent = pg; fogIconGui.Enabled = false

local fogIcon = Instance.new("ImageButton", fogIconGui)
fogIcon.Size = UDim2.fromOffset(50, 50)
fogIcon.Position = UDim2.new(0.03, 0, 0.4, 0)
fogIcon.BackgroundColor3 = Color3.fromRGB(200, 225, 245)
fogIcon.Image = "rbxthumb://type=Asset&id=988116310&w=420&h=420"
fogIcon.ScaleType = Enum.ScaleType.Fit; fogIcon.Active = true
Instance.new("UICorner", fogIcon).CornerRadius = UDim.new(1, 0)
local iconStroke = Instance.new("UIStroke", fogIcon)
iconStroke.Color = Color3.fromRGB(255,150,190); iconStroke.Thickness = 2

do
    local DRAG_PX = 30
    local iDrag, iStart, iPos, iMoved, lastToggle = false, nil, nil, false, 0
    local function togglePanel()
        if os.clock() - lastToggle < 0.25 then return end
        lastToggle = os.clock()
        fogGui.Enabled = not fogGui.Enabled
        if fogGui.Enabled then
            local cam = Workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1000, 600)
            local ap = fogFrame.AbsolutePosition
            if ap.Y > vp.Y - 120 or ap.Y < -20
               or ap.X > vp.X - 60 or ap.X < -fogFrame.AbsoluteSize.X + 60 then
                fogFrame.Position = UDim2.new(0.5, -120, 0.5, -175)
            end
        end
    end
    fogIcon.AutoButtonColor = false
    fogIcon.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            iDrag = true; iMoved = false
            iStart = input.Position; iPos = fogIcon.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if iDrag and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - iStart
            if d.Magnitude > DRAG_PX then iMoved = true end
            if iMoved then
                fogIcon.Position = UDim2.new(iPos.X.Scale, iPos.X.Offset + d.X,
                    iPos.Y.Scale, iPos.Y.Offset + d.Y)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if iDrag and (input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch) then
            iDrag = false
        end
    end)
    fogIcon.Activated:Connect(function()
        if not iMoved then togglePanel() end
    end)
end

-- =====================================================================
-- MUTE SHERIFF KILL SOUND
-- =====================================================================
end -- close FOG block

local TargetSoundName = "Kill"
local TargetSoundId = "rbxassetid://296102734"
local muteSheriffConns = {}

local function MuteSound(sound)
    if not sound or not sound:IsA("Sound") then return end
    if not muteSheriffActive then return end
    if sound.Name == TargetSoundName or sound.SoundId == TargetSoundId then
        sound.Volume = 0
        pcall(function() sound:Stop() end)
    end
end

local function muteSheriffDisconnect()
    for _, c in ipairs(muteSheriffConns) do
        pcall(function() c:Disconnect() end)
    end
    for i = #muteSheriffConns, 1, -1 do muteSheriffConns[i] = nil end
end

local function muteSheriffEnable()
    muteSheriffDisconnect()
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("Sound") then MuteSound(v) end
    end
    table.insert(muteSheriffConns, game.DescendantAdded:Connect(function(obj)
        if not muteSheriffActive then return end
        if obj:IsA("Sound") then
            MuteSound(obj)
            table.insert(muteSheriffConns, obj:GetPropertyChangedSignal("Volume"):Connect(function()
                MuteSound(obj)
            end))
            table.insert(muteSheriffConns, obj:GetPropertyChangedSignal("SoundId"):Connect(function()
                MuteSound(obj)
            end))
            table.insert(muteSheriffConns, obj:GetPropertyChangedSignal("Playing"):Connect(function()
                if obj.Playing then MuteSound(obj) end
            end))
        end
    end))
end

local function muteSheriffDisable()
    muteSheriffActive = false
    muteSheriffDisconnect()
end

-- =====================================================================
-- UI HELPERS
-- =====================================================================
local UI = {
    -- christmas tree — pine, noel red, gold, cream
    bg     = Color3.fromRGB(22, 48, 32),
    row    = Color3.fromRGB(34, 62, 42),
    hover  = Color3.fromRGB(48, 88, 56),
    line   = Color3.fromRGB(212, 175, 55),
    text   = Color3.fromRGB(255, 250, 240),
    dim    = Color3.fromRGB(190, 200, 175),
    accent = Color3.fromRGB(196, 40, 48),
    off    = Color3.fromRGB(40, 68, 48),
    font   = Enum.Font.Gotham,
    titleFont = Enum.Font.GothamBold,
    corner = 14,
}

local function softTween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.22,
        Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

-- Christmas click sparkles (lightweight, mobile-safe)
local function xmasClickFX(anchor)
    local parent = (UI and UI.decor) or (mainFrame and mainFrame) or anchor
    if not parent or not parent.Parent then return end
    local rng = Random.new()
    local origin
    if anchor and anchor:IsA("GuiObject") then
        origin = anchor.AbsolutePosition + anchor.AbsoluteSize * 0.5
    else
        return
    end
    local pAbs = parent.AbsolutePosition
    local cols = {
        Color3.fromRGB(255, 60, 70),
        Color3.fromRGB(255, 220, 80),
        Color3.fromRGB(60, 200, 90),
        Color3.fromRGB(255, 255, 255),
    }
    for i = 1, (isMobile and 5 or 8) do
        local d = Instance.new("Frame")
        local sz = rng:NextInteger(3, 7)
        d.Size = UDim2.fromOffset(sz, sz)
        d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.Position = UDim2.fromOffset(origin.X - pAbs.X, origin.Y - pAbs.Y)
        d.BackgroundColor3 = cols[rng:NextInteger(1, #cols)]
        d.BackgroundTransparency = 0.1
        d.BorderSizePixel = 0
        d.ZIndex = 50
        d.Active = false
        Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
        d.Parent = parent
        local ang = rng:NextNumber(0, math.pi * 2)
        local dist = rng:NextNumber(18, 48)
        local tx = (origin.X - pAbs.X) + math.cos(ang) * dist
        local ty = (origin.Y - pAbs.Y) + math.sin(ang) * dist
        TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.fromOffset(tx, ty),
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(1, 1),
        }):Play()
        task.delay(0.4, function() pcall(function() d:Destroy() end) end)
    end
end

-- Chi 1 lan click (tranh double bat/tat)
local function bindClick(btn, fn)
    local last = 0
    local function fire()
        local now = tick()
        if now - last < 0.25 then return end
        last = now
        pcall(fn)
    end
    btn.Activated:Connect(fire)
end

function UI.header(parent, order, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18); l.BackgroundTransparency = 1; l.LayoutOrder = order
    l.Font = UI.titleFont; l.TextSize = 11; l.TextColor3 = Color3.fromRGB(235, 200, 90)
    l.TextXAlignment = Enum.TextXAlignment.Left; l.TextYAlignment = Enum.TextYAlignment.Bottom
    l.Text = string.upper(text)
    Instance.new("UIPadding", l).PaddingLeft = UDim.new(0, 8)
    l.Parent = parent
    return l
end

function UI.rowBase(parent, order, text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, isMobile and 34 or 36)
    b.LayoutOrder = order
    b.BackgroundColor3 = UI.row; b.BackgroundTransparency = 0.25
    b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Text = ""
    b.Active = true
    b.Selectable = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, UI.corner)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = Color3.fromRGB(212, 175, 55)
    stroke.Transparency = 0.35
    stroke.Thickness = 1
    local lbl = Instance.new("TextLabel", b)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Font = UI.font
    lbl.TextSize = 16
    lbl.TextColor3 = UI.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Text = text
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Active = false
    b.MouseEnter:Connect(function()
        softTween(b, { BackgroundColor3 = UI.hover, BackgroundTransparency = 0.08 }, 0.15)
        softTween(stroke, { Transparency = 0.05 }, 0.15)
    end)
    b.MouseLeave:Connect(function()
        softTween(b, { BackgroundColor3 = UI.row, BackgroundTransparency = 0.18 }, 0.18)
        softTween(stroke, { Transparency = 0.2 }, 0.18)
    end)
    b.Parent = parent
    return b, lbl
end

function UI.toggle(parent, order, text, initial, callback)
    local state = initial and true or false

    local onCol  = Color3.fromRGB(196, 40, 48)
    local offCol = Color3.fromRGB(40, 68, 48)
    local onHover  = Color3.fromRGB(220, 70, 70)
    local offHover = Color3.fromRGB(55, 90, 62)

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, isMobile and 30 or 32)
    b.LayoutOrder = order
    b.BackgroundTransparency = 0
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.Active = true
    b.Selectable = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = Color3.fromRGB(130, 185, 220)
    stroke.Thickness = 1
    stroke.Transparency = 0.25

    local lbl = Instance.new("TextLabel", b)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.Font = UI.font
    lbl.TextSize = 16
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Text = text
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Active = false
    lbl.ZIndex = 2

    local function paint()
        b.BackgroundColor3 = state and onCol or offCol
        b.BackgroundTransparency = 0
        lbl.TextColor3 = state and Color3.fromRGB(255, 250, 246) or Color3.fromRGB(190, 200, 190)
    end
    paint()

    b.MouseEnter:Connect(function()
        b.BackgroundColor3 = state and onHover or offHover
        b.BackgroundTransparency = 0
    end)
    b.MouseLeave:Connect(function()
        paint()
    end)

    local last = 0
    local function toggle()
        local now = tick()
        if now - last < 0.25 then return end
        last = now
        pcall(xmasClickFX, b)
        state = not state
        paint()
        pcall(callback, state)
    end
    b.Activated:Connect(toggle)
    b.Parent = parent

    return b
end

function UI.action(parent, order, text, callback)
    local b, lbl = UI.rowBase(parent, order, text)
    local arrow = Instance.new("TextLabel", b)
    arrow.BackgroundTransparency = 1; arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -14, 0.5, 0)
    arrow.Size = UDim2.fromOffset(18, 20)
    arrow.Font = UI.font; arrow.TextSize = 18
    arrow.TextYAlignment = Enum.TextYAlignment.Center
    arrow.TextColor3 = UI.accent; arrow.Text = "›"
    arrow.Active = false
    arrow.ZIndex = 2

    local hit = Instance.new("TextButton", b)
    hit.Size = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 5
    hit.Active = true
    hit.AutoButtonColor = false
    hit.BorderSizePixel = 0

    local last = 0
    local function fire()
        local now = tick()
        if now - last < 0.25 then return end
        last = now
        pcall(xmasClickFX, hit)
        -- brief gold flash
        pcall(function()
            softTween(b, { BackgroundColor3 = Color3.fromRGB(212, 175, 55) }, 0.08)
            task.delay(0.1, function()
                softTween(b, { BackgroundColor3 = UI.row }, 0.2)
            end)
        end)
        pcall(callback)
    end
    hit.Activated:Connect(fire)
    return b
end

function UI.switch(parent, order, label, leftText, rightText, initialRight, callback)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, isMobile and 34 or 36)
    wrap.BackgroundColor3 = UI.row
    wrap.BackgroundTransparency = 0.05
    wrap.BorderSizePixel = 0
    Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, UI.corner)
    wrap.LayoutOrder = order; wrap.Parent = parent

    local title = Instance.new("TextLabel", wrap)
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(0.38, 0, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.Font = UI.font; title.TextSize = 17; title.TextColor3 = UI.text
    title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = label

    local seg = Instance.new("Frame", wrap)
    seg.Size = UDim2.new(0.55, -16, 0, 28)
    seg.AnchorPoint = Vector2.new(1, 0.5)
    seg.Position = UDim2.new(1, -10, 0.5, 0)
    seg.BackgroundColor3 = UI.off; seg.BorderSizePixel = 0
    Instance.new("UICorner", seg).CornerRadius = UDim.new(1, 0)

    local function mk(txt, isRight)
        local b = Instance.new("TextButton", seg)
        b.Size = UDim2.new(0.5, -2, 1, -4)
        b.Position = isRight and UDim2.new(0.5, 1, 0, 2) or UDim2.new(0, 2, 0, 2)
        b.BackgroundColor3 = UI.row; b.BackgroundTransparency = 1
        b.Text = txt; b.Font = UI.font; b.TextSize = 15
        b.TextColor3 = UI.dim; b.BorderSizePixel = 0; b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        return b
    end
    local leftBtn = mk(leftText, false)
    local rightBtn = mk(rightText, true)
    local isRight = initialRight and true or false
    local function paint()
        if isRight then
            leftBtn.BackgroundTransparency = 1; leftBtn.TextColor3 = UI.dim
            rightBtn.BackgroundTransparency = 0
            rightBtn.BackgroundColor3 = UI.accent
            rightBtn.TextColor3 = Color3.new(1,1,1)
        else
            rightBtn.BackgroundTransparency = 1; rightBtn.TextColor3 = UI.dim
            leftBtn.BackgroundTransparency = 0
            leftBtn.BackgroundColor3 = UI.accent
            leftBtn.TextColor3 = Color3.new(1,1,1)
        end
    end
    paint()
    bindClick(leftBtn, function()
        if isRight then isRight = false; paint(); callback(false) end
    end)
    bindClick(rightBtn, function()
        if not isRight then isRight = true; paint(); callback(true) end
    end)
    return wrap
end

function UI.separator(parent, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -8, 0, 1)
    f.BackgroundColor3 = UI.line
    f.BackgroundTransparency = 0.35
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.Parent = parent
    return f
end

function UI.slider(parent, order, label, minV, maxV, curV, callback, tall)
    local h = tall and (isMobile and 72 or 78) or (isMobile and 54 or 58)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, h)
    wrap.BackgroundColor3 = UI.row
    wrap.BackgroundTransparency = 0.05
    wrap.BorderSizePixel = 0; wrap.LayoutOrder = order
    Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, UI.corner)
    local st = Instance.new("UIStroke", wrap)
    st.Color = UI.line; st.Transparency = 0.55; st.Thickness = 1
    wrap.Parent = parent

    local lbl = Instance.new("TextLabel", wrap)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -28, 0, tall and 22 or 18)
    lbl.Position = UDim2.new(0, 14, 0, tall and 6 or 4)
    lbl.Font = UI.font; lbl.TextSize = tall and 17 or 15; lbl.TextColor3 = UI.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label .. ": " .. tostring(curV)

    local barH = tall and 10 or 6
    local barY = tall and 40 or 30
    local knS = tall and 18 or 14
    local bar = Instance.new("Frame", wrap)
    bar.Size = UDim2.new(1, -24, 0, barH); bar.Position = UDim2.new(0, 12, 0, barY)
    bar.BackgroundColor3 = UI.off; bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local r = (curV - minV) / math.max(maxV - minV, 1)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new(r, 0, 1, 0)
    fill.BackgroundColor3 = UI.accent; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local kn = Instance.new("Frame", bar)
    kn.Size = UDim2.fromOffset(knS, knS)
    kn.Position = UDim2.new(r, -knS / 2, 0.5, -knS / 2)
    kn.BackgroundColor3 = Color3.fromRGB(255, 250, 255); kn.BorderSizePixel = 0
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1, 0)

    local hit = Instance.new("TextButton", bar)
    hit.Size = UDim2.new(1, 0, 3, 12); hit.Position = UDim2.new(0, 0, 0, -8)
    hit.BackgroundTransparency = 1; hit.Text = ""; hit.Active = true
    local dragging = false
    local function update(x)
        local w = math.max(bar.AbsoluteSize.X, 1)
        local pos = math.clamp((x - bar.AbsolutePosition.X) / w, 0, 1)
        local v = math.floor(minV + (maxV - minV) * pos + 0.5)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        kn.Position = UDim2.new(pos, -knS / 2, 0.5, -knS / 2)
        lbl.Text = label .. ": " .. tostring(v)
        callback(v)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
           or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return wrap
end

-- =====================================================================
-- MAIN PANEL
-- =====================================================================
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "CNP_Panel"; mainGui.ResetOnSpawn = false
mainGui.DisplayOrder = 2147483647
pcall(function() mainGui.OnTopOfCoreBlur = true end)
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mainGui.IgnoreGuiInset = true
pcall(function() mainGui.Parent = game:GetService("CoreGui") end)
if not mainGui.Parent then mainGui.Parent = pg end
mainGui.Enabled = true

local mainFrame = Instance.new("Frame", mainGui)
do
    local vp = getViewport()
    -- bigger panel
    local mw = isMobile and math.clamp(math.floor(vp.X * 0.42), 280, 360) or 400
    local mh = isMobile and math.max(360, math.floor(vp.Y - 30)) or 680
    mainFrame.Size = UDim2.new(0, mw, 0, mh)
    mainFrame.Position = UDim2.new(0.5, -mw / 2, 0.5, -mh / 2)
end
mainFrame.BackgroundColor3 = UI.bg
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.BackgroundTransparency = 0
mainFrame.Active = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)
do
    -- pine tree depth gradient
    local g = Instance.new("UIGradient", mainFrame)
    g.Rotation = 165
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 72, 44)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(24, 52, 34)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(20, 42, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 28, 30)),
    })
end
do
    local st = Instance.new("UIStroke", mainFrame)
    st.Color = Color3.fromRGB(220, 180, 70)
    st.Transparency = 0.08
    st.Thickness = 2.2
end
do
    -- garland side strip (red / gold / green)
    local strip = Instance.new("Frame", mainFrame)
    strip.Size = UDim2.new(0, 5, 1, -14)
    strip.Position = UDim2.new(0, 6, 0, 7)
    strip.BackgroundColor3 = Color3.fromRGB(200, 50, 55)
    strip.BorderSizePixel = 0
    strip.ZIndex = 5
    Instance.new("UICorner", strip).CornerRadius = UDim.new(1, 0)
    local sg = Instance.new("UIGradient", strip)
    sg.Rotation = 90
    sg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(212, 175, 55)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(196, 40, 48)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 140, 70)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(196, 40, 48)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 175, 55)),
    })
end
UI.full = mainFrame.Size

local topBar = Instance.new("TextLabel", mainFrame)
topBar.Size = UDim2.new(1, -40, 0, 34); topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundTransparency = 1; topBar.Text = "CNP • Sabrine"
topBar.TextColor3 = Color3.fromRGB(255, 220, 120); topBar.Font = UI.titleFont; topBar.TextSize = 15
topBar.TextXAlignment = Enum.TextXAlignment.Left; topBar.Active = true
topBar.ZIndex = 3
Instance.new("UIPadding", topBar).PaddingLeft = UDim.new(0, 14)


local minBtn = Instance.new("TextButton", mainFrame)
minBtn.Size = UDim2.fromOffset(26, 26); minBtn.Position = UDim2.new(1, -30, 0, 2)
minBtn.BackgroundTransparency = 1; minBtn.TextColor3 = UI.dim
minBtn.Font = UI.font; minBtn.TextSize = 20; minBtn.Text = "-"; minBtn.BorderSizePixel = 0
minBtn.ZIndex = 4; minBtn.Active = true

local titleLine = Instance.new("Frame", mainFrame)
titleLine.Size = UDim2.new(1, -24, 0, 1)
titleLine.Position = UDim2.new(0, 12, 0, 38)
titleLine.BackgroundColor3 = UI.line
titleLine.BackgroundTransparency = 0.45; titleLine.BorderSizePixel = 0

makeDraggable(mainFrame, topBar)

-- winter decor (fall only)
do
    local decor = Instance.new("Frame")
    decor.Name = "Decor"
    decor.Size = UDim2.fromScale(1, 1)
    decor.BackgroundTransparency = 1
    decor.BorderSizePixel = 0
    decor.ClipsDescendants = true
    decor.ZIndex = 8
    decor.Active = false
    decor.Parent = mainFrame
    UI.decor = decor

    -- bottom gold ribbon
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.AnchorPoint = Vector2.new(0, 1)
    bar.Position = UDim2.fromScale(0, 1)
    bar.BorderSizePixel = 0
    bar.BackgroundColor3 = Color3.fromRGB(212, 175, 55)
    bar.BackgroundTransparency = 0.25
    bar.ZIndex = 1
    bar.Active = false
    bar.Parent = decor
    local bg = Instance.new("UIGradient", bar)
    bg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(196, 40, 48)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 140, 70)),
    })

    -- star badge top-right feel
    local star = Instance.new("TextLabel")
    star.BackgroundTransparency = 1
    star.Size = UDim2.fromOffset(28, 28)
    star.Position = UDim2.new(1, -52, 0, 4)
    star.Text = "★"
    star.TextColor3 = Color3.fromRGB(255, 220, 90)
    star.TextSize = 22
    star.Font = Enum.Font.GothamBold
    star.ZIndex = 9
    star.Active = false
    star.Parent = decor

    local rng = Random.new()
    local flakes = {}
    local lights = {}
    -- snow image flakes (no solid white dots)
    local SNOW_IMG = "rbxassetid://15216668864"
    local N = isMobile and 28 or 48
    for i = 1, N do
        local f = Instance.new("ImageLabel")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundTransparency = 1 -- no white plate behind
        f.BorderSizePixel = 0
        f.ZIndex = 8
        f.Active = false
        f.Image = SNOW_IMG
        f.ScaleType = Enum.ScaleType.Fit
        f.ImageTransparency = rng:NextNumber(0.05, 0.35)
        f.Parent = decor

        -- deformed oval size
        local w = rng:NextInteger(10, 22)
        local h = math.max(8, math.floor(w * rng:NextNumber(0.6, 1.1)))
        if rng:NextNumber() < 0.4 then
            w, h = h + rng:NextInteger(0, 4), w
        end
        f.Size = UDim2.fromOffset(w, h)
        f.Rotation = rng:NextNumber(-30, 30)

        local x0 = rng:NextNumber(0.02, 0.98)
        local y0 = -40 - (i % 20) * 20
        f.Position = UDim2.new(x0, 0, 0, y0)
        flakes[i] = {
            f = f, x0 = x0, y = y0,
            speed = rng:NextNumber(40, 120),
            amp = rng:NextNumber(0.012, 0.05),
            freq = rng:NextNumber(0.7, 2.4),
            phase = rng:NextNumber(0, 6.28),
            rot = f.Rotation,
            rotSpeed = rng:NextNumber(-55, 55),
            wobble = rng:NextNumber(0.8, 2.2),
            baseW = w,
            baseH = h,
        }
    end

    -- tree lights (twinkle dots along edges)
    local lightColors = {
        Color3.fromRGB(255, 80, 80),
        Color3.fromRGB(80, 220, 100),
        Color3.fromRGB(255, 220, 80),
        Color3.fromRGB(120, 200, 255),
        Color3.fromRGB(255, 160, 220),
    }
    local L = isMobile and 10 or 16
    for i = 1, L do
        local d = Instance.new("Frame")
        d.Size = UDim2.fromOffset(6, 6)
        d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.BackgroundColor3 = lightColors[((i - 1) % #lightColors) + 1]
        d.BackgroundTransparency = 0.15
        d.BorderSizePixel = 0
        d.ZIndex = 9
        d.Active = false
        Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
        d.Parent = decor
        local side = (i % 2 == 0) and 0.04 or 0.96
        d.Position = UDim2.new(side, 0, (i / (L + 1)), 0)
        lights[i] = { f = d, phase = rng:NextNumber(0, 6.28), speed = rng:NextNumber(2.5, 5) }
    end

    local t0 = 0
    task.spawn(function()
        while decor.Parent do
            local dt = task.wait(isMobile and 0.033 or 0.016)
            if not mainFrame.Parent then break end
            local h = mainFrame.AbsoluteSize.Y
            if h < 40 then h = 420 end
            dt = math.clamp(dt, 0, 0.05)
            t0 = t0 + dt
            for _, p in ipairs(flakes) do
                p.y = p.y + p.speed * dt
                if p.y > h + 24 then
                    p.y = -rng:NextNumber(8, 70)
                    p.x0 = rng:NextNumber(0.02, 0.98)
                    p.speed = rng:NextNumber(40, 130)
                end
                p.rot = p.rot + p.rotSpeed * dt
                local sway = math.sin(t0 * p.freq + p.phase) * p.amp
                p.f.Position = UDim2.new(p.x0 + sway, 0, 0, p.y)
                p.f.Rotation = p.rot
                if p.baseW and p.baseH then
                    local k = 1 + 0.1 * math.sin(t0 * (p.wobble or 1.2) + p.phase)
                    p.f.Size = UDim2.fromOffset(
                        math.max(6, math.floor(p.baseW * k)),
                        math.max(6, math.floor(p.baseH * (2 - k)))
                    )
                end
            end
            -- twinkle lights
            for _, L in ipairs(lights) do
                local a = 0.05 + 0.45 * (0.5 + 0.5 * math.sin(t0 * L.speed + L.phase))
                L.f.BackgroundTransparency = a
            end
            -- soft star pulse
            star.TextTransparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(t0 * 2.2))
        end
    end)
end

local scroll = Instance.new("ScrollingFrame", mainFrame)
scroll.Size = UDim2.new(1, -12, 1, -42); scroll.Position = UDim2.new(0, 6, 0, 36)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4; scroll.ScrollBarImageColor3 = UI.line
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ScrollingEnabled = true
scroll.Active = true
scroll.Selectable = false
scroll.ElasticBehavior = Enum.ElasticBehavior.Always
scroll.ClipsDescendants = true
scroll.ZIndex = 2
do
    local lay = Instance.new("UIListLayout", scroll)
    lay.Padding = UDim.new(0, 4); lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        -- dam bao canvas du cao de scroll
        scroll.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 16)
    end)
end
do
    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 2)
end

local isMini = false

-- ===== MOVEMENT =====
UI.header(scroll, 0.5, "movement")
UI.toggle(scroll, 1, "speed", false, function(v)
    speedEnabled = v
    if not v then
        renderFlickTarget = 0
        speedResetUnlock()
        local hum = speedHumanoid or (player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
        if hum and not hum.PlatformStand then
            hum.WalkSpeed = BASE_SPEED
        end
    end
end)

UI.slider(scroll, 1.15, "speed value", 80, 300, SPEED_VALUE, function(v)
    SPEED_VALUE = v
end, true)

-- fly gui → order 2 (later)
-- esp → order 3 (later)
UI.toggle(scroll, 4, "no reload animation", noReloadActive, function(v) noReloadActive = v end)
-- crosshair → order 5 (later)

UI.separator(scroll, 5.5)


-- =====================================================================
-- HOTBAR (for mobile) — quick equip bar
-- =====================================================================
local hotbarActive = false
local hotbarGui = nil
local hotbarConns = {}

local function destroyHotbar()
    for _, c in ipairs(hotbarConns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(hotbarConns)
    if hotbarGui then
        pcall(function() hotbarGui:Destroy() end)
        hotbarGui = nil
    end
    local old = pg:FindFirstChild("QuickEquipBarGui")
    if old then pcall(function() old:Destroy() end) end
    hotbarActive = false
end

local function initHotbar()
    if hotbarGui then return end
    destroyHotbar()
    hotbarActive = true

    local MAX_ITEMS = 8
    local SLOT_SIZE = 50
    local SLOT_GAP = 6
    local PAD = 4

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "QuickEquipBarGui"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 50
    pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
    if not screenGui.Parent then screenGui.Parent = pg end
    hotbarGui = screenGui

    local bar = Instance.new("Frame")
    bar.AnchorPoint = Vector2.new(0.5, 1) -- grow from center-bottom, no jump when width changes
    bar.Size = UDim2.new(0, SLOT_SIZE + PAD * 2, 0, SLOT_SIZE + PAD * 2)
    bar.Position = UDim2.new(0.5, 0, 1, -86)
    bar.BackgroundColor3 = Color3.fromRGB(15, 16, 19)
    bar.BackgroundTransparency = 0.6
    bar.BorderSizePixel = 0
    bar.Active = true
    bar.Parent = screenGui
    makeDraggable(bar, bar)

    local barPad = Instance.new("UIPadding")
    barPad.PaddingTop = UDim.new(0, PAD)
    barPad.PaddingBottom = UDim.new(0, PAD)
    barPad.PaddingLeft = UDim.new(0, PAD)
    barPad.PaddingRight = UDim.new(0, PAD)
    barPad.Parent = bar

    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Padding = UDim.new(0, SLOT_GAP)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = bar

    -- only change SIZE; never reset Position (keeps drag place, no tè le)
    local function updateBarWidth(count)
        local shown = math.max(1, math.clamp(count, 0, MAX_ITEMS))
        local width = shown * SLOT_SIZE + (shown - 1) * SLOT_GAP + PAD * 2
        local height = SLOT_SIZE + PAD * 2
        if bar.Size.X.Offset ~= width or bar.Size.Y.Offset ~= height then
            bar.Size = UDim2.new(0, width, 0, height)
        end
    end

    local function getHumanoid()
        local char = player.Character
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function getToolIcon(tool)
        if tool.TextureId and tool.TextureId ~= "" then
            return tool.TextureId
        end
        local handle = tool:FindFirstChild("Handle")
        if handle then
            local decal = handle:FindFirstChildWhichIsA("Decal", true)
            if decal and decal.Texture ~= "" then
                return decal.Texture
            end
            local mesh = handle:FindFirstChildWhichIsA("SpecialMesh", true)
            if mesh and mesh.TextureId ~= "" then
                return mesh.TextureId
            end
        end
        return "rbxasset://textures/ui/GuiImagePlaceholder.png"
    end

    local refreshToken = 0
    local lastToolSig = ""

    local function collectTools()
        local bag = player:FindFirstChildOfClass("Backpack") or bp
        local tools = {}
        local seen = {}
        -- backpack first = same order as default hotbar / backpack list
        if bag then
            for _, item in ipairs(bag:GetChildren()) do
                if item:IsA("Tool") and not seen[item] then
                    seen[item] = true
                    table.insert(tools, item)
                    if #tools >= MAX_ITEMS then return tools end
                end
            end
        end
        if player.Character then
            for _, item in ipairs(player.Character:GetChildren()) do
                if item:IsA("Tool") and not seen[item] then
                    seen[item] = true
                    table.insert(tools, item)
                    if #tools >= MAX_ITEMS then return tools end
                end
            end
        end
        return tools
    end

    local function refreshButtons()
        if not hotbarActive or not bar.Parent then return end
        refreshToken = refreshToken + 1
        local myToken = refreshToken
        task.defer(function()
            if myToken ~= refreshToken then return end
            if not hotbarActive or not bar.Parent then return end

        local tools = collectTools()

        -- skip rebuild if same tools + equip state (stops flicker / jump)
        local sigParts = {}
        for _, t in ipairs(tools) do
            sigParts[#sigParts + 1] = tostring(t) .. ":" .. tostring(t.Parent == player.Character)
        end
        local sig = table.concat(sigParts, "|")
        if sig == lastToolSig and #bar:GetChildren() > 2 then
            return
        end
        lastToolSig = sig

        for _, child in ipairs(bar:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for idx, tool in ipairs(tools) do
            local isEquipped = (tool.Parent == player.Character)
            local btn = Instance.new("TextButton")
            btn.LayoutOrder = idx
            btn.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
            btn.Text = ""
            btn.AutoButtonColor = true
            btn.BackgroundColor3 = isEquipped
                and Color3.fromRGB(32, 36, 44)
                or Color3.fromRGB(22, 24, 29)
            btn.BackgroundTransparency = isEquipped and 0.62 or 0.78
            btn.BorderSizePixel = 0
            btn.Parent = bar

            if isEquipped then
                local stroke = Instance.new("UIStroke")
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Color = Color3.fromRGB(0, 162, 255)
                stroke.Transparency = 0.05
                stroke.Thickness = 2
                stroke.Parent = btn
            end

            local slotNum = Instance.new("TextLabel")
            slotNum.Size = UDim2.new(0, 14, 0, 14)
            slotNum.Position = UDim2.new(0, 4, 0, 2)
            slotNum.BackgroundTransparency = 1
            slotNum.Text = tostring(idx)
            slotNum.TextColor3 = isEquipped
                and Color3.fromRGB(145, 215, 255)
                or Color3.fromRGB(200, 205, 215)
            slotNum.TextTransparency = isEquipped and 0.05 or 0.3
            slotNum.Font = Enum.Font.GothamBold
            slotNum.TextSize = 11
            slotNum.TextXAlignment = Enum.TextXAlignment.Left
            slotNum.Parent = btn

            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0.76, 0, 0.76, 0)
            icon.Position = UDim2.new(0.12, 0, 0.14, 0)
            icon.BackgroundTransparency = 1
            icon.Image = getToolIcon(tool)
            icon.ScaleType = Enum.ScaleType.Fit
            icon.Parent = btn

            btn.MouseButton1Click:Connect(function()
                local hum = getHumanoid()
                if not hum then return end
                if tool.Parent == player.Character then
                    hum:UnequipTools()
                else
                    hum:EquipTool(tool)
                end
                task.defer(refreshButtons)
            end)
        end

        updateBarWidth(#tools)
        end) -- end deferred debounce
    end

    refreshButtons()

    local function bindBag(bag)
        if not bag then return end
        table.insert(hotbarConns, bag.ChildAdded:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
        table.insert(hotbarConns, bag.ChildRemoved:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
    end
    bindBag(player:FindFirstChildOfClass("Backpack") or bp)

    table.insert(hotbarConns, player.CharacterAdded:Connect(function(char)
        lastToolSig = ""
        table.insert(hotbarConns, char.ChildAdded:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
        table.insert(hotbarConns, char.ChildRemoved:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
        task.wait(0.2)
        bindBag(player:FindFirstChildOfClass("Backpack"))
        refreshButtons()
    end))
    if player.Character then
        table.insert(hotbarConns, player.Character.ChildAdded:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
        table.insert(hotbarConns, player.Character.ChildRemoved:Connect(function()
            lastToolSig = ""
            task.defer(refreshButtons)
        end))
    end

    -- poll: show tools as soon as they appear in backpack (no need to equip first)
    task.spawn(function()
        while hotbarActive and hotbarGui and hotbarGui.Parent do
            refreshButtons()
            task.wait(0.35)
        end
    end)
end


-- =====================================================================
-- ANTIFLING (menu toggle — off by default)
-- =====================================================================
local function setAntifling(on)
    antiflingActive = on and true or false
    if not antiflingActive then
        print("[CNP] antifling off (reload character / rejoin to fully clear external script if needed)")
        return
    end
    task.spawn(function()
        local ok, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/sytcal/antifling/main/9999"))()
        end)
        if ok then
            print("[CNP] antifling on")
        else
            antiflingActive = false
            warn("[CNP] antifling load failed: ", err)
        end
    end)
end

-- ===== TOOLS =====
UI.header(scroll, 6.5, "tools")
-- c4 menu → order 7 (later)
UI.action(scroll, 8, "emote hub", function() loadEmoteHub() end)
UI.action(scroll, 8.1, "emote tool", function()
    GiveEmotesTool()
    print("emote tool -> backpack")
end)
UI.action(scroll, 9, "f3x tool", function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(
            "https://scriptblox.com/raw/Universal-Script-F3X-Tool-44387"
        ))()
    end)
    if not ok then warn("[CNP] F3X load loi: " .. tostring(err)) end
end)
UI.action(scroll, 10, "tool grip", function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(
            "https://scriptblox.com/raw/Universal-Script-Tool-grip-script-235304"
        ))()
    end)
    if not ok then warn("[CNP] Tool grip load loi: " .. tostring(err)) end
end)
UI.toggle(scroll, 10.2, "hotbar (for mobile)", false, function(v)
    if v then
        initHotbar()
    else
        destroyHotbar()
    end
end)
UI.separator(scroll, 10.5)

-- ===== VISUAL =====
UI.header(scroll, 11, "visual")
UI.toggle(scroll, 13, "shiftlock 2023", enableOldShiftLock, function(v)
    enableOldShiftLock = v
    if not v then
        _slWasLocked = false
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.CameraOffset == SHIFTLOCK_2023_OFFSET then
            pcall(function() hum.CameraOffset = Vector3.zero end)
        end
    end
end)
UI.toggle(scroll, 14, "fog panel", false, function(v)
    fogIconGui.Enabled = v
    if not v then fogGui.Enabled = false end
end)
UI.toggle(scroll, 14.2, "antifling", false, function(v)
    setAntifling(v)
end)
UI.toggle(scroll, 15, "old chat", oldBubbleChatActive, function(v)
    oldBubbleChatActive = v
    if v then initOldChat() else destroyOldChat() end
end)
UI.toggle(scroll, 15.1, "microphone", micActive, function(v)
    micActive = v
    if v then initMic() else destroyMic() end
end)
UI.toggle(scroll, 16, "sound equip gun", autoEquipActive, function(v) autoEquipActive = v end)
-- Old Notification Kill (PC mode): changes the MM2 kill feed text (PC & mobile)
local oldKillActive = false
local oldKillHooked = false
do
    local replacements = {
        ["Melee Kill!"] = "Melee Kill! + 250",
        ["Throwing Kill!"] = "Throwing Kill! +100",
    }
    local textConns = setmetatable({}, { __mode = "k" }) -- label -> Text listener
    local watchConns = {}                                  -- container listeners

    local function isTextObj(o) return o:IsA("TextLabel") or o:IsA("TextButton") end

    local function handle(obj)
        if not isTextObj(obj) or textConns[obj] then return end
        local n = replacements[obj.Text]
        if n then obj.Text = n end
        textConns[obj] = obj:GetPropertyChangedSignal("Text"):Connect(function()
            if not oldKillActive then return end
            local r = replacements[obj.Text]
            if r then obj.Text = r end
        end)
    end

    local function containers()
        local list = { player:FindFirstChild("PlayerGui"), Workspace }
        pcall(function() table.insert(list, game:GetService("CoreGui")) end)
        if type(gethui) == "function" then
            pcall(function() table.insert(list, gethui()) end)
        end
        return list
    end

    -- Method 1: hook (PC / strong executors, no delay)
    local function installHook()
        if oldKillHooked then return end
        if type(hookmetamethod) ~= "function" then return end
        oldKillHooked = true
        pcall(function()
            local old
            old = hookmetamethod(game, "__newindex", (newcclosure or function(f) return f end)(
                function(self, key, value)
                    if oldKillActive and key == "Text" and typeof(value) == "string"
                       and typeof(self) == "Instance"
                       and (self:IsA("TextLabel") or self:IsA("TextButton")) then
                        value = replacements[value] or value
                    end
                    return old(self, key, value)
                end))
        end)
    end

    -- Method 2: event-driven watcher (mobile / weak executors).
    -- Replaces the old 0.1s GetDescendants loop, which lagged the game.
    local function startWatch()
        for _, c in ipairs(containers()) do
            table.insert(watchConns, c.DescendantAdded:Connect(function(o)
                if oldKillActive then handle(o) end
            end))
            task.spawn(function()
                local ok, list = pcall(function() return c:GetDescendants() end)
                if not ok then return end
                for i, o in ipairs(list) do
                    if not oldKillActive then return end
                    handle(o)
                    if i % 400 == 0 then task.wait() end
                end
            end)
        end
    end

    local function stopWatch()
        for _, c in ipairs(watchConns) do pcall(function() c:Disconnect() end) end
        for i = #watchConns, 1, -1 do watchConns[i] = nil end
        for o, c in pairs(textConns) do
            pcall(function() c:Disconnect() end)
            textConns[o] = nil
        end
    end

    local row = UI.toggle(scroll, 17, "old Notification Kill (PC mode)", false, function(v)
        oldKillActive = v
        if v then
            installHook()
            startWatch()
        else
            stopWatch()
        end
    end)
    local lbl = row:FindFirstChildOfClass("TextLabel")
    if lbl then
        lbl.TextScaled = true
        local c = Instance.new("UITextSizeConstraint", lbl)
        c.MaxTextSize = 16; c.MinTextSize = 8
    end
end

UI.toggle(scroll, 16.1, "mute sheriff kill", false, function(v)
    muteSheriffActive = v
    if v then muteSheriffEnable() else muteSheriffDisable() end
end)

-- =====================================================================
-- CROSSHAIR
-- =====================================================================
do
    local IDS = {
        -- new crosshairs
        135664831329896,
        84061079851935,
        117904815213842,
        -- MouseLockedCursor (Image ids)
        106992068239006, -- green
        111484643328877, -- red
        106528735245531, -- white
        108310581939634, -- magenta
        107297431814947, -- pink
        130093398539862, -- purple
        73309572327512,  -- blue
        111655608294842, -- red 2
        72430341332878,  -- teal
        114300729287839, -- dark
    }
    local X = { built = false, size = 40, enabled = false, cur = IDS[1] }
    local gui, holder, panel, thumbs, setOn, render, cache = nil, nil, nil, {}, nil, nil, {}

    local function mount(g)
        local ok = pcall(function() g.Parent = (gethui and gethui()) or pg end)
        if not ok or not g.Parent then g.Parent = pg end
    end

    local function loadImage(label, id)
        if cache[id] then label.Image = cache[id]; return end
        local cands = {
            "rbxassetid://" .. id,
            "http://www.roblox.com/asset/?id=" .. id,
            "rbxthumb://type=Asset&id=" .. id .. "&w=420&h=420",
        }
        if type(game.GetObjects) == "function" then
            pcall(function()
                local o = game:GetObjects("rbxassetid://" .. id)[1]
                if o and (o:IsA("Decal") or o:IsA("Texture")) and o.Texture ~= "" then
                    table.insert(cands, 1, o.Texture)
                end
            end)
        end
        local CP = game:GetService("ContentProvider")
        for _, c in ipairs(cands) do
            label.Image = c
            local ok = false
            pcall(function()
                CP:PreloadAsync({ label }, function(_, st)
                    if st == Enum.AssetFetchStatus.Success then ok = true end
                end)
            end)
            if ok or label.IsLoaded then cache[id] = c; return end
        end
        label.Image = cands[1]
    end

    local function shiftlockOn()
        -- only true mouse-lock / shiftlock (not camera offset alone)
        return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
    end

    local function isOurs(v)
        local sg = v:FindFirstAncestorOfClass("ScreenGui")
        if not sg then return false end
        local n = sg.Name
        return n:sub(1, 4) == "CNP_" or n == "Fog_Panel" or n == "Fog_Icon"
            or n == "C4_Modern_Menu" or n == "ListUserPanel"
            or n == "Old2023ChatGui" or n == "SLPanel" or n == "SLIcon"
    end

    local hidden = {}
    local function hideObj(v)
        if hidden[v] then return end
        local rec = {}
        pcall(function()
            if v:IsA("ImageLabel") or v:IsA("ImageButton") then
                rec.ImageTransparency = v.ImageTransparency
                v.ImageTransparency = 1
            end
            if v:IsA("GuiObject") then
                rec.Visible = v.Visible
                v.Visible = false
            end
        end)
        hidden[v] = rec
    end
    local function restoreNative()
        for v, rec in pairs(hidden) do
            pcall(function()
                if rec.ImageTransparency ~= nil then v.ImageTransparency = rec.ImageTransparency end
                if rec.Visible ~= nil then v.Visible = rec.Visible end
            end)
        end
        hidden = {}
    end

    local SHIFT_NAME_HINTS = {
        mouselock=true, shiftlock=true, mouse_lock=true, shift_lock=true,
        crosshair=true, reticle=true, retical=true, mouseicon=true,
    }
    local function nameLooksNative(n)
        n = string.lower(n or "")
        for k in pairs(SHIFT_NAME_HINTS) do
            if n:find(k, 1, true) then return true end
        end
        return false
    end

    -- Lightweight: only scan likely containers, not every descendant every frame
    local function sweepNative()
        local roots = { pg }
        pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
        for _, root in ipairs(roots) do
            for _, sg in ipairs(root:GetChildren()) do
                if sg:IsA("ScreenGui") and not isOurs(sg) then
                    local sn = string.lower(sg.Name)
                    local scanDeep = nameLooksNative(sn)
                        or sn:find("player", 1, true)
                        or sn:find("control", 1, true)
                        or sn:find("camera", 1, true)
                    if scanDeep then
                        for _, v in ipairs(sg:GetDescendants()) do
                            if (v:IsA("ImageLabel") or v:IsA("ImageButton")) and not isOurs(v) then
                                if nameLooksNative(v.Name) then
                                    hideObj(v)
                                end
                            end
                        end
                    else
                        -- shallow only
                        for _, v in ipairs(sg:GetChildren()) do
                            if (v:IsA("ImageLabel") or v:IsA("ImageButton")) and nameLooksNative(v.Name) then
                                hideObj(v)
                            end
                        end
                    end
                end
            end
        end
    end
    X.sweep = function()
        sweepNative()
        task.delay(0.5, sweepNative)
    end

    local function build()
        local xgui = Instance.new("ScreenGui")
        xgui.Name = "CNP_Crosshair"; xgui.ResetOnSpawn = false
        xgui.IgnoreGuiInset = true; xgui.DisplayOrder = 998
        mount(xgui)
        holder = Instance.new("Frame", xgui)
        holder.BackgroundTransparency = 1
        holder.AnchorPoint = Vector2.new(.5, .5)
        holder.Position = UDim2.fromScale(.5, .5)
        holder.Size = UDim2.fromOffset(50, 50)
        holder.Active = false; holder.Visible = false
        pcall(function() holder.Interactable = false end)
        local hscale = Instance.new("UIScale", holder)
        local token = 0

        render = function()
            token = token + 1
            local my = token
            for _, c in ipairs(holder:GetChildren()) do
                if c:IsA("ImageLabel") then c:Destroy() end
            end
            -- off / no id → hide crosshair, restore default icons
            if not (X.enabled and X.cur) then
                holder.Visible = false
                restoreNative()
                return
            end
            -- crosshair only while shiftlock is ON
            local locked = shiftlockOn()
            holder.Visible = locked
            if locked then
                X.sweep() -- hide default shiftlock / reticle
            else
                restoreNative()
            end
            hscale.Scale = X.size / 50
            local i = Instance.new("ImageLabel", holder)
            i.Size = UDim2.fromScale(1, 1); i.BackgroundTransparency = 1; i.Active = false
            task.spawn(function() if my == token then loadImage(i, X.cur) end end)
        end

        -- Throttled Heartbeat (was RenderStepped every frame → lag)
        local lastSweep, acc = 0, 0
        local lastWant = false
        RunService.Heartbeat:Connect(function(dt)
            acc = acc + dt
            if acc < 0.08 then return end -- ~12.5 checks / sec
            acc = 0
            local locked = shiftlockOn()
            -- show custom crosshair only when enabled + shiftlocked
            local want = X.enabled and X.cur ~= nil and locked
            if want ~= lastWant then
                lastWant = want
                holder.Visible = want
                if want then
                    -- bật crosshair → mất shiftlock default
                    X.sweep()
                    lastSweep = os.clock()
                else
                    -- tắt shiftlock (hoặc tắt crosshair) → hide crosshair + trả icon gốc
                    restoreNative()
                end
            elseif want then
                local now = os.clock()
                if now - lastSweep > 1.8 then
                    lastSweep = now
                    X.sweep()
                end
            elseif X.enabled and not locked then
                -- shiftlock off: keep crosshair hidden
                if holder.Visible then holder.Visible = false end
            end
        end)

        gui = Instance.new("ScreenGui")
        gui.Name = "CNP_CrosshairPanel"; gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 2147483646
        gui.Enabled = true
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not gui.Parent then gui.Parent = pg end
        X.built = true
        panel = Instance.new("Frame", gui)
        panel.Size = UDim2.new(0, isMobile and 214 or 232,
            0, fitH(isMobile and 400 or 480))
        panel.Position = UDim2.new(0.5, -panel.Size.X.Offset / 2,
            0.5, -panel.Size.Y.Offset / 2)
        panel.BackgroundColor3 = UI.bg; panel.BackgroundTransparency = 0.05
        panel.BorderSizePixel = 0; panel.ClipsDescendants = true
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
        local pst = Instance.new("UIStroke", panel)
        pst.Color = Color3.fromRGB(80, 80, 95)
        pst.Transparency = 0.2; pst.Thickness = 1

        local top = Instance.new("TextLabel", panel)
        top.Size = UDim2.new(1, -36, 0, 32); top.BackgroundTransparency = 1
        top.Text = "crosshair"; top.TextColor3 = UI.text
        top.Font = UI.titleFont; top.TextSize = 15
        top.TextXAlignment = Enum.TextXAlignment.Left; top.Active = true
        Instance.new("UIPadding", top).PaddingLeft = UDim.new(0, 12)

        local closeB = Instance.new("TextButton", panel)
        closeB.Size = UDim2.fromOffset(26, 26)
        closeB.Position = UDim2.new(1, -30, 0, 3)
        closeB.BackgroundTransparency = 1
        closeB.TextColor3 = UI.dim; closeB.Font = UI.font; closeB.TextSize = 16
        closeB.Text = "x"; closeB.BorderSizePixel = 0
        closeB.Activated:Connect(function() gui.Enabled = false end)

        local tl = Instance.new("Frame", panel)
        tl.Size = UDim2.new(1, -24, 0, 1)
        tl.Position = UDim2.new(0, 12, 0, 32)
        tl.BackgroundColor3 = UI.line
        tl.BackgroundTransparency = 0.5; tl.BorderSizePixel = 0

        makeDraggable(panel, top)

        local ps = Instance.new("ScrollingFrame", panel)
        ps.Size = UDim2.new(1, -12, 1, -42); ps.Position = UDim2.new(0, 6, 0, 37)
        ps.BackgroundTransparency = 1; ps.BorderSizePixel = 0
        ps.ScrollBarThickness = 2; ps.ScrollBarImageColor3 = UI.line
        ps.AutomaticCanvasSize = Enum.AutomaticSize.Y
        ps.CanvasSize = UDim2.new()
        ps.ScrollingDirection = Enum.ScrollingDirection.Y
        local lay = Instance.new("UIListLayout", ps)
        lay.Padding = UDim.new(0, 5); lay.SortOrder = Enum.SortOrder.LayoutOrder

        local function paintSel()
            for id, t in pairs(thumbs) do
                local on = X.enabled and id == X.cur
                t.Color = on and UI.accent or UI.line
                t.Thickness = on and 2 or 1
            end
        end

        local gridBox = Instance.new("Frame", ps)
        gridBox.Size = UDim2.new(1, 0, 0, 0)
        gridBox.AutomaticSize = Enum.AutomaticSize.Y
        gridBox.LayoutOrder = 1; gridBox.BackgroundTransparency = 1
        local gl = Instance.new("UIGridLayout", gridBox)
        local cell = isMobile and 62 or 68
        gl.CellSize = UDim2.fromOffset(cell, cell)
        gl.CellPadding = UDim2.fromOffset(5, 5)
        gl.SortOrder = Enum.SortOrder.LayoutOrder

        for n, id in ipairs(IDS) do
            local b = Instance.new("ImageButton", gridBox)
            b.LayoutOrder = n; b.BackgroundColor3 = UI.row
            b.BackgroundTransparency = 0.1; b.BorderSizePixel = 0
            b.AutoButtonColor = false; b.ScaleType = Enum.ScaleType.Fit
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            local st = Instance.new("UIStroke", b)
            st.Thickness = 1; st.Color = UI.line
            thumbs[id] = st
            b.Activated:Connect(function()
                X.cur = id; X.enabled = true
                setOn(true); paintSel(); render()
            end)
            task.spawn(function() loadImage(b, id) end)
        end

        do
            local b, lbl = UI.rowBase(ps, 2, "show crosshair")
            local track = Instance.new("Frame", b)
            track.Size = UDim2.fromOffset(36, 18)
            track.AnchorPoint = Vector2.new(1, 0.5)
            track.Position = UDim2.new(1, -12, 0.5, 0)
            track.BorderSizePixel = 0
            Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
            local knob = Instance.new("Frame", track)
            knob.Size = UDim2.fromOffset(14, 14)
            knob.AnchorPoint = Vector2.new(0, 0.5)
            knob.BorderSizePixel = 0
            knob.BackgroundColor3 = Color3.fromRGB(255, 250, 255)
            Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
            setOn = function(v)
                X.enabled = v and true or false
                track.BackgroundColor3 = X.enabled and UI.accent or UI.off
                knob.Position = X.enabled
                    and UDim2.new(1, -16, 0.5, 0)
                    or UDim2.new(0, 2, 0.5, 0)
                lbl.TextColor3 = X.enabled and UI.text or Color3.fromRGB(150, 130, 145)
            end
            setOn(X.enabled)
            b.Activated:Connect(function()
                setOn(not X.enabled); paintSel(); render()
            end)
        end

        UI.slider(ps, 3, "size", 8, 150, X.size, function(v)
            X.size = v; render()
        end)

        local box = Instance.new("TextBox", ps)
        box.Size = UDim2.new(1, 0, 0, 30); box.LayoutOrder = 5
        box.BackgroundColor3 = UI.row; box.BackgroundTransparency = 0.05
        box.PlaceholderText = "enter image id..."
        box.PlaceholderColor3 = UI.dim
        box.Text = ""; box.ClearTextOnFocus = false
        box.TextColor3 = UI.text; box.Font = UI.font; box.TextSize = 12
        box.TextXAlignment = Enum.TextXAlignment.Left; box.BorderSizePixel = 0
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, UI.corner)
        Instance.new("UIPadding", box).PaddingLeft = UDim.new(0, 10)

        UI.action(ps, 6, "use this id", function()
            local id = tonumber((string.gsub(box.Text, "%D", "")))
            if id then
                X.cur = id; X.enabled = true
                setOn(true); paintSel(); render()
            end
        end)
        paintSel()

        local igui = Instance.new("ScreenGui")
        igui.Name = "CNP_CrosshairIcon"; igui.ResetOnSpawn = false
        igui.DisplayOrder = 2147483646
        mount(igui)
        local icon = Instance.new("TextButton", igui)
        icon.Size = UDim2.fromOffset(64, 40)
        icon.Position = UDim2.new(0.03, 0, 0.4, 0)
        icon.BackgroundColor3 = UI.bg; icon.BackgroundTransparency = 0.05
        icon.Text = "Shiftlock"; icon.TextColor3 = UI.text
        icon.Font = Enum.Font.BuilderSansBold; icon.TextSize = 11
        icon.AutoButtonColor = false; icon.Active = true
        Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 10)
        local ist = Instance.new("UIStroke", icon)
        ist.Color = UI.accent; ist.Thickness = 1.5

        local iDrag, iStart, iPos, iMoved, iLast = false, nil, nil, false, 0
        icon.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
               or i.UserInputType == Enum.UserInputType.Touch then
                iDrag = true; iMoved = false
                iStart = i.Position; iPos = icon.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if iDrag and (i.UserInputType == Enum.UserInputType.MouseMovement
               or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - iStart
                if d.Magnitude > 30 then iMoved = true end
                if iMoved then
                    icon.Position = UDim2.new(iPos.X.Scale, iPos.X.Offset + d.X,
                        iPos.Y.Scale, iPos.Y.Offset + d.Y)
                end
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if iDrag and (i.UserInputType == Enum.UserInputType.MouseButton1
               or i.UserInputType == Enum.UserInputType.Touch) then
                iDrag = false
            end
        end)
        icon.Activated:Connect(function()
            if iMoved or os.clock() - iLast < 0.25 then return end
            iLast = os.clock()
            gui.Enabled = not gui.Enabled
        end)
    end

    UI.action(scroll, 5, "crosshair", function()
        if not X.built then
            local ok, err = pcall(build)
            if not ok then warn("[CNP] crosshair build:", err) end
        end
        if gui then
            gui.Enabled = not gui.Enabled
            if gui.Enabled then
                gui.DisplayOrder = 2147483646
            end
        end
    end)
end



-- =====================================================================
-- SKYBOX (My Melody / Kuromi / Cinna) — sky only, no fog/brightness
-- =====================================================================
do
    local Lighting = game:GetService("Lighting")
    local SKY = {
        MyMelody = {
            Label = "My Melody",
            Bk = 112580788417374, Dn = 76445244290218, Ft = 99465758248467,
            Lf = 81358503463424, Rt = 124512710594732, Up = 99554554083078,
            Sun = 6196665106, Moon = 6444320592,
        },
        Kuromi = {
            Label = "Kuromi",
            Bk = 128347863539302, Dn = 78026197335557, Ft = 92502384929990,
            Lf = 76855314947494, Rt = 76773972098704, Up = 97649794413711,
            Sun = 6196665106, Moon = 6444320592,
        },
        Cinna = {
            Label = "Cinna",
            Bk = 95800443485595, Dn = 82068944590628, Ft = 116297505482359,
            Lf = 93826495998051, Rt = 93237266373246, Up = 90601359299354,
            Sun = 6196665106, Moon = 6444320592,
        },
    }
    local activePreset = nil
    local skyGui, skyFrame = nil, nil

    local function setProp(obj, prop, val)
        pcall(function() obj[prop] = val end)
    end

    local function getSky()
        for _, c in ipairs(Lighting:GetChildren()) do
            if c:IsA("Sky") and c.Name ~= "CNP_Sky" then
                pcall(function() c:Destroy() end)
            end
        end
        local sky = Lighting:FindFirstChild("CNP_Sky")
        if not sky then
            sky = Instance.new("Sky")
            sky.Name = "CNP_Sky"
            sky.Parent = Lighting
        end
        return sky
    end

    local function applySky(preset)
        if not preset then return end
        local sky = getSky()
        -- ONLY Sky instance textures — never Atmosphere / Fog / Ambient
        setProp(sky, "CelestialBodiesShown", true)
        setProp(sky, "SunAngularSize", 11)
        setProp(sky, "MoonAngularSize", 11)
        setProp(sky, "StarCount", 3000)
        local faces = {
            SkyboxBk = preset.Bk, SkyboxDn = preset.Dn, SkyboxFt = preset.Ft,
            SkyboxLf = preset.Lf, SkyboxRt = preset.Rt, SkyboxUp = preset.Up,
            SunTextureId = preset.Sun, MoonTextureId = preset.Moon,
        }
        for prop, id in pairs(faces) do
            if id and id ~= 0 then
                setProp(sky, prop, "rbxassetid://" .. tostring(id))
            end
        end
        -- explicitly do not modify Lighting.Fog* or Atmosphere
    end

    local function openSkyPanel()
        if skyGui and skyGui.Parent then
            skyGui.Enabled = not skyGui.Enabled
            return
        end
        skyGui = Instance.new("ScreenGui")
        skyGui.Name = "CNP_SkyPanel"
        skyGui.ResetOnSpawn = false
        skyGui.DisplayOrder = 2147483645
        skyGui.Parent = pg

        skyFrame = Instance.new("Frame")
        skyFrame.Size = UDim2.fromOffset(isMobile and 260 or 300, 260)
        skyFrame.Position = UDim2.new(0.5, -115, 0.25, 0)
        skyFrame.BackgroundColor3 = UI.bg
        skyFrame.BorderSizePixel = 0
        skyFrame.Active = true
        skyFrame.Parent = skyGui
        Instance.new("UICorner", skyFrame).CornerRadius = UDim.new(0, UI.corner)
        do
            local st = Instance.new("UIStroke", skyFrame)
            st.Color = UI.line
            st.Transparency = 0.3
            st.Thickness = 1.2
        end
        do
            local g = Instance.new("UIGradient", skyFrame)
            g.Rotation = 160
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 253, 255)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(232, 244, 252)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 226, 244)),
            })
        end

        local top = Instance.new("TextLabel", skyFrame)
        top.Size = UDim2.new(1, -36, 0, 30)
        top.Position = UDim2.fromOffset(10, 4)
        top.BackgroundTransparency = 1
        top.Font = UI.titleFont
        top.TextSize = 14
        top.TextColor3 = UI.text
        top.TextXAlignment = Enum.TextXAlignment.Left
        top.Text = "skybox"
        top.Active = true

        local close = Instance.new("TextButton", skyFrame)
        close.Size = UDim2.fromOffset(24, 24)
        close.Position = UDim2.new(1, -28, 0, 6)
        close.BackgroundTransparency = 1
        close.Text = "x"
        close.TextColor3 = UI.dim
        close.Font = UI.font
        close.TextSize = 16
        close.Activated:Connect(function()
            skyGui.Enabled = false
        end)

        local status = Instance.new("TextLabel", skyFrame)
        status.Size = UDim2.new(1, -20, 0, 16)
        status.Position = UDim2.fromOffset(10, 32)
        status.BackgroundTransparency = 1
        status.Font = UI.font
        status.TextSize = 11
        status.TextColor3 = UI.dim
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Text = "pick a sky"

        local function mkBtn(text, y, key, col)
            local b = Instance.new("TextButton", skyFrame)
            b.Size = UDim2.new(1, -20, 0, 34)
            b.Position = UDim2.fromOffset(10, y)
            b.BackgroundColor3 = col
            b.BackgroundTransparency = 0.15
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Text = text
            b.TextColor3 = Color3.fromRGB(255, 255, 255)
            b.Font = UI.font
            b.TextSize = 13
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
            local st = Instance.new("UIStroke", b)
            st.Color = UI.line
            st.Transparency = 0.35
            st.Thickness = 1
            b.Activated:Connect(function()
                activePreset = SKY[key]
                applySky(activePreset)
                status.Text = "on · " .. SKY[key].Label
            end)
        end
        mkBtn("My Melody", 54, "MyMelody", Color3.fromRGB(90, 160, 210))
        mkBtn("Kuromi", 94, "Kuromi", Color3.fromRGB(70, 120, 180))
        mkBtn("Cinna", 134, "Cinna", Color3.fromRGB(100, 175, 220))

        makeDraggable(skyFrame, top)

        -- reapply lightly so map scripts don't wipe sky
        task.spawn(function()
            while skyGui and skyGui.Parent do
                task.wait(2.5)
                if activePreset then
                    applySky(activePreset)
                end
            end
        end)
    end

    UI.action(scroll, 14.5, "skybox", function()
        openSkyPanel()
    end)
end

-- =====================================================================
-- C4 MENU
-- =====================================================================
do
    local function BuildC4()
        local Main = Instance.new("Part")
        Main.Name = "Handle"
        Main.Size = Vector3.new(1.8, 0.7, 1.2)
        Main.Color = Config.BombColor
        Main.Material = Enum.Material.Metal
        Main.CanCollide = true
        return Main
    end

    local function GiveTool()
        local Tool = Instance.new("Tool")
        Tool.Name = Config.ToolName
        Tool.RequiresHandle = true
        Tool.CanBeDropped = false
        Tool.Grip = CFrame.new(0, -0.2, 0.2) * CFrame.Angles(0, math.rad(180), 0)
        local C4Part = BuildC4()
        C4Part.Parent = Tool
        table.insert(ActiveTools, Tool)

        Tool.Activated:Connect(function()
            if not Config.CanUse then return end
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            Config.CanUse = false
            if CurrentDroppedBomb then CurrentDroppedBomb:Destroy() end

            -- Simple drop under feet + throw toward mouse
            local d_handle = BuildC4()
            d_handle.CFrame = hrp.CFrame * CFrame.new(0, -3.2, 0)
            d_handle.Parent = Workspace
            CurrentDroppedBomb = d_handle

            local dir = (mouse.Hit.p - hrp.Position)
            if dir.Magnitude > 0.1 then
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Velocity = dir.Unit * 25 + Vector3.new(0, 10, 0)
                bv.Parent = d_handle
                game:GetService("Debris"):AddItem(bv, 0.1)
            end

            -- Hide hand part during cooldown
            local parts = {}
            for _, p in pairs(Tool:GetChildren()) do
                if p:IsA("BasePart") then
                    parts[p] = p.Transparency
                    p.Transparency = 1
                end
            end

            task.wait(Config.Cooldown)

            if CurrentDroppedBomb then
                CurrentDroppedBomb:Destroy()
                CurrentDroppedBomb = nil
            end
            for p, trans in pairs(parts) do
                if p then p.Transparency = trans end
            end
            Config.CanUse = true
        end)
        Tool.Parent = player:WaitForChild("Backpack")
    end

    local function clearAllBombs()
        for _, tool in ipairs(ActiveTools) do
            if tool and tool.Parent then pcall(function() tool:Destroy() end) end
        end
        for i = #ActiveTools, 1, -1 do ActiveTools[i] = nil end
        local function clean(c)
            if not c then return end
            for _, o in ipairs(c:GetChildren()) do
                if o:IsA("Tool") and o.Name == Config.ToolName then
                    pcall(function() o:Destroy() end)
                end
            end
        end
        clean(player:FindFirstChild("Backpack"))
        clean(player.Character)
        if CurrentDroppedBomb then
            pcall(function() CurrentDroppedBomb:Destroy() end)
            CurrentDroppedBomb = nil
        end
        Config.CanUse = true
    end

    local function refreshAllBombs()
        for _, tool in ipairs(ActiveTools) do
            if tool and tool.Parent then
                local h = tool:FindFirstChild("Handle")
                if h and h:IsA("BasePart") then
                    h.Color = Config.BombColor
                end
            end
        end
        if CurrentDroppedBomb and CurrentDroppedBomb:IsA("BasePart") then
            CurrentDroppedBomb.Color = Config.BombColor
        end
    end

    local c4Gui = Instance.new("ScreenGui")
    c4Gui.Name = "C4_Modern_Menu"; c4Gui.ResetOnSpawn = false
    c4Gui.DisplayOrder = 2147483646; c4Gui.Parent = pg; c4Gui.Enabled = false

    local c4Frame = Instance.new("Frame", c4Gui)
    do
        local ch = fitH(isMobile and 380 or 460)
        local cw = isMobile and 260 or 300
        c4Frame.Size = UDim2.new(0, cw, 0, ch)
        c4Frame.Position = isMobile
            and UDim2.new(0.5, -cw/2 + 40, 0.5, -ch / 2)
            or UDim2.new(0.5, -cw/2 + 50, 0.5, -ch / 2)
    end
    c4Frame.BackgroundColor3 = UI.bg; c4Frame.BorderSizePixel = 0
    c4Frame.ClipsDescendants = true
    applyGlass(c4Frame, 0.2)
    Instance.new("UICorner", c4Frame).CornerRadius = UDim.new(0, 4)
    do
        local st = Instance.new("UIStroke", c4Frame)
        st.Color = UI.line; st.Thickness = 1
    end

    local c4Top = Instance.new("Frame", c4Frame)
    c4Top.Size = UDim2.new(1, 0, 0, 30)
    c4Top.BackgroundTransparency = 1; c4Top.Active = true

    local c4Title = Instance.new("TextLabel", c4Top)
    c4Title.Size = UDim2.new(1, -36, 1, 0); c4Title.BackgroundTransparency = 1
    c4Title.Text = "c4"; c4Title.TextColor3 = UI.text
    c4Title.Font = UI.font; c4Title.TextSize = 14
    c4Title.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UIPadding", c4Title).PaddingLeft = UDim.new(0, 12)

    local c4Close = Instance.new("TextButton", c4Top)
    c4Close.Size = UDim2.fromOffset(26, 26)
    c4Close.Position = UDim2.new(1, -30, 0, 2)
    c4Close.BackgroundTransparency = 1
    c4Close.Text = "x"; c4Close.TextColor3 = UI.dim
    c4Close.Font = UI.font; c4Close.TextSize = 14; c4Close.BorderSizePixel = 0
    c4Close.Activated:Connect(function() c4Gui.Enabled = false end)

    local c4Line = Instance.new("Frame", c4Frame)
    c4Line.Size = UDim2.new(1, 0, 0, 1)
    c4Line.Position = UDim2.new(0, 0, 0, 30)
    c4Line.BackgroundColor3 = UI.line; c4Line.BorderSizePixel = 0

    local c4Scroll = Instance.new("ScrollingFrame", c4Frame)
    c4Scroll.Size = UDim2.new(1, -12, 1, -38)
    c4Scroll.Position = UDim2.new(0, 6, 0, 34)
    c4Scroll.BackgroundTransparency = 1; c4Scroll.BorderSizePixel = 0
    c4Scroll.ScrollBarThickness = 2; c4Scroll.ScrollBarImageColor3 = UI.line
    c4Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    c4Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    do
        local lay = Instance.new("UIListLayout", c4Scroll)
        lay.Padding = UDim.new(0, 5); lay.SortOrder = Enum.SortOrder.LayoutOrder
    end

    local function createC4Input(order, labelText, defaultText)
        local f = Instance.new("Frame", c4Scroll)
        f.Size = UDim2.new(1, 0, 0, 44); f.BackgroundTransparency = 1
        f.LayoutOrder = order
        local lbl = Instance.new("TextLabel", f)
        lbl.Size = UDim2.new(1, 0, 0, 14); lbl.BackgroundTransparency = 1
        lbl.Text = labelText; lbl.TextColor3 = UI.dim
        lbl.Font = UI.font; lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        local box = Instance.new("TextBox", f)
        box.Size = UDim2.new(1, 0, 0, 26); box.Position = UDim2.new(0, 0, 0, 16)
        box.Text = defaultText; box.BackgroundColor3 = UI.row
        box.TextColor3 = UI.text; box.Font = UI.font; box.TextSize = 12
        box.BorderSizePixel = 0; box.ClearTextOnFocus = false
        box.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UIPadding", box).PaddingLeft = UDim.new(0, 8)
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)
        return box
    end

    local function createC4Button(order, text, bg, fg)
        local b = Instance.new("TextButton", c4Scroll)
        b.Size = UDim2.new(1, 0, 0, 28); b.LayoutOrder = order
        b.BackgroundColor3 = bg; b.Text = text; b.TextColor3 = fg
        b.Font = UI.font; b.TextSize = 12; b.BorderSizePixel = 0
        b.AutoButtonColor = true
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
        return b
    end

    local inputCD = createC4Input(1, "cooldown (sec)", tostring(Config.Cooldown))
    local inputAmount = createC4Input(2, "bomb amount", tostring(Config.BombAmount))
    local inputName = createC4Input(3, "tool name", Config.ToolName)

    local colorBtnC4 = createC4Button(4, "bomb color", UI.row, UI.text)
    colorBtnC4.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UIPadding", colorBtnC4).PaddingLeft = UDim.new(0, 10)
    local swatch = Instance.new("Frame", colorBtnC4)
    swatch.Size = UDim2.fromOffset(14, 14)
    swatch.AnchorPoint = Vector2.new(1, 0.5)
    swatch.Position = UDim2.new(1, -10, 0.5, 0)
    swatch.BackgroundColor3 = Config.BombColor; swatch.BorderSizePixel = 0
    Instance.new("UICorner", swatch).CornerRadius = UDim.new(1, 0)

    local c4ColorFrame = Instance.new("Frame", c4Scroll)
    c4ColorFrame.Size = UDim2.new(1, 0, 0, 122); c4ColorFrame.LayoutOrder = 5
    c4ColorFrame.BackgroundColor3 = UI.row; c4ColorFrame.BorderSizePixel = 0
    c4ColorFrame.Visible = false
    Instance.new("UICorner", c4ColorFrame).CornerRadius = UDim.new(0, 3)
    do
        local g = Instance.new("UIGridLayout", c4ColorFrame)
        g.CellSize = UDim2.fromOffset(30, 30)
        g.CellPadding = UDim2.fromOffset(6, 6)
        g.HorizontalAlignment = Enum.HorizontalAlignment.Center
        g.VerticalAlignment = Enum.VerticalAlignment.Center
    end

    local saveBtnC4 = createC4Button(7, "save & create bomb",
        UI.accent, Color3.fromRGB(20, 20, 22))
    local clearBtnC4 = createC4Button(8, "clear bombs",
        UI.row, Color3.fromRGB(235, 120, 120))
    clearBtnC4.Activated:Connect(function()
        clearAllBombs()
        clearBtnC4.Text = "cleared"
        task.delay(1, function() clearBtnC4.Text = "clear bombs" end)
    end)

    local c4Colors = {
        Color3.fromRGB(235, 30, 30), Color3.fromRGB(250, 100, 20),
        Color3.fromRGB(255, 170, 0), Color3.fromRGB(255, 230, 0),
        Color3.fromRGB(170, 220, 20), Color3.fromRGB(70, 200, 70),
        Color3.fromRGB(0, 180, 160), Color3.fromRGB(0, 150, 255),
        Color3.fromRGB(70, 80, 220), Color3.fromRGB(130, 60, 200),
        Color3.fromRGB(220, 50, 180), Color3.fromRGB(240, 50, 100),
        Color3.fromRGB(0, 0, 0),
    }
    for _, c in ipairs(c4Colors) do
        local b = Instance.new("TextButton", c4ColorFrame)
        b.BackgroundColor3 = c; b.Text = ""; b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        b.Activated:Connect(function()
            Config.BombColor = c
            swatch.BackgroundColor3 = c
            c4ColorFrame.Visible = false
            refreshAllBombs()
        end)
    end
    colorBtnC4.Activated:Connect(function()
        c4ColorFrame.Visible = not c4ColorFrame.Visible
    end)

    saveBtnC4.Activated:Connect(function()
        Config.Cooldown = tonumber(inputCD.Text) or 2
        Config.BombAmount = tonumber(inputAmount.Text) or 1
        local nm = inputName.Text
        if not nm or nm == "" then nm = "Gold C4 Bomb" end
        Config.ToolName = nm
        c4Gui.Enabled = false
        clearAllBombs()
        task.wait(0.1)
        for _ = 1, Config.BombAmount do GiveTool() end
    end)

    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        clearAllBombs()
    end)

    makeDraggable(c4Frame, c4Top)

    UI.action(scroll, 7, "c4 menu", function()
        c4Gui.Enabled = not c4Gui.Enabled
    end)
end

-- =====================================================================
-- FLY
-- =====================================================================
do
local flying, flySpeed = false, 80
local flyBV, flyBG, flyAtt, flyConn = nil, nil, nil, nil
local flyUp, flyDown = false, false

local flyGui = Instance.new("ScreenGui")
flyGui.Name = "CNP_Fly"; flyGui.ResetOnSpawn = false
flyGui.DisplayOrder = 2147483646; flyGui.Enabled = false; flyGui.Parent = pg

local flyFrame = Instance.new("Frame", flyGui)
do
    local fw = isMobile and 260 or 300
    local fh = 250
    flyFrame.Size = UDim2.fromOffset(fw, fh)
    flyFrame.Position = UDim2.new(0.5, -fw / 2, 0.12, 0)
end
flyFrame.BackgroundColor3 = UI.bg; flyFrame.BackgroundTransparency = 0.05
flyFrame.BorderSizePixel = 0; flyFrame.Active = true; flyFrame.ClipsDescendants = true
Instance.new("UICorner", flyFrame).CornerRadius = UDim.new(0, 12)
do
    local st = Instance.new("UIStroke", flyFrame)
    st.Color = Color3.fromRGB(80, 80, 95)
    st.Transparency = 0.2; st.Thickness = 1
end

local flyTitle = Instance.new("TextLabel", flyFrame)
flyTitle.Size = UDim2.new(1, -40, 0, 32); flyTitle.BackgroundTransparency = 1
flyTitle.Active = true; flyTitle.Text = "fly"; flyTitle.TextColor3 = UI.text
flyTitle.Font = Enum.Font.BuilderSansBold; flyTitle.TextSize = 15
flyTitle.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UIPadding", flyTitle).PaddingLeft = UDim.new(0, 12)
makeDraggable(flyFrame, flyTitle)

local flyCloseBtn = Instance.new("TextButton", flyFrame)
flyCloseBtn.Size = UDim2.fromOffset(26, 26)
flyCloseBtn.Position = UDim2.new(1, -30, 0, 3)
flyCloseBtn.BackgroundTransparency = 1
flyCloseBtn.Text = "x"; flyCloseBtn.TextColor3 = UI.dim
flyCloseBtn.Font = UI.font; flyCloseBtn.TextSize = 16; flyCloseBtn.BorderSizePixel = 0

local flyLine = Instance.new("Frame", flyFrame)
flyLine.Size = UDim2.new(1, -24, 0, 1)
flyLine.Position = UDim2.new(0, 12, 0, 32)
flyLine.BackgroundColor3 = UI.line
flyLine.BackgroundTransparency = 0.5; flyLine.BorderSizePixel = 0

local flyBody = Instance.new("Frame", flyFrame)
flyBody.Size = UDim2.new(1, -16, 1, -42)
flyBody.Position = UDim2.new(0, 8, 0, 38)
flyBody.BackgroundTransparency = 1
do
    local lay = Instance.new("UIListLayout", flyBody)
    lay.Padding = UDim.new(0, 6); lay.SortOrder = Enum.SortOrder.LayoutOrder
end

local flyToggle = Instance.new("TextButton", flyBody)
flyToggle.Size = UDim2.new(1, 0, 0, 36); flyToggle.LayoutOrder = 1
flyToggle.BackgroundColor3 = UI.row
flyToggle.AutoButtonColor = false; flyToggle.BorderSizePixel = 0
flyToggle.Text = "FLY"; flyToggle.TextColor3 = UI.text
flyToggle.Font = Enum.Font.BuilderSansBold; flyToggle.TextSize = 15
Instance.new("UICorner", flyToggle).CornerRadius = UDim.new(0, UI.corner)
local flyToggleStroke = Instance.new("UIStroke", flyToggle)
flyToggleStroke.Color = UI.line
flyToggleStroke.Transparency = 0.4; flyToggleStroke.Thickness = 1

UI.slider(flyBody, 2, "speed", 10, 300, flySpeed, function(v)
    flySpeed = math.max(10, v)
end)

local flyRow = Instance.new("Frame", flyBody)
flyRow.Size = UDim2.new(1, 0, 0, 34)
flyRow.LayoutOrder = 3; flyRow.BackgroundTransparency = 1

local function flyHoldBtn(text, xs, xo)
    local b = Instance.new("TextButton", flyRow)
    b.Size = UDim2.new(0.5, -3, 1, 0)
    b.Position = UDim2.new(xs, xo, 0, 0)
    b.BackgroundColor3 = UI.row; b.AutoButtonColor = false
    b.BorderSizePixel = 0; b.Text = text; b.TextColor3 = UI.text
    b.Font = UI.font; b.TextSize = 13
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, UI.corner)
    local st = Instance.new("UIStroke", b)
    st.Color = UI.line; st.Transparency = 0.5; st.Thickness = 1
    return b
end
local flyUpBtn = flyHoldBtn("UP", 0, 0)
local flyDownBtn = flyHoldBtn("DOWN", 0.5, 3)

local function holdBtn(btn, setter)
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            setter(true); btn.BackgroundColor3 = UI.hover
        end
    end)
    btn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            setter(false); btn.BackgroundColor3 = UI.row
        end
    end)
end
holdBtn(flyUpBtn, function(v) flyUp = v end)
holdBtn(flyDownBtn, function(v) flyDown = v end)

local flyControls = nil
local function getMoveVector()
    local x = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
        - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
    local z = (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
        - (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
    if x ~= 0 or z ~= 0 then return Vector3.new(x, 0, z) end

    if not flyControls then
        pcall(function()
            local ps = player:FindFirstChild("PlayerScripts")
            if not ps then return end
            local pm = ps:FindFirstChild("PlayerModule")
            if not pm then return end
            local cm = pm:FindFirstChild("ControlModule")
            if cm then flyControls = require(cm) end
        end)
    end
    if flyControls then
        local ok, v = pcall(function() return flyControls:GetMoveVector() end)
        if ok and v and v.Magnitude > 0 then return v end
    end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local cam = Workspace.CurrentCamera
    if hum and cam and hum.MoveDirection.Magnitude > 0.05 then
        local l = cam.CFrame:VectorToObjectSpace(hum.MoveDirection)
        return Vector3.new(l.X, 0, l.Z)
    end
    return Vector3.new(0, 0, 0)
end

local function paintFlyBtn()
    flyToggle.Text = flying and "STOP" or "FLY"
    softTween(flyToggle, { BackgroundColor3 = flying and UI.accent or UI.row }, 0.18)
    flyToggle.TextColor3 = flying and Color3.new(1, 1, 1) or UI.text
end

local function stopFly()
    flying = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then pcall(function() flyBV:Destroy() end); flyBV = nil end
    if flyBG then pcall(function() flyBG:Destroy() end); flyBG = nil end
    if flyAtt then pcall(function() flyAtt:Destroy() end); flyAtt = nil end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        if not speedEnabled then hum.WalkSpeed = BASE_SPEED end
    end
    paintFlyBtn()
end

local function startFly()
    if flying then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    flying = true
    hum.PlatformStand = true
    flyAtt = Instance.new("Attachment")
    flyAtt.Name = "CNP_FlyAtt"
    flyAtt.Parent = root
    flyBV = Instance.new("LinearVelocity")
    flyBV.Name = "CNP_FlyLV"
    flyBV.Attachment0 = flyAtt
    flyBV.MaxForce = 1e5
    flyBV.VectorVelocity = Vector3.zero
    flyBV.RelativeTo = Enum.ActuatorRelativeTo.World
    flyBV.Parent = root
    flyBG = Instance.new("AlignOrientation")
    flyBG.Name = "CNP_FlyAO"
    flyBG.Attachment0 = flyAtt
    flyBG.Mode = Enum.OrientationAlignmentMode.OneAttachment
    flyBG.Responsiveness = 200
    flyBG.MaxTorque = 1e5
    flyBG.Parent = root
    paintFlyBtn()
    local curVel = Vector3.zero
    flyConn = RunService.RenderStepped:Connect(function(dt)
        if not flying or not flyBV or not flyBV.Parent then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local move = getMoveVector()
        local vertical = 0
        if flyUp or UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertical = vertical + 1 end
        if flyDown or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vertical = vertical - 1 end
        local dir = cam.CFrame:VectorToWorldSpace(Vector3.new(move.X, 0, move.Z))
            + Vector3.new(0, vertical, 0)
        local want = dir.Magnitude > 0.05 and dir.Unit * flySpeed or Vector3.zero
        curVel = curVel:Lerp(want, 1 - math.exp(-14 * dt))
        flyBV.VectorVelocity = curVel
        if flyBG then
            flyBG.CFrame = CFrame.new(root.Position, root.Position + cam.CFrame.LookVector)
        end
    end)
end

flyToggle.Activated:Connect(function()
    if flying then stopFly() else startFly() end
end)
flyCloseBtn.Activated:Connect(function()
    stopFly(); flyGui.Enabled = false
end)
player.CharacterAdded:Connect(function() stopFly() end)

UI.action(scroll, 2, "fly gui", function()
    flyGui.Enabled = not flyGui.Enabled
    if not flyGui.Enabled then stopFly() end
end)

-- =====================================================================
-- LIST USER
-- =====================================================================
end -- close FLY block

do
local listGui = Instance.new("ScreenGui")
listGui.Name = "ListUserPanel"; listGui.ResetOnSpawn = false
listGui.DisplayOrder = 2147483646; listGui.Parent = pg; listGui.Enabled = false

local NAMES = {
    "riquywz", "fifikamah", "iszaquiho", "totartoor", "caio021213", "jusahxz",
    "erickpontes8087k", "yysnowzxz", "0Axyyhp", "d9rings", "lunapipoka",
    "vyperion_gamer", "xXLok_DBXx", "ydedexzk", "0ysbell", "dgsxtz",
    "MarcosYT224", "miko_yara22", "9dedoslula13", "v1ctorxxzc", "nick23ht",
    "Miguelb2328p", "ilxNyxz", "florwerxz", "peixinkokkj", "XDBerna7",
    "vencedor87", "28kxPuppy", "28kxlucaz", "29kxHar", "pdenadai",
    "43dramalho", "jeremarcospr011", "biel975oi", "nnsochescrivere21", "lokis23162", "yoyok_felipe", "Guhtxk", "dezxql", "samantw540", "dezxql91", "l3nnon_blox", "0_crzxwy", "souruin_nomurder", "doraa2911", "soukaina9999999999", "28kxfrwd",
    "Doumabr", "mm2_davz", "jerehzxs", "leyaldiecoole12", "kwwhhei", "flxyerz", "gb2013q8", "solit9de", "BALA_LOVE0KKJ",
}
local TOTAL = #NAMES
local TOTAL_OK = TOTAL

local function copyToClipboard(text)
    local fn = (type(setclipboard) == "function" and setclipboard)
        or (type(toclipboard) == "function" and toclipboard)
        or (type(writeclipboard) == "function" and writeclipboard)
    if not fn then return false end
    return (pcall(fn, text))
end

local mainList = Instance.new("Frame")
mainList.Size = UDim2.fromOffset(fitW(360), fitH(480))
mainList.Position = UDim2.new(0.5, 0, 0.5, 0)
mainList.AnchorPoint = Vector2.new(0.5, 0.5)
mainList.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
mainList.BorderSizePixel = 0; mainList.Active = true
applyGlass(mainList, 0.2); mainList.Parent = listGui
Instance.new("UICorner", mainList).CornerRadius = UDim.new(0, 8)
local ms = Instance.new("UIStroke", mainList)
ms.Color = Color3.fromRGB(0, 0, 0); ms.Thickness = 2

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
titleBar.BorderSizePixel = 0; titleBar.Parent = mainList
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
makeDraggable(mainList, titleBar)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -46, 1, 0); title.Position = UDim2.new(0, 12, 0, 0)
title.Font = Enum.Font.BuilderSansBold
title.Text = "LIST USER CNP • " .. TOTAL
title.TextColor3 = Color3.fromRGB(255, 255, 255); title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(24, 24); closeBtn.Position = UDim2.new(1, -30, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeBtn.Text = "X"; closeBtn.Font = Enum.Font.BuilderSansBold
closeBtn.TextSize = 12; closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
closeBtn.Activated:Connect(function() listGui.Enabled = false end)

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -20, 0, 25); searchBox.Position = UDim2.new(0, 10, 0, 42)
searchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
searchBox.PlaceholderText = "Search name..."
searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
searchBox.Text = ""; searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBox.Font = Enum.Font.BuilderSans; searchBox.TextSize = 11
searchBox.ClearTextOnFocus = false; searchBox.Parent = mainList
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)

local SCROLL_TOP = 75
local scrollList = Instance.new("ScrollingFrame")
scrollList.Size = UDim2.new(1, -10, 1, -(SCROLL_TOP + 8))
scrollList.Position = UDim2.new(0, 5, 0, SCROLL_TOP)
scrollList.BackgroundTransparency = 1; scrollList.BorderSizePixel = 0
scrollList.ScrollBarThickness = 3
scrollList.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollList.ScrollingDirection = Enum.ScrollingDirection.Y
scrollList.Parent = mainList

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4); layout.Parent = scrollList
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 2); pad.PaddingLeft = UDim.new(0, 2)
pad.PaddingRight = UDim.new(0, 2); pad.Parent = scrollList

local rows = {}
local function createRow(name, order)
    local row = Instance.new("Frame")
    row.Name = name; row.Size = UDim2.new(1, -4, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = scrollList
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", row)
    stroke.Color = Color3.fromRGB(60, 60, 65); stroke.Thickness = 1

    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.fromOffset(28, 28)
    avatar.Position = UDim2.new(0, 5, 0.5, 0)
    avatar.AnchorPoint = Vector2.new(0, 0.5)
    avatar.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    avatar.BorderSizePixel = 0; avatar.Image = ""
    avatar.ScaleType = Enum.ScaleType.Crop; avatar.Parent = row
    Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -100, 1, 0); label.Position = UDim2.new(0, 38, 0, 0)
    label.Font = Enum.Font.BuilderSansBold; label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255); label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd; label.Parent = row

    local hint = Instance.new("TextLabel")
    hint.BackgroundTransparency = 1
    hint.Size = UDim2.fromOffset(50, 38); hint.Position = UDim2.new(1, -55, 0, 0)
    hint.Font = Enum.Font.BuilderSansBold; hint.Text = "COPY"
    hint.TextColor3 = Color3.fromRGB(255, 100, 150); hint.TextSize = 10
    hint.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromScale(1, 1); btn.BackgroundTransparency = 1
    btn.Text = ""; btn.Parent = row
    btn.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12),
            { BackgroundColor3 = Color3.fromRGB(45, 45, 50) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12),
            { BackgroundColor3 = Color3.fromRGB(30, 30, 35) }):Play()
    end)
    btn.Activated:Connect(function()
        local ok = copyToClipboard(name)
        if ok then
            hint.Text = "COPIED"; hint.TextColor3 = Color3.fromRGB(130, 220, 160)
        else
            hint.Text = "FAIL!"; hint.TextColor3 = Color3.fromRGB(220, 50, 50)
        end
        task.delay(1.2, function()
            hint.Text = "COPY"; hint.TextColor3 = Color3.fromRGB(255, 100, 150)
        end)
    end)
    table.insert(rows, { name = name, avatar = avatar, frame = row })
end

for i, n in ipairs(NAMES) do createRow(n, i) end
scrollList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 15)
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 15)
end)

task.spawn(function()
    for i = #rows, 1, -1 do
        local data = rows[i]
        local ok, userId = pcall(function()
            return Players:GetUserIdFromNameAsync(data.name)
        end)
        if not ok or not userId or userId <= 0 then
            data.frame:Destroy()
            table.remove(rows, i)
            TOTAL_OK = TOTAL_OK - 1
            title.Text = ("LIST USER CNP • %d/%d"):format(TOTAL_OK, TOTAL)
        else
            local ok2, img = pcall(function()
                return Players:GetUserThumbnailAsync(userId,
                    Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok2 and img then data.avatar.Image = img end
        end
        task.wait(0.1)
    end
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q = searchBox.Text:lower()
    for _, data in ipairs(rows) do
        if q == "" then
            data.frame.Visible = true
        else
            data.frame.Visible = data.name:lower():find(q, 1, true) ~= nil
        end
    end
end)

UI.action(scroll, 18, "list user cnp", function()
    if listGui then listGui.Enabled = not listGui.Enabled end
end)


-- =====================================================================
-- ESP (Role outline: Knife = red, Gun = blue, others = white)
-- =====================================================================
do
local espActive = false
local ESP_NAME = "CNP_ToolESP"
local ESP_COLORS = {
    Knife = Color3.fromRGB(255, 70, 90),
    Gun = Color3.fromRGB(70, 140, 255),
    None = Color3.fromRGB(255, 255, 255),
}
local espLoopToken = 0

local function espHasTool(plr, toolName)
    local bp = plr:FindFirstChildOfClass("Backpack")
    if bp and bp:FindFirstChild(toolName) then return true end
    local ch = plr.Character
    if ch and ch:FindFirstChild(toolName) then return true end
    return false
end

local function espClear(plr)
    local ch = plr.Character
    local h = ch and ch:FindFirstChild(ESP_NAME)
    if h then h:Destroy() end
end

local function espUpdate(plr)
    if plr == player then return end
    local ch = plr.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not ch or not hum or hum.Health <= 0 then
        espClear(plr)
        return
    end
    local col = ESP_COLORS.None
    if espHasTool(plr, "Knife") then
        col = ESP_COLORS.Knife
    elseif espHasTool(plr, "Gun") then
        col = ESP_COLORS.Gun
    end
    local hl = ch:FindFirstChild(ESP_NAME)
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = ESP_NAME
        hl.Adornee = ch
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 1 -- outline only
        hl.Parent = ch
    end
    hl.OutlineColor = col
    hl.OutlineTransparency = 0
    hl.FillColor = col
end

local function espStop()
    espActive = false
    espLoopToken = espLoopToken + 1
    for _, plr in ipairs(Players:GetPlayers()) do espClear(plr) end
end

local function espStart()
    if espActive then return end
    espActive = true
    espLoopToken = espLoopToken + 1
    local my = espLoopToken
    task.spawn(function()
        while espActive and my == espLoopToken do
            for _, plr in ipairs(Players:GetPlayers()) do
                pcall(espUpdate, plr)
            end
            task.wait(0.5)
        end
    end)
end

UI.toggle(scroll, 3, "esp", false, function(v)
    if v then espStart() else espStop() end
end)
-- order 3 = esp (kept)

end -- close ESP block

end -- close LIST USER block (fix)

-- Minimize
minBtn.Activated:Connect(function()
    isMini = not isMini
    scroll.Visible = not isMini
    if UI.decor then UI.decor.Visible = not isMini end
    minBtn.Text = isMini and "+" or "-"
    local target = isMini
        and UDim2.new(UI.full.X.Scale, UI.full.X.Offset, 0, 31)
        or UI.full
    TweenService:Create(mainFrame,
        TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Size = target }):Play()
end)

-- =====================================================================
-- ADVANCED: KEY GATE + GEAR + BEAM
-- =====================================================================
local TOOLS_KEY = "" -- key system removed
local toolsUnlocked = true

local function CNP_GearSection() -- own function = own 200-local budget
local function getHum()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end


local function carpetReleaseMove(hum)
    if not hum then return end
    pcall(function()
        hum.PlatformStand = false
        hum.Sit = false
        hum.AutoRotate = true
        if hum.WalkSpeed < 1 and not speedEnabled then
            hum.WalkSpeed = BASE_SPEED
        end
    end)
    -- do not force MouseBehavior.Default if user is shiftlocked
    pcall(function()
        if not enableOldShiftLock
            and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
            -- leave as-is
        end
    end)
end

local function createRainbowCarpet()
    local BaseUrl = "http://www.roblox.com/asset/?id="
    local CarpetPieces = {
        { MeshId = 223079795 }, { MeshId = 223079835 },
        { MeshId = 223079888 }, { MeshId = 223079981 },
    }
    local CarpetSize = Vector3.new(3, 0.5, 6.5)
    local CarpetOffset = Vector3.new(0, -1.6, 0.5)
    local CameraSpeed = { X = 70, Z = 105 }
    local Rate = 1 / 10
    local RainbowColors = {
        Color3.new(1, 0, 0), Color3.new(1, 0.5, 0), Color3.new(1, 1, 0), Color3.new(0, 1, 0),
        Color3.new(0, 1, 1), Color3.new(0, 0, 1), Color3.new(0.5, 0, 1),
    }
    local Grips = {
        Normal = CFrame.new(-1.5, 0, 0, 0, 0, -1, -1, 8.90154915e-005, 0, 8.90154915e-005, 1, 0),
        Flying = CFrame.new(-1.5, 0.5, -0.75, -1, 0, -8.99756625e-009, -8.99756625e-009, 8.10000031e-008, 1, 7.28802977e-016, 0.99999994, -8.10000103e-008),
    }
    local old = bp:FindFirstChild("Rainbow Carpet") or (player.Character and player.Character:FindFirstChild("Rainbow Carpet"))
    if old then old:Destroy() end

    local Tool = Instance.new("Tool")
    Tool.Name = "Rainbow Carpet"
    Tool.RequiresHandle = true
    Tool.CanBeDropped = false
    Tool.Grip = Grips.Normal
    Tool.TextureId = "rbxassetid://223080070"

    local Handle = Instance.new("Part")
    Handle.Name = "Handle"; Handle.Size = CarpetSize
    Handle.Transparency = 1; Handle.CanCollide = false; Handle.Massless = true
    Handle.Parent = Tool

    local Roll = Instance.new("Part")
    Roll.Name = "Roll"; Roll.Size = CarpetSize
    Roll.CanCollide = false; Roll.Massless = true
    local RollMesh = Instance.new("SpecialMesh")
    RollMesh.MeshType = Enum.MeshType.FileMesh
    RollMesh.MeshId = BaseUrl .. "223079737"
    RollMesh.Scale = Vector3.new(1.125, 1.125, 1.125)
    RollMesh.TextureId = BaseUrl .. "223080038"
    RollMesh.Parent = Roll
    local RollWeld = Instance.new("Weld")
    RollWeld.Part0 = Handle; RollWeld.Part1 = Roll; RollWeld.Parent = Roll
    Roll.Parent = Tool

    local SitR6 = Instance.new("Animation"); SitR6.AnimationId = "http://www.roblox.com/asset/?id=225279725"; SitR6.Parent = Tool
    local SitR15 = Instance.new("Animation"); SitR15.AnimationId = "rbxassetid://855828754"; SitR15.Parent = Tool

    local Flying, ToolEquipped, Cooldown = false, false, false
    local Character, Humanoid, Root
    local FlightSpin, FlightPower, FlightHold, AnimTrack, FlightConn
    local TrailFolder = Workspace:FindFirstChild("CarpetRainbow") or Instance.new("Folder")
    TrailFolder.Name = "CarpetRainbow"; TrailFolder.Parent = Workspace

    local function CheckIfAlive()
        return Character and Character.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0
            and Root and Root.Parent
    end
    local function CleanUpCarpet()
        for _, v in ipairs(Tool:GetChildren()) do
            if v:IsA("BasePart") and v ~= Handle and v.Name ~= "Roll" then v:Destroy() end
        end
    end
    local function BuildCarpet()
        local n = #CarpetPieces
        for i, v in ipairs(CarpetPieces) do
            local part = Instance.new("Part")
            part.Size = Vector3.new(CarpetSize.X, CarpetSize.Y, CarpetSize.Z / n)
            part.CanCollide = false; part.Massless = true
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. v.MeshId
            mesh.TextureId = BaseUrl .. "223080038"
            mesh.Scale = Vector3.new(1.125, 1.125, 1.125)
            mesh.Parent = part
            local weld = Instance.new("Weld")
            weld.Part0 = Root
            weld.C0 = CFrame.new(CarpetOffset)
            weld.Part1 = part
            local xOff = ((i == 1 or i == n) and -0.005) or 0
            local zOff = (-((CarpetSize.Z / 2) - (part.Size.Z / 2))) + (part.Size.Z * (i - 1))
                + ((i == 2 and 0.245) or (i == 3 and 0.04) or (i == n and 0.28) or 0)
            weld.C1 = CFrame.new(0, xOff, zOff)
            weld.Parent = part
            part.Parent = Tool
        end
    end
    local function PlaySit()
        if not Humanoid then return end
        local anim = (Humanoid.RigType == Enum.HumanoidRigType.R15) and SitR15 or SitR6
        pcall(function()
            local animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid
            if AnimTrack then AnimTrack:Stop() end
            AnimTrack = animator:LoadAnimation(anim)
            AnimTrack:Play()
        end)
    end
    local function StopSit()
        if AnimTrack then pcall(function() AnimTrack:Stop() end); AnimTrack = nil end
    end
    local function CreateRainbow(lastPlace, currentPlace)
        local distance = (lastPlace - currentPlace).Magnitude
        if distance < 0.1 then return end
        local length = distance + 3.5
        local mid = CFrame.new(lastPlace + (currentPlace - lastPlace).Unit * (distance / 2), currentPlace)
        local model = Instance.new("Model")
        for i, color in ipairs(RainbowColors) do
            local p = Instance.new("Part")
            p.Anchored = true; p.CanCollide = false; p.Material = Enum.Material.SmoothPlastic
            p.Reflectance = 0.25; p.Transparency = 0.1
            p.Size = Vector3.new(0.5, 0.5, length)
            p.CFrame = mid * CFrame.new((i - 4) * 0.5, 0, 0)
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. "9856898"; mesh.TextureId = BaseUrl .. "1361097"
            mesh.Scale = p.Size * 2
            mesh.VertexColor = Vector3.new(color.R, color.G, color.B)
            mesh.Parent = p
            local light = Instance.new("PointLight")
            light.Brightness = 8; light.Range = 5; light.Color = color; light.Parent = p
            p.Parent = model
        end
        model.Parent = TrailFolder
        Debris:AddItem(model, 1)
    end
    local ControlsModule
    pcall(function()
        ControlsModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
    end)
    local function GetMoveVector()
        if ControlsModule then
            local ok, v = pcall(function() return ControlsModule:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then return v end
        end
        local md = Humanoid and Humanoid.MoveDirection or Vector3.zero
        local cf = Workspace.CurrentCamera.CFrame
        return Vector3.new(md:Dot(cf.RightVector), 0, -md:Dot(cf.LookVector))
    end
    local function StopFlying()
        Flying = false
        if FlightConn then FlightConn:Disconnect(); FlightConn = nil end
        for _, v in ipairs({ FlightSpin, FlightPower, FlightHold }) do
            if v and v.Parent then pcall(function() v:Destroy() end) end
        end
        FlightSpin, FlightPower, FlightHold = nil, nil, nil
        -- nuke any leftover movers that can freeze movement
        if Root then
            for _, ch in ipairs(Root:GetChildren()) do
                local n = ch.Name
                if n == "FlightSpin" or n == "FlightPower" or n == "FlightHold"
                    or ch:IsA("BodyVelocity") or ch:IsA("BodyPosition") or ch:IsA("BodyGyro") then
                    if n:find("Flight") or n == "FlightSpin" or n == "FlightPower" or n == "FlightHold" then
                        pcall(function() ch:Destroy() end)
                    end
                end
            end
        end
        if CheckIfAlive() then
            pcall(function()
                Root.AssemblyLinearVelocity = Vector3.zero
                Root.AssemblyAngularVelocity = Vector3.zero
            end)
            Humanoid.PlatformStand = false
            Humanoid.AutoRotate = true
            Humanoid.Sit = false
            if not speedEnabled then
                Humanoid.WalkSpeed = BASE_SPEED
            elseif Humanoid.WalkSpeed < 1 then
                Humanoid.WalkSpeed = BASE_SPEED
            end
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.defer(function()
                if Humanoid and Humanoid.Parent then
                    Humanoid.PlatformStand = false
                    if Humanoid.WalkSpeed < 1 then Humanoid.WalkSpeed = BASE_SPEED end
                end
            end)
        end
        StopSit(); Tool.Grip = Grips.Normal; CleanUpCarpet(); Roll.Transparency = 0
    end
    local function StartFlying()
        Flying = true; Roll.Transparency = 1; CleanUpCarpet(); BuildCarpet(); PlaySit()
        Tool.Grip = Grips.Flying
        FlightSpin = Instance.new("BodyGyro")
        FlightSpin.P = 1e6; FlightSpin.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        FlightSpin.CFrame = Root.CFrame; FlightSpin.Parent = Root
        FlightPower = Instance.new("BodyVelocity")
        FlightPower.Velocity = Vector3.zero; FlightPower.P = 10000
        FlightPower.MaxForce = Vector3.zero; FlightPower.Parent = Root
        FlightHold = Instance.new("BodyPosition")
        FlightHold.P = 1e5; FlightHold.MaxForce = Vector3.zero
        FlightHold.Position = Root.Position; FlightHold.Parent = Root
        Humanoid.WalkSpeed = 0; Humanoid.PlatformStand = false; Humanoid.AutoRotate = false
        Root.AssemblyLinearVelocity = Vector3.zero
        FlightConn = RunService.Heartbeat:Connect(function()
            if not (Flying and ToolEquipped and CheckIfAlive()) then StopFlying(); return end
            Humanoid.Jump = false
            local look = Workspace.CurrentCamera.CFrame.LookVector
            local right = Workspace.CurrentCamera.CFrame.RightVector
            local mv = GetMoveVector()
            local push = (look * (-mv.Z) * CameraSpeed.Z) + (right * mv.X * CameraSpeed.X)
            FlightSpin.CFrame = CFrame.new(Vector3.zero, look)
            if push.Magnitude < 1 then
                FlightHold.MaxForce = Vector3.new(FlightHold.P, FlightHold.P, FlightHold.P)
                FlightPower.MaxForce = Vector3.zero
                FlightHold.Position = Root.Position
            else
                FlightHold.MaxForce = Vector3.zero
                FlightPower.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            end
            FlightPower.Velocity = push
        end)
        task.spawn(function()
            local lastPlace
            while Flying and ToolEquipped and CheckIfAlive() do
                local current = (Root.CFrame * CFrame.new(CarpetOffset)).Position
                local vel = Root.AssemblyLinearVelocity
                local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                if lastPlace and speed > 10 then
                    CreateRainbow(lastPlace, current); lastPlace = current
                elseif not lastPlace then
                    lastPlace = current
                end
                task.wait(Rate)
            end
        end)
    end
    Tool.Equipped:Connect(function()
        Character = Tool.Parent
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        Root = Character:FindFirstChild("HumanoidRootPart")
        ToolEquipped = true; Tool.Grip = Grips.Normal
    end)
    Tool.Unequipped:Connect(function()
        ToolEquipped = false
        if Flying then StopFlying() end
        Roll.Transparency = 0
    end)
    Tool.Activated:Connect(function()
        if Cooldown or not CheckIfAlive() then return end
        Cooldown = true
        if Flying then StopFlying() else StartFlying() end
        task.delay(2, function() Cooldown = false end)
    end)
    return Tool
end

local function createBloodCarpet()
    local BaseUrl = "http://www.roblox.com/asset/?id="
    local CarpetIconId = "rbxassetid://72140049013374"
    local CarpetTextureId = "rbxassetid://137578723613004"

    local CarpetPieces = {
        { MeshId = 223079795 }, { MeshId = 223079835 },
        { MeshId = 223079888 }, { MeshId = 223079981 },
    }
    local CarpetSize = Vector3.new(3, 0.5, 6.5)
    local CarpetOffset = Vector3.new(0, -1.6, 0.5)
    local CameraSpeed = { X = 70, Z = 105 }
    local Rate = 1 / 10
    local StripeWidth = 0.32

    local BloodColors = {
        Color3.fromRGB(45, 0, 0),
        Color3.fromRGB(80, 0, 4),
        Color3.fromRGB(120, 0, 8),
        Color3.fromRGB(165, 5, 12),
        Color3.fromRGB(215, 15, 18),
        Color3.fromRGB(255, 35, 35),
        Color3.fromRGB(215, 15, 18),
        Color3.fromRGB(165, 5, 12),
        Color3.fromRGB(120, 0, 8),
        Color3.fromRGB(80, 0, 4),
        Color3.fromRGB(45, 0, 0),
    }

    local CarpetTint = Vector3.new(1, 1, 1)

    local Grips = {
        Normal = CFrame.new(-1.5, 0, 0, 0, 0, -1, -1, 8.90154915e-005, 0, 8.90154915e-005, 1, 0),
        Flying = CFrame.new(-1.5, 0.5, -0.75, -1, 0, -8.99756625e-009, -8.99756625e-009, 8.10000031e-008, 1, 7.28802977e-016, 0.99999994, -8.10000103e-008),
    }

    local bag = getBackpack and getBackpack() or bp
    local char0 = player.Character
    local old = (bag and bag:FindFirstChild("Blood Carpet"))
        or (char0 and char0:FindFirstChild("Blood Carpet"))
    if old then old:Destroy() end

    local Tool = Instance.new("Tool")
    Tool.Name = "Blood Carpet"
    Tool.RequiresHandle = true
    Tool.CanBeDropped = false
    Tool.Grip = Grips.Normal
    Tool.TextureId = CarpetIconId

    local Handle = Instance.new("Part")
    Handle.Name = "Handle"
    Handle.Size = CarpetSize
    Handle.Transparency = 1
    Handle.CanCollide = false
    Handle.Massless = true
    Handle.Parent = Tool

    local Roll = Instance.new("Part")
    Roll.Name = "Roll"
    Roll.Size = CarpetSize
    Roll.CanCollide = false
    Roll.Massless = true

    local RollMesh = Instance.new("SpecialMesh")
    RollMesh.MeshType = Enum.MeshType.FileMesh
    RollMesh.MeshId = BaseUrl .. "223079737"
    RollMesh.Scale = Vector3.new(1.125, 1.125, 1.125)
    RollMesh.TextureId = CarpetTextureId
    RollMesh.VertexColor = CarpetTint
    RollMesh.Parent = Roll

    local RollWeld = Instance.new("Weld")
    RollWeld.Part0 = Handle
    RollWeld.Part1 = Roll
    RollWeld.Parent = Roll
    Roll.Parent = Tool

    local SitR6 = Instance.new("Animation")
    SitR6.AnimationId = "http://www.roblox.com/asset/?id=225279725"
    SitR6.Parent = Tool

    local SitR15 = Instance.new("Animation")
    SitR15.AnimationId = "rbxassetid://855828754"
    SitR15.Parent = Tool

    local Flying, ToolEquipped, Cooldown = false, false, false
    local Character, Humanoid, Root
    local FlightSpin, FlightPower, FlightHold, AnimTrack, FlightConn

    local TrailFolder = Workspace:FindFirstChild("CarpetBlood") or Instance.new("Folder")
    TrailFolder.Name = "CarpetBlood"
    TrailFolder.Parent = Workspace

    local function CheckIfAlive()
        return Character and Character.Parent
            and Humanoid and Humanoid.Parent and Humanoid.Health > 0
            and Root and Root.Parent
    end

    local function CleanUpCarpet()
        for _, v in ipairs(Tool:GetChildren()) do
            if v:IsA("BasePart") and v ~= Handle and v.Name ~= "Roll" then
                v:Destroy()
            end
        end
    end

    local function BuildCarpet()
        local n = #CarpetPieces
        for i, v in ipairs(CarpetPieces) do
            local part = Instance.new("Part")
            part.Size = Vector3.new(CarpetSize.X, CarpetSize.Y, CarpetSize.Z / n)
            part.CanCollide = false
            part.Massless = true

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. v.MeshId
            mesh.TextureId = CarpetTextureId
            mesh.Scale = Vector3.new(1.125, 1.125, 1.125)
            mesh.VertexColor = CarpetTint
            mesh.Parent = part

            local weld = Instance.new("Weld")
            weld.Part0 = Root
            weld.C0 = CFrame.new(CarpetOffset)
            weld.Part1 = part

            local xOff = ((i == 1 or i == n) and -0.005) or 0
            local zOff = (-((CarpetSize.Z / 2) - (part.Size.Z / 2))) + (part.Size.Z * (i - 1))
                + ((i == 2 and 0.245) or (i == 3 and 0.04) or (i == n and 0.28) or 0)
            weld.C1 = CFrame.new(0, xOff, zOff)
            weld.Parent = part
            part.Parent = Tool
        end
    end

    local function PlaySit()
        if not Humanoid then return end
        local anim = (Humanoid.RigType == Enum.HumanoidRigType.R15) and SitR15 or SitR6
        pcall(function()
            local animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid
            if AnimTrack then AnimTrack:Stop() end
            AnimTrack = animator:LoadAnimation(anim)
            AnimTrack:Play()
        end)
    end

    local function StopSit()
        if AnimTrack then
            pcall(function() AnimTrack:Stop() end)
            AnimTrack = nil
        end
    end

    local function CreateBloodTrail(lastPlace, currentPlace)
        local distance = (lastPlace - currentPlace).Magnitude
        if distance < 0.1 then return end

        local length = distance + 3.5
        local mid = CFrame.new(lastPlace + (currentPlace - lastPlace).Unit * (distance / 2), currentPlace)
        local model = Instance.new("Model")
        local centerIndex = (#BloodColors + 1) / 2

        for i, color in ipairs(BloodColors) do
            local p = Instance.new("Part")
            p.Anchored = true
            p.CanCollide = false
            p.Material = Enum.Material.SmoothPlastic
            p.Reflectance = 0.25
            p.Transparency = 0.1
            p.Size = Vector3.new(StripeWidth, 0.5, length)
            p.CFrame = mid * CFrame.new((i - centerIndex) * StripeWidth, 0, 0)

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. "9856898"
            mesh.TextureId = BaseUrl .. "1361097"
            mesh.Scale = Vector3.new(StripeWidth * 2, 1, length * 2)
            mesh.VertexColor = Vector3.new(color.R, color.G, color.B)
            mesh.Parent = p

            local light = Instance.new("PointLight")
            light.Brightness = 4
            light.Range = 5
            light.Color = Color3.fromRGB(180, 0, 10)
            light.Parent = p

            p.Parent = model
        end

        model.Parent = TrailFolder
        Debris:AddItem(model, 1)
    end

    local ControlsModule
    pcall(function()
        ControlsModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
    end)

    local function GetMoveVector()
        if ControlsModule then
            local ok, v = pcall(function() return ControlsModule:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then return v end
        end
        local md = Humanoid and Humanoid.MoveDirection or Vector3.zero
        local cf = Workspace.CurrentCamera.CFrame
        return Vector3.new(md:Dot(cf.RightVector), 0, -md:Dot(cf.LookVector))
    end

    local function StopFlying()
        Flying = false
        if FlightConn then
            FlightConn:Disconnect()
            FlightConn = nil
        end
        for _, v in ipairs({ FlightSpin, FlightPower, FlightHold }) do
            if v and v.Parent then
                pcall(function() v:Destroy() end)
            end
        end
        FlightSpin, FlightPower, FlightHold = nil, nil, nil

        if Root then
            for _, ch in ipairs(Root:GetChildren()) do
                local n = ch.Name
                if (n == "FlightSpin" or n == "FlightPower" or n == "FlightHold") then
                    pcall(function() ch:Destroy() end)
                end
            end
        end

        if CheckIfAlive() then
            pcall(function()
                Root.AssemblyLinearVelocity = Vector3.zero
                Root.AssemblyAngularVelocity = Vector3.zero
            end)
            Humanoid.PlatformStand = false
            Humanoid.AutoRotate = true
            Humanoid.Sit = false
            if not speedEnabled then
                Humanoid.WalkSpeed = BASE_SPEED
            elseif Humanoid.WalkSpeed < 1 then
                Humanoid.WalkSpeed = BASE_SPEED
            end
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.defer(function()
                if Humanoid and Humanoid.Parent then
                    Humanoid.PlatformStand = false
                    if Humanoid.WalkSpeed < 1 then Humanoid.WalkSpeed = BASE_SPEED end
                end
            end)
        end

        StopSit()
        Tool.Grip = Grips.Normal
        CleanUpCarpet()
        Roll.Transparency = 0
    end

    local function StartFlying()
        Flying = true
        Roll.Transparency = 1
        CleanUpCarpet()
        BuildCarpet()
        PlaySit()
        Tool.Grip = Grips.Flying

        FlightSpin = Instance.new("BodyGyro")
        FlightSpin.Name = "FlightSpin"
        FlightSpin.P = 1e6
        FlightSpin.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        FlightSpin.CFrame = Root.CFrame
        FlightSpin.Parent = Root

        FlightPower = Instance.new("BodyVelocity")
        FlightPower.Name = "FlightPower"
        FlightPower.Velocity = Vector3.zero
        FlightPower.P = 10000
        FlightPower.MaxForce = Vector3.zero
        FlightPower.Parent = Root

        FlightHold = Instance.new("BodyPosition")
        FlightHold.Name = "FlightHold"
        FlightHold.P = 1e5
        FlightHold.MaxForce = Vector3.zero
        FlightHold.Position = Root.Position
        FlightHold.Parent = Root

        Humanoid.WalkSpeed = 0
        Humanoid.PlatformStand = false -- keep shiftlock mouse free
        Humanoid.AutoRotate = false
        Root.AssemblyLinearVelocity = Vector3.zero

        FlightConn = RunService.Heartbeat:Connect(function()
            if not (Flying and ToolEquipped and CheckIfAlive()) then
                StopFlying()
                return
            end
            Humanoid.Jump = false
            local look = Workspace.CurrentCamera.CFrame.LookVector
            local right = Workspace.CurrentCamera.CFrame.RightVector
            local mv = GetMoveVector()
            local push = (look * (-mv.Z) * CameraSpeed.Z) + (right * mv.X * CameraSpeed.X)
            FlightSpin.CFrame = CFrame.new(Vector3.zero, look)
            if push.Magnitude < 1 then
                FlightHold.MaxForce = Vector3.new(FlightHold.P, FlightHold.P, FlightHold.P)
                FlightPower.MaxForce = Vector3.zero
                FlightHold.Position = Root.Position
            else
                FlightHold.MaxForce = Vector3.zero
                FlightPower.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            end
            FlightPower.Velocity = push
        end)

        task.spawn(function()
            local lastPlace
            while Flying and ToolEquipped and CheckIfAlive() do
                local current = (Root.CFrame * CFrame.new(CarpetOffset)).Position
                local vel = Root.AssemblyLinearVelocity
                local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                if lastPlace and speed > 10 then
                    CreateBloodTrail(lastPlace, current)
                    lastPlace = current
                elseif not lastPlace then
                    lastPlace = current
                end
                task.wait(Rate)
            end
        end)
    end

    Tool.Equipped:Connect(function()
        Character = Tool.Parent
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        Root = Character:FindFirstChild("HumanoidRootPart")
        ToolEquipped = true
        Tool.Grip = Grips.Normal
    end)

    Tool.Unequipped:Connect(function()
        ToolEquipped = false
        if Flying then StopFlying() end
        Roll.Transparency = 0
    end)

    Tool.Activated:Connect(function()
        if Cooldown or not CheckIfAlive() then return end
        Cooldown = true
        if Flying then StopFlying() else StartFlying() end
        task.delay(2, function() Cooldown = false end)
    end)

    return Tool
end

local function createCinnaCarpet()
    local BaseUrl = "http://www.roblox.com/asset/?id="
    local CarpetIconId = "rbxassetid://104670537921161"
    local CarpetTextureId = "rbxassetid://96331741023084"

    local CarpetPieces = {
        { MeshId = 223079795 }, { MeshId = 223079835 },
        { MeshId = 223079888 }, { MeshId = 223079981 },
    }
    local CarpetSize = Vector3.new(3, 0.5, 6.5)
    local CarpetOffset = Vector3.new(0, -1.6, 0.5)
    local CameraSpeed = { X = 70, Z = 105 }
    local Rate = 1 / 10
    local StripeWidth = 0.32

    local CinnamorollColors = {
        Color3.fromRGB(135, 175, 225),
        Color3.fromRGB(155, 195, 238),
        Color3.fromRGB(180, 218, 248),
        Color3.fromRGB(205, 234, 255),
        Color3.fromRGB(232, 246, 255),
        Color3.fromRGB(255, 252, 250),
        Color3.fromRGB(232, 246, 255),
        Color3.fromRGB(205, 234, 255),
        Color3.fromRGB(180, 218, 248),
        Color3.fromRGB(155, 195, 238),
        Color3.fromRGB(135, 175, 225),
    }

    local CarpetTint = Vector3.new(1, 1, 1)
    local Grips = {
        Normal = CFrame.new(-1.5, 0, 0, 0, 0, -1, -1, 8.90154915e-005, 0, 8.90154915e-005, 1, 0),
        Flying = CFrame.new(-1.5, 0.5, -0.75, -1, 0, -8.99756625e-009, -8.99756625e-009, 8.10000031e-008, 1, 7.28802977e-016, 0.99999994, -8.10000103e-008),
    }

    local bag = getBackpack and getBackpack() or bp
    local char0 = player.Character
    local old = (bag and bag:FindFirstChild("Cinnamoroll Carpet"))
        or (char0 and char0:FindFirstChild("Cinnamoroll Carpet"))
    if old then old:Destroy() end

    local Tool = Instance.new("Tool")
    Tool.Name = "Cinnamoroll Carpet"
    Tool.RequiresHandle = true
    Tool.CanBeDropped = false
    Tool.Grip = Grips.Normal
    Tool.TextureId = CarpetIconId

    local Handle = Instance.new("Part")
    Handle.Name = "Handle"
    Handle.Size = CarpetSize
    Handle.Transparency = 1
    Handle.CanCollide = false
    Handle.Massless = true
    Handle.Parent = Tool

    local Roll = Instance.new("Part")
    Roll.Name = "Roll"
    Roll.Size = CarpetSize
    Roll.CanCollide = false
    Roll.Massless = true

    local RollMesh = Instance.new("SpecialMesh")
    RollMesh.MeshType = Enum.MeshType.FileMesh
    RollMesh.MeshId = BaseUrl .. "223079737"
    RollMesh.Scale = Vector3.new(1.125, 1.125, 1.125)
    RollMesh.TextureId = CarpetTextureId
    RollMesh.VertexColor = CarpetTint
    RollMesh.Parent = Roll

    local RollWeld = Instance.new("Weld")
    RollWeld.Part0 = Handle
    RollWeld.Part1 = Roll
    RollWeld.Parent = Roll
    Roll.Parent = Tool

    local SitR6 = Instance.new("Animation")
    SitR6.AnimationId = "http://www.roblox.com/asset/?id=225279725"
    SitR6.Parent = Tool
    local SitR15 = Instance.new("Animation")
    SitR15.AnimationId = "rbxassetid://855828754"
    SitR15.Parent = Tool

    local Flying, ToolEquipped, Cooldown = false, false, false
    local Character, Humanoid, Root
    local FlightSpin, FlightPower, FlightHold, AnimTrack, FlightConn

    local TrailFolder = Workspace:FindFirstChild("CarpetCinna") or Instance.new("Folder")
    TrailFolder.Name = "CarpetCinna"
    TrailFolder.Parent = Workspace

    local function CheckIfAlive()
        return Character and Character.Parent
            and Humanoid and Humanoid.Parent and Humanoid.Health > 0
            and Root and Root.Parent
    end

    local function CleanUpCarpet()
        for _, v in ipairs(Tool:GetChildren()) do
            if v:IsA("BasePart") and v ~= Handle and v.Name ~= "Roll" then
                v:Destroy()
            end
        end
    end

    local function BuildCarpet()
        local n = #CarpetPieces
        for i, v in ipairs(CarpetPieces) do
            local part = Instance.new("Part")
            part.Size = Vector3.new(CarpetSize.X, CarpetSize.Y, CarpetSize.Z / n)
            part.CanCollide = false
            part.Massless = true
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. v.MeshId
            mesh.TextureId = CarpetTextureId
            mesh.Scale = Vector3.new(1.125, 1.125, 1.125)
            mesh.VertexColor = CarpetTint
            mesh.Parent = part
            local weld = Instance.new("Weld")
            weld.Part0 = Root
            weld.C0 = CFrame.new(CarpetOffset)
            weld.Part1 = part
            local xOff = ((i == 1 or i == n) and -0.005) or 0
            local zOff = (-((CarpetSize.Z / 2) - (part.Size.Z / 2))) + (part.Size.Z * (i - 1))
                + ((i == 2 and 0.245) or (i == 3 and 0.04) or (i == n and 0.28) or 0)
            weld.C1 = CFrame.new(0, xOff, zOff)
            weld.Parent = part
            part.Parent = Tool
        end
    end

    local function PlaySit()
        if not Humanoid then return end
        local anim = (Humanoid.RigType == Enum.HumanoidRigType.R15) and SitR15 or SitR6
        pcall(function()
            local animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid
            if AnimTrack then AnimTrack:Stop() end
            AnimTrack = animator:LoadAnimation(anim)
            AnimTrack:Play()
        end)
    end

    local function StopSit()
        if AnimTrack then pcall(function() AnimTrack:Stop() end); AnimTrack = nil end
    end

    local function CreateCinnamorollTrail(lastPlace, currentPlace)
        local distance = (lastPlace - currentPlace).Magnitude
        if distance < 0.1 then return end
        local length = distance + 3.5
        local mid = CFrame.new(lastPlace + (currentPlace - lastPlace).Unit * (distance / 2), currentPlace)
        local model = Instance.new("Model")
        local centerIndex = (#CinnamorollColors + 1) / 2
        for i, color in ipairs(CinnamorollColors) do
            local p = Instance.new("Part")
            p.Anchored = true
            p.CanCollide = false
            p.Material = Enum.Material.SmoothPlastic
            p.Reflectance = 0.2
            p.Transparency = 0.1
            p.Size = Vector3.new(StripeWidth, 0.5, length)
            p.CFrame = mid * CFrame.new((i - centerIndex) * StripeWidth, 0, 0)
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. "9856898"
            mesh.TextureId = BaseUrl .. "1361097"
            mesh.Scale = Vector3.new(StripeWidth * 2, 1, length * 2)
            mesh.VertexColor = Vector3.new(color.R, color.G, color.B)
            mesh.Parent = p
            local light = Instance.new("PointLight")
            light.Brightness = 4
            light.Range = 5
            light.Color = Color3.fromRGB(185, 222, 255)
            light.Parent = p
            p.Parent = model
        end
        model.Parent = TrailFolder
        Debris:AddItem(model, 1)
    end

    local ControlsModule
    pcall(function()
        ControlsModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
    end)

    local function GetMoveVector()
        if ControlsModule then
            local ok, v = pcall(function() return ControlsModule:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then return v end
        end
        local md = Humanoid and Humanoid.MoveDirection or Vector3.zero
        local cf = Workspace.CurrentCamera.CFrame
        return Vector3.new(md:Dot(cf.RightVector), 0, -md:Dot(cf.LookVector))
    end

    local function StopFlying()
        Flying = false
        if FlightConn then FlightConn:Disconnect(); FlightConn = nil end
        for _, v in ipairs({ FlightSpin, FlightPower, FlightHold }) do
            if v and v.Parent then pcall(function() v:Destroy() end) end
        end
        FlightSpin, FlightPower, FlightHold = nil, nil, nil
        if Root then
            for _, ch in ipairs(Root:GetChildren()) do
                if ch.Name == "FlightSpin" or ch.Name == "FlightPower" or ch.Name == "FlightHold" then
                    pcall(function() ch:Destroy() end)
                end
            end
        end
        if CheckIfAlive() then
            pcall(function()
                Root.AssemblyLinearVelocity = Vector3.zero
                Root.AssemblyAngularVelocity = Vector3.zero
            end)
            Humanoid.PlatformStand = false
            Humanoid.AutoRotate = true
            Humanoid.Sit = false
            if not speedEnabled or Humanoid.WalkSpeed < 1 then
                Humanoid.WalkSpeed = BASE_SPEED
            end
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
        StopSit()
        Tool.Grip = Grips.Normal
        CleanUpCarpet()
        Roll.Transparency = 0
    end

    local function StartFlying()
        Flying = true
        Roll.Transparency = 1
        CleanUpCarpet()
        BuildCarpet()
        PlaySit()
        Tool.Grip = Grips.Flying
        FlightSpin = Instance.new("BodyGyro")
        FlightSpin.Name = "FlightSpin"
        FlightSpin.P = 1e6
        FlightSpin.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        FlightSpin.CFrame = Root.CFrame
        FlightSpin.Parent = Root
        FlightPower = Instance.new("BodyVelocity")
        FlightPower.Name = "FlightPower"
        FlightPower.Velocity = Vector3.zero
        FlightPower.P = 10000
        FlightPower.MaxForce = Vector3.zero
        FlightPower.Parent = Root
        FlightHold = Instance.new("BodyPosition")
        FlightHold.Name = "FlightHold"
        FlightHold.P = 1e5
        FlightHold.MaxForce = Vector3.zero
        FlightHold.Position = Root.Position
        FlightHold.Parent = Root
        Humanoid.WalkSpeed = 0
        Humanoid.PlatformStand = false -- keep shiftlock mouse free
        Humanoid.AutoRotate = false
        Root.AssemblyLinearVelocity = Vector3.zero
        FlightConn = RunService.Heartbeat:Connect(function()
            if not (Flying and ToolEquipped and CheckIfAlive()) then StopFlying(); return end
            Humanoid.Jump = false
            local look = Workspace.CurrentCamera.CFrame.LookVector
            local right = Workspace.CurrentCamera.CFrame.RightVector
            local mv = GetMoveVector()
            local push = (look * (-mv.Z) * CameraSpeed.Z) + (right * mv.X * CameraSpeed.X)
            FlightSpin.CFrame = CFrame.new(Vector3.zero, look)
            if push.Magnitude < 1 then
                FlightHold.MaxForce = Vector3.new(FlightHold.P, FlightHold.P, FlightHold.P)
                FlightPower.MaxForce = Vector3.zero
                FlightHold.Position = Root.Position
            else
                FlightHold.MaxForce = Vector3.zero
                FlightPower.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            end
            FlightPower.Velocity = push
        end)
        task.spawn(function()
            local lastPlace
            while Flying and ToolEquipped and CheckIfAlive() do
                local current = (Root.CFrame * CFrame.new(CarpetOffset)).Position
                local vel = Root.AssemblyLinearVelocity
                local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                if lastPlace and speed > 10 then
                    CreateCinnamorollTrail(lastPlace, current)
                    lastPlace = current
                elseif not lastPlace then
                    lastPlace = current
                end
                task.wait(Rate)
            end
        end)
    end

    Tool.Equipped:Connect(function()
        Character = Tool.Parent
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        Root = Character:FindFirstChild("HumanoidRootPart")
        ToolEquipped = true
        Tool.Grip = Grips.Normal
    end)
    Tool.Unequipped:Connect(function()
        ToolEquipped = false
        if Flying then StopFlying() end
        Roll.Transparency = 0
    end)
    Tool.Activated:Connect(function()
        if Cooldown or not CheckIfAlive() then return end
        Cooldown = true
        if Flying then StopFlying() else StartFlying() end
        task.delay(2, function() Cooldown = false end)
    end)

    return Tool
end

local function createGoldCarpet()
    local BaseUrl = "http://www.roblox.com/asset/?id="
    local CarpetPieces = {
        { MeshId = 223079795 }, { MeshId = 223079835 },
        { MeshId = 223079888 }, { MeshId = 223079981 },
    }
    local CarpetSize = Vector3.new(3, 0.5, 6.5)
    local CameraSpeed = { X = 70, Z = 105 }
    local Rate = 1 / 10
    local RainbowColors = {
        Color3.new(1, 0, 0), Color3.new(1, 0.5, 0), Color3.new(1, 1, 0), Color3.new(0, 1, 0),
        Color3.new(0, 1, 1), Color3.new(0, 0, 1), Color3.new(0.5, 0, 1),
    }
    local Grips = {
        Normal = CFrame.new(-1.5, 0, 0, 0, 0, -1, -1, 8.90154915e-005, 0, 8.90154915e-005, 1, 0),
        Flying = CFrame.new(-1.5, 0.5, -0.75, -1, 0, -8.99756625e-009, -8.99756625e-009, 8.10000031e-008, 1, 7.28802977e-016, 0.99999994, -8.10000103e-008),
    }
    local old = bp:FindFirstChild("Flying Carpet") or (player.Character and player.Character:FindFirstChild("Flying Carpet"))
    if old then old:Destroy() end

    local Tool = Instance.new("Tool")
    Tool.Name = "Flying Carpet"
    Tool.RequiresHandle = true
    Tool.CanBeDropped = false
    Tool.Grip = Grips.Normal
    Tool.TextureId = "rbxassetid://1014109561"

    local Handle = Instance.new("Part")
    Handle.Name = "Handle"; Handle.Size = CarpetSize
    Handle.Transparency = 1; Handle.CanCollide = false; Handle.Massless = true
    Handle.Parent = Tool

    local Roll = Instance.new("Part")
    Roll.Name = "Roll"; Roll.Size = CarpetSize
    Roll.CanCollide = false; Roll.Massless = true
    local RollMesh = Instance.new("SpecialMesh")
    RollMesh.MeshType = Enum.MeshType.FileMesh
    RollMesh.MeshId = BaseUrl .. "223079737"
    RollMesh.Scale = Vector3.new(1.125, 1.125, 1.125)
    RollMesh.TextureId = BaseUrl .. "1014108463"
    RollMesh.Parent = Roll
    local RollWeld = Instance.new("Weld")
    RollWeld.Part0 = Handle; RollWeld.Part1 = Roll; RollWeld.Parent = Roll
    Roll.Parent = Tool

    local SitR6 = Instance.new("Animation"); SitR6.AnimationId = "http://www.roblox.com/asset/?id=225279725"; SitR6.Parent = Tool
    local SitR15 = Instance.new("Animation"); SitR15.AnimationId = "rbxassetid://855828754"; SitR15.Parent = Tool

    local Flying, ToolEquipped, Cooldown = false, false, false
    local Character, Humanoid, Root
    local FlightSpin, FlightPower, FlightHold, AnimTrack, FlightConn
    local TrailFolder = Workspace:FindFirstChild("CarpetRainbow") or Instance.new("Folder")
    TrailFolder.Name = "CarpetRainbow"; TrailFolder.Parent = Workspace

    local function CheckIfAlive()
        return Character and Character.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0
            and Root and Root.Parent
    end
    local function CleanUpCarpet()
        for _, v in ipairs(Tool:GetChildren()) do
            if v:IsA("BasePart") and v ~= Handle and v.Name ~= "Roll" then v:Destroy() end
        end
    end
    local function BuildCarpet()
        local n = #CarpetPieces
        for i, v in ipairs(CarpetPieces) do
            local part = Instance.new("Part")
            part.Size = Vector3.new(CarpetSize.X, CarpetSize.Y, CarpetSize.Z / n)
            part.CanCollide = false; part.Massless = true
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. v.MeshId
            mesh.TextureId = BaseUrl .. "1014108463"
            mesh.Scale = Vector3.new(1.125, 1.125, 1.125)
            mesh.Parent = part
            local weld = Instance.new("Weld")
            weld.Part0 = Handle; weld.Part1 = part
            local xOff = ((i == 1 or i == n) and -0.005) or 0
            local zOff = (-((Handle.Size.Z / 2) - (part.Size.Z / 2))) + (part.Size.Z * (i - 1))
                + ((i == 2 and 0.245) or (i == 3 and 0.04) or (i == n and 0.28) or 0)
            weld.C1 = CFrame.new(0, xOff, zOff)
            weld.Parent = part
            part.Parent = Tool
        end
    end
    local function PlaySit()
        if not Humanoid then return end
        local anim = (Humanoid.RigType == Enum.HumanoidRigType.R15) and SitR15 or SitR6
        pcall(function()
            local animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid
            if AnimTrack then AnimTrack:Stop() end
            AnimTrack = animator:LoadAnimation(anim)
            AnimTrack:Play()
        end)
    end
    local function StopSit()
        if AnimTrack then pcall(function() AnimTrack:Stop() end); AnimTrack = nil end
    end
    local function CreateRainbow(lastPlace, currentPlace)
        local distance = (lastPlace - currentPlace).Magnitude
        if distance < 0.1 then return end
        local length = distance + 3.5
        local mid = CFrame.new(lastPlace + (currentPlace - lastPlace).Unit * (distance / 2), currentPlace)
        local model = Instance.new("Model")
        for i, color in ipairs(RainbowColors) do
            local p = Instance.new("Part")
            p.Anchored = true; p.CanCollide = false; p.Material = Enum.Material.SmoothPlastic
            p.BrickColor = BrickColor.new("Gold")
            p.Reflectance = 0.25; p.Transparency = 0.1
            p.Size = Vector3.new(0.5, 0.5, length)
            p.CFrame = mid * CFrame.new((i - 4) * 0.5, 0, 0)
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = BaseUrl .. "9856898"; mesh.TextureId = BaseUrl .. "1361097"
            mesh.Scale = p.Size * 2
            mesh.VertexColor = Vector3.new(239/255, 184/255, 56/255)
            mesh.Parent = p
            local light = Instance.new("PointLight")
            light.Brightness = 8; light.Range = 5; light.Color = color; light.Parent = p
            p.Parent = model
        end
        model.Parent = TrailFolder
        Debris:AddItem(model, 1)
    end
    local ControlsModule
    pcall(function()
        ControlsModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
    end)
    local function GetMoveVector()
        if ControlsModule then
            local ok, v = pcall(function() return ControlsModule:GetMoveVector() end)
            if ok and typeof(v) == "Vector3" then return v end
        end
        local md = Humanoid and Humanoid.MoveDirection or Vector3.zero
        local cf = Workspace.CurrentCamera.CFrame
        return Vector3.new(md:Dot(cf.RightVector), 0, -md:Dot(cf.LookVector))
    end
    local function StopFlying()
        Flying = false
        if FlightConn then FlightConn:Disconnect(); FlightConn = nil end
        for _, v in ipairs({ FlightSpin, FlightPower, FlightHold }) do
            if v and v.Parent then pcall(function() v:Destroy() end) end
        end
        FlightSpin, FlightPower, FlightHold = nil, nil, nil
        -- nuke any leftover movers that can freeze movement
        if Root then
            for _, ch in ipairs(Root:GetChildren()) do
                local n = ch.Name
                if n == "FlightSpin" or n == "FlightPower" or n == "FlightHold"
                    or ch:IsA("BodyVelocity") or ch:IsA("BodyPosition") or ch:IsA("BodyGyro") then
                    if n:find("Flight") or n == "FlightSpin" or n == "FlightPower" or n == "FlightHold" then
                        pcall(function() ch:Destroy() end)
                    end
                end
            end
        end
        if CheckIfAlive() then
            pcall(function()
                Root.AssemblyLinearVelocity = Vector3.zero
                Root.AssemblyAngularVelocity = Vector3.zero
            end)
            Humanoid.PlatformStand = false
            Humanoid.AutoRotate = true
            Humanoid.Sit = false
            if not speedEnabled then
                Humanoid.WalkSpeed = BASE_SPEED
            elseif Humanoid.WalkSpeed < 1 then
                Humanoid.WalkSpeed = BASE_SPEED
            end
            pcall(function() Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.defer(function()
                if Humanoid and Humanoid.Parent then
                    Humanoid.PlatformStand = false
                    if Humanoid.WalkSpeed < 1 then Humanoid.WalkSpeed = BASE_SPEED end
                end
            end)
        end
        StopSit(); Tool.Grip = Grips.Normal; CleanUpCarpet(); Roll.Transparency = 0
    end
    local function StartFlying()
        Flying = true; Roll.Transparency = 1; CleanUpCarpet(); BuildCarpet(); PlaySit()
        Tool.Grip = Grips.Flying
        FlightSpin = Instance.new("BodyGyro")
        FlightSpin.P = 1e6; FlightSpin.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        FlightSpin.CFrame = Root.CFrame; FlightSpin.Parent = Root
        FlightPower = Instance.new("BodyVelocity")
        FlightPower.Velocity = Vector3.zero; FlightPower.P = 10000
        FlightPower.MaxForce = Vector3.zero; FlightPower.Parent = Root
        FlightHold = Instance.new("BodyPosition")
        FlightHold.P = 1e5; FlightHold.MaxForce = Vector3.zero
        FlightHold.Position = Root.Position; FlightHold.Parent = Root
        Humanoid.WalkSpeed = 0; Humanoid.PlatformStand = false; Humanoid.AutoRotate = false
        Root.AssemblyLinearVelocity = Vector3.zero
        FlightConn = RunService.Heartbeat:Connect(function()
            if not (Flying and ToolEquipped and CheckIfAlive()) then StopFlying(); return end
            Humanoid.Jump = false
            local look = Workspace.CurrentCamera.CFrame.LookVector
            local right = Workspace.CurrentCamera.CFrame.RightVector
            local mv = GetMoveVector()
            local push = (look * (-mv.Z) * CameraSpeed.Z) + (right * mv.X * CameraSpeed.X)
            FlightSpin.CFrame = CFrame.new(Vector3.zero, look)
            if push.Magnitude < 1 then
                FlightHold.MaxForce = Vector3.new(FlightHold.P, FlightHold.P, FlightHold.P)
                FlightPower.MaxForce = Vector3.zero
                FlightHold.Position = Root.Position
            else
                FlightHold.MaxForce = Vector3.zero
                FlightPower.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            end
            FlightPower.Velocity = push
        end)
        task.spawn(function()
            local lastPlace
            while Flying and ToolEquipped and CheckIfAlive() do
                local current = Handle.Position
                local vel = Root.AssemblyLinearVelocity
                local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                if lastPlace and speed > 10 then
                    CreateRainbow(lastPlace, current); lastPlace = current
                elseif not lastPlace then
                    lastPlace = current
                end
                task.wait(Rate)
            end
        end)
    end
    Tool.Equipped:Connect(function()
        Character = Tool.Parent
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        Root = Character:FindFirstChild("HumanoidRootPart")
        ToolEquipped = true; Tool.Grip = Grips.Normal
    end)
    Tool.Unequipped:Connect(function()
        ToolEquipped = false
        if Flying then StopFlying() end
        Roll.Transparency = 0
    end)
    Tool.Activated:Connect(function()
        if Cooldown or not CheckIfAlive() then return end
        Cooldown = true
        if Flying then StopFlying() else StartFlying() end
        task.delay(2, function() Cooldown = false end)
    end)
    return Tool
end

local function createHairDryer()
    local TOOL_NAME = "HairDryer"
    local MESH_ID = "rbxassetid://11712365"
    local TEXTURE_ID = "rbxassetid://11712384"
    local ICON_ID = "rbxassetid://11716958"
    local SOUND_ID = "rbxassetid://9114743032"
    local POP_SOUND_ID = "rbxassetid://9125402946"
    local PUSH_BACK, PUSH_UP = 90, 110
    local PUSH_SPEED_MULT, PUSH_SMOOTH_IN = 0.45, 8
    local Colors = { "White", "Light stone grey", "Light blue", "Pastel Blue" }
    local Gravity = 196.2

    local bag = getBackpack and getBackpack() or bp
    local char0 = player.Character
    local old = (bag and bag:FindFirstChild(TOOL_NAME))
        or (char0 and char0:FindFirstChild(TOOL_NAME))
    if old then old:Destroy() end

    local Tool = Instance.new("Tool")
    Tool.Name = TOOL_NAME
    Tool.RequiresHandle = true
    Tool.CanBeDropped = false
    Tool.TextureId = ICON_ID
    Tool.Grip = CFrame.new(0.5, 0, -0.8) * CFrame.Angles(0, math.rad(90), math.rad(90))

    -- MeshPart like original (fallback to Part+SpecialMesh)
    local Handle
    local okMesh = pcall(function()
        Handle = Instance.new("MeshPart")
        Handle.Name = "Handle"
        Handle.Size = Vector3.new(1, 1, 1)
        Handle.Transparency = 0
        Handle.CanCollide = false
        Handle.MeshId = MESH_ID
        Handle.TextureID = TEXTURE_ID
        Handle.Parent = Tool
    end)
    if not okMesh or not Handle then
        Handle = Instance.new("Part")
        Handle.Name = "Handle"
        Handle.Size = Vector3.new(1, 1, 1)
        Handle.CanCollide = false
        Handle.Massless = true
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.FileMesh
        m.MeshId = MESH_ID
        m.TextureId = TEXTURE_ID
        m.Parent = Handle
        Handle.Parent = Tool
    end

    local DryerSound = Instance.new("Sound")
    DryerSound.Name = "DryerSound"
    DryerSound.SoundId = SOUND_ID
    DryerSound.Looped = true
    DryerSound.Volume = 1
    DryerSound.Parent = Handle

    local BasePart = Instance.new("Part")
    BasePart.Shape = Enum.PartType.Block
    BasePart.Material = Enum.Material.Plastic
    BasePart.Size = Vector3.new(0.2, 0.2, 0.2)
    BasePart.CanCollide = true
    BasePart.Anchored = false
    local AirBubble = BasePart:Clone()
    AirBubble.Name = "Effect"
    AirBubble.Shape = Enum.PartType.Ball
    AirBubble.Size = Vector3.new(1.4, 1.4, 1.4)
    AirBubble.CanCollide = false
    AirBubble.Massless = true
    AirBubble.CanQuery = false
    AirBubble.CanTouch = true

    local MouseDown, ToolEquipped = false, false
    local Character = player.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local pushBV, currentVel, targetVel = nil, Vector3.new(), Vector3.new()

    local function CheckIfAlive()
        return Character and Character.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0
    end

    -- old-style BodyVelocity push, but lower force + hard cleanup so move is not locked
    local function EnsurePushBV(root)
        if pushBV and pushBV.Parent == root then return pushBV end
        if pushBV then pcall(function() pushBV:Destroy() end) end
        pushBV = Instance.new("BodyVelocity")
        pushBV.Name = "DryerPush"
        pushBV.MaxForce = Vector3.new(4e4, 4e4, 4e4) -- not 1e7 (was locking move)
        pushBV.Velocity = Vector3.new()
        pushBV.Parent = root
        return pushBV
    end

    local function ApplyPush(Direction)
        if not CheckIfAlive() then return end
        local root = Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local backDir = Vector3.new(-Direction.X, 0, -Direction.Z)
        if backDir.Magnitude < 0.01 then
            backDir = Vector3.new()
        else
            backDir = backDir.Unit
        end
        targetVel = Vector3.new(
            backDir.X * PUSH_BACK * PUSH_SPEED_MULT,
            PUSH_UP * PUSH_SPEED_MULT,
            backDir.Z * PUSH_BACK * PUSH_SPEED_MULT
        )
        EnsurePushBV(root)
    end

    local function StopPush()
        targetVel = Vector3.new()
        currentVel = Vector3.new()
        if pushBV then pcall(function() pushBV:Destroy() end) pushBV = nil end
        local root = Character and Character:FindFirstChild("HumanoidRootPart")
        if root then
            for _, c in ipairs(root:GetChildren()) do
                if c.Name == "DryerPush" then pcall(function() c:Destroy() end) end
            end
        end
        if Humanoid then
            pcall(function()
                Humanoid.PlatformStand = false
                Humanoid.AutoRotate = true
                if Humanoid.WalkSpeed < 1 then Humanoid.WalkSpeed = BASE_SPEED end
            end)
        end
    end

    RunService.Heartbeat:Connect(function(dt)
        if not MouseDown then
            if pushBV then StopPush() end
            return
        end
        if not CheckIfAlive() then StopPush() return end
        local root = Character:FindFirstChild("HumanoidRootPart")
        if not root or not pushBV or pushBV.Parent ~= root then return end
        currentVel = currentVel:Lerp(targetVel, math.clamp(dt * PUSH_SMOOTH_IN, 0, 1))
        pushBV.Velocity = currentVel
    end)

    local function setupBubblePop(bubble)
        local popped = false
        local conn
        conn = bubble.Touched:Connect(function(hit)
            if popped then return end
            if not hit:IsA("BasePart") then return end
            if hit.Name == "Effect" then return end
            if Character and hit:IsDescendantOf(Character) then return end
            popped = true
            if conn then conn:Disconnect() end
            pcall(function()
                local pop = Instance.new("Sound")
                pop.SoundId = POP_SOUND_ID
                pop.Volume = 0.5
                pop.Parent = bubble
                pop:Play()
            end)
            task.spawn(function()
                for _ = 1, 5 do
                    if bubble and bubble.Parent then
                        bubble.Size = bubble.Size * 0.7
                        bubble.Transparency = math.min(1, bubble.Transparency + 0.2)
                    end
                    task.wait(0.02)
                end
                if bubble and bubble.Parent then bubble:Destroy() end
            end)
        end)
    end

    local function Fire(Direction)
        if not CheckIfAlive() then return end
        local SpawnPos = Handle.Position + (Direction * 7.5)
        local Force = 80
        local Air = AirBubble:Clone()
        Air.Transparency = math.random() * 0.5
        Air.CFrame = CFrame.new(SpawnPos, SpawnPos + Direction)
        pcall(function() Air.AssemblyLinearVelocity = Direction * Force end)
        Air.BrickColor = BrickColor.new(Colors[math.random(1, #Colors)])
        local Mass = Air:GetMass() * Gravity
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(Mass, Mass, Mass)
        bv.Velocity = Direction * Force
        bv.Parent = Air
        local Creator = Instance.new("ObjectValue")
        Creator.Name = "Creator"
        Creator.Value = player
        Creator.Parent = Air
        setupBubblePop(Air)
        Debris:AddItem(Air, 2.4)
        Air.Parent = Workspace
        -- after a short flight, scatter sideways so bubbles fan out
        task.delay(0.28 + math.random() * 0.12, function()
            if not Air or not Air.Parent then return end
            local side = Vector3.new(math.random() - 0.5, math.random() * 0.4, math.random() - 0.5)
            if side.Magnitude > 0.01 then side = side.Unit end
            local spread = 35 + math.random() * 45
            local newV = Direction * (Force * 0.55) + side * spread
            if bv and bv.Parent then bv.Velocity = newV end
            pcall(function() Air.AssemblyLinearVelocity = newV end)
        end)
    end

    local function GetTargetPosition()
        local camera = Workspace.CurrentCamera
        if not camera then return nil end
        if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
            return camera.CFrame.Position + (camera.CFrame.LookVector * 100)
        end
        local mouse = player:GetMouse()
        if mouse and mouse.Hit then return mouse.Hit.Position end
        local ray = camera:ScreenPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        local params = RaycastParams.new()
        if Character then params.FilterDescendantsInstances = { Character, Tool } end
        params.FilterType = Enum.RaycastFilterType.Exclude
        local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
        return result and result.Position or (ray.Origin + ray.Direction * 50)
    end

    local function StartFiring()
        if MouseDown or not ToolEquipped then return end
        MouseDown = true
        task.spawn(function()
            pcall(function() DryerSound:Play() end)
            local Rate = 1 / 60
            while MouseDown and ToolEquipped and CheckIfAlive() do
                local TargetPos = GetTargetPosition()
                if TargetPos then
                    task.spawn(function()
                        for _ = 1, 1 do
                            if ToolEquipped and MouseDown then
                                local Direction = (TargetPos - Handle.Position)
                                if Direction.Magnitude > 0.05 then
                                    Direction = Direction.Unit
                                    local Offset = Vector3.new(
                                        (math.random() - 0.5) * 0.3,
                                        (math.random() - 0.5) * 0.3,
                                        (math.random() - 0.5) * 0.3
                                    )
                                    Fire((Direction + Offset).Unit)
                                end
                                task.wait(0.1)
                            end
                        end
                    end)
                    local pushDir = (TargetPos - Handle.Position)
                    if pushDir.Magnitude > 0.05 then
                        ApplyPush(pushDir.Unit)
                    end
                end
                task.wait(Rate)
            end
            pcall(function() DryerSound:Stop() end)
        end)
    end

    local function StopFiring()
        MouseDown = false
        StopPush()
    end

    Tool.Equipped:Connect(function()
        Character = Tool.Parent
        Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        if not CheckIfAlive() then return end
        ToolEquipped = true
    end)

    Tool.Unequipped:Connect(function()
        MouseDown = false
        ToolEquipped = false
        pcall(function() DryerSound:Stop() end)
        StopPush()
    end)

    -- PC + mobile hold (only while this tool equipped)
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or not ToolEquipped then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            StartFiring()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if not ToolEquipped then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            StopFiring()
        end
    end)
    pcall(function()
        ContextActionService:BindAction("CNP_HairDryer_" .. tostring(Tool), function(_, state)
            if not ToolEquipped then return Enum.ContextActionResult.Pass end
            if state == Enum.UserInputState.Begin then StartFiring()
            elseif state == Enum.UserInputState.End then StopFiring() end
            return Enum.ContextActionResult.Sink
        end, false, Enum.KeyCode.ButtonR2)
    end)

    return Tool
end

local function createWaterBow()
    local t = Instance.new("Tool")
    t.Name = "WaterBow"
    t.RequiresHandle = true
    t.CanBeDropped = false
    t.TextureId = "rbxassetid://235108271"
    local h = Instance.new("Part")
    h.Name = "Handle"
    h.Size = Vector3.new(1, 1, 1)
    h.CanCollide = false
    h.Massless = true
    local wm = Instance.new("SpecialMesh")
    wm.MeshType = Enum.MeshType.FileMesh
    wm.MeshId = "rbxassetid://235107551"
    wm.TextureId = "rbxassetid://235107780"
    wm.Scale = Vector3.new(1, 1, 1)
    wm.Parent = h
    h.Parent = t
    t.Grip = CFrame.new(0, -0.2, 0.5) * CFrame.Angles(0, math.rad(20), 0)
    return t
end

local WATER_RADIUS, WATER_HEIGHT = 12, 9
local JUMP_COOLDOWN, CLICK_COOLDOWN = 0.5, 1
local lastJumpTime, launching, lastWaterClick = 0, false, 0
local currentWater, touchStartPos = nil, nil

local function SpawnWaterBlock()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if currentWater and currentWater.cleanup then currentWater.cleanup() end
    local center = Vector3.new(root.Position.X, root.Position.Y - 2, root.Position.Z)
    Workspace.Terrain:FillBall(center, WATER_RADIUS, Enum.Material.Water)
    currentWater = {
        center = center,
        radius = WATER_RADIUS,
        topY = center.Y + WATER_HEIGHT / 2,
        bottomY = center.Y - WATER_HEIGHT / 2,
    }
    currentWater.cleanup = function()
        pcall(function() Workspace.Terrain:FillBall(center, WATER_RADIUS, Enum.Material.Air) end)
        currentWater = nil
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local char = player.Character
    if not char or not char:FindFirstChild("WaterBow") then return end
    if input.UserInputType == Enum.UserInputType.Touch then
        touchStartPos = input.Position
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        if tick() - lastWaterClick > CLICK_COOLDOWN then
            lastWaterClick = tick()
            SpawnWaterBlock()
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    local char = player.Character
    if not char or not char:FindFirstChild("WaterBow") then return end
    if input.UserInputType == Enum.UserInputType.Touch and touchStartPos then
        local d = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(touchStartPos.X, touchStartPos.Y)).Magnitude
        if d < 15 and tick() - lastWaterClick > CLICK_COOLDOWN then
            lastWaterClick = tick()
            SpawnWaterBlock()
        end
        touchStartPos = nil
    end
end)

local function launchOut()
    if launching or tick() - lastJumpTime < JUMP_COOLDOWN or not currentWater then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    local p, w = root.Position, currentWater
    local dx, dz = p.X - w.center.X, p.Z - w.center.Z
    local dist = math.sqrt(dx * dx + dz * dz)
    if not (dist <= w.radius and p.Y < w.topY and p.Y > w.bottomY - 20) then return end
    local depthY = math.clamp(p.Y, w.bottomY, w.topY)
    local depthRatio = math.clamp((w.topY - depthY) / math.max(w.topY - w.bottomY, 0.01), 0, 1)
    -- higher launch: base 130 surface, deeper up to ~210
    local power = 130 + (90 * depthRatio)
    power = math.clamp(power, 130, 210)
    launching = true
    lastJumpTime = tick()
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Freefall) end)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(0, math.huge, 0) -- only vertical — less fling
    bv.Velocity = Vector3.new(0, power, 0)
    bv.Parent = root
    task.delay(0.15, function() if bv then bv:Destroy() end end)
    task.delay(JUMP_COOLDOWN, function() launching = false end)
end

pcall(function()
    ContextActionService:BindActionAtPriority("WaterLaunch", function(_, state)
        if state == Enum.UserInputState.Begin then launchOut() end
        return Enum.ContextActionResult.Pass
    end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end)

task.spawn(function()
    for _ = 1, 20 do
        local tg = pg:FindFirstChild("TouchGui")
        local jb = tg and tg:FindFirstChild("JumpButton", true)
        if jb and not jb:GetAttribute("CNP_WaterHook") then
            jb:SetAttribute("CNP_WaterHook", true)
            jb.MouseButton1Down:Connect(launchOut)
        end
        task.wait(0.5)
    end
end)

local function getBackpack()
    local bag = player:FindFirstChildOfClass("Backpack")
    if bag then return bag end
    local ok, b = pcall(function() return player:WaitForChild("Backpack", 3) end)
    if ok then return b end
    return nil
end



-- ===== COILS (Speed / Gravity / DualGravity) =====
local COIL_DEFAULT_SPEED = BASE_SPEED
local DUAL_GRAVITY_LOCKED_OFFSET = CFrame.new(-0.3, -1.45, 0.28) -- Y up a bit, Z forward a bit
local coilLoopConn = nil
local coilGravityMult = 1
-- coilActiveSpeed / coilSpeedBoost are outer-scope (STATE)
coilActiveSpeed = COIL_DEFAULT_SPEED
coilSpeedBoost = false
local coilForce = nil
local coilAttachment = nil
local coilWeld = nil

local COIL_CONFIGS = {
    {
        Name = "SpeedCoil",
        TextureId = "rbxassetid://99170415",
        MeshId = "rbxassetid://16606212",
        SkinTextureId = "rbxassetid://99170547",
        SoundId = "rbxassetid://99173388",
        Color = Color3.fromRGB(255, 60, 60),
        WalkSpeed = 34,
        GravityMultiplier = 1,
        Scale = 0.6,
    },
    {
        Name = "GravityCoil",
        TextureId = "rbxassetid://16619617",
        MeshId = "rbxassetid://16606212",
        SkinTextureId = "rbxassetid://16606141",
        SoundId = "rbxassetid://16619553",
        Color = Color3.fromRGB(80, 170, 255),
        WalkSpeed = COIL_DEFAULT_SPEED,
        GravityMultiplier = 0.25,
        Scale = 0.6,
    },
    {
        Name = "DualGravityCoil",
        TextureId = "rbxassetid://150063217",
        MeshId = "rbxassetid://150063131",
        SkinTextureId = "rbxassetid://150063177",
        SoundId = "rbxassetid://16619553",
        Color = Color3.fromRGB(120, 210, 255),
        WalkSpeed = COIL_DEFAULT_SPEED,
        GravityMultiplier = 0.15,
        Scale = 1.35,
        AtFootPositionLockPose = true,
    },
}

local function clearCoilWeld()
    if coilWeld then
        pcall(function() coilWeld:Destroy() end)
        coilWeld = nil
    end
end

local function clearCoilGravityForce()
    if coilForce then
        pcall(function() coilForce:Destroy() end)
        coilForce = nil
    end
    if coilAttachment then
        pcall(function() coilAttachment:Destroy() end)
        coilAttachment = nil
    end
end

local function placeCoilAtFootLockedPose(char, hum, root, handle)
    clearCoilWeld()
    if not char or not hum or not root or not handle then return end
    local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
    if rightHand then
        local grip = rightHand:FindFirstChild("RightGrip")
        if grip then pcall(function() grip:Destroy() end) end
    end
    handle.Anchored = false
    handle.CanCollide = false
    handle.Massless = true
    handle.CFrame = root.CFrame * DUAL_GRAVITY_LOCKED_OFFSET
    local weld = Instance.new("Weld")
    weld.Name = "DualGravityLockedFootWeld"
    weld.Part0 = root
    weld.Part1 = handle
    weld.C0 = DUAL_GRAVITY_LOCKED_OFFSET
    weld.C1 = CFrame.new()
    weld.Parent = handle
    coilWeld = weld
end

local function ensureCoilGravityForce(root)
    if not root then return end
    if not coilAttachment or not coilAttachment.Parent then
        coilAttachment = Instance.new("Attachment")
        coilAttachment.Name = "CoilGravityAttachment"
        coilAttachment.Parent = root
    end
    if not coilForce or not coilForce.Parent then
        coilForce = Instance.new("VectorForce")
        coilForce.Name = "CoilGravityForce"
        coilForce.Attachment0 = coilAttachment
        coilForce.RelativeTo = Enum.ActuatorRelativeTo.World
        coilForce.ApplyAtCenterOfMass = true
        coilForce.Parent = root
    end
    coilForce.Attachment0 = coilAttachment
end

local function stopCoilEffect()
    if coilLoopConn then
        coilLoopConn:Disconnect()
        coilLoopConn = nil
    end
    coilGravityMult = 1
    coilActiveSpeed = COIL_DEFAULT_SPEED
    coilSpeedBoost = false
    clearCoilGravityForce()
    clearCoilWeld()
    local c = player.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hum and not speedEnabled and hum.WalkSpeed ~= BASE_SPEED then
        pcall(function() hum.WalkSpeed = BASE_SPEED end)
    end
end

local function startCoilEffect(cfg, tool)
    stopCoilEffect()
    coilActiveSpeed = cfg.WalkSpeed or COIL_DEFAULT_SPEED
    coilGravityMult = cfg.GravityMultiplier or 1
    -- SpeedCoil must work even when CNP speed is off (speed system was clamping to 16)
    coilSpeedBoost = (coilActiveSpeed > COIL_DEFAULT_SPEED + 0.5)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local handle = tool and tool:FindFirstChild("Handle")
    if hum and coilSpeedBoost then
        pcall(function() hum.WalkSpeed = coilActiveSpeed end)
    end
    if cfg.AtFootPositionLockPose and char and hum and root and handle then
        task.defer(function()
            if tool.Parent == char then
                placeCoilAtFootLockedPose(char, hum, root, handle)
            end
        end)
    end
    coilLoopConn = RunService.Heartbeat:Connect(function()
        local c = player.Character
        local curHum = c and c:FindFirstChildOfClass("Humanoid")
        local curRoot = c and c:FindFirstChild("HumanoidRootPart")
        if not curHum or curHum.Health <= 0 or not curRoot then
            clearCoilGravityForce()
            return
        end
        -- apply coil speed unless CNP speed boost is actively running
        if coilSpeedBoost and not speedEnabled then
            if curHum.WalkSpeed ~= coilActiveSpeed then
                curHum.WalkSpeed = coilActiveSpeed
            end
        elseif coilSpeedBoost and speedEnabled and not isUnlocked then
            -- CNP speed on but not unlocked yet → still let SpeedCoil work
            if curHum.WalkSpeed ~= coilActiveSpeed then
                curHum.WalkSpeed = coilActiveSpeed
            end
        end
        if cfg.AtFootPositionLockPose and handle and (not coilWeld or not coilWeld.Parent) and tool.Parent == c then
            placeCoilAtFootLockedPose(c, curHum, curRoot, handle)
        end
        if coilGravityMult < 1 then
            ensureCoilGravityForce(curRoot)
            local mass = curRoot.AssemblyMass
            local liftY = mass * Workspace.Gravity * (1 - coilGravityMult)
            coilForce.Force = Vector3.new(0, liftY, 0)
        else
            clearCoilGravityForce()
        end
    end)
end

local function createCoilTool(cfg)
    local bag = getBackpack and getBackpack() or bp
    local char0 = player.Character
    local old = (bag and bag:FindFirstChild(cfg.Name))
        or (char0 and char0:FindFirstChild(cfg.Name))
    if old then old:Destroy() end

    local scale = cfg.Scale or 1
    local tool = Instance.new("Tool")
    tool.Name = cfg.Name
    tool.TextureId = cfg.TextureId
    tool.RequiresHandle = true
    tool.CanBeDropped = false

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1.5 * scale, 1.5 * scale, 1.5 * scale)
    handle.Color = cfg.Color
    handle.Material = Enum.Material.SmoothPlastic
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = cfg.MeshId
    mesh.TextureId = cfg.SkinTextureId
    mesh.Scale = Vector3.new(scale, scale, scale)
    mesh.Parent = handle

    local sound = Instance.new("Sound")
    sound.Name = "EquipSound"
    sound.SoundId = cfg.SoundId
    sound.Volume = 1
    sound.Parent = handle

    tool.Equipped:Connect(function()
        pcall(function() sound:Play() end)
        startCoilEffect(cfg, tool)
    end)
    tool.Unequipped:Connect(function()
        stopCoilEffect()
    end)
    tool.Destroying:Connect(function()
        stopCoilEffect()
    end)

    return tool
end

local function createSpeedCoil()
    return createCoilTool(COIL_CONFIGS[1])
end
local function createGravityCoil()
    return createCoilTool(COIL_CONFIGS[2])
end
local function createDualGravityCoil()
    return createCoilTool(COIL_CONFIGS[3])
end

local function createBombSphere()
    local LIFT_SPEED = 55
    local bag = getBackpack and getBackpack() or bp
    local char0 = player.Character
    local old = (bag and bag:FindFirstChild("bomb"))
        or (char0 and char0:FindFirstChild("bomb"))
    if old then old:Destroy() end

    local tool = Instance.new("Tool")
    tool.Name = "bomb"
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.Grip = CFrame.new(0, -0.2, 0.2)

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Shape = Enum.PartType.Ball
    handle.Size = Vector3.new(1.5, 1.5, 1.5)
    handle.Color = Color3.fromRGB(15, 15, 15)
    handle.Material = Enum.Material.SmoothPlastic
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = tool

    local liftConnection = nil
    local bodyVelocity = nil

    local function stopLift()
        if liftConnection then
            liftConnection:Disconnect()
            liftConnection = nil
        end
        if bodyVelocity then
            pcall(function() bodyVelocity:Destroy() end)
            bodyVelocity = nil
        end
        -- clear leftover on HRP
        local c = player.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("SphereLiftVelocity")
            if bv then pcall(function() bv:Destroy() end) end
        end
    end

    tool.Equipped:Connect(function()
        stopLift()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid or humanoid.Health <= 0 then return end

        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "SphereLiftVelocity"
        bodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
        bodyVelocity.Velocity = Vector3.new(0, LIFT_SPEED, 0)
        bodyVelocity.Parent = hrp

        liftConnection = RunService.Heartbeat:Connect(function()
            if not tool.Parent or tool.Parent ~= char then
                stopLift()
                return
            end
            if humanoid.Health <= 0 then
                stopLift()
                return
            end
            if bodyVelocity and bodyVelocity.Parent then
                bodyVelocity.Velocity = Vector3.new(0, LIFT_SPEED, 0)
            end
        end)
    end)

    tool.Unequipped:Connect(stopLift)
    tool.Destroying:Connect(stopLift)

    return tool
end

local function handleGetTool(name, createFn)
    -- always refresh backpack (respawn replaces the old one)
    local bag = getBackpack()
    if not bag then
        warn("[gear] no backpack")
        return
    end
    bp = bag -- keep global ref fresh

    local t = bag:FindFirstChild(name)
    if not t then
        local c = player.Character
        if c then t = c:FindFirstChild(name) end
    end
    if t then
        if t.Parent ~= bag then
            local ok, err = pcall(function() t.Parent = bag end)
            if not ok then warn("[gear] move failed: ", err) end
        end
        print("[gear] already have " .. name)
        return
    end

    local ok, result = pcall(createFn)
    if not ok then
        warn("[gear] create failed (" .. name .. "): ", result)
        return
    end
    t = result
    if not t then
        warn("[gear] create returned nil: " .. name)
        return
    end
    local ok2, err2 = pcall(function() t.Parent = bag end)
    if not ok2 then
        warn("[gear] parent failed: ", err2)
        return
    end
    print("[gear] got " .. name)
end

local function destroyAllCoils()
    local c = player.Character
    local hm = c and c:FindFirstChildOfClass("Humanoid")
    if hm then pcall(function() hm:UnequipTools() end) end
    do
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if root then
            for _, ch in ipairs(root:GetChildren()) do
                if ch.Name == "DryerPush" then ch:Destroy() end
            end
        end
    end
    pcall(function() stopCoilEffect() end)
    for _, n in ipairs({ "Rainbow Carpet", "Blood Carpet", "Cinnamoroll Carpet", "Flying Carpet", "HairDryer", "WaterBow", "bomb", "SpeedCoil", "GravityCoil", "DualGravityCoil" }) do
        local a = c and c:FindFirstChild(n)
        if a then a:Destroy() end
        local btool = bp:FindFirstChild(n)
        if btool then btool:Destroy() end
    end
    if hm and not speedEnabled then
        pcall(function() hm.WalkSpeed = BASE_SPEED end)
    end
    if currentWater and currentWater.cleanup then currentWater.cleanup() end
end

-- ===== KEY PANEL =====
local keyGui = Instance.new("ScreenGui")
keyGui.Name = "CNP_KeyGate"
keyGui.ResetOnSpawn = false
keyGui.DisplayOrder = 2147483646
keyGui.IgnoreGuiInset = true
keyGui.Enabled = false -- key system removed
pcall(function() keyGui.Parent = game:GetService("CoreGui") end)
if not keyGui.Parent then keyGui.Parent = pg end

local dim = Instance.new("Frame", keyGui)
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(20, 12, 18)
dim.BackgroundTransparency = 0.45
dim.BorderSizePixel = 0
dim.Active = true

local card = Instance.new("Frame", keyGui)
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(isMobile and 300 or 340, 210)
card.BackgroundColor3 = Color3.fromRGB(232, 244, 252)
card.BorderSizePixel = 0
card.Active = true
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)
do
    local st = Instance.new("UIStroke", card)
    st.Color = Color3.fromRGB(255, 160, 195)
    st.Thickness = 1.5
    st.Transparency = 0.2
end

local keyTitle = Instance.new("TextLabel", card)
keyTitle.BackgroundTransparency = 1
keyTitle.Position = UDim2.fromOffset(0, 16)
keyTitle.Size = UDim2.new(1, 0, 0, 26)
keyTitle.Font = UI.titleFont
keyTitle.TextSize = 20
keyTitle.TextColor3 = Color3.fromRGB(40, 100, 150)
keyTitle.Text = "Advanced Unlock"
keyTitle.ZIndex = 2

local keySub = Instance.new("TextLabel", card)
keySub.BackgroundTransparency = 1
keySub.Position = UDim2.fromOffset(18, 44)
keySub.Size = UDim2.new(1, -36, 0, 18)
keySub.Font = UI.font
keySub.TextSize = 12
keySub.TextColor3 = Color3.fromRGB(170, 130, 150)
keySub.TextXAlignment = Enum.TextXAlignment.Left
keySub.Text = "enter key to use CNP panel"
keySub.ZIndex = 2

local boxHold = Instance.new("Frame", card)
boxHold.Position = UDim2.fromOffset(18, 78)
boxHold.Size = UDim2.new(1, -36, 0, 40)
boxHold.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
boxHold.BackgroundTransparency = 0.15
boxHold.BorderSizePixel = 0
boxHold.ZIndex = 2
Instance.new("UICorner", boxHold).CornerRadius = UDim.new(0, 10)

local keyBox = Instance.new("TextBox", boxHold)
keyBox.BackgroundTransparency = 1
keyBox.Size = UDim2.new(1, -16, 1, 0)
keyBox.Position = UDim2.fromOffset(8, 0)
keyBox.Font = UI.font
keyBox.TextSize = 13
keyBox.TextColor3 = Color3.fromRGB(90, 50, 70)
keyBox.PlaceholderColor3 = Color3.fromRGB(190, 160, 175)
keyBox.PlaceholderText = "Enter you key ( Buy with Robux or MM2 Godlys )"
keyBox.Text = ""
keyBox.ClearTextOnFocus = false
keyBox.TextXAlignment = Enum.TextXAlignment.Left
keyBox.ZIndex = 3

local unlockBtn = Instance.new("TextButton", card)
unlockBtn.Position = UDim2.fromOffset(18, 136)
unlockBtn.Size = UDim2.new(1, -36, 0, 40)
unlockBtn.BackgroundColor3 = Color3.fromRGB(70, 150, 210)
unlockBtn.BorderSizePixel = 0
unlockBtn.Font = UI.titleFont
unlockBtn.TextSize = 16
unlockBtn.TextColor3 = Color3.new(1, 1, 1)
unlockBtn.Text = "unlock"
unlockBtn.AutoButtonColor = false
unlockBtn.ZIndex = 2
Instance.new("UICorner", unlockBtn).CornerRadius = UDim.new(0, 10)

local closeKey = Instance.new("TextButton", card)
closeKey.Position = UDim2.new(1, -32, 0, 8)
closeKey.Size = UDim2.fromOffset(24, 24)
closeKey.BackgroundTransparency = 1
closeKey.Font = UI.font
closeKey.TextSize = 18
closeKey.TextColor3 = Color3.fromRGB(200, 150, 170)
closeKey.Text = "x"
closeKey.ZIndex = 3

local function closeKeyPanel()
    -- key system removed
end

local function openKeyPanel()
    -- key system removed
end

-- không đóng khi bấm ra ngoài / nút x — chỉ đóng khi nhập đúng hoặc sai key
closeKey.Visible = false
dim.Active = true

-- ===== GEAR PANEL =====
local gearGui = Instance.new("ScreenGui")
gearGui.Name = "CNP_GearPanel"
gearGui.ResetOnSpawn = false
gearGui.DisplayOrder = 2147483645
gearGui.Enabled = false
gearGui.IgnoreGuiInset = true
gearGui.DisplayOrder = 2147483645
pcall(function() gearGui.Parent = game:GetService("CoreGui") end)
if not gearGui.Parent then gearGui.Parent = pg end

local gearFrame = Instance.new("Frame", gearGui)
do
    local gw = fitW(isMobile and 270 or 300)
    local gh = fitH(isMobile and 380 or 420)
    gearFrame.Size = UDim2.fromOffset(gw, gh)
    gearFrame.Position = UDim2.new(0.5, -gw / 2, 0.5, -gh / 2)
end
gearFrame.BackgroundColor3 = UI.bg
gearFrame.BorderSizePixel = 0
gearFrame.Active = true
gearFrame.ClipsDescendants = true
pcall(function() gearFrame.Modal = false end)
pcall(function() applyGlass(gearFrame, 0.12) end)
Instance.new("UICorner", gearFrame).CornerRadius = UDim.new(0, 14)
do
    local st = Instance.new("UIStroke", gearFrame)
    st.Color = Color3.fromRGB(200, 160, 70)
    st.Thickness = 2
    st.Transparency = 0.15
end

local gearTop = Instance.new("TextLabel", gearFrame)
gearTop.Size = UDim2.new(1, -40, 0, 36)
gearTop.BackgroundTransparency = 1
gearTop.Active = true
gearTop.Text = "Gear"
gearTop.TextColor3 = Color3.fromRGB(240, 200, 100)
gearTop.Font = UI.titleFont
gearTop.TextSize = 20
gearTop.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UIPadding", gearTop).PaddingLeft = UDim.new(0, 14)
makeDraggable(gearFrame, gearTop)

local gearClose = Instance.new("TextButton", gearFrame)
gearClose.Size = UDim2.fromOffset(26, 26)
gearClose.Position = UDim2.new(1, -30, 0, 5)
gearClose.BackgroundTransparency = 1
gearClose.Text = "x"
gearClose.TextColor3 = UI.dim
gearClose.Font = UI.font
gearClose.TextSize = 18
gearClose.BorderSizePixel = 0
local function closeGearPanel()
    gearGui.Enabled = false
    -- never force MouseBehavior here (keeps PC camera free / shiftlock intact)
end
gearClose.Activated:Connect(closeGearPanel)

do
    local ln = Instance.new("Frame", gearFrame)
    ln.Size = UDim2.new(1, -24, 0, 1)
    ln.Position = UDim2.new(0, 12, 0, 36)
    ln.BackgroundColor3 = UI.line
    ln.BackgroundTransparency = 0.45
    ln.BorderSizePixel = 0
end

local gearScroll = Instance.new("ScrollingFrame", gearFrame)
gearScroll.Size = UDim2.new(1, -14, 1, -46)
gearScroll.Position = UDim2.new(0, 7, 0, 41)
gearScroll.BackgroundTransparency = 1
gearScroll.BorderSizePixel = 0
gearScroll.ScrollBarThickness = 3
gearScroll.ScrollBarImageColor3 = UI.line
gearScroll.CanvasSize = UDim2.new()
gearScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
gearScroll.ScrollingDirection = Enum.ScrollingDirection.Y
do
    local lay = Instance.new("UIListLayout", gearScroll)
    lay.Padding = UDim.new(0, 5)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
end

UI.action(gearScroll, 1, "rainbow carpet", function()
    handleGetTool("Rainbow Carpet", createRainbowCarpet)
end)
UI.action(gearScroll, 2, "blood carpet", function()
    handleGetTool("Blood Carpet", createBloodCarpet)
end)
UI.action(gearScroll, 3, "cinnamoroll carpet", function()
    handleGetTool("Cinnamoroll Carpet", createCinnaCarpet)
end)
UI.action(gearScroll, 4, "flying carpet", function()
    handleGetTool("Flying Carpet", createGoldCarpet)
end)
UI.action(gearScroll, 5, "hair dryer", function()
    handleGetTool("HairDryer", createHairDryer)
end)
UI.action(gearScroll, 6, "waterbow", function()
    handleGetTool("WaterBow", createWaterBow)
end)
UI.action(gearScroll, 7, "bomb", function()
    handleGetTool("bomb", createBombSphere)
end)
UI.action(gearScroll, 8, "speed coil", function()
    handleGetTool("SpeedCoil", createSpeedCoil)
end)
UI.action(gearScroll, 9, "gravity coil", function()
    handleGetTool("GravityCoil", createGravityCoil)
end)
UI.action(gearScroll, 10, "dual gravity coil", function()
    handleGetTool("DualGravityCoil", createDualGravityCoil)
end)
UI.action(gearScroll, 11, "clear all tools", function()
    destroyAllCoils()
    print("gear tools cleared")
end)


-- ===== GEAR FLOAT BUTTON (G) — right side =====
local gearFloatGui = Instance.new("ScreenGui")
gearFloatGui.Name = "CNP_GearFloat"
gearFloatGui.ResetOnSpawn = false
gearFloatGui.DisplayOrder = 2147483645
gearFloatGui.IgnoreGuiInset = true
gearFloatGui.Enabled = true
pcall(function() gearFloatGui.Parent = game:GetService("CoreGui") end)
if not gearFloatGui.Parent then gearFloatGui.Parent = pg end

local gearFloat = Instance.new("TextButton", gearFloatGui)
gearFloat.Name = "GearG"
gearFloat.Size = UDim2.fromOffset(44, 44)
gearFloat.AnchorPoint = Vector2.new(1, 0.5)
gearFloat.Position = UDim2.new(1, -14, 0.5, 0)
gearFloat.BackgroundColor3 = Color3.fromRGB(196, 40, 48)
gearFloat.BackgroundTransparency = 0.05
gearFloat.BorderSizePixel = 0
gearFloat.Text = "G"
gearFloat.Font = UI.titleFont
gearFloat.TextSize = 22
gearFloat.TextColor3 = Color3.fromRGB(255, 240, 200)
gearFloat.AutoButtonColor = false
gearFloat.Active = true
pcall(function() gearFloat.Modal = false end)
Instance.new("UICorner", gearFloat).CornerRadius = UDim.new(0, 12)
do
    local st = Instance.new("UIStroke", gearFloat)
    st.Color = Color3.fromRGB(212, 175, 55)
    st.Thickness = 2
    st.Transparency = 0.1
end
do
    local g = Instance.new("UIGradient", gearFloat)
    g.Rotation = 120
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 60, 55)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 120, 60)),
    })
end
makeDraggable(gearFloat, gearFloat)

gearFloat.MouseButton1Click:Connect(function()
    gearGui.Enabled = not gearGui.Enabled
    if gearFrame then
        pcall(function() gearFrame.Modal = false end)
    end
end)
gearFloat.MouseEnter:Connect(function()
    gearFloat.BackgroundColor3 = Color3.fromRGB(95, 170, 225)
end)
gearFloat.MouseLeave:Connect(function()
    gearFloat.BackgroundColor3 = Color3.fromRGB(70, 150, 210)
end)

-- ===== BEAM PANEL (kawaii style, matches main) =====
local beamGui = Instance.new("ScreenGui")
beamGui.Name = "CNP_BeamPanel"
beamGui.ResetOnSpawn = false
beamGui.DisplayOrder = 2147483644
beamGui.Enabled = false
pcall(function() beamGui.Parent = game:GetService("CoreGui") end)
if not beamGui.Parent then beamGui.Parent = pg end

do
    local ORIGINAL_KEY = "GAME ORIGINAL"
    local BeamThickness = 0.26
    local GlowIntensity = 1.0
    local IsGlowEnabled = true
    local NeonEnabled = false
    local CurrentBeamMode = ORIGINAL_KEY
    local Running = true
    local CurrentBeam = nil
    local BaseBrightness = 1
    local OriginalState = nil
    local NeedRestoreOriginal = false
    local NEON_BRIGHTNESS = 2
    local HALO_SCALE = 2.4
    local HALO_TRANSPARENCY = 0.55
    local Halo, HaloSource = nil, nil
    local Connections = {}
    local function Track(c) table.insert(Connections, c); return c end

    local HasBrightness = pcall(function()
        local b = Instance.new("Beam")
        local _ = b.Brightness
        b:Destroy()
    end)
    local function SetBrightness(beam, v)
        if HasBrightness then pcall(function() beam.Brightness = v end) end
    end

    local C = Color3.fromRGB
    local Categories = { "ORIGINAL", "MIX", "COMBO", "WARM", "COOL", "SPACE" }
    local BeamList = {}
    local function P(cat, name, ...) table.insert(BeamList, { cat, name, { ... } }) end
    -- ORIGINAL
    P("ORIGINAL", ORIGINAL_KEY)
    P("ORIGINAL", "Red", C(255,0,0))
    P("ORIGINAL", "Orange", C(255,120,0))
    P("ORIGINAL", "Yellow", C(255,230,0))
    P("ORIGINAL", "Lime", C(130,255,0))
    P("ORIGINAL", "Green", C(0,255,0))
    P("ORIGINAL", "Teal", C(0,220,170))
    P("ORIGINAL", "Cyan", C(0,255,255))
    P("ORIGINAL", "Sky Blue", C(80,180,255))
    P("ORIGINAL", "Blue", C(0,60,255))
    P("ORIGINAL", "Violet", C(130,0,255))
    P("ORIGINAL", "Purple", C(190,0,255))
    P("ORIGINAL", "Magenta", C(255,0,255))
    P("ORIGINAL", "Pink", C(255,183,197))
    P("ORIGINAL", "Hot Pink", C(255,0,110))
    P("ORIGINAL", "White", C(255,255,255))
    -- MIX
    P("MIX", "Bubblegum", C(255,140,200), C(255,200,230), C(140,220,255))
    P("MIX", "Grape", C(60,0,90), C(130,30,190), C(200,120,255))
    P("MIX", "Royal", C(30,30,140), C(80,40,200), C(255,200,40))
    P("MIX", "Rose Gold", C(183,110,121), C(255,190,170), C(255,225,210))
    P("MIX", "Peach", C(255,150,120), C(255,190,150), C(255,225,190))
    P("MIX", "Desert", C(120,60,20), C(210,140,60), C(255,220,140))
    P("MIX", "Silver", C(120,120,130), C(210,210,220), C(255,255,255))
    P("MIX", "Cherry", C(120,0,30), C(220,0,60), C(255,90,120))
    P("MIX", "Forest", C(0,40,10), C(20,110,30), C(110,190,60))
    P("MIX", "Lemon Lime", C(255,250,60), C(160,255,60), C(0,220,80))
    P("MIX", "Sakura", C(255,190,210), C(255,100,170), C(255,0,130), C(255,220,240))
    -- COMBO
    P("COMBO", "Rainbow Hard", C(255,0,0), C(255,127,0), C(255,255,0), C(0,255,0), C(0,180,255), C(0,0,255), C(180,0,255))
    P("COMBO", "Rainbow Roll", C(255,0,0), C(255,120,0), C(255,255,0), C(0,255,0), C(0,255,255), C(0,80,255), C(200,0,255))
    P("COMBO", "Pastel Rainbow", C(255,170,170), C(255,220,150), C(200,255,170), C(150,230,255), C(210,170,255))
    P("COMBO", "Candy", C(255,80,120), C(255,200,60), C(90,230,200), C(140,100,255))
    P("COMBO", "Retro", C(255,0,110), C(255,190,11), C(58,134,255), C(131,56,236))
    P("COMBO", "Plasma", C(255,0,200), C(120,0,255), C(0,160,255), C(0,255,200))
    P("COMBO", "Vaporwave", C(255,113,206), C(1,205,254), C(5,255,161), C(185,103,255))
    P("COMBO", "Aurora", C(0,255,135), C(0,180,255), C(130,60,255), C(255,60,200))
    P("COMBO", "Cotton Candy", C(255,150,210), C(180,150,255), C(100,220,255), C(255,255,255))
    P("COMBO", "Fire & Ice", C(255,40,0), C(255,200,0), C(255,255,255), C(0,200,255), C(0,60,255))
    P("COMBO", "Cyberpunk", C(255,0,100), C(255,0,220), C(0,255,255), C(0,100,255))
    P("COMBO", "Police", C(255,0,0), C(255,255,255), C(0,0,255), C(255,255,255))
    P("COMBO", "Black & White", C(0,0,0), C(255,255,255), C(0,0,0), C(255,255,255))
    P("COMBO", "Gold & Silver", C(255,190,0), C(255,240,150), C(180,180,180), C(255,255,255))
    -- WARM
    P("WARM", "Fire", C(120,0,0), C(255,0,0), C(255,90,0), C(255,220,0))
    P("WARM", "Magma", C(40,0,0), C(150,0,0), C(255,40,0), C(255,150,0))
    P("WARM", "Lava", C(60,0,0), C(200,20,0), C(255,110,0), C(255,230,60))
    P("WARM", "Sunset", C(255,0,80), C(255,70,0), C(255,160,0), C(255,230,100))
    P("WARM", "Sunrise", C(255,94,98), C(255,153,102), C(255,206,84), C(255,250,200))
    P("WARM", "Blood Moon", C(30,0,0), C(100,0,0), C(200,0,0), C(255,40,40))
    -- COOL
    P("COOL", "Ocean Blue", C(0,20,100), C(0,100,255), C(0,220,255), C(100,255,255))
    P("COOL", "Sapphire", C(0,0,70), C(0,50,180), C(0,130,255), C(100,220,255))
    P("COOL", "Ice", C(255,255,255), C(150,240,255), C(0,180,255), C(0,70,255))
    P("COOL", "Teal Wave", C(0,60,70), C(0,160,170), C(90,240,230))
    P("COOL", "Mint", C(0,200,150), C(120,255,210), C(220,255,245))
    P("COOL", "Emerald", C(0,50,30), C(0,130,70), C(0,255,130), C(150,255,200))
    -- SPACE
    P("SPACE", "Galaxy", C(5,0,40), C(60,0,140), C(180,40,255), C(255,120,230), C(255,255,255))
    P("SPACE", "Midnight", C(10,10,50), C(40,30,120), C(90,60,200), C(160,140,255))
    P("SPACE", "Pink Galaxy", C(255,20,147), C(255,105,180), C(190,0,255), C(100,0,180), C(255,0,220))
    P("SPACE", "Purple Haze", C(50,0,100), C(120,0,255), C(200,0,255), C(255,0,180))
    P("SPACE", "Amethyst", C(60,0,100), C(120,0,200), C(190,80,255), C(255,180,255))

    local BeamPresets = {}
    for _, e in ipairs(BeamList) do
        if #e[3] > 0 then BeamPresets[e[2]] = e[3] end
    end

    local function CreateHardSequence(colors)
        local keypoints = {}
        local step = 1 / #colors
        for i, color in ipairs(colors) do
            table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) * step, color))
            if i < #colors then
                table.insert(keypoints, ColorSequenceKeypoint.new(i * step - 0.01, color))
            else
                table.insert(keypoints, ColorSequenceKeypoint.new(1, color))
            end
        end
        return ColorSequence.new(keypoints)
    end
    local function CreateSmoothSequence(colors)
        local n = #colors
        if n == 1 then return ColorSequence.new(colors[1]) end
        local kp = {}
        for i, c in ipairs(colors) do kp[i] = ColorSequenceKeypoint.new((i - 1) / (n - 1), c) end
        return ColorSequence.new(kp)
    end
    local SequenceCache = {}
    for name, colors in pairs(BeamPresets) do
        SequenceCache[name] = CreateHardSequence(colors)
    end
    local LastRollOffset, RollSequence = -1, nil
    local function GetRollSequence()
        local base = BeamPresets["Rainbow Roll"]
        local offset = math.floor(tick() * 8) % #base
        if offset ~= LastRollOffset then
            LastRollOffset = offset
            local rolled = {}
            for i = 1, #base do rolled[i] = base[((i + offset - 1) % #base) + 1] end
            RollSequence = CreateHardSequence(rolled)
        end
        return RollSequence
    end

    local function DestroyHalo()
        if Halo then Halo:Destroy(); Halo = nil; HaloSource = nil end
    end
    local function UpdateHalo(beam)
        if not Halo or HaloSource ~= beam or not Halo.Parent then
            DestroyHalo()
            local ok, h = pcall(function() return beam:Clone() end)
            if not ok or not h then return end
            h.Name = "NeonHalo"; h.Parent = beam.Parent
            Halo = h; HaloSource = beam
        end
        Halo.Enabled = beam.Enabled
        Halo.Attachment0 = beam.Attachment0
        Halo.Attachment1 = beam.Attachment1
        Halo.Color = beam.Color
        Halo.Texture = ""
        Halo.Width0 = BeamThickness * HALO_SCALE
        Halo.Width1 = BeamThickness * HALO_SCALE
        Halo.Transparency = NumberSequence.new(HALO_TRANSPARENCY)
        Halo.LightEmission = 1
        Halo.LightInfluence = 0
        SetBrightness(Halo, NEON_BRIGHTNESS)
    end

    local OriginalByBeam = setmetatable({}, { __mode = "k" })

    local function isHaloBeam(b)
        return b == Halo or (b and b.Name == "NeonHalo")
    end

    local function FindAllBeams()
        local list = {}
        local seen = {}
        local function add(obj)
            if obj and obj:IsA("Beam") and not isHaloBeam(obj) and not seen[obj] then
                seen[obj] = true
                list[#list + 1] = obj
            end
        end
        local function addFrom(root)
            if not root then return end
            local ok, descs = pcall(function() return root:GetDescendants() end)
            if ok and descs then
                for _, obj in ipairs(descs) do add(obj) end
            end
            for _, obj in ipairs(root:GetChildren()) do add(obj) end
        end
        -- character / tools
        addFrom(player.Character)
        -- MM2 shot beam often Workspace.Part.Beam
        for _, ch in ipairs(Workspace:GetChildren()) do
            if ch.Name == "Part" then addFrom(ch) end
        end
        return list
    end

    local StyledWidth = setmetatable({}, { __mode = "k" }) -- width applied once

    local function rememberOriginal(beam)
        if OriginalByBeam[beam] then return end
        local st = {
            Color = beam.Color,
            Texture = beam.Texture,
            Width0 = beam.Width0,
            Width1 = beam.Width1,
            LightEmission = beam.LightEmission,
            LightInfluence = beam.LightInfluence,
            Brightness = 1,
        }
        if HasBrightness then
            pcall(function() st.Brightness = beam.Brightness end)
        end
        OriginalByBeam[beam] = st
    end

    -- shot beams live under Workspace (e.g. Workspace.Part.Beam) — color only, never force glow/width
    local function isCharacterBeam(beam)
        local char = player.Character
        return char and beam:IsDescendantOf(char)
    end

    local function applyOneBeam(beam)
        if not beam or not beam.Parent then return end
        if beam.Enabled == false then return end

        rememberOriginal(beam)
        local onChar = player.Character and beam:IsDescendantOf(player.Character)

        -- COLOR every frame (game may overwrite)
        if CurrentBeamMode == ORIGINAL_KEY then
            if NeedRestoreOriginal then
                local ob = OriginalByBeam[beam]
                if ob then
                    pcall(function()
                        beam.Color = ob.Color
                        beam.Texture = ob.Texture
                    end)
                end
            end
        else
            pcall(function()
                beam.Texture = ""
                if CurrentBeamMode == "Rainbow Roll" then
                    beam.Color = GetRollSequence()
                else
                    local seq = SequenceCache[CurrentBeamMode]
                    if seq then
                        beam.Color = seq
                    end
                end
            end)
        end

        -- width/glow: character beams only (shot beams keep native fade)
        if not onChar then return end

        if not StyledWidth[beam] then
            pcall(function()
                beam.Width0 = BeamThickness
                beam.Width1 = BeamThickness
            end)
            StyledWidth[beam] = true
        end

        if NeonEnabled then
            beam.LightEmission = 1
            beam.LightInfluence = 0
            SetBrightness(beam, NEON_BRIGHTNESS)
        elseif IsGlowEnabled then
            beam.LightEmission = GlowIntensity
            beam.LightInfluence = 0
            local ob = OriginalByBeam[beam]
            SetBrightness(beam, (ob and ob.Brightness) or BaseBrightness)
        else
            -- slight emission so solid ColorSequence shows clearly
            beam.LightEmission = 0.35
            beam.LightInfluence = 0.4
            local ob = OriginalByBeam[beam]
            SetBrightness(beam, (ob and ob.Brightness) or BaseBrightness)
        end
    end

    local MainFrame = Instance.new("Frame")
    do
        local bw = fitW(isMobile and 290 or 320)
        local bh = fitH(isMobile and 400 or 440)
        MainFrame.Size = UDim2.fromOffset(bw, bh)
        MainFrame.Position = UDim2.new(0.5, -bw / 2, 0.5, -bh / 2)
    end
    MainFrame.BackgroundColor3 = UI.bg
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = beamGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)
    do
        local g = Instance.new("UIGradient", MainFrame)
        g.Rotation = 155
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 48, 38)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 34, 28)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 24, 26)),
        })
    end
    do
        local st = Instance.new("UIStroke", MainFrame)
        st.Color = Color3.fromRGB(200, 160, 70)
        st.Thickness = 2
        st.Transparency = 0.15
    end

    local TitleBar = Instance.new("Frame", MainFrame)
    TitleBar.Size = UDim2.new(1, 0, 0, 36)
    TitleBar.BackgroundTransparency = 1
    TitleBar.Active = true

    local TitleText = Instance.new("TextLabel", TitleBar)
    TitleText.Size = UDim2.new(1, -56, 1, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "Beam"
    TitleText.TextColor3 = Color3.fromRGB(240, 200, 100)
    TitleText.Font = UI.titleFont
    TitleText.TextSize = 20
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UIPadding", TitleText).PaddingLeft = UDim.new(0, 14)

    local CloseBtn = Instance.new("TextButton", TitleBar)
    CloseBtn.Size = UDim2.fromOffset(26, 26)
    CloseBtn.Position = UDim2.new(1, -30, 0, 5)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Text = "x"
    CloseBtn.TextColor3 = UI.dim
    CloseBtn.Font = UI.font
    CloseBtn.TextSize = 18
    CloseBtn.BorderSizePixel = 0

    makeDraggable(MainFrame, TitleBar)

    do
        local ln = Instance.new("Frame", MainFrame)
        ln.Size = UDim2.new(1, -24, 0, 1)
        ln.Position = UDim2.new(0, 12, 0, 36)
        ln.BackgroundColor3 = UI.line
        ln.BackgroundTransparency = 0.45
        ln.BorderSizePixel = 0
    end

    local Content = Instance.new("Frame", MainFrame)
    Content.Size = UDim2.new(1, -16, 1, -46)
    Content.Position = UDim2.new(0, 8, 0, 42)
    Content.BackgroundTransparency = 1

    local ChipBar = Instance.new("ScrollingFrame", Content)
    ChipBar.Size = UDim2.new(1, 0, 0, 24)
    ChipBar.BackgroundTransparency = 1
    ChipBar.BorderSizePixel = 0
    ChipBar.ScrollBarThickness = 0
    ChipBar.ScrollingDirection = Enum.ScrollingDirection.X
    ChipBar.AutomaticCanvasSize = Enum.AutomaticSize.X
    ChipBar.CanvasSize = UDim2.new()
    local ChipLayout = Instance.new("UIListLayout", ChipBar)
    ChipLayout.FillDirection = Enum.FillDirection.Horizontal
    ChipLayout.Padding = UDim.new(0, 4)
    ChipLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local CatScrolls, CatChips = {}, {}
    local function SelectCategory(cat)
        for c, sc in pairs(CatScrolls) do sc.Visible = (c == cat) end
        for c, chip in pairs(CatChips) do
            chip.BackgroundColor3 = (c == cat) and Color3.fromRGB(180, 45, 50) or Color3.fromRGB(40, 58, 48)
            chip.TextColor3 = (c == cat) and Color3.new(1, 1, 1) or UI.text
        end
    end

    for idx, cat in ipairs(Categories) do
        local sc = Instance.new("ScrollingFrame", Content)
        sc.Size = UDim2.new(1, 0, 0, 150)
        sc.Position = UDim2.new(0, 0, 0, 30)
        sc.BackgroundTransparency = 1
        sc.BorderSizePixel = 0
        sc.ScrollBarThickness = 3
        sc.ScrollBarImageColor3 = UI.line
        sc.CanvasSize = UDim2.new()
        sc.Visible = false
        CatScrolls[cat] = sc
        local grid = Instance.new("UIGridLayout", sc)
        grid.CellSize = UDim2.new(0.48, 0, 0, 28)
        grid.CellPadding = UDim2.fromOffset(5, 5)
        grid.SortOrder = Enum.SortOrder.LayoutOrder
        Track(grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            sc.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 6)
        end))

        local chip = Instance.new("TextButton", ChipBar)
        chip.LayoutOrder = idx
        chip.Size = UDim2.new(0, 0, 1, 0)
        chip.AutomaticSize = Enum.AutomaticSize.X
        chip.BackgroundColor3 = Color3.fromRGB(40, 58, 48)
        chip.Text = cat
        chip.TextColor3 = UI.text
        chip.Font = UI.font
        chip.TextSize = 11
        Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 8)
        local pad = Instance.new("UIPadding", chip)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 8)
        CatChips[cat] = chip
        Track(chip.MouseButton1Click:Connect(function() SelectCategory(cat) end))
    end

    local orderInCat = {}
    for _, entry in ipairs(BeamList) do
        local cat, name, colors = entry[1], entry[2], entry[3]
        orderInCat[cat] = (orderInCat[cat] or 0) + 1
        local btn = Instance.new("TextButton")
        btn.LayoutOrder = orderInCat[cat]
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextStrokeTransparency = 0.4
        btn.Font = UI.font
        btn.TextSize = 11
        btn.AutoButtonColor = true
        btn.Text = name
        btn.Parent = CatScrolls[cat]
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        if #colors > 0 then
            btn.BackgroundColor3 = Color3.new(1, 1, 1)
            local g = Instance.new("UIGradient", btn)
            g.Color = CreateSmoothSequence(colors)
        else
            btn.BackgroundColor3 = Color3.fromRGB(180, 45, 50)
            btn.Text = "★ " .. name
        end
        Track(btn.MouseButton1Click:Connect(function()
            CurrentBeamMode = name
            if name == ORIGINAL_KEY then NeedRestoreOriginal = true end
        end))
    end
    SelectCategory("ORIGINAL")

    local function StyleToggle(btn, text, on, onColor)
        btn.Text = text .. (on and ": ON" or ": OFF")
        btn.BackgroundColor3 = on and onColor or Color3.fromRGB(40, 58, 48)
    end

    NeonEnabled = false -- neon removed

    local GlowToggle = Instance.new("TextButton", Content)
    GlowToggle.Size = UDim2.new(1, 0, 0, 28)
    GlowToggle.Position = UDim2.new(0, 0, 0, 188)
    GlowToggle.TextColor3 = Color3.new(1, 1, 1)
    GlowToggle.Font = UI.font
    GlowToggle.TextSize = 12
    GlowToggle.BorderSizePixel = 0
    Instance.new("UICorner", GlowToggle).CornerRadius = UDim.new(0, 8)
    StyleToggle(GlowToggle, "GLOW", IsGlowEnabled, Color3.fromRGB(180, 45, 50))
    Track(GlowToggle.MouseButton1Click:Connect(function()
        IsGlowEnabled = not IsGlowEnabled
        StyleToggle(GlowToggle, "GLOW", IsGlowEnabled, Color3.fromRGB(180, 45, 50))
    end))

    local BrightLabel = Instance.new("TextLabel", Content)
    BrightLabel.Size = UDim2.new(1, 0, 0, 16)
    BrightLabel.Position = UDim2.new(0, 0, 0, 224)
    BrightLabel.BackgroundTransparency = 1
    BrightLabel.Text = "Brightness: 1.00"
    BrightLabel.TextColor3 = UI.text
    BrightLabel.Font = UI.font
    BrightLabel.TextSize = 12
    BrightLabel.TextXAlignment = Enum.TextXAlignment.Left

    local BrightSlider = Instance.new("TextButton", Content)
    BrightSlider.Size = UDim2.new(1, 0, 0, 16)
    BrightSlider.Position = UDim2.new(0, 0, 0, 242)
    BrightSlider.BackgroundColor3 = Color3.fromRGB(40, 58, 48)
    BrightSlider.Text = ""
    BrightSlider.AutoButtonColor = false
    BrightSlider.BorderSizePixel = 0
    Instance.new("UICorner", BrightSlider).CornerRadius = UDim.new(0, 6)
    local BrightFill = Instance.new("Frame", BrightSlider)
    BrightFill.Size = UDim2.new(1, 0, 1, 0)
    BrightFill.BackgroundColor3 = Color3.fromRGB(200, 160, 70)
    BrightFill.BorderSizePixel = 0
    Instance.new("UICorner", BrightFill).CornerRadius = UDim.new(0, 6)

    local SliderActive = false
    local function UpdateSlider(posX)
        if not SliderActive then return end
        local percent = math.clamp((posX - BrightSlider.AbsolutePosition.X) / math.max(BrightSlider.AbsoluteSize.X, 1), 0, 1)
        BrightFill.Size = UDim2.new(percent, 0, 1, 0)
        GlowIntensity = percent
        BrightLabel.Text = string.format("Brightness: %.2f", GlowIntensity)
    end
    Track(BrightSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            SliderActive = true
            UpdateSlider(input.Position.X)
        end
    end))
    Track(UserInputService.InputChanged:Connect(function(input)
        if SliderActive and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateSlider(input.Position.X)
        end
    end))
    Track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            SliderActive = false
        end
    end))

    Track(CloseBtn.MouseButton1Click:Connect(function()
        beamGui.Enabled = false
    end))

    local beamScanAcc = 0
    local CachedBeams = {}

    Track(RunService.Heartbeat:Connect(function(dt)
        if not Running or not beamGui.Parent then return end
        beamScanAcc = beamScanAcc + (dt or 0.016)
        -- rescan often so new Workspace.Part.Beam / tool beams get color immediately
        if beamScanAcc >= 0.08 or #CachedBeams == 0 then
            beamScanAcc = 0
            CachedBeams = FindAllBeams()
            CurrentBeam = CachedBeams[1]
            if CurrentBeam and HasBrightness then
                pcall(function() BaseBrightness = CurrentBeam.Brightness end)
            end
        end
        if #CachedBeams == 0 then return end

        local restoredThisFrame = false
        for _, beam in ipairs(CachedBeams) do
            if beam and beam.Parent then
                applyOneBeam(beam)
                if CurrentBeamMode == ORIGINAL_KEY then
                    restoredThisFrame = true
                end
            end
        end
        if restoredThisFrame and NeedRestoreOriginal then
            NeedRestoreOriginal = false
        end
        if NeonEnabled and CurrentBeam then
            UpdateHalo(CurrentBeam)
        end
    end))
end

-- ===== ADVANCED BUTTONS (always unlocked — key removed) =====
UI.separator(scroll, 10.02)
UI.header(scroll, 10.03, "advanced")

local gearBtn = UI.action(scroll, 10.05, "Gear", function()
    gearGui.Enabled = not gearGui.Enabled
    pcall(function() gearFrame.Modal = false end)
end)

local beamBtn = UI.action(scroll, 10.06, "Beam", function()
    beamGui.Enabled = not beamGui.Enabled
end)

end
CNP_GearSection()

-- =====================================================================
-- CHARACTER HOOK
-- =====================================================================
local function onCharacterAdded(char)
    climbLaunched = false
    speedSetupCharacter(char)
    setupGunSystem(char)
    task.defer(function()
        local bag = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
        if bag then bp = bag end
    end)
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

print("cnp v57 up — @sabrine")
