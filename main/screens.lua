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

M.url_controller = msg.url("main", "/screens", "controller")
M.transition = {
	url  = msg.url("main", "/transition", "transition"),
	msg_play = hash("transition_play"),
	msg_done = hash("transition_done"),
	id_in  = "fade_in",
	id_out = "fade_out",
	render_order = 2,
}

---@param proxy string
---@return boolean
local function is_proxy_popup(proxy)
	return string.find(proxy, "popup") ~= nil
end

---@param proxy string
---@return boolean
local function is_proxy_listed(proxy)
	for _, name in ipairs(history) do
		if name == proxy then
			return true
		end
	end
	return false
end

---@return url
local function get_last_proxy_url()
	return msg.url(history[#history], "/go", history[#history])
end

---@param proxy string
---@return url
local function get_proxy_url(proxy)
	return msg.url("main", "/screens", proxy)
end

---@param proxy url
local function unload(proxy)
	msg.post(proxy, M.MSG_DISABLE)
	msg.post(proxy, M.MSG_FINAL)
	msg.post(proxy, M.MSG_UNLOAD)
end

---@param proxy string
local function load(proxy)
	if not is_proxy_listed(proxy) then
		history[#history+1] = proxy
	end

	proxy = "#" .. proxy
	msg.post(proxy, M.MSG_LOAD)
	msg.post(proxy, M.MSG_INIT)
end

---@param proxy string
---@param meta table|nil
local function show(proxy, meta)
	co = coroutine.create(function()
		local transite = function(animation)
			if go.exists(M.transition.url) then
				msg.post(M.transition.url, M.transition.msg_play, { animation = animation })
				coroutine.yield()
			end
		end

		if is_proxy_popup(proxy) then
			msg.post(get_last_proxy_url(), M.MSG_RELEASE_INPUT)
		else
			if #history > 0 then
				if is_proxy_popup(history[#history]) then
					transite(M.transition.id_in)
					-- clear prev popups + last proxy
					for i = #history, -1, -1 do
						local name = history[i]
						if name == proxy then
							break
						end
						metadata[proxy] = nil
						table.remove(history, i)

						unload(get_proxy_url(name))
					end
				else
					metadata[proxy] = nil

					msg.post(last_proxy, M.MSG_RELEASE_INPUT)
					transite(M.transition.id_in)
					unload(last_proxy)
				end
			end
		end

		metadata[proxy] = meta
		load(proxy)
		coroutine.yield()

		if is_proxy_popup(proxy) then
			msg.post(msg.url(history[#history-1], "/go", history[#history-1]), M.MSG_POPUP_OPENED)
		end

		msg.post(last_proxy, M.MSG_ENABLE)
		msg.post(last_proxy, M.MSG_ACQUIRE_INPUT)
		msg.post(get_last_proxy_url(), M.MSG_ACQUIRE_INPUT)
		transite(M.transition.id_out)
	end)

	coroutine.resume(co)
end

---@param meta table|nil
local function back(meta)
	if is_proxy_popup(history[#history]) then
		unload(last_proxy)

		table.remove(history, #history)
		last_proxy = get_proxy_url(history[#history])
		msg.post(get_last_proxy_url(), M.MSG_ACQUIRE_INPUT)
		msg.post(get_last_proxy_url(), M.MSG_POPUP_CLOSED, meta)
	else
		table.remove(history, #history)
		show(history[#history], meta)
	end
end

---@param proxy string
---@param meta table|nil
function M.show(proxy, meta)
	msg.post(M.url_controller, "show", { proxy = proxy, meta = meta })
end

---@param meta table|nil
function M.back(meta)
	msg.post(M.url_controller, "back", { meta = meta })
end

---@param proxy any
function M.meta(proxy)
	return metadata[proxy]
end

function M.on_message(self, message_id, message, sender)
	if message_id == M.MSG_LOADED then
		last_proxy = sender
		coroutine.resume(co)
	elseif message_id == M.MSG_SHOW then
		show(message.proxy, message.meta)
	elseif message_id == M.MSG_BACK then
		back(message.meta)
	elseif message_id == M.transition.msg_done then
		coroutine.resume(co)
	end
end

return M
