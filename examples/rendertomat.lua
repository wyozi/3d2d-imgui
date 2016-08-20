-- This example demonstrates rendering a TDUI to a material

ENT.Type = "anim"
ENT.Model = Model("models/props/cs_office/computer.mdl")

function ENT:Initialize()
	if SERVER then
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_BBOX)
	end
end

if CLIENT then
	function ENT:CreateMat()
		return CreateMaterial("TestMat" .. self:EntIndex() .. "." .. CurTime(), "VertexLitGeneric", {
			["$model"] = 1,
			["$basetexturetransform"]="center 0 0 scale 0.3 0.3 rotate 0 translate 0 0", 
		})
	end

	function ENT:Draw()
	    self.p = self.p or tdui.Create()
	    self.mat = self.mat or self:CreateMat()
	    
	    local p, mat = self.p, self.mat
	    
	    -- The material has different angles so we need to mess around.
	    -- These do not affect rendering, because TDUI is never rendered, only the
	    -- generated texture is. Still, this is required for working input
	    local ang = self:GetAngles()
	    ang:RotateAroundAxis(ang:Forward(), 180)
	    ang:RotateAroundAxis(ang:Right(), 180)
	    p:_UpdatePAS(self:GetPos() + ang:Right()*-10.77 + ang:Up()*24.5, ang, 0.134)
	    
	    -- Input status needs to be updated manually too
	    -- 'true' forces update to happen (required for RenderToTexture TDUI)
	    -- 1.32 indicates input aspect ratio; it is required because texture's UV
	    --     coordinates skew the texture away from expected 1:1. 
	    --     '1.32' means that MouseY is multiplied by 1.32 internally.
	    p:_UpdateInputStatus(true, 1.32)
	    
	   	-- Note: material drawing does not support negative coordinates
	    p:Rect(0, 0, 160, 150, _, Color(255, 255, 255))
	    p:Text("Hello there!", "DermaLarge", 80, 5)
	    if p:Button("Say hi", "DermaDefaultBold", 30, 40, 100, 25) then
	        RunConsoleCommand("say", "hi!")
	    end
	    p:Cursor()
	
		-- Render to a texture and set material to use that texture.
	    local rt = p:RenderToTexture()
	    mat:SetTexture("$basetexture", rt)
	    
	    -- Draw the model using the material as an override
		render.MaterialOverrideByIndex(1, mat)
		self:DrawModel()
		render.MaterialOverrideByIndex(1)
	end
end