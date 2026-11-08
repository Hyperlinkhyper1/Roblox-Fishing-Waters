if options.actualLayout then
	-- VECTOR_TYPES --
	local Vector2=vectorType(2)
	local Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
	function CFrame.lookAt(a,b)
		local d=b-a
		return CFrame.new(a.X,a.Y,a.Z,math.atan2(-d.X,-d.Z))
	end
	local Instance={new=function()
		local item=object("Generated")
		item.Parent=nil
		return setmetatable(item,{
			__newindex=function(self,key,value)
				if key=="Parent" then
					rawset(self,"parent",value)
					if value then table.insert(value.children,self) end
				else rawset(self,key,value) end
			end,
			__index=function(self,key) return if key=="Parent" then rawget(self,"parent") else nil end,
		})
	end}
	local Props={pick=function() end}
	function Props.beam(parent,a,b,width,_,height,material)
		local part=road(a,b,width)
		part.Position=Vector3.new(part.Position.X,(a.Y+b.Y)/2,part.Position.Z)
		part.CFrame=CFrame.new(part.Position.X,part.Position.Y,part.Position.Z,part.CFrame.yaw)
		part.Material,part.Size=material,Vector3.new(width,height,(b-a).Magnitude)
		table.insert(parent.children,part)
		return part
	end
	function Props.cylinder(parent,position,height,width,_,material)
		local part=object("Joint",{},{
			Position=position,CFrame=CFrame.new(position),Size=Vector3.new(height,width,width),
			Material=material,Shape="Cylinder",
		})
		table.insert(parent.children,part)
		return part
	end
	function Props.part(parent,size,frame,_,material)
		local part=object("Part",{},{
			Position=frame.Position,CFrame=frame,Size=size,Material=material,Shape="Block",
		})
		table.insert(parent.children,part)
		return part
	end
	local dependencies=setmetatable({Props=Props},{__index=function() return {} end})
	local Harbour=(function()
		-- HARBOUR_SOURCE --
	end)()
	village=object("Village")
	map=object("Map",{object("Harbour Isle",{village})})
	layoutFrames=Harbour.pedestrianLayout(village)
end
