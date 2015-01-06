## 3D2D Immediate Mode GUI for Garry's Mod

3D2D panels made simple. Vaguely based on [imgui](https://github.com/ocornut/imgui).

![example](http://i.imgur.com/dhjqFZD.jpg)

```lua
local p
hook.Add("PostDrawTranslucentRenderables", "Paint3D2DUI", function()
    -- Create a 3D2D-IMGUI instance and cache it
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
Panel creation:
```lua
local p = tdui.Create()
```

Drawing components:
```lua
p:Rect(x, y, w, h, [fill_color], [outline_color])

p:Mat(material, x, y, w, h)

-- Note: horizontally aligned to center by default
p:Text(text, font, x, y, [color], [halign], [valign])

local isMouseOrUseDown = p:Button(text, font, x, y, w, h, [color])

p:Cursor()
```

Rendering:
```lua
p:Render(pos, angles, scale)
```

## Tips
Cache the panel. Use a local variable for hooks and ```self.Panel = self.Panel or tdui.CreatePanel()``` for ```ENT:Draw()```.

Don't be afraid to use the y-axis as the horizontal center point. 3D2D-IMGUI supports negative coordinates and the example uses them.

Do figure out how to use non-queued mode (ie. initiating render context manually using ```tdui:BeginRender()``` and ```tdui:EndRender()```, and using ```tdui:Draw[ComponentName]()``` for drawing components), if you need the extra performance.
