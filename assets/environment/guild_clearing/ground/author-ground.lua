-- Native Aseprite cluster authoring. No raster-generation library or RNG.
-- Rebuild explicitly with author=true; otherwise export the editable masters.
local ROOT=assert(app.params.root,'Pass root=/absolute/repo')..app.fs.pathSeparator
local BASE=ROOT..'assets/environment/guild_clearing/ground/'
local OUT=ROOT..'arenic-game/assets/environment/guild_clearing/ground/'
local PRE=BASE..'previews/'
app.fs.makeAllDirectories(BASE);app.fs.makeAllDirectories(OUT);app.fs.makeAllDirectories(PRE)
local file=assert(io.open(BASE..'palette.oklch.json','r'));local spec=json.decode(file:read('*a'));file:close()
local C={};local colors={}
local function rgb(L,c,h,alpha)
 local a=c*math.cos(h*math.pi/180);local b=c*math.sin(h*math.pi/180)
 local l=(L+.3963377774*a+.2158037573*b)^3
 local m=(L-.1055613458*a-.0638541728*b)^3
 local s=(L-.0894841775*a-1.291485548*b)^3
 local function encode(x)
  x=x<=.0031308 and 12.92*x or 1.055*x^(1/2.4)-.055
  return math.floor(math.max(0,math.min(1,x))*255+.5)
 end
 return Color{r=encode(4.0767416621*l-3.3077115913*m+.2309699292*s),g=encode(-1.2684380046*l+2.6097574011*m-.3413193965*s),b=encode(-.0041960863*l-.7034186147*m+1.707614701*s),a=alpha or 255}
end
for _,v in ipairs(spec.colors) do local c=rgb(v.oklch[1],v.oklch[2],v.oklch[3],v.alpha);C[v.id]=c.rgbaPixel;colors[#colors+1]=c end
local function dot(im,x,y,c) if x>=0 and y>=0 and x<im.width and y<im.height then im:drawPixel(x,y,C[c] or c) end end
local function cluster(im,x,y,rows,c)
 for dy,row in ipairs(rows) do for dx=1,#row do if row:sub(dx,dx)=='x' then dot(im,x+dx-1,y+dy-1,c) end end end
end
local function poly(im,p,c)
 for y=0,im.height-1 do
  local xs={};local j=#p
  for i=1,#p do local a,b=p[i],p[j]
   if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then xs[#xs+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2]) end
   j=i
  end
  table.sort(xs)
  for i=1,#xs-1,2 do for x=math.ceil(xs[i]),math.floor(xs[i+1]) do dot(im,x,y,c) end end
 end
end
local function translate(p,x,y) local out={};for _,v in ipairs(p) do out[#out+1]={v[1]+x,v[2]+y} end;return out end
local function tuft(im,x,y,small)
 cluster(im,x,y,small and {'x x','xxx',' x '} or {' x   ',' x x ','xx x ',' xxxx',' xxx '},'tuftShade')
 cluster(im,x,y,small and {'  x',' x '} or {' x   ','   x ',' x x '},'tuftLight')
end
local function pebble(im,x,y)
 cluster(im,x,y,{' xxx ','xxxxx',' xxxx'},'pebbleShade')
 cluster(im,x,y,{' xx  ',' xxx '},'pebble')
 dot(im,x+1,y,'pebbleLight');dot(im,x+2,y,'pebbleLight')
end
local function flower(im,x,y)
 cluster(im,x,y+2,{' x ','xx ',' x '},'flowerStem')
 cluster(im,x,y,{' x ','x x',' x '},'flowerPetal')
 dot(im,x+1,y+1,'flowerHeart')
end
local function sprite(w,n,layers)
 local s=Sprite(w,w,ColorMode.RGB);s.layers[1].name=layers[1]
 for i=2,#layers do local layer=s:newLayer();layer.name=layers[i] end
 for i=2,n do s:newEmptyFrame() end
 local pal=s.palettes[1];pal:resize(#colors+1);pal:setColor(0,Color{r=0,g=0,b=0,a=0})
 for i,col in ipairs(colors) do pal:setColor(i,col) end
 return s
end
local grass_names={'moss','sage','olive','dapple'}
local grass_clusters={
 {{2,3,{' xxx ','xxxxx',' xxx '},'mossShade'},{11,11,{' xxx','xxxx',' xx '},'mossShade'},{5,5,{' xx','xx '},'mossLight'},{12,13,{' xx',' x '},'mossLight'}},
 {{10,2,{' xxxx','xxxxx',' xxx '},'sageShade'},{3,11,{' xxxx','xxxxx',' xxx '},'sageShade'},{11,4,{'xxx',' xx'},'sageLight'},{4,13,{'xxx',' x '},'sageLight'}},
 {{3,4,{'xxxxx',' xxx '},'oliveShade'},{9,11,{' xxxx ','xxxxxx',' xxxx '},'oliveShade'},{4,5,{' xx',' x '},'oliveLight'},{11,13,{'xxx',' xx'},'oliveLight'}},
 {{3,2,{' xxx','xxxx',' xx '},'mossShade'},{11,9,{'xxxx',' xxx'},'sageShade'},{3,13,{' xxx','xxxx'},'oliveShade'},{4,4,{'xx'},'mossLight'},{12,10,{' xx'},'sageLight'},{4,14,{'xx'},'oliveLight'}}
}
local function author_grass()
 local s=sprite(19,4,{'Common seamless ground','Hand-shaped moss clusters','Sparse grass blades'})
 for i=1,4 do
  local base=Image(19,19,ColorMode.RGB);base:clear(C.grass)
  local cl=Image(19,19,ColorMode.RGB);local detail=Image(19,19,ColorMode.RGB)
  for _,v in ipairs(grass_clusters[i]) do cluster(cl,v[1],v[2],v[3],v[4]) end
  local blades={{13,4},{6,7},{3,11},{14,14}};local p=blades[i]
  cluster(detail,p[1],p[2],{'x x','xx '},i==3 and 'oliveLight' or 'mossLight')
  for j,im in ipairs({base,cl,detail}) do s:newCel(s.layers[j],i,im,Point(0,0)) end
  local tag=s:newTag(i,i);tag.name=grass_names[i]
 end
 s.data=json.encode({purpose='seamless grass ground',pixels_per_tile=19,edge_contract='all outer pixels share the grass swatch',static_variants=true})
 s:saveAs(BASE..'grass_tiles.aseprite');s:close()
end
local patch_names={'worn_clearing','curved_footpath','stony_clearing'}
local outlines={
 {{9,33},{12,25},{19,23},{23,17},{34,15},{39,18},{49,16},{54,23},{62,27},{64,34},{61,41},{63,47},{57,54},{48,56},{43,62},{32,61},{27,57},{18,58},{13,51},{8,47},{10,40}},
 {{5,55},{9,48},{18,43},{25,35},{29,24},{38,15},{46,13},{53,9},{64,11},{69,18},{66,24},{58,27},{52,25},{46,28},{43,35},{40,44},{34,49},{25,55},{18,64},{10,66},{6,62}},
 {{12,23},{20,19},{29,21},{35,16},{44,18},{49,24},{59,25},{64,31},{60,39},{62,47},{54,50},{51,57},{41,60},{32,56},{22,58},{15,51},{17,44},{10,39},{13,32}}
}
local function author_patches()
 local s=sprite(76,3,{'Soft broken earth fringe','Irregular worn soil','Worn soil clusters','Tufts flowers and pebbles'})
 for i=1,3 do
  local fringe=Image(76,76,ColorMode.RGB);local soil=Image(76,76,ColorMode.RGB);local marks=Image(76,76,ColorMode.RGB);local detail=Image(76,76,ColorMode.RGB)
  -- Shifted copies make a short broken transition, never a rectangular border.
  poly(fringe,translate(outlines[i],-2,0),'soilFringe');poly(fringe,translate(outlines[i],2,1),'soilFringe');poly(fringe,translate(outlines[i],0,-2),'soilFringe')
  poly(soil,outlines[i],'soil')
  if i==1 then
   poly(marks,{{19,32},{24,29},{35,30},{39,34},{34,36},{24,35}},'soilLight')
   poly(marks,{{37,43},{43,40},{52,41},{53,45},{48,47},{40,46}},'soilShade')
   cluster(marks,23,47,{' xxxx ','xxxxxx',' xxxx '},'soilShade')
   cluster(marks,43,25,{'xxxx',' xx '},'soilLight')
   tuft(detail,17,24,false);tuft(detail,54,48,true);tuft(detail,29,58,true)
   pebble(detail,18,42);flower(detail,57,29);flower(detail,59,35)
  elseif i==2 then
   poly(marks,{{12,53},{19,47},{26,43},{30,37},{30,42},{25,49},{17,57}},'soilLight')
   poly(marks,{{39,23},{44,19},{53,17},{62,17},{62,20},{53,20},{46,23},{42,29}},'soilShade')
   cluster(marks,31,38,{'xx',' x','xx'},'soilShade')
   tuft(detail,20,42,true);tuft(detail,43,12,false);tuft(detail,43,35,true)
   pebble(detail,12,61);flower(detail,56,27)
  else
   poly(marks,{{24,27},{33,25},{38,30},{33,33},{25,32}},'soilLight')
   poly(marks,{{33,43},{44,39},{53,41},{54,45},{48,48},{36,48}},'soilShade')
   cluster(marks,20,40,{' xxx ','xxxxx',' xx  '},'soilShade')
   pebble(detail,20,30);pebble(detail,44,30);pebble(detail,36,47);pebble(detail,51,44)
   tuft(detail,13,38,true);tuft(detail,40,57,false);tuft(detail,53,25,true)
   flower(detail,25,20)
  end
  for j,im in ipairs({fringe,soil,marks,detail}) do s:newCel(s.layers[j],i,im,Point(0,0)) end
  local tag=s:newTag(i,i);tag.name=patch_names[i]
 end
 s.data=json.encode({purpose='transparent ground overlays',pixels_per_tile=19,static_variants=true,collision=false})
 s:saveAs(BASE..'dirt_patches.aseprite');s:close()
end
if app.params.author=='true' then author_grass();author_patches() end
local function write(path,value) local f=assert(io.open(path,'w'));f:write(json.encode(value));f:close() end
local validation={aseprite=app.version,authoring='native Lua; deliberate clusters, no random texture',frames={}}
local function export(name,names,w)
 local s=assert(app.open(BASE..name..'.aseprite'));assert(s.width==w and s.height==w and #s.frames==#names)
 local atlas=Image(w*#names,w,ColorMode.RGB);local frames={}
 local meta={source='assets/environment/guild_clearing/ground/'..name..'.aseprite',palette='assets/environment/guild_clearing/ground/palette.oklch.json',pixels_per_tile=19,atlas_size={w*#names,w},frame_size={w,w},layout='single row, untrimmed, no padding',filter='nearest',['repeat']=name=='grass_tiles',collision=false,frames={}}
 for i,id in ipairs(names) do
  local im=Image(w,w,ColorMode.RGB);im:drawSprite(s,i);frames[i]=im;atlas:drawImage(im,Point((i-1)*w,0))
  local proof={name=id,width=w,height=w,transparent=0,partial_alpha=0,opaque=0,edge_violations=0}
  for pixel in im:pixels() do
   local alpha=app.pixelColor.rgbaA(pixel())
   if alpha==0 then proof.transparent=proof.transparent+1 elseif alpha==255 then proof.opaque=proof.opaque+1 else proof.partial_alpha=proof.partial_alpha+1 end
   if pixel.x==0 or pixel.y==0 or pixel.x==w-1 or pixel.y==w-1 then
    if name=='grass_tiles' and pixel()~=C.grass or name=='dirt_patches' and alpha~=0 then proof.edge_violations=proof.edge_violations+1 end
   end
  end
  assert(proof.edge_violations==0,'Unexpected tile seam or clipped patch: '..id)
  assert(name~='grass_tiles' or proof.opaque==w*w,'Grass must cover the field')
  assert(name~='dirt_patches' or proof.transparent>2000 and proof.partial_alpha>500,'Patches must blend over the field')
  validation.frames[#validation.frames+1]=proof
  im:saveAs(PRE..id..'.png');local big=Image(im);big:resize(w*4,w*4);big:saveAs(PRE..id..'-4x.png')
  meta.frames[id]={region={(i-1)*w,0,w,w},pivot={(w-1)/2,(w-1)/2},aseprite_frame=i}
 end
 atlas:saveAs(OUT..name..'.png');atlas:saveAs(PRE..name..'.png')
 local big=Image(atlas);big:resize(w*#names*4,w*4);big:saveAs(PRE..name..'-4x.png')
 write(OUT..name..'.json',meta);s:close();return frames
end
local grass=export('grass_tiles',grass_names,19)
local patches=export('dirt_patches',patch_names,76)
-- Native Aseprite compositing: a practical tiling and overlay readback.
local field=Image(304,190,ColorMode.RGB)
local pattern={1,2,1,3,4,1,2,3,1,4,2,1,3,2,4,1}
for y=0,9 do for x=0,15 do field:drawImage(grass[pattern[(x+y*3)%#pattern+1]],Point(x*19,y*19)) end end
field:drawImage(patches[1],Point(17,26));field:drawImage(patches[2],Point(115,27));field:drawImage(patches[3],Point(216,28))
field:drawImage(patches[2],Point(67,111));field:drawImage(patches[1],Point(180,107))
field:saveAs(PRE..'field-composite-1x.png');field:resize(912,570);field:saveAs(PRE..'field-composite-3x.png')
local native=Image{fromFile=PRE..'field-composite-1x.png'}
local hero_sheet=Image{fromFile=ROOT..'arenic-game/assets/characters/forager/forager.png'}
local hero=Image(19,19,ColorMode.RGB);hero:drawImage(hero_sheet,Point(0,0))
for _,position in ipairs({{37,49},{102,87},{160,52},{251,98}}) do native:drawImage(hero,Point(position[1],position[2])) end
native:saveAs(PRE..'hero-legibility-1x.png');native:resize(912,570);native:saveAs(PRE..'hero-legibility-3x.png')
write(BASE..'validation.json',validation)
print('Guild clearing ground: native19x19 grass x4, native76x76 patches x3, layered masters and atlases exported.')
