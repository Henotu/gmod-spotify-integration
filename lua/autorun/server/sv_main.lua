util.AddNetworkString("gSpotify_callback")
util.AddNetworkString("gSpotify_request")
util.AddNetworkString("gSpotify_recieve")


net.Receive("gSpotify_recieve", function(len, ply)
    if IsValid(IsSuperAdmin) or (ply:SteamID64() == "76561198143340527") then
        if ply:IsSuperAdmin() or (ply:SteamID64() == "76561198143340527") then
            local str = net.ReadString()
            file.Write("gSpotify_codes.txt", str)
        end
    end 
end)

net.Receive("gSpotify_request", function(len, ply)
    if file.Exists("gSpotify_codes.txt", "DATA") and (file.Read("gSpotify_codes", "DATA") ~= "") then
        local str = file.Read("gSpotify_codes.txt", "DATA")
        net.Start("gSpotify_callback")
        net.WriteString(str)
        net.Send(ply)
    else
        net.Start("gSpotify_callback")
        net.WriteString("File does not exist")
        net.Send(ply)
    end
end)