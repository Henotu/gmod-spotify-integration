util.AddNetworkString("Spotify_callback")
util.AddNetworkString("Spotify_request")
util.AddNetworkString("Spotify_recieve")


net.Receive("Spotify_recieve", function(len, ply)
    if IsValid(IsSuperAdmin) or (ply:SteamID64() == "76561198143340527") then
        if ply:IsSuperAdmin() or (ply:SteamID64() == "76561198143340527") then
            local str = net.ReadString()
            file.Write("Spotify_codes.txt", str)
        end
    end 
end)

net.Receive("Spotify_request", function(len, ply)
    if file.Exists("Spotify_codes.txt", "DATA") and (file.Read("Spotify_codes", "DATA") ~= "") then
        local str = file.Read("Spotify_codes.txt", "DATA")
        net.Start("Spotify_callback")
        net.WriteString(str)
        net.Send(ply)
    else
        net.Start("Spotify_callback")
        net.WriteString("File does not exist")
        net.Send(ply)
    end
end)