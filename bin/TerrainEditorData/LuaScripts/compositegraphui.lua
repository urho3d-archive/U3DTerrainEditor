-- Node-graph UI
-- Instance data
-- Consists of opcodes.
-- If opcode=="Parameter" then get the specified input parameter.
-- If opcode=="Function" then instantiate the given ANL function, with the specified array indices
require 'LuaScripts/tableshow'

CompositeGraphUI=ScriptObject()

function CompositeGraphUI:Start()
	--self.createnodemenu=ui:LoadLayout(cache:GetResource("XMLFile", "UI/CreateNodeMenu.xml"))
	--self.pane:AddChild(self.createnodemenu)

	self.pane=ui.root:CreateChild("UIElement")
	self.pane:SetSize(graphics.width, graphics.height)
	self.closetext=self.pane:CreateChild("Text")
	self.closetext:SetStyle("Text", cache:GetResource("XMLFile","UI/DefaultStyle.xml"))
	self.closetext:SetFontSize(20)
	self.closetext.text="Press 'M' to close window."
	self.pane.visible=false


	self.testmenu=self:CreateNodeCreateMenu(self.pane)
	self.testmenu:SetPosition(100,100)
	self.testmenu.visible=false


	self.nodegroup=nil
	self.cursortarget=cursor:CreateChild("NodeGraphLinkDest")
end

function CompositeGraphUI:Activate()
	self.nodegroupslist.visible=true
end

function CompositeGraphUI:Deactivate()
	self.nodegroupslist.visible=false
	if self.nodegroup then
		self.nodegroup.pane.visible=false
		self.nodegroup.pane.focus=false
		if self.closetext then self.closetext:Remove() self.closetext=nil end
	end
end

function CompositeGraphUI:Clear()
	local list=self.nodegroupslist:GetChild("List",true)
	list:RemoveAllItems()

	local g
	for _,g in ipairs(self.nodegroups) do
		g.pane:Remove()
		--g.previewtex:delete()
		--g.histotex:delete()
	end
	self.nodegroup=nil
	self.nodegroups={}
	self.nodegroupcounter=0
end

function CompositeGraphUI:Save(fullpath)
	local groups={}

	print("Saving "..#self.nodegroups.." node groups.")

	function FindLinkIndex(group, target)
		local c
		for c=1,#group.nodes,1 do
			if group.nodes[c]==target then return c end
		end
		return 0
	end

	local c
	for _,c in ipairs(self.nodegroups) do
		local group={}
		group.name=c.name
		group.nodes={}

		local n
		print("Saving "..#c.nodes.." nodes")
		for _,n in ipairs(c.nodes) do
			local pos=n.position
			local nd=
			{
				type=n.name,
				pos={pos.x,pos.y},
				links={},
				inputs={}
			}

			if n.name=="constant" or n.name=="seed" then
				nd.value=n:GetChild("Value",true):GetText()
				nd.title=n:GetChild("Title",true):GetText()
			end


			local inputs=n:GetChild("Inputs",true)
			local numparams=inputs:GetNumChildren()
			local ip
			for ip=1,numparams,1 do
				local v=n:GetChild("Value"..tostring(ip-1),true)

				if v then table.insert(nd.inputs, v.text) end
			end

			local output=n:GetChild("Output0",true)
			if output then
				local numlinks=output:GetNumLinks()
				local l
				print("numlinks: "..numlinks)
				for l=0,numlinks-1,1 do
					local link=output:GetLink(l)
					if(link) then
						local target=link:GetTarget()
						if target then
							local targetroot=target:GetRoot()
							if targetroot then
								local targetindex=FindLinkIndex(c,targetroot)
								table.insert(nd.links, {targetindex,target.name})
								-- A 0 index should mean output node.
							end
						end
					end

				end
			end


			table.insert(group.nodes, nd)
		end
		table.insert(groups, group)
	end

	local str=table.show(groups, "loader.nodegroups")
	local f=io.open(fullpath.."/nodegroups.lua", "w")
	f:write(str)
	f:close()

	local f=io.open(fullpath.."/nodegroups.json", "w")
	if f then
		LuaToJSON(groups, f)
		f:close()
	else print("Couldn't open node groups file.")
	end
end

function CompositeGraphUI:Load(loader)
	if not loader or not loader.nodegroups then return end

	self:Clear()
	local g
	for _,g in ipairs(loader.nodegroups) do
		local group=self:CreateNodeGroup(g.name)
		local n
		for _,n in ipairs(g.nodes) do
			local node=self:BuildNode(group, n.type)
			table.insert(group.nodes, node)
			if node then
				node:SetPosition(IntVector2(n.pos[1],n.pos[2]))
				if n.type=="constant" or n.type=="seed" then
					node:GetChild("Value",true):SetText(n.value)
					node:GetChild("Title",true):SetText(n.title)
				end

				local cp,ip
				for cp,ip in ipairs(n.inputs) do
					local np=node:GetChild("Value"..(cp-1),true)
					if np then
						np.text=ip
					end
				end
			end
		end

		-- Build links
		local i
		for i,n in ipairs(g.nodes) do
			local lnk
			local node=group.nodes[i]
			for _,lnk in ipairs(n.links) do
				local targetnode
				if lnk[1]==0 then targetnode=group.output
				else targetnode=group.nodes[lnk[1]]
				end
				if targetnode then
					local link=group.linkpane:CreateLink(node:GetChild("Output0",true),targetnode:GetChild(lnk[2],true))
					link:SetImageRect(IntRect(193,81,207,95))
				end
			end
		end
	end
end

function CompositeGraphUI:CreateNodeCreateMenu(parent)
	local menu=ui:LoadLayout(cache:GetResource("XMLFile", "UI/CreateNodeButton.xml"))
	local mn=menu:GetChild("Menu",true)

	local pop=CreatePopup(mn)
	local i,c
	for i,c in pairs(nodecategories) do
		local mi=CreateMenuItem(i,-1)
		pop:AddChild(mi)

		local childpop=CreatePopup(mi)
		local e,f
		for e,f in ipairs(c) do
			local ni=CreateMenuItem(f,0)
			childpop:AddChild(ni)
			--self:SubscribeToEvent(ni, "MenuSelected", "CompositeGraphUI:HandleMenuSelected")
		end
	end

	self:SubscribeToEvent("MenuSelected", "CompositeGraphUI:HandleMenuSelected")

	parent:AddChild(menu)
	return menu

end

function CompositeGraphUI:CreateNodeGroup(name)
	local nodegroup=
	{
		nodes={}
	}
	nodegroup.pane=self.pane:CreateChild("Window")
	nodegroup.pane.size=IntVector2(graphics.width*2, graphics.height*2)
	nodegroup.pane.position=IntVector2(-graphics.width/2, -graphics.height/2)
	nodegroup.pane:SetImageRect(IntRect(208,0,223,15))
	nodegroup.pane:SetImageBorder(IntRect(4,4,4,4))
	nodegroup.pane:SetTexture(cache:GetResource("Texture2D", "Textures/UI_modified.png"))
	nodegroup.pane.opacity=0.75
	nodegroup.pane.bringToFront=true
	nodegroup.pane.movable=true
	nodegroup.pane.clipChildren=false
	nodegroup.pane:SetDefaultStyle(cache:GetResource("XMLFile", "UI/NodeStyle.xml"))

	nodegroup.linkpane=nodegroup.pane:CreateChild("NodeGraphLinkPane")
	nodegroup.linkpane.size=IntVector2(graphics.width*2, graphics.height*2)
	nodegroup.linkpane.visible=true
	nodegroup.linkpane.texture=cache:GetResource("Texture2D", "Data/Textures/UI_modified.png")

	nodegroup.previewtex=Texture2D:new()
	nodegroup.previewimg=Image()
	nodegroup.previewimg:SetSize(256,256,3)
	nodegroup.previewimg:Clear(Color(0,0,0))
	nodegroup.previewtex:SetData(nodegroup.previewimg,false)

	nodegroup.histotex=Texture2D:new()
	nodegroup.histoimg=Image()
	nodegroup.histoimg:SetSize(256,64,3)
	nodegroup.histoimg:Clear(Color(0,0,0))
	nodegroup.histotex:SetData(nodegroup.histoimg,false)

	nodegroup.output=self:OutputNode(nodegroup)
	nodegroup.output.position=IntVector2(-nodegroup.pane.position.x + graphics.width-nodegroup.output.width, -nodegroup.pane.position.y + graphics.height/4)

	nodegroup.output:GetChild("Preview",true).texture=nodegroup.previewtex
	nodegroup.output:GetChild("Histogram",true).texture=nodegroup.histotex

	local list=nodegroup.output:GetChild("TargetList",true)
	local smtypes=
	{
		"Terrain",
		"Layer 1",
		"Layer 2",
		"Layer 3",
		"Layer 4",
		"Layer 5",
		"Layer 6",
		"Layer 7",
		"Layer 8",
		"Mask 1",
		"Mask 2",
		"Mask 3",
		"Water"
	}

	local c
	for _,c in ipairs(smtypes) do
		local t=Text:new(context)
		t:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 9)
		t.text=c
		t.color=Color(1,1,1)
		t.minSize=IntVector2(0,16)
		list:AddItem(t)
	end
	list.selection=0

	list=nodegroup.output:GetChild("BlendOpList",true)
	local bops=
	{
		"Replace",
		"Add",
		"Subtract",
		"Multiply",
		"Min",
		"Max",
	}
	for _,c in ipairs(bops) do
		local t=Text:new(context)
		t:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 9)
		t.text=c
		t.color=Color(1,1,1)
		t.minSize=IntVector2(0,16)
		list:AddItem(t)
	end
	list.selection=0

	--nodegroup.pane:AddChild(self.createnodemenu)

	--self:SubscribeToEvent(nodegroup.output:GetChild("Generate",true),"Pressed","CompositeGraphUI:HandleGenerate")
	self:SubscribeToEvent(nodegroup.output:GetChild("Execute",true),"Pressed","CompositeGraphUI:HandleExecute")
	--self:SubscribeToEvent(nodegroup.output:GetChild("Store",true),"Pressed","CompositeGraphUI:HandleStore")
	nodegroup.pane.visible=false

	--local name="Group "..self.nodegroupcounter
	--self.nodegroupcounter=self.nodegroupcounter+1
	nodegroup.name=name

	self.nodegroup=nodegroup

	return nodegroup
end

function CompositeGraphUI:HideGroup()
	if self.nodegroup then
		self.nodegroup.pane.visible=false
		self.nodegroup.pane.focus=false
	end
	self.pane.visible=false
end

function CompositeGraphUI:HandleCreateNode(eventType, eventData)
	if not self.nodegroup then return end
	local e=eventData["Element"]:GetPtr("UIElement")
	if not e then return end
	local n

	n=self:BuildNode(self.nodegroup, e.name)
	if not n then return end

	n.position=IntVector2(-self.nodegroup.pane.position.x + graphics.width/2, -self.nodegroup.pane.position.y + graphics.height/2)
	table.insert(self.nodegroup.nodes, n)
	return n
end

function CompositeGraphUI:SubscribeLinkPoints(e,numinputs)
	local output=e:GetChild("Output0", true)
	if(output) then
		self:SubscribeToEvent(output, "DragBegin", "CompositeGraphUI:HandleOutputDragBegin")
		self:SubscribeToEvent(output, "DragEnd", "CompositeGraphUI:HandleDragEnd")
		output:SetRoot(e)
	end

	local c
	for c=0,numinputs-1,1 do
		local input=e:GetChild("Input"..c, true)
		if(input) then
			self:SubscribeToEvent(input, "DragBegin", "CompositeGraphUI:HandleInputDragBegin")
			self:SubscribeToEvent(input, "DragEnd", "CompositeGraphUI:HandleDragEnd")
			input:SetRoot(e)
		end
	end
end

function CompositeGraphUI:RemoveLinkPoints(e)
	local d=GetNodeTypeDesc(e.name)--nodetypes[type]
	if not d then return end

	local numinputs=#d.inputs

	local c
	for c=0,numinputs-1,1 do
		local input=e:GetChild("Input"..c, true)
		if(input) then
			local link=input:GetLink()
			if link then
				print("clearing link")
				--input:ClearLink()
				--local src=link:GetSource()
				--if src then src:RemoveLink(link) end
				self.nodegroup.linkpane:RemoveLink(link)
			end
		end
	end

	local output=e:GetChild("Output0", true)

	if output then
		local numlinks=output:GetNumLinks()
		print("numlinks: "..numlinks)
		for c=0,numlinks-1,1 do
			local link=output:GetLink(c)
			if link then
				self.nodegroup.linkpane:RemoveLink(link)
			end
		end
	end

end

function CompositeGraphUI:OutputNode(nodegroup)
	local e=ui:LoadLayout(cache:GetResource("XMLFile", "UI/OutputNode.xml"))
	e.visible=true
	self:SubscribeLinkPoints(e,1)

	nodegroup.pane:AddChild(e)
	return e
end

function CompositeGraphUI:BuildNode(nodegroup, type)
	local e=CreateNodeType(nodegroup.pane, type)
	local d=GetNodeTypeDesc(type) --nodetypes[type]
	if not d then return end

	if e then
		self:SubscribeLinkPoints(e,#d.inputs)
	end
	self:SubscribeToEvent(e:GetChild("Close",true), "Pressed", "CompositeGraphUI:HandleCloseNode")
	return e
end



function CompositeGraphUI:HandleOutputDragBegin(eventType, eventData)
	if not self.nodegroup then return end
	local element=eventData["Element"]:GetPtr("NodeGraphLinkSource")
	self.link=self.nodegroup.linkpane:CreateLink(element,self.cursortarget)
	self.link:SetImageRect(IntRect(193,81,207,95))

end

function CompositeGraphUI:HandleDragEnd(eventType, eventData)
	if not self.link then return end
	if not self.nodegroup then return end

	local at=ui:GetElementAt(cursor.position)
	if at then
		if string.sub(at.name, 1, 5)=="Input" then
			local thislink=at:GetLink()
			if thislink then
				--at:ClearLink()
				--local src=thislink:GetSource()
				--if src then src:RemoveLink(thislink) end
				self.nodegroup.linkpane:RemoveLink(thislink)
			end
			self.link:SetTarget(at)
			return
		end
	end

	-- Destroy the link if not dropped on a valid target
	--local source=self.link:GetSource()
	--if(source) then source:RemoveLink(self.link) end
	self.nodegroup.linkpane:RemoveLink(self.link)
	self.link=nil
end

function CompositeGraphUI:HandleInputDragBegin(eventType, eventData)
	local element=eventData["Element"]:GetPtr("NodeGraphLinkDest")
	if element then
		local link=element:GetLink()
		if link then
			self.link=link
			link:SetTarget(self.cursortarget)
			element:ClearLink()
		else
			self.link=nil
		end
	end
end

function CompositeGraphUI:HandleGenerate(eventType, eventData)
	if not self.nodegroup then return end
	local kernel=BuildANLFunction(self.nodegroup.output)
	local minmax=RenderANLKernelToImage(self.nodegroup.previewimg,kernel,0,1,self.nodegroup.histoimg,SEAMLESS_NONE,false,0.0,1.0,1.0,true)
	self.nodegroup.previewtex:SetData(self.nodegroup.previewimg)
	self.nodegroup.output:GetChild("LowValue",true).text=string.format("%.4f",minmax.x)
	self.nodegroup.output:GetChild("HighValue",true).text=string.format("%.4f",minmax.y)
	self.nodegroup.histotex:SetData(self.nodegroup.histoimg,false)
end

function CompositeGraphUI:HandleStore(eventType, eventData)
	local st,nodefunc=CreateLibraryDesc(self.nodegroup.output)
	local name=self.nodegroup.output:GetChild("StoreName",true).text
	print(st)
	local dothing=table.show(nodefunc, "nodetypes.user."..name)
	print(dothing)
	local chunk=loadstring(dothing)
	chunk()
	local ct
	local found=false
	for _,ct in pairs(nodecategories.user) do
		if ct==name then found=true end
	end
	if not found then
		table.insert(nodecategories.user, name)
	end
	self.testmenu:Remove()
	self.testmenu=nil
	self.testmenu=self:CreateNodeCreateMenu(self.pane)
	self.testmenu:SetPosition(100,100)
end

function CompositeGraphUI:HandleExecute(eventType, eventData)
	if not self.nodegroup then return end

	local target=self.nodegroup.output:GetChild("TargetList",true).selection
	local blendop=self.nodegroup.output:GetChild("BlendOpList",true).selection

	local um1,im1=self.nodegroup.output:GetChild("UseMask1",true).checked,self.nodegroup.output:GetChild("InvertMask1",true).checked
	local um2,im2=self.nodegroup.output:GetChild("UseMask2",true).checked,self.nodegroup.output:GetChild("InvertMask2",true).checked
	local um3,im3=self.nodegroup.output:GetChild("UseMask3",true).checked,self.nodegroup.output:GetChild("InvertMask3",true).checked
	local ms=MaskSettings(um1,im1,um2,im2,um3,im3)

	local low=tonumber(self.nodegroup.output:GetChild("Low",true).text) or 0.0
	local high=tonumber(self.nodegroup.output:GetChild("High",true).text) or 1.0

	local rescale=self.nodegroup.output:GetChild("Rescale",true).checked

	if target==0 then
		-- Map terrain
		if not self.nodegroup then return end
		local kernel=BuildANLFunction(self.nodegroup.output)
		local arr=CArray2Dd(TerrainState:GetTerrainWidth(), TerrainState:GetTerrainHeight())
		map2DNoZ(SEAMLESS_NONE,arr,kernel,SMappingRanges(0,1,0,1,0,1), kernel:lastIndex())
		if rescale then arr:scaleToRange(low,high) end
		TerrainState:SetHeightBuffer(arr,ms,blendop)
		--self.nodemapping.visible=false
		saveDoubleArray("map.png",arr)
		return
	elseif target>=1 and target<=8 then
		if not self.nodegroup then return end
		local kernel=BuildANLFunction(self.nodegroup.output)
		local arr=CArray2Dd(TerrainState:GetBlendWidth(), TerrainState:GetBlendHeight())
		map2DNoZ(SEAMLESS_NONE,arr,kernel,SMappingRanges(0,1,0,1,0,1), kernel:lastIndex())
		if rescale then arr:scaleToRange(low,high) end
		TerrainState:SetLayerBuffer(arr,target-1,ms)
		--self.nodemapping.visible=false
		return
	elseif target>=9 and target<=11 then
		if not self.nodegroup then return end
		local kernel=BuildANLFunction(self.nodegroup.output)
		local arr=CArray2Dd(TerrainState:GetTerrainWidth(), TerrainState:GetTerrainHeight())
		map2DNoZ(SEAMLESS_NONE,arr,kernel,SMappingRanges(0,1,0,1,0,1), kernel:lastIndex())
		if rescale then arr:scaleToRange(low,high) end
		print("Setting to mask "..target-9)
		TerrainState:SetMaskBuffer(arr,target-9)
	elseif target==12 then
		if not self.nodegroup then return end
		local kernel=BuildANLFunction(self.nodegroup.output)
		local arr=CArray2Dd(TerrainState:GetTerrainWidth(), TerrainState:GetTerrainHeight())
		map2DNoZ(SEAMLESS_NONE,arr,kernel,SMappingRanges(0,1,0,1,0,1), kernel:lastIndex())
		if rescale then arr:scaleToRange(low,high) end
		TerrainState:SetWaterBuffer(arr,ms)
	end
end

function CompositeGraphUI:HandleCloseNode(eventType, eventData)
	print("Close node")
	local e=eventData["Element"]:GetPtr("UIElement").parent.parent

	if e then self:RemoveLinkPoints(e) end

	local c,i, index
	for c,i in ipairs(self.nodegroup.nodes) do
		if i==e then index=c end
	end

	if index then table.remove(self.nodegroup.nodes, index) end

	e:Remove()
end

function CompositeGraphUI:HandleMenuSelected(eventType, eventData)
	local menu = eventData["Element"]:GetPtr("Menu")
	if not menu then print("no menu") return end

	local t=menu:GetChild("Text",true)
	if t then
		print(t.text)
		self.testmenu:GetChild("Menu",true).showPopup=false

		if not self.nodegroup then return end
		local n

		n=self:BuildNode(self.nodegroup, t.text)
		if not n then return end

		n.position=IntVector2(-self.nodegroup.pane.position.x + graphics.width/2, -self.nodegroup.pane.position.y + graphics.height/2)
		table.insert(self.nodegroup.nodes, n)
	else
		print("no text")
	end


	--self:HandlePopup(menu)

end