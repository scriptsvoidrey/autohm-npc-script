local player = game.Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
-- Compatibilidad: si el executor no tiene la librería task (Lua 5.1), la recrea
if not task then
	local _u = table.unpack or unpack
	task = {
		spawn = function(f, ...) local a = {...}; spawn(function() f(_u(a)) end) end,
		wait = function(t) return wait(t or 0) end,
		defer = function(f, ...) local a = {...}; spawn(function() f(_u(a)) end) end,
		delay = function(t, f) delay(t, f) end,
	}
end

-- ====== CONFIGURACIÓN ======
local TOGGLE_KEY         = Enum.KeyCode.Q   -- Activar/desactivar rápido
local ADD_ALLY_KEY       = Enum.KeyCode.F   -- Marcar personaje más cercano como ALIADO (jugador o NPC)
local CLEAR_ALLY_KEY     = Enum.KeyCode.G   -- Limpiar lista de aliados manuales
local STOP_DISTANCE      = 3.5
local LAST_POS_TIMEOUT   = 2.0              -- aumentado: persigue última posición más tiempo
local STUCK_CHECK_TIME   = 1.1
local STUCK_PAUSE_TIME   = 1.3
local AUTO_JUMP_ON_STUCK = true

-- === NPCs / Bots (detección mejorada) ===
local INCLUDE_NPCS          = true   -- Atacar también NPCs/bots del Workspace
local NPC_ALLY_BY_TEAM      = true   -- Si un NPC comparte tu equipo/atributo, no lo ataca
local NPC_FULL_SCAN_INTERVAL= 2.0    -- Escaneo completo de seguridad cada X seg (los eventos detectan al instante)
local IGNORE_ANCHORED_NPCS  = true   -- Ignora NPCs anclados (estatuas/maniquíes/decoración)
local RESPECT_FRIENDLY_ATTR = true   -- Si el NPC tiene atributo Friendly=true o Hostile=false, es aliado
local TARGET_STICKINESS     = 0.75   -- No cambia de objetivo a menos que el nuevo esté 25% más cerca
-- Tags comunes de CollectionService que usan los juegos para marcar enemigos
local NPC_TAGS = {"Enemy","NPC","Bot","Zombie","Mob","Hostile","Target","Kill","AI","Monster","EnemyCharacter","Npc","Enemigo"}
-- Nombres de NPC que se ignoran completamente (minúsculas, coincidencia parcial)
local NPC_IGNORE_KEYWORDS = {"dummy","maniqui","practice","testdummy","decor","display","targetdummy","prop"}
-- =========================

local GUI_NAME = "AutoHM_MainGUI"
local playerGui = player:WaitForChild("PlayerGui")

-- Limpia GUI vieja al re-ejecutar
for _, child in ipairs(playerGui:GetChildren()) do
	if child:IsA("ScreenGui") then
		local isOld = child.Name == GUI_NAME or child:GetAttribute("AutoHMScript")
		if not isOld then
			local fr = child:FindFirstChildOfClass("Frame")
			if fr then
				local title = fr:FindFirstChildOfClass("TextLabel")
				if title and title.Text == "⚡ Auto HM" then isOld = true end
			end
		end
		if isOld then child:Destroy() end
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui:SetAttribute("AutoHMScript", true)
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 170, 0, 102)
frame.Position = UDim2.new(0, 40, 0, 40)
frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local frameStroke = Instance.new("UIStroke", frame)
frameStroke.Thickness = 1.5
frameStroke.Color = Color3.fromRGB(45, 50, 70)

local titleBar = Instance.new("TextLabel")
titleBar.Size = UDim2.new(1, -90, 0, 24)
titleBar.Position = UDim2.new(0, 8, 0, 6)
titleBar.BackgroundTransparency = 1
titleBar.Text = "⚡ Auto HM"
titleBar.TextColor3 = Color3.fromRGB(240, 240, 255)
titleBar.TextSize = 13
titleBar.Font = Enum.Font.GothamBold
titleBar.TextXAlignment = Enum.TextXAlignment.Left
titleBar.Parent = frame

-- Botones: Candado / Minimizar / Cerrar
local topButtonsFrame = Instance.new("Frame")
topButtonsFrame.Size = UDim2.new(0, 78, 0, 20)
topButtonsFrame.Position = UDim2.new(1, -82, 0, 8)
topButtonsFrame.BackgroundTransparency = 1
topButtonsFrame.ZIndex = 5
topButtonsFrame.Parent = frame

local lockBtn = Instance.new("TextButton")
lockBtn.Size = UDim2.new(0, 22, 0, 20)
lockBtn.Position = UDim2.new(0, 0, 0, 0)
lockBtn.BackgroundColor3 = Color3.fromRGB(55, 60, 80)
lockBtn.Text = "🔓"
lockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
lockBtn.TextSize = 12
lockBtn.Font = Enum.Font.GothamBold
lockBtn.BorderSizePixel = 0
lockBtn.ZIndex = 6
lockBtn.Parent = topButtonsFrame
Instance.new("UICorner", lockBtn).CornerRadius = UDim.new(0, 6)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 22, 0, 20)
minBtn.Position = UDim2.new(0, 26, 0, 0)
minBtn.BackgroundColor3 = Color3.fromRGB(55, 60, 80)
minBtn.Text = "+"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.TextSize = 14
minBtn.Font = Enum.Font.GothamBold
minBtn.BorderSizePixel = 0
minBtn.ZIndex = 6
minBtn.Parent = topButtonsFrame
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 20)
closeBtn.Position = UDim2.new(0, 52, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(210, 45, 65)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 12
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 6
closeBtn.Parent = topButtonsFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -16, 0, 34)
button.Position = UDim2.new(0, 8, 0, 34)
button.BackgroundColor3 = Color3.fromRGB(210, 45, 65)
button.Text = "Activar"
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.TextSize = 14
button.Font = Enum.Font.GothamBold
button.BorderSizePixel = 0
button.Parent = frame
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

local btnGrad = Instance.new("UIGradient", button)
btnGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 60, 85)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 25, 45)),
})
btnGrad.Rotation = 90

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 18)
statusLabel.Position = UDim2.new(0, 8, 0, 74)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "OFF"
statusLabel.TextColor3 = Color3.fromRGB(140, 145, 170)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.Parent = frame

-- Arrastre con candado
local locked = false
local dragging, dragStart, startPos

frame.InputBegan:Connect(function(input)
	if locked then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

lockBtn.MouseButton1Click:Connect(function()
	locked = not locked
	if locked then
		lockBtn.Text = "🔒"
		TweenService:Create(lockBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(230, 170, 40)}):Play()
		TweenService:Create(frameStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(230, 170, 40)}):Play()
	else
		lockBtn.Text = "🔓"
		TweenService:Create(lockBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(55, 60, 80)}):Play()
		TweenService:Create(frameStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(45, 50, 70)}):Play()
	end
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		minBtn.Text = "-"
		TweenService:Create(frame, TweenInfo.new(0.2), {Size = UDim2.new(0, 170, 0, 36)}):Play()
		button.Visible = false
		statusLabel.Visible = false
	else
		minBtn.Text = "+"
		TweenService:Create(frame, TweenInfo.new(0.2), {Size = UDim2.new(0, 170, 0, 102)}):Play()
		button.Visible = true
		statusLabel.Visible = true
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

-- ====== Estado interno ======
local enabled = false
local currentTarget = nil
local lastKnownPos = nil
local lastKnownTime = 0
local stuckUntil = 0
local stuckCheckPos = nil
local stuckCheckTime = 0
local allyCount = 0
local npcAliveCount = 0
local serverHasTeams = false
local ignoreList = {}   -- [userId] = true, aliados manuales (jugadores, tecla F)
local allyNpcs = {}     -- [model] = true, aliados manuales (NPCs, tecla F)
-- Cache de NPCs como mapa [model] = {model, humanoid, root} para añadir/quitar al instante
local npcCache = {}
local lastFullNpcScan = 0

local movementKeys = {
	[Enum.KeyCode.W] = false, [Enum.KeyCode.A] = false,
	[Enum.KeyCode.S] = false, [Enum.KeyCode.D] = false,
	[Enum.KeyCode.Up] = false, [Enum.KeyCode.Down] = false,
	[Enum.KeyCode.Left] = false, [Enum.KeyCode.Right] = false,
}

local function isMovingManually()
	for _, held in pairs(movementKeys) do
		if held then return true end
	end
	return false
end

local function setStatus(text, color)
	statusLabel.Text = text
	statusLabel.TextColor3 = color or Color3.fromRGB(140, 145, 170)
end

local function setEnabled(state)
	enabled = state
	if enabled then
		button.Text = "Desactivar"
		setStatus("Buscando...", Color3.fromRGB(255, 200, 80))
		TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 180, 90)}):Play()
		btnGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 210, 105)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 110, 50)),
		})
	else
		button.Text = "Activar"
		setStatus("OFF", Color3.fromRGB(140, 145, 170))
		lastKnownPos = nil
		stuckUntil = 0
		currentTarget = nil
		TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(210, 45, 65)}):Play()
		btnGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 60, 85)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 25, 45)),
		})
	end
end

button.MouseButton1Click:Connect(function()
	setEnabled(not enabled)
end)

-- ============================================================
-- ====== DETECCIÓN DE NPCs / BOTS (mejorada) ======
-- ============================================================
local function isNpcNameIgnored(npcName)
	local lower = npcName:lower()
	for _, kw in ipairs(NPC_IGNORE_KEYWORDS) do
		if lower:find(kw, 1, true) then return true end
	end
	return false
end

-- Intenta añadir un modelo a la cache de NPCs si cumple los requisitos
local function addNpcToCache(model)
	if not model or not model:IsA("Model") then return end
	if model == player.Character then return end
	if npcCache[model] then return end -- ya está
	if Players:GetPlayerFromCharacter(model) then return end -- es un jugador real
	if isNpcNameIgnored(model.Name) then return end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not hum or not root then return end
	if IGNORE_ANCHORED_NPCS and root.Anchored then return end -- estatua/decoración
	npcCache[model] = {model = model, humanoid = hum, root = root}
end

local function removeNpcFromCache(model)
	if model then npcCache[model] = nil end
end

-- Escaneo completo (de seguridad, cada pocos segundos) + tags de CollectionService
local function fullNpcScan()
	-- no limpiamos del todo para no perder los que añadieron los eventos;
	-- marcamos y luego borramos los que ya no existen
	local seen = {}
	local function scan(parent, depth)
		if depth > 8 then return end
		for _, obj in ipairs(parent:GetChildren()) do
			if obj:IsA("Model") then
				local hum = obj:FindFirstChildOfClass("Humanoid")
				local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
				if hum and root then
					if obj ~= player.Character and not Players:GetPlayerFromCharacter(obj) and not isNpcNameIgnored(obj.Name) then
						if not (IGNORE_ANCHORED_NPCS and root.Anchored) then
							seen[obj] = true
							npcCache[obj] = {model = obj, humanoid = hum, root = root}
						end
					end
				else
					scan(obj, depth + 1)
				end
			elseif obj:IsA("Folder") or obj:IsA("Configuration") then
				scan(obj, depth + 1)
			end
		end
	end
	pcall(function() scan(Workspace, 0) end)

	-- Tags de CollectionService (muchos juegos marcan enemigos así)
	for _, tag in ipairs(NPC_TAGS) do
		local ok, tagged = pcall(function() return CollectionService:GetTagged(tag) end)
		if ok and tagged then
			for _, inst in ipairs(tagged) do
				local model = inst
				if not model:IsA("Model") then
					model = inst:FindFirstAncestorOfClass("Model") or inst.Parent
				end
				if model and model:IsA("Model") then
					local hum = model:FindFirstChildOfClass("Humanoid")
					local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
					if hum and root and model ~= player.Character and not Players:GetPlayerFromCharacter(model) then
						if not (IGNORE_ANCHORED_NPCS and root.Anchored) and not isNpcNameIgnored(model.Name) then
							seen[model] = true
							npcCache[model] = {model = model, humanoid = hum, root = root}
						end
					end
				end
			end
		end
	end

	-- Borrar de la cache los que ya no existen o no tienen raíz
	for model, entry in pairs(npcCache) do
		if not seen[model] then
			if not model.Parent or not entry.root.Parent or not entry.humanoid.Parent then
				npcCache[model] = nil
			end
		end
	end
end

-- Detección INSTANTÁNEA por eventos (no espera al escaneo periódico)
Workspace.DescendantAdded:Connect(function(inst)
	if not INCLUDE_NPCS then return end
	-- Un NPC aparece cuando se crea su Humanoid o su HumanoidRootPart
	if inst:IsA("Humanoid") or (inst:IsA("BasePart") and inst.Name == "HumanoidRootPart") then
		local model = inst.Parent
		if model and model:IsA("Model") then
			task.defer(addNpcToCache, model)
		end
	end
end)

Workspace.DescendantRemoving:Connect(function(inst)
	if not INCLUDE_NPCS then return end
	if npcCache[inst] then
		npcCache[inst] = nil
	elseif inst:IsA("Model") then
		removeNpcFromCache(inst)
	elseif inst:IsA("Humanoid") or inst.Name == "HumanoidRootPart" then
		removeNpcFromCache(inst.Parent)
	end
end)
-- ============================================================

-- Teclas: movimiento / toggle Q / añadir aliado F / limpiar aliados G
UIS.InputBegan:Connect(function(input, gpe)
	if movementKeys[input.KeyCode] ~= nil then
		movementKeys[input.KeyCode] = true
	elseif not gpe then
		if input.KeyCode == TOGGLE_KEY then
			setEnabled(not enabled)
		elseif input.KeyCode == ADD_ALLY_KEY then
			local char = player.Character
			if char and char.PrimaryPart then
				local myPos = char.PrimaryPart.Position
				local closestDist = 35
				local closestName = ""
				local closestIsPlayer = false
				local closestPlayer = nil
				local closestNpcModel = nil

				-- 1. Jugadores reales
				for _, v in ipairs(Players:GetPlayers()) do
					if v ~= player and v.Character and v.Character.PrimaryPart then
						local d = (myPos - v.Character.PrimaryPart.Position).Magnitude
						if d < closestDist then
							closestDist = d
							closestIsPlayer = true
							closestPlayer = v
							closestNpcModel = nil
							closestName = v.Name
						end
					end
				end

				-- 2. NPCs / bots del Workspace
				if INCLUDE_NPCS then
					for _, n in pairs(npcCache) do
						if n.root.Parent and n.humanoid and n.humanoid.Health > 0 and not allyNpcs[n.model] then
							local d = (myPos - n.root.Position).Magnitude
							if d < closestDist then
								closestDist = d
								closestIsPlayer = false
								closestPlayer = nil
								closestNpcModel = n.model
								closestName = n.model.Name
							end
						end
					end
				end

				if closestName ~= "" then
					if closestIsPlayer then
						ignoreList[closestPlayer.UserId] = true
					elseif closestNpcModel then
						allyNpcs[closestNpcModel] = true
					end
					setStatus("Aliado: " .. closestName, Color3.fromRGB(120, 180, 255))
					task.delay(2, function() if enabled and gui.Parent then setStatus("Buscando...", Color3.fromRGB(255, 200, 80)) end end)
				else
					setStatus("No hay personaje cerca", Color3.fromRGB(255, 120, 120))
					task.delay(2, function() if enabled and gui.Parent then setStatus("Buscando...", Color3.fromRGB(255, 200, 80)) end end)
				end
			end
		elseif input.KeyCode == CLEAR_ALLY_KEY then
			ignoreList = {}
			allyNpcs = {}
			setStatus("Aliados manuales limpios", Color3.fromRGB(255, 200, 80))
			task.delay(2, function() if enabled and gui.Parent then setStatus("Buscando...", Color3.fromRGB(255, 200, 80)) end end)
		end
	end
end)

UIS.InputEnded:Connect(function(input)
	if movementKeys[input.KeyCode] ~= nil then
		movementKeys[input.KeyCode] = false
	end
end)

local function hasBombEquipped()
	local char = player.Character
	if not char then return false end
	for _, item in ipairs(char:GetChildren()) do
		if item:IsA("Tool") then
			local nameLower = item.Name:lower()
			if nameLower:find("bomb") or nameLower:find("time") or nameLower:find("bomba") then
				return true
			end
		end
	end
	return false
end

-- ============================================================
-- ====== ANTI-TEAM ======
-- ============================================================
local teamKeywords = {"team", "faction", "squad", "crew", "gang", "side", "teamid", "group", "rank", "job", "role", "alliance", "company", "teamname", "clan", "party", "platoon", "force", "unit", "color", "band", "house"}

local function collectTeamIds(instance, ids)
	if not instance then return end
	for _, name in ipairs(teamKeywords) do
		local ok, val = pcall(function() return instance:GetAttribute(name) end)
		if ok and val ~= nil then
			ids[tostring(val)] = true
		end
	end
	local foldersToCheck = {instance}
	for _, fname in ipairs({"leaderstats", "Data", "PlayerData", "Stats", "GameData", "Values", "Folder"}) do
		local f = instance:FindFirstChild(fname)
		if f and f:IsA("Folder") then table.insert(foldersToCheck, f) end
	end
	for _, f in ipairs(foldersToCheck) do
		for _, obj in ipairs(f:GetChildren()) do
			if obj:IsA("ValueBase") then
				local lowerName = obj.Name:lower()
				for _, kw in ipairs(teamKeywords) do
					if lowerName == kw or lowerName:find(kw, 1, true) then
						ids[tostring(obj.Value)] = true
						break
					end
				end
			end
		end
	end
end

local function isTeammate(otherPlayer)
	if otherPlayer == player then return true end
	if ignoreList[otherPlayer.UserId] then return true end
	if player.Team and otherPlayer.Team and player.Team == otherPlayer.Team then
		return true
	end
	if serverHasTeams and player.TeamColor == otherPlayer.TeamColor
		and not player.Neutral and not otherPlayer.Neutral then
		return true
	end
	local myIds, theirIds = {}, {}
	collectTeamIds(player, myIds)
	collectTeamIds(otherPlayer, theirIds)
	collectTeamIds(player.Character, myIds)
	collectTeamIds(otherPlayer.Character, theirIds)
	for id in pairs(myIds) do
		if theirIds[id] then return true end
	end
	return false
end

-- Comprueba atributos Friendly/Hostile en el NPC (modelo, raíz o humanoid)
local function hasFriendlyAttribute(npcEntry)
	local function check(inst)
		if not inst then return false end
		local ok1, f = pcall(function() return inst:GetAttribute("Friendly") end)
		if ok1 and f == true then return true end
		local ok2, h = pcall(function() return inst:GetAttribute("Hostile") end)
		if ok2 and h == false then return true end
		return false
	end
	return check(npcEntry.model) or check(npcEntry.root) or check(npcEntry.humanoid)
end

local function isNpcAlly(npcEntry, myTeamIds)
	if allyNpcs[npcEntry.model] then return true end
	if RESPECT_FRIENDLY_ATTR and hasFriendlyAttribute(npcEntry) then return true end
	if not NPC_ALLY_BY_TEAM or not myTeamIds then return false end
	local npcIds = {}
	collectTeamIds(npcEntry.model, npcIds)
	collectTeamIds(npcEntry.root, npcIds)
	for id in pairs(myTeamIds) do
		if npcIds[id] then return true end
	end
	return false
end
-- ============================================================

local function hasLineOfSight(fromPos, toPos, characterToIgnore)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {player.Character, characterToIgnore}
	raycastParams.IgnoreWater = true
	local result = Workspace:Raycast(fromPos, toPos - fromPos, raycastParams)
	if result and not result.Instance:IsDescendantOf(characterToIgnore) then
		return false
	end
	return true
end

-- Búsqueda de objetivos (jugadores + NPCs)
task.spawn(function()
	while gui.Parent do
		task.wait(0.04)
		repeat
		if not enabled or not hasBombEquipped() then
			currentTarget = nil
			break
		end

		local char = player.Character
		if not char then break end
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then break end

		-- Equipos reales?
		local colors = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if not p.Neutral then colors[tostring(p.TeamColor)] = true end
		end
		local distinct = 0
		for _ in pairs(colors) do distinct = distinct + 1 end
		serverHasTeams = (distinct >= 2)

		-- Escaneo completo de seguridad periódico
		if INCLUDE_NPCS and (tick() - lastFullNpcScan) >= NPC_FULL_SCAN_INTERVAL then
			lastFullNpcScan = tick()
			fullNpcScan()
		end

		local myTeamIds = {}
		collectTeamIds(player, myTeamIds)
		collectTeamIds(player.Character, myTeamIds)

		local myPos = root.Position
		local maxRange = 220
		local allies = 0
		local aliveNpcs = 0
		local candidates = {}

		-- 1. Jugadores reales
		for _, v in ipairs(Players:GetPlayers()) do
			if isTeammate(v) then
				if v ~= player then allies = allies + 1 end
			elseif v.Character then
				local tr = v.Character:FindFirstChild("HumanoidRootPart")
				local hum = v.Character:FindFirstChild("Humanoid")
				if tr and hum and hum.Health > 0 then
					table.insert(candidates, {root = tr, model = v.Character})
				end
			end
		end

		-- 2. NPCs / bots
		if INCLUDE_NPCS then
			for _, n in pairs(npcCache) do
				if n.root.Parent and n.humanoid and n.humanoid.Health > 0 then
					aliveNpcs = aliveNpcs + 1
					if isNpcAlly(n, myTeamIds) then
						allies = allies + 1
					else
						table.insert(candidates, {root = n.root, model = n.model})
					end
				else
					-- limpiar muertos/destruidos
					npcCache[n.model] = nil
				end
			end
		end
		npcAliveCount = aliveNpcs

		-- Elegir el más cercano válido
		local bestTarget, bestDist = nil, math.huge
		for _, c in ipairs(candidates) do
			local tr = c.root
			local heightDiff = tr.Position.Y - myPos.Y
			if heightDiff > -12 and heightDiff < 22 then
				local dist = (myPos - tr.Position).Magnitude
				if dist <= maxRange and hasLineOfSight(myPos + Vector3.new(0, 2, 0), tr.Position + Vector3.new(0, 2, 0), c.model) then
					if dist < bestDist then
						bestDist, bestTarget = dist, tr
					end
				end
			end
		end

		-- "Stickiness": si el objetivo actual sigue siendo válido, no cambiar a menos que
		-- el nuevo esté notablemente más cerca (evita saltos de objetivo constantes)
		if currentTarget and currentTarget.Parent then
			local cHum = currentTarget.Parent:FindFirstChildOfClass("Humanoid")
			if cHum and cHum.Health > 0 then
				local cDist = (myPos - currentTarget.Position).Magnitude
				local heightDiff = currentTarget.Position.Y - myPos.Y
				if heightDiff > -12 and heightDiff < 22 and cDist <= maxRange
					and hasLineOfSight(myPos + Vector3.new(0, 2, 0), currentTarget.Position + Vector3.new(0, 2, 0), currentTarget.Parent) then
					if bestTarget == nil or bestDist >= cDist * TARGET_STICKINESS then
						bestTarget = currentTarget
						bestDist = cDist
					end
				end
			end
		end

		allyCount = allies
		currentTarget = bestTarget
		if bestTarget then
			lastKnownPos = bestTarget.Position
			lastKnownTime = tick()
		end
		until true
	end
end)

-- Movimiento
RunService.RenderStepped:Connect(function()
	if not gui.Parent or not enabled or not hasBombEquipped() then return end

	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChild("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end

	if isMovingManually() then
		stuckCheckPos = nil
		setStatus("Control manual", Color3.fromRGB(120, 180, 255))
		return
	end

	if tick() < stuckUntil then
		setStatus("Atascado — maniobra tú", Color3.fromRGB(255, 140, 60))
		return
	end

	local moveTarget = nil

	if currentTarget and currentTarget.Parent then
		local targetHum = currentTarget.Parent:FindFirstChildOfClass("Humanoid")
		if targetHum and targetHum.Health > 0 then
			local targetPos = currentTarget.Position
			local heightDiff = root.Position.Y - targetPos.Y
			if heightDiff > -15 and heightDiff < 22 then
				moveTarget = targetPos
				lastKnownPos = targetPos
				lastKnownTime = tick()
			else
				currentTarget = nil
			end
		else
			currentTarget = nil
		end
	end

	if not moveTarget and lastKnownPos and (tick() - lastKnownTime) < LAST_POS_TIMEOUT then
		moveTarget = lastKnownPos
	end

	if moveTarget then
		local dist = (root.Position - moveTarget).Magnitude
		if dist <= STOP_DISTANCE then
			hum:MoveTo(root.Position)
			stuckCheckPos = nil
			setStatus("Sobre el objetivo ✓", Color3.fromRGB(80, 230, 130))
			return
		end

		hum:MoveTo(moveTarget)
		setStatus("Persiguiendo... | Aliados: " .. allyCount .. " | NPCs: " .. npcAliveCount, Color3.fromRGB(80, 230, 130))

		local now = tick()
		if not stuckCheckPos then
			stuckCheckPos, stuckCheckTime = root.Position, now
		elseif (now - stuckCheckTime) >= STUCK_CHECK_TIME then
			if (root.Position - stuckCheckPos).Magnitude < 2 then
				stuckUntil = now + STUCK_PAUSE_TIME
				if AUTO_JUMP_ON_STUCK and hum.FloorMaterial ~= Enum.Material.Air then hum.Jump = true end
			end
			stuckCheckPos, stuckCheckTime = root.Position, now
		end
	else
		stuckCheckPos = nil
		setStatus("Buscando... | Aliados: " .. allyCount .. " | NPCs: " .. npcAliveCount, Color3.fromRGB(255, 200, 80))
	end
end)
