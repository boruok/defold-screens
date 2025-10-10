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

M.url_controller = msg.url("main", "/screens", "controller")
M.url_trasition  = msg.url("main", "/transition", "transition")
M.msg_transition_play = hash("transition_play")
M.msg_transition_done = hash("transition_done")
M.transition_in  = "fade_in"
M.transition_out = "fade_out"
M.transition_render_order = 2

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

---@return string
local function get_last_proxy_name()
	return history[#history]
end

---@return url
local function get_last_proxy_url()
	return msg.url(get_last_proxy_name(), "/go", "gui")
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
local function show(proxy)
	co = coroutine.create(function()
		local transite = function(animation)
			if go.exists(M.url_trasition) then
				msg.post(M.url_trasition, M.msg_transition_play, { animation = animation })
				coroutine.yield()
			end
		end

		if is_proxy_popup(proxy) then
			msg.post(get_last_proxy_url(), M.MSG_RELEASE_INPUT)
		else
			if #history > 0 then
				if is_proxy_popup(get_last_proxy_name()) then
					transite(M.transition_in)
					-- clear prev popups + last proxy
					for i = #history, -1, -1 do
						local name = history[i]
						if name == proxy then
							break
						end
						table.remove(history, i)
						unload(get_proxy_url(name))
					end
				else
					msg.post(last_proxy, M.MSG_RELEASE_INPUT)
					transite(M.transition_in)
					unload(last_proxy)
				end
			end
		end

		load(proxy)
		coroutine.yield()

		msg.post(last_proxy, M.MSG_ENABLE)
		msg.post(last_proxy, M.MSG_ACQUIRE_INPUT)
		msg.post(get_last_proxy_url(), M.MSG_ACQUIRE_INPUT)
		transite(M.transition_out)
	end)
	coroutine.resume(co)
end

local function back()
	if is_proxy_popup(get_last_proxy_name()) then
		unload(last_proxy)
		table.remove(history, #history)
		last_proxy = get_proxy_url(get_last_proxy_name())
		msg.post(get_last_proxy_url(), M.MSG_ACQUIRE_INPUT)
	else
		table.remove(history, #history)
		show(get_last_proxy_name())
	end
end

---@param proxy string
function M.show(proxy)
	msg.post(M.url_controller, "show", { proxy = proxy })
end

function M.back()
	msg.post(M.url_controller, "back")
end

function M.on_message(self, message_id, message, sender)
	if message_id == M.MSG_LOADED then
		last_proxy = sender
		coroutine.resume(co)
	elseif message_id == M.MSG_SHOW then
		show(message.proxy)
	elseif message_id == M.MSG_BACK then
		back()
	elseif message_id == M.msg_transition_done then
		coroutine.resume(co)
	end
end

return M
