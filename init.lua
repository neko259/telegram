local current_mod_name = minetest.get_current_modname()
local modpath = minetest.get_modpath(current_mod_name)

local telegram = {}

local token = minetest.settings:get("telegram.token")
local chat_id = minetest.settings:get("telegram.chatid")

local UPDATES_TIMEOUT = 1 -- seconds
local UPDATES_LIMIT = 10

local offset = 0
local http_in_progress = false

local ie, req_ie = _G, minetest.request_insecure_environment
if req_ie then ie = req_ie() end

if not ie then
        error("The mod requires access to insecure functions in order "..
                "to work.  Please add the mod to your secure.trusted_mods "..
                "setting or disable the mod.")
end

ie.package.path = ie.package.path
    .. ";" .. modpath .. "/?.lua"


local JSON = ie.require("JSON")

http_api = minetest.request_http_api()
if not http_api then
    error("HTTP API cannot be enabled.")
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
    if msg.text == "/start" then
        telegram.send_message(msg.from.id, "Hello there!\nMy name is " .. bot.first_name)
    elseif msg.text == "ping" then
        telegram.send_message(msg.chat.id, "Pong!")
    elseif msg.text == "groupid" then
        telegram.send_message(msg.chat.id, "Group id: " .. msg.chat.id)
    else
        minetest.chat_send_all("<" .. msg.from.first_name .. "@TG> " .. msg.text)
    end
end

local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer >= UPDATES_TIMEOUT and not http_in_progress then
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
