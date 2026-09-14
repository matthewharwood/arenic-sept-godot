-- Native Aseprite authoring/export. Existing masters remain authoritative.
-- aseprite --batch --script-param root=/absolute/repo --script assets/pipeline/build-gathering-sites.lua
-- rebuild=true explicitly regenerates the editable master from this pixel score.
local root=assert(app.params.root,'root is required')..'/'
local source_dir=root..'assets/environment/gathering/'
local runtime=root..'arenic-game/assets/environment/gathering/'
local preview=source_dir..'previews/'
for _,p in ipairs({source_dir,runtime,preview}) do app.fs.makeAllDirectories(p) end
local file=assert(io.open(root..'assets/environment/palette.oklch.json','r'))
local palette=json.decode(file:read('*a'));file:close()
local colors={};local swatches={}
for _,entry in ipairs(palette.colors) do
 local L,C,H=table.unpack(entry.oklch);local a=C*math.cos(math.rad(H));local b=C*math.sin(math.rad(H))
 local l=(L+.3963377774*a+.2158037573*b)^3
 local m=(L-.1055613458*a-.0638541728*b)^3
 local s=(L-.0894841775*a-1.291485548*b)^3
 local function enc(v) return math.floor(math.max(0,math.min(1,v<=.0031308 and 12.92*v or 1.055*v^(1/2.4)-.055))*255+.5) end
 local c=Color{r=enc(4.0767416621*l-3.3077115913*m+.2309699292*s),g=enc(-1.2684380046*l+2.6097574011*m-.3413193965*s),b=enc(-.0041960863*l-.7034186147*m+1.707614701*s)}
 colors[entry.id]=c.rgbaPixel;table.insert(swatches,c)
end
local W=57
local names={'wood_source','gold_source','wood_dropoff','gold_dropoff'}
local master=source_dir..'gathering_sites.aseprite'
local function dot(im,x,y,c)
 x=math.floor(x+.5);y=math.floor(y+.5)
 assert(x>=3 and x<W-3 and y>=3 and y<W-3,'art must retain transparent margins')
 im:drawPixel(x,y,type(c)=='string' and assert(colors[c],c) or c)
end
local function rect(im,x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(im,xx,yy,c) end end end
local function line(im,x,y,u,v,c)
 local n=math.max(math.abs(u-x),math.abs(v-y),1)
 for i=0,n do dot(im,x+(u-x)*i/n,y+(v-y)*i/n,c) end
end
local function poly(im,points,fill,edge)
 local low,high=W,0
 for _,p in ipairs(points) do low=math.min(low,p[2]);high=math.max(high,p[2]) end
 for y=low,high do
  local xs={};local j=#points
  for i=1,#points do local a,b=points[i],points[j]
   if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then xs[#xs+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2]) end
   j=i
  end
  table.sort(xs)
  for i=1,#xs-1,2 do for x=math.ceil(xs[i]),math.floor(xs[i+1]) do dot(im,x,y,fill) end end
 end
 if edge then for i,a in ipairs(points) do local b=points[i%#points+1];line(im,a[1],a[2],b[1],b[2],edge) end end
end
local function box(im,x,y,w,h,fill,edge) rect(im,x,y,w,h,edge or 'ink');rect(im,x+1,y+1,w-2,h-2,fill) end
local function ellipse(im,x,y,rx,ry,c)
 for yy=-ry,ry do for xx=-rx,rx do if (xx/rx)^2+(yy/ry)^2<=1 then dot(im,x+xx,y+yy,c) end end end
end
local function log(im,x,y,length)
 box(im,x,y,length,7,'woodDeep');rect(im,x+2,y+1,length-4,2,'woodLight')
 line(im,x+2,y+4,x+length-3,y+4,'wood')
 ellipse(im,x+length-3,y+3,3,3,'ink');ellipse(im,x+length-3,y+3,2,2,'paperShade');dot(im,x+length-3,y+3,'wood')
 line(im,x+2,y+2,x+length-7,y+2,'wood')
end
local function ore(im,x,y,size)
 poly(im,{{x-size,y},{x-1,y-size},{x+size,y-size+1},{x+size+1,y+2},{x,y+size}},'gold','goldDeep')
 line(im,x-size+1,y,x,y-size+1,'goldLight');dot(im,x+1,y-1,'ivory');line(im,x+1,y+size-1,x+size,y+1,'goldDeep')
end
if not app.fs.isFile(master) or app.params.rebuild=='true' then
 local sprite=Sprite(W,W,ColorMode.RGB);sprite.layers[1].name='Ground shadow'
 for _,name in ipairs({'Material silhouettes','Tools and resource detail','Edge light'}) do local layer=sprite:newLayer();layer.name=name end
 sprite.gridBounds=Rectangle(0,0,19,19)
 local p=sprite.palettes[1];p:resize(#swatches+1);p:setColor(0,Color{r=0,g=0,b=0,a=0})
 for i,c in ipairs(swatches) do p:setColor(i,c) end
 for frame,name in ipairs(names) do
  if frame>1 then sprite:newEmptyFrame() end
  sprite.frames[frame].duration=1.0
  local S,B,D,H=Image(W,W,ColorMode.RGB),Image(W,W,ColorMode.RGB),Image(W,W,ColorMode.RGB),Image(W,W,ColorMode.RGB)
  local shadow=Color(colors.shadow);shadow.alpha=78
  ellipse(S,28,31,22,17,shadow.rgbaPixel)
  if frame==1 then
   -- An overhead evergreen crown, cut rounds and two bark-covered logs.
   poly(B,{{11,12},{18,8},{25,11},{30,8},{34,17},{38,22},{33,30},{26,34},{19,32},{11,34},{12,25},{7,21}},'greenDeep','ink')
   poly(D,{{18,11},{24,14},{29,10},{30,19},{35,23},{27,25},{24,32},{20,25},{11,29},{15,20},{10,19}},'green','ink')
   poly(H,{{18,13},{23,18},{27,13},{26,22},{21,26},{20,21},{15,25}},'greenLight')
   line(H,20,18,23,22,'leafTip');line(H,28,20,31,22,'greenLight')
   ellipse(B,38,35,9,7,'ink');ellipse(D,38,34,8,6,'wood');ellipse(D,38,34,6,5,'woodLight')
   ellipse(H,38,34,4,3,'wood');ellipse(H,38,34,2,1,'paperShade');line(H,39,34,43,36,'woodDeep')
   log(D,13,37,17);log(D,20,44,22)
   line(H,28,39,35,46,'woodLight');poly(H,{{28,38},{33,35},{36,38},{32,41}},'steel','ink');line(H,31,36,34,38,'steelLight')
  elseif frame==2 then
   -- A dark overhead mine cut with timber bracing and exposed gold seams.
   poly(B,{{11,14},{24,8},{38,11},{47,23},{44,39},{32,46},{16,42},{7,29}},'stoneDeep','ink')
   poly(D,{{12,15},{23,10},{33,13},{28,22},{13,24}},'stone')
   poly(D,{{36,14},{44,23},{41,32},{34,26},{29,21}},'stoneLight')
   poly(D,{{12,30},{19,26},{26,33},{29,43},{18,39}},'stone')
   poly(D,{{22,20},{33,20},{37,29},{33,37},{23,35},{18,27}},'ink')
   line(H,12,15,22,11,'stoneLight');line(H,10,29,17,35,'stoneLight')
   for _,x in ipairs({19,34}) do box(H,x,19,4,20,'wood');line(H,x+1,21,x+1,36,'woodLight') end
   box(H,17,18,23,5,'woodDeep');line(H,18,19,38,19,'woodLight')
   box(H,18,34,22,4,'wood');line(H,19,35,38,35,'woodLight')
   ore(H,15,25,3);ore(H,40,35,4);ore(H,32,42,2);ore(H,28,13,2)
   line(H,42,43,49,35,'woodLight');poly(H,{{43,35},{47,31},{51,32},{47,34}},'steel','ink')
  elseif frame==3 then
   -- Timber receiving rack: open slatted frame, stacked ends and binding rope.
   box(B,9,13,39,33,'woodDeep');rect(D,12,16,33,27,'ink')
   for _,y in ipairs({17,26,35}) do log(D,14,y,28) end
   for _,x in ipairs({9,44}) do box(H,x,11,4,37,'wood');line(H,x+1,13,x+1,45,'woodLight') end
   line(H,24,16,24,41,'paperShade');line(H,25,16,25,41,'paper');line(H,23,29,28,31,'paper')
   for _,x in ipairs({10,45}) do dot(H,x+1,14,'steelLight');dot(H,x+1,43,'steel') end
   box(H,20,9,16,6,'wood');line(H,23,11,32,11,'paperShade');line(H,23,13,30,13,'paperShade')
  else
   -- Open strongbox viewed from above, with a gold-rimmed tray of raw nuggets.
   box(B,10,13,37,32,'ink');box(D,12,15,33,28,'woodDeep')
   box(D,13,8,31,12,'wood');rect(D,15,10,27,7,'violetDeep')
   line(H,15,10,41,10,'gold');line(H,15,11,15,16,'goldDeep');line(H,41,11,41,16,'goldDeep')
   rect(D,15,23,27,17,'ink')
   ore(H,20,28,4);ore(H,31,27,4);ore(H,36,34,3);ore(H,24,35,4);ore(H,16,36,2)
   for _,x in ipairs({12,42}) do rect(H,x,20,3,22,'goldDeep');line(H,x+1,20,x+1,40,'gold') end
   box(H,25,40,8,7,'goldDeep');rect(H,27,41,4,4,'gold');dot(H,28,43,'ink')
   line(H,15,42,24,42,'woodLight');line(H,34,42,40,42,'woodLight')
  end
  for i,im in ipairs({S,B,D,H}) do sprite:newCel(sprite.layers[i],frame,im,Point(0,0)) end
 end
 for i,name in ipairs(names) do local tag=sprite:newTag(i,i);tag.name=name end
 local slice=sprite:newSlice(Rectangle(0,0,W,W));slice.name='frame';slice.pivot=Point(28,28)
 sprite.data=json.encode({projection='overhead',pixels_per_tile=19,static_objects=true})
 sprite:saveAs(master);sprite:close()
end
local sprite=assert(app.open(master));assert(sprite.width==W and sprite.height==W and #sprite.frames==4)
local atlas=Image(W*4,W,ColorMode.RGB)
local metadata={source='assets/environment/gathering/gathering_sites.aseprite',palette='assets/environment/palette.oklch.json',canvas={W,W},pivot={28,28},pixels_per_tile=19,frames={}}
for i,name in ipairs(names) do
 local im=Image(W,W,ColorMode.RGB);im:drawSprite(sprite,i);atlas:drawImage(im,Point((i-1)*W,0))
 im:saveAs(preview..name..'.png');im:resize(W*4,W*4);im:saveAs(preview..name..'-4x.png')
 metadata.frames[name]={region={(i-1)*W,0,W,W},pivot={28,28}}
end
atlas:saveAs(runtime..'gathering_sites.png');atlas:saveAs(preview..'gathering_sites.png')
atlas:resize(W*16,W*4);atlas:saveAs(preview..'gathering_sites-4x.png')
local function write(path,value) local f=assert(io.open(path,'w'));f:write(value);f:close() end
write(runtime..'gathering_sites.json',json.encode(metadata))
if not app.fs.isFile(runtime..'gathering_sites.png.import') then
 write(runtime..'gathering_sites.png.import','[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\nmipmaps/generate=false\ndetect_3d/compress_to=0\nprocess/fix_alpha_border=false\n')
end
sprite:close();print('Gathering sites: four layered 57px masters and native PNG atlas exported.')
