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
 {'o','deep ink',{.16,.025,280}},{'v','gel violet shadow',{.28,.08,299}},{'V','gel violet',{.41,.12,303}},{'p','violet inner reflection',{.57,.13,310}},
 {'d','deep emerald',{.28,.07,169}},{'g','emerald',{.43,.13,156}},{'G','emerald upper surface',{.58,.155,150}},{'h','gel edge',{.72,.14,147}},{'H','liquid glint',{.91,.04,150}},
 {'s','bone shadow',{.51,.075,144}},{'b','submerged bone',{.70,.08,140}},{'B','bone crown',{.84,.065,116}},
 {'a','brass shadow',{.39,.075,73}},{'A','brass',{.65,.13,82}},{'L','brass highlight',{.86,.10,91}},{'c','cork',{.49,.075,55}},{'C','cork crown',{.68,.10,67}}
})
local names={'bomb','skull','potion'}
-- Matched polar boundaries keep the gel connected throughout each shape change.
local shapes={
 {39,40,42,40,41,40,44,42,39,40,43,42,40,43,41,39,40,42,40,41,43,41,40,41,39,37,35,34,34,35,36,38},
 {40,42,43,44,41,40,42,40,37,38,40,42,42,44,42,40,38,39,41,40,36,29,31,35,39,36,30,29,35,37,40,41},
 {40,42,43,43,40,42,41,43,40,41,43,41,42,40,43,41,40,36,32,28,24,22,25,38,44,38,25,22,24,28,32,36}
}
local function draw(p)
 local ls={image(),image(),image(),image(),image(),image()};local t=p.t or 0;local a,b=p.a,p.b or p.a;local wave=math.sin(p.phase);local wt={0,0,0};wt[a]=1-t;wt[b]=wt[b]+t
 local pts={};for j=1,32 do local an=(j-1)*math.pi/16;local r=shapes[a][j]*(1-t)+shapes[b][j]*t+math.sin(an*3+p.phase)*1.15;pts[j]={56.5+math.cos(an)*r,58+math.sin(an)*r} end
 poly(ls[1],pts,'v');path(ls[1],pts,'o',3,true)
 -- Dark purple inclusions beneath the emerald dome retain the portrait's two-tone gel.
 for y=13,104 do for x=10,104 do if app.pixelColor.rgbaA(ls[1]:getPixel(x,y))>0 and ls[1]:getPixel(x,y)~=C.o then
  local d=((x-51)/39)^2+((y-52)/40)^2
  local c=d<.53 and 'G' or d<.84 and 'g' or 'd'
  if x>63+math.sin(y*.095+p.phase*.18)*8 and y>43 then c=d<.55 and 'V' or 'v' end
  if x<48 and y<46 and d>.62 and d<.88 then c='h' end
  px(ls[2],x,y,c)
 end end end
 -- Surface folds stretch with the current contour, never detaching as particles.
 for j=1,7 do local k=j*4;local edge=pts[k];local inner={56+(edge[1]-56)*.72,58+(edge[2]-58)*.72};path(ls[2],{inner,{(inner[1]+edge[1])/2-2,(inner[2]+edge[2])/2},edge},j%2==0 and 'V' or 'g',2) end
 local skull=wt[2];local cx=53+wave;local cy=54-6*skull;local rx=13+11*skull;local ry=15+13*skull
 -- Dorsal cranium and northward jaw: the bone is seen through the upper gel surface.
 local bone={{cx-rx*.72,cy+ry},{cx+rx*.63,cy+ry},{cx+rx,cy+ry*.38},{cx+rx*.91,cy-ry*.35},{cx+rx*.50,cy-ry*.80},{cx+rx*.34,cy-ry-4},{cx-rx*.38,cy-ry-4},{cx-rx*.52,cy-ry*.78},{cx-rx*.96,cy-ry*.2},{cx-rx,cy+ry*.4}}
 poly(ls[3],bone,'s');path(ls[3],bone,'d',2,true)
 local crown={};for _,v in ipairs(bone) do crown[#crown+1]={cx+(v[1]-cx)*.82,cy+(v[2]-cy)*.82} end;poly(ls[3],crown,'b')
 ellipse(ls[3],cx-3,cy+3,rx*.62,ry*.64,'B');path(ls[3],{{cx-1,cy+ry*.8},{cx+2,cy+ry*.45},{cx-2,cy+ry*.10},{cx+1,cy-ry*.25}},'s')
 -- Foreshortened sockets sit at the front edge, not a portrait-facing face.
 ellipse(ls[3],cx-rx*.43,cy-ry*.48,rx*.21,3+skull,'d');ellipse(ls[3],cx+rx*.43,cy-ry*.48,rx*.21,3+skull,'d')
 poly(ls[3],{{cx,cy-ry*.69},{cx-3,cy-ry*.90},{cx+3,cy-ry*.90}},'d')
 for j=-2,2 do line(ls[3],cx+j*3,cy-ry-1,cx+j*3,cy-ry+3,'s') end
 -- Gel veils visibly cross the embedded skull.
 path(ls[4],{{cx-rx+2,cy+ry*.3},{cx-5,cy+ry*.5},{cx+rx-2,cy+ry*.25}},'G',3)
 path(ls[4],{{cx-rx+4,cy+ry*.38},{cx-6,cy+ry*.58},{cx+rx-4,cy+ry*.33}},'h')
 for j=1,8 do local an=j*.86;local rr=25+(j%3)*5;local xx=56+math.cos(an)*rr;local yy=58+math.sin(an)*rr+math.sin(p.phase+j)*1.5;local r=2+(j%3)
  ellipse(ls[4],xx,yy,r,r,'d');ring(ls[4],xx,yy,r-1,r-1,j%2==0 and 'p' or 'h',1,math.pi,math.pi*1.9);px(ls[4],xx-1,yy-1,'H')
 end
 -- The original bottle fitting is part of the creature, rotating toward its narrowed neck.
 local necky=33-15*wt[3];local neckx=72-15*wt[3]-8*wt[2];local nr=9+2*wt[1]
 ellipse(ls[5],neckx,necky,nr+2,8,'o');ellipse(ls[5],neckx,necky,nr,6,'a');ring(ls[5],neckx,necky-1,nr-1,5,'A',3);ring(ls[5],neckx-1,necky-2,nr-2,3,'L',1,math.pi,math.pi*1.9)
 ellipse(ls[5],neckx,necky-1,nr-4,3,'c');line(ls[5],neckx-3,necky-2,neckx+3,necky-2,'C',2)
 for _,dx in ipairs({-6,6}) do px(ls[5],neckx+dx,necky+3,'L') end
 -- Liquid fuse curls back over the body so the six-cell silhouette stays contained.
 local fuse={{neckx,necky},{neckx-4,necky-8},{neckx-13,necky-9},{neckx-16,necky-4},{neckx-12,necky+1}};for _,v in ipairs(fuse) do v[1]=v[1]+wave*.8 end
 path(ls[6],fuse,'v',5);path(ls[6],fuse,'G',3);path(ls[6],fuse,'h')
 path(ls[4],{{28,42+wave},{27,48+wave},{29,53+wave}},'h',3);line(ls[4],30,38+wave,33,35+wave,'H',2)
 for _,q in ipairs({{39,81},{80,67},{76,84}}) do poly(ls[5],{{q[1]-3,q[2]},{q[1],q[2]-3},{q[1]+3,q[2]},{q[1],q[2]+2}},'a');line(ls[5],q[1]-2,q[2],q[1],q[2]-2,'A') end
 -- Bubbles and gloss stay trapped within the gel even as flask shoulders narrow.
 for y=0,113 do for x=0,113 do if app.pixelColor.rgbaA(ls[1]:getPixel(x,y))==0 then ls[4]:drawPixel(x,y,0) end end end
 return ls
end
local groups={};local cycle={id='cycle',draw=draw,poses={}}
for k=1,3 do for f=1,4 do cycle.poses[#cycle.poses+1]={a=k,phase=(f-1)*math.pi/2,ms=400} end;for f=1,6 do cycle.poses[#cycle.poses+1]={a=k,b=k%3+1,t=f/7,phase=f*math.pi/3,ms=180} end end
groups[1]=cycle
for k,id in ipairs(names) do local g={id=id,draw=draw,poses={}};for f=1,8 do g.poses[#g.poses+1]={a=k,phase=(f-1)*math.pi/4,ms=220} end;groups[#groups+1]=g end
build('alchemist',{'01 Living gel contour','02 Emerald and violet body','03 Submerged dorsal skull','04 Bubbles and liquid veils','05 Brass neck and inclusions','06 Liquid fuse and surface glints'},groups)
