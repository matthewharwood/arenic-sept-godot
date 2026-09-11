-- Editable, true overhead Guild House sparring construct. Existing masters win.
-- aseprite --batch --script-param root=/absolute/repository --script <this file>
local root=assert(app.params.root,'root is required')..'/'
local folder=root..'assets/environment/guild_house/'
local output=root..'arenic-game/assets/environment/'
app.fs.makeAllDirectories(folder); app.fs.makeAllDirectories(output)
local source=folder..'training_target.aseprite'
local W=114
local function oklch(L,C,H,A)
 local a=C*math.cos(math.rad(H));local b=C*math.sin(math.rad(H))
 local l=(L+.3963377774*a+.2158037573*b)^3
 local m=(L-.1055613458*a-.0638541728*b)^3
 local s=(L-.0894841775*a-1.291485548*b)^3
 local function enc(v) return math.floor(math.max(0,math.min(1,v<=.0031308 and 12.92*v or 1.055*v^(1/2.4)-.055))*255+.5) end
 return Color{r=enc(4.0767416621*l-3.3077115913*m+.2309699292*s),g=enc(-1.2684380046*l+2.6097574011*m-.3413193965*s),b=enc(-.0041960863*l-.7034186147*m+1.707614701*s),a=A or 255}.rgbaPixel
end
local ink=oklch(.19,.028,65);local wood=oklch(.39,.075,65);local grain=oklch(.47,.079,70)
local brass=oklch(.72,.123,62.4);local shine=oklch(.89,.08,87);local steel=oklch(.32,.038,205)
local glow=oklch(.78,.12,165);local shadow=oklch(.1,.01,65,120)
local function rect(im,x,y,w,h,c)
 assert(c and w>=0 and h>=0 and w<=W and h<=W, "rectangle needs bounded dimensions and a color")
 for yy=y,y+h-1 do for xx=x,x+w-1 do im:drawPixel(xx,yy,c) end end
end
local function ellipse(im,x,y,rx,ry,c)
 for yy=y-ry,y+ry do for xx=x-rx,x+rx do if ((xx-x)/rx)^2+((yy-y)/ry)^2<=1 then im:drawPixel(xx,yy,c) end end end
end
local function disc(im,x,y,r,c) ellipse(im,x,y,r,r,c) end
local function rivet(im,x,y) disc(im,x,y,3,ink);disc(im,x,y,2,brass);im:drawPixel(x-1,y-1,shine) end
print('Training target: starting source check')
if not app.fs.isFile(source) then
 local sprite=Sprite(W,W,ColorMode.RGB)
 sprite.layers[1].name='Ground shadow'
 local body=sprite:newLayer();body.name='Wood and iron'
 local trim=sprite:newLayer();trim.name='Brass fittings'
 local light=sprite:newLayer();light.name='Clockwork core'
 for f=1,32 do
  if f>1 then sprite:newEmptyFrame() end
  sprite.frames[f].duration=.12
  local direction=math.floor((f-1)/8);local phase=(f-1)%8
  local images={Image(W,W,ColorMode.RGB),Image(W,W,ColorMode.RGB),Image(W,W,ColorMode.RGB),Image(W,W,ColorMode.RGB)}
  local S,B,T,L=table.unpack(images)
  ellipse(S,59,66,45,34,shadow)
  -- A wooden armored torso and paired hinged arms seen straight down.
  rect(B,14,49,86,18,ink);rect(B,18,52,78,12,wood)
  for _,x in ipairs({20,88}) do
   ellipse(B,x,58,9,18,ink);ellipse(B,x,56,7,15,steel)
   rect(T,x-5,44,10,3,brass);rect(T,x-5,67,10,3,brass)
   rivet(T,x,51);rivet(T,x,63)
  end
  ellipse(B,57,60,28,32,ink);ellipse(B,57,58,25,29,wood)
  for x=39,76,6 do rect(B,x,36,2,44,grain) end
  ellipse(T,57,57,25,27,brass);ellipse(T,57,57,22,24,ink)
  ellipse(T,57,57,20,22,wood)
  rect(T,36,49,43,3,brass);rect(T,36,64,43,3,brass)
  rect(B,45,16,25,20,ink);rect(B,48,19,19,15,steel)
  rect(T,49,17,17,3,brass)
  -- A clear north-pointing brow identifies the rear for Backstab.
  for y=20,27 do rect(T,57-math.floor((y-20)/2),y,1+2*math.floor((y-20)/2),1,shine) end
  for _,p in ipairs({{40,39},{74,39},{40,76},{74,76}}) do rivet(T,p[1],p[2]) end
  disc(L,57,57,12,ink);disc(L,57,57,10,brass);disc(L,57,57,8,steel)
  disc(L,57,57,5,glow);disc(L,56,55,2,shine)
  for i=0,3 do
   local angle=(i*2+phase)*math.pi/4
   local x=math.floor(57+math.cos(angle)*9+.5);local y=math.floor(57+math.sin(angle)*9+.5)
   rect(L,x-1,y-1,2,2,shine)
  end
  for layer=1,4 do
   local im=images[layer]
   for _=1,direction do local rotated=Image(W,W,ColorMode.RGB);for it in im:pixels() do rotated:drawPixel(W-1-it.y,it.x,it()) end;im=rotated end
   sprite:newCel(sprite.layers[layer],f,im,Point(0,0))
  end
 end
 for i,d in ipairs({'n','e','s','w'}) do local tag=sprite:newTag((i-1)*8+1,i*8);tag.name='idle_'..d end
 local slice=sprite:newSlice(Rectangle(0,0,W,W));slice.name='frame';slice.pivot=Point(57,57)
 sprite:saveAs(source);sprite:close()
end
local sprite=app.open(source)
assert(sprite.width==W and sprite.height==W and #sprite.frames==32,'unexpected training target master')
local atlas=Image(W*8,W*4,ColorMode.RGB)
for i=1,32 do local frame=Image(W,W,ColorMode.RGB);frame:drawSprite(sprite,i);atlas:drawImage(frame,Point(((i-1)%8)*W,math.floor((i-1)/8)*W)) end
atlas:saveAs(output..'training_target.png')
local lines={'[gd_resource type="SpriteFrames" format=3]','','[ext_resource type="Texture2D" path="res://assets/environment/training_target.png" id="1"]',''}
for i=0,31 do
 table.insert(lines,string.format('[sub_resource type="AtlasTexture" id="F%d"]\natlas = ExtResource("1")\nregion = Rect2(%d, %d, 114, 114)\nfilter_clip = true\n',i,(i%8)*W,math.floor(i/8)*W))
end
table.insert(lines,'[resource]\nanimations = [')
for di,d in ipairs({'n','e','s','w'}) do
 local frames={};for f=(di-1)*8,di*8-1 do table.insert(frames,string.format('{"duration": %s, "texture": SubResource("F%d")}',sprite.frames[f+1].duration*1000,f)) end
 table.insert(lines,string.format('{"frames": [%s], "loop": true, "name": &"idle_%s", "speed": 1000.0}%s',table.concat(frames,', '),d,di==4 and '' or ','))
end
table.insert(lines,']\n')
local file=assert(io.open(output..'training_target_frames.tres','w'));file:write(table.concat(lines,'\n'));file:close()
print('Training target: editable114px master,32frames,four facings; exported saved source.')
sprite:close()
