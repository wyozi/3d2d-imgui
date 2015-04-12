## 3D2D Immediate Mode GUI for Garry's Mod

3D2D panels made simple. Vaguely based on [imgui](https://github.com/ocornut/imgui).

![example](http://i.imgur.com/dhjqFZD.jpg)

```lua
hook.Add("PostDrawTranslucentRenderables", "Paint3D2DUI", function()
	-- Begin 3D2D Render Context
    tdui.Begin(Vector(980, -83, -79), Angle(0, 0, 0), 0.4)
    
	    -- Draw a rectangle (x, y, w, h, [fill_color], [outline_color])
	    tdui.Rect(-80, 0, 160, 150, _, Color(255, 255, 255))
	
	    -- Draw a line of text (text, font, x, y, [color], [halign], [valign])
	    -- Note: text is implicitly horizontally centered
	    tdui.Text("Hello there!", "DermaLarge", 0, 5)
	
	    -- Draw a button (text, font, x, y, w, h, [color])
	    -- Return value is boolean indicating whether left mouse or +use was pressed during this frame
	    if tdui.Button("Say hi", "DermaDefaultBold", -50, 40, 100, 25) then
	        RunConsoleCommand("say", "hi!")
	    end
	
	    -- Draws a simple crosshair cursor at current mouse position
	    tdui.Cursor()
    
    -- End 3D2D Render Context
    tdui.End()
end)
```

## Installation
__As a library to a project:__ copy [lua/autorun/client/3d2dimgui.lua](../blob/master/lua/autorun/client/3d2dimgui.lua) and remember to include/AddCSLuaFile it on clientside.  
__As a generic addon:__ ```git clone https://github.com/wyozi/3d2d-imgui.git``` in the ```garrysmod/addons``` folder.

## Usage

Drawing components:
```lua
tdui.Rect(x, y, w, h, [fill_color], [outline_color])

tdui.Mat(material, x, y, w, h)

-- Same vertices layout as surface.DrawPoly
tdui.Polygon(vertices, color, material)

-- Note: horizontally aligned to center by default
tdui.Text(text, font, x, y, [color], [halign], [valign], [scissor_rect])

local isMouseOrUseDown = tdui.Button(text, font, x, y, w, h, [color])

tdui.Cursor()
```

Configuration:
```lua
tdui.SetIgnoreZ(bool) -- Draws and accepts input through walls
```

## Tips
Code is mostly self-documenting. If there's a part you don't understand, feel free to post an issue.

Y-axis can be used as the horizontal center point. 3D2D-IMGUI supports negative coordinates.

If you need to make eg. scrolling text, ```p:Text()``` accepts ```scissor_rect``` as the last parameter. It should be a table containing ```x, y, x2, y2```. 
