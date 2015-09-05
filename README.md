## 3D2D Immediate Mode GUI for Garry's Mod

3D2D panels made simple. Vaguely based on [imgui](https://github.com/ocornut/imgui).

![example](http://i.imgur.com/dhjqFZD.jpg)

```lua
local p
hook.Add("PostDrawTranslucentRenderables", "Paint3D2DUI", function()
	-- Create a 3D2D-IMGUI instance and cache it
	-- Note: if drawing TDUI inside a ENT:Draw(), you should cache the
	--       panel to the entity instance (self) instead of a local variable.
	--       That way there will be one panel per entity.
	p = p or tdui.Create()

	-- Draw a rectangle (x, y, w, h, [fill_color], [outline_color])
	p:Rect(-80, 0, 160, 150, _, Color(255, 255, 255))

	-- Draw a line of text (text, font, x, y, [color], [halign], [valign])
	-- Note: text is implicitly horizontally centered
	p:Text("Hello there!", "DermaLarge", 0, 5)

	-- Draw a button (text, font, x, y, w, h, [color])
	-- Return value is boolean indicating whether left mouse or +use was pressed during this frame
	if p:Button("Say hi", "DermaDefaultBold", -50, 40, 100, 25) then
		RunConsoleCommand("say", "hi!")
	end

	-- Draws a simple crosshair cursor at current mouse position
	p:Cursor()

	-- Renders all the queued draw commands
	p:Render(Vector(980, -83, -79), Angle(0, 0, 0), 0.4)
end)
```

## Installation
__As a library to a project:__ copy [lua/autorun/client/3d2dimgui.lua](../blob/master/lua/autorun/client/3d2dimgui.lua) and remember to include/AddCSLuaFile it on clientside.  
__As a generic addon:__ ```git clone https://github.com/wyozi/3d2d-imgui.git``` in the ```garrysmod/addons``` folder.

## Usage
Panel creation (should be called only once):
```lua
local p = tdui.Create()
```

Drawing components (should be called in a drawing hook, eg. ```ENT:Draw()``` or ```PostDrawTranslucentRenderables```):
```lua
p:Rect(x, y, w, h, [fill_color], [outline_color])

p:Mat(material, x, y, w, h)

-- Same vertices layout as surface.DrawPoly
p:Polygon(vertices, color, material)

-- Note: horizontally aligned to center by default
p:Text(text, font, x, y, [color], [halign], [valign], [scissor_rect])

local isMouseOrUseDown = p:Button(text, font, x, y, w, h, [color])

-- You can pass normal GMod fonts to the font parameter of p:Text and p:Button
-- but it also accepts some special formats that you can use:

p:Text("Hello world", "!Roboto@18", 0, 0)
-- This kind of syntax automatically creates and caches a font based on "Roboto"
-- typeface at size 18. The caching is pretty efficient so this can be used even
-- in finished projects, not just during development.

p:Cursor()
```

Configuration:
```lua
p:SetIgnoreZ(true) -- Draws and accepts input through walls
```

Rendering (should be called in same drawing hook as drawing components):
```lua
p:Render(pos, angles, scale)
```

## Tips
Code is mostly self-documenting. If there's a part you don't understand, feel free to post an issue.

Cache the panel. Use a local variable for hooks and ```self.Panel = self.Panel or tdui.CreatePanel()``` for ```ENT:Draw()```.

Don't be afraid to use the y-axis as the horizontal center point. 3D2D-IMGUI supports negative coordinates and the example uses them.

Do figure out how to use non-queued mode (ie. initiating render context manually using ```tdui:BeginRender()``` and ```tdui:EndRender()```, and using ```tdui:Draw[ComponentName]()``` for drawing components), if you need the extra performance.

If you need to make eg. scrolling text, ```p:Text()``` accepts ```scissor_rect``` as the last parameter. It should be a table containing ```x, y, x2, y2```.
