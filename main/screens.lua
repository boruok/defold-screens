local metadata = {}
local history = {}
local last_proxy
local co

local M = {}
M.MSG_DISABLE = hash("disable")
M.MSG_FINAL   = hash("final")
M.MSG_UNLOAD  = hash("unload")
M.MSG_LOAD    = hash("load")
M.MSG_INIT    = hash("init")
M.MSG_ENABLE  = hash("enable")
M.MSG_ACQUIRE_INPUT = hash("acquire_input_focus")
M.MSG_RELEASE_INPUT = hash("release_input_focus")

M.MSG_LOADED = hash("proxy_loaded")
M.MSG_SHOW   = hash("show")
M.MSG_BACK   = hash("back")

M.MSG_POPUP_OPENED = hash("popup_opened")
M.MSG_POPUP_CLOSED = hash("popup_closed")

M.url = msg.url("main", "/screens", "controller")
M.transition = {
	url  = msg.url("main", "/transition", "transition"),
	msg_play = hash("transition_play"),
	msg_done = hash("transition_done"),
	id_in  = "fade_in",
	id_out = "fade_out",
	render_order = 2,
}

---@param id string
---@return boolean
local function is_screen_popup(id)
	return string.find(id, "popup") ~= nil
end

---@param id string
---@return boolean
local function is_screen_listed(id)
	for _, prev in ipairs(history) do
		if prev == id then
			return true
		end
	end
	return false
end

---@return url
local function get_last_proxy_url()
	return msg.url(history[#history], "/go", history[#history])
end

---@param id string
---@return url
local function get_screen_url(id)
	return msg.url(id, "/go", id)
end

---@param screen url
local function unload(screen)
	msg.post(screen, M.MSG_DISABLE)
	msg.post(screen, M.MSG_FINAL)
	msg.post(screen, M.MSG_UNLOAD)
end

---@param screen string
local function load(screen)
	if not is_screen_listed(screen) then
		history[#history+1] = screen
	end

	screen = "#" .. screen
	msg.post(screen, M.MSG_LOAD)
	msg.post(screen, M.MSG_INIT)
end

---@param screen string
---@param meta table|nil
local function show(screen, meta)
	co = coroutine.create(function()
		local play_transition = function(animation)
			if go.exists(M.transition.url) then
				msg.post(M.transition.url, M.transition.msg_play, { animation = animation })
				coroutine.yield()
			end
		end

		if is_screen_popup(screen) then
			msg.post(get_last_proxy_url(), M.MSG_RELEASE_INPUT)
		else
			if #history > 0 then
				if is_screen_popup(history[#history]) then
					play_transition(M.transition.id_in)

					for i = #history, -1, -1 do
						local prev = history[i]
						if prev == screen then
							break
						end
						metadata[screen] = nil
						table.remove(history, i)

						unload(get_screen_url(prev))
					end
				else
					metadata[screen] = nil

					msg.post(last_proxy, M.MSG_RELEASE_INPUT)
					play_transition(M.transition.id_in)
					unload(last_proxy)
				end
			end
		end

		metadata[screen] = meta
		load(screen)
		coroutine.yield()

		if is_screen_popup(screen) then
			msg.post(get_screen_url(history[#history-1]), M.MSG_POPUP_OPENED)
		end

		msg.post(last_proxy, M.MSG_ENABLE)
		msg.post(last_proxy, M.MSG_ACQUIRE_INPUT)
		msg.post(get_last_proxy_url(), M.MSG_ACQUIRE_INPUT)
		play_transition(M.transition.id_out)
	end)

	coroutine.resume(co)
end

---@param meta table|nil
local function back(meta)
	if is_screen_popup(history[#history]) then
		unload(last_proxy)

		table.remove(history, #history)
		last_proxy = get_screen_url(history[#history])
		msg.post(get_last_proxy_url(), M.MSG_ACQUIRE_INPUT)
		msg.post(get_last_proxy_url(), M.MSG_POPUP_CLOSED, meta)
	else
		table.remove(history, #history)
		show(history[#history], meta)
	end
end

---@param screen string
---@param meta table|nil
function M.show(screen, meta)
	msg.post(M.url, "show", { screen = screen, meta = meta })
end

---@param meta table|nil
function M.back(meta)
	msg.post(M.url, "back", { meta = meta })
end

---@param screen any
function M.meta(screen)
	return metadata[screen]
end

function M.on_message(self, message_id, message, sender)
	if message_id == M.MSG_LOADED then
		last_proxy = sender
		coroutine.resume(co)
	elseif message_id == M.MSG_SHOW then
		show(message.screen, message.meta)
	elseif message_id == M.MSG_BACK then
		back(message.meta)
	elseif message_id == M.transition.msg_done then
		coroutine.resume(co)
	end
end

return M
