local VERSION = "1.31"
local MODULE_ROOM = "*#mckeydown fs %s"
local admins = {
  ["Mckeydown#0000"] = 10,
  ["Lays#1146"] = 10,
}
local maps = {
  7954539,
  7954420,
  7954412,
  7951350,
}

local settings = {
  throwables = false,
  auto_respawn = true,
  timeup_msg = true,
  --theme_ui = false,
  mapname_theme = true,
  allow_npc = false,
  allow_skills = true,
  auto_cp = true,
  allow_join = true,
  auto_color = true,
  time_warning = true,
  log_npc = false,
  log_admin_joins = false,
  log_participant_joins = false,
}

local mapName
local backgroundColor
local roomPlayers = {}
local bans = {}
local participants = {}
local tpTarget = {}
local holdingShift = {}
local canTeleport = {}
local playerNPC = {}
local playerNPCPos = {}
local arrowEnabled = {}
local arrowAllowTime = {}
local deathPosition = {}
local colorTarget = {}
local participantsColor = 0xffe249
local participantOutColor = 0xCB546B
local defaultGravity, defaultWind, mapGravity, mapWind
local defaultFreeze
local currentTheme = 'TBD'
local timeWarningMessage = 'There is less than 1 minute left...'
local timeupMessage = 'Time is up!'
local timeupMessageShown
local lastMinuteWarningShown

local lastMapCode
local loadMapCode, loadMapReversed

do
  local nextLoadTime
  local newGame = tfm.exec.newGame

  function tfm.exec.newGame(mapCode, flipped)
    if not mapCode then
      return
    end

    if nextLoadTime and os.time() < nextLoadTime then
      loadMapCode, loadMapReversed = mapCode, flipped
      return
    end

    nextLoadTime = os.time() + 3100
    loadMapCode, loadMapReversed = nil, nil
    newGame(mapCode, flipped)
  end
end


local function sendModuleMessage(text, playerName)
  tfm.exec.chatMessage("<BL>[module] <N>" .. tostring(text), playerName)
end

local function initPlayer(playerName)
  roomPlayers[playerName] = true

  system.bindMouse(playerName, true)
  tfm.exec.bindKeyboard(playerName, 16, true, true)
  tfm.exec.bindKeyboard(playerName, 16, false, true)
  tfm.exec.bindKeyboard(playerName, 77, true, true)
  tfm.exec.bindKeyboard(playerName, 46, true, true)

  local room = tfm.get.room
  local player = room.playerList[playerName]
  local tribeName = room.name:sub(3)
  local isGuest = playerName:find('*')

  if not isGuest and player then
    if room.name:find(playerName) or room.isTribeHouse and player.tribeName == tribeName then
      admins[playerName] = 6
    end
  end

  eventChatCommand(playerName, "help")
end

local function newRandomMap(reversed)
  tfm.exec.newGame(maps[math.random(1, #maps)], reversed)
end

local function disableStuff()
  tfm.exec.disableAfkDeath(true)
  tfm.exec.disableAutoScore(true)
  tfm.exec.disableAutoShaman(true)
  tfm.exec.disableAutoNewGame(true)
  tfm.exec.disableAutoTimeLeft(true)
  tfm.exec.disableAllShamanSkills(not settings.allow_skills)
  tfm.exec.disablePhysicalConsumables(not settings.throwables)
  system.disableChatCommandDisplay(nil, true)
end

local function doesItMeanReversed(str)
  if str then
    str = str:lower()
    return ('reversed'):find(str) == 1 or ('mirrored'):find(str) == 1 or str == 'yes'
  end
end

local function multiTargetCall(targetName, fnc, ...)
  if not targetName then
    return
  end

  local multi = targetName:lower()
  if multi == 'all' or multi == 'room' then
    for targetName in next, roomPlayers do
      fnc(targetName, ...)
    end
    return
  end

  if multi == 'admins' then
    for targetName in next, roomPlayers do
      if admins[targetName] then
        fnc(targetName, ...)
      end
    end
    return
  end

  if multi == 'players' then
    for targetName in next, roomPlayers do
      if not admins[targetName] then
        fnc(targetName, ...)
      end
    end
    return
  end

  if multi == 'out' then
    for targetName in next, roomPlayers do
      if not admins[targetName] and not participants[targetName] then
        fnc(targetName, ...)
      end
    end
    return
  end

  if multi == 'participants' or multi == 'in' then
    for targetName, yes in next, participants do
      if yes then
        fnc(targetName, ...)
      end
    end
    return
  end

  fnc(targetName, ...)
end

local function updateThemeUI()
  if settings.mapname_theme then
    ui.setMapName(mapName)
  end

  if settings.theme_ui then
    ui.addTextArea(
      666,
      ('<font color="#%6x">Theme: %s'):format(
        0xffffff,
        currentTheme:gsub('&', '&amp;'):gsub('\\', '\\\\'):gsub('<', '&lt;')
      ),
      nil,
      100, 100,
      nil, nil,
      1, 0, 0.8, true
    )
  else
    ui.removeTextArea(666, nil)
  end
end

local function announceAdmins(message)
  for adminName in next, admins do
    if roomPlayers[adminName] then
      tfm.exec.chatMessage(message, adminName)
    end
  end
end

local function chatMessageList(playerName, list, max, pre)
  for i=1, #list, max do
    tfm.exec.chatMessage(pre .. table.concat(list, ' ', i, math.min(#list, i + max - 1)), playerName)
  end
end


local allowCommandForEveryone = {
  ["version"] = true,
  ["mapinfo"] = true,
  ["commands"] = true,
  ["help"] = true,
  ["admins"] = true,
  ["theme"] = true,
  ["npc"] = true,
  ["join"] = true,
  ["leave"] = true,
  ["participants"] = true,
  ["room"] = true,
}
local commands = {}
local commandAlias = {}

commands.room = function(playerName, args)
  sendModuleMessage("You can create your room by typing\n<BL>/room " .. MODULE_ROOM:format(playerName), playerName)

  if args[1] ~= 'onlymine' then
    local roomName = tfm.get.room.name

    if roomName:sub(1, 1) ~= '@' and roomName:sub(1, 1) ~= '*' then
      roomName = ('%s <J>(%s)'):format(roomName, tfm.get.room.community)
    end

    sendModuleMessage("You are currently in\n<BL>/room " .. roomName, playerName)
  end
end

commands.help = function(playerName, args)
  tfm.exec.chatMessage("<N>This is a small utility module made for fashion shows. You can type <BL>!commands <N>to see available commands.", playerName)

  if not admins[playerName] then
    eventChatCommand(playerName, 'room onlymine')

    if settings.allow_join then
      tfm.exec.chatMessage("<N>If you are here for a fashion show, type <BL>!join <N>to participate.", playerName)
    end
  end
end

commands.mapinfo = function(playerName, args)
  sendModuleMessage(tostring(lastMapCode), playerName)
end

commands.version = function(playerName, args)
  sendModuleMessage("fs v" .. VERSION .. ' ~ Lays#1146', playerName)
end
commandAlias.v = commands.version

commands.commands = function(playerName, args)
  local list = {}

  if admins[playerName] then
    for commandName in next, commands do
      list[1 + #list] = commandName
    end
  else
    for commandName in next, allowCommandForEveryone do
      list[1 + #list] = commandName
    end
  end

  table.sort(list)
  sendModuleMessage('Available commands: <BL>' .. table.concat(list, ', '), playerName)
  sendModuleMessage('You can use the following targets in most of the commands: <BL>all room admins players out in/participants', playerName)
end
commandAlias.cmds = commands.commands

commands.participants = function(playerName, args)
  local inRoom, outRoom, removed = {}, {}, {}
  for name, yes in next, participants do
    if yes then
      if roomPlayers[name] then
        inRoom[1 + #inRoom] = name
      else
        outRoom[1 + #outRoom] = name
      end
    else
      removed[1 + #removed] = name
    end
  end
  sendModuleMessage("Participants:", playerName)
  chatMessageList(playerName, inRoom, 10, '<V>')
  chatMessageList(playerName, outRoom, 10, '<G>')
  chatMessageList(playerName, removed, 10, '<R>')
  return true
end

commands.admins = function(playerName, args)
  local list = {}
  for name, level in next, admins do
    if level < 7 or roomPlayers[name] then
      list[1 + #list] = name
    end
  end
  sendModuleMessage("Admins:", playerName)
  chatMessageList(playerName, list, 10, '<V>')
  return true
end

commands.bans = function(playerName, args)
  local list = {}
  for name in next, bans do
    list[1 + #list] = name
  end
  sendModuleMessage("Ban list:", playerName)
  chatMessageList(playerName, list, 10, '<V>')
  return true
end
commandAlias.banlist = commands.bans

commands.map = function(playerName, args)
  local code, perm

  if args[1] then
    code = args[1]:match('^@?%d+$')
    perm = args[1]:match('^#%d+$')
  end

  if not code and not perm then
    newRandomMap(doesItMeanReversed(args[1]))
    return
  end

  tfm.exec.newGame(code or perm, doesItMeanReversed(args[2]))
end

commands.rst = function(playerName, args)
  local info = tfm.get.room.xmlMapInfo
  if (info and info.author == "#Module") or args[1] == 'xml' then
    if info and info.xml then
      tfm.exec.newGame(info.xml, doesItMeanReversed(args[1]) or doesItMeanReversed(args[2]))
    end
  else
    tfm.exec.newGame(tfm.get.room.currentMap, doesItMeanReversed(args[1]))
  end
end
commandAlias.reset = commands.rst
commandAlias.restart = commands.rst

commands.time = function(playerName, args)
  local time = args[1]
  if not time then
    sendModuleMessage('Usage: <BL>!time [seconds]', playerName)
    return true
  end

  if time then
    local minutes = tonumber(time:lower():match('^(%d+)m$'))
    time = minutes and (minutes * 60) or tonumber(time)
  end

  if time > 60 then
    lastMinuteWarningShown = false
  end

  timeupMessageShown = false
  tfm.exec.setGameTime(time, true)
end

commands.size = function(playerName, args)
  local size = tonumber(args[2]) or 1

  multiTargetCall(args[1], tfm.exec.changePlayerSize, size)
end

commands.color = function(playerName, args)
  local target = args[1]
  local color = args[2] and tonumber(args[2], 16)

  if color then
    if target == 'participants' or target == 'in' then
      participantsColor = color
    elseif target == 'out' then
      participantOutColor = color
    end

    multiTargetCall(target, tfm.exec.setNameColor, color)
  else
    colorTarget[playerName] = target or playerName
    ui.showColorPicker(444, playerName, 0, "Pick a color for name color:")
    return true
  end
end
commandAlias.name = commands.color

commands.snow = function(playerName, args)
  local duration = tonumber(args[1])
  local snowballPower = tonumber(args[2])
  tfm.exec.snow(duration, snowballPower)
end

commands.mapname = function(playerName, args)
  if args[1] then
    mapName = args[-1]
    ui.setMapName(mapName)
  else
    mapName = nil

    local info = tfm.get.room.xmlMapInfo
    ui.setMapName(info and ('%s <BL>- %s'):format(info.author, tfm.get.room.currentMap) or tfm.get.room.currentMap)
  end
end

local function removeNPC(playerName)
  if not playerNPC[playerName] then
    return
  end

  playerNPC[playerName] = nil
  playerNPCPos[playerName] = nil
  tfm.exec.addNPC(playerName, {
    look = '-1;',
    x = -10000,
    y = -10000,
  })
end
local function createNPC(playerName, look, keepPos)
  local player = tfm.get.room.playerList[playerName]
  if not player then
    return
  end

  if not look or look:find(';') then
    look = look or player.look
  else
    look = (playerNPC[playerName] or '') .. look
  end

  if #look > 4096 then
    return
  end

  local pos = keepPos and playerNPCPos[playerName] or {
    x = player.x,
    y = player.y,
  }

  playerNPC[playerName] = look
  playerNPCPos[playerName] = pos
  tfm.exec.addNPC(playerName, {
    title = player.title,
    look = look,
    x = pos.x,
    y = pos.y,
    female = player.gender == 0,
    lookLeft = not player.isFacingRight,
    lookAtPlayer = true,
  })
end
commands.removenpc = function(playerName, args)
  multiTargetCall(args[1] or playerName, removeNPC)
end
commands.copynpc = function(playerName, args)
  multiTargetCall(args[1] or playerName, createNPC)
end
commands.npc = function(playerName, args)
  if not admins[playerName] and (not settings.allow_npc or not participants[playerName]) then
    sendModuleMessage('<R>You are not allowed to create NPC', playerName)
    return
  end

  if not args[1] then
    createNPC(playerName)
    return
  end

  local look = args[-1]
  if look == 'remove' then
    removeNPC(playerName)
    return
  end

  local targetPlayer = tfm.get.room.playerList[look]
  if targetPlayer then
    if admins[playerName] then
      look = targetPlayer.look
    else
      sendModuleMessage('<R>Only admins can copy outfits', playerName)
      return
    end
  end

  createNPC(playerName, look)

  if settings.log_npc then
    announceAdmins(("<V>[%s] <BL>!npc %s"):format(playerName, args[-1]))
  end
end
commandAlias.dressing = commands.npc

commands.timeup = function(playerName, args)
  if not args[1] then
    sendModuleMessage('Changes time is up message: <BL>!timeup [message]', playerName)
    return true
  end

  timeupMessage = args[-1]
end

commands.timewarning = function(playerName, args)
  if not args[1] then
    sendModuleMessage('Changes last 1 minute warning message: <BL>!timewarning [message]', playerName)
    return true
  end

  timeWarningMessage = args[-1]
end

commands.newtheme = function(playerName, args)
  if not args[1] then
    sendModuleMessage('Usage: <BL>!newtheme [theme]', playerName)
    return true
  end

  currentTheme = args[-1]

  if settings.mapname_theme then
    mapName = 'Theme: ' .. currentTheme
  end

  updateThemeUI()
  sendModuleMessage('New Theme: <J>' .. currentTheme, nil)
end

commands.theme = function(playerName, args)
  sendModuleMessage('Theme: ' .. currentTheme, playerName)
end

commands.t = function(playerName, args)
  if not args[1] then
    sendModuleMessage('Usage: <BL>!t [admin chat message]', playerName)
    return true
  end

  announceAdmins(("<N2>• <b>[%s]</b> %s"):format(playerName, args[-1]))
  return true
end
commandAlias.c = commands.t
commandAlias.a = commands.t

commands.announce = function(playerName, args)
  if not args[1] then
    sendModuleMessage('Usage: <BL>!t [announce message]', playerName)
    return true
  end

  tfm.exec.chatMessage(("<S><b>[%s]</b> %s"):format(playerName, args[-1]), nil)
  return true
end

commands.lock = function(playerName, args)
  local limit = math.min(math.max(tonumber(args[1]) or 50, 1), 100)
  tfm.exec.setRoomMaxPlayers(limit)
  sendModuleMessage('Room has been locked to ' .. limit .. ' mice.', nil)
end

commands.pw = function(playerName, args)
  local password = args[-1]
  tfm.exec.setRoomPassword(password)
  sendModuleMessage('Room password has been changed.', nil)
end

commands.grav = function(playerName, args)
  mapWind = tonumber(args[2]) or defaultWind
  mapGravity = tonumber(args[1]) or defaultGravity
  tfm.exec.setWorldGravity(mapWind, mapGravity)
end
commandAlias.gravity = commands.grav

commands.admin = function(playerName, args)
  local targetName = args[1]
  if not targetName then
    sendModuleMessage('Usage: <BL>!admin [target]', playerName)
    return
  end

  if admins[targetName] and admins[targetName] >= admins[playerName] then
    return
  end

  if targetName == "all" or targetName == "room" then
    for targetName in next, roomPlayers do
      if not admins[targetName] then
        admins[targetName] = 5
      end
    end
    return
  end

  admins[targetName] = 5
end

commands.unadmin = function(playerName, args)
  local targetName = args[1]
  if not targetName then
    sendModuleMessage('Usage: <BL>!unadmin [target]', playerName)
    return
  end

  if admins[targetName] and admins[targetName] >= admins[playerName] then
    return
  end

  if targetName == "all" then
    local list = {}
    local playerPermLevel = admins[playerName]

    for targetName, level in next, admins do
      if level < playerPermLevel then
        list[1+#list] = targetName
      end
    end

    for i=1, #list do
      admins[list[i]] = nil
    end
    return
  end

  if targetName == "room" then
    for targetName in next, roomPlayers do
      if admins[targetName] and admins[targetName] < admins[playerName] then
        admins[targetName] = nil
      end
    end
    return
  end

  admins[targetName] = nil
end
commandAlias.deadmin = commands.unadmin

commands.arrow = function(playerName, args)
  if args[1] == 'on' then
    arrowEnabled[playerName] = 'on'
  elseif args[1] == 'off' then
    arrowEnabled[playerName] = nil
  else
    arrowEnabled[playerName] = true
  end
end

commands.shamode = function(playerName, args)
  local mode = args[1]

  if mode == 'normal' then
    mode = 0
  elseif mode == 'hard' then
    mode = 1
  elseif mode == 'div' or mode == 'divinity' then
    mode = 2
  else
    mode = tonumber(args[1])
  end

  if not mode then
    sendModuleMessage('Usage: <BL>!shamode [normal/hard/divinity/div]', playerName)
    return
  end

  tfm.exec.setShamanMode(playerName, mode)
end

commands.score = function(playerName, args)
  local score = tonumber(args[2]) or 0

  multiTargetCall(args[1] or playerName, tfm.exec.setPlayerScore, score, false)
end

commands.kill = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.killPlayer)
end

commands.respawn = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.respawnPlayer)
end

commands.sham = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.setShaman, true)
end
commandAlias.shaman = commands.sham

commands.unsham = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.setShaman, false)
end
commandAlias.unshaman = commands.unsham

commands.meep = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.giveMeep, true)
end

commands.unmeep = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.giveMeep, false)
end

commands.transform = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.giveTransformations, true)
end

commands.untransform = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.giveTransformations, false)
end

commands.vampire = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.setVampirePlayer, true)
end

commands.unvampire = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.setVampirePlayer, false)
end

commands.tp = function(playerName, args)
  if args[1] == 'off' then
    tpTarget[playerName] = nil
  end

  tpTarget[playerName] = args[1] or playerName
end

commands.tpp = function(playerName, args)
  local sourceName = args[1]
  local destName = args[2]
  local destPlayer = destName and tfm.get.room.playerList[destName]

  if not destPlayer then
    sendModuleMessage('Usage: <BL>!tpp [target] [toPlayer]', playerName)
    return
  end

  local function moveToTarget(sourceName)
    tfm.exec.movePlayer(sourceName, destPlayer.x, destPlayer.y)
  end

  multiTargetCall(args[1], moveToTarget)
end

local function setAllowTeleport(playerName, yes)
  canTeleport[targetName] = yes
end

commands.cantp = function(playerName, args)
  if not args[1] then
    sendModuleMessage('Usage: <BL>!cantp [target] (no)', playerName)
    return true
  end

  local yes = args[2] ~= 'no' or nil

  if args[1] == 'all' and not yes then
    canTeleport = {}
  end

  multiTargetCall(args[1], setAllowTeleport, yes)
end

commands.link = function(playerName, args)
  local playerName1 = args[1]
  local playerName2 = args[2]

  if not playerName1 then
    sendModuleMessage('Usage: <BL>!link [player1] [player2]', playerName)
    return true
  end

  if playerName1 and playerName2 then
    tfm.exec.linkMice(playerName1, playerName2, true)
  end
end

commands.unlink = function(playerName, args)
  local playerName1 = args[1]
  local playerName2 = args[2] or playerName1

  if not playerName1 then
    sendModuleMessage('Usage: <BL>!unlink [all/player1] ([player2])', playerName)
    return true
  end

  if playerName1 == "all" then
    for name in next, roomPlayers do
      tfm.exec.linkMice(name, name, false)
    end
    return
  end

  tfm.exec.linkMice(playerName1, playerName2, false)
end

commands.freeze = function(playerName, args)
  if args[1] == "all" then
    defaultFreeze = true
  end
  multiTargetCall(args[1] or playerName, tfm.exec.freezePlayer, true)
end

commands.unfreeze = function(playerName, args)
  if args[1] == "all" then
    defaultFreeze = false
  end
  multiTargetCall(args[1] or playerName, tfm.exec.freezePlayer, false)
end

commands.cheese = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.giveCheese)
end

commands.uncheese = function(playerName, args)
  multiTargetCall(args[1] or playerName, tfm.exec.removeCheese)
end

local function setNightmode(targetName, on)
  tfm.exec.setPlayerNightMode(on, targetName)
end
commands.nightmode = function(playerName, args)
  multiTargetCall(args[1] or playerName, setNightmode, args[2] ~= 'off' and args[2] ~= 'no')
end

local function playerVictory(targetName)
  tfm.exec.giveCheese(targetName)
  tfm.exec.playerVictory(targetName)
end
commands.win = function(playerName, args)
  multiTargetCall(args[1] or playerName, playerVictory)
end

commands.sy = function(playerName, args)
  tfm.exec.setPlayerSync(args[1])
end

commands.clear = function(playerName, args)
  local startId = tonumber(args[1])
  local endId = tonumber(args[2])

  if startId then
    if startId >= 0 and endId and endId >= startId and endId - startId < 102 then
      for objId=startId, endId do
        tfm.exec.removeObject(objId)
      end
    else
      sendModuleMessage('<R>Invalid object id range', playerName)
    end
    return
  end

  local list = {}
  for objId in next, tfm.get.room.objectList do
    list[1 + #list] = objId
  end

  for i=1, #list do
    tfm.exec.removeObject(list[i])
  end
end

commands.settings = function(playerName, args)
  local key = args[1]
  if not key or settings[key] == nil then
    local list = {}
    for key in next, settings do
      list[1 + #list] = key
    end
    table.sort(list)
    sendModuleMessage('Available settings:', playerName)
    for i=1, #list do
      tfm.exec.chatMessage(('%s = %s'):format(list[i], settings[list[i]] and 'yes' or 'no'), playerName)
    end
    return true
  end

  local value = args[2]
  if value then
    value = ('yes'):find(value) == 1
  else
    value = not settings[key]
  end

  settings[key] = value
  sendModuleMessage(key ..' = ' .. (value and 'yes' or 'no'), playerName)
  disableStuff()
  updateThemeUI()
end
commandAlias.set = commands.settings

local function updateParticipant(playerName, status)
  if participants[playerName] == status then
    return
  end

  if status == false and not participants[playerName] and not roomPlayers[playerName] then
    return
  end

  participants[playerName] = status

  if status then
    sendModuleMessage('<V>' .. playerName .. ' <N>has joined the show.', nil)

    if settings.allow_npc then
      sendModuleMessage('You can type <BL>!npc [/dressing code here] <N>to create an NPC wearing a fit you created in /dressing or in external dress room tools.', playerName)
    end
  elseif status == false then
    sendModuleMessage('<V>' .. playerName .. ' <N>has been removed from the show.', nil)
  else
    sendModuleMessage('<V>' .. playerName .. ' <N>has left the show.', nil)
  end

  if settings.auto_color then
    if status then
      tfm.exec.setNameColor(playerName, participantsColor)
    else
      tfm.exec.setNameColor(playerName, participantOutColor)
    end
  end
end

local function banPlayer(targetName, yes)
  bans[targetName] = yes

  if yes then
    updateParticipant(targetName, false)
    tfm.exec.killPlayer(targetName)
  elseif settings.auto_respawn then
    tfm.exec.respawnPlayer(targetName)
  end
end

commands.ban = function(playerName, args)
  multiTargetCall(args[1], banPlayer, true)
end

commands.unban = function(playerName, args)
  if args[1] == "all" then
    bans = {}
  end

  multiTargetCall(args[1], banPlayer, nil)
end

commands.join = function(playerName, args)
  if not settings.allow_join or participants[playerName] ~= nil then
    sendModuleMessage('<R>You cannot join the show right now.', playerName)
    return
  end

  updateParticipant(playerName, true)
end

commands.leave = function(playerName, args)
  if not participants[playerName] then
    return
  end

  updateParticipant(playerName, nil)
end

commands.add = function(playerName, args)
  multiTargetCall(args[1], updateParticipant, true)
end

commands.remove = function(playerName, args)
  if args[1] == "all" then
    participants = {}
    sendModuleMessage('<N>Participants list has been cleaned.', nil)

    if settings.auto_color then
      for name in next, roomPlayers do
        tfm.exec.setNameColor(playerName, participantOutColor)
      end
    end

    return
  end

  multiTargetCall(args[1], updateParticipant, false)
end

commands.group = function(playerName, args)
  local number = tonumber(args[1])
  if not number then
    sendModuleMessage('Usage: <BL>!group [size] (private)', playerName)
    return
  end

  if number < 1 then
    sendModuleMessage('._.', playerName)
    return
  end

  local list = {}
  for name, yes in next, participants do
    if yes then
      list[1 + #list] = name
    end
  end

  local target = args[2] == 'private' and playerName or nil

  sendModuleMessage(('Random groups of %s:'):format(number), target)

  local count = math.ceil(#list / number)
  local index, group
  for i=1, count do
    group = {}

    for j=1, number do
      if #list == 0 then
        break
      end
      index = math.random(#list)
      group[j] = list[index]
      list[index] = list[#list]
      list[#list] = nil
    end

    chatMessageList(target, group, 10, ('<N>Group-%s: <V>'):format(i))
  end
end

commands.bgcolor = function(playerName, args)
  backgroundColor = args[1] and ("#" .. args[1]) or nil
  ui.setBackgroundColor(backgroundColor)
end


function eventNewGame()
  -- sometimes it bugs so we refresh it every round
  disableStuff()

  timeupMessageShown = false
  lastMinuteWarningShown = false
  playerNPC = {}
  playerNPCPos = {}

  if lastMapCode ~= tfm.get.room.currentMap then
    deathPosition = {}
  end

  local info = tfm.get.room.xmlMapInfo
  if info and info.xml then
    local xml = info.xml
    local properties = info.xml:match('<P( .-)/>')

    if info.author ~= '#Module' then
      lastMapCode = tfm.get.room.currentMap
    end

    if properties then
      if info.author ~= '#Module' and properties:find(' reload=""') then
        tfm.exec.newGame(xml, tfm.get.room.mirroredMap)
      else
        local wind, gravity = properties:match(' G="(.-),(.-)"')
        defaultWind = tonumber(wind) or 0
        defaultGravity = tonumber(gravity) or 10

        backgroundColor = properties:match(' bgcolor="(.-)"') or backgroundColor
        ui.setBackgroundColor(backgroundColor)
      end
    end
  end

  if mapName then
    ui.setMapName(mapName)
  end

  for playerName in next, roomPlayers do
    if bans[playerName] then
      tfm.exec.killPlayer(playerName)
    end
  end
end

function eventLoop(elapsedTime, remainingTime)
  if loadMapCode then
    tfm.exec.newGame(loadMapCode, loadMapReversed)
  end

  if remainingTime < 60000 and remainingTime > 50000 and settings.time_warning and not lastMinuteWarningShown then
    lastMinuteWarningShown = true
    sendModuleMessage('<R>' .. timeWarningMessage, nil)
  elseif remainingTime < 0 and settings.timeup_msg and not timeupMessageShown then
    timeupMessageShown = true
    sendModuleMessage('<R>' .. timeupMessage, nil)
  end
end

function eventNewPlayer(playerName)
  initPlayer(playerName)

  if backgroundColor then
    ui.setBackgroundColor(backgroundColor)
  end

  if mapName then
    ui.setMapName(mapName)
  end

  updateThemeUI()

  if mapWind and mapGravity then
    tfm.exec.setWorldGravity(mapWind, mapGravity)
  end

  if not bans[playerName] then
    if settings.auto_respawn then
      tfm.exec.respawnPlayer(playerName)
    end
  end

  for targetName, look in next, playerNPC do
    createNPC(targetName, look, true)
  end

  if admins[playerName] and settings.log_admin_joins then
    announceAdmins(('<N2>• <V>%s <N2>has joined the room.'):format(playerName))
  elseif participants[playerName] and settings.log_participant_joins then
    announceAdmins(('<S>• <V>%s <S>has joined the room.'):format(playerName))
  end
end

function eventPlayerLeft(playerName)
  roomPlayers[playerName] = nil
  tpTarget[playerName] = nil
  arrowEnabled[playerName] = nil
  colorTarget[playerName] = nil

  if admins[playerName] and settings.log_admin_joins then
    announceAdmins(('<N2>• <V>%s <N2>has left the room.'):format(playerName))
  elseif participants[playerName] and settings.log_participant_joins then
    announceAdmins(('<S>• <V>%s <S>has left the room.'):format(playerName))
  end
end

function eventPlayerRespawn(playerName)
  if defaultFreeze then
    tfm.exec.freezePlayer(playerName, true, true)
  end

  if settings.auto_color then
    if participants[playerName] then
      tfm.exec.setNameColor(playerName, participantsColor)
    elseif participants[playerName] == false then
      tfm.exec.setNameColor(playerName, participantOutColor)
    end
  end

  if settings.auto_cp then
    local death = deathPosition[playerName]
    
    if death then
      tfm.exec.movePlayer(playerName, death.x, death.y)
    end
  end
end

function eventPlayerDied(playerName)
  local player = tfm.get.room.playerList[playerName]

  if player then
    deathPosition[playerName] = {
      x = player.x,
      y = player.y,
    }
  end

  if not bans[playerName] then
    if settings.auto_respawn then
      tfm.exec.respawnPlayer(playerName)
    end
  end
end

function eventPlayerWon(playerName)
  if not bans[playerName] then
    if settings.auto_respawn then
      tfm.exec.respawnPlayer(playerName)
    end
  end
end

function eventColorPicked(colorPickerId, playerName, color)
  if not admins[playerName] or not colorTarget[playerName] then
    return
  end

  if colorPickerId ~= 444 then
    return
  end

  if color ~= -1 then
    local target = colorTarget[playerName]

    if target == 'participants' or target == 'in' then
      participantsColor = color
    elseif target == 'out' then
      participantOutColor = color
    end

    multiTargetCall(target, tfm.exec.setNameColor, color)
    announceAdmins(("<V>[%s] <BL>!color %s %6x"):format(playerName, target, color))
  end

  colorTarget[playerName] = nil
end

function eventKeyboard(playerName, keyCode, down)
  if keyCode == 16 then
    holdingShift[playerName] = down
  elseif keyCode == 77 or keyCode == 46 then
    tfm.exec.killPlayer(playerName)
  end
end

function eventMouse(playerName, x, y)
  if holdingShift[playerName] and (canTeleport[playerName] or admins[playerName]) then
    tfm.exec.movePlayer(playerName, x, y)
  end

  if not admins[playerName] then
    return
  end

  if arrowEnabled[playerName] then
    if arrowEnabled[playerName] ~= 'on' then
      arrowEnabled[playerName] = nil
    end

    if arrowAllowTime[playerName] and os.time() < arrowAllowTime[playerName] then
      return
    end

    arrowAllowTime[playerName] = os.time() + 100
    tfm.exec.addShamanObject(0, x, y)
  end

  if tpTarget[playerName] then
    multiTargetCall(tpTarget[playerName], tfm.exec.movePlayer, x, y)
    tpTarget[playerName] = nil
  end
end

function eventChatCommand(playerName, command)
  local args, count = {}, 0
  for arg in command:gmatch('%S+') do
    args[count] = arg
    count = 1 + count
  end
  args[-1] = command:sub(#args[0] + 2)
  args[0] = args[0]:lower()

  if not admins[playerName] and not allowCommandForEveryone[args[0]] then
    return
  end

  local cmd = commands[args[0]] or commandAlias[args[0]]
  if cmd then
    ok, err = pcall(cmd, playerName, args)
    if not ok and err then
      sendModuleMessage(("<R>Module error on command !%s: <BL>%s"):format(args[0], tostring(err)), playerName)
    end

    if not allowCommandForEveryone[args[0]] and (ok and not err) then
      announceAdmins(("<V>[%s] <BL>!%s"):format(playerName, command))
    end
  end
end


for eventName, eventFunc in next, _G do
  if eventName:find('event') == 1 then
    _G[eventName] = function(...)
      ok, err = pcall(eventFunc, ...)
      if not ok then
        announceAdmins(("<R>Module error on %s: <BL>%s"):format(eventName, tostring(err)))
      end
    end
  end
end

for playerName in next, tfm.get.room.playerList do
  initPlayer(playerName)
end

math.randomseed(os.time())
disableStuff()
newRandomMap()
