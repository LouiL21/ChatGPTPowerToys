--!strict
--[[
	Remotes
	Single source of truth for the RemoteEvent / RemoteFunction surface. The
	server creates the instances; the client waits for them. Handlers are wired
	in the server services and client controllers — this module only owns the
	transport objects so names never drift between the two sides.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

-- Client -> Server (RemoteEvents the client fires)
Remotes.ClientEvents = {
	"Fuse", -- summon at the Altar
	"ChamberFuse", -- combine two owned beasts in the Fusion Chamber
	"SetPet", -- choose the beast that follows you / fights
	"FightBoss",
	"ChallengePlayer",
	"RespondDuel",
	"UpgradeAltar",
	"SetDisplay",
	"ClaimDaily",
	"ClaimQuest",
	"Ascend",
	"Collect",
	"RequestTrade",
	"RespondTrade",
	"VisitPlayer",
	"PromptPurchase", -- client asks server to prompt a product/gamepass purchase
}

-- Server -> Client (RemoteEvents the server fires)
Remotes.ServerEvents = {
	"StateUpdate", -- authoritative (partial or full) player-state replication
	"Notify", -- transient toast/message
	"FusionResult", -- result of a fusion (for animation + discovery popup)
	"OpenFusion", -- player activated the Altar; client opens the summon panel
	"OpenChamber", -- player activated the Fusion Chamber
	"BattleEvent", -- streamed turn-by-turn battle updates
	"DuelChallenge", -- someone challenged you to a duel
}

-- RemoteFunctions (request/response). Kept minimal — mutations go through events.
Remotes.Functions = {
	"GetState", -- initial full-state pull on join
	"GetRecipeHint", -- optional flavor lookup for an element combo
}

local FOLDER_NAME = "FaBRemotes"

local function buildServer(): Folder
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if folder then
		return folder :: Folder
	end
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	local function make(className: string, containerName: string, nameLists: { { string } })
		local container = Instance.new("Folder")
		container.Name = containerName
		container.Parent = folder
		for _, names in ipairs(nameLists) do
			for _, name in ipairs(names) do
				local remote = Instance.new(className)
				remote.Name = name
				remote.Parent = container
			end
		end
	end

	-- All RemoteEvents share ONE container named "RemoteEvent" (names are unique
	-- across both direction lists).
	make("RemoteEvent", "RemoteEvent", { Remotes.ClientEvents, Remotes.ServerEvents })
	make("RemoteFunction", "RemoteFunction", { Remotes.Functions })

	folder.Parent = ReplicatedStorage
	return folder :: Folder
end

local _folder: Folder? = nil
local function getFolder(): Folder
	if _folder then
		return _folder
	end
	if RunService:IsServer() then
		_folder = buildServer()
	else
		_folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Folder
		if not _folder then
			error("[FaB] Remotes folder never replicated to client")
		end
	end
	return _folder
end

function Remotes.event(name: string): RemoteEvent
	local folder = getFolder()
	local container = folder:WaitForChild("RemoteEvent") :: Folder
	return container:WaitForChild(name, 30) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	local folder = getFolder()
	local container = folder:WaitForChild("RemoteFunction") :: Folder
	return container:WaitForChild(name) :: RemoteFunction
end

return Remotes
