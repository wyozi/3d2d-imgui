--[[
	The MIT License (MIT)

	Copyright (c) 2014 Wyozi <http://www.github.com/wyozi>

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

-- Localize globals
local bor, band, lshift = bit.bor, bit.band, bit.lshift

tdui = {}

-- Input constants.
-- We're not using GMod- versions, because they're not powers of two.
-- If you want to add a new input, see tdui:_UpdateInputStatus()
tdui.FMOUSE_LEFT =  lshift(1, 0)
tdui.FMOUSE_RIGHT = lshift(1, 1)
tdui.FKEY_USE     = lshift(1, 8)

-- Input constants that are make tdui:Button() return true etc.
tdui.FINPUT_PRESSED = bor(tdui.FMOUSE_LEFT, tdui.FKEY_USE)

-- Input state constants.
-- These are the bits returned from tdui:_CheckInputInRect()
tdui.FSTATE_HOVERING    = lshift(1, 0)
tdui.FSTATE_PRESSING    = lshift(1, 1) -- if input is pressed right now
tdui.FSTATE_JUSTPRESSED = lshift(1, 2) -- if input was pressed during this frame

-- The main function. See below for functions in tdui.Meta
function tdui.Create()
	return setmetatable({}, tdui.Meta)
end

local tdui_meta = {}
tdui_meta.__index = tdui_meta

tdui.Meta = tdui_meta

function tdui_meta:EnableRectStencil(x, y, w, h)
	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetStencilReferenceValue(1)

	render.OverrideColorWriteEnable(true, false)

	surface.SetDrawColor(255, 255, 255)
	surface.DrawRect(x, y, w, h)

	render.OverrideColorWriteEnable(false, false)

	render.SetStencilCompareFunction(STENCIL_EQUAL)
end

function tdui_meta:DisableStencil()
	render.SetStencilEnable(false)
end

function tdui_meta:DrawRect(x, y, w, h, clr, out_clr)
	clr = clr or Color(255, 255, 255, 15)

	surface.SetDrawColor(clr)
	surface.DrawRect(x, y, w, h)

	if out_clr then
		surface.SetDrawColor(out_clr)
		surface.DrawOutlinedRect(x, y, w, h)
	end
end
function tdui_meta:Rect(x, y, w, h, clr, out_clr)
	self:_QueueRender(function()
		self:DrawRect(x, y, w, h, clr, out_clr)
	end)
end

function tdui_meta:DrawMat(mat, x, y, w, h)
	surface.SetMaterial(mat)
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRect(x, y, w, h)
end
function tdui_meta:Mat(mat, x, y, w, h)
	self:_QueueRender(function()
		self:DrawMat(mat, x, y, w, h)
	end)
end

function tdui_meta:DrawText(str, font, x, y, clr, halign, valign, scissor_rect)
	clr = clr or Color(255, 255, 255)

	surface.SetFont(font)
	surface.SetTextColor(clr)

	local tw, th = surface.GetTextSize(str)

	-- Horizontal align default: TEXT_ALIGN_CENTER
	local aligned_x = x-tw/2
	if     halign == TEXT_ALIGN_LEFT then    aligned_x = x
	elseif halign == TEXT_ALIGN_RIGHT then   aligned_x = x-tw
	end

	-- Vertical align default: TEXT_ALIGN_TOP
	local aligned_y = y
	if     valign == TEXT_ALIGN_CENTER then  aligned_y = y-th/2
	elseif valign == TEXT_ALIGN_BOTTOM then  aligned_y = y-th
	end

	surface.SetTextPos(aligned_x, aligned_y)

	if scissor_rect then
		self:EnableRectStencil(scissor_rect.x, scissor_rect.y, scissor_rect.x2-scissor_rect.x, scissor_rect.y2-scissor_rect.y)
	end

	surface.DrawText(str)

	if scissor_rect then
		self:DisableStencil()
	end
end
function tdui_meta:Text(str, font, x, y, clr, halign, valign, scissor_rect)
	self:_QueueRender(function()
		self:DrawText(str, font, x, y, clr, halign, valign, scissor_rect)
	end)
end

function tdui_meta:DrawButton(str, font, x, y, w, h, clr)
	clr = clr or Color(255, 255, 255)

	surface.SetFont(font)

	local inputstate = self:_CheckInputInRect(x, y, w, h)

	if     band(inputstate, bor(tdui.FSTATE_PRESSING, tdui.FSTATE_JUSTPRESSED)) ~= 0 then
		clr = Color(200, 80, 0)
	elseif band(inputstate, tdui.FSTATE_HOVERING) ~= 0 then
		clr = Color(255, 127, 0)
	end

	self:DrawText(str, font, x + w/2, y + h/2, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	self:DrawRect(x, y, w, h, Color(0, 0, 0, 0), clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	return pressed, hovered
end
function tdui_meta:Button(str, font, x, y, w, h, clr)
	self:_QueueRender(function()
		self:DrawButton(str, font, x, y, w, h, clr)
	end)

	if band(self:_CheckInputInRect(x, y, w, h), tdui.FSTATE_JUSTPRESSED) ~= 0 then
		return true
	end
	return false
end


function tdui_meta:DrawCursor()
	local inputstate = self:_CheckInputInRect(-1000, -1000, 2000, 2000)
	--print(inputstate)
	if band(inputstate, tdui.FSTATE_JUSTPRESSED) ~= 0 then
		surface.SetDrawColor(255, 0, 0)
	elseif band(inputstate, tdui.FSTATE_PRESSING) ~= 0 then
		surface.SetDrawColor(255, 127, 0)
	end

	surface.DrawLine(self._mx-2, self._my, self._mx+2, self._my)
	surface.DrawLine(self._mx, self._my-2, self._mx, self._my+2)
end
function tdui_meta:Cursor()
	self:_QueueRender(function()
		self:DrawCursor()
	end)
end

function tdui_meta:_QueueRender(fn)
	if not self.renderQueue then return end
	self.renderQueue[#self.renderQueue+1] = fn
end

function tdui_meta:_WorldToLocal(rayOrigin, rayDirection)
	local pos = self._pos
	local angles = self._angles
	local scale = self._scale

	local planePos = pos
	local planeNormal = angles:Up()

	local scale = self._scale

	local hitPos = util.IntersectRayWithPlane(rayOrigin, rayDirection, planePos, planeNormal)
	if hitPos then
		local diff = hitPos - planePos

		-- Magic
		diff:Rotate(Angle(0, -angles.y, 0))
		diff:Rotate(Angle(-angles.p, 0, 0))
		diff:Rotate(Angle(0, 0, -angles.r))

		local xchange = diff.x
		local ychange = diff.y

		xchange = xchange * (1/scale)
		ychange = ychange * (1/scale)

		local finalx, finaly = xchange, -ychange

		if finalx >= -1000 and finalx <= 1000 and finaly >= -1000 and finaly <= 1000 then
			return finalx, finaly
		end
	end
end

function tdui_meta:_CheckInputInRect(x, y, w, h, input)
	input = input or tdui.FINPUT_PRESSED

	local state = 0

	if not self._mx or not self._my then
		return state
	end

	if self._mx >= x and self._my >= y and self._mx <= (x+w) and self._my <= (y+h) then
		state = bor(state, tdui.FSTATE_HOVERING)

		if band(self._justPressed, input) ~= 0 then
			state = bor(state, tdui.FSTATE_JUSTPRESSED)
		end
		if band(self._inputDown, input) ~= 0 then
			state = bor(state, tdui.FSTATE_PRESSING)
		end
	end

	return state
end

function tdui_meta:_UpdateInputStatus()
	-- Calculate mouse position in local space
	local mx, my = self:_WorldToLocal(LocalPlayer():EyePos(), gui.ScreenToVector(ScrW()/2, ScrH()/2))
	self._mx = mx or -1
	self._my = my or -1

	-- Update input down statuses
	local oldInput = self._inputDown
	local nowInput = 0
	local justPressed = 0

	local function CheckInput(code, isDown)
		if isDown then nowInput = bit.bor(nowInput, code) end

		if oldInput and bit.band(oldInput, code) == 0 and isDown then
			justPressed = bit.bor(justPressed, code)
		end
	end
	local function CheckMouse(gm_code, code)
		CheckInput(code, input.IsMouseDown(gm_code))
	end
	local function CheckInKey(gm_code, code)
		CheckInput(code, LocalPlayer():KeyDown(gm_code))
	end

	CheckMouse(MOUSE_LEFT, tdui.FMOUSE_LEFT)
	CheckMouse(MOUSE_RIGHT, tdui.FMOUSE_RIGHT)

	CheckInKey(IN_USE, tdui.FKEY_USE)

	self._inputDown = nowInput
	self._justPressed = justPressed
end

-- The default values for rendering params
tdui_meta._pos = Vector(0, 0, 0)
tdui_meta._angles = Angle(0, 0, 0)
tdui_meta._scale = 1

function tdui_meta:_UpdatePAS(pos, angles, scale)

	-- If updating the angle of the render context, we apply a transformation,
	-- which makes it so that if angles was EyeAngles(), it would face us directly.
	-- TODO: this might screw some people up?
	if angles then
		angles:RotateAroundAxis(angles:Right(), 90)
		angles:RotateAroundAxis(angles:Up(), -90)
	end

	self._pos    = pos    or self._pos
	self._angles = angles or self._angles
	self._scale  = scale  or self._scale
end

function tdui_meta:BeginRender(pos, angles, scale)
	self:_UpdatePAS(pos, angles, scale)

	-- Reset parameters
	self.renderQueue = self.renderQueue or {}
	self:_UpdateInputStatus()

	-- Reset colors, materials
	surface.SetDrawColor(255, 255, 255)
	render.SetColorMaterial()

	-- Start 3D2D render context
	render.PushFilterMin(TEXFILTER.ANISOTROPIC)
	render.PushFilterMag(TEXFILTER.ANISOTROPIC)

	cam.Start3D2D(self._pos, self._angles, self._scale)
end

function tdui_meta:EndRender()
	-- End 3D2D render context
	cam.End3D2D()

	render.PopFilterMin()
	render.PopFilterMag()

	-- Reset parameters
	table.Empty(self.renderQueue)
end

function tdui_meta:Render(pos, angles, scale)
	self:_UpdatePAS(pos, angles, scale)

	self:BeginRender()

		for i=1, #self.renderQueue do
			local r, e = pcall(self.renderQueue[i])
			if not r then print("Render err: ", e) end
		end

	self:EndRender()
end
