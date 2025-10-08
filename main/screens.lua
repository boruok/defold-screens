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
function M.show(proxy)
	msg.post(M.url_controller, "show", { proxy = proxy })
end

function M.back()
	msg.post(M.url_controller, "back")
end

return M
