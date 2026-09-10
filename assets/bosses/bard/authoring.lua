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
 {'o','deep fur ink',{.16,.018,44}},{'d','charcoal brown',{.24,.025,48}},{'b','deep umber',{.31,.035,51}},{'B','mastiff brown',{.40,.055,57}},{'c','copper fur',{.51,.075,58}},{'C','copper ridge',{.62,.07,65}},{'h','fur glint',{.70,.055,73}},
 {'v','plum collar shadow',{.26,.065,326}},{'V','plum collar',{.39,.09,329}},{'p','collar stitching',{.55,.10,337}},
 {'a','gold bell shade',{.39,.08,70}},{'A','gold bell',{.65,.13,82}},{'L','gold bell glint',{.87,.10,91}},{'n','nose ridge',{.33,.016,272}},{'t','ivory nail',{.77,.04,89}}
})
local function fur(im,pts,color) poly(im,pts,color);path(im,{pts[1],pts[2],pts[3]},'d') end
local function draw(p)
 local ls={image(),image(),image(),image(),image(),image()};local w=math.sin(p.phase);local breath=w*.8
 -- Four splayed paws are partially occluded by the shoulders and haunches.
 for side=-1,1,2 do
  local x=56+side*29;local front={{x-side*8,44},{x+side*5,42},{x+side*11,51},{x+side*9,63},{x+side*2,65},{x-side*5,57}}
  poly(ls[1],front,'b');path(ls[1],front,'o',3,true);path(ls[1],{{x+side*4,53},{x+side*6,58},{x+side*5,62}},'c',2)
  for j=0,2 do line(ls[1],x+side*(2+j*3),62-j,x+side*(2+j*3),64-j,'t') end
  local xx=56+side*22;poly(ls[1],{{xx-side*9,76},{xx+side*7,77},{xx+side*10,91},{xx+side*5,98},{xx-side*3,98},{xx-side*7,91}},'b')
  path(ls[1],{{xx+side*7,78},{xx+side*10,91},{xx+side*5,98},{xx-side*3,98}},'o',3);line(ls[1],xx,91,xx+side*2,96,'c',2)
  for j=0,2 do line(ls[1],xx+side*(j*2-1),96,xx+side*(j*2-1),98,'t') end
 end
 -- Thick curled tail: a continuous back-facing loop, not a humanoid appendage.
 local tx=math.sin(p.phase-.6)*1.7;local tail={{59,86},{64,96},{77,100},{87+tx,95},{91+tx,86},{86+tx,80},{79+tx,81},{77+tx,86}}
 path(ls[2],tail,'o',15);path(ls[2],tail,'b',11);path(ls[2],tail,'c',7);path(ls[2],tail,'C',3);path(ls[2],{{65,98},{76,102},{87+tx,97}},'b',2)
 -- Broad dorsal silhouette, heavy shoulders and a narrower haunch.
 local body={{37-breath,39},{26-breath,49},{25-breath,66},{31-breath,82},{40,93},{52,96},{64,94},{76+breath,86},{84+breath,72},{86+breath,55},{79+breath,44},{66,38}}
 poly(ls[3],body,'b');path(ls[3],body,'o',3,true)
 poly(ls[3],{{36,45},{45,39},{61,39},{77,47},{78,60},{73,71},{72,84},{60,91},{47,89},{38,78},{34,63}},'B')
 poly(ls[3],{{40,49},{49,42},{60,43},{67,54},{63,70},{66,81},{57,89},{47,84},{42,68}},'c')
 path(ls[3],{{50,43},{48,55},{54,69},{52,82},{56,88}},'C',3)
 path(ls[3],{{62,44},{68,55},{66,66},{73,78}},'b',3)
 local tufts={{{31,54},{35,50},{38,58},{35,65},{33,59}},{{30,69},{34,65},{39,74},{37,81},{34,75}},{{40,82},{44,78},{48,86},{48,90},{44,88}},{{72,80},{75,73},{79,71},{78,80},{74,87}},{{78,55},{80,50},{83,58},{82,66},{79,63}},{{40,48},{45,43},{47,49},{43,59},{41,55}},{{56,65},{58,59},{62,63},{61,73},{58,77}}}
 for i,q in ipairs(tufts) do fur(ls[3],q,i%3==0 and 'C' or i%2==0 and 'B' or 'c') end
 -- The nape and skull crown are seen from above, with the muzzle pointing north.
 ellipse(ls[4],56,31,24+breath,20,'o');ellipse(ls[4],56,31,22+breath,18,'b')
 poly(ls[4],{{44,15},{54,11},{64,14},{72,24},{69,37},{64,43},{48,42},{40,34},{40,25}},'B')
 poly(ls[4],{{46,17},{54,13},{61,17},{60,26},{65,34},{61,41},{51,41},{47,31}},'c')
 path(ls[4],{{54,15},{52,24},{55,32},{53,37}},'C',3)
 -- Floppy ears overlap the sides of the collar and swing independently of breathing.
 local ew=math.sin(p.phase+.7)*1.4
 for side=-1,1,2 do local ex=56+side*21;local ey=27+ew*side;local pts={{ex-side*5,ey-7},{ex+side*6,ey-4},{ex+side*11,ey+6},{ex+side*9,ey+21},{ex+side*2,ey+27},{ex-side*4,ey+17},{ex-side*7,ey+5}}
  poly(ls[4],pts,'o');local inn={};for _,q in ipairs(pts) do inn[#inn+1]={ex+(q[1]-ex)*.79,ey+6+(q[2]-ey-6)*.87} end;poly(ls[4],inn,'b')
  path(ls[4],{{ex+side*3,ey+2},{ex+side*5,ey+11},{ex+side*3,ey+20}},'c',3);path(ls[4],{{ex,ey+3},{ex+side*2,ey+12},{ex-side*1,ey+18}},'d',2)
 end
 -- Short heavy mastiff muzzle: dark dorsal nasal plane with side jowl folds.
 poly(ls[5],{{45,21},{46,12},{51,7},{61,7},{66,13},{67,21},{62,27},{50,27}},'o')
 poly(ls[5],{{48,19},{49,12},{53,9},{60,9},{63,14},{63,20},{59,23},{51,23}},'d')
 ellipse(ls[5],56,10,7,4,'o');line(ls[5],51,8,60,8,'n',2);px(ls[5],52,10,'d');px(ls[5],60,10,'d')
 path(ls[5],{{45,21},{48,25},{51,26}},'C');path(ls[5],{{67,21},{64,25},{61,26}},'B')
 path(ls[5],{{42,23},{46,22},{47,24}},'d',2);path(ls[5],{{66,24},{68,22},{71,23}},'d',2)
 -- Purple resonance collar crosses the nape behind the overhead head.
 path(ls[6],{{35,41},{40,47},{49,51},{62,51},{73,47},{79,41}},'o',9)
 path(ls[6],{{35,41},{40,47},{49,51},{62,51},{73,47},{79,41}},'V',7)
 path(ls[6],{{34,39},{40,45},{49,48},{62,48},{73,44},{79,39}},'A',2)
 path(ls[6],{{37,44},{42,49},{50,54},{62,54},{72,50},{77,44}},'a',2)
 for _,q in ipairs({{40,46},{56,52},{73,46}}) do local yy=q[2]+math.sin(p.phase+.2)*.6;ellipse(ls[6],q[1],yy+3,5,5,'o');ellipse(ls[6],q[1],yy+2,4,4,'A');ring(ls[6],q[1]-1,yy+1,2,2,'L',1,math.pi,math.pi*1.9);line(ls[6],q[1]-2,yy+4,q[1]+2,yy+4,'a');line(ls[6],q[1],yy+3,q[1],yy+5,'o') end
 for _,x in ipairs({47,65}) do poly(ls[6],{{x,48},{x+2,50},{x,52},{x-2,50}},'L') end
 return ls
end
local g={id='idle',draw=draw,poses={}};for f=1,12 do g.poses[#g.poses+1]={phase=(f-1)*math.pi/6,ms=180} end
build('bard',{'01 Four resting paws','02 Curled mastiff tail','03 Broad back and copper fur','04 Skull crown and floppy ears','05 Dorsal muzzle and nose','06 Plum collar and resonator bells'}, {g})
