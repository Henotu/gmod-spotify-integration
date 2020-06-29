-- Backend
if (not ConVarExists("gSpotify_enable")) or (not ConVarExists("gSpotify_show_Authorization")) then
  CreateClientConVar("gSpotify_enable", 0, true, false)
  CreateClientConVar("gSpotify_show_Authorization", 1, true, false)
  CreateClientConVar("gSpotify_track_queue", 1, true, false)
  --[[LocalPlayer():SetPData("gmod_spotify_access_token", "")
  LocalPlayer():SetPData("gmod_spotify_refresh_token", "")
  LocalPlayer():SetPData("gmod_spotify_expire_time", "")]]
end

--[[
  List of used scopes (https://developer.spotify.com/documentation/general/guides/scopes/):
    * user-modify-playback-state
    * user-read-currently-playing
]]

local volume_percent
--local header = {}

local function Authorization(initial, key)
  -- Authorize the Controller using the spotify accounts service
  local hea = {}
  hea["Content-length"] = "0"

  if initial then
    local param = {
      grant_type = "authorization_code",
      code = key,
      redirect_uri = "https://henotu.github.io",
      client_id = "72e22413ad224bceb933b0c27113aa6e",
      client_secret = "CLIENT_SECRET"
    }

    local request = {
      url = "https://accounts.spotify.com/api/token",
      method = "post",
      headers = hea,
      parameters = param,
      success = function( code, json, headers )
        if code == 200 then
          local body = util.JSONToTable(json)
          local expire_time = os.time() + body["expires_in"]
          LocalPlayer():SetPData("gmod_spotify_access_token", body["access_token"])
          LocalPlayer():SetPData("gmod_spotify_refresh_token", body["refresh_token"])
          LocalPlayer():SetPData("gmod_spotify_expire_time", expire_time)
        else
          error("The provided key is probably out of date")
        end
      end,
      failed	=	function(a)
        print("request failed") --NEEDED
      end
    }
  HTTP(request)

  elseif not initial then
    --Updating the access_token
    local body = {
      client_id = "72e22413ad224bceb933b0c27113aa6e",
      client_secret = "CLIENT_SECRET",
      grant_type = "refresh_token",
      refresh_token = LocalPlayer():GetPData("gmod_spotify_refresh_token", "")
    }
    local request = {
      url = "https://accounts.spotify.com/api/token",
      method = "post",
      parameters = body,
      success = function( code, json, headers )
        if code == 200 then
          local body = util.JSONToTable(json)
          local expire_time = os.time() + body["expires_in"]
          LocalPlayer():SetPData("gmod_spotify_access_token", body["access_token"])
          LocalPlayer():SetPData("gmod_spotify_expire_time", expire_time)
        else
          error("The provided key is probably out of date")
        end
      end,
      failed = function() error("Update of token has failed, try updating authorization") end
    }
    HTTP(request)
  end

  --[[print(LocalPlayer():GetPData("gmod_spotify_access_token", nil))
  print(LocalPlayer():GetPData("gmod_spotify_refresh_token", nil))
  print(LocalPlayer():GetPData("gmod_spotify_expire_time", nil))]]
end

local function CheckForValidToken()
  if (LocalPlayer():GetPData("gmod_spotify_expire_time", "") == "") then
    error("The Addon hasn't been activated yet")
  elseif ( tonumber(LocalPlayer():GetPData("gmod_spotify_expire_time", "") ) <= os.time()) then
    print("Authorize")
    Authorization(false)
  end
end

local function CreateRequest(url, method, header, bod)
  --Create a Request Table
  local request = {
    url			= url,
    method = method,
    headers		= header or {},
    body = bod or {},
    success = function(code, json) print(code, json) end, --TEMP
    failed	=	function(a)
      error("There was an error creating that request")
    end
  }
  return request
end

local function SpaceGenerator(name, artist)
  local len = string.len(name) - string.len(artist)
  local str = ""
    if len > 0 then
      if len % 2 == 1 then
        len = len - 1
      end
      local i = 1
      while i <= (len * 0.5) do
        str = str .. " "
        i = i + 1
      end
  end
  return str
end

local function GetCurrentPlayback(cb)
  CheckForValidToken()
  local head = {}
    head["Authorization"] = "Bearer " .. LocalPlayer():GetPData("gmod_spotify_access_token", "")
    head["Content-Length"] = "0"
  local request = CreateRequest("https://api.spotify.com/v1/me/player", "GET", head)
  request["success"] = function(code, json)
    local tbl = util.JSONToTable(json)
    paused = tbl["is_playing"]
    print(type(tbl["is_playing"]))
    if paused then
      volume_percent = tbl["device"]["volume_percent"]
      if (tbl["device"]["type"] == "Computer") then
        LocalPlayer():SetPData("gmod_spotify_device_id", tbl["device"]["id"])
      end
    end
    if cb then
      cb(paused)
    end
  end
  HTTP(request)
end

local function PausePlayback()
  -- Pause Playback using the spotify api
  CheckForValidToken()
  local head = {}
  head["Content-Length"] = "0"
  head["Authorization"] = "Bearer " .. LocalPlayer():GetPData("gmod_spotify_access_token", "")
  paused = true
  HTTP(CreateRequest("https://api.spotify.com/v1/me/player/pause", "PUT", head))
end

local function ContinuePlayback()
  -- Continue Playback using the spotify api
  CheckForValidToken()
  local head = {}
  head["Content-Length"] = "0"
  head["Authorization"] = "Bearer " .. LocalPlayer():GetPData("gmod_spotify_access_token", "")
  local request = CreateRequest("https://api.spotify.com/v1/me/player/play", "PUT", head)
  request["success"] = function(code, json)
    if code == 404 then
      tbl = util.JSONToTable(json)
      if (tbl["error"]["reason"] == "NO_ACTIVE_DEVICE") and (LocalPlayer():GetPData("gmod_spotify_device_id", "") ~= "" ) then
        local header = {}
        header["Content-Length"] = "0"
        header["Authorization"] = "Bearer " .. LocalPlayer():GetPData("gmod_spotify_access_token", "")
        HTTP(CreateRequest("https://api.spotify.com/v1/me/player/play?devide_id=" .. LocalPlayer():GetPData("gmod_spotify_device_id", ""), "PUT", header))
      elseif (tbl["error"]["message"] == "Player command failed: Restriction violated") then
        paused = true
      end
    end
  end
  paused = false
  HTTP(request)
end

local function PlayTrack(uri)
  local head = {}
  head["Accept"] = "application/json"
  head["Content-Type"] = "application/json"
  head["Authorization"] = "Bearer " .. LocalPlayer():GetPData("gmod_spotify_access_token")
  head["Content-length"] = "0"
  if GetConVar("gSpotify_track_queue"):GetBool() then
    local url = "https://api.spotify.com/v1/me/player/queue?uri=" .. uri
    HTTP(CreateRequest(url, "POST", head))
  else
    local request = CreateRequest("https://api.spotify.com/v1/me/player/play", "PUT", head)
    request["body"] = "{\"uris\":[\"".. uri .."\"],\"position_ms\":0}"
    HTTP(request)
  end
end

local function ChangeVolume(percent)
  CheckForValidToken()
  local head = {}
  head["Accept"] = "application/json"
  head["Content-Type"] = "application/json"
  head["Authorization"] = "Bearer " .. LocalPlayer():GetPData("gmod_spotify_access_token")
  head["Content-length"] = "0"
  local url = "https://api.spotify.com/v1/me/player/volume?volume_percent=" .. tostring(percent)
  HTTP(CreateRequest(url, "PUT", head))
end

local function SkipTrack(prev)
  CheckForValidToken()
  head = {}
  head["Accept"] = "application/json"
  head["Content-Type"] = "application/json"
  head["Authorization"] = "Bearer " .. LocalPlayer():GetPData("gmod_spotify_access_token")
  head["Content-length"] = "0"
  local url
  if prev then
    url = "https://api.spotify.com/v1/me/player/previous"
  else
    url = "https://api.spotify.com/v1/me/player/next"
  end
  HTTP(CreateRequest(url, "POST", head))
end

local function Search(text, cb, obj)
  CheckForValidToken()
  local query = string.Replace(text, " ", "+")
  local head = {}
  head["Authorization"] = "Bearer " .. LocalPlayer():GetPData("gmod_spotify_access_token")
  local request = CreateRequest("https://api.spotify.com/v1/search?type=track&limit=3&market=DE&q=" .. query, "GET", head)
  local tracks = {}
  request["success"] = function(code, json)
    local tbl = util.JSONToTable(json)
    local i = 1
    if code == 200 then
      for k, v in pairs(tbl["tracks"]["items"]) do
        local tblName = "track" .. tostring(k)
        tracks[tblName] = {}
        tracks[tblName]["name"] = tbl["tracks"]["items"][i]["name"]
        tracks[tblName]["artist"] = tbl["tracks"]["items"][i]["album"]["artists"][1]["name"]
        tracks[tblName]["album"] = tbl["tracks"]["items"][i]["album"]["name"]
        tracks[tblName]["uri"] = tbl["tracks"]["items"][i]["uri"]
        i = i + 1
      end
    end
    cb(true, obj, tracks)
  end
  HTTP(request)
end

local function ShowSearchResults(tblExists, obj, tbl)
  if tblExists then
    obj[2]:Clear()
    for k, v in pairs(tbl) do
      local resultButton = obj[2]:Add("DButton")
      local name = v["name"]
      local artist = v["artist"]
      resultButton:SetText("\n" .. SpaceGenerator(artist, name) .. name .. "\n".. SpaceGenerator(name, artist) .. artist .. "\n")
      resultButton:SizeToContentsY()
      resultButton.Paint = function( self, w, h ) draw.RoundedBox( 4, 0, 0, (w - 10), h, Color(255, 255, 255, 255)) end
      resultButton:Dock(TOP)
      resultButton:DockMargin(0,0,0,5)
      resultButton.DoClick = function()
        PlayTrack(v["uri"])
      end
    end
  else
    Search(obj[1]:GetValue(), ShowSearchResults, obj)
  end
end

local function PlayStateChange(paused)
  if paused == false then
    ContinuePlayback()
  elseif paused == true then
    PausePlayback()
  else
    GetCurrentPlayback(PlayStateChange)
  end
end

local function SetPlayImage(obj)
  if (not paused) then
    obj:SetImage("gSpotify/Pause.png")
  else
    obj:SetImage("gSpotify/Play.png")
  end
end

local function ChangePlayButton(obj, clicked)
  if clicked then
    local cV = GetConVar("gSpotify_track_queue")
    cV:SetBool(not cV:GetBool())
  end
  if GetConVar("gSpotify_track_queue"):GetBool() then
    obj:SetText("☑ Queue this track\n\n  ☐ Play this track")
  else
    obj:SetText("☐ Queue this track\n\n  ☑ Play this track")
  end
end

-- Frontend -> 1DB954
local function RunWindow()

  GetCurrentPlayback()

  local frame = vgui.Create("DFrame")
  frame.Paint = function( self, w, h ) draw.RoundedBox( 4, 0, 0, w, h, Color(86, 86, 86, 255)) end
  frame:SetPos(0.325 * ScrW(), 0.325 * ScrH())
  frame:SetSize(0.35 * ScrW(), 0.35 * ScrH())
  frame:SetTitle("Spotify Controller")
  frame:MakePopup()

  local sheet = vgui.Create("DPropertySheet", frame)
  sheet.Paint = function( self, w, h ) draw.RoundedBox( 0, 0, 0, w, h, Color(86, 86, 86, 255)) end
  sheet:SetSize(frame:GetWide(), 0.93 * frame:GetTall())
  sheet:SetPos(0, 0.07 * frame:GetTall())

  local control = vgui.Create("DPanel", sheet)
  control.Paint = function( self, w, h ) draw.RoundedBox( 4, 0, 0, w, h, Color(55, 55, 55, 255)) end
  control:SetSize( sheet:GetWide(), sheet:GetTall())
  sheet:AddSheet("Control", control, "icon16/sound.png")

  local volumeButtonUp = vgui.Create("DButton", control)
  volumeButtonUp:SetPos(0,0)
  volumeButtonUp:SetSize(0.5 * control:GetWide(), 0.2 * control:GetTall())
  volumeButtonUp:SetText("+")
  volumeButtonUp.DoClick = function()
    if volume_percent <= 90 then
      volume_percent = volume_percent + 10
      ChangeVolume(volume_percent)
    elseif volume_percent > 90 then
      volume_percent = 100
      ChangeVolume(100)
    end
  end


  local volumeButtonDown = vgui.Create("DButton", control)
  volumeButtonDown:SetPos(0.5 * control:GetWide(), 0)
  volumeButtonDown:SetSize(0.5 * control:GetWide(), 0.2 * control:GetTall())
  volumeButtonDown:SetText("-")
  volumeButtonDown.DoClick = function()
    if volume_percent >= 10 then
      volume_percent = volume_percent - 10
      ChangeVolume(volume_percent)
    elseif volume_percent < 10 then
      volume_percent = 0
      ChangeVolume(100)
    end
  end

  local buttonNext = vgui.Create("DButton", control)
  buttonNext:SetPos(0, 0.2 * control:GetTall())
  buttonNext:SetSize(0.5 * control:GetWide(), 0.2 * control:GetTall())
  buttonNext:SetText("next")
  buttonNext.DoClick = function()
    SkipTrack(false)
  end

  local buttonPrev = vgui.Create("DButton", control)
  buttonPrev:SetPos(0.5 * control:GetWide(), 0.2 * control:GetTall())
  buttonPrev:SetSize(0.5 * control:GetWide(), 0.2 * control:GetTall())
  buttonPrev:SetText("prev")
  buttonPrev.DoClick = function()
    SkipTrack(true)
  end


  local infoLabel = vgui.Create("DLabel", control)
  infoLabel:Dock(FILL)
  infoLabel:SetText("This Addon is not enabled. \nGo to the settings tab to get startet with the Spotify controller.\n")
  infoLabel:SetVisible(false)

  local button = vgui.Create("DImageButton", control)
  button:SetSize(0.25 * control:GetWide(), 0.33 * control:GetTall())
  button:SetPos(0.375 * control:GetWide(), 0.335 * control:GetTall())
  --button.OnClick = PausePlayback

  local gSpotify_enable = GetConVar("gSpotify_enable"):GetBool() or false

  if not gSpotify_enable then
    infoLabel:SetVisible(true)
  end

  local search = vgui.Create("DPanel", sheet)
  search.Paint = function( self, w, h ) draw.RoundedBox( 4, 0, 0, w, h, Color(55, 55, 55, 255)) end
  search:SetSize( sheet:GetWide(), sheet:GetTall())
  sheet:AddSheet("Search", search, "icon16/magnifier.png")

  local scrollPanel = vgui.Create("DScrollPanel", search)
  scrollPanel:SetPos(0.38 * search:GetWide(), 0.02 * search:GetTall())
  scrollPanel:SetSize(0.6 * search:GetWide(), 0.96 * search:GetTall())

  local playButton = vgui.Create("DButton", search)
  playButton:SetSize(0.25 * search:GetWide(), 0.3 * search:GetTall())
  playButton:SetPos(0.05 * search:GetWide(), 0.25 * search:GetTall())
  playButton.Paint = function( self, w, h ) draw.RoundedBox( 4, 0, 0, w, h, Color(55, 55, 55, 0)) end
  playButton:SetTextColor(Color(255,255,255,255))
  playButton.DoClick = function()
    ChangePlayButton(playButton, true)
  end

  ChangePlayButton(playButton)

  local searchBar = vgui.Create("DTextEntry", search)
  searchBar:SetSize(0.35 * search:GetWide(), 0.15 * search:GetTall())
  searchBar:SetPos(0.01 * search:GetWide(), 0.02 * search:GetTall())
  searchBar:SetPlaceholderText("Press ENTER to search a track...")
  searchBar.OnEnter = function()
    local obj = {
      searchBar,
      scrollPanel
    }
    ShowSearchResults(false, obj)
  end


  local settings = vgui.Create("DPanel", sheet)
  settings.Paint = function( self, w, h ) draw.RoundedBox( 4, 0, 0, w, h, Color(55, 55, 55, 255)) end
  settings:SetSize( sheet:GetWide(), sheet:GetTall())
  sheet:AddSheet("Settings", settings, "icon16/page_white_gear.png")

  local authorize = vgui.Create("DPanel")
  authorize.Paint = function( self, w, h ) draw.RoundedBox( 4, 0, 0, w, h, Color(55, 55, 55, 255)) end
  authorize:SetSize( sheet:GetWide(), sheet:GetTall())
  authorize:SetVisible(GetConVar("gSpotify_show_Authorization"):GetBool())
  sheet:AddSheet("Authorization", authorize, "icon16/exclamation.png")

  local linkLabelInfo = vgui.Create("DLabel", authorize)
  linkLabelInfo:SetPos(0,0)
  linkLabelInfo:SetTall(0.25 * authorize:GetTall())
  linkLabelInfo:SetText("To authorize this controller, please click")
  linkLabelInfo:SizeToContentsX()

  local keyEntry = vgui.Create("DTextEntry", authorize)
  keyEntry:SetSize(authorize:GetWide(), 0.2 * authorize:GetTall())
  keyEntry:SetPos(0, 0.25 * authorize:GetTall())
  keyEntry:SetPlaceholderText("Copy the OAuthKey here")
  keyEntry.OnChange = function()
    if string.len(keyEntry:GetValue()) > 20 then
      Authorization(true, keyEntry:GetValue())
    end
  end

  local linkLabel = vgui.Create("DLabelURL", authorize)
  linkLabel:SetPos(linkLabelInfo:GetWide(), 0)
  linkLabel:SetColor(Color(255,255,255,255))
  linkLabel:SetText(" here")
  linkLabel:SetSize(authorize:GetWide() - linkLabelInfo:GetWide(), 0.25 * authorize:GetTall())
  linkLabel:SetURL("https://accounts.spotify.com/authorize?client_id=72e22413ad224bceb933b0c27113aa6e&response_type=code&redirect_uri=https://henotu.github.io&scope=user-modify-playback-state%20user-read-currently-playing%20user-read-playback-state")
end

concommand.Add("gSpot", RunWindow)
concommand.Add("gPause", PlayStateChange)
concommand.Add("gCur", GetCurrentPlayback)
