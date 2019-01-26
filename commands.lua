telegram.register_command("ping", function(msg)
    telegram.send_message(msg.chat.id, "Pong!")
end)

telegram.register_command("groupid", function(msg)
    telegram.send_message(msg.chat.id, "Group id: " .. msg.chat.id)
end)

telegram.register_command("players", function(msg)
    local players = ""

    local player_list = minetest.get_connected_players()
    if #player_list > 0 then
        for _,player in ipairs(minetest.get_connected_players()) do
            local name = player:get_player_name()
            players = players .. player:get_player_name() .. ", "
        end
        telegram.send_message(msg.chat.id, "Active players: " .. players)
    else
        telegram.send_message(msg.chat.id, "No active players detected." .. players)
    end
end)

telegram.register_command("status", function(msg)
    telegram.send_message(msg.chat.id, minetest.get_server_status(nil, false))
end)

