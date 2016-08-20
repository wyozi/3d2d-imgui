local tdui = include("tdui/tdui.lua")

local state = { sliderFrac = 0.5 }

local bm_t = 0
local bm_c = 0
local bm_avg = 0

local function drawToP(p)
	p:Text(string.format("Average render time in past 100 renders: %fms", bm_avg), "!Roboto@18", 10, 260, nil, TEXT_ALIGN_LEFT)

	local _zx = 0
	local function allocateZone(name, w, h)
		local zx = _zx
		_zx = _zx + w + 10

		p:Text(name, "!Roboto@18", zx + 5, -20, nil, TEXT_ALIGN_LEFT)
		p:Rect(zx, 0, w, h, tdui.COLOR_WHITE_TRANSPARENT, tdui.COLOR_WHITE_TRANSLUCENT)
		return zx + 5, 5
	end

	local x, y = allocateZone("Rectangles", 250, 250)
	p:Rect(x, y, 50, 50)
	p:Rect(x+60, y, 50, 50, tdui.COLOR_RED)
	p:Rect(x+120, y, 50, 50, tdui.COLOR_WHITE_TRANSPARENT, tdui.COLOR_RED)
	p:Rect(x+180, y, 50, 50, tdui.COLOR_ORANGE, tdui.COLOR_RED)

	local x, y = allocateZone("Text", 250, 250)
	p:Text("Hello world", "DermaDefault", x+60, y)
	p:Text("|Hello world", "DermaDefault", x+60, y + 15, nil, TEXT_ALIGN_LEFT)
	p:Text("Hello world|", "DermaDefault", x+60, y + 30, nil, TEXT_ALIGN_RIGHT)

	p:Text("mi mo ma", "!Roboto@18", x+100, y + 60, nil)
	p:Text("mi mo ma", "!Roboto@24", x+100, y + 80, tdui.COLOR_RED)
	p:Text("mi mo ma", "!Roboto@32", x+100, y + 100, tdui.COLOR_WHITE_TRANSLUCENT)

	p:Text("äöå", "!Roboto@18", x+100, y + 145, nil)

	local x, y = allocateZone("Lines", 250, 250)
	p:Line(x + 10, y + 10, x + 230, y + 10)
	p:Line(x + 10, y + 60, x + 230, y + 100, tdui.COLOR_ORANGE)

	local x, y = allocateZone("Polygons", 250, 250)
	p:Polygon({
		{ x = x + 70, y = y + 10, },
		{ x = x + 230, y = y + 100, },
		{ x = x + 20, y = y + 100, },
		{ x = x + 50, y = y + 10, },
	}, tdui.COLOR_GREEN)

	local x, y = allocateZone("Material", 250, 250)
	p:Mat(Material("models/shadertest/shader5"), x + 10, y + 10, 120, 120)

	local x, y = allocateZone("Buttons", 250, 250)

	local _jp, _press, _hover = p:Button("hey mon", "!Roboto@18", x + 10, y + 10, 220, 45)
	if _jp then p:Text("Just pressed", "!Roboto@18", x + 10, y + 60, nil, TEXT_ALIGN_LEFT) end
	if _hover then p:Text("Hovering", "!Roboto@18", x + 10, y + 80, nil, TEXT_ALIGN_LEFT) end
	if _press then p:Text("Pressing", "!Roboto@18", x + 10, y + 100, nil, TEXT_ALIGN_LEFT) end

	local x, y = allocateZone("Sliders", 250, 250)

	state.sliderFrac = p:Slider(state.sliderFrac, x + 10, y + 10, 220, 40)
	p:Text(tostring(state.sliderFrac), "!Roboto@18", x + 10, y + 60, nil, TEXT_ALIGN_LEFT)

    p:Cursor()
end

local p, pbig
hook.Add("PostDrawTranslucentRenderables", "Paint3D2DUI", function(bDrawingSkybox, bDrawingDepth)
    if bDrawingDepth then return end

	local bm_start = SysTime()

	p = p or tdui.Create()
	drawToP(p)

	-- draws on gm_construct spawn building wall
    p:Render(Vector(1770, 800, -60), Angle(0, 0, 0), 0.1)

	local bm_elapsed = SysTime() - bm_start

	pbig = pbig or tdui.Create()
	pbig:SetUIScale(2)
	drawToP(pbig)
    pbig:Render(Vector(1770, 400, -40), Angle(0, 0, 0), 0.1)

	bm_t = bm_t + bm_elapsed
	bm_c = bm_c + 1
	if bm_c == 100 then
		bm_avg = ((bm_t / bm_c) * 1000)
		bm_c = 0
		bm_t = 0
	end
end)