-- Native Aseprite pixels. The saved layered master remains authoritative.
-- aseprite -b --script-param root=/absolute/repo --script [this file]
-- Only rebuild=true replaces the master with this original authored pixel score.
local root=assert(app.params.root,'root required')..'/'
local dir=root..'assets/npcs/keeper/seated/'
local runtime=root..'arenic-game/assets/npcs/keeper/seated/'
for _,p in ipairs({dir,dir..'previews/',runtime}) do app.fs.makeAllDirectories(p) end
local function read(path) local f=assert(io.open(path));local v=json.decode(f:read('*a'));f:close();return v end
local function write(path,text) local f=assert(io.open(path,'w'));f:write(text);f:close() end
local colors,swatches={},{}
local function load_palette(path)
 for _,e in ipairs(read(path).colors) do
  local L,C,H=table.unpack(e.oklch);local a=C*math.cos(math.rad(H));local b=C*math.sin(math.rad(H))
  local l=(L+.3963377774*a+.2158037573*b)^3;local m=(L-.1055613458*a-.0638541728*b)^3;local s=(L-.0894841775*a-1.291485548*b)^3
  local function enc(v) return math.floor(math.max(0,math.min(1,v<=.0031308 and 12.92*v or 1.055*v^(1/2.4)-.055))*255+.5) end
  local c=Color{r=enc(4.0767416621*l-3.3077115913*m+.2309699292*s),g=enc(-1.2684380046*l+2.6097574011*m-.3413193965*s),b=enc(-.0041960863*l-.7034186147*m+1.707614701*s),a=math.floor((e.alpha or 1)*255+.5)}
  colors[e.id]=c.rgbaPixel;swatches[#swatches+1]=c
 end
end
load_palette(root..'assets/environment/palette.oklch.json')
load_palette(root..'assets/npcs/keeper/palette.oklch.json')
local W,H=38,38
local function dot(im,x,y,c)
 assert(x>=3 and x<W-3 and y>=3 and y<H-3,'transparent margin')
 im:drawPixel(x,y,type(c)=='string' and assert(colors[c],c) or c)
end
local function rect(im,x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(im,xx,yy,c) end end end
local function line(im,x,y,u,v,c)
 local n=math.max(math.abs(u-x),math.abs(v-y),1)
 for i=0,n do dot(im,math.floor(x+(u-x)*i/n+.5),math.floor(y+(v-y)*i/n+.5),c) end
end
local function box(im,x,y,w,h,c) rect(im,x,y,w,h,'ink');rect(im,x+1,y+1,w-2,h-2,c) end
local function ellipse(im,x,y,rx,ry,c)
 for yy=-ry,ry do for xx=-rx,rx do if (xx/rx)^2+(yy/ry)^2<=1 then dot(im,x+xx,y+yy,c) end end end
end
local function poly(im,pts,c)
 local lo,hi=H,0;for _,p in ipairs(pts) do lo=math.min(lo,p[2]);hi=math.max(hi,p[2]) end
 for y=lo,hi do
  local xs={};local j=#pts
  for i,a in ipairs(pts) do local b=pts[j]
   if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then xs[#xs+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2]) end;j=i
  end
  table.sort(xs);for i=1,#xs-1,2 do for x=math.ceil(xs[i]),math.floor(xs[i+1]) do dot(im,x,y,c) end end
 end
end
local durations={.8,.3,.8,.3,.18,.22,.30,.24}
local master=dir..'keeper_seated.aseprite'
if not app.fs.isFile(master) or app.params.rebuild=='true' then
 -- Retain the exact original south-facing silver crown and topknot pixels.
 local reference=assert(app.open(root..'assets/npcs/keeper/keeper.aseprite'))
 local crown_layer
 for _,layer in ipairs(reference.layers) do if layer.name=='Silver crown and topknot' then crown_layer=layer end end
 local crown=assert(assert(crown_layer,'original crown layer'):cel(9),'original idle_s crown cel')
 local crown_image=Image(crown.image);local crown_at=Point(crown.position.x+9,crown.position.y+2)
 reference:close()
 local sprite=Sprite(W,H,ColorMode.RGB)
 local names={'Ground shadow','Timber chair and feet','Violet mantle and lap','Ivory collar','Sleeves and quiet hands','Gold clasp and eightfold thread','Silver crown and topknot'}
 sprite.layers[1].name=names[1];for i=2,#names do sprite:newLayer().name=names[i] end
 sprite.gridBounds=Rectangle(0,0,19,19)
 local palette=sprite.palettes[1];palette:resize(#swatches+1);palette:setColor(0,Color{r=0,g=0,b=0,a=0});for i,c in ipairs(swatches) do palette:setColor(i,c) end
 for frame=1,8 do
  if frame>1 then sprite:newEmptyFrame() end
  sprite.frames[frame].duration=durations[frame]
  local ims={};for i=1,#names do ims[i]=Image(W,H,ColorMode.RGB) end
  local S,C,R,I,A,G,Hd=table.unpack(ims)
  ellipse(S,20,22,13,12,'shadow')
  -- Stable chair, seen from above: back rail, narrow arms, seat, four feet.
  box(C,9,8,20,6,'woodDeep');line(C,11,9,26,9,'woodLight');line(C,12,11,25,11,'wood')
  for _,x in ipairs({9,26}) do box(C,x,7,3,6,'wood');dot(C,x+1,8,'woodLight');box(C,x,28,3,4,'woodDeep') end
  rect(C,11,13,16,16,'woodDeep');line(C,13,14,13,27,'wood');line(C,24,14,24,27,'wood')
  for _,x in ipairs({8,27}) do box(C,x,14,4,15,'wood');line(C,x+1,15,x+1,26,'woodLight');dot(C,x+1,16,'gold_shadow') end
  -- Shoulders and bent robed knees form one overhead seated silhouette.
  poly(R,{{13,11},{23,11},{26,15},{26,23},{25,28},{22,31},{14,31},{11,27},{11,16}},'ink')
  poly(R,{{14,12},{22,12},{25,16},{25,24},{22,29},{15,29},{12,25},{12,17}},'robe_shadow')
  poly(R,{{14,13},{21,13},{24,17},{23,23},{22,28},{15,28},{13,23},{13,17}},'robe')
  line(R,14,18,15,26,'robe_light');line(R,16,26,21,28,'robe_light');line(R,23,22,22,27,'robe_shadow')
  line(R,18,22,18,28,'robe_shadow');line(R,19,24,19,28,'robe_light')
  -- Small breathing changes redraw folds, never translate the chair or head.
  if frame==2 or frame==4 then line(R,14,24,16,27,'robe_light');dot(R,21,27,'robe_edge')
  else line(R,14,23,15,25,'robe_light');dot(R,20,28,'robe_edge') end
  poly(I,{{13,17},{16,18},{20,18},{24,16},{23,20},{19,22},{14,20}},'ivory_shadow')
  line(I,14,18,17,20,'ivory');line(I,20,20,23,18,'ivory')
  -- Left hand rests over the near chair arm. Right hand lifts in invitation.
  poly(A,{{12,17},{14,20},{13,24},{10,25},{9,22},{10,19}},'robe_shadow')
  line(A,10,20,11,23,'robe_light');rect(A,10,24,3,2,'skin_shadow');rect(A,10,24,2,1,'skin')
  local reach=({0,0,0,0,0,2,3,1})[frame]
  local rise=({0,0,0,0,0,1,3,1})[frame]
  poly(A,{{23,17},{26,18},{28+reach,22-rise},{28+reach,25-rise},{25,25},{23,21}},'ink')
  poly(A,{{24,18},{26,19},{27+reach,22-rise},{27+reach,24-rise},{25,24},{24,21}},'robe')
  line(A,25,20,27+reach,23-rise,'robe_light')
  rect(A,27+reach,24-rise,2,2,'skin_shadow');rect(A,27+reach,24-rise,2,1,'skin')
  if reach>0 then dot(A,28+reach,23-rise,'skin');dot(A,27+reach,25-rise,'skin_shadow') end
  -- Worn clasp and restrained eightfold stitches, never an overt spider form.
  ellipse(G,23,19,2,2,'gold_shadow');dot(G,23,18,'gold_light');dot(G,22,19,'gold');dot(G,23,20,'gold');dot(G,24,19,'gold')
  for _,p in ipairs({{14,24},{15,27},{17,29},{20,29},{22,28},{24,25},{14,16},{22,14}}) do dot(G,p[1],p[2],'gold_shadow') end
  Hd:drawImage(crown_image,crown_at)
  for i,im in ipairs(ims) do sprite:newCel(sprite.layers[i],frame,im,Point(0,0)) end
 end
 local idle=sprite:newTag(1,4);idle.name='idle_s'
 local beckon=sprite:newTag(5,8);beckon.name='beckon_s'
 local slice=sprite:newSlice(Rectangle(0,0,W,H));slice.name='frame';slice.pivot=Point(19,19)
 sprite.data=json.encode({projection='true overhead orthographic',facing='south',pose='seated',source_crown='keeper.aseprite layer Silver crown and topknot, frame 9',chair_fixed=true})
 sprite:saveAs(master);sprite:close()
end
local sprite=assert(app.open(master));assert(sprite.width==W and sprite.height==H and #sprite.frames==8)
local sheet=Image(W*8,H,ColorMode.RGB);local frames={};local frame_rows={}
for f=1,8 do
 local im=Image(W,H,ColorMode.RGB);im:drawSprite(sprite,f);sheet:drawImage(im,Point((f-1)*W,0));frames[f]=im
 local bounds={W,H,0,0};local count=0
 for it in im:pixels() do if app.pixelColor.rgbaA(it())>0 then
  assert(it.x>=3 and it.x<W-3 and it.y>=3 and it.y<H-3,'export lost margin')
  bounds[1]=math.min(bounds[1],it.x);bounds[2]=math.min(bounds[2],it.y);bounds[3]=math.max(bounds[3],it.x);bounds[4]=math.max(bounds[4],it.y);count=count+1
 end end
 frame_rows[f]={index=f,region={(f-1)*W,0,W,H},duration_msec=math.floor(sprite.frames[f].duration*1000+.5),alpha_bounds=bounds,nontransparent_pixels=count}
end
sheet:saveAs(runtime..'keeper_seated.png');sheet:saveAs(dir..'previews/keeper_seated.png')
sheet:resize(W*8*4,H*4);sheet:saveAs(dir..'previews/keeper_seated-4x.png')
frames[1]:saveAs(dir..'previews/idle-s.png');frames[1]:resize(W*4,H*4);frames[1]:saveAs(dir..'previews/idle-s-4x.png')
frames[7]:saveAs(dir..'previews/beckon-s.png');frames[7]:resize(W*4,H*4);frames[7]:saveAs(dir..'previews/beckon-s-4x.png')
local metadata={source='assets/npcs/keeper/seated/keeper_seated.aseprite',canvas={W,H},atlas={W*8,H},pivot={19,19},frames=frame_rows,tags={{name='idle_s',from=1,to=4,loop=true},{name='beckon_s',from=5,to=8,loop=false}},layers=#sprite.layers,nearest=true,trimmed=false}
write(runtime..'keeper_seated.json',json.encode(metadata));write(dir..'validation.json',json.encode(metadata))
local tres={'[gd_resource type="SpriteFrames" load_steps=10 format=3]','', '[ext_resource type="Texture2D" path="res://assets/npcs/keeper/seated/keeper_seated.png" id="1"]',''}
for f=1,8 do tres[#tres+1]='[sub_resource type="AtlasTexture" id="Atlas_'..f..'"]\natlas = ExtResource("1")\nregion = Rect2('..((f-1)*W)..', 0, 38, 38)\n' end
tres[#tres+1]='[resource]\nanimations = ['
for t,tag in ipairs(metadata.tags) do
 tres[#tres+1]='{\n"frames": ['
 for f=tag.from,tag.to do tres[#tres+1]='{ "duration": '..tostring(sprite.frames[f].duration*1000)..', "texture": SubResource("Atlas_'..f..'") }'..(f<tag.to and ',' or '') end
 tres[#tres+1]='],\n"loop": '..tostring(tag.loop)..',\n"name": &"'..tag.name..'",\n"speed": 1000.0\n}'..(t<#metadata.tags and ',' or '')
end
tres[#tres+1]=']';write(runtime..'keeper_seated.tres',table.concat(tres,'\n')..'\n')
if not app.fs.isFile(runtime..'keeper_seated.png.import') then write(runtime..'keeper_seated.png.import','[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\nmipmaps/generate=false\ndetect_3d/compress_to=0\nprocess/fix_alpha_border=false\n') end
sprite:close();print('Seated Keeper exported: '..json.encode(metadata))
