local VERSION = "1.87"
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
  7956894,
  7923125,
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
  allow_leave = false,
  auto_color = true,
  time_warning = true,
  log_npc = false,
  log_admin_joins = false,
  log_participant_joins = false,
  auto_shaman = false,
  allow_minimalist = false,
  allow_emotes = true,
  allow_extra_time = true,
}

local mapCategories = {
  ['vanilla'] = { color = '<ROSE>', name = "Vanilla" },
  ['P?'] = { color = '<G>', name = "Unknown" },
  ['P0'] = { color = '<N>', name = "Standard" },
  ['P1'] = { color = '<J>', name = "Protection" },
  ['P2'] = { color = '<J>', name = "Prime" },
  ['P3'] = { color = '<VP>', name = "Prime Bootcamp" },
  ['P4'] = { color = '<VP>', name = "Shaman" },
  ['P5'] = { color = '<VP>', name = "Art" },
  ['P6'] = { color = '<VP>', name = "Mechanism" },
  ['P7'] = { color = '<VP>', name = "No Shaman" },
  ['P8'] = { color = '<VP>', name = "Dual Shaman" },
  ['P9'] = { color = '<VP>', name = "Miscellaneous" },
  ['P10'] = { color = '<VP>', name = "Survivor" },
  ['P11'] = { color = '<VP>', name = "Vampire Survivor" },
  ['P13'] = { color = '<VP>', name = "Bootcamp" },
  ['P17'] = { color = '<VP>', name = "Racing" },
  ['P18'] = { color = '<VP>', name = "Defilante" },
  ['P19'] = { color = '<VP>', name = "Music" },
  ['P20'] = { color = '<BV>', name = "Survivor Test" },
  ['P21'] = { color = '<BV>', name = "Vampire Survivor Test" },
  ['P22'] = { color = '<CEP>', name = "Tribe House" },
  ['P23'] = { color = '<BV>', name = "Bootcamp Test" },
  ['P24'] = { color = '<VP>', name = "Dual Shaman Survivor" },
  ['P32'] = { color = '<BV>', name = "Dual Shaman Test" },
  ['P34'] = { color = '<BV>', name = "Dual Shaman Survivor Test" },
  ['P38'] = { color = '<BV>', name = "Racing Test" },
  ['P41'] = { color = '<CH>', name = "Module" },
  ['P42'] = { color = '<BV>', name = "No Shaman Test" },
  ['P43'] = { color = '<R>', name = "Deleted (Inappropriate)" },
  ['P44'] = { color = '<R>', name = "Deleted" },
  ['P60'] = { color = '<CE>', name = "Thematic" },
  ['P66'] = { color = '<CE>', name = "Thematic" },
  ['P87'] = { color = '<ROSE>', name = "User-Made Vanilla" },
}
local mapInfo = {
  code = tfm.get.room.currentMap,
  author = "???",
  perm = 'P?',
  fakeauthor = nil,
  title = nil,
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
local callOnClick = {}
local callOnColor = {}
local canTeleport = {}
local playerNPC = {}
local arrowEnabled = {}
local arrowAllowTime = {}
local spawnPosition = {}
local deathPosition = {}
local deathTime = {}
local allowMortHotkeyTime = {}
local playerColor = {}
local isDead = {}
local timeRequestTs = {}
local currentTime = 0
local extraTimeSeconds = 60
local participantsColor = 0xffe249
local participantOutColor = 0xCB546B
local themeColor = 0xB2B42E
local guestColor = 0
local defaultGravity, defaultWind, mapGravity, mapWind
local defaultFreeze
local isFrozen = {}
local currentTheme
local timeWarningMessage = 'There is less than 1 minute left...'
local timeupMessage = 'Time is up!'
local timeupMessageShown = true
local lastMinuteWarningShown = true
local throwErrorOnLoop
local onscreenRules = {
  _len=0,
  show = true,
  hide = {},
  style = {
    x = 0, y = 30,
    color = 1,
    textcolor = 0xffffff,
    opacity = 0.8,
    width = false,
    height = false,
    font = false,
    size = false,
  },
  defaultsFalse = {
    width = true,
    height = true,
    font = true,
    size = true,
  }
}

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

local function updateGameTime(time, set)
  time = tonumber(time) or 5
  currentTime = set and time or (math.max(0, currentTime) + time)
  currentTime = math.max(5, currentTime)

  if currentTime > 60 then
    lastMinuteWarningShown = false
  end

  timeupMessageShown = false
  return tfm.exec.setGameTime(currentTime, true)
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

local function elevatedAdminLevel(playerName, initial)
  if not initial and DEFAULT_ADMINS[playerName] then
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
      local playerCount = 0
      for _ in next, room.playerList do
        playerCount = 1 + playerCount
      end

      return 6, playerCount == 1
    end
  end

  if DEFAULT_ADMINS[playerName] then
    return DEFAULT_ADMINS[playerName]
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
  local level, auto = elevatedAdminLevel(playerName, true)

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

local function randomizeMapOrder()
  local index2
  for index=1, maps._len do
    index2 = math.random(maps._len)
    maps[index], maps[index2] = maps[index2], maps[index]
  end
end

do
  maps._index = 1
  maps._len = #maps
  randomizeMapOrder()
end

local function newRandomMap(reversed)
  tfm.exec.newGame(maps[maps._index], reversed)
  maps._index = maps._index + 1
  if maps._index > maps._len then
    maps._index = 1
    randomizeMapOrder()
  end
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

local function setMapName()
  if mapName then
    ui.setMapName(mapName)
    return
  end

  if settings.mapname_theme and currentTheme then
    ui.setMapName(('Theme: <font color="#%.6x">%s'):format(themeColor, currentTheme))
    return
  end

  if mapInfo.title then
    ui.setMapName(mapInfo.title)
    return
  end

  if mapInfo.fakeauthor or mapInfo.author then
    ui.setMapName(('%s <BL>- %s'):format(mapInfo.fakeauthor or mapInfo.author, mapInfo.code))
    return
  end

  ui.setMapName(mapInfo.code)
end

local function updateThemeUI()
  setMapName()

  if settings.theme_ui and currentTheme then
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

local function updateOnscreenRules(playerName, _text)
  if not onscreenRules.show or onscreenRules._len == 0 then
    ui.removeTextArea(111, playerName)
    return
  end

  local style = onscreenRules.style

  if _text then
    return ui.addTextArea(
      111,
      _text,
      playerName,
      style.x, style.y,
      style.width, style.height,
      style.color, style.color,
      style.opacity, false
    )
  end

  local header = ('<font color="#%.6x"%s%s><a href="event:rules"><b>RULES</b></a>'):format(
    style.textcolor,
    style.font and (' face="%s"'):format(style.font) or '',
    style.size and (' size="%s"'):format(style.size) or ''
  )

  if playerName and onscreenRules.hide[playerName] then
    return updateOnscreenRules(playerName, header)
  end

  local text = { header }
  for i=1, onscreenRules._len do
    text[i + 1] = ('<b>%s.</b> %s'):format(i, onscreenRules[i])
  end

  text = table.concat(text, '\n')
  text = text:sub(1, 2000)

  if playerName then
    updateOnscreenRules(playerName, text)
  else
    for playerName in next, roomPlayers do
      updateOnscreenRules(playerName, (not onscreenRules.hide[playerName]) and text or nil)
    end
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
    local pos = settings.auto_cp and deathPosition[playerName]
             or settings.checkpoint and spawnPosition[playerName]
    if pos then
      tfm.exec.movePlayer(playerName, pos.x, pos.y)
    end
  end
end

local function showColorPicker(playerName, text, defaultColor, callback)
  if not playerName then
    return
  end

  callOnColor[playerName] = callback
  ui.showColorPicker(444, playerName, defaultColor, text)
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
  local perm = mapCategories[mapInfo.perm] or mapCategories['P?']
  local title = mapInfo.title
  if title then
    title = ' <G>- ' .. title:gsub('<', ''):gsub('&', '')
  end
  sendModuleMessage(('<J>%s <BL>- %s - %s - %s%s%s'):format(
    mapInfo.author or 'Transformice',
    mapInfo.code,
    mapInfo.perm,
    perm.color,
    perm.name,
    title or ''
  ), playerName)
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

commands.extratime = function(playerName, args)
  extraTimeSeconds = math.max(5, tonumber(args[1]) or 60)
end

commands.time = function(playerName, args)
  local time = args[1] and args[-1]

  if not admins[playerName] then
    if time or not settings.allow_extra_time or not participants[playerName] then
      return true
    end

    if timeRequestTs[playerName] and os.time() < timeRequestTs[playerName] then
      return true
    end

    if currentTime > extraTimeSeconds or currentTime < 1 then
      return true
    end

    timeRequestTs[playerName] = os.time() + extraTimeSeconds * 1000 * 1.5
  end

  if not time then
    updateGameTime(extraTimeSeconds, false)
    sendModuleMessage(
      ('<V>%s</V> added <G>%s</G> seconds to the game.'):format(
        playerName,
        extraTimeSeconds
      ),
      nil
    )
    return true
  end

  local relative = time:sub(1, 1)
  relative = (relative == '+' and 1) or (relative == '-' and -1)

  if relative then
    time = time:sub(2)
  end

  local minutes, unit = time:lower():match('^%s*(%d+)%s*(%a+)$')
  minutes = unit and ('minutes'):find(unit) == 1 and tonumber(minutes)
  time = minutes and (minutes * 60) or tonumber(time)

  if not time then
    sendModuleMessage('Usage: <BL>!time (+/-)[seconds/minutes](m)', playerName)
    return true
  end

  updateGameTime(time * (relative or 1), not relative)
end
commandPerms[commands.time] = 0

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
    target = target or playerName
    showColorPicker(playerName, "Pick a name color:", 0, function(playerName, color)
      if target == 'participants' or target == 'in' then
        participantsColor = color
      elseif target == 'out' then
        participantOutColor = color
      elseif target == 'guest' then
        guestColor = color
      end
  
      multiTargetCall(target, setNameColor, color)
      announceAdmins(("<V>[%s] <BL>!color %s %.6x"):format(playerName, target, color))
    end)
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
  else
    mapName = nil
  end

  setMapName()
end

local function removeNPC(playerName)
  if not playerNPC[playerName] then
    return
  end

  playerNPC[playerName] = nil
  tfm.exec.addNPC(playerName, {
    look = '-1;',
    x = -10000,
    y = -10000,
  })
end
local function showNPC(playerName, npc, visibleFor)
  tfm.exec.addNPC(playerName, {
    title = npc.title,
    look = npc.look,
    x = npc.x,
    y = npc.y,
    female = npc.female,
    lookLeft = npc.lookLeft,
    lookAtPlayer = npc.lookAtPlayer,
  }, visibleFor)
end
local function moveNPC(playerName, x, y)
  local npc = playerNPC[playerName]
  if not npc then
    return
  end

  npc.x, npc.y = x, y
  showNPC(playerName, npc, nil)
end
local function createNPC(playerName, look, onlyUpdateLook, visibleFor)
  local player = tfm.get.room.playerList[playerName]
  if not player then
    return
  end

  local npc = playerNPC[playerName]

  if not look or look:find(';') then
    look = look or player.look
  else
    look = (npc and npc.look or '') .. look
  end

  if #look > 4096 then
    return
  end

  local death = isDead[playerName] and (deathPosition[playerName] or spawnPosition[playerName])
  local female, lookLeft

  if onlyUpdateLook and npc then
    female, lookLeft = npc.female, npc.lookLeft
  else
    female, lookLeft = player.gender == 0, not player.isFacingRight
  end

  npc = {
    title = onlyUpdateLook and npc and npc.title or player.title,
    look = look,
    x = onlyUpdateLook and npc and npc.x or death and death.x or player.x,
    y = onlyUpdateLook and npc and npc.y or death and death.y or player.y,
    female = female,
    lookLeft = lookLeft,
  }

  if visibleFor then
    removeNPC(playerName)
  else
    playerNPC[playerName] = npc
  end

  showNPC(playerName, npc, visibleFor)
end
commands.removenpc = function(playerName, args)
  multiTargetCall(args[1] or playerName, removeNPC)
end
local function moveNpcCallback(playerName, x, y)
  if playerName == 'all' or playerName == '*' then
    for playerName in next, playerNPC do
      moveNPC(playerName, x, y)
    end
    return
  end

  multiTargetCall(playerName, moveNPC, x, y)
end
commands.movenpc = function(playerName, args)
  local targetName = args[1] or playerName

  if args[2] and args[3] then
    local x, y = tonumber(args[2]), tonumber(args[3])
    if not x or not y then
      sendModuleMessage('Usage: <BL>!movenpc [Player#1234] ([x] [y])', playerName)
      return
    end

    moveNpcCallback(targetName, x, y)
    return
  end

  callOnClick[playerName] = function(playerName, x, y)
    moveNpcCallback(targetName, x, y)
  end
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

commands.rules = function(playerName, args)
  if args[1] == 'add' then
    if not args[2] then
      sendModuleMessage('Add new rule: <BL>!rules add [text]', playerName)
      return true
    end

    local text = table.concat(args, ' ', 2, #args)
    text = text:gsub('%*%*(.-)%*%*', '<b>%1</b>')
    text = text:gsub('%*(.-)%*', '<i>%1</i>')
    text = text:gsub('__(.-)__', '<u>%1</u>')
    onscreenRules._len = 1 + onscreenRules._len
    onscreenRules[onscreenRules._len] = text
    updateOnscreenRules()

  elseif args[1] == 'remove' then
    if not args[2] then
      sendModuleMessage('Remove a rule: <BL>!rules remove [line number]', playerName)
      return true
    end

    local index = tonumber(args[2])
    if not index or index < 1 or index > onscreenRules._len or onscreenRules._len == 0 then
      sendModuleMessage('Remove a rule: <BL>!rules remove [line number]', playerName)
      return true
    end

    onscreenRules._len = onscreenRules._len - 1
    table.remove(onscreenRules, index)
    updateOnscreenRules()

  elseif args[1] == 'hide' then
    if onscreenRules.show then
      onscreenRules.show = false
      updateOnscreenRules()
    end

  elseif args[1] == 'show' then
    if not onscreenRules.show then
      onscreenRules.show = true
      updateOnscreenRules()
    end

  elseif args[1] == 'move' then
    callOnClick[playerName] = function(playerName, x, y)
      onscreenRules.style.x = x
      onscreenRules.style.y = y
      updateOnscreenRules()
    end

  elseif args[1] == 'style' then
    local key = args[2]
    if key == 'color' or key == 'textcolor' then
      if args[3] then
        args[3] = tonumber(args[3], 16)
      else
        showColorPicker(playerName, "Pick a color for rules:", onscreenRules.style[key], function(playerName, color)
          onscreenRules.style[key] = color
          updateOnscreenRules()
          announceAdmins(("<V>[%s] <BL>!rules style %s %.6x"):format(playerName, key, color))
        end)
        return true
      end
    end

    if not key or onscreenRules.style[key] == nil or not args[3] then
      sendModuleMessage('Change rules ui style or position: <BL>!rules style x/y/color/opacity/width/height/font/size [value]', playerName)
      return true
    end

    local value = tonumber(args[3]) or false

    if key == 'font' then
      value = table.concat(args, ' ', 3, #args)
      value = value:gsub('[^a-zA-Z0-9%s]', '')
    end

    if not value then
      if not onscreenRules.defaultsFalse[key] or args[3] ~= '-' then
        sendModuleMessage('<r>Invalid value', playerName)
        return true
      end
    end

    onscreenRules.style[key] = value
    updateOnscreenRules()

  else
    sendModuleMessage('Manage rules: <BL>!rules add/remove/hide/show/move/style', playerName)
    return true
  end
end

commands.newtheme = function(playerName, args)
  if not args[1] then
    currentTheme = nil
    updateThemeUI()
    return
  end

  if settings.mapname_theme then
    mapName = nil
  end

  currentTheme = args[-1]
  updateThemeUI()
  sendModuleMessage(('New Theme: <font color="#%.6x">%s'):format(themeColor, currentTheme), nil)
end

commands.themecolor = function(playerName, args)
  if not args[1] then
    showColorPicker(playerName, "Pick a theme color:", themeColor, function(playerName, color)
      themeColor = color
      updateThemeUI()
      announceAdmins(("<V>[%s] <BL>!themecolor %.6x"):format(playerName, color))
    end)
    return true
  end

  local color = tonumber(args[1], 16) or 0xB2B42E
  themeColor = color
  updateThemeUI()
end

commands.theme = function(playerName, args)
  sendModuleMessage('Theme: ' .. (currentTheme or 'TBD'), playerName)
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

local function sortedSettingList()
  local list = {}
  for key in next, settings do
    list[1 + #list] = key
  end
  table.sort(list)
  return list
end

local function updateSettingsUI(playerName)
  local list = sortedSettingList()
  for i=1, #list do
    list[i] = ('<%s><a href="event:%s">%s = %s</a>'):format(
      settings[list[i]] and 'VP' or 'R',
      list[i],
      list[i]:gsub('_', ' '),
      settings[list[i]] and 'yes' or 'no'
    )
  end
  list[1 + #list] = '\n<R><a href="event:close">[close]</a>'

  local text = table.concat(list, '\n')
  ui.addTextArea(999, text, playerName, 200, 50, nil, nil, 1, 1, 0.9, true)
end

commands.settings = function(playerName, args)
  local key = args[1]
  if not key then
    updateSettingsUI(playerName)
    return true
  end

  if settings[key] == nil then
    local list = sortedSettingList()
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

    if settings.allow_extra_time then
      sendModuleMessage('If you need to ask for more time just type <BL>!time', playerName)
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
  if not settings.allow_join then
    sendModuleMessage('<R>You cannot join the show right now.', playerName)
    return true
  end

  if participants[playerName] then
    sendModuleMessage('<R>You are already a participant in the show.', playerName)
    return true
  end

  if participants[playerName] == false then
    sendModuleMessage('<R>You are removed from the show.', playerName)
    return true
  end

  updateParticipant(playerName, true)
  return true
end
commandPerms[commands.join] = 0

commands.leave = function(playerName, args)
  if not participants[playerName] then
    sendModuleMessage('<R>You are not a participant in the show.', playerName)
    return true
  end

  if not settings.allow_leave then
    sendModuleMessage('<R>You are not allowed to change your participant status in the show.', playerName)
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
  if not args[1] then
    showColorPicker(playerName, "Pick a background color:", backgroundColor or 0, function(playerName, color)
      backgroundColor = ('#%.6x'):format(color)
      ui.setBackgroundColor(backgroundColor)
      announceAdmins(("<V>[%s] <BL>!bgcolor %.6x"):format(playerName, color))
    end)
    return true
  end

  backgroundColor = args[1] ~= '-' and args[1] ~= 'none' and ("#" .. args[1]) or nil
  ui.setBackgroundColor(backgroundColor)
end


function eventNewGame()
  -- sometimes it bugs so we refresh it every round
  disableStuff()

  timeupMessageShown = false
  lastMinuteWarningShown = false
  playerNPC = {}
  isDead = {}
  lastTimeRequest = {}

  local code = tfm.get.room.currentMap
  if mapInfo.code ~= code then
    spawnPosition = {}
    deathPosition = {}
  end

  local info = tfm.get.room.xmlMapInfo
  if info then
    if info.author ~= '#Module' then
      mapInfo = {
        code = code,
        author = info.author,
        perm = 'P' .. info.permCode,
      }
    end

    local xml = info.xml
    local properties = xml and xml:match('<P( .-)/>')

    if properties then
      if info.author ~= '#Module' and properties:find(' reload="[^"]*"') then
        tfm.exec.newGame(xml, tfm.get.room.mirroredMap)
      else
        local wind, gravity = properties:match(' G="(.-),(.-)"')
        defaultWind = tonumber(wind) or 0
        defaultGravity = tonumber(gravity) or 10

        backgroundColor = properties:match(' bgcolor="(.-)"') or backgroundColor
        ui.setBackgroundColor(backgroundColor)

        local author = properties:match(' author="(.-)"')
        if author then
          mapInfo.fakeauthor = author
        end

        local title = properties:match(' title="(.-)"')
        if title then
          mapInfo.title = title
        end
      end
    end
  else
    mapInfo = {
      code = code,
      perm = 'vanilla',
    }
  end

  for playerName in next, roomPlayers do
    if bans[playerName] then
      tfm.exec.killPlayer(playerName)
    end
  end

  setMapName()
  updateGameTime(60 * 60, true)
end

function eventLoop(elapsedTime, remainingTime)
  currentTime = remainingTime / 1000

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

  setMapName()
  updateThemeUI()
  updateOnscreenRules(playerName)

  if mapWind and mapGravity then
    tfm.exec.setWorldGravity(mapWind, mapGravity)
  end

  autoSpawnAndMove(playerName)

  for targetName, npc in next, playerNPC do
    showNPC(targetName, npc, playerName)
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
  allowMortHotkeyTime[playerName] = nil
  arrowAllowTime[playerName] = nil
  deathTime[playerName] = nil
  callOnClick[playerName] = nil
  callOnColor[playerName] = nil

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
    local pos = settings.auto_cp and deathPosition[playerName]
             or settings.checkpoint and spawnPosition[playerName]
    if pos then
      tfm.exec.movePlayer(playerName, pos.x, pos.y)
    end
  end
end

function eventPlayerDied(playerName)
  isDead[playerName] = true

  if settings.auto_cp then
    local time = deathTime[playerName]
    deathTime[playerName] = os.time() + 500

    if time and os.time() < time then
      deathPosition[playerName] = nil
    else
      local death = deathPosition[playerName]
      if not death or death.timestamp + 1000 < os.time() then
        local player = tfm.get.room.playerList[playerName]
        if player then
          deathPosition[playerName] = {
            x = player.x,
            y = player.y,
            timestamp = os.time(),
          }
        end
      end
    end
  end

  autoSpawnAndMove(playerName)
end

function eventPlayerWon(playerName)
  isDead[playerName] = true
  autoSpawnAndMove(playerName)
end

function eventColorPicked(colorPickerId, playerName, color)
  if colorPickerId ~= 444 then
    return
  end

  if not admins[playerName] then
    return
  end

  if color ~= -1 then
    local callback = callOnColor[playerName]
    if callback then
      callback(playerName, color)
      callOnColor[playerName] = nil
    end
  end
end

function eventEmotePlayed(playerName, emoteType, emoteParam)
  if settings.allow_emotes or emoteType == 9 then
    return
  end

  tfm.exec.playEmote(playerName, 9, nil)
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
        timestamp = os.time(),
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

  -- for now only admins can trigger this so no need to configure bind yet
  local callback = callOnClick[playerName]
  if callback then
    callback(playerName, x, y)
    callOnClick[playerName] = nil
  end

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

function eventTextAreaCallback(textAreaId, playerName, eventName)
  if textAreaId == 111 then
    if eventName == 'rules' then
      onscreenRules.hide[playerName] = not onscreenRules.hide[playerName]
      updateOnscreenRules(playerName)
    end
    return
  elseif textAreaId == 999 then
    if eventName == 'close' then
      return ui.removeTextArea(textAreaId, playerName)
    end

    if not admins[playerName] then
      return
    end

    if settings[eventName] == nil then
      return
    end

    eventChatCommand(playerName, ("settings %s %s"):format(
      eventName,
      settings[eventName] and 'no' or 'yes'
    ))
    updateSettingsUI(playerName)
  end
end


for eventName, eventFunc in next, _G do
  if eventName:find('event') == 1 then
    _G[eventName] = function(...)
      ok, err = pcall(eventFunc, ...)
      if not ok then
        print(eventName)
        print(err)
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
