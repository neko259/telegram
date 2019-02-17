local current_mod_name = minetest.get_current_modname()
local modpath = minetest.get_modpath(current_mod_name)

local ANNOUNCE_NONE = "none"
local ANNOUNCE_PRIVILEGED = "privileged"
local ANNOUNCE_ALL = "all"

telegram = {}

local token = minetest.settings:get("telegram.token")
local chat_id = minetest.settings:get("telegram.chatid")
local updates_timeout = tonumber(minetest.settings:get("telegram.timeout"))

if not updates_timeout then
    updates_timeout = 1
end

local announce_mode = minetest.settings:get("telegram.announce_mode")
if not announce_mode then
    announce_mode = ANNOUNCE_NONE
end
local message_color = minetest.settings:get("telegram.message_color") or "#339933"

if not token then
    error("Bot token should be specified in the config in order to work.")
end

local UPDATES_LIMIT = 10

local offset = 0
local http_in_progress = false

local JSON = dofile(modpath .. "/JSON.lua")

local http_api = minetest.request_http_api()
if not http_api then
    error("HTTP API cannot be enabled. Add the mods to trusted.")
end

local COMMANDS = {}

function telegram.register_command(name, command)
    COMMANDS[name] = command
end

local function make_request(method, request_body, callback)
    local response = {}

    local request = {
        url = "https://api.telegram.org/bot" .. token .. "/" .. method,
        timeout = 10,
        post_data = request_body
    }

    -- We can run request without callback, but minetest fails in this case
    if not callback then
        callback = function(response)
        end
    end
    http_api.fetch(request, callback)
end

local function process_updates(response)
    if response.completed then
        local updates = JSON:decode(response.data)
        if updates then
            if updates.result then
                for key, update in pairs(updates.result) do
                    if update.message then
                        if update.message.text then
                            telegram.on_text_receive(update.message)
                        else
                            telegram.notify_non_text_receive(update.message)
                        end
                    end
                    -- TODO Other types of messages
                    offset = update.update_id + 1
                end
            end
        end
    end

    http_in_progress = false
end

function telegram.send_message(chat_id, text)
    local allowed_parse_mode = {
        ["Markdown"] = true,
        ["HTML"] = true
    }

    if (not allowed_parse_mode[parse_mode]) then parse_mode = "" end

    local request_body = {}

    request_body.chat_id = chat_id
    request_body.text = tostring(text)
    request_body.parse_mode = parse_mode
    request_body.reply_markup = ""

    make_request("sendMessage", request_body, nil)
end

local function get_command(msg)
    local comm = nil
    local bot_name = nil

    comm, bot_name = string.match(msg.text, "/(%a+)@(.+)")
    if not comm then
        comm = string.match(msg.text, "/(%a+)")
    end

    -- TODO Check the bot name if using full command
    return COMMANDS[comm]
end

function telegram.on_text_receive(msg)
    local command = get_command(msg)
    if command then
        command(msg)
    else
        local message_text = msg.text
        if msg.reply_to_message and msg.reply_to_message.text then
            message_text = ">>" .. msg.reply_to_message.text .. "\n" .. message_text
        end
        minetest.chat_send_all(minetest.colorize(message_color, "<" .. msg.from.first_name .. "> " .. message_text))
    end
end

function telegram.notify_non_text_receive(message)
    local payload = 'something'

    if message.photo then
        payload = 'photo'
    elseif message.voice then
        payload = 'voice message'
    elseif message.sticker then
        payload = 'sticker'
    end

    minetest.chat_send_all(minetest.colorize(message_color, message.from.first_name .. " sent " .. payload))
end

local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer >= updates_timeout and not http_in_progress then
        local timeout = 0

        print(offset)
        local request_body = {
            offset = offset,
            limit = UPDATES_LIMIT,
            timeout = timeout,
            allowed_updates = nil
        }

        http_in_progress = true
        make_request("getUpdates", request_body, process_updates)
        timer = 0
    end
end)

-- Don't send messages from MT to telegram if we don't know where to
if chat_id then
    minetest.register_on_chat_message(function(name, message)
        telegram.send_message(chat_id, "<" .. name .. "> " .. message)
        return false
    end)

    if announce_mode ~= ANNOUNCE_NONE then
        minetest.register_on_joinplayer(function(player)
            local name = player:get_player_name()
            if announce_mode == ANNOUNCE_ALL or minetest.check_player_privs(name, "interact") then
                telegram.send_message(chat_id, name .. " joined the game.")
            end
        end)

        minetest.register_on_leaveplayer(function(player, timed_out)
            local name = player:get_player_name()
            if announce_mode == ANNOUNCE_ALL or minetest.check_player_privs(name, "interact") then
                telegram.send_message(chat_id, name .. " left the game.")
            end
        end)
    end
end

dofile(modpath .. "/commands.lua")
