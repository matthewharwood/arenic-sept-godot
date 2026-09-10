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
 {'o','storm ink',{.15,.025,280}},{'d','lower storm',{.22,.04,280}},{'v','violet shadow',{.30,.065,292}},{'V','violet side',{.40,.075,288}},
 {'b','indigo cloud',{.34,.06,267}},{'B','blue cloud',{.47,.06,263}},{'h','silver blue rim',{.61,.04,253}},{'H','silver highlight',{.76,.025,242}},
 {'a','lightning deep gold',{.48,.125,66}},{'A','lightning gold',{.77,.15,82}},{'L','lightning heart',{.96,.08,101}}
})
local lobes={{34,29,20,16},{61,24,21,15},{85,38,18,20},{88,64,18,19},{77,85,20,18},{52,90,23,16},{28,76,19,22},{24,51,17,20},{50,52,26,24},{69,63,23,24}}
local function draw(p)
 local ls={image(),image(),image(),image(),image()};local phase=p.phase
 -- A coiled funnel is viewed down its axis and curls underneath the cloud shelf.
 local spiral={};for j=0,50 do local an=j*.115+phase*.05;local rr=21-j*.25;spiral[#spiral+1]={72+math.cos(an)*rr,79+math.sin(an)*rr*.82} end
 path(ls[1],spiral,'o',15);path(ls[1],spiral,'v',11);path(ls[1],spiral,'B',5);path(ls[1],spiral,'h')
 for i,l in ipairs(lobes) do
  local xx=l[1]+math.sin(phase+i*.8)*1.1;local yy=l[2]+math.cos(phase+i*.6)*.9;local rx=l[3]+math.sin(phase+i)*.7;local ry=l[4]+math.cos(phase+i)*.8
  ellipse(ls[2],xx,yy,rx+2,ry+2,'o');ellipse(ls[2],xx,yy,rx,ry,i%3==0 and 'v' or 'b')
  ellipse(ls[3],xx-3,yy-3,rx*.81,ry*.78,i%3==0 and 'B' or 'B')
  -- Broken stepped rims and inset curls give each lobe a sculpted upper surface.
  ring(ls[3],xx-2,yy-1,rx*.87,ry*.87,'h',2,math.pi*1.03,math.pi*1.61)
  ring(ls[3],xx-2,yy-1,rx*.87,ry*.87,'H',1,math.pi*1.24,math.pi*1.47)
  path(ls[3],{{xx+rx*.45,yy-ry*.25},{xx+rx*.67,yy+ry*.1},{xx+rx*.4,yy+ry*.41},{xx+rx*.09,yy+ry*.43}},'v',2)
  ring(ls[3],xx+2,yy+3,rx*.43,ry*.44,'b',2,math.pi*.05,math.pi*.70)
  ring(ls[3],xx-4,yy-4,rx*.36,ry*.33,'h',1,math.pi*1.12,math.pi*1.80)
 end
 -- One deep central vortex ties the lobe arrangement into a sentient storm.
 local pts={};for j=0,60 do local an=j*.145+phase*.045;local rr=20-j*.24;pts[#pts+1]={57+math.cos(an)*rr,57+math.sin(an)*rr*.82} end
 path(ls[4],pts,'d',7);path(ls[4],pts,'V',4);path(ls[4],pts,'B',2)
 -- Fissures run over the top surface rather than forming a frontal portrait face.
 local flick=math.sin(phase*2)>0;local fissures={{{34,38},{43,41},{45,45},{51,44},{48,50},{54,51}},{{73,37},{67,42},{70,46},{63,47},{62,53}},{{75,69},{67,68},{65,74},{59,73},{62,80}}}
 for i,q in ipairs(fissures) do path(ls[5],q,'o',5);path(ls[5],q,'a',3);path(ls[5],q,'A',2);if flick or i==1 then path(ls[5],{q[1],q[2],q[3]},'L') end end
 path(ls[5],{{33,39},{35,34},{38,34}},'a');path(ls[5],{{68,68},{72,63},{77,63}},'A')
 -- Peripheral vapor fingers roll by one pixel while the anchor stays fixed.
 for j=1,6 do local a=j*1.04+phase*.035;local x=56+math.cos(a)*39;local y=56+math.sin(a)*38;path(ls[3],{{x-2,y-1},{x,y+2},{x+4,y+2}},j%2==0 and 'h' or 'V') end
 return ls
end
local g={id='idle',draw=draw,poses={}};for f=1,12 do g.poses[#g.poses+1]={phase=(f-1)*math.pi/6,ms=180} end
build('cardinal',{'01 Curled funnel beneath','02 Rolling cloud silhouette','03 Silver cloud crowns','04 Top vortex','05 Contained gold lightning'}, {g})
