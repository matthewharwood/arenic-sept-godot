-- Native pixel authoring support. All palette literals are authored in OKLCH.
-- Rebuild only deliberately: the saved layered .aseprite is authoritative after hand edits.
local folder=assert(app.params.output,'Pass --script-param output=<this boss source directory>')..'/'
local N=114
local function readJson(path) local f=assert(io.open(path));local text=f:read('*a');f:close();return json.decode(text) end
local function writeJson(path,value) local f=assert(io.open(path,'w'));f:write(json.encode(value));f:close() end
local function rgba(t)
 local L,C,H=t[1],t[2],math.rad(t[3]);local a,b=C*math.cos(H),C*math.sin(H)
 local l=(L+.3963377774*a+.2158037573*b)^3;local m=(L-.1055613458*a-.0638541728*b)^3;local s=(L-.0894841775*a-1.291485548*b)^3
 local function cv(v) v=math.max(0,math.min(1,v));return math.floor(255*(v<=.0031308 and 12.92*v or 1.055*v^(1/2.4)-.055)+.5) end
 return Color{r=cv(4.0767416621*l-3.3077115913*m+.2309699292*s),g=cv(-1.2684380046*l+2.6097574011*m-.3413193965*s),b=cv(-.0041960863*l-.7034186147*m+1.707614701*s),a=t[4] or 255}
end
local C,palette={},nil
local function setPalette(rows)
 palette=Palette(#rows+1);palette:setColor(0,Color{r=0,g=0,b=0,a=0});local data={space='oklch',colors={}}
 for i,row in ipairs(rows) do local color=rgba(row[3]);palette:setColor(i,color);C[row[1]]=color.rgbaPixel;data.colors[i]={symbol=row[1],name=row[2],oklch=row[3]} end
 writeJson(folder..'palette.oklch.json',data)
end
local function image() return Image(N,N,ColorMode.RGB) end
local function px(im,x,y,c) x=math.floor(x+.5);y=math.floor(y+.5);assert(x>=0 and y>=0 and x<N and y<N,'Out of canvas '..x..','..y);im:drawPixel(x,y,type(c)=='string' and assert(C[c],c) or c) end
local function line(im,x0,y0,x1,y1,c,width)
 x0=math.floor(x0+.5);y0=math.floor(y0+.5);x1=math.floor(x1+.5);y1=math.floor(y1+.5)
 local dx=math.abs(x1-x0);local sx=x0<x1 and 1 or -1;local dy=-math.abs(y1-y0);local sy=y0<y1 and 1 or -1;local err=dx+dy
 while true do if width and width>1 then local r=math.floor(width/2);for yy=-r,r do for xx=-r,r do if xx*xx+yy*yy<=r*r+.5 then px(im,x0+xx,y0+yy,c) end end end else px(im,x0,y0,c) end;if x0==x1 and y0==y1 then break end;local e=2*err;if e>=dy then err=err+dy;x0=x0+sx end;if e<=dx then err=err+dx;y0=y0+sy end end
end
local function path(im,pts,c,width,closed)
 for i=1,#pts-1 do line(im,pts[i][1],pts[i][2],pts[i+1][1],pts[i+1][2],c,width) end
 if closed then line(im,pts[#pts][1],pts[#pts][2],pts[1][1],pts[1][2],c,width) end
end
local function poly(im,pts,c)
 local minx,miny,maxx,maxy=N,N,0,0;for _,p in ipairs(pts) do minx=math.min(minx,p[1]);maxx=math.max(maxx,p[1]);miny=math.min(miny,p[2]);maxy=math.max(maxy,p[2]) end
 for y=math.max(0,math.floor(miny)),math.min(N-1,math.ceil(maxy)) do for x=math.max(0,math.floor(minx)),math.min(N-1,math.ceil(maxx)) do
  local inside=false;local j=#pts
  for i=1,#pts do local a,b=pts[i],pts[j];if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then inside=not inside end;j=i end
  if inside then px(im,x,y,c) end
 end end
end
local function ellipse(im,cx,cy,rx,ry,c)
 for y=math.max(0,math.floor(cy-ry)),math.min(N-1,math.ceil(cy+ry)) do for x=math.max(0,math.floor(cx-rx)),math.min(N-1,math.ceil(cx+rx)) do if ((x-cx)/rx)^2+((y-cy)/ry)^2<=1 then px(im,x,y,c) end end end
end
local function ring(im,cx,cy,rx,ry,c,width,start,finish)
 local pts={};for j=0,64 do local a=(start or 0)+((finish or math.pi*2)-(start or 0))*j/64;pts[#pts+1]={cx+math.cos(a)*rx,cy+math.sin(a)*ry} end;path(im,pts,c,width)
end
local function stamp(im,x,y,rows)
 for r,row in ipairs(rows) do for k=1,#row do local c=row:sub(k,k);if C[c] then px(im,x+k-1,y+r-1,c) end end end
end
local function rotate(im,d)
 local out=image();for y=0,N-1 do for x=0,N-1 do local value=im:getPixel(x,y);if app.pixelColor.rgbaA(value)>0 then local xx,yy=x,y;for i=1,d do xx,yy=N-1-yy,xx end;out:drawPixel(xx,yy,value) end end end;return out
end
local function build(id,layers,groups)
 local s=Sprite(N,N,ColorMode.RGB);s:setPalette(palette);s.layers[1].name=layers[1];for i=2,#layers do local l=s:newLayer();l.name=layers[i] end
 local total=0;for _,g in ipairs(groups) do total=total+#g.poses*4 end;for f=2,total do s:newEmptyFrame(f) end
 local cursor=0;local summary={id=id,canvas={N,N},pivot={57,57},layers=layers,states={}}
 for _,g in ipairs(groups) do
  local count=#g.poses;local north={};local ms=0;for f,p in ipairs(g.poses) do north[f]=g.draw(p);ms=ms+p.ms end
  summary.states[#summary.states+1]={id=g.id,frames_per_direction=count,duration_ms=ms}
  for d,dir in ipairs({'n','e','s','w'}) do
   local first=cursor+1
   for f,p in ipairs(g.poses) do cursor=cursor+1;s.frames[cursor].duration=p.ms/1000;for l,im in ipairs(north[f]) do s:newCel(s.layers[l],cursor,rotate(im,d-1),Point(0,0)) end end
   local t=s:newTag(first,cursor);t.name=g.id..'_'..dir;t.repeats=0;t.color=palette:getColor(2)
   if g.id=='cycle' then t=s:newTag(first,cursor);t.name='idle_'..dir;t.repeats=0;t.color=palette:getColor(3) end
  end
 end
 local slice=s:newSlice(Rectangle(0,0,N,N));slice.name='frame';slice.pivot=Point(57,57)
 s.data=json.encode({kind='boss',id=id,projection='strict overhead orthographic',pixels_per_tile=19,footprint_tiles={6,6},pivot={57,57},idle_only=true})
 s:saveAs(folder..id..'.aseprite');s:close();writeJson(folder..'native-summary.json',summary);print(id..': saved '..total..' frames in '..#groups..' states')
end
setPalette({
 {'o','deep ink',{.17,.015,280}},{'d','charcoal cloth',{.25,.025,285}},{'g','pine shadow',{.30,.035,169}},{'G','pine',{.42,.065,155}},{'m','moss plane',{.54,.07,144}},{'M','moss rim',{.65,.068,140}},
 {'v','violet fold',{.32,.06,305}},{'V','violet reflection',{.47,.095,306}},{'p','spectral glint',{.72,.12,299}},
 {'b','bow wood shadow',{.31,.055,62}},{'w','bow wood',{.48,.09,65}},{'W','bow wood light',{.64,.105,77}},
 {'a','antique gold shadow',{.52,.10,78}},{'A','antique gold',{.74,.115,86}},{'L','gold glint',{.91,.075,95}},
 {'s','bone shadow',{.51,.045,80}},{'S','aged bone',{.76,.05,88}},{'H','pale bone',{.89,.045,97}},{'n','mask grain',{.64,.05,80}}
})
local radial={
 {31,34,39,37,38,34,37,34,35,31,34,32,39,33,42,35,40,34,37,31,34,30,39,32,41,36,36,33,36,31,34,30},
 {29,31,36,33,33,30,34,36,40,42,47,46,43,36,39,36,42,45,48,43,42,33,32,30,30,29,33,31,30,28,29,29},
 {39,36,44,40,44,41,46,42,40,39,44,38,43,39,42,38,42,43,46,41,45,42,44,39,39,40,45,40,44,40,41,39},
 {30,31,45,33,48,32,45,32,38,30,43,30,48,30,45,29,40,29,46,31,48,32,44,31,38,30,45,31,48,32,43,30},
 {34,31,38,43,44,34,40,46,45,34,35,41,46,36,39,43,43,34,37,44,48,36,38,45,44,33,36,42,46,35,38,42}
}
local ids={'quiet','sorrow','startled','wrath','elation'}
local function mask(im,kind,cx,cy,squash,breath)
 local widths={17,14,19,17,19};local heights={21,25,20,21,23};local rx=widths[kind]*squash;local ry=heights[kind]+breath
 local pts={{cx-rx*.65,cy-ry},{cx+rx*.55,cy-ry},{cx+rx,cy-ry*.45},{cx+rx*.85,cy+ry*.25},{cx+rx*.45,cy+ry*.8},{cx,cy+ry},{cx-rx*.55,cy+ry*.65},{cx-rx,cy-ry*.3}}
 poly(im,pts,'s');path(im,pts,'o',2,true)
 local inner={};for _,p in ipairs(pts) do inner[#inner+1]={cx+(p[1]-cx)*.84,cy+(p[2]-cy)*.90} end;poly(im,inner,'S')
 poly(im,{{cx-rx*.6,cy-ry*.8},{cx-rx*.1,cy-ry*.92},{cx-rx*.1,cy+ry*.55},{cx-rx*.5,cy+ry*.15}},'H')
 local ex=rx*.44;local ey=cy-5
 if kind==1 then
  line(im,cx-ex-3*squash,ey,cx-ex+3*squash,ey+1,'o',2);line(im,cx+ex-3*squash,ey+1,cx+ex+3*squash,ey,'o',2);ellipse(im,cx,cy+10,2*squash,2,'o')
 elseif kind==2 then
  path(im,{{cx-ex-4*squash,ey-3},{cx-ex,ey},{cx-ex+3*squash,ey+1}},'o',2);path(im,{{cx+ex-3*squash,ey+1},{cx+ex,ey},{cx+ex+4*squash,ey-3}},'o',2)
  path(im,{{cx-5*squash,cy+14},{cx,cy+9},{cx+5*squash,cy+14}},'o',2)
 elseif kind==3 then ellipse(im,cx-ex,ey,3*squash,6,'o');ellipse(im,cx+ex,ey,3*squash,6,'o');ellipse(im,cx,cy+11,4*squash,7,'o')
 elseif kind==4 then
  poly(im,{{cx-ex-5*squash,ey-5},{cx-ex+4*squash,ey},{cx-ex+2*squash,ey+4},{cx-ex-3*squash,ey+3}},'o');poly(im,{{cx+ex+5*squash,ey-5},{cx+ex-4*squash,ey},{cx+ex-2*squash,ey+4},{cx+ex+3*squash,ey+3}},'o')
  path(im,{{cx-6*squash,cy+14},{cx,cy+8},{cx+6*squash,cy+14}},'o',3)
 else
  ring(im,cx-ex,ey,4*squash,4,'o',2,math.pi,math.pi*2);ring(im,cx+ex,ey,4*squash,4,'o',2,math.pi,math.pi*2)
  poly(im,{{cx-8*squash,cy+6},{cx+8*squash,cy+6},{cx+5*squash,cy+16},{cx,cy+19},{cx-5*squash,cy+16}},'o');line(im,cx-5*squash,cy+7,cx+5*squash,cy+7,'H')
 end
 -- Hairline wood/bone cracks follow the crown instead of front-facing anatomy.
 for k=-2,2 do local xx=cx+k*rx*.29;path(im,{{xx,cy-ry+4},{xx-1,cy-ry+8},{xx,cy-ry+11}},'n') end
 path(im,{{cx+rx*.75,cy+3},{cx+rx*.57,cy+7},{cx+rx*.55,cy+14}},'n')
end
local function draw(p)
 local layers={image(),image(),image(),image(),image(),image()};local a,b,t=p.a,p.b or p.a,p.t or 0
 local wave=math.sin(p.phase or 0);local pts={};local radii={}
 for j=1,32 do local an=(j-1)*math.pi/16;local r=radial[a][j]*(1-t)+radial[b][j]*t+wave*.7;local turn=t*.07;radii[j]=r;pts[j]={56.5+math.cos(an+turn)*r,58+math.sin(an+turn)*r} end
 poly(layers[1],pts,'d');path(layers[1],pts,'o',3,true)
 -- Radial cloth panels curl around a single overhead core.
 for j=1,16 do
  local k=j*2-1;local p1,p2,p3=pts[k],pts[k%32+1],pts[(k+1)%32+1]
  local inner={56+math.cos(j*1.17)*10,58+math.sin(j*.9)*10}
  poly(layers[2],{inner,p1,p2,p3},j%3==0 and 'v' or j%2==0 and 'g' or 'G')
  local mid={(p1[1]+p2[1])/2,(p1[2]+p2[2])/2};local bend={inner[1]*.45+mid[1]*.55+math.sin(j)*3,inner[2]*.45+mid[2]*.55}
  path(layers[2],{inner,bend,mid},j%3==0 and 'V' or 'm',2)
  path(layers[2],{{inner[1]+2,inner[2]+3},{bend[1]+2,bend[2]+2},{mid[1]-1,mid[2]+1}},'d')
  if j%4==0 then path(layers[3],{bend,mid},'a',3);path(layers[3],{{bend[1]-1,bend[2]-1},{mid[1]-1,mid[2]-1}},'A') end
 end
 -- Side facets remain attached to the hood, opening and closing like one organism.
 local folding=math.sin(t*math.pi);local left=22+folding*9;local right=86-folding*8
 ellipse(layers[3],left,57,9-folding*4,15,'o');ellipse(layers[3],left,56,7-folding*3,12,'s');path(layers[3],{{left-3,51},{left+2,56},{left-2,59}},'d',2)
 ellipse(layers[3],right,60,7-folding*3,13,'o');ellipse(layers[3],right,59,5-folding*2,10,'S');line(layers[3],right-2,55,right+1,60,'d',2)
 local active=t<.5 and a or b;local squash=1-folding*.72
 ellipse(layers[4],56.5,61,25-10*folding,23,'o');ellipse(layers[4],56,60,23-10*folding,21,'G')
 -- Crown planes remain visible behind a flat, foreshortened folding mask canopy.
 poly(layers[4],{{39+folding*7,54},{55,43},{73-folding*7,56},{67,77},{53,83},{43,74}},'g')
 path(layers[4],{{55,43},{54,64},{53,81}},'m',2)
 path(layers[4],{{39+folding*7,54},{47,67},{43,74}},'M')
 path(layers[4],{{73-folding*7,56},{63,66},{67,77}},'v',3)
 ring(layers[4],56,59,22-9*folding,20,'a',2,0,math.pi)
 local canopy=image();mask(canopy,active,56,57,squash,wave*.6)
 for y=29,88 do for x=33,79 do local value=canopy:getPixel(x,y);if app.pixelColor.rgbaA(value)>0 then px(layers[4],x,48+(y-57)*.55,value) end end end
 -- Dormant organic recurve sits across the north of the creature; no drawn arrow.
 local bow={{13,34},{18,26},{26,21},{38,20},{49,26},{56,28},{64,26},{76,20},{87,21},{96,26},{101,34}}
 path(layers[5],bow,'o',7);path(layers[5],bow,'w',5);path(layers[5],bow,'A',2)
 path(layers[5],{{13,34},{33,40},{56,43},{81,40},{101,34}},'v',2);path(layers[5],{{13,34},{56,43},{101,34}},'p')
 for _,x in ipairs({23,88}) do poly(layers[5],{{x,24},{x+3,18},{x+5,24},{x+2,29}},'A');px(layers[5],x+3,21,'L') end
 ellipse(layers[5],42,35,4,3,'o');ellipse(layers[5],42,34,3,2,'S');ellipse(layers[5],74,35,4,3,'o');ellipse(layers[5],74,34,3,2,'S')
 for j=1,6 do local an=j*.8+(p.phase or 0)*.05;local xx=56+math.cos(an)*34;local yy=58+math.sin(an)*34;line(layers[6],xx,yy,xx+1,yy+2,j%2==0 and 'm' or 'V') end
 return layers
end
local groups={};local cycle={id='cycle',draw=draw,poses={}}
for k=1,5 do
 for f=1,4 do cycle.poses[#cycle.poses+1]={a=k,phase=(f-1)*math.pi/2,ms=350} end
 for f=1,4 do cycle.poses[#cycle.poses+1]={a=k,b=k%5+1,t=f/5,phase=f*.7,ms=200} end
end
groups[1]=cycle
for k,id in ipairs(ids) do local g={id=id,draw=draw,poses={}};for f=1,8 do g.poses[#g.poses+1]={a=k,phase=(f-1)*math.pi/4,ms=220} end;groups[#groups+1]=g end
build('hunter',{'01 Cloak silhouette','02 Folded mantle planes','03 Facets and gold edging','04 Upward mask and hood','05 Organic bow and hands','06 Spectral stitching'},groups)
