## 3D2D Immediate Mode GUI for Garry's Mod

3D2D panels made simple. Vaguely based on [imgui](https://github.com/ocornut/imgui).

![example](http://i.imgur.com/dhjqFZD.jpg)

```lua
local tdui = include("tdui.lua") -- tdui.lua should be in same folder and AddCSLuaFile'd

local p
hook.Add("PostDrawTranslucentRenderables", "Paint3D2DUI", function()
    -- Create a 3D2D-IMGUI instance and cache it
    -- Note: if drawing TDUI inside a ENT:Draw(), you should cache the
    --       panel to the entity instance (self) instead of a local variable.
    --       That way there will be one panel per entity.
    p = p or tdui.Create()

    -- Draw a rectangle (x, y, w, h, [fill_color], [outline_color])
    p:Rect(-320, 0, 640, 600, _, Color(255, 255, 255))

    -- Draw a line of text (text, font, x, y, [color], [halign], [valign])
    -- Note: text is implicitly horizontally centered
    p:Text("Hello there!", "!Roboto@100", 0, 20)

    -- Draw a button (text, font, x, y, w, h, [color])
    -- Return value is boolean indicating whether left mouse or +use was pressed during this frame
    if p:Button("Say hi", "DermaLarge", -200, 160, 400, 100) then
        RunConsoleCommand("say", "hi!")
    end

    -- Draws a simple crosshair cursor at current mouse position
    p:Cursor()

    -- Renders all the queued draw commands at given 3D location (this one's near gm_construct wall)
    p:Render(Vector(980, -83, -79), Angle(0, 0, 0), 0.1)
end)
```

## Installation
Copy [lua/autorun/client/3d2dimgui.lua](../blob/master/lua/autorun/client/3d2dimgui.lua) into a folder and remember to AddCSLuaFile it.
Try to avoid `lua/autorun/client` folder. Instead prefer eg. `lua/myaddon/tdui.lua`.

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
-- Draws and accepts input through walls
p:SetIgnoreZ(true)

-- Scales (multiplies) all UI elements by this value. This can be used during development
-- to test different UI scales or if you're lazy and don't want to scale values by hand.
-- This method also scales fonts that use the special !Typeface@Size format
p:SetUIScale(10)
```

Rendering (should be called in same drawing hook as drawing components):
```lua
p:Render(pos, angles, scale)
```

## Tips
Code is mostly self-documenting. If there's a part you don't understand, feel free to post an issue.

Cache the panel. Use a local variable for hooks and ```self.Panel = self.Panel or tdui.CreatePanel()``` for ```ENT:Draw()```.

Make the ```scale``` parameter to ```p:Render``` as small as possible (eg. ```0.1```) and compensate by either scaling UI elements manually or by using ```p:SetUIScale```. This makes the elements look sharper.

Don't be afraid to use the y-axis as the horizontal center point. 3D2D-IMGUI supports negative coordinates and the example uses them.

If you need to make eg. scrolling text, ```p:Text()``` accepts ```scissor_rect``` as the last parameter. It should be a table containing ```x, y, x2, y2```.
