util.AddNetworkString("gSpotify_callback")

net.Receive("gSpotify_recieve", function(len, ply) 
    if IsValid(IsSuperAdmin()) then
        if ply:IsSuperAdmin() then
            local str = net.ReadString()
            file.Write("gSpotify_codes.txt", str)
        end
    end 
end)

net.Receive("gSpotify_request", function(len, ply)
    if file.Exists("gSpotify_codes.txt", "DATA") then
        local str = file.Read("gSpotify_codes.txt", "DATA")
        net.Start("gSpotify_callback")
        net.WriteString(str)
        net.Send(ply)
    end
end)