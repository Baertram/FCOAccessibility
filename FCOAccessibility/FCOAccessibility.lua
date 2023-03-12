------------------------------------------------------------------
--FCOAccessibility.lua
--Author: Baertram
------------------------------------------------------------------

--Global addon variable
FCOAB = {}
local FCOAB = FCOAB


local myDisplayName = GetDisplayName()

--local lua and game functions
local tos = tostring
local tins = table.insert
local tsort = table.sort
local strfor = string.format

local atan2 = math.atan2
local ROTATION_OFFSET = 3 * ZO_HALF_PI


--Local game global speed up variables
local CM = CALLBACK_MANAGER
local EM = EVENT_MANAGER
local soundsRef = SOUNDS

--local game functions
local iigpm = IsInGamepadPreferredMode
local gmpw = GetMapPlayerWaypoint
local gmrp = GetMapRallyPoint

local CON_NONE       = "NONE"
local CON_SOUND_NONE = soundsRef[CON_NONE]

local CON_PLAYER = "player"
local CON_RETICLE = "reticleover"
local CON_COMPANION = "companion"

local CON_CRITTER_MAX_HEALTH = 1


--Addon variables
FCOAB.addonVars                            = {}
FCOAB.addonVars.gAddonName                 = "FCOAccessibility"
FCOAB.addonVars.addonNameMenu              = "FCO Accessibility"
FCOAB.addonVars.addonNameMenuDisplay       = "|c00FF00FCO |cFFFF00Accessibility|r"
FCOAB.addonVars.addonAuthor                = '|cFFFF00Baertram|r'
FCOAB.addonVars.addonVersionOptions        = '0.02' -- version shown in the settings panel
FCOAB.addonVars.addonSavedVariablesName    = "FCOAccessibility_Settings"
FCOAB.addonVars.addonSavedVariablesVersion = 0.02 -- Changing this will reset SavedVariables!
FCOAB.addonVars.gAddonLoaded               = false
local addonVars                            = FCOAB.addonVars
local addonName                            = addonVars.gAddonName

--Libraries
-- Create the addon settings menu
local LAM = LibAddonMenu2
local FCOABSettingsPrefixStr = addonName .. " setting %q changed to: "

local GPS = LibGPS3

--Original variables

--Control names of ZO* standard controls etc.
FCOAB.zosVars                              = {}
local zosVars = FCOAB.zosVars
zosVars.compass = COMPASS
local compass = zosVars.compass
zosVars.compassCenterOverPinLabel = compass.centerOverPinLabel
local compassCenterOverPinLabel = zosVars.compassCenterOverPinLabel


--Settings
FCOAB.settingsVars					= {}
FCOAB.settingsVars.settings 		= {}
FCOAB.settingsVars.defaultSettings	= {}

--Prevention booleans
FCOAB.preventerVars = {}

--Constants
local soundNames = {}
local soundNamesInternal = {}
for soundName, _ in pairs(soundsRef) do
    if soundName ~= CON_NONE then
        tins(soundNames, soundName)
    end
end
tsort(soundNames)
if #soundNames <= 0 then
    d("[".. FCOAB.addonVars.addonNameMenuDisplay .. "] ERROR No sounds could be found - AddOn won't work properly!")
    return
end
--Insert "NONE" as first sound
tins(soundNames, 1, CON_NONE)
--Build the lookup table of the internal soundNames to the sound KEY value
for soundIndex, soundName in ipairs(soundNames) do
	soundNamesInternal[soundsRef[soundName]] = soundName
end

local playerWaypointPinTypes = {
	[MAP_PIN_TYPE_PLAYER_WAYPOINT] = true,
}
local trackedQuestPinTypes = {
	[MAP_PIN_TYPE_TRACKED_QUEST_CONDITION] = true, --19
	[MAP_PIN_TYPE_TRACKED_QUEST_ENDING]= true, --21
	[MAP_PIN_TYPE_TRACKED_QUEST_OFFER_ZONE_STORY] = true, --37
	[MAP_PIN_TYPE_TRACKED_QUEST_OPTIONAL_CONDITION] = true, --20
	[MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_CONDITION] = true, --22
	[MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_ENDING] = true, --24
	[MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_OPTIONAL_CONDITION] = true, --23
	[MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_CONDITION] = true, --25
	[MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_ENDING] = true, --27
	[MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_OPTIONAL_CONDITION] = true, --26
}
local assistedQuestPinTypes  = {
	[MAP_PIN_TYPE_ASSISTED_QUEST_CONDITION] = true, --10
	[MAP_PIN_TYPE_ASSISTED_QUEST_ENDING] = true, --12
	[MAP_PIN_TYPE_ASSISTED_QUEST_OPTIONAL_CONDITION] = true, --11
	[MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_CONDITION] = true, --13
	[MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_ENDING] = true, --15
	[MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_OPTIONAL_CONDITION] = true, --14
	[MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_CONDITION] = true, --16
	[MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_ENDING] = true, --18
	[MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_OPTIONAL_CONDITION] = true, --17
}
local companionPinTypes = {
	[MAP_PIN_TYPE_ACTIVE_COMPANION] = true,
}
local groupPinTypes = {
	[MAP_PIN_TYPE_GROUP] = true
}
local groupLeaderPinTypes = {
	[MAP_PIN_TYPE_GROUP_LEADER] = true
}
local rallyPointPinTypes = {
	[MAP_PIN_TYPE_RALLY_POINT] = true
}
local mapPinTypeToCompassText = {
	[MAP_PIN_TYPE_QUEST_COMPLETE] = "Quest complete",
	[MAP_PIN_TYPE_QUEST_CONDITION] = "Quest condition",
	[MAP_PIN_TYPE_QUEST_ENDING] = "Quest ending",
	--[MAP_PIN_TYPE_QUEST_GIVE_ITEM] = "Quest item",
	[MAP_PIN_TYPE_QUEST_INTERACT] = "Quest interact",
	[MAP_PIN_TYPE_QUEST_OFFER] = "Quest offer",
	[MAP_PIN_TYPE_QUEST_OFFER_REPEATABLE] = "Quest offer repeatable",
	[MAP_PIN_TYPE_QUEST_OFFER_ZONE_STORY] = "Quest offer zone story",
	[MAP_PIN_TYPE_QUEST_OPTIONAL_CONDITION] = "Optional quest condition",
	[MAP_PIN_TYPE_QUEST_ZONE_STORY_CONDITION] = "Quest zone story condition",
	[MAP_PIN_TYPE_QUEST_ZONE_STORY_ENDING] = "Quest zone story ending",
	[MAP_PIN_TYPE_QUEST_ZONE_STORY_OPTIONAL_CONDITION] = "Quest zone story optional condition",
	[MAP_PIN_TYPE_QUEST_TALK_TO] = "Quest talk to",
}



local autoRemoveWaypointEventName = addonName .. "_AutoRemoveWaypoint"
local groupLeaderPosEventName = addonName .. "_GroupLeaderPos"

--Sring comparison variables
--[[
SafeAddString(SI_TOOLTIP_UNIT_MAP_PING, "Kartensignal: <<C:1>>", 0)
SafeAddString(SI_TOOLTIP_UNIT_MAP_PLAYER_WAYPOINT, "Euer gesetztes Ziel", 0)
SafeAddString(SI_TOOLTIP_UNIT_MAP_RALLY_POINT, "Gruppentreffpunkt", 0)
]]
local compassbaseStr = "Compass"
local yourPlayersWaypointStr = GetString(SI_TOOLTIP_UNIT_MAP_PLAYER_WAYPOINT) -- Player waypoint text at the compass
local rallyPointStr = GetString(SI_TOOLTIP_UNIT_MAP_RALLY_POINT) --Group rally point
local groupStr = GetString(SI_PLAYERS_MET_TITLE_GROUP) -- Group
local groupLeaderStr = GetString(SI_GROUP_LEADER_TOOLTIP) --Group leader
local companionStr = GetString(SI_UNIT_FRAME_NAME_COMPANION)

--Variables for the compass checks
--local lastCompassCenterOverPinLabeltext
local noCompassPinSelected = true
local lastTrackedQuestIndex, lastTrackedQuestName, lastTrackedQuestBackgroundText, lastTrackedQuestActiveStepText
local lastPlayed = {
	--Sounds
	waypoint = 0,
	rallyPoint = 0,
	quest = 0,
	groupLeader = 0,

	--Chat
	compass2Chat = 0,
	reticle2Chat = 0,
	reticleInteraction2Chat = 0,
}

local lastAddedToChat
local compassToChatDelay = 250

local lastAddedReticleToChat = {
	name = nil,
	caption = nil,
}
local lastAddedInteractionReticleToChat = {
	action = nil,
	interactableName = nil,
	interactionBlocked = nil,
	isOwned = nil,
	additionalInteractInfo = nil,
	context = nil,
	contextLink = nil,
	isCriminalInteract = nil,
	chatText = nil,
}

local reticleToChatDelay = 500
local reticleInteractionToChatDelay = 500

FCOAB.groupLeaderData = {}
local groupLeaderData = FCOAB.groupLeaderData

local combatTips = {
		--The table key is the tipId
		-- Priority: BLOCK -> OFF BALANCE -> INTERRUPT -> DODGE
		[1] = {key = "block", 		tipId = 1, label = "BLOCK"},
		[2] = {key = "offBalance", 	tipId = 2, label = "OFF BALANCE"},
		[3] = {key = "interrupt", 	tipId = 3, label = "INTERRUPT"},
		[4] = {key = "dodge", 		tipId = 4, label = "DODGE"}
}

local alreadyInteractedNPCNames    = {}
local reticleOverLastHealthPercent = 0

--===================== EARLY CALLED game code ==============================================


--===================== FUNCTIONS ==============================================

local function startsWith(strToSearch, searchFor)
	if string.find(strToSearch, searchFor, 1, true) ~= nil then
		return true
	end
	return false
end

local function addToChatWithPrefix(chatMsg, prefixText)
	if chatMsg == nil or chatMsg == "" then return end
	prefixText = prefixText or FCOAB.settingsVars.settings.chatAddonPrefix
	if prefixText ~= nil and prefixText ~= "" then
		d(prefixText .. chatMsg)
	end
end

local function outputLAMSettingsChangeToChat(chatMsg, prefixText)
	if FCOAB.settingsVars.settings.thisAddonLAMSettingsSetFuncToChat == false then return end
	addToChatWithPrefix(chatMsg, strfor(FCOABSettingsPrefixStr, prefixText))
end

local function showCombatTipInChat(tipId)
	if tipId == nil or tipId <= 0 or
		not FCOAB.settingsVars.settings.combatTipToChat then return end
	--Hide ZOs alert? -->Should not be needed for visibly impaired players
	--ZO_ActiveCombatTips:SetHidden(true)
	local tipData = combatTips[tipId]
	if tipData == nil then return end

	addToChatWithPrefix(tipData.label, nil)
end

local function enableActiveCombatTipsIfDisabled()
	--Activate combat tips. Set them to "Always show"
	SetSetting(SETTING_TYPE_ACTIVE_COMBAT_TIP, 0, ACT_SETTING_ALWAYS)
end

local function getCompassChatText(newText)
	local compassStr = compassbaseStr

	--Checks with the pintype
	local bestPinType = FCOAB._bestPinType
	if bestPinType ~= nil then
		if IsUnitGrouped(CON_PLAYER) then
			if groupLeaderPinTypes[bestPinType] then
				return compassStr .. " " .. groupLeaderStr .. ": "
			elseif groupPinTypes[bestPinType] then
				return compassStr .. " " .. groupStr .. ": "
			end
		end
		if companionPinTypes[bestPinType] then
			return compassStr .. " " .. companionStr .. ": "
		elseif rallyPointPinTypes[bestPinType] then
			return compassStr .. ": "
		end

		local questCompassText = mapPinTypeToCompassText[bestPinType]
		if questCompassText ~= nil then
			return compassStr .. " " .. questCompassText .. ": "
		end
	end

	--Checks without the pinType
	if IsUnitGrouped(CON_PLAYER) then
		--RallyPoint of group?
		if newText == rallyPointStr then
			--Do nothing, the "Rally point" string will be added automatically from the compass pin's text
		elseif newText == ZO_CachedStrFormat(SI_UNIT_NAME, GetUnitName(GetGroupLeaderUnitTag())) then
			compassStr = compassStr .. " " .. groupLeaderStr
		end
	end
	return compassStr .. ": "
end

local function playSoundLoopNow(soundToPlay, soundRepeats)
	local soundName = soundNamesInternal[soundToPlay]
--d("[FCOAB]PlaySound: " ..tos(soundName) .. ", volumeIncrease: " ..tos(soundRepeats))
	if not soundToPlay or not soundsRef[soundName] then return false end
	soundRepeats = soundRepeats or 1
	local wasPlayed = false
    for i=1, soundRepeats, 1 do
		--Play the sound (multiple times will play it louder)
		PlaySound(soundsRef[soundName])
        wasPlayed = true
	end
--d("<wasPlayed: " ..tos(wasPlayed))
    return wasPlayed
end

local function hasWaypoint()
	local offsetX, offsetY = gmpw()
	return offsetX ~= 0 or offsetY ~= 0
end

local function hasRallyPoint()
	local offsetX, offsetY = gmrp()
	return offsetX ~= 0 or offsetY ~= 0
end

local function calculateLayerInformedDistance(drawLayer, drawLevel)
	return (1.0 - (drawLevel / 0xFFFFFFFF)) - drawLayer
end

local function isWayPointItAutoRemoveWaypointEnabled()
	if WAYPOINTIT == nil or (WAYPOINTIT ~= nil and WAYPOINTIT.sv == nil) then return false end
	if not WAYPOINTIT.sv["AUTO_REMOVE_WAYPOINT"] then return false end
	return true
end

local function isWaypointSetAndShouldBeRemovedAutomaticallyByFCOAB()
	return (FCOAB.settingsVars.settings.autoRemoveWaypoint and not IsUnitDead(CON_PLAYER) and not isWayPointItAutoRemoveWaypointEnabled()) and hasWaypoint()
end

local function checkUnitIsOnlineAndInSameIniAndWorld(unitTag)
	local isUnitOnlineAndInSameWorldEtc = false
	if unitTag == nil or unitTag == "" or unitTag == CON_PLAYER then return false end

	local doesUnitExist = DoesUnitExist(unitTag)
	local isOnline = IsUnitOnline(unitTag)
	local inSameInstance = IsGroupMemberInSameInstanceAsPlayer(unitTag)
	local inSameWorld = IsGroupMemberInSameLayerAsPlayer(unitTag)
	local inSameLayer = IsGroupMemberInSameLayerAsPlayer(unitTag)
	isUnitOnlineAndInSameWorldEtc = (doesUnitExist and isOnline and inSameInstance and inSameWorld and inSameLayer and true) or false
	if isUnitOnlineAndInSameWorldEtc == false then
		if not inSameWorld and not inSameLayer and doesUnitExist and isOnline then
			--Check if the group leader is in the same parent zone (inside a delve of the zone e.g.)
			local zoneIndexOfUnit = GetUnitZoneIndex(unitTag)
			local parentZoneId = GetParentZoneId(zoneIndexOfUnit)
			local zoneIndexOfPlayer    = GetCurrentMapZoneIndex()
			local parentZoneIdOfPlayer = GetParentZoneId(zoneIndexOfPlayer)
			if zoneIndexOfPlayer == zoneIndexOfUnit or (parentZoneIdOfPlayer > 0 and parentZoneId > 0 and parentZoneIdOfPlayer == parentZoneId) then
				isUnitOnlineAndInSameWorldEtc = true
			end
		end
	end
--d("[FCOAB]checkIfUnitOnlineEtc - unitTag: " ..tos(unitTag) .. ", result: " ..tos(isUnitOnlineAndInSameWorldEtc))
	return isUnitOnlineAndInSameWorldEtc
end

local function isGroupedAndGroupLeaderGivenAndShouldSoundPlayByFCOAB()
	if FCOAB.settingsVars.settings.groupLeaderSound == false then return false end

	groupLeaderData = {}
	local isNotDeadAndIsGrouped = (not IsUnitDead(CON_PLAYER) and IsUnitGrouped(CON_PLAYER) and true) or false
	local groupLeaderNotMeAndGivenAndOnlineAndInZone = false
	if isNotDeadAndIsGrouped == true then
		local groupLeaderUnitTag = GetGroupLeaderUnitTag()
		if groupLeaderUnitTag ~= nil and groupLeaderUnitTag ~= "" then
			--Check that we arent't the group leader
			local groupLeaderDisplayName = GetUnitDisplayName(groupLeaderUnitTag)
			if myDisplayName ~= groupLeaderDisplayName then
				groupLeaderNotMeAndGivenAndOnlineAndInZone = checkUnitIsOnlineAndInSameIniAndWorld(groupLeaderUnitTag)
				if groupLeaderNotMeAndGivenAndOnlineAndInZone == true then
					groupLeaderData = {
						unitTag = groupLeaderUnitTag
					}
				end
			end
		end
	end
--d("[FCOAB]isGroupedEtc - notDead&Grouped: " ..tos(isNotDeadAndIsGrouped) ..", leaderInZone: " ..tos(groupLeaderNotMeAndGivenAndOnlineAndInZone))
	return isNotDeadAndIsGrouped and groupLeaderNotMeAndGivenAndOnlineAndInZone
end

--Code exmaples taken from Circonian's WayPointIt: Many thanks!
local function canProcessMap()
	if GPS:IsMeasuring() then
		return false
	end
	-- cant get coordinates from the cosmic map
	--if GetMapType() == MAPTYPE_COSMIC then
	if ZO_WorldMap_IsWorldMapShowing() then
		return true
	end
	if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
		CM:FireCallbacks("OnWorldMapChanged")
	end
	--end
	return DoesUnitExist(CON_PLAYER)
end


local function getDistanceToLocalCoords(locX, locY, playerOffsetX, playerOffsetY)
	-- if not on cosmic map or we reset it to player location
	if not canProcessMap() then
		return 0, false
	end

	local locX, locY = GPS:LocalToGlobal(locX, locY)
	if not playerOffsetX then
		playerOffsetX, playerOffsetY = GPS:LocalToGlobal(GetMapPlayerPosition(CON_PLAYER))
	end

	local gameUnitDistance = GPS:GetGlobalDistanceInMeters(locX, locY, playerOffsetX, playerOffsetY)

	-- 11,000 steps per unit, stride length 3.5 feet per step -- No longer calculated this way
	-- Strike that, changing calculations to match ability grey out distance/range
	-- 15000 * 5.6 = 84000 and feet to meters: 84000 * 0.3048 = 25603.2
	return math.floor(gameUnitDistance * 1) --distance in meters, in feet the multiplier would be: 3.28084
end

local function isWaypointOutsideOfRemovalDistance(xLoc, yLoc)
	local settings = FCOAB.settingsVars.settings
	local pinDeltaMin, pinDeltaMax, distToCoords = settings.WAYPOINT_DELTA_SCALE, settings.WAYPOINT_DELTA_SCALE_MAX, getDistanceToLocalCoords(xLoc, yLoc)

	return distToCoords > pinDeltaMin and distToCoords < pinDeltaMax
end

-- RegisterUpdate function to check current loc vs waypoint loc
-- Used for Automatically removing waypoints local function CheckWaypointLoc()
local isWaypointRemoveUpdateEventActive = false
local isGroupLeaderUpdateEventActive = false
local runWaypointRemoveUpdates, runGroupLeaderUpdates
local function checkWaypointLoc()
	-- if not on cosmic map or we reset it to player location
	if not canProcessMap() then
		return
	end

	--[[ If somehow the waypoint no longer exists...but it was not caught in the OnMapPing remove event, remove it now & stop the updates.
	There was a particular instance when this was happening, which is why I added it...but I don't remember what it was now. Maybe it was just a bug...better safe than sorry though.
	--]]
	local waypointOffsetX, waypointOffsetY = gmpw()
	if waypointOffsetX == 0 and waypointOffsetY == 0 then
		runWaypointRemoveUpdates(false, nil)
		--runHeadingUpdates(false)
		FCOAB.settingsVars.settings.currentWaypoint = nil
		return
	end

	-- coordinates get converted to global, so distances are consistent
	-- accross all maps.
	if not isWaypointOutsideOfRemovalDistance(waypointOffsetX, waypointOffsetY) then
		--[[
		local waypoint = settings.currentWaypoint
		local setBy = (waypoint and waypoint.setBy) or "n/a"

		if (setBy == "rowClick" and self.sv["WAYPOINT_MESSAGES_USER_DEFINED"]) or (setBy == "autoQuest" and self.sv["WAYPOINT_MESSAGES_AUTO_QUEST"]) then
			CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATECORY_SMALL_TEXT, SOUNDS.ACHIEVEMENT_AWARDED, GetString(SI_WAYPOINTIT_WAYPOINT_REACHED))
		end
		]]

		--Remove the waypoint
		ZO_WorldMap_RemovePlayerWaypoint() --use this to remove teh pin on the worldmap too! will internally call RemovePlayerWaypoint()
	end
end

runWaypointRemoveUpdates = function (doEnable, forced)
	--d("[FCOAB]runWaypointRemoveUpdates - doEnable: " ..tos(doEnable) .. ", forced: " ..tos(forced))
	if doEnable and (forced or FCOAB.settingsVars.settings.autoRemoveWaypoint) then
		isWaypointRemoveUpdateEventActive = true
		EM:RegisterForUpdate(autoRemoveWaypointEventName, 50,
				function() checkWaypointLoc() end
		)
	else
		isWaypointRemoveUpdateEventActive = false
		EM:UnregisterForUpdate(autoRemoveWaypointEventName)
	end
end

local function OnTryHandlingInteraction(reticleObj, interactionPossible, currentFrameTimeSeconds)
	if not interactionPossible then return false end
	if FCOAB.settingsVars.settings.reticleInteractionToChatText == false then return false end

	local now = GetGameTimeMilliseconds()
	local lastReticleInteraction2Chat = lastPlayed.reticleInteraction2Chat
	if lastReticleInteraction2Chat == 0 or now >= (lastReticleInteraction2Chat + reticleInteractionToChatDelay) then
		lastPlayed.reticleInteraction2Chat = now

		local action, interactableName, interactionBlocked, isOwned, additionalInteractInfo, context, contextLink, isCriminalInteract = GetGameCameraInteractableActionInfo()
		--if additionalInteractInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE and not interactionBlocked then
		if action == nil then
			lastAddedInteractionReticleToChat = {
				action = nil,
				interactableName = nil,
				interactionBlocked = nil,
				isOwned = nil,
				additionalInteractInfo = nil,
				context = nil,
				contextLink = nil,
				isCriminalInteract = nil,
				chatText = nil,
			}
			return
		end
		--d(">action: " ..tos(action) .. ", additionalInteractInfo: " .. tos(additionalInteractInfo) .. ", interactableName: " ..tos(interactableName) .. ", interactionBlocked: " .. tos(interactionBlocked) .. ", isOwned: " .. tos(isOwned) .. ", context: " ..tos(context) .. ", contextLink: " ..tos(contextLink) .. ", isCriminal: " ..tos(isCriminalInteract))

		if action ~= lastAddedInteractionReticleToChat.action
				or interactableName ~= lastAddedInteractionReticleToChat.interactableName
				or interactionBlocked ~= lastAddedInteractionReticleToChat.interactionBlocked
				or isOwned ~= lastAddedInteractionReticleToChat.isOwned
				or additionalInteractInfo ~= lastAddedInteractionReticleToChat.additionalInteractInfo
				or context ~= lastAddedInteractionReticleToChat.context
				or contextLink ~= lastAddedInteractionReticleToChat.contextLink
				or isCriminalInteract ~= lastAddedInteractionReticleToChat.isCriminalInteract
		then
			lastAddedInteractionReticleToChat = {
				action = action,
				interactableName = interactableName,
				interactionBlocked = interactionBlocked,
				isOwned = isOwned,
				additionalInteractInfo = additionalInteractInfo,
				context = context,
				contextLink = contextLink,
				isCriminalInteract = isCriminalInteract,
			}
			local newText
			if action ~= "" then
				newText = action
				if interactionBlocked == true or isCriminalInteract == true then
					newText = newText .. " !"
					if interactionBlocked == true then
						newText = newText .. "BLOCKED"
					end
					if isCriminalInteract == true then
						if interactionBlocked == true then
							newText = newText .. ", "
						end
						newText = newText .. "CRIMINAL"
					end
					newText = newText .. "!"
				end
			end
			if interactableName ~= nil and interactableName ~= "" then
				newText = (newText == nil and "'" .. interactableName .. "'") or newText .. "'" .. interactableName .. "'"
			end
			if newText ~= nil and newText ~= "" and newText ~= lastAddedInteractionReticleToChat.chatText then
				lastAddedInteractionReticleToChat.chatText = newText
				addToChatWithPrefix("Interaction: " .. newText)
			end
		end
	end
end

local interactionPostHookDone = false
local function interactionData()
	local settings = FCOAB.settingsVars.settings
	if not interactionPostHookDone and settings.reticleInteractionToChatText == true then
		--SecurePostHook(FISHING_MANAGER, "StartInteraction", OnStartInteraction)
		ZO_PreHook(RETICLE, "TryHandlingInteraction", OnTryHandlingInteraction)

		interactionPostHookDone = true
	end
end


local function buildUnitChatOutputAndAddToChat(unitPrefix, unitSuffix, unitName, unitDisplayName, unitCaption)
	if unitPrefix == nil or unitPrefix == "" then return end
	local newText = unitPrefix
	if unitDisplayName ~= nil and unitDisplayName ~= "" then
		newText = (newText == nil and "'" .. unitDisplayName .. '"') or newText .. " '" .. unitDisplayName .. "'"
	end
	if unitName ~= nil and unitName ~= "" then
		if unitDisplayName == nil then
			newText = (newText == nil and "'" .. unitName .. '"') or newText .. " '" .. unitName .. '"'
		else
			newText = (newText == nil and unitName) or newText .. " " .. unitName
		end
	end
	if unitCaption ~= nil and unitCaption ~= "" then
		newText = (newText == nil and ("<" .. unitCaption .. ">")) or newText .. " <" .. unitCaption ..">"
	end
	if unitSuffix ~= nil and unitSuffix ~= "" then
		newText = newText .. " " .. unitSuffix
	end
	if newText ~= nil and newText ~= "" then
		addToChatWithPrefix("Reticle: " .. newText)
	end
end

local function getReticleOverUnitDataAndPrepareChatText(reticlePlayerToChatText, healthCurrent, healthMax)
	reticlePlayerToChatText = reticlePlayerToChatText or false
	local unitPrefix, unitSuffix, unitHealth
	local unitDisplayName

	local unitName = zo_strformat(SI_UNIT_NAME, GetUnitName(CON_RETICLE))
	local unitCaption = zo_strformat(SI_UNIT_NAME, GetUnitCaption(CON_RETICLE))
	local gender = GetUnitGender(CON_RETICLE)
	local isDead = IsUnitDead(CON_RETICLE)
	local isAttackable = IsUnitAttackable(CON_RETICLE)
	local difficulty = GetUnitDifficulty(CON_RETICLE)
	local unitReaction = GetUnitReaction(CON_RETICLE)
	local unitReactionColortype = GetUnitReactionColorType(CON_RETICLE)
	local currentHealth, maxHealth = healthCurrent, healthMax
	if currentHealth == nil or maxHealth == nil then
		currentHealth, maxHealth = GetUnitPower(CON_RETICLE, COMBAT_MECHANIC_FLAGS_HEALTH)
	end

	local isInteractableMonster = IsGameCameraInteractableUnitMonster()

	--[[
		UNIT_TYPE_PLAYER	1
		UNIT_TYPE_MONSTER 	2
	]]
	local unitType = GetUnitType(CON_RETICLE)
	local isOtherPlayer, isNPC, isCritter, isMonster = false, false, false, false

	--Player characters
	if unitType == UNIT_TYPE_PLAYER and reticlePlayerToChatText == true then
		isOtherPlayer = true
		unitDisplayName = GetUnitDisplayName(CON_RETICLE)
		local isFriend = IsUnitFriend(CON_RETICLE)
		if isFriend  then
			unitPrefix = "Friend"
		else
			local isGuildMate = false
			local guildIndex
			for idx=1, GetNumGuilds(), 1 do
				if guildIndex == nil and isGuildMate == false then
					local guildId = GetGuildId(idx)
					if guildId ~= nil then
						local guildMemberIndex = GetGuildMemberIndexFromDisplayName(guildId, unitDisplayName)
						if guildMemberIndex ~= nil and guildMemberIndex > 0 then
							guildIndex = idx
							isGuildMate = true
							break
						end
					end
				end
			end
			if isGuildMate == true then
				unitPrefix = strfor("Guild %s member", tos(guildIndex))
			else
				unitPrefix = "Player"
			end
		end

		local isGrouped = IsUnitGrouped(CON_RETICLE)
		local class = ZO_CachedStrFormat(SI_UNIT_NAME,GetUnitClass(CON_RETICLE))
		local race = GetUnitRace(CON_RETICLE)
		local alliance = GetUnitAlliance(CON_RETICLE)
		local level = GetUnitLevel(CON_RETICLE)
		local cp = GetUnitEffectiveChampionPoints(CON_RETICLE)
		if isDead == true then
			if IsUnitBeingResurrected(CON_RETICLE) == true then
				unitPrefix = unitPrefix .. " (actively ressurrected)"
			else
				unitPrefix = unitPrefix .. " (dead)"
			end
		end
		if isGrouped == true then
			unitPrefix = unitPrefix " .. (in a group)"
		end
		if class then
			unitSuffix = unitSuffix or ""
			unitSuffix = unitSuffix .. ", class: " .. class
		end
		if race ~= nil and gender ~= nil and type(race) == "number" then
			local raceName = ZO_CachedStrFormat(SI_UNIT_NAME, GetRaceName(gender, race))
			unitSuffix = unitSuffix or ""
			unitSuffix = unitSuffix .. ", race: " .. raceName
		end
		if level then
			unitSuffix = unitSuffix or ""
			if cp and cp > 0 then
				unitSuffix = unitSuffix .. ", CP: " .. tos(cp)
			else
				unitSuffix = unitSuffix .. ", level: " .. tos(level)
			end
		end
		if alliance and type(alliance) == "number" then
			unitSuffix = unitSuffix or ""
			local allianceName = ZO_CachedStrFormat(SI_UNIT_NAME, GetAllianceName(alliance))
			unitSuffix = unitSuffix .. ", alliance: " .. allianceName
		end


	--Monsters and NPCs
	elseif unitType == UNIT_TYPE_MONSTER then
		isOtherPlayer= false
		local isEngaged = IsUnitActivelyEngaged(CON_RETICLE)
d(">unitReactColor: " ..tos(unitReactionColortype))
		--local companionName = ZO_CachedStrFormat(SI_UNIT_NAME, GetUnitName(CON_COMPANION))
		--local isMyCompanion = (unitName == companionName and true) or false
		local isMyCompanion = AreUnitsEqual(CON_COMPANION, CON_RETICLE)
		if isMyCompanion == true then
			unitPrefix = "My companion"
		else
			local isInvulnerableGuard = IsUnitInvulnerableGuard(CON_RETICLE)
			if isInvulnerableGuard == true then
				unitPrefix = "Invulnerable GUARD"
			else
				local isJusticeGuard = IsUnitJusticeGuard(CON_RETICLE)
				if isJusticeGuard == true then
					unitPrefix = "Justice GUARD"
				else
					local isFriendlyFollower = IsUnitFriendlyFollower(CON_RETICLE)
					if isFriendlyFollower == true then
						unitPrefix = "Friendly follower"
					else
						local isLiveStock = IsUnitLivestock(CON_RETICLE)
						if isLiveStock == true then
							unitPrefix = "Livestock"
						else
							--[[
							UNIT_REACTION_DEFAULT = 0
							UNIT_REACTION_HOSTILE = 1
							UNIT_REACTION_NEUTRAL = 2
							UNIT_REACTION_FRIENDLY = 3
							UNIT_REACTION_PLAYER_ALLY = 4
							UNIT_REACTION_NPC_ALLY = 5
							UNIT_REACTION_COMPANION = 6
							]]
							if unitReaction == UNIT_REACTION_FRIENDLY or unitReaction == UNIT_REACTION_PLAYER_ALLY then
	d(">friendly")
								if alreadyInteractedNPCNames[unitName] == true or isInteractableMonster == true or unitReactionColortype == UNIT_REACTION_COLOR_NEUTRAL then
									isNPC = true
								else
									--currentHealth, maxHealth = GetUnitPower(CON_RETICLE, COMBAT_MECHANIC_FLAGS_HEALTH)
									if maxHealth <= CON_CRITTER_MAX_HEALTH or unitReactionColortype == UNIT_REACTION_COLOR_NEUTRAL then

	d(">max health below 1000 - Critter?1")
										isNPC = false
										isCritter = true
									else
										isAttackable = (currentHealth < maxHealth and true) or false
										if isAttackable == false and (unitCaption ~= nil or unitReactionColortype == UNIT_REACTION_COLOR_FRIENDLY) then
	d(">not attackable - NPC?1")
											isNPC = true
										end
									end
								end
							elseif UNIT_REACTION_HOSTILE and isAttackable == false then
	d(">hostile")
								if isAttackable == false and not isDead then
	d(">not attackable - NPC?2")
									isNPC = true
								end
							elseif UNIT_REACTION_NPC_ALLY then
	d(">NPC ally")

								isNPC = false
								if isAttackable == true then
									--currentHealth, maxHealth = GetUnitPower(CON_RETICLE, COMBAT_MECHANIC_FLAGS_HEALTH)
									if maxHealth <= CON_CRITTER_MAX_HEALTH then
	d("<attackable, max health < 1000 - Critter?2")
										isCritter = true
									else
										if unitReactionColortype == UNIT_REACTION_COLOR_HOSTILE then
											isNPC = false --it's a monster/enemy
											isCritter = false
											--[[
											* UNIT_REACTION_COLOR_DEFAULT 		0
											* UNIT_REACTION_COLOR_HOSTILE 		1
											* UNIT_REACTION_COLOR_NEUTRAL 		2
											* UNIT_REACTION_COLOR_FRIENDLY 		3
											* UNIT_REACTION_COLOR_PLAYER_ALLY 	4
											* UNIT_REACTION_COLOR_NPC_ALLY 		5
											* UNIT_REACTION_COLOR_DEAD 			6
											* UNIT_REACTION_COLOR_INTERACT 		7
											* UNIT_REACTION_COLOR_COMPANION 	8
											]]
										end
									end
								else
									isNPC = true
								end
							elseif UNIT_REACTION_NEUTRAL then
	d(">neutral")
								isAttackable = false
								if isNPC == false and (alreadyInteractedNPCNames[unitName] == true or isInteractableMonster == true) then
	d(">>isInteractMonster")
									isNPC = true
								end
							end

							if isNPC == true then
								alreadyInteractedNPCNames[unitName] = true
								unitPrefix = "NPC"
							else
								--[[
								* MONSTER_DIFFICULTY_DEADLY
								* MONSTER_DIFFICULTY_EASY
								* MONSTER_DIFFICULTY_HARD
								* MONSTER_DIFFICULTY_NONE
								* MONSTER_DIFFICULTY_NORMAL
								]]
								isMonster = true
								if isCritter == true or difficulty == MONSTER_DIFFICULTY_NONE then
									unitPrefix = "Critter"
									isMonster = false
								elseif difficulty >= MONSTER_DIFFICULTY_EASY and difficulty <= MONSTER_DIFFICULTY_NORMAL then
									unitPrefix = "Monster"
								elseif difficulty == MONSTER_DIFFICULTY_HARD then
									unitPrefix = "HARD monster"
								elseif difficulty == MONSTER_DIFFICULTY_DEADLY then
									unitPrefix = "DEADLY monster"
								end
							end
						end
					end
				end
			end
		end
		--Show monster's health current in %, and max in values?
		--Died meanwhile?
		isDead = IsUnitDead(CON_RETICLE)
		if isMonster == true and isDead == false then
			local currentHealthPercent = 100
			if healthCurrent == nil and healthMax == nil then
				currentHealth, maxHealth = GetUnitPower(CON_RETICLE, COMBAT_MECHANIC_FLAGS_HEALTH)
			end
			if(maxHealth and maxHealth > 0) then
				currentHealthPercent = zo_round((currentHealth / maxHealth) * 100)
			else
				currentHealthPercent = 0
			end

			unitHealth = " [" .. tos(currentHealthPercent) .. "%/" ..tos(maxHealth) .. "]"
			unitPrefix = unitPrefix .. unitHealth
		end
		if isEngaged == true then
			if isDead == true then
				unitPrefix = unitPrefix .. " (dead)"
			else
				unitPrefix = unitPrefix .. " (in combat)"
			end
		end
	end
	return unitPrefix, unitSuffix, unitName, unitDisplayName, unitCaption
end

local function onPowerUpdate(eventId, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
	--Only in combat!
	if not IsUnitInCombat(CON_PLAYER) then return end
	if FCOAB.settingsVars.settings.showReticleOverUnitHealthInChat == false then return end

d("[FCOAB]OnPowerUpdate-powerValue: " .. tos(powerValue) .. ", powerMax: " ..tos(powerMax))
	--if unitTag ~= CON_RETICLE then return end 			--Done via event filters already
	--if not trackedPowerType[powerType] then return end	--Done via event filters already

	--if powerType == COMBAT_MECHANIC_FLAGS_HEALTH then --currently the only tracked
	--Check if the active reticleOver unit is the same as we saved in the OnReticleChanged callback
	local unitName = zo_strformat(SI_UNIT_NAME, GetUnitName(CON_RETICLE))
	if lastAddedReticleToChat.name ~= unitName then
		reticleOverLastHealthPercent = 0
		return
	end
	--Only update to chat in 10% steps
	local healthPercent = 0
	if powerValue <= 0 or reticleOverLastHealthPercent == 0 or IsUnitDead(CON_RETICLE) then
		return
	else
		healthPercent = zo_round((powerValue / powerMax) * 100)
		local healthDiff = reticleOverLastHealthPercent - healthPercent
		if healthDiff > 0 then
			if healthDiff < 10 then
				return
			end
		else
			if healthDiff > -10 then
				return
			end
		end
	end

	--Output the current reticleOver unit's health to chat
	--local unitPrefix, unitSuffix, unitName, unitDisplayName, unitCaption = getReticleOverUnitDataAndPrepareChatText(nil, powerValue, powerMax)
	local unitPrefix = "\'" .. tos(unitName) .. "\' health: " ..tos(healthPercent) .. "%/" .. tos(powerMax)
	buildUnitChatOutputAndAddToChat(unitPrefix, nil, unitName, nil, nil)
	--end
end

local reticleOverChangedEventRegistered = false

local function reticleUnitData()
	local settings = FCOAB.settingsVars.settings
	local reticleUnitToChatText = settings.reticleUnitToChatText
	local reticlePlayerToChatText = settings.reticlePlayerToChatText
	local showReticleOverUnitHealthInChat = settings.showReticleOverUnitHealthInChat

	if (reticleUnitToChatText == true or reticlePlayerToChatText == true or showReticleOverUnitHealthInChat == true) and reticleOverChangedEventRegistered == false then
		reticleOverLastHealthPercent = 0
		EM:RegisterForEvent(addonName .. "_RETICLE_OVER_CHANGED", EVENT_RETICLE_TARGET_CHANGED, function(eventId)
			settings = FCOAB.settingsVars.settings
			reticleUnitToChatText = settings.reticleUnitToChatText
			reticlePlayerToChatText = settings.reticlePlayerToChatText
			showReticleOverUnitHealthInChat = settings.showReticleOverUnitHealthInChat

			if showReticleOverUnitHealthInChat == true then
				--Update the last saved health value of the target below the reticle, as %
				local health, maxHealth = GetUnitPower(CON_RETICLE, COMBAT_MECHANIC_FLAGS_HEALTH)
				if health > 0 and maxHealth > 0 then
					reticleOverLastHealthPercent = zo_round((health / maxHealth) * 100)
				else
					reticleOverLastHealthPercent = 0
				end
			else
				reticleOverLastHealthPercent = 0
			end

			if reticleUnitToChatText == true or reticlePlayerToChatText == true then
				local now = GetGameTimeMilliseconds()
				local lastReticle2Chat = lastPlayed.reticle2Chat

				if lastReticle2Chat == 0 or now >= (lastReticle2Chat + reticleToChatDelay) then
					lastPlayed.reticle2Chat = now

					local unitPrefix, unitSuffix, unitName, unitDisplayName, unitCaption = getReticleOverUnitDataAndPrepareChatText(reticlePlayerToChatText, nil, nil)

					local lastAddedUnitName = lastAddedReticleToChat.name
					if lastAddedReticleToChat == nil or lastAddedUnitName == nil
							or (	(unitName ~= nil and lastAddedUnitName ~= unitName)
								or 	(unitDisplayName ~= nil and lastAddedUnitName ~= unitDisplayName)
							)
					then
						lastAddedReticleToChat.name = unitName or unitDisplayName
						lastAddedReticleToChat.caption = unitCaption

						buildUnitChatOutputAndAddToChat(unitPrefix, unitSuffix, unitName, unitDisplayName, unitCaption)
					end
				end
			end
		end)

		--Reticle power update (health, magicka, stamina)
		EM:RegisterForEvent(addonName .. "_EVENT_POWER_UPDATE_HEALTH", 		EVENT_POWER_UPDATE, 		onPowerUpdate)
		EM:AddFilterForEvent(addonName .. "_EVENT_POWER_UPDATE_HEALTH", 	EVENT_POWER_UPDATE, 		REGISTER_FILTER_UNIT_TAG, CON_RETICLE, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_HEALTH)
		--[[
		EM:RegisterForEvent(addonName .. "_EVENT_POWER_UPDATE_STAMINA", 	EVENT_POWER_UPDATE, 		onPowerUpdate)
		EM:AddFilterForEvent(addonName .. "_EVENT_POWER_UPDATE_STAMINA", 	EVENT_POWER_UPDATE, 		REGISTER_FILTER_UNIT_TAG, CON_RETICLE, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_STAMINA)
		EM:RegisterForEvent(addonName .. "_EVENT_POWER_UPDATE_MAGICKA", 	EVENT_POWER_UPDATE, 		onPowerUpdate)
		EM:AddFilterForEvent(addonName .. "_EVENT_POWER_UPDATE_MAGICKA", 	EVENT_POWER_UPDATE, 		REGISTER_FILTER_UNIT_TAG, CON_RETICLE, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_MAGICKA)
		]]

		reticleOverChangedEventRegistered = true
	else
		if reticleOverChangedEventRegistered == true then
			reticleOverLastHealthPercent = 0
			EM:UnregisterForEvent(addonName .. "_RETICLE_OVER_CHANGED", 		EVENT_RETICLE_TARGET_CHANGED)
			EM:UnregisterForEvent(addonName .. "_EVENT_POWER_UPDATE_HEALTH",	EVENT_POWER_UPDATE)
			reticleOverChangedEventRegistered = false
		end
	end
end

local function onGroupStatusChange(hasLeft, hasJoined, onUpdate, onUpdateEventPlayerActivated)
	--d("[FCOAB]onGroupStatus-left: " .. tos(hasLeft) .. ", joined: " ..tos(hasJoined) .. ", update: " ..tos(onUpdate) .. ", eventPlayerActivated. " .. tos(onUpdateEventPlayerActivated))
	--Check that the group leader sound should be played,  player is not dead, in a group, group leader exists and is not the player
	--or No group leader data but event is currently active? Deactivate
	if isGroupedAndGroupLeaderGivenAndShouldSoundPlayByFCOAB() == false or (groupLeaderData.unitTag == nil and isGroupLeaderUpdateEventActive) then
		--Disable the sound checks and the updater
		runGroupLeaderUpdates(false, true)
		return
	end

	--Enable the sound checks for the group leader, if not already active
	if not isGroupLeaderUpdateEventActive then
		runGroupLeaderUpdates(true, true)
	end
end

local function isPlayerLookingAtUnit(destNormX, destNormY)
	if not destNormX or not destNormY or (destNormX == 0 and destNormY == 0) then return nil end
	-- player position
	local playerNormX, playerNormY, playerNormZ, isInCurrentMap = GetMapPlayerPosition(CON_PLAYER)
	--[[
	--using vectors here does not really work, maybe some values need to be normalized or values below 0 needs to be recaclulated etc.

	-- target position
	-- player view direction vector
	local heading = GetPlayerCameraHeading()
	--Get vector vx and vy by heading, using cos and sin
	local vx = math.cos(heading)
	local vy = math.sin(heading)
	-- calculate direction vector from player to target
	local dx = destNormX - playerNormX
	local dy = destNormY - playerNormY
	-- calculate dot product of direction vector and view direction vector
	local dot_product = vx * dx + vy * dy
	-- calculate magnitudes of vectors
	local v_magnitude = math.sqrt(vx^2 + vy^2)
	local d_magnitude = math.sqrt(dx^2 + dy^2)
d(">>====================>>")
d(">destX: " ..tos(destNormX) .. ", destY: " ..tos(destNormY) .. ", isInMap: " ..tos(isInCurrentMap))
d("heading: " ..tos(heading) .. "/vx: " ..tos(vx) .. ", vy: " ..tos(vy) .. "/dx: " ..tos(dx) .. ", dy: " ..tos(dy))
d(">dotProduct: " ..tos(dot_product) .. "/v_magni: " ..tos(v_magnitude) .. ", d_magni: " ..tos(d_magnitude))

	-- calculate angle between vectors in radians
	local angle_radians = math.acos(dot_product / (v_magnitude * d_magnitude))
	if angle_radians < 0 then
		angle_radians = angle_radians + 2 * math.pi
	end

	-- convert angle to degrees
	local angle_degrees = math.deg(angle_radians)
d(">angle: " .. tos(angle_degrees) .. ", radians: " ..tos(angle_radians))
d("<<====================<<")
	]]

	--using radian values and changing it to degrees in the end. if value is above 360° it will be subtracted by 360 again
	local opp = playerNormY - destNormY
	local adj = destNormX - playerNormX
	local angle_radians = math.atan2(opp, adj)
	angle_radians = angle_radians - math.pi / 2
	if angle_radians < 0 then
		angle_radians = angle_radians + 2 * math.pi
	end

	local heading = GetPlayerCameraHeading()
	local rotateHeading = angle_radians + ((2 * math.pi) - heading)

	local angle_degrees = math.deg(rotateHeading)
	if angle_degrees > 360 then angle_degrees = angle_degrees - 360 end

	-- check if angle is smaller than threshold 20°
	--todo check if the settings angle (groupLeaderAngle) matches
	local groupLeaderAngle = FCOAB.settingsVars.settings.groupLeaderSoundAngle
	local groupLeaderAngleHalf = groupLeaderAngle / 2
--d(">angle_degrees: " ..tos(angle_degrees) .. " (" ..tos(360 - groupLeaderAngleHalf) .. "/" .. tos(groupLeaderAngleHalf) ..")")
	if angle_degrees >= (360 - groupLeaderAngleHalf) or angle_degrees <= groupLeaderAngleHalf then
--d("<Looking at unit!")
		return true
	else
		--reset the last played group leader sound so next time we look at the group leader again it will be played directly
		lastPlayed.groupLeader = 0
		return false
	end
end

--[[
FCOAB.testLookingAtGroup = function(groupIndex)
	if groupIndex == nil or groupIndex == "" then return end
	if not IsUnitGrouped(CON_PLAYER) then return end
	local unitTag = GetGroupUnitTagByIndex(groupIndex)
	local x, y = GetMapPlayerPosition(unitTag)
	local isLookingAt = isPlayerLookingAtUnit(x, y)
	d("[FCOAB]isLookingAt tag \'" .. tos(unitTag) .. "\': " ..tos(isLookingAt))
	return isLookingAt
end
]]



local function checkGroupLeaderPos()
--d("[FCOAB]checkGroupLeaderPos")
	local unitTagOfGroupLeader = groupLeaderData.unitTag
	if unitTagOfGroupLeader == nil or unitTagOfGroupLeader == "" then
		--Do a new "is unit in group check + get group leader" by simulating a member has left the group
		onGroupStatusChange(true, false, false, false)
		return
	end

	local isUnitOnlineAndInSameWorldEtc = checkUnitIsOnlineAndInSameIniAndWorld(unitTagOfGroupLeader)
	local isUnitStillGroupLeader = (IsUnitGrouped(CON_PLAYER) and isUnitOnlineAndInSameWorldEtc == true and GetGroupLeaderUnitTag() == unitTagOfGroupLeader and true) or false
	if not isUnitStillGroupLeader then
		--Do a new "is unit in group check + get group leader" by simulating a group update
		-->and if the player is dead or the player is the group leader: Disable the sound notifications
		onGroupStatusChange(false, false, true, false)
		return
	end

	local settings = FCOAB.settingsVars.settings

	--Get the x & y coordinates of the group leader
	local normX, normY = GetMapPlayerPosition(unitTagOfGroupLeader)

	--get the distance to the group leader
	local distToGroupLeader = getDistanceToLocalCoords(normX, normY)
	local distToGroupleaderCheckValue = settings.groupLeaderSoundDistance
	--is the player more than x meters away from the groupLeader
	if distToGroupLeader <= distToGroupleaderCheckValue then
		--We are near enough, no sound needs to be played
		--Reset the last played sound time so the next time we looka t the group leader and are not near enough anymore, the sound will be played again
		lastPlayed.groupLeader = 0
		return
	end

	--Check if the player is looking into the group leader's direction
	local isPlayerLookingAtGroupLeader = isPlayerLookingAtUnit(normX, normY)

	--[[
	FCOAB._rads = {
		groupLeader = {
			x = normX,
			y = normY,
		},
		player = {
			x = playerNormX,
			y = playerNormY,
		},
		opp = opp,
		adj = adj,
		rads = rads,
		rotateHeading = rotateHeading,
		distance = distToGroupLeader,
	}
	]]
	--is the player more than 3 meters away from the groupLeader
	if isPlayerLookingAtGroupLeader == true then
		local now = GetGameTimeMilliseconds()
		local lastPlayedGroupLeader = lastPlayed.groupLeader
		local waitTime = settings.groupLeaderSoundDelay * 1000

		if lastPlayedGroupLeader == 0 or now >= (lastPlayedGroupLeader + waitTime) then
			lastPlayed.groupLeader = now
			playSoundLoopNow(settings.groupLeaderSoundName, settings.groupLeaderSoundRepeat)

			if settings.groupLeaderDistanceToChat == true then
				addToChatWithPrefix("Distance to group leader: ", tos(distToGroupLeader))
			end
		end
	end
end

runGroupLeaderUpdates = function (doEnable, forced)
--d("[FCOAB]runGroupLeaderUpdates - doEnable: " ..tos(doEnable) .. ", forced: " ..tos(forced))
	if doEnable and (forced or FCOAB.settingsVars.settings.groupLeaderSound) then
		--Check every 1000ms = 1 second for the position of the group leader
		isGroupLeaderUpdateEventActive = true
		EM:RegisterForUpdate(groupLeaderPosEventName, 1000,
				function() checkGroupLeaderPos() end
		)
	else
		isGroupLeaderUpdateEventActive = false
		--Reset the GroupLeader data
		groupLeaderData = {}
		EM:UnregisterForUpdate(groupLeaderPosEventName)
	end
end



local function onPlayerCombatState(eventId, inCombat)
	local settings = FCOAB.settingsVars.settings
	local combatStartEndInfo = settings.combatStartEndInfo

	if combatStartEndInfo == true then
		local yourHealth = 		GetUnitPower(CON_PLAYER, 	COMBAT_MECHANIC_FLAGS_HEALTH)
		local yourMagicka = 	GetUnitPower(CON_PLAYER, 	COMBAT_MECHANIC_FLAGS_MAGICKA)
		local yourStamina = 	GetUnitPower(CON_PLAYER, 	COMBAT_MECHANIC_FLAGS_STAMINA)
		local yourUltimate = 	GetUnitPower(CON_PLAYER, 	COMBAT_MECHANIC_FLAGS_ULTIMATE)
		--Player got into combat
		if inCombat == true then
			if settings.combatStartSound then
				playSoundLoopNow(settings.combatStartSoundName, settings.combatStartSoundRepeat)
			end
			addToChatWithPrefix("COMBAT START!")
		else
			--Player left combat
			if settings.combatEndSound then
				playSoundLoopNow(settings.combatEndSoundName, settings.combatEndSoundRepeat)
			end
			addToChatWithPrefix("COMBAT END!")
		end
		addToChatWithPrefix(strfor("Your health %s, magicka %s, stamina %s, ultimate %s", tos(yourHealth), tos(yourMagicka), tos(yourStamina), tos(yourUltimate)))
	end
end

--===================== SLASH COMMANDS ==============================================
--Show a help inside the chat
local function help()
	addToChatWithPrefix(FCOAB.addonVars.addonNameMenuDisplay)
end

--Check the commands ppl type to the chat
local function command_handler(args)
    --Parse the arguments string
	local options = {}
    local searchResult = { string.match(args, "^(%S*)%s*(.-)$") }
    for i,v in pairs(searchResult) do
        if (v ~= nil and v ~= "") then
            options[i] = string.lower(v)
        end
    end

	if #options == 0 or options[1] == "" or options[1] == "help" or options[1] == "hilfe" or options[1] == "aide" or options[1] == "list" then
		help()
	else
	end
end

--returns the table  playSoundData = {number repeats, milliseconds delay, number playMultipleTimesToIncreaseVolume}
local function getPreviewDataTab(soundType, repeats)
	local settings = FCOAB.settingsVars.settings
	repeats = repeats or 1
	--{number playCount, number delayInMS, number increaseVolume}, -- table or function returning a table. If this table is provided the chosen sound will be played playCount (default is 1) times after each other, with a delayInMS (default is 0) in milliseconds in between, and each played sound will be played increaseVolume times (directly at the same time) to increase the volume (default is 1, max is 10) (optional)
	if soundType == "CompassTrackedQuest" then
		return {
			playCount = repeats,
			delayInMS = settings.compassTrackedQuestSoundDelay * 1000, --transfer seconds to milliseconds
			increaseVolume = settings.compassTrackedQuestSoundRepeat,
		}
	elseif soundType == "CompassPlayerWaypoint" then
		return {
			playCount = repeats,
			delayInMS = settings.compassPlayerWaypointSoundDelay * 1000, --transfer seconds to milliseconds
			increaseVolume = settings.compassPlayerWaypointSoundRepeat,
		}
	elseif soundType == "CompassGroupRallyPoint" then
		return {
			playCount = repeats,
			delayInMS = settings.compassGroupRallyPointSoundDelay * 1000, --transfer seconds to milliseconds
			increaseVolume = settings.compassGroupRallyPointSoundRepeat,
		}
	elseif soundType == "GroupLeader" then
		return {
			playCount = repeats,
			delayInMS = settings.groupLeaderSoundDelay * 1000, --transfer seconds to milliseconds
			increaseVolume = settings.groupLeaderSoundRepeat,
		}
	elseif soundType == "CombatStart" then
		return {
			playCount = repeats,
			delayInMS = 0,
			increaseVolume = settings.combatStartSoundRepeat,
		}
	elseif soundType == "CombatEnd" then
		return {
			playCount = repeats,
			delayInMS = 0,
			increaseVolume = settings.combatEndSoundRepeat,
		}
	end
end


-- Build the options menu
local function BuildAddonMenu()
	local panelData = {
		type 				= 'panel',
		name 				= addonVars.addonNameMenu,
		displayName 		= addonVars.addonNameMenuDisplay,
		author 				= addonVars.addonAuthor,
		version 			= addonVars.addonVersionOptions,
		registerForRefresh 	= true,
		registerForDefaults = true,
		slashCommand 		= "/FCOABs",
	}

	local savedVariablesOptions = {
		[1] = "Per character",
		[2] = "Account wide",
	}
	local savedVariablesOptionsValues = {
		[1] = 1,
		[2] = 2,
	}

	local settings = FCOAB.settingsVars.settings
	local defaultSettings = FCOAB.settingsVars.defaults

	FCOAB.SettingsPanel = LAM:RegisterAddonPanel(addonName, panelData)


	--LAM 2.0 callback function if the panel was created
	--[[
	local FCOLAMPanelCreated
	FCOLAMPanelCreated = function(panel)
        if panel ~= FCOAB.SettingsPanel then return end
    end
    ]]

	local optionsTable = {    -- BEGIN OF OPTIONS TABLE

		{
			type = 'description',
			text = "This AddOn provides little helpers for blind players",
		},
		--==============================================================================
		{
			type = 'header',
			name = "Settings to chat",
		},
		{
			type = "checkbox",
			name = "Changed setting value: To chat",
			tooltip = "Output the currently changed value of this addon to the chat, including the name of the changed setting",
			getFunc = function() return settings.thisAddonLAMSettingsSetFuncToChat end,
			setFunc = function(value)
				settings.thisAddonLAMSettingsSetFuncToChat = value
				outputLAMSettingsChangeToChat(tos(value), "Changed setting value: To chat")
			end,
			default = defaultSettings.thisAddonLAMSettingsSetFuncToChat,
			--disabled = function() false end,
		},
		--==============================================================================
		{
			type = 'header',
			name = "Settings save mode",
		},
		{
			type          = 'dropdown',
			name          = "SavedVariables save mode",
			tooltip       = "Chose how your settings will be saved",
			choices       = savedVariablesOptions,
			choicesValues = savedVariablesOptionsValues,
			getFunc       = function() return FCOAB.settingsVars.defaultSettings.saveMode end,
			setFunc       = function(value)
				FCOAB.settingsVars.defaultSettings.saveMode = value
				ReloadUI()
			end,
			warning       = "Changing this setting will reload your UI!",
		},
		--==============================================================================
		{
			type = 'header',
			name = "Chat",
		},
		{
			type = "editbox",
			name = "Chat reader prefix text, of this addon",
			tooltip = "Choose a prefix which should be printed in front of all chat messages which this addon writes to chat, so that the Accessibility screen reader reads it loud to you, and you notice the text is coming from this addon.\nThe default value is ´",
			getFunc = function() return settings.chatAddonPrefix end,
			setFunc = function(value)
				settings.chatAddonPrefix = value
				outputLAMSettingsChangeToChat(tos(value), "Chat reader prefix text, of this addon")
			end,
			isMultiline = false, -- boolean (optional)
			isExtraWide = false, -- boolean (optional)
			maxChars = 10, -- number (optional)
			--textType = TEXT_TYPE_NUMERIC, -- number (optional) or function returning a number. Valid TextType numbers: TEXT_TYPE_ALL, TEXT_TYPE_ALPHABETIC, TEXT_TYPE_ALPHABETIC_NO_FULLWIDTH_LATIN, TEXT_TYPE_NUMERIC, TEXT_TYPE_NUMERIC_UNSIGNED_INT, TEXT_TYPE_PASSWORD
			width = "full", -- or "half" (optional)
			--disabled = function() return false end, -- or boolean (optional)
			default = defaultSettings.chatAddonPrefix, -- default value or function that returns the default value (optional)
		},

		--==============================================================================
		{
			type = 'header',
			name = "Compass",
		},
		{
			type = "checkbox",
			name = "Show compass data in chat",
			tooltip = "Show the currently looked at compass data in the chat",
			getFunc = function() return settings.compassToChatText end,
			setFunc = function(value)
				settings.compassToChatText = value
				outputLAMSettingsChangeToChat(tos(value), "Show compass data in chat")
			end,
			default = defaultSettings.compassToChatText,
			--disabled = function() false end,
		},

		{
			type    = "checkbox",
			name    = "Compass: Tracked quest - Play sound",
			tooltip = "Plays a sound repetively if your compass' center is heading into the direction of the currently tracked quest.\nAttention: If there are multiple quest objects shown at the compass, for the same quest, this addon is not able to differ them and will play the sound for all of these shown compass pins!",
			getFunc = function() return settings.compassTrackedQuestSound end,
			setFunc = function(value)
				settings.compassTrackedQuestSound = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Tracked quest - Play sound")
			end,
			default = defaultSettings.compassTrackedQuestSound,
			requiresReload = true,
		},
		{
			type = "soundslider",
			name = "Compass: Choose tracked quest sound", -- or string id or function returning a string
			tooltip = "Choose the sound to play for the compass tracked quest at this horizontal slider. Changing the slider will play the sound as a preview 3 times, using the chosen delay too.", -- or string id or function returning a string (optional)
			getFunc = function() return settings.compassTrackedQuestSoundName end,
			setFunc = function(value)
				settings.compassTrackedQuestSoundName = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Choose tracked quest sound")
			end,
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			saveSoundIndex = false, -- or function returning a boolean (optional) If set to false (default) the internal soundName will be saved. If set to true the selected sound's index will be saved to the SavedVariables (the index might change if sounds get inserted later!).
			showSoundName = true, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be shown at the label of the slider, and at the tooltip too
			playSound = false, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be played via function PlaySound
			playSoundData = function() return getPreviewDataTab("CompassTrackedQuest", 3) end, --{number playCount, number delayInMS, number increaseVolume}, -- table or function returning a table. If this table is provided the chosen sound will be played playCount (default is 1) times after each other, with a delayInMS (default is 0) in milliseconds in between, and each played sound will be played increaseVolume times (directly at the same time) to increase the volume (default is 1, max is 10) (optional)
			showPlaySoundButton = true,
			noAutomaticSoundPreview = false,
			readOnly = false, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			disabled = function() return not settings.compassTrackedQuestSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			--requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.compassTrackedQuestSoundName, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			reference = "FCOAB_LAM_COMPASS_TRACKED_QUEST_SOUNDSLIDER", -- unique global reference to control (optional)
			width = "full",
		},
		{
			type = "slider",
			name = "Compass: Choose tracked quest delay (s)", -- or string id or function returning a string
			tooltip = "Choose the delay in seconds between each repetively played sound for the compass tracked quest at this horizontal slider", -- or string id or function returning a string (optional)
			getFunc = function() return settings.compassTrackedQuestSoundDelay end,
			setFunc = function(value)
				settings.compassTrackedQuestSoundDelay = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Choose tracked quest delay (s)")
			end,
			min = 0,
			max = 30,
			step = 0.25, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 2, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.compassTrackedQuestSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.compassTrackedQuestSoundDelay, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},
		{
			type = "slider",
			name = "Compass: Volume tracked quest sound", -- or string id or function returning a string
			tooltip = "Playing the same sound multiple times increases the volume. Choose how often you want to repeat the played sound for the compass tracked quest to increase the volume with this slider.",
			getFunc = function() return settings.compassTrackedQuestSoundRepeat end,
			setFunc = function(value)
				settings.compassTrackedQuestSoundRepeat = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Volume tracked quest sound")
			end,
			min = 1,
			max = 10,
			step = 1, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 0, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.compassTrackedQuestSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.compassTrackedQuestSoundRepeat, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},


		{
			type    = "checkbox",
			name    = "Compass: Player waypoint - Play sound",
			tooltip = "Plays a sound repetively if your compass' center is heading into the direction of your set player waypoint.",
			getFunc = function() return settings.compassPlayerWaypointSound end,
			setFunc = function(value)
				settings.compassPlayerWaypointSound = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Player waypoint - Play sound")
			end,
			default = defaultSettings.compassPlayerWaypointSound,
			requiresReload = true,
		},
		{
			type = "soundslider",
			name = "Compass: Choose player waypoint sound", -- or string id or function returning a string
			tooltip = "Choose the sound to play for the compass player waypoint at this horizontal slider. Changing the slider will play the sound as a preview 3 times, using the chosen delay too.", -- or string id or function returning a string (optional)
			getFunc = function() return settings.compassPlayerWaypointSoundName end,
			setFunc = function(value)
				settings.compassPlayerWaypointSoundName = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Choose player waypoint sound")
			end,
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			saveSoundIndex = false, -- or function returning a boolean (optional) If set to false (default) the internal soundName will be saved. If set to true the selected sound's index will be saved to the SavedVariables (the index might change if sounds get inserted later!).
			showSoundName = true, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be shown at the label of the slider, and at the tooltip too
			playSound = false, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be played via function PlaySound
			playSoundData = function() return getPreviewDataTab("CompassPlayerWaypoint", 3) end, --{number playCount, number delayInMS, number increaseVolume}, -- table or function returning a table. If this table is provided the chosen sound will be played playCount (default is 1) times after each other, with a delayInMS (default is 0) in milliseconds in between, and each played sound will be played increaseVolume times (directly at the same time) to increase the volume (default is 1, max is 10) (optional)
			showPlaySoundButton = true,
			noAutomaticSoundPreview = false,
			readOnly = false, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.compassPlayerWaypointSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			--requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.compassPlayerWaypointSoundName, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			reference = "FCOAB_LAM_COMPASS_PLAYER_WAYPOINT_SOUNDSLIDER" -- unique global reference to control (optional)
		},
		{
			type = "slider",
			name = "Compass: Choose player waypoint delay (s)", -- or string id or function returning a string
			tooltip = "Choose the delay in seconds between each repetively played sound for the compass player waypoint at this horizontal slider", -- or string id or function returning a string (optional)
			getFunc = function() return settings.compassPlayerWaypointSoundDelay end,
			setFunc = function(value)
				settings.compassPlayerWaypointSoundDelay = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Choose player waypoint delay (s)")
			end,
			min = 0,
			max = 30,
			step = 0.25, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 2, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.compassPlayerWaypointSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.compassPlayerWaypointSoundDelay, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},
		{
			type = "slider",
			name = "Compass: Volume player waypoint sound", -- or string id or function returning a string
			tooltip = "Playing the same sound multiple times increases the volume. Choose how often you want to repeat the played sound for the compass player waypoint to increase the volume with this slider.",
			getFunc = function() return settings.compassPlayerWaypointSoundRepeat end,
			setFunc = function(value)
				settings.compassPlayerWaypointSoundRepeat = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Volume player waypoint sound")
			end,
			min = 1,
			max = 10,
			step = 1, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 0, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.compassPlayerWaypointSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.compassPlayerWaypointSoundRepeat, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},

		{
			type    = "checkbox",
			name    = "Compass: Group rally point - Play sound",
			tooltip = "Plays a sound repetively if your compass' center is heading into the direction of your set group rally point.",
			getFunc = function() return settings.compassGroupRallyPointSound end,
			setFunc = function(value)
				settings.compassGroupRallyPointSound = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Group rally point - Play sound")
			end,
			default = defaultSettings.compassGroupRallyPointSound,
			requiresReload = true,
		},
		{
			type = "soundslider",
			name = "Compass: Choose group rally point sound", -- or string id or function returning a string
			tooltip = "Choose the sound to play for the compass group rally point at this horizontal slider. Changing the slider will play the sound as a preview 3 times, using the chosen delay too.", -- or string id or function returning a string (optional)
			getFunc = function() return settings.compassGroupRallyPointSoundName end,
			setFunc = function(value)
				settings.compassGroupRallyPointSoundName = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Choose group rally point sound")
			end,
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			saveSoundIndex = false, -- or function returning a boolean (optional) If set to false (default) the internal soundName will be saved. If set to true the selected sound's index will be saved to the SavedVariables (the index might change if sounds get inserted later!).
			showSoundName = true, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be shown at the label of the slider, and at the tooltip too
			playSound = false, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be played via function PlaySound
			playSoundData = function() return getPreviewDataTab("CompassGroupRallyPoint", 3) end, --{number playCount, number delayInMS, number increaseVolume}, -- table or function returning a table. If this table is provided the chosen sound will be played playCount (default is 1) times after each other, with a delayInMS (default is 0) in milliseconds in between, and each played sound will be played increaseVolume times (directly at the same time) to increase the volume (default is 1, max is 10) (optional)
			showPlaySoundButton = true,
			noAutomaticSoundPreview = false,
			readOnly = false, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.compassGroupRallyPointSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			--requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.compassGroupRallyPointSoundName, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			reference = "FCOAB_LAM_COMPASS_GROUP_RALLY_POINT_SOUNDSLIDER" -- unique global reference to control (optional)
		},
		{
			type = "slider",
			name = "Compass: Choose group rally point delay (s)", -- or string id or function returning a string
			tooltip = "Choose the delay in seconds between each repetively played sound for the compass group rally point at this horizontal slider", -- or string id or function returning a string (optional)
			getFunc = function() return settings.compassGroupRallyPointSoundDelay end,
			setFunc = function(value)
				settings.compassGroupRallyPointSoundDelay = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Choose group rally point delay (s)")
			end,
			min = 0,
			max = 30,
			step = 0.25, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 2, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.compassGroupRallyPointSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.compassGroupRallyPointSoundDelay, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},
		{
			type = "slider",
			name = "Compass: Volume group rally point sound", -- or string id or function returning a string
			tooltip = "Playing the same sound multiple times increases the volume. Choose how often you want to repeat the played sound for the compass group rally point to increase the volume with this slider.",
			getFunc = function() return settings.compassGroupRallyPointSoundRepeat end,
			setFunc = function(value)
				settings.compassGroupRallyPointSoundRepeat = value
				outputLAMSettingsChangeToChat(tos(value), "Compass: Volume group rally point sound")
			end,
			min = 1,
			max = 10,
			step = 1, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 0, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.compassGroupRallyPointSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.compassGroupRallyPointSoundRepeat, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},
		--==============================================================================
		{
			type = 'header',
			name = "Waypoints",
		},
		{
			type = "checkbox",
			name = "Auto-Remove Waypoints",
			tooltip = "Automatically removes waypoints once you have reached them.\n\nIf the addon \'WaypointIt\' is active and it's setting to auto-remove waypoints is enabled, this setting here will be disabled",
			getFunc = function() return settings.autoRemoveWaypoint end,
			setFunc = function(value)
				settings.autoRemoveWaypoint = value
				outputLAMSettingsChangeToChat(tos(value), "Auto-Remove Waypoints")
				runWaypointRemoveUpdates(value, true)
			end,
			default = defaultSettings.autoRemoveWaypoint,
			disabled = function() return isWayPointItAutoRemoveWaypointEnabled() end,
		},

		--==============================================================================
		{
			type = 'header',
			name = "Reticle",
		},
		{
			type = "checkbox",
			name = "Show unit data (enemy, NPC, ...) in chat",
			tooltip = "Show the currently looked at unit data in the chat",
			getFunc = function() return settings.reticleUnitToChatText end,
			setFunc = function(value)
				settings.reticleUnitToChatText = value
				outputLAMSettingsChangeToChat(tos(value), "Show unit data (enemy, NPC, ...) in chat")
				reticleUnitData()
			end,
			default = defaultSettings.reticleUnitToChatText,
			--disabled = function() false end,
		},
		{
			type = "checkbox",
			name = "Show other player data in chat",
			tooltip = "Show the currently looked at other player data in the chat",
			getFunc = function() return settings.reticlePlayerToChatText end,
			setFunc = function(value)
				settings.reticlePlayerToChatText = value
				outputLAMSettingsChangeToChat(tos(value), "Show other player data in chat")
				reticleUnitData()
			end,
			default = defaultSettings.reticlePlayerToChatText,
			--disabled = function() false end,
		},

		{
			type = "checkbox",
			name = "Show interaction (doors, boxes, ...) data in chat",
			tooltip = "Show the currently looked at interaction data in the chat and show if they are blocked, if it's criminal to use/open them, etc.",
			getFunc = function() return settings.reticleInteractionToChatText end,
			setFunc = function(value)
				settings.reticleInteractionToChatText = value
				outputLAMSettingsChangeToChat(tos(value), "Show interaction (doors, boxes, ...) data in chat")
				interactionData()
			end,
			default = defaultSettings.reticleInteractionToChatText,
			--disabled = function() false end,
		},

		--==============================================================================
		{
			type = 'header',
			name = "Group",
		},
		{
			type = "checkbox",
			name    = "Group leader - Play sound",
			tooltip = "Plays a sound repetively if you are looking into the direction of your group leader.",
			getFunc = function() return settings.groupLeaderSound end,
			setFunc = function(value)
				settings.groupLeaderSound = value
				outputLAMSettingsChangeToChat(tos(value), "Group leader: Play sound")
				runGroupLeaderUpdates(value, true)
			end,
			default = defaultSettings.groupLeaderSound,
			--disabled = function() return false end,
		},
		{
			type = "soundslider",
			name = "Group leader: Choose sound", -- or string id or function returning a string
			tooltip = "Choose the sound to play if you look into the group leader's direction. Changing the slider will play the sound as a preview 3 times, using the chosen delay too.", -- or string id or function returning a string (optional)
			getFunc = function() return settings.groupLeaderSoundName end,
			setFunc = function(value)
				settings.groupLeaderSoundName = value
				outputLAMSettingsChangeToChat(tos(value), "Group leader: Choose sound")
			end,
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			saveSoundIndex = false, -- or function returning a boolean (optional) If set to false (default) the internal soundName will be saved. If set to true the selected sound's index will be saved to the SavedVariables (the index might change if sounds get inserted later!).
			showSoundName = true, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be shown at the label of the slider, and at the tooltip too
			playSound = false, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be played via function PlaySound
			playSoundData = function() return getPreviewDataTab("GroupLeader", 3) end, --{number playCount, number delayInMS, number increaseVolume}, -- table or function returning a table. If this table is provided the chosen sound will be played playCount (default is 1) times after each other, with a delayInMS (default is 0) in milliseconds in between, and each played sound will be played increaseVolume times (directly at the same time) to increase the volume (default is 1, max is 10) (optional)
			showPlaySoundButton = true,
			noAutomaticSoundPreview = false,
			readOnly = false, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.groupLeaderSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			--requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.groupLeaderSoundName, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			reference = "FCOAB_LAM_GROUP_LEADER_SOUNDSLIDER" -- unique global reference to control (optional)
		},
		{
			type = "slider",
			name = "Group leader: Choose delay (s)", -- or string id or function returning a string
			tooltip = "Choose the delay in seconds between each repetively played sound for the Group leader sound at this horizontal slider", -- or string id or function returning a string (optional)
			getFunc = function() return settings.groupLeaderSoundDelay end,
			setFunc = function(value)
				settings.groupLeaderSoundDelay = value
				outputLAMSettingsChangeToChat(tos(value), "Group leader: Choose delay (s)")
			end,
			min = 0,
			max = 30,
			step = 0.25, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 2, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.groupLeaderSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.groupLeaderSoundDelay, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},
		{
			type = "slider",
			name = "Group leader: Volume", -- or string id or function returning a string
			tooltip = "Playing the same sound multiple times increases the volume. Choose how often you want to repeat the played sound if you are looking into the group leader's direction to increase the volume with this slider.",
			getFunc = function() return settings.groupLeaderSoundRepeat end,
			setFunc = function(value)
				settings.groupLeaderSoundRepeat = value
				outputLAMSettingsChangeToChat(tos(value), "Group leader: Volume")
			end,
			min = 1,
			max = 10,
			step = 1, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 0, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.groupLeaderSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.groupLeaderSoundRepeat, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},
		{
			type = "slider",
			name = "Group leader: Sound distance", -- or string id or function returning a string
			tooltip = "Choose the distance in meters around the group leader where the sound will not play. If you move away from the group leader more than this choosen meters the sound will play again.",
			getFunc = function() return settings.groupLeaderSoundDistance end,
			setFunc = function(value)
				settings.groupLeaderSoundDistance = value
				outputLAMSettingsChangeToChat(tos(value), "Group leader: Sound distance")
			end,
			min = 1,
			max = 100,
			step = 1, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 0, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.groupLeaderSoundDistance end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.groupLeaderSoundDistance, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},
		{
			type = "checkbox",
			name    = "Group leader: Distance to chat",
			tooltip = "Shows the distance to the group leader, in meters, in the chat so that the chat reader can read it out o you.",
			getFunc = function() return settings.groupLeaderDistanceToChat end,
			setFunc = function(value)
				settings.groupLeaderDistanceToChat = value
				outputLAMSettingsChangeToChat(tos(value), "Group leader: Distance to chat")
			end,
			default = defaultSettings.groupLeaderDistanceToChat,
			disabled = function() return not settings.groupLeaderSound end,
		},
		{
			type = "slider",
			name = "Group leader: Sound angle", -- or string id or function returning a string
			tooltip = "Choose the angle in degrees where the sound still should be played if you look at the group leader direction. The default value is 20°. That means: if you look at teh group leader and you are aiming 10° to the left or to the right the sound will still be played.",
			getFunc = function() return settings.groupLeaderSoundAngle end,
			setFunc = function(value)
				settings.groupLeaderSoundAngle = value
				outputLAMSettingsChangeToChat(tos(value), "Group leader: Sound angle")
			end,
			min = 1,
			max = 90,
			step = 1, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 0, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.groupLeaderSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.groupLeaderSoundAngle, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},
		--==============================================================================
		{
			type = 'header',
			name = "Combat",
		},
		{
			type = "checkbox",
			name = "Combat: Start & end info to chat",
			tooltip = "If you get into combat, or leave combat, the chat will show you some information about your health, magicka and stamina",
			getFunc = function() return settings.combatStartEndInfo end,
			setFunc = function(value)
				settings.combatStartEndInfo = value
				outputLAMSettingsChangeToChat(tos(value), "Combat: Start & end info to chat")
			end,
			default = defaultSettings.combatStartEndInfo,
			--disabled = function() false end,
		},

		{
			type = "checkbox",
			name = "Combat: Active enemy health to chat",
			tooltip = "Show the actually engaged enemy's health in chat, as %/maximum Health. This will be updated by 10% steps",
			getFunc = function() return settings.showReticleOverUnitHealthInChat end,
			setFunc = function(value)
				settings.showReticleOverUnitHealthInChat = value
				outputLAMSettingsChangeToChat(tos(value), "Combat: Active enemy health to chat")
				reticleUnitData()
			end,
			default = defaultSettings.showReticleOverUnitHealthInChat,
			--disabled = function() false end,
		},

		{
			type = "checkbox",
			name = "Combat: Tip to chat",
			tooltip = "If you get a tip in combat, like \'Block\' or \'Dodge\' or \'Interrupt\', the tip will be written to the chat so that the accessibility chat reader can read it to you",
			getFunc = function() return settings.combatTipToChat end,
			setFunc = function(value)
				settings.combatTipToChat = value
				outputLAMSettingsChangeToChat(tos(value), "Combat: Tip to chat")
				if value == true then
					enableActiveCombatTipsIfDisabled()
				end
			end,
			default = defaultSettings.combatTipToChat,
			--disabled = function() false end,
		},


		{
			type = "checkbox",
			name    = "Combat start - Play sound",
			tooltip = "Plays a sound once if you get into combat.",
			getFunc = function() return settings.combatStartSound end,
			setFunc = function(value)
				settings.combatStartSound = value
				outputLAMSettingsChangeToChat(tos(value), "Combat start - Play sound")
			end,
			default = defaultSettings.combatStartSound,
			--disabled = function() return false end,
		},
		{
			type = "soundslider",
			name = "Combat start: Choose sound", -- or string id or function returning a string
			tooltip = "Choose the sound to play if combat starts. Changing the slider will play the sound once as a preview.", -- or string id or function returning a string (optional)
			getFunc = function() return settings.combatStartSoundName end,
			setFunc = function(value)
				settings.combatStartSoundName = value
				outputLAMSettingsChangeToChat(tos(value), "Combat start: Choose sound")
			end,
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			saveSoundIndex = false, -- or function returning a boolean (optional) If set to false (default) the internal soundName will be saved. If set to true the selected sound's index will be saved to the SavedVariables (the index might change if sounds get inserted later!).
			showSoundName = true, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be shown at the label of the slider, and at the tooltip too
			playSound = false, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be played via function PlaySound
			playSoundData = function() return getPreviewDataTab("CombatStart", 1) end, --{number playCount, number delayInMS, number increaseVolume}, -- table or function returning a table. If this table is provided the chosen sound will be played playCount (default is 1) times after each other, with a delayInMS (default is 0) in milliseconds in between, and each played sound will be played increaseVolume times (directly at the same time) to increase the volume (default is 1, max is 10) (optional)
			showPlaySoundButton = true,
			noAutomaticSoundPreview = false,
			readOnly = false, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.combatStartSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			--requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.combatStartSoundName, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			reference = "FCOAB_LAM_COMBAT_START_SOUNDSLIDER" -- unique global reference to control (optional)
		},
		{
			type = "slider",
			name = "Combat start: Volume", -- or string id or function returning a string
			tooltip = "Playing the same sound multiple times increases the volume. Choose how often you want to repeat the played sound if combat is started to increase the volume with this slider.",
			getFunc = function() return settings.combatStartSoundRepeat end,
			setFunc = function(value)
				settings.combatStartSoundRepeat = value
				outputLAMSettingsChangeToChat(tos(value), "Combat start: Volume")
			end,
			min = 1,
			max = 10,
			step = 1, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 0, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.combatStartSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.combatStartSoundRepeat, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},
		
		{
			type = "checkbox",
			name    = "Combat end - Play sound",
			tooltip = "Plays a sound once if you leave combat.",
			getFunc = function() return settings.combatEndSound end,
			setFunc = function(value)
				settings.combatEndSound = value
				outputLAMSettingsChangeToChat(tos(value), "Combat end - Play sound")
			end,
			default = defaultSettings.combatEndSound,
			--disabled = function() return false end,
		},
		{
			type = "soundslider",
			name = "Combat end: Choose sound", -- or string id or function returning a string
			tooltip = "Choose the sound to play if combat ends. Changing the slider will play the sound once as a preview.", -- or string id or function returning a string (optional)
			getFunc = function() return settings.combatEndSoundName end,
			setFunc = function(value)
				settings.combatEndSoundName = value
				outputLAMSettingsChangeToChat(tos(value), "Combat end: Choose sound")
			end,
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			saveSoundIndex = false, -- or function returning a boolean (optional) If set to false (default) the internal soundName will be saved. If set to true the selected sound's index will be saved to the SavedVariables (the index might change if sounds get inserted later!).
			showSoundName = true, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be shown at the label of the slider, and at the tooltip too
			playSound = false, -- or function returning a boolean (optional) If set to true (default) the selected sound name will be played via function PlaySound
			playSoundData = function() return getPreviewDataTab("CombatEnd", 1) end, --{number playCount, number delayInMS, number increaseVolume}, -- table or function returning a table. If this table is provided the chosen sound will be played playCount (default is 1) times after each other, with a delayInMS (default is 0) in milliseconds in between, and each played sound will be played increaseVolume times (directly at the same time) to increase the volume (default is 1, max is 10) (optional)
			showPlaySoundButton = true,
			noAutomaticSoundPreview = false,
			readOnly = false, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.combatEndSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			--requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.combatEndSoundName, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			reference = "FCOAB_LAM_COMBAT_END_SOUNDSLIDER" -- unique global reference to control (optional)
		},
		{
			type = "slider",
			name = "Combat end: Volume", -- or string id or function returning a string
			tooltip = "Playing the same sound multiple times increases the volume. Choose how often you want to repeat the played sound if combat ends to increase the volume with this slider.",
			getFunc = function() return settings.combatEndSoundRepeat end,
			setFunc = function(value)
				settings.combatEndSoundRepeat = value
				outputLAMSettingsChangeToChat(tos(value), "Combat end: Volume")
			end,
			min = 1,
			max = 10,
			step = 1, -- (optional)
			clampInput = true, -- boolean, if set to false the input won't clamp to min and max and allow any number instead (optional)
			--clampFunction = function(value, min, max) return math.max(math.min(value, max), min) end, -- function that is called to clamp the value (optional)
			decimals = 0, -- when specified the input value is rounded to the specified number of decimals (optional)
			autoSelect = false, -- boolean, automatically select everything in the text input field when it gains focus (optional)
			inputLocation = "below", -- or "right", determines where the input field is shown. This should not be used within the addon menu and is for custom sliders (optional)
			--readOnly = true, -- boolean, you can use the slider, but you can't insert a value manually (optional)
			width = "full", -- or "half" (optional)
			disabled = function() return not settings.combatEndSound end, --or boolean (optional)
			--warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
			requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
			default = defaultSettings.combatEndSoundRepeat, -- default value or function that returns the default value (optional)
			--helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
			--reference = "MyAddonSlider", -- unique global reference to control (optional)
			--resetFunc = function(sliderControl) d("defaults reset") end, -- custom function to run after the control is reset to defaults (optional)
		},		
	}

	--CM:RegisterCallback("LAM-PanelControlsCreated", FCOLAMPanelCreated)
	LAM:RegisterOptionControls(addonName, optionsTable)
end

--==============================================================================
--============================== END SETTINGS ==================================
--==============================================================================

--Check for other addons and react on them
--[[
local function CheckIfOtherAddonsActive()
	return false
end
]]






function FCOAB.GetCompassCenterPins()
	local bestPinIndices = {}
	local bestPinDistances = {}
	local bestPinDescription, bestPinType

	if not COMPASS_FRAME:GetBossBarActive() then
		ZO_ClearNumericallyIndexedTable(bestPinIndices)
		ZO_ClearNumericallyIndexedTable(bestPinDistances)
		for i = 1, compass.container:GetNumCenterOveredPins() do
			if not compass.container:IsCenterOveredPinSuppressed(i) then
				local drawLayer, drawLevel = compass.container:GetCenterOveredPinLayerAndLevel(i)
				local layerInformedDistance = calculateLayerInformedDistance(drawLayer, drawLevel)
				local insertIndex
				for bestPinIndex = 1, #bestPinIndices do
					if layerInformedDistance < bestPinDistances[bestPinIndex] then
						insertIndex = bestPinIndex
						break
					end
				end
				if not insertIndex then
					insertIndex = #bestPinIndices + 1
				end

				table.insert(bestPinIndices, insertIndex, i)
				table.insert(bestPinDistances, insertIndex, layerInformedDistance)
			end
		end

		for i, centeredPinIndex in ipairs(bestPinIndices) do
			local description = compass.container:GetCenterOveredPinDescription(centeredPinIndex)
			if description ~= "" then
				bestPinDescription = description
				bestPinType = compass.container:GetCenterOveredPinType(centeredPinIndex)
				break
			end
		end
	end

	return bestPinIndices, bestPinDistances, bestPinDescription, bestPinType
end




--==============================================================================
--===== HOOKS BEGIN ============================================================
--==============================================================================
local function CreateCompassHooks()
	--Update compass variables
	zosVars.compass = COMPASS
	compass = zosVars.compass
	zosVars.compassCenterOverPinLabel = compass.centerOverPinLabel
	compassCenterOverPinLabel = zosVars.compassCenterOverPinLabel

	local settings = FCOAB.settingsVars.settings
	local compassTrackedQuestSound = settings.compassTrackedQuestSound

	if compassTrackedQuestSound == true or settings.compassPlayerWaypointSound == true or settings.compassGroupRallyPointSound == true then
		if compassCenterOverPinLabel ~= nil then
			--This will be called way too often, multiple times a second...
			ZO_PreHook(compassCenterOverPinLabel, "SetText", function(ctrl, newText)
				local now = GetGameTimeMilliseconds()

				--if lastCompassCenterOverPinLabeltext == nil or lastCompassCenterOverPinLabeltext ~= newText then
				settings = FCOAB.settingsVars.settings

				--lastCompassCenterOverPinLabeltext = newText

				if settings.compassToChatText == true and newText and newText ~= "" then
					local lastCommpass2Chat = lastPlayed.compass2Chat
					if lastCommpass2Chat == 0 or now >= (lastCommpass2Chat + compassToChatDelay) then
						if lastAddedToChat == nil or lastAddedToChat == "" or lastAddedToChat ~= newText then
							lastAddedToChat = newText
							local compassStr = getCompassChatText(newText)
							--Check if compass text is a group member, or the leader, or a group ralley point
							addToChatWithPrefix(compassStr .. newText)
						end
					end
				end

				--[[
				SI_COMPASS_NORTH_ABBREVIATION
				SI_COMPASS_EAST_ABBREVIATION
				SI_COMPASS_SOUTH_ABBREVIATION
				SI_COMPASS_WEST_ABBREVIATION
				]]
				--Player waypoint sound
				if settings.compassPlayerWaypointSound == true and settings.compassPlayerWaypointSoundName ~= CON_SOUND_NONE and hasWaypoint() then
					--Your waypoint is currently in the middle
					local normX, normY = gmpw()
					local bestPinType = FCOAB._bestPinType
					if normX ~= nil and normY ~= nil and ((bestPinType ~= nil and playerWaypointPinTypes[bestPinType]) or (newText and newText == yourPlayersWaypointStr)) then
						local lastPlayedWaypoint = lastPlayed.waypoint
						local waitTime = settings.compassPlayerWaypointSoundDelay * 1000

						--d("[FCOAB]ZO_CompassCenterOverPinLabel - Waypoint - waitTime: " ..tos(waitTime) .. ", " ..tos(newText) .. ", x: " ..tos(normX) .. ", y: " ..tos(normY))
						if lastPlayedWaypoint == 0 or now >= (lastPlayedWaypoint + waitTime) then
							lastPlayed.waypoint = now
							playSoundLoopNow(settings.compassPlayerWaypointSoundName, settings.compassPlayerWaypointSoundRepeat)
						end
					end
				end

				--Group rally point sound
				if settings.compassGroupRallyPointSound == true and settings.compassGroupRallyPointSoundName ~= CON_SOUND_NONE and IsUnitGrouped(CON_PLAYER) and hasRallyPoint() then
					--Your rallypoint is currently in the middle
					local normX, normY = gmrp()
					if normX ~= nil and normY ~= nil and newText and newText == rallyPointStr then
						local lastPlayedRallyPoint = lastPlayed.rallyPoint
						local waitTime = settings.compassGroupRallyPointSoundDelay * 1000

						if lastPlayedRallyPoint == 0 or now >= (lastPlayedRallyPoint + waitTime) then
							lastPlayed.rallyPoint = now
							playSoundLoopNow(settings.compassGroupRallyPointSoundName, settings.compassGroupRallyPointSoundRepeat)
						end
					end
				end

				--Active quest found?
				if settings.compassTrackedQuestSound == true and settings.compassTrackedQuestSoundName ~= CON_SOUND_NONE and lastTrackedQuestIndex ~= nil and lastTrackedQuestIndex ~= 0 then
					local questPinType = FCOAB._bestPinType
					local questPinDescription = FCOAB._bestPinDescription
					if questPinType ~= nil and (trackedQuestPinTypes[questPinType] or assistedQuestPinTypes[questPinType]) and questPinDescription ~= nil and newText and questPinDescription == newText then
						local lastPlayedQuest = lastPlayed.quest
						local waitTime = settings.compassTrackedQuestSoundDelay * 1000

						--d("[FCOAB]ZO_CompassCenterOverPinLabel - Quest - waitTime: " ..tos(waitTime) .. ", questPinType: " ..tos(questPinType) .. ", questPinDescription: " .. tos(questPinDescription) ..", newText: " ..tos(newText) .. ", lastTrackedQuestIndex: " ..tos(lastTrackedQuestIndex))
						if lastPlayedQuest == 0 or now >= (lastPlayedQuest + waitTime) then
							lastPlayed.quest = now
							playSoundLoopNow(settings.compassTrackedQuestSoundName, settings.compassTrackedQuestSoundRepeat)
						end
					end
				end
			end)
		end
	end


	--Quest tracker
	if compassTrackedQuestSound == true then
		local function onQuestTrackerTrackingStateChanged(questTracker, tracked, trackType, arg1, arg2)
			--d("[FCOAB]onQuestTrackerTrackingStateChanged-tracked: " ..tos(tracked) .. ", type: " ..tos(trackType) .. ", arg1: " ..tos(arg1) .. ", arg2: " ..tos(arg2))
			if trackType == TRACK_TYPE_QUEST and tracked == true then
				lastTrackedQuestIndex = arg1
				--Update the SavedVariables
				FCOAB.settingsVars.settings.lastTrackedQuestIndex = lastTrackedQuestIndex
				--local trackingLevel = GetTrackingLevel(TRACK_TYPE_QUEST, lastTrackedQuestIndex)

				-- @return questName string, backgroundText string, activeStepText string, activeStepType integer, activeStepTrackerOverrideText string, completed bool, tracked bool, questLevel integer, pushed bool, questType integer, instanceDisplayType [InstanceDisplayType|#InstanceDisplayType]
				lastTrackedQuestName, lastTrackedQuestBackgroundText, lastTrackedQuestActiveStepText = GetJournalQuestInfo(lastTrackedQuestIndex)
				--d(">index: " ..tos(lastTrackedQuestIndex) .. ", name: " ..tos(lastTrackedQuestName) .. ", backgroundText: " ..tos(lastTrackedQuestBackgroundText) .. ", activeStepText: " ..tos(lastTrackedQuestActiveStepText))
			end
		end
		FOCUSED_QUEST_TRACKER:RegisterCallback("QuestTrackerTrackingStateChanged", onQuestTrackerTrackingStateChanged)


		--Compass:OnUpdate call hooks
		local TIME_BETWEEN_LABEL_UPDATES_MS = 100

		local bestPinIndices = {}
		local bestPinDistances = {}

		local pinTypeToFormatId =
		{
			[MAP_PIN_TYPE_POI_SEEN] = SI_COMPASS_LOCATION_NAME_FORMAT,
			[MAP_PIN_TYPE_POI_COMPLETE] = SI_COMPASS_LOCATION_NAME_FORMAT,
		}

		function COMPASS:OnUpdate()
			local self = compass
			if self.areaOverrideAnimation:IsPlaying() then
				self.centerOverPinLabelAnimation:PlayBackward()
			elseif not self.centerOverPinLabelAnimation:IsPlaying() or not self.centerOverPinLabelAnimation:IsPlayingBackward() then
				local now = GetFrameTimeMilliseconds()
				if now < self.nextLabelUpdateTime then
					return
				end
				self.nextLabelUpdateTime = now + TIME_BETWEEN_LABEL_UPDATES_MS

				local bestPinDescription
				local bestPinType
				if not COMPASS_FRAME:GetBossBarActive() then
					ZO_ClearNumericallyIndexedTable(bestPinIndices)
					ZO_ClearNumericallyIndexedTable(bestPinDistances)
					for i = 1, self.container:GetNumCenterOveredPins() do
						if not self.container:IsCenterOveredPinSuppressed(i) then
							local drawLayer, drawLevel = self.container:GetCenterOveredPinLayerAndLevel(i)
							local layerInformedDistance = calculateLayerInformedDistance(drawLayer, drawLevel)
							local insertIndex
							for bestPinIndex = 1, #bestPinIndices do
								if layerInformedDistance < bestPinDistances[bestPinIndex] then
									insertIndex = bestPinIndex
									break
								end
							end
							if not insertIndex then
								insertIndex = #bestPinIndices + 1
							end

							table.insert(bestPinIndices, insertIndex, i)
							table.insert(bestPinDistances, insertIndex, layerInformedDistance)
						end
					end

					for i, centeredPinIndex in ipairs(bestPinIndices) do
						local description = self.container:GetCenterOveredPinDescription(centeredPinIndex)
						if description ~= "" then
							bestPinDescription = description
							bestPinType = self.container:GetCenterOveredPinType(centeredPinIndex)
							break
						end
					end

					--For debugging
					FCOAB._bestPinIndices = 	ZO_ShallowTableCopy(bestPinIndices)
					FCOAB._bestPinDistances = 	ZO_ShallowTableCopy(bestPinDistances)
					FCOAB._bestPinDescription = bestPinDescription
					FCOAB._bestPinType = 		bestPinType
				end

				if bestPinDescription then
					noCompassPinSelected = false
					local formatId = pinTypeToFormatId[bestPinType]
					--The first 3 types are the player pins (self, group, leader)
					if bestPinType < 3 then
						bestPinDescription = ZO_FormatUserFacingCharacterOrDisplayName(bestPinDescription)
					end
					if formatId then
						self.centerOverPinLabel:SetText(ZO_CachedStrFormat(formatId, bestPinDescription))
					else
						self.centerOverPinLabel:SetText(bestPinDescription)
					end

					self.centerOverPinLabelAnimation:PlayForward()
				else
					noCompassPinSelected = true
					--reset the last played sound time of waypoint, qeust etc. so that the next selected compass pin plays a sound directly again
					lastPlayed.waypoint = 0
					lastPlayed.rallyPoint = 0
					lastPlayed.quest = 0

					self.centerOverPinLabelAnimation:PlayBackward()
				end
			end
		end
	end
end

local function CreateWaypointHooks()
	SecurePostHook("SetMapPlayerWaypoint", function() --why isn't this called properly as a new waypoint is set?
--d("[FCOAB]PostHook SetMapPlayerWaypoint")
		--Auto remove wayshines update handler: Enable/or disable
		runWaypointRemoveUpdates(isWaypointSetAndShouldBeRemovedAutomaticallyByFCOAB(), true)
	end)

	--Gamepad map keybind for "Set waypoint" / "Ziel setzen"
	--[[
	local x, y = NormalizePreferredMousePositionToMap()
	if ZO_WorldMap_IsNormalizedPointInsideMapBounds(x, y) then
		PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, x, y)
		g_keybindStrips.gamepad:DoMouseEnterForPinType(MAP_PIN_TYPE_PLAYER_WAYPOINT) -- this should have been called by the mouseover update, but it's not getting called
	end
	]]
	SecurePostHook("PingMap", function(mapPinType, mapTypeLocation, x, y)
		if mapPinType == MAP_PIN_TYPE_PLAYER_WAYPOINT and mapTypeLocation == MAP_TYPE_LOCATION_CENTERED and ZO_WorldMap_IsNormalizedPointInsideMapBounds(x, y) then
--d("[FCOAB]PingMap MAP_PIN_TYPE_PLAYER_WAYPOINT - x: " ..tos(x) .. ", y: " ..tos(y))
			--Auto remove wayshines update handler: Enable/or disable
			runWaypointRemoveUpdates(isWaypointSetAndShouldBeRemovedAutomaticallyByFCOAB(), true)
		end
	end)


	--[[
	SecurePostHook("SetPlayerWaypointByWorldLocation", function() --only used for furniture/houses?
d("[FCOAB]PostHook SetPlayerWaypointByWorldLocation")
		--Auto remove wayshines update handler: Enable/or disable
		runWaypointRemoveUpdates(FCOAB.settingsVars.settings.autoRemoveWaypoint and hasWaypoint(), true)
	end)
	]]

	SecurePostHook("RemovePlayerWaypoint", function() --alos called from within ZO_WorldMap_RemovePlayerWaypoint
--d("[FCOAB]PostHook RemovePlayerWaypoint")
		--Auto remove wayshines update handler: Enable/or disable
		runWaypointRemoveUpdates(false, true)
	end)
end


local function onPlayerActivated()
	if FCOAB.settingsVars.settings.combatTipsToChat == true then
		enableActiveCombatTipsIfDisabled()
		--Is the addon AccountSettings enabled?
		if AccountSettings ~= nil then
			--AccountSettings will switch the settings to other account settings, but starting after 5seconds.
			--So we wait another +2 after that and change this setting again then
			local delay = 7000
			zo_callLater(function() enableActiveCombatTipsIfDisabled() end, delay)
		end
	end

	--Auto remove waypoints if reached?
	runWaypointRemoveUpdates(isWaypointSetAndShouldBeRemovedAutomaticallyByFCOAB(), true)

	--Play sound for group leader handler: Enable/or disable
	if isGroupedAndGroupLeaderGivenAndShouldSoundPlayByFCOAB() then
		onGroupStatusChange(false, false, false, true)
	end
end


------------------------------------------------------------------------------------------------------------------------
local function CreateReticleHooks()
	reticleUnitData()
	interactionData()
end

local function CreateGroupHooks()
	--Player is promoting someone else to the leader? EVENT_GROUP_UPDATE won't fire then...
	-->So simulate it
	SecurePostHook("GroupPromote", function(unitTag)
		--Delay a bit to let group update happen
		zo_callLater(function()
			if isGroupedAndGroupLeaderGivenAndShouldSoundPlayByFCOAB() then
				onGroupStatusChange(false, false, false, true)
			end
		end, 1000)
	end)
end

--Create the hooks & pre-hooks
local function CreateHooks()
	--other compass hooks
	CreateCompassHooks()

	--other player waypoint related hooks
	CreateWaypointHooks()

	--other hooks for the reticle
	CreateReticleHooks()

	--Group hooks
	CreateGroupHooks()

	--React on an input mode change keyboard->gamepad->keyboard and register the needed hooks
	--EM:RegisterForEvent(addonName .. "_EVENT_INPUT_TYPE_CHANGED", EVENT_INPUT_TYPE_CHANGED, onEventInputTypeChanged)
end

--Register the slash commands
local function RegisterSlashCommands()
    -- Register slash commands
	SLASH_COMMANDS["/FCOAccessibility"] 	= command_handler
	SLASH_COMMANDS["/fcna"] 				= command_handler
end

--Load the SavedVariables
local function LoadUserSettings()
--The default values for the language and save mode
    FCOAB.settingsVars.firstRunSettings = {
        --language 	 		    = 1, --Standard: English
        saveMode     		    = 2, --Standard: Account wide FCOAB.settingsVars.settings
    }

    --Pre-set the deafult values
    FCOAB.settingsVars.defaults = {
		thisAddonLAMSettingsSetFuncToChat = true,

		--From Circonian's WaypointIt addon!
		["WAYPOINT_DELTA_SCALE"] = 3,
		["WAYPOINT_DELTA_SCALE_MAX"] = 5000,

		--Last * data stored in SV
		lastTrackedQuestIndex = 0,
		currentWaypoint = nil,

		--FCOAB adddon settings
		chatAddonPrefix = "´", --read as Akut

		compassTrackedQuestSound = true,
		compassTrackedQuestSoundName = "Backpack_Open",
		compassTrackedQuestSoundDelay = 3,
		compassTrackedQuestSoundRepeat = 2,

		compassPlayerWaypointSound = true,
		compassPlayerWaypointSoundName = "Click_Edit",
		compassPlayerWaypointSoundDelay = 3,
		compassPlayerWaypointSoundRepeat = 2,

		compassGroupRallyPointSound = true,
		compassGroupRallyPointSoundName = "Housing_StoreItem",
		compassGroupRallyPointSoundDelay = 3,
		compassGroupRallyPointSoundRepeat = 2,

		compassToChatText = true,

		reticleUnitToChatText = true,
		reticlePlayerToChatText = true,
		reticleInteractionToChatText = true,

		autoRemoveWaypoint = true,

		groupLeaderSound = true,
		groupLeaderSoundName = "Champion_StarStageUp",
		groupLeaderSoundDelay = 3,
		groupLeaderSoundRepeat = 2,
		groupLeaderSoundDistance = 3, --meters
		groupLeaderDistanceToChat = false,
		groupLeaderSoundAngle = 20, --degree, 20°

		combatStartEndInfo = true,

		combatStartSound = true,
		combatStartSoundName = "Tribute_Summary_ProgressBarIncrease",
		combatStartSoundRepeat = 4,

		combatEndSound = true,
		combatEndSoundName = "Tribute_Summary_ProgressBarDecrease",
		combatEndSoundRepeat = 4,

		combatTipToChat = true,

		showReticleOverUnitHealthInChat = true,
    }
	local defaults = FCOAB.settingsVars.defaults

	local worldName = GetWorldName()
	local addonSavedVariablesName = addonVars.addonSavedVariablesName
	local addonSavedVariablesVersion = addonVars.addonSavedVariablesVersion

--=============================================================================================================
--	LOAD USER SETTINGS
--=============================================================================================================
    --Load the user's FCOAB.settingsVars.settings from SavedVariables file -> Account wide of basic version 999 at first
	FCOAB.settingsVars.defaultSettings = ZO_SavedVars:NewAccountWide(addonSavedVariablesName, 999, "SettingsForAll", FCOAB.settingsVars.firstRunSettings, worldName)

	--Check, by help of basic version 999 FCOAB.settingsVars.settings, if the FCOAB.settingsVars.settings should be loaded for each character or account wide
    --Use the current addon version to read the FCOAB.settingsVars.settings now
	if (FCOAB.settingsVars.defaultSettings.saveMode == 1) then
    	FCOAB.settingsVars.settings = ZO_SavedVars:NewCharacterIdSettings(addonSavedVariablesName, addonSavedVariablesVersion, "Settings", defaults, worldName)
	else
		FCOAB.settingsVars.settings = ZO_SavedVars:NewAccountWide(addonSavedVariablesName, addonSavedVariablesVersion, "Settings", defaults, worldName, nil)
	end
--=============================================================================================================

	--Update the last tracked questInded
	if FCOAB.settingsVars.settings.lastTrackedQuestIndex ~= 0 then
		lastTrackedQuestIndex = FCOAB.settingsVars.settings.lastTrackedQuestIndex
		lastTrackedQuestName, lastTrackedQuestBackgroundText, lastTrackedQuestActiveStepText = GetJournalQuestInfo(lastTrackedQuestIndex)
	end
end

--Addon loads up
local function FCOAccessibility_Loaded(eventCode, addOnNameOfEachAddonLoaded)
	--Is this addon found?
	if addOnNameOfEachAddonLoaded ~= addonName then return end
	--Unregister this event again so it isn't fired again after this addon has beend reckognized
	EM:UnregisterForEvent(addonName .. "_EVENT_ADD_ON_LOADED", EVENT_ADD_ON_LOADED)

	addonVars.gAddonLoaded = false

	LAM = LibAddonMenu2
	GPS = LibGPS3

	--SavedVariables
	LoadUserSettings()

	--Show the menu
	BuildAddonMenu()

	--Create the hooks
	CreateHooks()

	-- Register slash commands
	--RegisterSlashCommands()

	--Events
	--Player Activated/Zone change with laoding screen (e.g. after Port to Group Leader)
	EM:RegisterForEvent(addonName .. "_EVENT_PLAYER_ACTIVATED",			EVENT_PLAYER_ACTIVATED,		onPlayerActivated)

	--Death
	EM:RegisterForEvent(addonName .. "_EVENT_PLAYER_ALIVE",				EVENT_PLAYER_ALIVE,			onPlayerActivated)
	EM:RegisterForEvent(addonName .. "_EVENT_PLAYER_DEAD",				EVENT_PLAYER_DEAD,			function() onGroupStatusChange(false, false, true, false) end)

	--Group
	EM:RegisterForEvent(addonName .. "_EVENT_GROUP_MEMBER_LEFT", 		EVENT_GROUP_MEMBER_LEFT, 	function() onGroupStatusChange(true, false, false, false) end)
	EM:RegisterForEvent(addonName .. "_EVENT_GROUP_MEMBER_JOINED", 		EVENT_GROUP_MEMBER_JOINED, 	function() onGroupStatusChange(false, true, false, false) end)
	EM:RegisterForEvent(addonName .. "_EVENT_GROUP_UPDATE", 			EVENT_GROUP_UPDATE, 		function() onGroupStatusChange(false, false, true, false) end)

	--Combat
	EM:RegisterForEvent(addonName .. "_EVENT_PLAYER_COMBAT_STATE", 		EVENT_PLAYER_COMBAT_STATE, 	onPlayerCombatState)
	EM:RegisterForEvent(addonName .. "_EVENT_DISPLAY_ACTIVE_COMBAT_TIP", EVENT_DISPLAY_ACTIVE_COMBAT_TIP, function(_, tipId)
		--Chat output for the combat tipId
		showCombatTipInChat(tipId)
	end)
	--[[
	EM:RegisterForEvent(addonName .. "_EVENT_REMOVE_ACTIVE_COMBAT_TIP", EVENT_REMOVE_ACTIVE_COMBAT_TIP, function(_, tipId)
	end)
	]]


	addonVars.gAddonLoaded = true
end

-- Register the event "addon loaded" for this addon
local function FCOAccessibility_Initialized()
	EM:RegisterForEvent(addonName .. "_EVENT_ADD_ON_LOADED", EVENT_ADD_ON_LOADED, 					FCOAccessibility_Loaded)
end


--------------------------------------------------------------------------------
--- Call the start function for this addon to register events etc.
--------------------------------------------------------------------------------
FCOAccessibility_Initialized()



--Mount on multi mount:
--/tb UseMountAsPassenger("@Zardek-TESO")