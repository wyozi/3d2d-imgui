--[[
	The MIT License (MIT)

	Copyright (c) 2014-2015 Wyozi <http://www.github.com/wyozi>

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

if SERVER then return end

-- Localize libraries
local bit, render, surface, string, math, vgui =
	bit, render, surface, string, math, vgui

-- Localize some library functions
local type, pcall, IsValid, ScrW, ScrH, FrameNumber, EyePos, EyeAngles, Vector,
 	Angle, SysTime, unpack =
	type, pcall, IsValid, ScrW, ScrH, FrameNumber, EyePos, EyeAngles, Vector,
	Angle, SysTime, unpack
local bor, band, lshift = bit.bor, bit.band, bit.lshift
local math_min, math_max, math_Round = math.min, math.max, math.Round
local string_byte = string.byte
local util_IntersectRayWithPlane, util_TraceLine =
	util.IntersectRayWithPlane, util.TraceLine
local vgui_IsHoveringWorld, vgui_CursorVisible =
	vgui.IsHoveringWorld, vgui.CursorVisible
local gui_ScreenToVector, gui_MousePos = gui.ScreenToVector, gui.MousePos
local surface_SetFont, surface_SetTextColor, surface_GetTextSize,
	surface_SetTextPos, surface_DrawText, surface_SetDrawColor,
	surface_DrawLine =
	surface.SetFont, surface.SetTextColor, surface.GetTextSize,
	surface.SetTextPos, surface.DrawText, surface.SetDrawColor,
	surface.DrawLine
local render_SetColorMaterial, render_PushFilterMin, render_PushFilterMag,
	render_PopFilterMin, render_PopFilterMag, render_GetRenderTarget =
	render.SetColorMaterial, render.PushFilterMin, render.PushFilterMag,
	render.PopFilterMin, render.PopFilterMag, render.GetRenderTarget
local cam_Start3D2D, cam_End3D2D = cam.Start3D2D, cam.End3D2D

-- Setup TDUI
local old_tdui = tdui -- autorefresh support
local tdui = {}

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

-- Color constants
tdui.COLOR_BLACK = Color(0, 0, 0)
tdui.COLOR_BLACK_TRANSPARENT = Color(0, 0, 0, 0)

tdui.COLOR_WHITE = Color(255, 255, 255)
tdui.COLOR_WHITE_TRANSPARENT = Color(255, 255, 255, 0)
tdui.COLOR_WHITE_TRANSLUCENT = Color(255, 255, 255, 15)

tdui.COLOR_RED = Color(255, 0, 0)
tdui.COLOR_GREEN = Color(0, 255, 0)
tdui.COLOR_BLUE = Color(0, 0, 255)
tdui.COLOR_YELLOW = Color(255, 255, 0)

tdui.COLOR_ORANGE = Color(255, 127, 0)
tdui.COLOR_ORANGE_DARK = Color(220, 80, 0)
tdui.COLOR_ORANGE_LIGHT = Color(255, 180, 0)

-- Feature constants (indicate existence of a feature)
tdui.FEATURE_STENCILRECT_UISCALE = true -- Stencil rectangle is scaled by UIScale

-- Helper function. Call this inside a deprecated function as the first statement
local d = {}
function tdui.Deprecate(msg)
	local dbg = debug.getinfo(3, "Sl")
	local srcstr = string.format("%s@%d", dbg.source, dbg.currentline)

	if d[srcstr] then return end
	d[srcstr] = true

	if not msg then
		local thisdbg = debug.getinfo(2, "n")
		msg = thisdbg.name .. "() is deprecated"
	end
	print("[TDUI Deprecation Warning] " .. msg .. " (called at " .. srcstr .. ")")
end

-- The main function. See below for functions in tdui.Meta
function tdui.Create()
	local ui = setmetatable({
		renderQueue = {},
		renderQueuePointer = 0,

		_renderBounds = {x = 0, y = 0, x2 = 0, y2 = 0},

		specialFontCache = {} -- cache of fonts that specify font size etc
	}, tdui.Meta)
	hook.Call("TDUICreated", nil, ui)
	return ui
end

-- This is accessed so often we can improve performance by making it local
local TDUI_DEFAULT_SKIN

tdui.Skins = (old_tdui and old_tdui.Skins) or {}
function tdui.RegisterSkin(name, tbl)
	tdui.Skins[name] = tbl
	if name == "default" then TDUI_DEFAULT_SKIN = tbl end
end

tdui.RenderOperations = {
	["stencil_rect"] = function(_self, x, y, w, h)
		render.ClearStencil()
		render.SetStencilEnable(true)
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilPassOperation(STENCIL_REPLACE)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)

		render.SetStencilWriteMask(1)
		render.SetStencilTestMask(1)
		render.SetStencilReferenceValue(1)

		render.OverrideColorWriteEnable(true, false)

		surface.SetDrawColor(tdui.COLOR_WHITE)
		surface.DrawRect(x, y, w, h)

		render.OverrideColorWriteEnable(false, false)

		render.SetStencilCompareFunction(STENCIL_EQUAL)
	end,
	["stencil_off"] = function()
		render.SetStencilEnable(false)
	end
}

local tdui_meta = {}
tdui_meta.__index = tdui_meta
tdui.Meta = tdui_meta

function tdui_meta:SetSkin(skin)
	self._skin = skin
	self._skinobj = tdui.Skins[skin]
end
function tdui_meta:GetSkin()
	return self._skin
end

function tdui_meta:_GetSkinParams(type, ...)
	local defskin = TDUI_DEFAULT_SKIN
	local skin = self._skinobj or defskin

	local deftbl = defskin[type]
	if not deftbl then return end

	local tbl = skin[type] or deftbl

	local x = {}
	for k,v in pairs{...} do
		x[k] = tbl[v] or deftbl[v]
	end

	return unpack(x)
end

function tdui_meta:EnableRectStencil(x, y, w, h)
	local uiscale = self:GetUIScale()
	x, y, w, h = x * uiscale, y * uiscale, w * uiscale, h * uiscale

	self:_QueueRenderOP("stencil_rect", x, y, w, h)
end

function tdui_meta:DisableStencil()
	self:_QueueRenderOP("stencil_off")
end

local colorMat = Material("color")
function tdui_meta:DrawRect(x, y, w, h, color, borderColor, borderWidth)
	local skin_color, skin_borderColor, skin_borderWidth = self:_GetSkinParams("rect", "color", "borderColor", "borderWidth")

	color = color or skin_color
	borderColor = borderColor or skin_borderColor

	borderWidth = borderWidth or skin_borderWidth or 1

	local uiscale = self:GetUIScale()
	x, y, w, h = x * uiscale, y * uiscale, w * uiscale, h * uiscale

	surface.SetDrawColor(color)
	surface.DrawRect(x, y, w, h)

	if borderColor then
		surface.SetDrawColor(borderColor)
		surface.SetMaterial(colorMat)
		local line_width = borderWidth * math.ceil(1 / (self._scale * 40))

		surface.DrawTexturedRect(x, y, w, line_width)
		surface.DrawTexturedRect(x, y, line_width, h)
		surface.DrawTexturedRect(x, y+h-line_width, w, line_width)
		surface.DrawTexturedRect(x+w-line_width, y, line_width, h)
	end

	self:_ExpandRenderBounds(x, y, w, h)
end
tdui.RenderOperations["rect"] = tdui_meta.DrawRect
function tdui_meta:Rect(x, y, w, h, clr, out_clr, bwide)
	self:_QueueRenderOP("rect", x, y, w, h, clr, out_clr,bwide)
end

function tdui_meta:DrawLine(x, y, x2, y2, clr)
	local color = self:_GetSkinParams("line", "color")
	clr = clr or color

	local uiscale = self:GetUIScale()
	x, y, x2, y2 = x * uiscale, y * uiscale, x2 * uiscale, y2 * uiscale

	surface.SetDrawColor(clr)
	surface.DrawLine(x, y, x2, y2)

	local bx, by = math.min(x, x2), math.min(y, y2)
	local bw, bh = math.max(x, x2) - bx, math.max(y, y2) - by
	self:_ExpandRenderBounds(bx, by, bw, bh)
end
tdui.RenderOperations["line"] = tdui_meta.DrawLine
function tdui_meta:Line(x, y, x2, y2, clr)
	self:_QueueRenderOP("line", x, y, x2, y2, clr)
end

function tdui_meta:DrawPolygon(verts, clr, mat)
	local color = self:_GetSkinParams("polygon", "color")
	clr = clr or color

	surface.SetDrawColor(clr)

	if mat then
		surface.SetMaterial(mat)
	else
		draw.NoTexture()
	end

	surface.DrawPoly(verts)
end
tdui.RenderOperations["polygon"] = tdui_meta.DrawPolygon
function tdui_meta:Polygon(verts, clr, mat)
	self:_QueueRenderOP("polygon", verts, clr, mat)
end

function tdui_meta:DrawMat(mat, x, y, w, h, clr)
	clr = clr or tdui.COLOR_WHITE

	local uiscale = self:GetUIScale()
	x, y, w, h = x * uiscale, y * uiscale, w * uiscale, h * uiscale

	surface.SetMaterial(mat)
	surface.SetDrawColor(clr)
	surface.DrawTexturedRect(x, y, w, h)

	self:_ExpandRenderBounds(x, y, w, h)
end
tdui.RenderOperations["mat"] = tdui_meta.DrawMat
function tdui_meta:Mat(mat, x, y, w, h, clr)
	self:_QueueRenderOP("mat", mat, x, y, w, h, clr)
end

-- The cache that has String->Bool mappings telling if font has been created
local _createdFonts = {}

local EXCLAMATION_BYTE = string.byte("!")
function tdui_meta:_ParseFont(font)
	-- special font
	if string_byte(font, 1) == EXCLAMATION_BYTE then
		-- Check if font has been cached
		-- This cache is cleared on UIScale change
		local cachedFont = self.specialFontCache[font]
		if cachedFont then
			return cachedFont
		end

		-- Font not cached; parse the font and scale it according to UIScale
		local name, size = font:match("!([^@]+)@(.+)")
		local parsedSize = tonumber(size)

		local uiscale = self:GetUIScale()
		parsedSize = math.Round(parsedSize * uiscale)

		local fontName = string.format("TDUICached_%s_%d", name, parsedSize)

		-- Cache for later usage with same font string
		self.specialFontCache[font] = fontName

		if not _createdFonts[fontName] then
			surface.CreateFont(fontName, {
				font = name,
				size = parsedSize
			})
			_createdFonts[fontName] = true
		end

		return fontName
	end
	return font
end

function tdui_meta:DrawText(str, font, x, y, clr, halign, valign, scissor_rect)
	local color = self:_GetSkinParams("text", "color")
	clr = clr or color or tdui.COLOR_WHITE

	local uiscale = self:GetUIScale()
	x, y = x * uiscale, y * uiscale

	surface_SetFont(self:_ParseFont(font))
	surface_SetTextColor(clr)

	local tw, th = surface_GetTextSize(str)

	-- Horizontal align default: TEXT_ALIGN_CENTER
	local aligned_x = x - tw / 2
	if     halign == TEXT_ALIGN_LEFT then    aligned_x = x
	elseif halign == TEXT_ALIGN_RIGHT then   aligned_x = x - tw
	end

	-- Vertical align default: TEXT_ALIGN_TOP
	local aligned_y = y
	if     valign == TEXT_ALIGN_CENTER then  aligned_y = y - th / 2
	elseif valign == TEXT_ALIGN_BOTTOM then  aligned_y = y - th
	end

	surface_SetTextPos(aligned_x, aligned_y)

	if scissor_rect then
		self:EnableRectStencil(scissor_rect.x, scissor_rect.y, scissor_rect.x2-scissor_rect.x, scissor_rect.y2-scissor_rect.y)
	end

	surface_DrawText(str)

	if scissor_rect then
		self:DisableStencil()
	end

	self:_ExpandRenderBounds(aligned_x, aligned_y, tw, th)
end
tdui.RenderOperations["text"] = tdui_meta.DrawText
function tdui_meta:Text(str, font, x, y, clr, halign, valign, scissor_rect)
	self:_QueueRenderOP("text", str, font, x, y, clr, halign, valign, scissor_rect)
end

function tdui_meta:DrawButton(input, font, x, y, w, h, clr, hover_clr)
	local fgColor, bgColor, fgHoverColor, fgPressColor, bgHoverColor, bgPressColor, borderWidth =
		self:_GetSkinParams("button", "fgColor", "bgColor", "fgHoverColor", "fgPressColor", "bgHoverColor", "bgPressColor", "borderWidth")

	-- Override skin constants with params if needed
	fgColor = clr or fgColor
	fgHoverColor = hover_clr or fgHoverColor

	surface_SetFont(self:_ParseFont(font))

	local just_pressed, pressing, hovering = self:TestAreaInput(x, y, w, h, true)

	local finalFgColor, finalBgColor = fgColor, bgColor

	if just_pressed or pressing then
		finalFgColor, finalBgColor = fgPressColor, bgPressColor
	elseif hovering then
		finalFgColor, finalBgColor = fgHoverColor, bgHoverColor
	end

	self:DrawRect(x, y, w, h, finalBgColor, finalFgColor, borderWidth)

	-- if it's a table we need ITERATION
	if type(input) == "table" then
		local uiscale = self:GetUIScale()
		local padding = 3

		local in_w = -padding -- one instance of padding needs to be subtracted, we do it here
		for k,v in pairs(input) do
			local size
			if type(v) == "IMaterial" then
				size = v:Width() * uiscale
			elseif type(v) == "table" and v.mat then
				size = (v.width or v.mat:Width()) * uiscale * 0.5
			else
				size = surface.GetTextSize(v)
			end

			in_w = in_w + (size + padding)
		end

		local in_x = -in_w / 2
		for k,v in pairs(input) do
			local size
			if type(v) == "IMaterial" then
				self:DrawMat(v, x + w / 2 + in_x, y + h / 2 - v:Height() / 2, v:Width(), v:Height())
				size = v:Width() * uiscale
			elseif type(v) == "table" and v.mat then
				local matw, math = v.width or v.mat:Width(), v.height or v.mat:Height()
				self:DrawMat(v.mat, x + w / 2 + in_x, y + h / 2 - math / 2, matw, math)
				size = (v.width or v.mat:Width()) * uiscale
			else
				self:DrawText(v, font, x + w / 2 + in_x, y + h / 2, finalFgColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				size = surface_GetTextSize(v)
			end
			in_x = in_x + (size + padding)
		end
	else
		self:DrawText(input, font, x + w / 2, y + h / 2, finalFgColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if not self:ShouldAcceptInput() then
		return false, false, false
	end
	return just_pressed, pressing, hovering
end
tdui.RenderOperations["button"] = tdui_meta.DrawButton
function tdui_meta:Button(str, font, x, y, w, h, clr, hover_clr)
	self:_QueueRenderOP("button", str, font, x, y, w, h, clr, hover_clr)
	return self:TestAreaInput(x, y, w, h)
end

local SLIDER_HEIGHT = 4
local SLIDER_KNOB_WIDTH = 16

function tdui_meta:_SliderInput(frac, x, y, w, h)
	local pressed, pressing = self:TestAreaInput(x, y, w, h)
	if pressed or pressing then
		local mx, my = self:_GetLocalMousePos()
		return (mx - x) / w
	end
	return frac
end

function tdui_meta:DrawSlider(frac, x, y, w, h)
	frac = math_min(math_max(frac, 0), 1)
	-- Input must be retrieved with UIScale adjustments
	local _, _, hovering = self:TestAreaInput(x, y, w, h)

	self:DrawRect(x, y + h/2 - SLIDER_HEIGHT/2, w, SLIDER_HEIGHT, tdui.COLOR_WHITE_TRANSLUCENT)

	if hovering then
		local mx, my = self:_GetLocalMousePos()
		local hoverFrac = (mx - x) / w

		local hknobMidX = x + w * hoverFrac
		self:DrawRect(hknobMidX - SLIDER_KNOB_WIDTH/2, y, SLIDER_KNOB_WIDTH, h, tdui.COLOR_WHITE_TRANSLUCENT)
	end

	local knobMidX = x + w * frac
	self:DrawRect(knobMidX - SLIDER_KNOB_WIDTH/2, y, SLIDER_KNOB_WIDTH, h, tdui.COLOR_WHITE)

	return self:_SliderInput(frac, x, y, w, h)
end
tdui.RenderOperations["slider"] = tdui_meta.DrawSlider
function tdui_meta:Slider(frac, x, y, w, h)
	self:_QueueRenderOP("slider", frac, x, y, w, h)
	return self:_SliderInput(frac, x, y, w, h)
end

-- Returns input state bitmap of input within currently active renderbounds
function tdui_meta:GetInputStateWithinRenderBounds()
	local rb = self._renderBounds
	return self:_CheckInputInRect(rb.x, rb.y, rb.x2-rb.x, rb.y2-rb.y)
end

function tdui_meta:DrawCursor()
	local inputstate = self:GetInputStateWithinRenderBounds()

	-- If cursor is not within render bounds at all (is not hovering it)
	-- we should not draw a cursor
	if band(inputstate, tdui.FSTATE_HOVERING) == 0 then
		return
	end

	local color, hoverColor, pressColor = self:_GetSkinParams("cursor", "color", "hoverColor", "pressColor")
	if band(inputstate, tdui.FSTATE_JUSTPRESSED) ~= 0 then
		surface.SetDrawColor(hoverColor)
	elseif band(inputstate, tdui.FSTATE_PRESSING) ~= 0 then
		surface.SetDrawColor(pressColor)
	else
		surface.SetDrawColor(color)
	end

	local cursorSize = math_Round(2 * self:GetUIScale())

	surface_DrawLine(self._mx - cursorSize, self._my, self._mx + cursorSize, self._my)
	surface_DrawLine(self._mx, self._my - cursorSize, self._mx, self._my + cursorSize)
end
tdui.RenderOperations["cursor"] = tdui_meta.DrawCursor
function tdui_meta:Cursor()
	self:_QueueRenderOP("cursor")
end

function tdui_meta:Custom(fn)
	self:_QueueRender(fn)
end

function tdui_meta:TestAreaInput(x, y, w, h, dontCheckAcceptance)
	local just_pressed, pressing, hovering

	if self:ShouldAcceptInput() or dontCheckAcceptance then
		local uiscale = self:GetUIScale()
		local inputstate = self:_CheckInputInRect(x * uiscale, y * uiscale, w * uiscale, h * uiscale)

		just_pressed = band(inputstate, tdui.FSTATE_JUSTPRESSED) ~= 0
		pressing = band(inputstate, tdui.FSTATE_PRESSING) ~= 0
		hovering = band(inputstate, tdui.FSTATE_HOVERING) ~= 0
	else
		just_pressed, pressing, hovering = false, false, false
	end

	return just_pressed, pressing, hovering
end

function tdui_meta:_QueueRender(fn)
	if self._rendering then
		local r, e = pcall(fn, self)
		if not r then print("TDUI rendering error: ", e) end
		return
	end

	self.renderQueuePointer = self.renderQueuePointer + 1
	self.renderQueue[self.renderQueuePointer] = {fn}
end

-- Queues a render operation to be done during next render pass
function tdui_meta:_QueueRenderOP(op, ...)
	local fn = tdui.RenderOperations[op]
	if not fn then
		error("Trying to queue inexistent render operation '" .. op .. "''")
		return
	end

	if self._rendering then
		local r, e = pcall(fn, self, ...)
		if not r then print("TDUI rendering error: ", e) end
		return
	end

	self.renderQueuePointer = self.renderQueuePointer + 1
	self.renderQueue[self.renderQueuePointer] = {fn, ...}
end

--- Should be called every time something is drawn with an approximate bounding
-- box of the drawn area. Used for eg. determining where we should show the cursor
function tdui_meta:_ExpandRenderBounds(x, y, w, h)
	self._renderBounds.x = math_min(self._renderBounds.x, x)
	self._renderBounds.y = math_min(self._renderBounds.y, y)

	self._renderBounds.x2 = math_max(self._renderBounds.x2, x + w)
	self._renderBounds.y2 = math_max(self._renderBounds.y2, y + h)
end

function tdui_meta:_WorldToLocal(rayOrigin, rayDirection)
	local pos = self._pos
	local angles = self._angles
	local scale = self._scale

	local planeNormal = angles:Up()

	local hitPos = util_IntersectRayWithPlane(rayOrigin, rayDirection, pos, planeNormal)
	if hitPos then
		local diff = pos - hitPos

		-- This cool code is from Willox's keypad CalculateCursorPos
		local x = diff:Dot(-angles:Forward()) / scale
		local y = diff:Dot(-angles:Right()) / scale

		return x, y, hitPos
	end
end

function tdui_meta:_CheckInputInRect(x, y, w, h, input)
	-- Update screen mouse
	self:_UpdateScreenMouse()

	input = input or tdui.FINPUT_PRESSED

	local state = 0

	if not self._mx or not self._my or self._mObscured then
		return state
	end

	if self._mx >= x and self._my >= y and self._mx <= (x + w) and self._my <= (y + h) then
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

-- Gets the mouse position transformed back to local space (ie. the space in which
-- coordinates are passed to TDUI) from render space (ie. at what coordinate are
-- primitives actually drawn in)
function tdui_meta:_GetLocalMousePos()
	local uiscale = self:GetUIScale()
	local rmx, rmy = self:_GetRenderMousePos()
	return rmx/uiscale, rmy/uiscale
end
-- Returns mouse position in render space
function tdui_meta:_GetRenderMousePos()
	return self._mx, self._my
end

local function isInContextMenu()
	return vgui.CursorVisible() and vgui.GetHoveredPanel() ~= g_ContextMenu
end

local traceEntFilter = function(ent)
	if ent:GetClass() == "prop_physics" then
		return true
	end
end
local traceResultTable = {}
local traceQueryTable = { filter = traceEntFilter, output = traceResultTable }
function tdui_meta:_ComputeScreenMouse()
	local eyepos, eyenormal
	local me = LocalPlayer()
	local veh = me:GetVehicle()
	if IsValid(veh) then
		if veh:GetThirdPersonMode() then
			-- desperate attempt at getting hovered ctx pos in vehicle. Works only in rendering hook?
			eyepos = EyePos()
			eyenormal = me:GetAimVector()
		else
			eyepos = me:EyePos()
			eyenormal = gui.ScreenToVector(ScrW() / 2, ScrH() / 2)
		end
	else
		local tr = me:GetEyeTrace()
		eyepos = tr.StartPos

		if vgui_IsHoveringWorld() and vgui_CursorVisible() then
			eyenormal = gui.ScreenToVector(gui.MousePos())
		else
			eyenormal = tr.Normal
		end
	end

	-- Calculate mouse position in local space
	local mx, my, hitPos = self:_WorldToLocal(eyepos, eyenormal)
	self._mx = mx
	self._my = my

	-- Input aspect ratio for rendering to texture
	if self._inputAspectRatio and self._my then
		self._my = self._my * self._inputAspectRatio
	end

	-- Dot product between eye direction and panel backward facing normal vector
	local backnormal = self:GetBackNormal()
	local plyLookingAtPanel = backnormal and (backnormal:Dot(eyenormal) > 0)

	-- If player is not even looking at the panel, it is obscured for sure
	-- This makes sure you cannot press buttons from the "back" side of the panel
	if not plyLookingAtPanel then
		self._mObscured = true

	-- Check for obstructions in the world (eg props or the worldspawn)
	elseif hitPos then

		-- If we're ignoring Z, it doesn't matter if we hit something
		if self._IgnoreZ then
			self._mObscured = false
			return
		end

		local q = traceQueryTable
		q.start = eyepos
		q.endpos = hitPos

		local tr = util_TraceLine(q)
		self._mObscured = tr.Hit
	end
end

function tdui_meta:_ComputeInput()
	-- Update input down statuses
	local oldInput = self._inputDown
	local nowInput = 0
	local justPressed = 0

	-- Check input (only checks if game panel is active)
	if not isInContextMenu() then
		if input.IsMouseDown(MOUSE_LEFT) then
			local code = tdui.FMOUSE_LEFT

			nowInput = bor(nowInput, code)
			if oldInput and band(oldInput, code) == 0 then
				justPressed = bor(justPressed, code)
			end
		end
		if input.IsMouseDown(MOUSE_RIGHT) then
			local code = tdui.FMOUSE_RIGHT

			nowInput = bor(nowInput, code)
			if oldInput and band(oldInput, code) == 0 then
				justPressed = bor(justPressed, code)
			end
		end

		local useKey = KEY_E

		-- attempt to map to key player has bound for +use, but fall back to KEY_E
		local useBoundKey = input.LookupBinding("+use")
		if useBoundKey and useBoundKey ~= "e" then
			useKey = _G["KEY_" .. useBoundKey:upper()] or KEY_E
		end

		if input.IsKeyDown(useKey) then
			local code = tdui.FKEY_USE

			nowInput = bor(nowInput, code)
			if oldInput and band(oldInput, code) == 0 then
				justPressed = bor(justPressed, code)
			end
		end
	end

	self._inputDown = nowInput
	self._justPressed = justPressed
end

-- UpdateInputStatus should be called once per frame to update input status
-- This is used for things such as making sure buttons only get clicked once
function tdui_meta:_UpdateInputStatus(forceUpdate, inputAspectRatio)
	-- Make sure we only do something if the frame changed
	local curFrame = FrameNumber()
	if self._lastInputFrame == curFrame and not forceUpdate then
		return
	end
	self._lastInputFrame = curFrame

	self._inputAspectRatio = inputAspectRatio

	self:_ComputeInput()
end

-- Updates the screen mouse position
-- Contains additional checks to make sure we don't do it if we don't need to
function tdui_meta:_UpdateScreenMouse()
	local curGEyePos = EyePos()
	local curGEyeAngles = EyeAngles()
	if self._lastGEyePos == curGEyePos and self._lastGEyeAngles == curGEyeAngles then
		return
	end
	self._lastGEyePos = curGEyePos
	self._lastGEyeAngles = curGEyeAngles

	self:_ComputeScreenMouse()
end

-- The default values for rendering params
tdui_meta._pos = Vector(0, 0, 0)
tdui_meta._angles = Angle(0, 0, 0)
tdui_meta._scale = 1

function tdui_meta:_UpdatePAS(pos, angles, scale)

	-- If updating the angle of the render context, we apply a transformation,
	-- which makes it so that if angles was EyeAngles(), it would face us directly.
	if angles then
		-- Use cached copy of transformed angle
		if self._transformedAnglesOrig == angles then
			angles = self._transformedAnglesResult
		else
			self._transformedAnglesOrig = angles

			-- Create a copy of the angle object
			angles = Angle(angles.p, angles.y, angles.r)
			angles:RotateAroundAxis(angles:Right(), 90)
			angles:RotateAroundAxis(angles:Up(), -90)
			
			self._transformedAnglesResult = angles
		end
	end

	self._pos    = pos    or self._pos
	self._angles = angles or self._angles
	self._scale  = scale  or self._scale
end

--- Returns a normal vector facing away from the TDUI panel towards the front of the panel
-- Due to angle rotations in _UpdatePAS this is not the obvious self._angles:Forward()
function tdui_meta:GetFrontNormal()
	if not self._angles then return end
	return self._angles:Up()
end

--- Returns a normal vector facing away from the TDUI panel towards the back of the panel
-- Example usecase: figuring out if the player is looking at the panel or not
function tdui_meta:GetBackNormal()
	local frontnormal = self:GetFrontNormal()
	if frontnormal then return -frontnormal end
end

function tdui_meta:SetIgnoreZ(b)
	self._IgnoreZ = b
end

function tdui_meta:PreRenderReset()
	-- Reset parameters
	self:_UpdateInputStatus()

	-- Reset render bounds
	self._renderBounds.x = 0
	self._renderBounds.y = 0
	self._renderBounds.x2 = 0
	self._renderBounds.y2 = 0

	-- Reset colors, materials
	surface_SetDrawColor(tdui.COLOR_WHITE)
	render_SetColorMaterial()
end

function tdui_meta:BeginRender()
	if self._rendering then error("Calling BeginRender() with an ongoing render") end

	self:PreRenderReset()

	-- Set IgnoreZ
	if self._IgnoreZ then
		cam.IgnoreZ(true)
		self._IgnoreZActive = true
	else
		self._IgnoreZActive = false
	end

	-- Start render context
	render_PushFilterMin(TEXFILTER.ANISOTROPIC)
	render_PushFilterMag(TEXFILTER.ANISOTROPIC)

	cam_Start3D2D(self._pos, self._angles, self._scale)

	self._rendering = true
	self._renderStarted = SysTime()
end

function tdui_meta:PostRenderReset()
	-- "Empty" renderQueue
	self.renderQueuePointer = 0

	-- Count how many renders have been done this frame
	local curFrame = FrameNumber()
	if self._lastRenderFrame == curFrame then
		self._frameRenderCount = (self._frameRenderCount or 0) + 1
	else
		self._frameRenderCount = 1
	end

	self._renderEnded = SysTime()
end

function tdui_meta:EndRender()
	if not self._rendering then error("Calling EndRender() without matching BeginRender()") end

	self._rendering = false

	-- End render context
	cam_End3D2D()

	render_PopFilterMin()
	render_PopFilterMag()

	if self._IgnoreZActive then
		cam.IgnoreZ(false)
	end

	self:PostRenderReset()

	self._lastRenderFrame = FrameNumber()
end

function tdui_meta:RenderQueued()
	for i = 1, self.renderQueuePointer do
		-- First component = render function
		-- Second.. components = render payload
		local renderData = self.renderQueue[i]
		local r, e = pcall(renderData[1], self, unpack(renderData, 2))

		if not r then
			return false, e
		end
	end

	return true
end

function tdui_meta:Render(pos, angles, scale)
	self:_UpdatePAS(pos, angles, scale)

	self:BeginRender()
	local succ, err = self:RenderQueued()
	self:EndRender()

	if not succ then
		error("TDUI Rendering error: " .. tostring(err))
	end
end

-- EXPERIMENTAL rendering to texture
-- See examples/rendertomat.lua
function tdui_meta:RenderToTexture(rtw, rth)
	local id = "TDUIMat_" .. (string.match(tostring(self), "table: 0x(.*)"))

	local w, h = rtw or 512, rth or 512
	local rt = GetRenderTarget(id, w, h)

	render.PushRenderTarget(rt)
	render.Clear(0, 0, 0, 255)

		cam.Start2D()
			self:PreRenderReset()
			self:RenderQueued()
			self:PostRenderReset()
		cam.End2D()

	render.PopRenderTarget()

	return rt
end

-- Is this the first render during this frame
function tdui_meta:IsFirstRenderThisFrame()
	return not self._frameRenderCount or self._frameRenderCount == 1
end

function tdui_meta:WasRenderedThisFrame()
	return self._lastRenderFrame == FrameNumber()
end

-- Are we rendering to the "main" render target aka the screen
function tdui_meta:IsWorldRenderpass()
	return render_GetRenderTarget() == nil
end

-- Note: does not affect return values from CheckInputInRect
function tdui_meta:ShouldAcceptInput()
	return self:IsWorldRenderpass()
end

-- Scales all UI elements (including fonts that use custom format)
-- Behind the scenes this scales all x, y, w, h etc by this value
-- Can be used for testing or because of laziness
function tdui_meta:SetUIScale(scale)
	self._uiscale = scale
	self.specialFontCache = {} -- special font cache must be recreated
end
function tdui_meta:GetUIScale()
	return self._uiscale or 1
end

-- Create code for detecting +use presses on TDUI, which should be blocked if BlockUseBind is enabled
local useBindChecks = setmetatable({}, {__mode = "k"})

hook.Add("PlayerBindPress", "TDUI_BlockUseBindChecker" .. debug.getinfo(1, "S").short_src, function(ply, bind, pressed)
	if bind == "+use" then
		for ui,b in pairs(useBindChecks) do
			if b then
				local inputstate = ui:GetInputStateWithinRenderBounds()

				-- if hovering, block bind
				if band(inputstate, tdui.FSTATE_HOVERING) ~= 0 then
					return true
				end
			end
		end
	end
end)

-- Inserts current TDUI to list of TDUIs checked when player presses +use
-- If the +use happened while hovering tdui, the bind is blocked
-- This is useful to prevent eg. exiting from a car if trying to interact with TDUI inside a car
function tdui_meta:BlockUseBind()
	useBindChecks[self] = true
end

-- OBSOLETE!
-- Old description: Enables workaround which fixes input events happening in world space.
function tdui_meta:EnableReflectionWorkaround()
end

-- Create singleton instance of TDUI
-- It can be used for simplicity

local singleton = tdui.Create()

function tdui.Begin(pos, ang, scale)
	if not pos then error("pos expected", 2) end
	if not ang then error("ang expected", 2) end
	scale = scale or 1

	singleton:_UpdatePAS(pos, ang, scale)

	singleton:BeginRender()
end

-- Not real currying, I know
local function curry(f, x)
	return function(...)
		return f(x, ...)
	end
end

-- Drawing
tdui.Rect    = curry(singleton.DrawRect, singleton)
tdui.Line    = curry(singleton.DrawLine, singleton)
tdui.Mat     = curry(singleton.DrawMat, singleton)
tdui.Polygon = curry(singleton.DrawPolygon, singleton)
tdui.Text    = curry(singleton.DrawText, singleton)
tdui.Button  = curry(singleton.DrawButton, singleton)
tdui.Cursor  = curry(singleton.DrawCursor, singleton)
tdui.Custom  = curry(singleton.Custom, singleton)

-- Configuration
tdui.SetIgnoreZ  = curry(singleton.SetIgnoreZ, singleton)

function tdui.End()
	singleton:EndRender()
end

-- Register default skin
tdui.RegisterSkin("default", {
	rect = {
		color = tdui.COLOR_WHITE_TRANSLUCENT,
		borderColor = nil
	},
	text = {
		color = tdui.COLOR_WHITE
	},
	line = {
		color = tdui.COLOR_WHITE
	},
	polygon = {
		color = tdui.COLOR_WHITE_TRANSLUCENT
	},
	button = {
		fgColor = tdui.COLOR_WHITE,
		fgHoverColor = tdui.COLOR_ORANGE,
		fgPressColor = tdui.COLOR_ORANGE_DARK,

		bgColor = tdui.COLOR_BLACK_TRANSPARENT,
		bgHoverColor = tdui.COLOR_BLACK_TRANSPARENT,
		bgPressColor = tdui.COLOR_BLACK_TRANSPARENT,
	},
	cursor = {
		color = tdui.COLOR_WHITE,
		hoverColor = tdui.COLOR_RED,
		pressColor = tdui.COLOR_ORANGE
	}
})

return tdui
