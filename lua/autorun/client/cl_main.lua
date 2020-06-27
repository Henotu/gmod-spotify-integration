-- Backend

if not ConVarExists("gSpotify_enable") then
  CreateClientConVar("gSpotify_enable", 0, true, false)
  LocalPlayer():SetPData("gmod_spotify_access_token", "")
  LocalPlayer():SetPData("gmod_spotify_refresh_token", "")
  LocalPlayer():SetPData("gmod_spotify_expire_time", "")
end

--[[
  List of used scopes (https://developer.spotify.com/documentation/general/guides/scopes/):
    * user-modify-playback-state
    * user-read-currently-playing
]]

--curl -d grant_type=authorization_code -d code=AQD4o5zede64dTUolRk9CAdVXoPeKzdeAzBJsMoaVq4Kggl3dlqHpUfPJMa7wMlEixy1cGiHerjrGHfxupq9nG3JYDpaCxbhvuESwQO8v-XaajAEWIoa6LNUwqEfMlSd-z7KD5_dR-MLfHmfaWeFfBEPG-mES5x9ipwvQIOV-qHwMiHxJUWYllRtTRL3ZGoMdeWSSZgY1HOMVryK_eCuDdS9fGQu907khzEdbTxvXiWH624CMg -d redirect_uri=https%3A%2F%2Fhenotu.github.io -d client_id=72e22413ad224bceb933b0c27113aa6e -d client_secret=ffd81e619c174272aa983fdb7461e044 https://accounts.spotify.com/api/token
local paused
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
      client_secret = "ffd81e619c174272aa983fdb7461e044"
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
      client_secret = "ffd81e619c174272aa983fdb7461e044",
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

  --print(LocalPlayer():GetPData("gmod_spotify_access_token", nil))
  print(LocalPlayer():GetPData("gmod_spotify_refresh_token", nil))
  print(LocalPlayer():GetPData("gmod_spotify_expire_time", nil))
end

local function CheckForValidToken()
  if tonumber(LocalPlayer():GetPData("gmod_spotify_expire_time", nil)) <= os.time() then
    Authorization(false)
  end
end

local function StoreOAuthKey()
  -- Stores the Key got from Authorization() inside a medium yet to be determined
end

local function ReadOAuthKey()

end

function CreateRequest(url, method, header, bod)
  --Create a Request Table
  --header["Content-length"] = "0"
--  header["Authorization"]  = "Bearer AQC4IOhtFiV2tks3Qv_xMC6jGDHQ36GV40v-Xl1FD4dorslkljrBXM6fo4F6QEljEKZmJgPhuD8x3vJdt85B7pP4UyH1v-S-psde-e02Eg3u7ShPw_090a1hdgTf2gzAyhb8nfM_BMj-O8LOuBhUKne1sNZt38Vo6MHkCxisGsGZTtc0-Ju-gxwbxXuJdLtizXhCJviLEzgv-TdsHAb6Y4lPmHJ0xsoHGVUzkj5hgEsfkkWvIw"
  local request = {
    url			= url,
    method = method,
    headers		= header or {},
    body = bod or {},
    failed	=	function(a)
      error("There was an error creating that request")
    end
  }
  return request
end

local function PausePlayback()
  -- Pause Playback using the spotify api
  CheckForValidToken()
  local head = {}
  head["Content-Length"] = "0"
  head["Authorization"] = "Bearer " .. LocalPlayer():GetPData("gmod_spotify_access_token", "")
  HTTP(CreateRequest("https://api.spotify.com/v1/me/player/pause", "PUT", head))
  paused = true
end

local function ContinuePlayback()
  -- Continue Playback using the spotify api
  CheckForValidToken()
  local head = {}
  head["Content-Length"] = "0"
  head["Authorization"] = "Bearer " .. LocalPlayer():GetPData("gmod_spotify_access_token", "")
  HTTP(CreateRequest("https://api.spotify.com/v1/me/player/play", "PUT", head))
  paused = false
end

local function ChangeVolume()

end


local function PlayStateChange()
  if paused then
    ContinuePlayback()
  else
    PausePlayback()
  end
end

local function SetPlayImage(obj)
  if (not paused) then
    obj:SetImage("gSpotify/Pause.png")
  else
    obj:SetImage("gSpotify/Play.png")
  end
end

-- Frontend -> 1DB954
local function RunWindow()


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

  local infoLabel = vgui.Create("DLabel", control)
  infoLabel:Dock(FILL)
  infoLabel:SetText("This Addon is not enabled. \nGo to the settings tab to get startet with the Spotify controller.\n")
  infoLabel:SetVisible(true)

  local button = vgui.Create("DImageButton", control)
  button:SetSize(0.25 * control:GetWide(), 0.33 * control:GetTall())
  button:SetPos(0.375 * control:GetWide(), 0.335 * control:GetTall())
  --button.OnClick = PausePlayback
  PlayStateChange(button)

  local gSpotify_enable = GetConVar("gSpotify_enable"):GetBool() or false


  if not gSpotify_enable then
    infoLabel:SetVisible(true)
  end

  local settings = vgui.Create("DPanel", sheet)
  settings.Paint = function( self, w, h ) draw.RoundedBox( 4, 0, 0, w, h, Color(55, 55, 55, 255)) end
  settings:SetSize( sheet:GetWide(), sheet:GetTall())
  sheet:AddSheet("Settings", settings, "icon16/page_white_gear.png")

  local authorize = vgui.Create("DPanel")
  authorize.Paint = function( self, w, h ) draw.RoundedBox( 4, 0, 0, w, h, Color(55, 55, 55, 255)) end
  authorize:SetSize( sheet:GetWide(), sheet:GetTall())
  --authorize:SizeToContents()
  sheet:AddSheet("Authorization", authorize, "icon16/exclamation.png")

  local linkLabelInfo = vgui.Create("DLabel", authorize)
  linkLabelInfo:SetPos(0,0)
  linkLabelInfo:SetTall(0.25 * authorize:GetTall())
  linkLabelInfo:SetText("To authorize this controller, please click")
  linkLabelInfo:SizeToContentsX()


  local linkLabel = vgui.Create("DLabelURL", authorize)
  linkLabel:SetPos(linkLabelInfo:GetWide(), 0)
  linkLabel:SetColor(Color(255,255,255,255))
  linkLabel:SetText(" here")
  linkLabel:SetSize(authorize:GetWide() - linkLabelInfo:GetWide(), 0.25 * authorize:GetTall())
  linkLabel:SetURL("https://accounts.spotify.com/authorize?client_id=72e22413ad224bceb933b0c27113aa6e&response_type=code&redirect_uri=https://henotu.github.io&scope=user-modify-playback-state%20user-read-currently-playing")

  local keyEntry = vgui.Create("DTextEntry", authorize)
  keyEntry:SetSize(authorize:GetWide(), 0.2 * authorize:GetTall())
  keyEntry:SetPos(0, 0.25 * authorize:GetTall())
  keyEntry:SetPlaceholderText("Copy the OAuthKey here")
  keyEntry.OnChange = function()
    if string.len(keyEntry:GetValue()) > 20 then
      Authorization(true, keyEntry:GetValue())
    end
  end
end

concommand.Add("gSpot", RunWindow)
concommand.Add("gPause", PlayStateChange)
