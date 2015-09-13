local cvar_debug = CreateConVar("tdui_debug", "0")

local uis = TDUIDEBUGUIS or setmetatable({}, {__mode = "v"})
TDUIDEBUGUIS = uis
hook.Add("TDUICreated", "TDUI_DebuggerNew", function(ui)
	table.insert(uis, ui)
end)

hook.Add("HUDPaint", "TDUI_Debugger", function()
	if not cvar_debug:GetBool() then return end

	local i = 0
	for k,v in pairs(uis) do
		local t = {}

		t[1] = {txt = tostring(v)}

		if v._pos and v._angles then
			local eyepos = LocalPlayer():EyePos()
			local eyeang = LocalPlayer():EyeAngles()
			local txt = string.format("[dist: %.02f pos-dot: %.02f ang-dot: %.02f]", eyepos:Distance(v._pos), eyeang:Forward():Dot((v._pos - eyepos):GetNormalized()), eyeang:Forward():Dot(v._angles:Forward()))
			t[2] = {txt = txt}
		else
			t[2] = {txt = "no _pos or _angles", clr = Color(255, 0, 0)}
		end

		local rtf = v:WasRenderedThisFrame()
		t[3] = {clr = rtf and Color(0, 255, 0) or Color(255, 127, 0), txt = rtf and "rendered" or "not rendered"}

		if v._renderStarted and v._renderEnded then
			local renderTime = (v._renderEnded - v._renderStarted) * 1000
			t[4] = {txt = string.format("rendering took %.03f ms (%.02f%%)", renderTime, (renderTime / (FrameTime()*1000))*100)}
		end

		local x = 10
		for _,te in pairs(t) do
			surface.SetFont("DermaDefault")
			surface.SetTextColor(te.clr or Color(255, 255, 255))
			surface.SetTextPos(x, 15 + i*20)

			local tw, th = surface.GetTextSize(te.txt)
			x = x + tw + 5
			surface.DrawText(te.txt)
		end

		i = i + 1
	end
end)
