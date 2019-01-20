local current_mod_name = minetest.get_current_modname()
local modpath = minetest.get_modpath(current_mod_name)

telegram = {}

local token = minetest.settings:get("telegram.token")
local chat_id = minetest.settings:get("telegram.chatid")
local updates_timeout = tonumber(minetest.settings:get("telegram.timeout"))

if not updates_timeout then
    updates_timeout = 1
end

if not token then
    error("Bot token should be specified in the config in order to work.")
end

local UPDATES_LIMIT = 10

local offset = 0
local http_in_progress = false

local JSON = dofile(modpath .. "/JSON.lua")

http_api = minetest.request_http_api()
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
                            --print(update.message.text)
                            telegram.on_text_receive(update.message)
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

function telegram.on_text_receive(msg)
    local comm, bot_name = string.match(msg.text, "/(%a+)@(.+)")
    -- TODO Check the bot name
    local command = COMMANDS[comm]
    if command then
        command(msg)
    else
        local message_text = msg.text
        if msg.reply_to_message and msg.reply_to_message.text then
            message_text = ">>" .. msg.reply_to_message.text .. "\n" .. message_text
        end
        minetest.chat_send_all("<" .. msg.from.first_name .. "@TG> " .. message_text)
    end
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
        telegram.send_message(chat_id, "<" .. name .. "@MT> " .. message)
        return false
    end)
end

dofile(modpath .. "/commands.lua")
