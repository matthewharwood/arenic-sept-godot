-- Native Aseprite pixel score and export. Saved masters are authoritative.
-- aseprite --batch --script-param root=/absolute/repo --script assets/pipeline/build-guild-forest.lua
-- Pass rebuild=true only to deliberately reauthor the layered masters.
local root=assert(app.params.root,'root is required')..'/'
local source=root..'assets/environment/guild_clearing/forest/'
local runtime=root..'arenic-game/assets/environment/guild_clearing/forest/'
local preview=source..'previews/'
for _,path in ipairs({source,runtime,preview}) do app.fs.makeAllDirectories(path) end
local function write(path,value) local f=assert(io.open(path,'w'));f:write(value);f:close() end
local file=assert(io.open(root..'assets/environment/palette.oklch.json','r'))
local base=json.decode(file:read('*a'));file:close()
local authored={space='oklch',base='assets/environment/palette.oklch.json',colors={}}
local ramp_specs={
 oak={{.26,.052,161},{.35,.069,154},{.43,.084,148},{.51,.098,141},{.60,.112,133},{.69,.115,123}},
 birch={{.29,.046,147},{.39,.072,139},{.48,.089,130},{.57,.104,123},{.66,.110,113},{.75,.104,102}},
 pine={{.23,.037,179},{.32,.051,173},{.40,.066,166},{.48,.080,159},{.57,.086,150},{.65,.087,141}},
 crooked={{.26,.047,164},{.35,.064,158},{.43,.080,153},{.52,.092,145},{.60,.107,137},{.69,.110,128}},
 fir={{.25,.043,173},{.34,.057,169},{.42,.071,163},{.50,.084,155},{.59,.090,147},{.67,.092,139}},
}
for id,ramp in pairs(ramp_specs) do for i,color in ipairs(ramp) do authored.colors[#authored.colors+1]={id=id..i,oklch=color} end end
authored.colors[#authored.colors+1]={id='meadow',oklch={.510,.061,138}}
authored.colors[#authored.colors+1]={id='meadowDark',oklch={.495,.058,140}}
authored.colors[#authored.colors+1]={id='moss',oklch={.49,.076,130}}
authored.colors[#authored.colors+1]={id='stoneWarm',oklch={.57,.033,82}}
table.sort(authored.colors,function(a,b) return a.id<b.id end)
write(source..'palette.oklch.json',json.encode(authored))
local colors,swatches={},{}
local function color_from_oklch(value)
 local L,C,H=table.unpack(value);local a=C*math.cos(math.rad(H));local b=C*math.sin(math.rad(H))
 local l=(L+.3963377774*a+.2158037573*b)^3
 local m=(L-.1055613458*a-.0638541728*b)^3
 local s=(L-.0894841775*a-1.291485548*b)^3
 local function encode(v) return math.floor(math.max(0,math.min(1,v<=.0031308 and 12.92*v or 1.055*v^(1/2.4)-.055))*255+.5) end
 return Color{r=encode(4.0767416621*l-3.3077115913*m+.2309699292*s),g=encode(-1.2684380046*l+2.6097574011*m-.3413193965*s),b=encode(-.0041960863*l-.7034186147*m+1.707614701*s)}
end
for _,set in ipairs({base.colors,authored.colors}) do for _,entry in ipairs(set) do
 local c=color_from_oklch(entry.oklch);colors[entry.id]=c.rgbaPixel;swatches[#swatches+1]=c
end end
local function noise(x,y,seed) return ((x*127+y*311+seed*73)%97)/97 end
local function pixel(im,x,y,c)
 x=math.floor(x+.5);y=math.floor(y+.5)
 if x<3 or y<3 or x>=im.width-3 or y>=im.height-3 then return end
 im:drawPixel(x,y,type(c)=='string' and assert(colors[c],c) or c)
end
local function line(im,x,y,u,v,c,width)
 local count=math.max(math.abs(u-x),math.abs(v-y),1)
 for i=0,count do for dx=0,(width or 1)-1 do for dy=0,(width or 1)-1 do pixel(im,x+(u-x)*i/count+dx,y+(v-y)*i/count+dy,c) end end end
end
local function poly(im,points,color)
 local lo,hi=999,-999
 for _,p in ipairs(points) do lo=math.min(lo,p[2]);hi=math.max(hi,p[2]) end
 for y=math.ceil(lo),math.floor(hi) do
  local crossings={};local j=#points
  for i=1,#points do local a,b=points[i],points[j]
   if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then crossings[#crossings+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2]) end
   j=i
  end
  table.sort(crossings)
  for i=1,#crossings-1,2 do for x=math.ceil(crossings[i]),math.floor(crossings[i+1]) do pixel(im,x,y,color) end end
 end
end
local function rotated(x,y,d,w)
 local c=(w-1)/2;x=x-c;y=y-c
 for _=1,d do x,y=-y,x end
 return math.floor(x+c+.5),math.floor(y+c+.5)
end
local function turn_points(points,d,w)
 local result={};for _,p in ipairs(points) do local x,y=rotated(p[1],p[2],d,w);result[#result+1]={x,y} end;return result
end
local function turn_line(im,d,w,x,y,u,v,color,width)
 x,y=rotated(x,y,d,w);u,v=rotated(u,v,d,w);line(im,x,y,u,v,color,width)
end
local function alpha(color,value) local c=Color(colors[color]);c.alpha=value;return c.rgbaPixel end
local function images(w) return {Image(w,w,ColorMode.RGB),Image(w,w,ColorMode.RGB),Image(w,w,ColorMode.RGB),Image(w,w,ColorMode.RGB),Image(w,w,ColorMode.RGB)} end
local names={'oak','birch','pine','crooked','fir'}
local directions={'n','e','s','w'}
-- Distinct crown architecture: broad old oak; airy split birch; long radial
-- pine; windswept forked broadleaf; small, dense five-whorl fir.
local lobes={
 oak={{23,32,13,13},{38,25,15,14},{53,34,13,13},{23,49,14,13},{40,46,18,17},{56,49,11,12},{39,61,11,7}},
 birch={{31,25,11,10},{45,28,12,12},{25,40,12,11},{42,43,13,12},{53,49,9,10},{29,55,10,9}},
 crooked={{20,30,11,12},{33,24,12,10},{46,30,14,12},{54,43,11,13},{38,45,12,11},{44,59,13,8}},
}
local function broad_mask(id,x,y)
 local best,lobe=-999,nil
 for i,p in ipairs(lobes[id]) do
  local dx,dy=(x-p[1])/p[3],(y-p[2])/p[4]
  local angle=math.atan(dy,dx)
  local scallop=.052*math.sin(angle*7+i*2)+.035*math.sin(angle*13+i)
  local height=1-dx*dx-dy*dy+scallop
  if height>best then best=height;lobe=p end
 end
 return best,lobe
end
local function needle_mask(id,x,y)
 local cx,cy=38,39;local dx,dy=x-cx,y-cy
 if id=='pine' then dx=dx*1.10;dy=dy*.89 end
 local a=math.atan(dy,dx);local r=math.sqrt(dx*dx+dy*dy)
 -- Long pine: ragged needle sprays around an elongated branch scaffold.
 -- Compact fir: five broad branch whorls with short secondary edge needles.
 local edge=id=='pine' and (24+3.1*math.cos(a*13+.5)+1.8*math.sin(a*5-1))
   or (20+2.6*math.cos(a*5-.4)+1.1*math.sin(a*15)+1.2*math.sin(a*3))
 if r>edge then return -1,nil end
 local needles=id=='pine' and 13 or 5
 local radial=(math.cos(a*needles+.5)+1)*.10
 local whorl=(math.cos(r*.80+a*.8)+1)*.10
 return .22+(1-r/edge)*.66+radial+whorl,{cx,cy,edge,edge}
end
local function foliage_mask(id,x,y)
 if id=='pine' or id=='fir' then return needle_mask(id,x,y) end
 return broad_mask(id,x,y)
end
local function tree(id,d)
 local w=76;local out=images(w);local S,G,B,C,H=table.unpack(out)
 local mask={};local geometry={}
 for y=5,69 do for x=5,69 do
  local h,lobe=foliage_mask(id,x,y)
  if h>0 then local u,v=rotated(x,y,d,w);mask[v*w+u]=true;geometry[#geometry+1]={u,v,x,y,h,lobe} end
 end end
 -- Screen-space grounded penumbra is repainted for every orientation.
 for _,p in ipairs(geometry) do
  pixel(S,p[1]+3,p[2]+3,alpha('shadow',28));pixel(S,p[1]+2,p[2]+4,alpha('shadow',28))
 end
 for _,p in ipairs(geometry) do pixel(S,p[1]+2,p[2]+2,alpha('shadow',63)) end
 -- Roots are bark clusters with side light, extending beyond the canopy.
 local roots={{38,37,36,10},{37,30,28,16},{39,37,49,15},{39,44,63,54},{36,45,15,59},{40,44,48,67}}
 if id=='birch' then roots={{37,44,28,11},{32,26,20,17},{32,25,41,12},{40,47,58,64},{34,48,17,59}} end
 if id=='crooked' then roots={{39,45,24,59},{25,59,10,55},{26,58,18,69},{38,45,50,17},{50,20,62,12}} end
 if id=='pine' then roots={{38,38,35,12},{38,40,57,50},{39,43,47,65},{37,43,18,55}} end
 if id=='fir' then roots={{38,39,35,15},{38,41,60,43},{38,42,33,65}} end
 for _,r in ipairs(roots) do
  turn_line(B,d,w,r[1],r[2],r[3],r[4],'woodDeep',3)
  turn_line(B,d,w,r[1],r[2],r[3],r[4],id=='birch' and 'paperShade' or 'wood',2)
  turn_line(B,d,w,r[1],r[2],r[3],r[4],id=='birch' and 'ivory' or 'woodLight',1)
 end
 if id=='birch' then
  for t=0,4 do turn_line(B,d,w,28+t*2,13+t*6,31+t*2,14+t*6,'woodDeep',1) end
 else turn_line(B,d,w,37,34,37,14,'woodDeep',1) end
 -- Sparse tufts have pointed leaf clusters and no rectangular ground plate.
 for i=1,16 do
  local a=i*2.399+1.2;local r=25+noise(i,3,#id)*6
  local x,y=38+math.cos(a)*r,39+math.sin(a)*r
  x,y=rotated(x,y,d,w)
  if not mask[math.floor(y)*w+math.floor(x)] then
   line(G,x-2,y+2,x-3,y-2,'greenDeep');line(G,x,y+2,x,y-3,'moss');line(G,x+1,y+1,x+3,y-1,'green')
   pixel(G,x-1,y,'greenLight')
  end
 end
 -- Pixel-cluster lighting: broad shaded lobes, broken edges and leaf shelves.
 -- Geometry rotates, but the world-space upper-left light remains fixed.
 for _,p in ipairs(geometry) do
  local x,y,ox,oy,h,lobe=table.unpack(p)
  local cx,cy=rotated(lobe[1],lobe[2],d,w)
  local light=((cx-x)+(cy-y))*.018
  local cluster=(noise(math.floor(ox/4),math.floor(oy/3),#id)-.5)*.24
  local shade=math.max(1,math.min(6,math.floor(1.55+h*2.8+light+cluster)))
  if not mask[(y+1)*w+x] or not mask[y*w+x+1] then shade=math.max(1,shade-1) end
  pixel(C,x,y,id..shade)
 end
 for _,p in ipairs(geometry) do
  local x,y,ox,oy,h=table.unpack(p)
  local cellx,celly=math.floor(ox/5),math.floor(oy/5)
  if h>.14 and ox%5==1 and oy%5==2 and noise(cellx,celly,#id)>.36 then
   local shade=math.max(3,math.min(6,math.floor(3.7+h+((38-x)+(38-y))*.022)))
   local points={{0,0},{1,-1},{2,-1},{-1,1},{0,1},{1,1}}
   for _,point in ipairs(points) do
    local u,v=x+point[1],y+point[2]
    if mask[v*w+u] then pixel(H,u,v,id..shade) end
   end
   if mask[(y+2)*w+x+1] then pixel(H,x+1,y+2,id..math.max(2,shade-2)) end
  end
 end
 -- Conifer branch shelves follow a radial needle grain instead of leaf curls.
 if id=='pine' or id=='fir' then
  local arms=id=='pine' and 13 or 5
  for arm=0,arms-1 do
   local a=arm*math.pi*2/arms+.11
   for radius=6,22,4 do
    local x,y=38+math.cos(a)*radius,39+math.sin(a)*radius
    x,y=rotated(x,y,d,w)
    local shade=(x+y<76) and id..5 or id..4
    for off=-2,2 do
     local u,v=math.floor(x+off+.5),math.floor(y-math.abs(off)+.5)
     if mask[v*w+u] then pixel(H,u,v,shade) end
    end
   end
  end
 end
 return out
end

-- An open cut with individually authored rock facets, timber braces and warm
-- mineral veins. No surrounding tile/base is painted into the sprite.
local rocks={
 {{18,23},{25,11},{40,9},{48,20},{39,31},{24,33}},
 {{43,12},{59,10},{70,21},{64,35},{47,34},{39,25}},
 {{66,24},{79,25},{85,39},{80,55},{66,51},{60,36}},
 {{12,36},{23,28},{35,36},{31,54},{19,61},{8,49}},
 {{17,56},{29,46},{42,54},{40,71},{27,76},{14,68}},
 {{62,47},{78,48},{86,63},{78,77},{64,73},{55,60}},
 {{35,25},{50,21},{61,32},{57,48},{39,45},{29,36}},
}
local function rock(im,detail,points,d,index)
 local p=turn_points(points,d,95);poly(im,p,'stoneDeep')
 local cx,cy=0,0;for _,point in ipairs(p) do cx=cx+point[1];cy=cy+point[2] end;cx=cx/#p;cy=cy/#p
 local inner={};for _,point in ipairs(p) do inner[#inner+1]={cx+(point[1]-cx)*.80,cy+(point[2]-cy)*.80} end
 poly(detail,inner,'stone')
 for i,a in ipairs(p) do local b=p[i%#p+1]
  local mx,my=(a[1]+b[1])/2,(a[2]+b[2])/2
  local light=(mx-cx)+(my-cy)<-3
  poly(detail,{{cx-2,cy-2},{a[1],a[2]},{b[1],b[2]}},light and 'stoneLight' or (((i+index)%3==0) and 'stoneWarm' or 'stone'))
  if light then line(detail,a[1]+1,a[2]+1,b[1]-1,b[2]-1,'stoneLight') end
 end
 -- Broken cracks: short forks, kept inside the material's facets.
 line(detail,cx-3,cy+1,cx+3,cy+4,'stoneDeep');line(detail,cx+2,cy+3,cx+5,cy+1,'stoneDeep')
 -- Small planar chips and mineral inclusions break broad flat surfaces.
 for k=0,5 do
  local x=math.floor(cx-5+noise(k,index,9)*10);local y=math.floor(cy-5+noise(index,k,4)*10)
  local shade=(x+y<cx+cy) and 'stoneLight' or 'stoneDeep'
  line(detail,x,y,x+2,y,shade);pixel(detail,x+1,y+1,(k%3==0) and 'stoneWarm' or 'stone')
 end
end
local function mine(d)
 local w=95;local out=images(w);local S,G,B,C,H=table.unpack(out)
 for _,points in ipairs(rocks) do
  local shifted={};for _,p in ipairs(turn_points(points,d,w)) do shifted[#shifted+1]={p[1]+2,p[2]+3} end
  poly(S,shifted,alpha('shadow',48))
 end
 -- Loose soil around the mouth and rails remains irregular and local.
 poly(G,turn_points({{32,54},{51,48},{63,59},{65,73},{56,85},{34,81},{25,69}},d,w),'woodDeep')
 poly(G,turn_points({{32,58},{51,53},{61,62},{58,80},{38,79},{29,68}},d,w),'wood')
 for i,points in ipairs(rocks) do rock(B,C,points,d,i) end
 -- Deep mine entrance between the outcrop shoulders, seen straight overhead.
 poly(C,turn_points({{35,40},{43,35},{54,39},{62,48},{59,67},{37,68},{31,55}},d,w),'ink')
 poly(C,turn_points({{38,43},{49,40},{57,46},{56,63},{39,63}},d,w),'shadow')
 for _,x in ipairs({33,58}) do
  poly(H,turn_points({{x,44},{x+4,43},{x+5,70},{x,71}},d,w),'woodDeep')
  turn_line(H,d,w,x+1,45,x+1,69,'woodLight',2)
  turn_line(H,d,w,x+3,48,x+3,64,'wood',1)
 end
 poly(H,turn_points({{31,42},{63,42},{64,48},{31,47}},d,w),'woodDeep')
 turn_line(H,d,w,33,43,61,43,'woodLight',2)
 turn_line(H,d,w,37,46,54,46,'wood',1)
 for _,x in ipairs({35,59}) do local u,v=rotated(x,45,d,w);pixel(H,u,v,'steelLight') end
 -- Short internal rail pair and three old cross-ties lead into the opening.
 for _,y in ipairs({61,69,77}) do turn_line(H,d,w,35,y,60,y-1,'woodDeep',3);turn_line(H,d,w,37,y,58,y,'woodLight') end
 for _,x in ipairs({40,54}) do turn_line(H,d,w,x,55,x,80,'steel',2);turn_line(H,d,w,x,59,x,77,'stoneLight') end
 -- Gold is a branching seam, embedded in rock, rather than coins on top.
 local veins={{{22,20},{28,24},{28,29},{33,31}},{{61,17},{57,23},{61,28},{60,33}},{{73,34},{75,40},{71,44},{74,49}},{{20,48},{23,53},{20,59},{24,63}},{{74,60},{68,64},{70,68}}}
 for _,vein in ipairs(veins) do
  for i=1,#vein-1 do local a,b=vein[i],vein[i+1]
   turn_line(H,d,w,a[1],a[2],b[1],b[2],'goldDeep',3)
   turn_line(H,d,w,a[1],a[2],b[1],b[2],'gold',2)
  end
  for i,p in ipairs(vein) do local x,y=rotated(p[1],p[2],d,w);pixel(H,x,y,'goldLight');if i%2==0 then pixel(H,x-1,y,'ivory') end end
 end
 -- Moss, roots, shale chips and two low shrubs soften the cut edges.
 for _,p in ipairs({{13,29},{20,75},{68,78},{82,55},{38,12},{74,20}}) do
  local x,y=rotated(p[1],p[2],d,w)
  poly(H,{{x-3,y},{x-2,y-3},{x+1,y-4},{x+4,y-1},{x+2,y+3},{x-2,y+2}},'greenDeep')
  line(H,x-2,y-1,x+1,y-2,'green');pixel(H,x-1,y-2,'greenLight');pixel(H,x+2,y,'moss')
 end
 for _,p in ipairs({{9,64},{15,78},{70,83},{84,72},{83,20},{46,7}}) do
  local x,y=rotated(p[1],p[2],d,w)
  poly(H,{{x-2,y},{x,y-2},{x+3,y},{x+1,y+2}},'stoneDeep');line(H,x-1,y,x+1,y-1,'stone')
 end
 turn_line(H,d,w,16,69,9,72,'woodDeep',2);turn_line(H,d,w,15,70,10,72,'wood')
 return out
end

local layers={'Grounded shadow','Roots, grass and soil','Structure silhouette','Material planes','Leaf, mineral and edge clusters'}
local function master(path,w,frames,pivot,draw)
 if app.fs.isFile(path) and app.params.rebuild~='true' then return end
 local sprite=Sprite(w,w,ColorMode.RGB);sprite.layers[1].name=layers[1]
 for i=2,#layers do local layer=sprite:newLayer();layer.name=layers[i] end
 sprite.gridBounds=Rectangle(0,0,19,19)
 local p=sprite.palettes[1];p:resize(#swatches+1);p:setColor(0,Color{r=0,g=0,b=0,a=0})
 for i,color in ipairs(swatches) do p:setColor(i,color) end
 for frame,item in ipairs(frames) do
  if frame>1 then sprite:newEmptyFrame() end
  sprite.frames[frame].duration=1
  for i,im in ipairs(draw(item)) do sprite:newCel(sprite.layers[i],frame,im,Point(0,0)) end
 end
 for i,item in ipairs(frames) do local tag=sprite:newTag(i,i);tag.name=item.name end
 local slice=sprite:newSlice(Rectangle(0,0,w,w));slice.name='frame';slice.pivot=Point(pivot,pivot)
 sprite.data=json.encode({projection='orthographic_overhead',pixels_per_tile=19,lighting='screen_upper_left',static=true})
 sprite:saveAs(path);sprite:close()
end
local trees={};for _,name in ipairs(names) do for d,direction in ipairs(directions) do trees[#trees+1]={name=name..'_'..direction,variant=name,d=d-1} end end
local mines={};for d,direction in ipairs(directions) do mines[#mines+1]={name='mine_'..direction,d=d-1} end
master(source..'trees.aseprite',76,trees,38,function(item) return tree(item.variant,item.d) end)
master(source..'mine.aseprite',95,mines,47,function(item) return mine((item.d+2)%4) end)
local validation={pixels_per_tile=19,minimum_transparent_margin=3,assets={}}
local function export(name,w,frames,pivot,cols)
 local sprite=assert(app.open(source..name..'.aseprite'));assert(sprite.width==w and sprite.height==w and #sprite.frames==#frames)
 local rows=math.ceil(#frames/cols);local atlas=Image(w*cols,w*rows,ColorMode.RGB)
 local contact=Image(w*cols,w*rows,ColorMode.RGB)
 for y=0,contact.height-1 do for x=0,contact.width-1 do contact:drawPixel(x,y,colors[(math.floor(x/19)+math.floor(y/19))%2==0 and 'meadow' or 'meadowDark']) end end
 local metadata={source='assets/environment/guild_clearing/forest/'..name..'.aseprite',canvas={w,w},pivot={pivot,pivot},pixels_per_tile=19,columns=cols,rows=rows,frames={}}
 local info={width=w,height=w,frames=#frames,layers={},tags={},transparent_margin=3,pixel_counts={}}
 for _,layer in ipairs(sprite.layers) do info.layers[#info.layers+1]=layer.name end
 for i,item in ipairs(frames) do
  assert(sprite.tags[i].name==item.name and sprite.tags[i].fromFrame.frameNumber==i and sprite.tags[i].toFrame.frameNumber==i)
  info.tags[#info.tags+1]=item.name
  local im=Image(w,w,ColorMode.RGB);im:drawSprite(sprite,i)
  local opaque,translucent=0,0
  for y=0,w-1 do for x=0,w-1 do
   local a=app.pixelColor.rgbaA(im:getPixel(x,y))
   assert(a==0 or (x>=3 and y>=3 and x<w-3 and y<w-3),'Opaque atlas border: '..item.name)
   if a==255 then opaque=opaque+1 elseif a>0 then translucent=translucent+1 end
  end end
  assert(opaque>600 and translucent>100,'Missing material or shadow: '..item.name)
  info.pixel_counts[item.name]={opaque=opaque,translucent=translucent}
  local x,y=((i-1)%cols)*w,math.floor((i-1)/cols)*w
  atlas:drawImage(im,Point(x,y));contact:drawImage(im,Point(x,y))
  metadata.frames[item.name]={region={x,y,w,w},pivot={pivot,pivot},tag=item.name}
  im:saveAs(preview..item.name..'.png')
 end
 atlas:saveAs(runtime..name..'.png');atlas:saveAs(preview..name..'.png')
 contact:saveAs(preview..name..'-field-1x.png');contact:resize(contact.width*3,contact.height*3);contact:saveAs(preview..name..'-field-3x.png')
 write(runtime..name..'.json',json.encode(metadata));validation.assets[name]=info
 if not app.fs.isFile(runtime..name..'.png.import') then write(runtime..name..'.png.import','[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\nmipmaps/generate=false\ndetect_3d/compress_to=0\nprocess/fix_alpha_border=false\n') end
 sprite:close()
end
export('trees',76,trees,38,4);export('mine',95,mines,47,4)
write(source..'validation.json',json.encode(validation))
print('Guild forest: 20 layered 76px trees, four layered 95px mine orientations; margins and tags validated.')
