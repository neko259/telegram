= Available configurations (add to minetest.conf) =
* telegram.token -- requred, bot token aquired for your bot in telegram
* telegram.chatid -- id of the chat you will relay messages to. You can start the bot without it and send groupid command to get it later.
* telegram.timeout -- update periodicity. The bot does check for the new messages with this timeout, but the in-game messages are sent to telegram immediately. Increase for better performance.
* telegram.announce_mode -- announce player joining or leaving. Available options: none, privileged, all. Priviliged means interact for now. Player deaths may be announced in the future, but not yet.
* telegram.message_color -- color of the telegram messages in the in-game chat

