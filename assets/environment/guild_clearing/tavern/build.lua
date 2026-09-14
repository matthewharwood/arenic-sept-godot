-- Native Aseprite authoring and saved-master export. Rebuild only explicitly.
-- aseprite -b --script-param root=/absolute/repo --script [this file]
-- Pass rebuild=true to replace the master from this original pixel score.
local root=assert(app.params.root,'root required')..'/'
local dir=root..'assets/environment/guild_clearing/tavern/'
local runtime=root..'arenic-game/assets/environment/guild_clearing/tavern/'
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
load_palette(root..'assets/environment/palette.oklch.json');load_palette(dir..'palette.oklch.json')
local W,H=247,171
local function dot(im,x,y,c)
 x=math.floor(x+.5);y=math.floor(y+.5);assert(x>=3 and x<W-3 and y>=3 and y<H-3,'transparent margin')
 im:drawPixel(x,y,type(c)=='string' and assert(colors[c],c) or c)
end
local function rect(im,x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(im,xx,yy,c) end end end
local function line(im,x,y,u,v,c)
 local n=math.max(math.abs(u-x),math.abs(v-y),1)
 for i=0,n do dot(im,x+(u-x)*i/n,y+(v-y)*i/n,c) end
end
local function box(im,x,y,w,h,c,edge) rect(im,x,y,w,h,edge or 'ink');rect(im,x+1,y+1,w-2,h-2,c) end
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
local function leaf(im,x,y,light)
 poly(im,{{x-3,y},{x-1,y-3},{x+2,y-2},{x+3,y},{x,y+2}},'greenDeep')
 line(im,x-1,y-1,x+1,y,'green');if light then dot(im,x-1,y-2,'greenLight') end
end
local glyphs={T={'111','010','010','010','010'},A={'010','101','111','101','101'},V={'101','101','101','101','010'},E={'111','100','110','100','111'},R={'110','101','110','101','101'},N={'101','111','111','111','101'}}
local function label(im,text,x,y)
 for i=1,#text do for yy,row in ipairs(glyphs[text:sub(i,i)]) do for xx=1,#row do if row:sub(xx,xx)=='1' then dot(im,x+(i-1)*4+xx-1,y+yy-1,'goldLight') end end end end
end
local master=dir..'tavern.aseprite'
if not app.fs.isFile(master) or app.params.rebuild=='true' then
 local sprite=Sprite(W,H,ColorMode.RGB)
 local names={'Attached ground shadow','Stone footing and porch','Timber walls and posts','Russet roof planes','Hand-laid shingles','Ridge and roof beams','Chimney and ironwork','Entrance and tavern sign','Attached vines and barrels'}
 sprite.layers[1].name=names[1];for i=2,#names do sprite:newLayer().name=names[i] end
 sprite.gridBounds=Rectangle(0,0,19,19)
 local palette=sprite.palettes[1];palette:resize(#swatches+1);palette:setColor(0,Color{r=0,g=0,b=0,a=0});for i,c in ipairs(swatches) do palette:setColor(i,c) end
 local ims={};for i=1,#names do ims[i]=Image(W,H,ColorMode.RGB) end
 local S,F,B,R,T,D,C,E,V=table.unpack(ims)
 local shadow=Color(colors.shadow);shadow.alpha=65
 poly(S,{{16,69},{45,28},{224,29},{234,47},{234,138},{174,146},{173,151},{101,151},{99,149},{15,151}},shadow.rgbaPixel)
 -- A broad main house, an attached west pantry and a centered south porch.
 box(F,39,25,184,117,'mortar');box(F,17,67,55,79,'mortar')
 for row=0,2 do for x=41+(row%2)*6,219,12 do
  local w=math.min(11,220-x);if w>0 then rect(F,x,130+row*4,w,3,(x+row)%3==0 and 'sandstoneLight' or 'sandstone') end
 end end
 for x=19,67,10 do box(F,x,138,9,6,'sandstone','mortar') end
 box(F,101,137,72,14,'mortar');box(F,104,138,66,11,'woodDeep')
 for x=106,166,6 do rect(F,x,140,5,8,'wood');line(F,x+1,141,x+1,146,'woodLight') end
 for y=148,149,2 do line(F,119,y,154,y,'sandstoneLight');line(F,119,y+1,154,y+1,'sandstone') end
 -- Thin wall strips are seen beneath the eaves, not a front-facing facade.
 rect(B,44,122,174,11,'plaster');rect(B,21,125,47,13,'plaster')
 for _,x in ipairs({44,76,108,158,187,214}) do rect(B,x,122,4,14,'woodDeep');line(B,x,122,x,133,'woodLight') end
 line(B,45,132,217,132,'wood');line(B,49,124,72,130,'wood');line(B,81,130,102,124,'wood')
 line(B,162,124,183,130,'wood');line(B,191,130,211,124,'wood')
 -- Smaller attached west roof sits below the main eave and breaks symmetry.
 box(R,11,59,67,77,'roofDeep');rect(R,13,61,31,72,'roofWarm');rect(R,44,61,32,72,'roofShade')
 for y=64,130,8 do line(T,14,y,42,y,'roofLight');line(T,46,y,74,y,'roof') end
 for x=17,71,9 do line(T,x,64,x,131,'roofDeep') end
 box(D,42,61,4,71,'woodDeep');line(D,42,62,42,130,'woodLight')
 -- Main pitched roof: long east-west ridge with warm and shaded planes.
 box(R,34,19,194,111,'roofDeep');rect(R,37,22,188,47,'roofWarm');rect(R,37,70,188,56,'roofShade')
 for row=0,5 do
  local y=23+row*8
  for x=38-(row%2)*6,224,13 do
   local a=math.max(38,x);local b=math.min(223,x+11)
   if b>=a then
    rect(T,a,y,b-a+1,7,((x+row*5)%4==0) and 'roof' or 'roofWarm')
    line(T,a,y+6,b,y+6,'roof');line(T,a,y,a+math.min(5,b-a),y,'roofLight')
    if b-a>5 then dot(T,b,y+5,'roofDeep') end
   end
  end
 end
 for row=0,6 do
  local y=72+row*8
  for x=38-(row%2)*6,224,13 do
   local a=math.max(38,x);local b=math.min(223,x+11)
   if b>=a then
    rect(T,a,y,b-a+1,7,(x+row)%4==0 and 'roofDeep' or 'roofShade')
    line(T,a,y,b,y,'roof');line(T,a,y+6,b,y+6,'roofDeep')
    if b-a>4 then line(T,a+1,y+1,a+3,y+1,'roofWarm') end
   end
  end
 end
 -- Exposed end caps, two weathered strap beams and the highlighted ridge cap.
 for _,x in ipairs({35,224}) do rect(D,x,20,3,109,'woodDeep');line(D,x,21,x,126,'wood') end
 for _,x in ipairs({79,171}) do rect(D,x,22,3,105,'roofDeep');line(D,x,23,x,125,'wood') end
 rect(D,37,19,188,3,'woodDeep');line(D,38,19,223,19,'woodLight')
 rect(D,37,126,188,4,'woodDeep');line(D,38,126,223,126,'wood')
 box(D,35,67,192,6,'woodDeep');line(D,37,67,224,67,'woodLight');line(D,37,69,224,69,'wood')
 for x=43,218,19 do dot(D,x,68,'goldDeep');dot(D,x,127,'steel') end
 -- Top-down stone chimney, dark flue and copper rain lip.
 box(C,185,28,24,30,'ink');rect(C,187,30,20,26,'stoneDeep')
 for row=0,3 do for x=188+(row%2)*4,204,8 do rect(C,x,31+row*6,math.min(7,205-x),5,'sandstone') end end
 box(C,183,26,28,23,'mortar');rect(C,185,28,24,19,'sandstoneLight');box(C,188,31,18,12,'stoneDeep');rect(C,191,34,12,6,'ink')
 line(C,186,28,207,28,'ivory');line(C,207,29,207,45,'sandstone');line(C,188,43,205,43,'goldDeep')
 -- Entrance threshold, slender porch rails and two warm lantern caps.
 box(E,119,129,37,10,'woodDeep');rect(E,122,130,31,6,'ink');line(E,122,136,152,136,'goldDeep');line(E,122,138,152,138,'woodLight')
 for _,x in ipairs({104,167}) do box(E,x,137,3,11,'woodDeep');line(E,x,138,x,145,'woodLight');box(E,x-1,138,5,4,'wood') end
 for _,x in ipairs({113,162}) do box(E,x,132,5,6,'ink');rect(E,x+1,133,3,3,'gold');dot(E,x+1,133,'ivory') end
 -- Sign hangs directly from the east porch bracket; small tankard icon.
 line(E,192,132,192,134,'woodDeep');line(E,193,132,193,134,'wood')
 box(E,166,134,45,14,'woodDeep');box(E,168,136,41,10,'wood')
 box(E,170,138,6,6,'goldDeep');rect(E,171,138,4,4,'gold');line(E,171,137,174,137,'ivory');line(E,176,138,178,138,'gold');line(E,178,138,178,141,'gold');line(E,176,142,178,142,'gold')
 label(E,'TAVERN',181,138)
 -- Barrels touch the pantry wall. Vines cling to the east gutter and north roof.
 for _,p in ipairs({{25,141},{42,141}}) do
  ellipse(V,p[1],p[2],7,9,'ink');ellipse(V,p[1],p[2]-1,6,8,'wood');ellipse(V,p[1],p[2]-3,5,5,'woodLight')
  line(V,p[1]-4,p[2]-3,p[1]+4,p[2]-3,'wood');line(V,p[1]-5,p[2]+3,p[1]+5,p[2]+3,'steel');line(V,p[1]-5,p[2]-7,p[1]+5,p[2]-7,'steel')
  dot(V,p[1],p[2]-4,'woodDeep')
 end
 line(V,225,47,228,113,'greenDeep');line(V,227,79,222,94,'greenDeep')
 for i=0,8 do leaf(V,226+(i%2)*3,49+i*7,i%3==0) end
 for _,p in ipairs({{222,86},{220,93},{224,103},{225,115},{217,22},{210,23},{204,24}}) do leaf(V,p[1],p[2],true) end
 for i,im in ipairs(ims) do sprite:newCel(sprite.layers[i],1,im,Point(0,0)) end
 local tag=sprite:newTag(1,1);tag.name='tavern'
 local slice=sprite:newSlice(Rectangle(0,0,W,H));slice.name='frame';slice.pivot=Point(123,85)
 sprite.data=json.encode({projection='true overhead orthographic',pixels_per_tile=19,porch_anchor={136,150},single_building=true})
 sprite:saveAs(master);sprite:close()
end
local sprite=assert(app.open(master));assert(sprite.width==W and sprite.height==H and #sprite.frames==1)
local image=Image(W,H,ColorMode.RGB);image:drawSprite(sprite,1)
local bounds={W,H,0,0};local count=0
for it in image:pixels() do if app.pixelColor.rgbaA(it())>0 then
 assert(it.x>=3 and it.x<W-3 and it.y>=3 and it.y<H-3,'export lost margin')
 bounds[1]=math.min(bounds[1],it.x);bounds[2]=math.min(bounds[2],it.y);bounds[3]=math.max(bounds[3],it.x);bounds[4]=math.max(bounds[4],it.y);count=count+1
end end
image:saveAs(runtime..'tavern.png');image:saveAs(dir..'previews/tavern.png');image:resize(W*4,H*4);image:saveAs(dir..'previews/tavern-4x.png')
local metadata={source='assets/environment/guild_clearing/tavern/tavern.aseprite',canvas={W,H},pivot={123,85},porch_anchor={136,150},pixels_per_tile=19,alpha_bounds=bounds,nontransparent_pixels=count,frames=1,layers=#sprite.layers,nearest=true,trimmed=false}
write(runtime..'tavern.json',json.encode(metadata));write(dir..'validation.json',json.encode(metadata))
if not app.fs.isFile(runtime..'tavern.png.import') then write(runtime..'tavern.png.import','[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\nmipmaps/generate=false\ndetect_3d/compress_to=0\nprocess/fix_alpha_border=false\n') end
sprite:close();print('Tavern exported: '..json.encode(metadata))
