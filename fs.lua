local VERSION = "1.70"
local MODULE_ROOM = "*#mckeydown fs %s"
local DEFAULT_ADMINS = {
  ["Mckeydown#0000"] = 10,
  ["Lays#1146"] = 10,
}
local admins = {}
local maps = {
  7954539,
  7954420,
  7954412,
  7951350,
  7954520,
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
  checkpoint = true,
  allow_join = true,
  auto_color = true,
  time_warning = true,
  log_npc = false,
  log_admin_joins = false,
  log_participant_joins = false,
  auto_shaman = false,
  allow_minimalist = false,
}

local mapName
local backgroundColor
local roomPlayers = {}
local bans = {}
local participants = {}
local tpTarget = {}
local holdingKey = {
  [16] = {}, -- shift
  [17] = {}, -- ctrl
}
local canTeleport = {}
local playerNPC = {}
local playerNPCPos = {}
local arrowEnabled = {}
local arrowAllowTime = {}
local spawnPosition = {}
local deathPosition = {}
local deathTime = {}
local colorTarget = {}
local allowMortHotkeyTime = {}
local playerColor = {}
local isDead = {}
local participantsColor = 0xffe249
local participantOutColor = 0xCB546B
local themeColor = 0xB2B42E
local guestColor = 0
local defaultGravity, defaultWind, mapGravity, mapWind
local defaultFreeze
local isFrozen = {}
local currentTheme = 'TBD'
local timeWarningMessage = 'There is less than 1 minute left...'
local timeupMessage = 'Time is up!'
local timeupMessageShown
local lastMinuteWarningShown
local throwErrorOnLoop

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


local function findLowerStrInArr(str, arr, start, last)
  if not str then
    return
  end

  start = start or 1
  last = last or #arr
  str = str:lower()

  for i=start, last do
    if not arr[i] then
      return
    end

    if arr[i] == str then
      return i
    end
  end
end

local function getNumberAndString(arg1, arg2)
  local num = tonumber(arg1)
  if num then
    return num, arg2
  end
  num = tonumber(arg2)
  if num then
    return num, arg1
  end
  return nil, arg1 or arg2
end

local function sendMultiLineMessages(text, playerName)
  local message = tostring(text)

  for msg in message:gmatch('[^\r\n]+') do
    tfm.exec.chatMessage(msg:sub(1, 2000):gsub('<[^>]*$', ''), playerName)
  end
end

local function sendModuleMessage(text, playerName)
  sendMultiLineMessages("<BL>[#] <N>" .. tostring(text), playerName)
end

local function elevatedAdminLevel(playerName)
  if DEFAULT_ADMINS[playerName] then
    return DEFAULT_ADMINS[playerName]
  end

  if not playerName:find('*') then
    local playerTag = playerName:sub(#playerName-4)

    if playerTag == '#0001' or playerTag == '#0010' or playerTag == '#0015' or playerTag == '#0020' then
      return 7
    end

    local room = tfm.get.room

    if room.name:find(playerName) then
      return 6, true
    end

    local player = room.playerList[playerName]
    local tribeName = room.name:sub(3)

    if player and room.isTribeHouse and player.tribeName == tribeName then
      return 6
    end
  end

  return 0
end

local function autoBind(playerName)
  local isAdmin = admins[playerName]
  local isBanned = bans[playerName]
  local canTp = isAdmin or not isBanned and canTeleport[playerName]
  canTp = canTp and true or false

  system.bindMouse(playerName, canTp)
  tfm.exec.bindKeyboard(playerName, 77, true, not isBanned)
  tfm.exec.bindKeyboard(playerName, 46, true, not isBanned)
  tfm.exec.bindKeyboard(playerName, 69, true, not isBanned and settings.checkpoint)

  for key in next, holdingKey do
    tfm.exec.bindKeyboard(playerName, key, true, canTp)
    tfm.exec.bindKeyboard(playerName, key, false, canTp)
  end
end

local function initPlayer(playerName)
  roomPlayers[playerName] = true

  local currentLevel = admins[playerName] or 0
  local level, auto = elevatedAdminLevel(playerName)

  eventChatCommand(playerName, "help")

  if currentLevel < level then
    if auto then
      admins[playerName] = level
    else
      sendModuleMessage(
        '<BL>!adminme <N2>command is available for you here, please use it responsibly.',
        playerName
      )
    end
  end

  autoBind(playerName)
end

local function newRandomMap(reversed)
  tfm.exec.newGame(maps[math.random(1, #maps)], reversed)
end

local function disableStuff()
  tfm.exec.disableAfkDeath(true)
  tfm.exec.disableAutoScore(true)
  tfm.exec.disableAutoNewGame(true)
  tfm.exec.disableAutoTimeLeft(true)
  tfm.exec.disableAutoShaman(not settings.auto_shaman)
  tfm.exec.disableAllShamanSkills(not settings.allow_skills)
  tfm.exec.disablePhysicalConsumables(not settings.throwables)
  tfm.exec.disableMinimalistMode(not settings.allow_minimalist)
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
  if multi == 'all' or multi == 'room' or multi == '*' then
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

  if multi == 'guest' then
    for targetName in next, roomPlayers do
      if not admins[targetName] and not participants[targetName] then
        fnc(targetName, ...)
      end
    end
    return
  end

  if multi == 'out' then
    for targetName in next, roomPlayers do
      if not admins[targetName] and participants[targetName] == false then
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

  local mouseName = targetName:lower():gsub('^+?[a-z]', string.upper)

  if not mouseName:find('#') then
    mouseName = mouseName .. '#0000'
  end

  if not roomPlayers[mouseName] then
    targetName = targetName:lower()

    for name in next, roomPlayers do
      if name:lower():match(targetName) then
        mouseName = nil
        fnc(name, ...)
      end
    end
  end

  if mouseName then
    fnc(mouseName, ...)
  end
end

local function updateThemeUI()
  if settings.mapname_theme and mapName then
    ui.setMapName(mapName)
  end

  if settings.theme_ui then
    ui.addTextArea(
      666,
      ('<font color="#%.6x">Theme: %s'):format(
        themeColor,
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
      sendMultiLineMessages(message, adminName)
    end
  end
end

local function chatMessageList(playerName, list, max, pre)
  for i=1, #list, max do
    tfm.exec.chatMessage(pre .. table.concat(list, ' ', i, math.min(#list, i + max - 1)), playerName)
  end
end

local function autoSpawnAndMove(playerName)
  if bans[playerName] or not settings.auto_respawn then
    return
  end

  tfm.exec.respawnPlayer(playerName)

  if settings.checkpoint or settings.auto_cp then
    local pos = settings.checkpoint and spawnPosition[playerName]
             or settings.auto_cp and deathPosition[playerName]
    if pos then
      tfm.exec.movePlayer(playerName, pos.x, pos.y)
    end
  end
end


local commands = {}
local commandAlias = {}
local commandPerms = {}

commands.room = function(playerName, args)
  sendModuleMessage("You can create your room by typing\n<BL>/room " .. MODULE_ROOM:format(playerName), playerName)

  if args[1] ~= 'onlymine' then
    local roomName = tfm.get.room.name

    if roomName:sub(1, 1) ~= '@' and roomName:sub(1, 1) ~= '*' then
      roomName = ('%s <J>(%s)'):format(roomName, tfm.get.room.community)
    end

    sendModuleMessage("You are currently in\n<BL>/room " .. roomName, playerName)
  end

  return true
end
commandPerms[commands.room] = 0

commands.help = function(playerName, args)
  sendModuleMessage("This is a small utility module made for fashion shows. You can type <BL>!commands <N>to see available commands.", playerName)

  if not admins[playerName] then
    eventChatCommand(playerName, 'room onlymine')

    if settings.allow_join then
      sendModuleMessage("<N>If you are here for a fashion show, type <BL>!join <N>to participate.", playerName)
    end
  end

  return true
end
commandPerms[commands.help] = 0

commands.mapinfo = function(playerName, args)
  sendModuleMessage(tostring(lastMapCode), playerName)
  return true
end
commandPerms[commands.mapinfo] = 0

commands.version = function(playerName, args)
  sendModuleMessage("fs v" .. VERSION .. ' ~ Lays#1146', playerName)
  return true
end
commandAlias.v = commands.version
commandPerms[commands.version] = 0

commands.commands = function(playerName, args)
  local list = {}
  local playerLevel = admins[playerName] or 0

  for commandName, cmd in next, commands do
    if playerLevel >= (commandPerms[cmd] or 5) and commandName ~= 'adminme' then
      list[1 + #list] = commandName
    end
  end

  table.sort(list)
  sendModuleMessage('Available commands: <BL>' .. table.concat(list, ', '), playerName)

  if playerLevel > 0 then
    sendModuleMessage('You can use the following targets in most of the commands: <BL>all room admins players guest out in/participants', playerName)
  end

  return true
end
commandAlias.cmds = commands.commands
commandPerms[commands.commands] = 0

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
commandAlias['in'] = commands.participants
commandPerms[commands.participants] = 0

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
commandPerms[commands.admins] = 0

commands.spectators = function(playerName, args)
  local list = {}
  for name in next, bans do
    list[1 + #list] = name
  end
  sendModuleMessage("Spectators:", playerName)
  chatMessageList(playerName, list, 10, '<V>')
  return true
end
commandAlias.banlist = commands.spectators
commandAlias.bans = commands.spectators

commands.map = function(playerName, args)
  local code, perm

  if args[1] then
    code = args[1]:match('^@?%d+$')
    perm = args[1]:match('^#%d+$') or args[1]:match('^[pP]%d+$')
    perm = perm and perm:gsub('[pP]', '#')
  end

  if not code and not perm then
    if doesItMeanReversed(args[1]) then
      newRandomMap(true)
      return
    end

    if args[1] then
      sendModuleMessage('Usage: <BL>!map [@code|#perm|reversed] (reversed)', playerName)
      return true
    end

    newRandomMap()
    return
  end

  tfm.exec.newGame(code or perm, doesItMeanReversed(args[2]))
end
commandAlias.np = commands.map

commands.rst = function(playerName, args)
  local info = tfm.get.room.xmlMapInfo
  local reversed = (
    args[1] and doesItMeanReversed(args[1])
    or args[2] and doesItMeanReversed(args[2])
    or not args[1] and not args[2] and tfm.get.room.mirroredMap
  )
  if (info and info.author == "#Module") or args[1] == 'xml' then
    if info and info.xml then
      tfm.exec.newGame(info.xml, reversed)
    end
  else
    tfm.exec.newGame(tfm.get.room.currentMap, reversed)
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
  local size, target = getNumberAndString(args[2], args[1])
  size = size or 1
  target = target or playerName
  multiTargetCall(target, tfm.exec.changePlayerSize, size)
end

local function setNameColor(playerName, color)
  if not playerName then
    return
  end

  color = color or playerColor[playerName] or guestColor
  playerColor[playerName] = color
  tfm.exec.setNameColor(playerName, color)
end
commands.color = function(playerName, args)
  local target = args[1]
  local color = args[2] and tonumber(args[2], 16)

  if not color then
    color = args[1] and tonumber(args[1], 16)
    if color then
      setNameColor(playerName, color)
      return
    end
  end

  if color then
    if target == 'participants' or target == 'in' then
      participantsColor = color
    elseif target == 'out' then
      participantOutColor = color
    elseif target == 'guest' then
      guestColor = color
    end

    multiTargetCall(target, setNameColor, color)
  else
    colorTarget[playerName] = target or playerName
    ui.showColorPicker(444, playerName, 0, "Pick a name color:")
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
local function createNPC(playerName, look, keepPos, visibleFor)
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

  local death = isDead[playerName] and (spawnPosition[playerName] or deathPosition[playerName])
  local pos = keepPos and playerNPCPos[playerName] or death or {
    x = player.x,
    y = player.y,
  }

  if not visibleFor then
    playerNPC[playerName] = look
    playerNPCPos[playerName] = pos
  end

  tfm.exec.addNPC(playerName, {
    title = player.title,
    look = look,
    x = pos.x,
    y = pos.y,
    female = player.gender == 0,
    lookLeft = not player.isFacingRight,
    lookAtPlayer = true,
  }, visibleFor)
end
commands.removenpc = function(playerName, args)
  multiTargetCall(args[1] or playerName, removeNPC)
end
commands.createnpc = function(playerName, args)
  if not args[1] then
    sendModuleMessage('Usage: <BL>!createnpc [Player#1234] (/dressing code) (update|hide)', playerName)
    return true
  end

  local look = args[2]
  local visibleFor = findLowerStrInArr('hide', args, 3) and playerName or nil
  local keepPos = findLowerStrInArr('update', args, 3) or nil

  local targetPlayer = tfm.get.room.playerList[look]
  if targetPlayer then
    look = targetPlayer.look
  end

  multiTargetCall(args[1], createNPC, look, keepPos, visibleFor)
end
commands.npc = function(playerName, args)
  if not admins[playerName] and (not settings.allow_npc or not participants[playerName]) then
    sendModuleMessage('<R>You are not allowed to create NPC', playerName)
    return true
  end

  if not args[1] then
    createNPC(playerName)
    return not settings.log_npc
  end

  if args[1] == 'remove' then
    removeNPC(playerName)
    return not settings.log_npc
  end

  local look = args[1]
  local targetPlayer = tfm.get.room.playerList[look]
  local visibleFor = findLowerStrInArr('hide', args, 2) and playerName or nil
  local keepPos = findLowerStrInArr('update', args, 2) or nil

  if targetPlayer then
    if not admins[playerName] then
      sendModuleMessage('<R>Only admins can copy outfits', playerName)
      return true
    end

    look = targetPlayer.look
  end

  createNPC(playerName, look, keepPos, visibleFor)

  return not settings.log_npc
end
commandAlias.dressing = commands.npc
commandPerms[commands.npc] = 0

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
  local colored = ('<font color="#%.6x">%s'):format(themeColor, currentTheme)

  if settings.mapname_theme then
    mapName = '<J>Theme: ' .. colored
  end

  updateThemeUI()
  sendModuleMessage('New Theme: ' .. colored, nil)
end

commands.themecolor = function(playerName, args)
  local color = args[1] and tonumber(args[1], 16) or 0xB2B42E

  themeColor = color
  updateThemeUI()
end

commands.theme = function(playerName, args)
  sendModuleMessage('Theme: ' .. currentTheme, playerName)
  return true
end
commandPerms[commands.theme] = 0

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

  if password == "" then
    sendModuleMessage('Room password has been removed.', nil)
  else
    sendModuleMessage('Room password has been changed.', nil)
  end
end

commands.grav = function(playerName, args)
  mapWind = tonumber(args[2]) or defaultWind
  mapGravity = tonumber(args[1]) or defaultGravity
  tfm.exec.setWorldGravity(mapWind, mapGravity)
end
commandAlias.gravity = commands.grav

commands.error = function(playerName, args)
  if args[1] == 'event' then
    throwErrorOnLoop = args[2] and args[-1]:gsub('^event%s*', '') or "test"
    return
  end

  error(args[1] and args[-1] or "test")
end
commandPerms[commands.error] = 9

local function setAdminLevel(playerName, level, compareLevel)
  if not playerName or not level or not compareLevel then
    return
  end

  local currentLevel = admins[playerName] or 0

  if compareLevel <= currentLevel or compareLevel < level or currentLevel == level then
    return
  end

  admins[playerName] = level ~= 0 and level or nil
  autoBind(playerName)

  if level == 0 then
    announceAdmins(('<V>%s <N2>is not an admin anymore.'):format(playerName))
  else
    if currentLevel > 0 then
      announceAdmins(('<V>%s <N2>is an admin now. [%s]'):format(playerName, level))
    else
      announceAdmins(('<V>%s <N2>is an admin now.'):format(playerName))
    end
  end
end

commands.setadmin = function(playerName, args)
  local target = args[1]
  local level = tonumber(args[2])

  if not target or not level or level < 0 or level > 10 then
    return
  end

  multiTargetCall(target, setAdminLevel, level, admins[playerName])
end
commandPerms[commands.setadmin] = 9

commands.adminme = function(playerName, args)
  local level = elevatedAdminLevel(playerName)
  if not level or level == 0 then
    return true
  end

  setAdminLevel(playerName, level, 11)
end
commandPerms[commands.adminme] = 0

commands.unadminme = function(playerName, args)
  setAdminLevel(playerName, 0, 11)
  sendModuleMessage('<N2>You are not an admin anymore.', playerName)
end
commandPerms[commands.unadminme] = 1

commands.admin = function(playerName, args)
  local target = args[1]
  if not target then
    sendModuleMessage('Usage: <BL>!admin [target]', playerName)
    return
  end

  multiTargetCall(target, setAdminLevel, 5, admins[playerName])
end

commands.unadmin = function(playerName, args)
  local target = args[1]
  if not target then
    sendModuleMessage('Usage: <BL>!unadmin [target]', playerName)
    return
  end

  local playerLevel = admins[playerName]

  if target == "all" or target == "*" then
    local all = {}

    for name in next, admins do
      all[name] = true
    end

    for targetName in next, all do
      setAdminLevel(targetName, 0, playerLevel)
    end

    return
  end

  multiTargetCall(target, setAdminLevel, 0, playerLevel)
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
    return true
  end

  tfm.exec.setShamanMode(playerName, mode)
  return true
end
commandPerms[commands.shamode] = 0

commands.score = function(playerName, args)
  local score, target = getNumberAndString(args[2], args[1])
  score = score or 0
  target = target or playerName
  multiTargetCall(target, tfm.exec.setPlayerScore, score, false)
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
  canTeleport[playerName] = yes
  autoBind(playerName)
end

commands.cantp = function(playerName, args)
  if not args[1] then
    sendModuleMessage('Usage: <BL>!cantp [target] (no)', playerName)
    return true
  end

  local yes = args[2] ~= 'no' or nil

  if (args[1] == 'all' or args[1] == '*') and not yes then
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

  if playerName1 == "all" or playerName1 == "*" or playerName1 == "room" then
    for name in next, roomPlayers do
      tfm.exec.linkMice(name, name, false)
    end
    return
  end

  tfm.exec.linkMice(playerName1, playerName2, false)
end

local function setFreezeStatus(playerName, status)
  isFrozen[playerName] = status or nil
  tfm.exec.freezePlayer(playerName, status)
end

commands.freeze = function(playerName, args)
  if args[1] == "all" or args[1] == "*" then
    defaultFreeze = true
  end
  multiTargetCall(args[1] or playerName, setFreezeStatus, true)
end

commands.unfreeze = function(playerName, args)
  if args[1] == "all" or args[1] == "*" then
    defaultFreeze = false
    isFrozen = {}
  end
  multiTargetCall(args[1] or playerName, setFreezeStatus, false)
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
  local targetName = args[1] or playerName
  local enabled = args[2] ~= 'off' and args[2] ~= 'no'

  if args[1] == 'off' or args[1] == 'no' then
    targetName = playerName
    enabled = false
  end

  multiTargetCall(targetName, setNightmode, enabled)
end

local function playerVictory(targetName, showMessage)
  tfm.exec.giveCheese(targetName)
  tfm.exec.playerVictory(targetName)

  if showMessage then
    sendModuleMessage(('<b><V>%s</V> <S>is the winner!%s</S></b>'):format(
      targetName, ('!'):rep(math.random(1, 5))
    ), nil)
  end
end
commands.win = function(playerName, args)
  multiTargetCall(args[1] or playerName, playerVictory, true)
end
commands.hole = function(playerName, args)
  multiTargetCall(args[1] or playerName, playerVictory, false)
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

  if key == 'checkpoint' then
    for name in next, tfm.get.room.playerList do
      autoBind(name)
    end
  end
end
commandAlias.set = commands.settings

local function updateParticipant(playerName, status)
  if participants[playerName] == status then
    return
  end

  if status == false and not participants[playerName] and not roomPlayers[playerName] then
    return
  end

  if status then
    sendModuleMessage('<V>' .. playerName .. ' <N>has joined the show.', nil)

    if settings.allow_npc then
      sendModuleMessage('You can type <BL>!npc [/dressing code here] <N>to create an NPC wearing a fit you created in /dressing or in external dress room tools.', playerName)
    end
  elseif status == false then
    if participants[playerName] then
      sendModuleMessage('<V>' .. playerName .. ' <N>has been removed from the show.', nil)
    else
      sendModuleMessage('<V>' .. playerName .. ' <N>has been banned from the show.', nil)
    end
  else
    sendModuleMessage('<V>' .. playerName .. ' <N>has left the show.', nil)
  end

  participants[playerName] = status

  if settings.auto_color then
    if status then
      setNameColor(playerName, participantsColor)
    elseif status == false then
      setNameColor(playerName, participantOutColor)
    else
      setNameColor(playerName, guestColor)
    end
  end
end

local function banPlayer(targetName, yes)
  bans[targetName] = yes
  autoBind(targetName)

  if yes then
    updateParticipant(targetName, false)
    tfm.exec.killPlayer(targetName)
  else
    autoSpawnAndMove(targetName)
  end
end

commands.spec = function(playerName, args)
  multiTargetCall(args[1] or playerName, banPlayer, true)
end
commandAlias.ban = commands.spec

commands.unspec = function(playerName, args)
  if args[1] == "all" or args[1] == "*" then
    bans = {}
  end

  multiTargetCall(args[1] or playerName, banPlayer, nil)
end
commandAlias.unban = commands.unspec

commands.join = function(playerName, args)
  if not settings.allow_join or participants[playerName] ~= nil then
    sendModuleMessage('<R>You cannot join the show right now.', playerName)
    return true
  end

  updateParticipant(playerName, true)
  return true
end
commandPerms[commands.join] = 0

commands.leave = function(playerName, args)
  if not participants[playerName] then
    return true
  end

  updateParticipant(playerName, nil)
  return true
end
commandPerms[commands.leave] = 0

commands.add = function(playerName, args)
  multiTargetCall(args[1], updateParticipant, true)
end

commands.remove = function(playerName, args)
  if args[1] == "all" or args[1] == "*" then
    if settings.auto_color then
      for name in next, participants do
        setNameColor(name, guestColor)
      end
    end

    participants = {}
    sendModuleMessage('<N>Participants list has been cleaned.', nil)

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
  isDead = {}

  if lastMapCode ~= tfm.get.room.currentMap then
    spawnPosition = {}
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

  tfm.exec.setGameTime(60 * 60)
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

  if throwErrorOnLoop then
    local err = throwErrorOnLoop
    throwErrorOnLoop = nil
    error(err)
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

  autoSpawnAndMove(playerName)

  for targetName, look in next, playerNPC do
    createNPC(targetName, look, true, playerName)
  end

  if admins[playerName] and settings.log_admin_joins then
    announceAdmins(('<N2>• <V>%s <N2>has joined the room.'):format(playerName))
  elseif participants[playerName] and settings.log_participant_joins then
    announceAdmins(('<S>• <V>%s <S>has joined the room.'):format(playerName))
  end
end

function eventPlayerLeft(playerName)
  isDead[playerName] = nil
  roomPlayers[playerName] = nil
  tpTarget[playerName] = nil
  arrowEnabled[playerName] = nil
  colorTarget[playerName] = nil
  allowMortHotkeyTime[playerName] = nil
  arrowAllowTime[playerName] = nil
  deathTime[playerName] = nil

  if admins[playerName] and settings.log_admin_joins then
    announceAdmins(('<N2>• <V>%s <N2>has left the room.'):format(playerName))
  elseif participants[playerName] and settings.log_participant_joins then
    announceAdmins(('<S>• <V>%s <S>has left the room.'):format(playerName))
  end
end

function eventPlayerRespawn(playerName)
  isDead[playerName] = nil

  if defaultFreeze or isFrozen[playerName] then
    tfm.exec.freezePlayer(playerName, true, true)
  end

  if playerColor[playerName] then
    setNameColor(playerName)
  elseif settings.auto_color then
    if participants[playerName] then
      setNameColor(playerName, participantsColor)
    elseif participants[playerName] == false then
      setNameColor(playerName, participantOutColor)
    else
      setNameColor(playerName, guestColor)
    end
  end

  if settings.checkpoint or settings.auto_cp then
    local pos = settings.checkpoint and spawnPosition[playerName]
             or settings.auto_cp and deathPosition[playerName]
    if pos then
      tfm.exec.movePlayer(playerName, pos.x, pos.y)
    end
  end
end

function eventPlayerDied(playerName)
  isDead[playerName] = true

  local time = deathTime[playerName]
  if time and os.time() < time then
    deathPosition[playerName] = nil
  end

  deathTime[playerName] = os.time() + 500
  autoSpawnAndMove(playerName)
end

function eventPlayerWon(playerName)
  isDead[playerName] = true
  autoSpawnAndMove(playerName)
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
    elseif target == 'guest' then
      guestColor = color
    end

    multiTargetCall(target, setNameColor, color)
    announceAdmins(("<V>[%s] <BL>!color %s %.6x"):format(playerName, target, color))
  end

  colorTarget[playerName] = nil
end

function eventKeyboard(playerName, keyCode, down, x, y)
  local holding = holdingKey[keyCode]
  if holding then
    holding[playerName] = down or nil
  elseif keyCode == 77 or keyCode == 46 then
    if allowMortHotkeyTime[playerName] and os.time() < allowMortHotkeyTime[playerName] then
      return
    end

    if settings.auto_cp then
      deathPosition[playerName] = {
        x = x,
        y = y,
      }
    end

    allowMortHotkeyTime[playerName] = os.time() + 500
    tfm.exec.killPlayer(playerName)
  elseif keyCode == 69 then
    if settings.checkpoint then
      spawnPosition[playerName] = {
        x = x,
        y = y,
      }
    end
  end
end

function eventMouse(playerName, x, y)
  local holdingShift = holdingKey[16][playerName]
  local holdingControl = holdingKey[17][playerName]
  local holdingBoth = holdingShift and holdingControl

  if not holdingBoth and (holdingShift or holdingControl) and (canTeleport[playerName] or admins[playerName]) then
    tfm.exec.movePlayer(playerName, x, y)
  end

  if not admins[playerName] then
    return
  end

  if holdingBoth then
    for id, obj in next, tfm.get.room.objectList do
      if math.pow(obj.x - x, 2) + math.pow(obj.y - y, 2) < 250 then
        tfm.exec.removeObject(id)
        break
      end
    end
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

  local cmd = commands[args[0]] or commandAlias[args[0]]
  if cmd then
    local playerPerm = admins[playerName] or 0
    local cmdPerm = commandPerms[cmd] or 5

    if playerPerm < cmdPerm then
      return
    end

    local ok, ret = xpcall(function()
      return cmd(playerName, args)
    end, debug.traceback)
    if not ok then
      sendModuleMessage(("<R>Module error on command !%s:\n<BL>%s\n<G>v%s"):format(args[0], tostring(ret), VERSION), playerName)
      return
    end

    if not ret then
      announceAdmins(("<V>[%s] <BL>!%s"):format(playerName, command))
    end
  end
end


for eventName, eventFunc in next, _G do
  if eventName:find('event') == 1 then
    _G[eventName] = function(...)
      ok, err = pcall(eventFunc, ...)
      if not ok then
        announceAdmins(("<BL>[#] <R>Module error on %s:\n<BL>%s\n<G>v%s"):format(eventName, tostring(err), VERSION))
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
