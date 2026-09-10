-- Native Aseprite authoring and export. Run from the repository root:
-- aseprite --batch --script-param root=/absolute/repo --script assets/pipeline/build-arena-decorations.lua
-- Re-authoring is explicit: hand-edited .aseprite masters are authoritative after creation.
-- Pass export_only=true to preserve native edits and rebuild only the atlas/previews/readback.
local ROOT=(app.params.root or app.fs.currentPath)..app.fs.pathSeparator
local BASE=ROOT..'assets/environment/'
local OUT=ROOT..'arenic-game/assets/environment/'
local W=76
local file=assert(io.open(BASE..'palette.oklch.json','r'))
local spec=json.decode(file:read('*a'));file:close()
local C={}
local function convert(L,ch,hue,alpha)
 local a=ch*math.cos(hue*math.pi/180);local b=ch*math.sin(hue*math.pi/180)
 local x=(L+.3963377774*a+.2158037573*b)^3
 local y=(L-.1055613458*a-.0638541728*b)^3
 local z=(L-.0894841775*a-1.291485548*b)^3
 local function enc(v)
  v=v<=.0031308 and 12.92*v or 1.055*v^(1/2.4)-.055
  return math.floor(math.max(0,math.min(1,v))*255+.5)
 end
 return Color{r=enc(4.0767416621*x-3.3077115913*y+.2309699292*z),g=enc(-1.2684380046*x+2.6097574011*y-.3413193965*z),b=enc(-.0041960863*x-.7034186147*y+1.707614701*z),a=alpha or 255}
end
local palette=Palette(#spec.colors+4)
palette:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,v in ipairs(spec.colors) do
 local col=convert(table.unpack(v.oklch));C[v.id]=col.rgbaPixel;palette:setColor(i,col)
end
local shadowColor=convert(.14,.02,275,90).rgbaPixel
local function dot(im,x,y,c)
 x=math.floor(x+.5);y=math.floor(y+.5)
 if x>=4 and y>=4 and x<=70 and y<=70 then im:drawPixel(x,y,type(c)=='number' and c or assert(C[c],c)) end
end
local function rect(im,x,y,w,h,c)
 for yy=y,y+h-1 do for xx=x,x+w-1 do dot(im,xx,yy,c) end end
end
local function ellipse(im,cx,cy,rx,ry,c)
 for y=math.floor(cy-ry),math.ceil(cy+ry) do
  for x=math.floor(cx-rx),math.ceil(cx+rx) do
   if ((x-cx)/rx)^2+((y-cy)/ry)^2<=1 then dot(im,x,y,c) end
  end
 end
end
local function line(im,x0,y0,x1,y1,c,w)
 x0=math.floor(x0+.5);y0=math.floor(y0+.5);x1=math.floor(x1+.5);y1=math.floor(y1+.5)
 local dx,dy=math.abs(x1-x0),-math.abs(y1-y0)
 local sx=x0<x1 and 1 or -1;local sy=y0<y1 and 1 or -1;local e=dx+dy
 while true do
  if w and w>1 then ellipse(im,x0,y0,(w-1)/2,(w-1)/2,c) else dot(im,x0,y0,c) end
  if x0==x1 and y0==y1 then break end
  local e2=2*e;if e2>=dy then e=e+dy;x0=x0+sx end;if e2<=dx then e=e+dx;y0=y0+sy end
 end
end
local function path(im,p,c,w)
 for i=1,#p-1 do line(im,p[i][1],p[i][2],p[i+1][1],p[i+1][2],c,w) end
end
local function poly(im,p,c,edge,w)
 local low,high=75,0
 for _,q in ipairs(p) do low=math.min(low,q[2]);high=math.max(high,q[2]) end
 for y=math.floor(low),math.ceil(high) do
  local xs={};local j=#p
  for i=1,#p do
   local a,b=p[i],p[j]
   if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then xs[#xs+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2]) end
   j=i
  end
  table.sort(xs)
  for i=1,#xs-1,2 do for x=math.ceil(xs[i]),math.floor(xs[i+1]) do dot(im,x,y,c) end end
 end
 if edge then for i=1,#p do local a,b=p[i],p[i%#p+1];line(im,a[1],a[2],b[1],b[2],edge,w or 1) end end
end
local function box(im,x,y,w,h,c,edge)
 rect(im,x,y,w,h,edge or 'ink');rect(im,x+1,y+1,w-2,h-2,c)
end
local function ring(im,cx,cy,r,fill,edge)
 ellipse(im,cx,cy,r,r,edge or 'ink');ellipse(im,cx,cy,r-1,r-1,fill)
end
local function cross(im,x,y,c)
 line(im,x-2,y,x+2,y,c);line(im,x,y-2,x,y+2,c)
end
local function shifted(points,dx,dy)
 local out={};for i,p in ipairs(points) do out[i]={p[1]+dx,p[2]+dy} end;return out
end
local S,B,D,H
local draw={}

-- Labyrinth: a broken canopy, roof beams seen directly from above, and a tiled lantern roof.
function draw.sakura()
 path(B,{{35,62},{38,47},{30,34},{19,28}},'ink',7)
 path(B,{{38,47},{47,29},{54,21}},'ink',6)
 path(D,{{35,60},{38,47},{30,34},{20,28}},'wood',3)
 path(D,{{38,47},{46,30},{54,21}},'woodLight',2)
 local clusters={{25,24,14},{43,19,12},{55,32,13},{42,43,14},{21,42,12}}
 for _,q in ipairs(clusters) do
  local x,y,r=table.unpack(q)
  poly(B,shifted({{-r,1},{-r+2,-6},{-7,-7},{-5,-r},{3,-r+1},{7,-8},{r-2,-5},{r,3},{r-4,5},{r-3,10},{5,r-1},{0,r-3},{-6,r},{-8,8},{-r,7}},x,y),'violetDeep','ink')
  poly(D,shifted({{-r+3,0},{-9,-5},{-4,-7},{-3,-r+3},{3,-r+4},{4,-5},{r-4,-3},{r-3,2},{5,4},{6,9},{0,8},{-5,10},{-6,5},{-10,4}},x,y),'violet')
  for _,p in ipairs({{-6,-3},{3,-6},{-1,3},{6,1}}) do
   local px,py=x+p[1],y+p[2]
   rect(H,px-2,py,5,2,'violetLight');rect(H,px,py-2,2,5,'blueLight');dot(H,px,py,'pinkLight')
  end
 end
 for _,p in ipairs({{17,59},{52,56},{61,48}}) do line(D,p[1],p[2],p[1]+2,p[2]-1,'violetLight') end
end
function draw.torii()
 -- Gate canopy in plan: top ridge, two tiled slopes, and square post caps at the eaves.
 for _,x in ipairs({18,49}) do box(B,x,27,11,26,'woodDeep');box(D,x+2,29,7,22,'wood','goldDeep') end
 poly(B,{{8,19},{17,23},{58,23},{67,19},{65,32},{67,49},{58,53},{17,53},{9,49},{11,32}},'blueDeep','ink',2)
 poly(D,{{10,22},{19,26},{56,26},{65,22},{61,35},{15,35}},'blue','ink')
 poly(D,{{15,37},{61,37},{64,47},{56,49},{20,49},{12,47}},'blueDeep','ink')
 for x=20,56,6 do line(H,x,27,x-2,33,'blueLight');line(D,x,39,x+2,47,'blue') end
 path(H,{{10,22},{19,25},{56,25},{65,22}},'blueLight',2)
 path(H,{{12,47},{20,50},{56,50},{64,47}},'blue',2)
 path(B,{{9,34},{18,36},{57,36},{66,34}},'ink',5)
 path(H,{{9,34},{18,35},{57,35},{66,34}},'gold',2)
 poly(H,{{37,29},{42,35},{37,41},{32,35}},'gold','woodDeep');dot(H,37,34,'goldLight')
 for _,x in ipairs({22,54}) do box(H,x-2,53,5,5,'wood','ink');dot(H,x-1,54,'goldLight') end
end
function draw.stone_lantern()
 -- The four hip-roof planes hide the shaft; only stone plinth corners remain visible.
 poly(B,{{18,20},{55,20},{59,25},{59,56},{53,61},{20,61},{15,56},{15,26}},'stoneDeep','ink',2)
 path(D,{{19,24},{54,24},{55,55},{21,56},{19,24}},'stone',3)
 poly(B,{{38,8},{67,37},{38,66},{9,37}},'stoneDeep','ink',2)
 poly(D,{{38,12},{62,37},{38,60},{14,37}},'stone','ink')
 poly(H,{{38,12},{38,36},{15,37}},'stoneLight')
 poly(H,{{38,13},{61,37},{39,37}},'blueLight')
 poly(D,{{15,38},{38,39},{38,60}},'stoneDeep')
 path(H,{{38,12},{62,37},{38,60},{14,37},{38,12}},'stoneLight')
 path(D,{{38,16},{38,57}},'stoneDeep');line(D,18,37,58,37,'stoneDeep')
 for _,r in ipairs({9,16}) do path(D,{{38,38-r},{38+r,38},{38,38+r},{38-r,38},{38,38-r}},'stoneDeep') end
 ring(H,38,37,7,'goldDeep','ink');ring(H,38,37,5,'gold','goldLight')
 poly(H,{{38,32},{42,37},{38,41},{34,37}},'stoneLight','ink');dot(H,37,35,'ivory')
end

-- Guild House: textiles, a scattered reading arrangement, and a masonry fire bowl.
function draw.coffee_rug()
 box(B,11,13,53,49,'woodDeep')
 box(D,13,15,49,45,'redDeep','goldDeep');box(D,16,18,43,39,'wood','gold')
 for x=14,60,4 do line(D,x,10,x,14,'paperShade');line(D,x,62,x,65,'paperShade') end
 path(D,{{19,37},{37,22},{56,37},{37,54},{19,37}},'gold',2)
 path(H,{{25,37},{37,28},{49,37},{37,48},{25,37}},'redDeep',2)
 for _,p in ipairs({{19,22},{54,22},{19,51},{54,51}}) do cross(H,p[1],p[2],'paperShade') end
 ellipse(B,39,38,11,10,'ink');ellipse(D,38,37,10,9,'ivory')
 ring(D,39,37,7,'woodDeep','gold');ring(H,39,37,5,'wood','paperShade')
 path(H,{{36,37},{38,35},{41,35},{43,37},{40,40},{38,39}},'paper')
 box(D,47,33,6,7,'goldDeep');box(H,49,35,3,3,'ivory')
 line(H,23,28,27,31,'goldLight')
end
function draw.books()
 -- Three closed volumes plus an open folio, all cover/page planes.
 box(B,13,14,27,33,'woodDeep');box(D,14,15,24,29,'redDeep','goldDeep')
 line(H,18,16,18,42,'gold');box(H,22,21,11,14,'red','gold');cross(H,27,28,'goldLight')
 box(B,36,19,26,34,'woodDeep');rect(D,38,21,21,30,'paperShade')
 for y=23,48,3 do line(H,39,y,58,y,'paper') end
 box(D,40,18,23,31,'tealDeep','ink');line(H,44,21,59,21,'gold');line(H,44,45,59,45,'gold')
 poly(B,{{12,47},{30,43},{38,46},{44,43},{64,47},{65,63},{43,59},{38,62},{31,59},{12,63}},'woodDeep','ink',2)
 poly(D,{{14,48},{30,45},{37,48},{37,59},{30,56},{14,60}},'paper','goldDeep')
 poly(D,{{39,48},{45,45},{62,49},{63,60},{45,56},{39,59}},'paperShade','goldDeep')
 for y=50,56,3 do line(H,17,y,30,y-2,'woodLight');line(H,45,y-2,59,y+1,'wood') end
 line(H,38,48,38,61,'gold');line(H,32,60,32,66,'red')
end
function draw.hearth()
 poly(B,{{18,15},{57,15},{65,24},{65,54},{56,63},{19,63},{11,55},{11,24}},'stoneDeep','ink',2)
 poly(D,{{20,19},{55,19},{61,25},{61,53},{54,59},{21,59},{15,53},{15,26}},'woodDeep','wood')
 for _,p in ipairs({{18,17,14,8},{35,16,18,9},{56,22,8,15},{55,43,9,13},{35,55,18,7},{19,53,13,9},{12,34,9,15},{13,22,11,9}}) do
  box(D,p[1],p[2],p[3],p[4],'stone','stoneDeep');line(H,p[1]+2,p[2]+2,p[1]+p[3]-3,p[2]+2,'stoneLight')
 end
 ellipse(B,38,39,18,16,'redDeep')
 path(D,{{25,49},{50,28}},'ink',8);path(D,{{26,48},{49,29}},'wood',5)
 path(D,{{24,31},{49,48}},'ink',8);path(D,{{25,32},{49,48}},'woodLight',4)
 poly(H,{{27,39},{31,28},{35,35},{40,24},{43,33},{49,30},{47,42},{42,49},{34,46}},'redLight','redDeep')
 poly(H,{{31,40},{35,33},{38,38},{41,30},{44,40},{41,46},{35,44}},'flame')
 poly(H,{{35,41},{38,36},{41,41},{39,45}},'flameHot')
end

-- Sanctum: closed shrine, candle crowns viewed overhead, and an inset gothic rose.
function draw.reliquary()
 poly(B,{{25,10},{51,10},{58,18},{58,58},{50,66},{25,66},{18,58},{18,18}},'goldDeep','ink',2)
 poly(D,{{27,14},{48,14},{54,21},{54,55},{47,62},{28,62},{22,55},{22,21}},'gold','woodDeep')
 poly(D,{{29,17},{46,17},{50,23},{50,53},{45,58},{30,58},{26,53},{26,23}},'redDeep','goldLight')
 line(H,37,20,37,54,'goldLight',3);line(H,29,30,45,30,'goldLight',3)
 poly(H,{{37,21},{41,27},{37,30},{33,27}},'ivory','goldDeep')
 poly(H,{{37,40},{42,45},{37,51},{32,45}},'gold','woodDeep');dot(H,36,44,'ivory')
 for _,p in ipairs({{26,20},{49,20},{26,56},{49,56}}) do ring(H,p[1],p[2],2,'goldLight','woodDeep') end
 line(H,23,26,23,51,'goldLight');line(H,29,15,46,15,'ivory')
 for _,y in ipairs({29,45}) do box(B,14,y,5,5,'gold','ink');box(B,58,y,5,5,'gold','ink') end
end
function draw.candles()
 poly(B,{{15,22},{59,22},{65,51},{58,58},{19,58},{11,50}},'goldDeep','ink',2)
 path(D,{{16,25},{57,25},{61,49},{56,54},{21,54},{15,49},{16,25}},'gold',2)
 for _,q in ipairs({{24,37,8},{39,29,9},{53,40,7},{35,48,7}}) do
  local x,y,r=table.unpack(q)
  ring(D,x,y,r+2,'gold','ink');ring(D,x,y,r,'paperShade','goldDeep')
  ellipse(H,x-1,y-1,r-2,r-2,'ivory');ellipse(H,x,y,3,3,'goldDeep')
  poly(H,{{x,y-7},{x+3,y-1},{x+2,y+3},{x-2,y+3},{x-3,y}},'flame','redDeep')
  line(H,x,y-3,x,y+1,'flameHot',2)
  line(D,x+r-1,y+2,x+r-2,y+6,'ivory',2)
 end
 cross(H,22,52,'goldLight');cross(H,52,26,'goldLight')
end
function draw.tracery()
 ring(B,38,38,30,'stoneDeep','ink');ring(D,38,38,27,'goldDeep','stoneLight');ring(D,38,38,24,'redDeep','gold')
 -- Eight pointed lancets form the stone rose; the dark openings remain within a floor medallion.
 for j=0,7 do
  local a=j*math.pi/4;local cs,sn=math.cos(a),math.sin(a)
  local function turn(points)
   local q={};for _,p in ipairs(points) do q[#q+1]={38+p[1]*cs-p[2]*sn,38+p[1]*sn+p[2]*cs} end;return q
  end
  poly(D,turn({{0,-24},{6,-17},{5,-9},{0,-5},{-5,-9},{-6,-17}}),'stoneDeep','gold',2)
  path(H,turn({{-3,-16},{0,-21},{3,-16},{2,-11}}),'stoneLight')
 end
 ring(H,38,38,7,'goldDeep','ink');ring(H,38,38,5,'red','goldLight');cross(H,38,38,'goldLight')
 for j=0,7 do local a=j*math.pi/4;dot(H,38+27*math.cos(a),38+27*math.sin(a),'ivory') end
end

-- Mountain: branching fronds, a radial conifer crown, and irregular cap clusters.
function draw.fern()
 local fronds={{{38,58},{25,40},{14,33}},{{38,58},{20,49},{9,47}},{{38,58},{44,34},{48,14}},{{38,58},{31,30},{24,17}},{{38,58},{52,42},{65,37}},{{38,58},{51,55},{66,55}},{{38,58},{38,38},{37,8}}}
 for k,p in ipairs(fronds) do
  path(B,p,'ink',4);path(D,p,'greenLight',2)
  local a,b=p[1],p[2];local c=p[3]
  for n=1,5 do
   local t=n/6;local x=b[1]+(c[1]-b[1])*t;local y=b[2]+(c[2]-b[2])*t
   local dx,dy=c[1]-b[1],c[2]-b[2];local len=math.sqrt(dx*dx+dy*dy);local nx,ny=-dy/len,dx/len
   local z=8-n*.65
   for _,sgn in ipairs({-1,1}) do
    poly(D,{{x-dx*.15,y-dy*.15},{x+sgn*nx*z-dx*.12,y+sgn*ny*z-dy*.12},{x+sgn*nx*(z+2),y+sgn*ny*(z+2)},{x+dx*.08,y+dy*.08}},k%2==0 and 'green' or 'greenLight','greenDeep')
    line(H,x,y,x+sgn*nx*z,y+sgn*ny*z,'leafTip')
   end
  end
 end
 ring(D,38,57,5,'green','greenDeep');path(H,{{36,56},{36,53},{39,52},{41,54},{39,56}},'leafTip')
end
function draw.pine()
 local crowns={
  {{37,7},{43,20},{50,15},{52,28},{66,28},{61,39},{68,45},{56,50},{58,63},{44,59},{39,69},{32,59},{19,64},{20,52},{8,49},{17,39},{10,31},{24,28},{24,17},{33,21}},
  {{38,14},{43,27},{51,23},{49,34},{60,37},{50,43},{52,55},{40,51},{33,60},{31,49},{18,48},{25,38},{18,33},{31,31}},
  {{38,21},{43,33},{50,36},{43,40},{43,48},{36,43},{29,47},{30,38},{26,33},{34,33}}
 }
 for i,p in ipairs(crowns) do poly(i==1 and B or D,p,({'greenDeep','green','greenLight'})[i],'ink') end
 for _,p in ipairs({{{37,13},{36,32},{20,39}},{{38,25},{43,33},{52,36}},{{38,36},{37,48},{30,55}},{{30,32},{22,34}},{{42,46},{49,51}}}) do path(H,p,'leafTip') end
 path(H,{{36,28},{37,22},{39,28},{37,36}},'greenLight',2)
 for _,p in ipairs({{20,49},{53,48},{30,57}}) do poly(D,{{p[1],p[2]-2},{p[1]+3,p[2]},{p[1]+1,p[2]+4},{p[1]-2,p[2]+2}},'wood','ink') end
end
function draw.mushrooms()
 poly(B,{{13,39},{19,21},{35,16},{50,20},{63,34},{61,53},{43,64},{22,60}},'greenDeep','ink')
 for _,q in ipairs({{28,29,14},{49,45,13},{23,51,9},{52,22,8}}) do
  local x,y,r=table.unpack(q)
  ellipse(B,x,y,r+1,r,'ink');ellipse(D,x,y,r,r-1,'redDeep')
  ellipse(D,x-1,y-2,r-2,r-3,'red');ellipse(H,x-3,y-4,r-6,r-6,'redLight')
  for _,p in ipairs({{-5,-3},{2,-6},{5,2},{-3,5}}) do if r>10 then rect(H,x+p[1],y+p[2],3,2,'paper') end end
  if r<10 then dot(H,x-2,y-2,'ivory');dot(H,x+3,y+1,'ivory') end
  path(D,{{x-r+3,y+3},{x-3,y+r-2},{x+3,y+r-2},{x+r-2,y+3}},'paperShade')
 end
 for _,p in ipairs({{14,35},{39,62},{61,30}}) do path(H,{{p[1]-3,p[2]+1},{p[1],p[2]-3},{p[1]+2,p[2]+1}},'greenLight') end
end

-- Bastion: an open forge, the sculpted plan of an anvil, and laid-out fortress shields.
function draw.forge()
 poly(B,{{15,16},{53,16},{61,24},{61,56},{52,63},{15,63},{10,57},{10,23}},'stoneDeep','ink',2)
 box(D,16,20,39,36,'redDeep','stone');box(D,21,25,29,26,'ink','woodDeep')
 for _,y in ipairs({19,57}) do for x=15,48,11 do box(D,x,y,10,6,'stone','ink');line(H,x+1,y+1,x+7,y+1,'steel') end end
 for _,x in ipairs({12,54}) do for y=27,48,10 do box(D,x,y,6,9,'stone','ink') end end
 for _,p in ipairs({{25,45},{32,33},{43,41},{38,50},{26,28}}) do
  poly(D,{{p[1]-3,p[2]},{p[1],p[2]-3},{p[1]+4,p[2]},{p[1]+2,p[2]+3}},'red','woodDeep');line(H,p[1]-1,p[2]-1,p[1]+2,p[2]-1,'flame')
 end
 poly(H,{{29,39},{32,29},{36,35},{41,28},{45,40},{41,47},{34,46}},'flame','red')
 poly(H,{{33,39},{36,34},{40,40},{38,44}},'flameHot')
 for y=27,51,7 do line(D,20,y,50,y,'steel',2);dot(H,22,y-1,'steelLight') end
 path(B,{{61,31},{68,32},{68,46},{61,49}},'ink',4);path(D,{{61,31},{67,33},{67,45},{61,48}},'goldDeep',2)
end
function draw.anvil()
 -- Horn, hardy hole, heel and polished face in plan on a circular end-grain stump.
 ring(B,39,39,26,'woodDeep','ink');ring(D,39,39,23,'wood','goldDeep')
 for _,r in ipairs({15,19}) do
  path(H,{{39-r,36},{42-r,27},{43,22},{54,28},{59,40},{54,53},{40,59},{27,54}},'woodLight')
 end
 poly(B,{{9,38},{22,28},{31,26},{34,18},{56,18},{60,23},{60,52},{55,56},{34,56},{30,48},{21,45}},'stoneDeep','ink',2)
 poly(D,{{12,38},{24,30},{33,30},{37,22},{54,22},{56,25},{56,49},{53,52},{37,52},{33,44},{24,42}},'steel','stoneDeep')
 poly(H,{{13,37},{27,31},{34,31},{38,23},{52,23},{52,28},{37,33},{27,35}},'steelLight')
 path(H,{{37,24},{35,32},{35,45},{38,50}},'stoneLight')
 box(D,47,25,6,6,'ink','steelLight');ring(D,49,44,2,'ink','stoneLight')
 line(H,40,34,51,34,'steelLight');line(D,40,48,48,48,'stoneDeep')
 line(B,16,59,29,49,'ink',5);line(D,16,59,29,49,'woodLight',3)
 poly(H,{{24,47},{29,42},{38,50},{33,55}},'steel','ink');line(H,27,47,30,45,'steelLight')
end
function draw.shield_rack()
 box(B,10,16,55,45,'woodDeep');box(D,12,18,51,41,'wood','ink')
 for x=15,61,8 do line(D,x,20,x,56,'woodDeep');line(H,x+2,20,x+2,55,'woodLight') end
 for _,y in ipairs({20,53}) do line(D,13,y,62,y,'goldDeep',3)
  for _,x in ipairs({15,59}) do dot(H,x,y,'goldLight') end
 end
 for _,q in ipairs({{14,26,'red'},{33,23,'blueDeep'},{47,30,'redDeep'}}) do
  local x,y,c=table.unpack(q)
  poly(B,{{x,y},{x+14,y},{x+15,y+14},{x+7,y+23},{x-1,y+14}},'goldDeep','ink',2)
  poly(D,{{x+2,y+2},{x+12,y+2},{x+12,y+13},{x+7,y+19},{x+2,y+13}},c,'gold')
  line(H,x+7,y+3,x+7,y+17,'goldLight');line(H,x+3,y+8,x+11,y+8,'goldLight')
  ring(H,x+7,y+10,3,'steel','ink');dot(H,x+6,y+9,'steelLight')
 end
end

-- Pawnshop: packed wooden crates, a brass storm lamp and a split purse of coins.
local function crate(x,y,w,h)
 box(B,x,y,w,h,'woodDeep');box(D,x+2,y+2,w-4,h-4,'wood','goldDeep')
 for n=x+5,x+w-5,5 do line(D,n,y+3,n,y+h-4,'woodDeep');line(H,n+1,y+3,n+1,y+h-4,'woodLight') end
 line(D,x+3,y+3,x+w-4,y+h-4,'goldDeep',5);line(H,x+3,y+3,x+w-4,y+h-4,'woodLight',3)
 for _,p in ipairs({{x+3,y+3},{x+w-4,y+3},{x+3,y+h-4},{x+w-4,y+h-4}}) do dot(H,p[1],p[2],'steelLight') end
end
function draw.crates()
 crate(12,15,31,30);crate(37,31,28,29);crate(14,44,25,22)
 box(D,47,39,9,9,'goldDeep');box(H,49,41,5,5,'gold','ink');dot(H,51,43,'ink')
 box(H,18,20,9,7,'paper','woodDeep');line(H,20,23,24,23,'wood')
end
function draw.lamp()
 -- Four cage ribs and the top vent establish the overhead lantern, with glass between.
 path(B,{{27,19},{27,11},{31,8},{44,8},{48,11},{48,19}},'ink',4)
 path(H,{{28,18},{28,12},{32,10},{43,10},{46,12},{46,18}},'gold',2)
 poly(B,{{25,19},{50,19},{61,31},{61,49},{49,61},{26,61},{14,49},{14,31}},'goldDeep','ink',2)
 poly(D,{{28,24},{47,24},{56,33},{56,46},{47,55},{29,55},{20,46},{20,34}},'wood','gold')
 poly(H,{{29,27},{45,27},{52,34},{52,44},{45,51},{30,51},{23,44},{23,35}},'flame','goldDeep')
 poly(H,{{32,30},{43,30},{47,36},{47,43},{41,47},{32,45},{27,40},{29,34}},'flameHot')
 for _,q in ipairs({{24,26,51,53},{51,26,24,53},{37,20,37,58},{17,39,58,39}}) do
  line(D,q[1],q[2],q[3],q[4],'ink',4);line(H,q[1],q[2],q[3],q[4],'gold',2)
 end
 ring(H,37,39,10,'goldDeep','ink');ring(H,37,39,7,'gold','woodDeep');ring(H,37,39,4,'ink','goldLight')
 dot(H,32,32,'ivory');dot(H,52,30,'ivory')
end
local function coin(x,y,r)
 ring(D,x,y,r,'goldDeep','ink');ellipse(H,x-1,y-1,r-1,r-1,'gold')
 ellipse(H,x-1,y-2,r-3,r-3,'goldLight');line(H,x-1,y-r+2,x+2,y-r+2,'ivory')
 if r>=6 then line(D,x,y-2,x,y+3,'goldDeep');line(D,x-2,y-1,x+2,y-1,'goldDeep') end
end
function draw.coins()
 poly(B,{{20,13},{36,12},{39,20},{49,29},{50,45},{43,56},{21,55},{12,44},{14,29},{20,23}},'woodDeep','ink',2)
 poly(D,{{20,25},{30,21},{40,27},{44,37},{40,48},{23,50},{17,41},{18,31}},'wood','goldDeep')
 path(H,{{20,29},{19,40},{24,45}},'woodLight',2)
 path(D,{{20,22},{27,25},{35,21}},'gold',3);line(H,29,22,36,16,'goldLight');line(H,29,22,24,16,'goldLight')
 ellipse(D,40,42,10,7,'ink');ellipse(H,40,41,8,5,'goldDeep')
 for _,q in ipairs({{39,41,6},{49,47,7},{36,57,6},{55,57,8},{62,37,6},{22,61,5}}) do coin(table.unpack(q)) end
end

-- Crucible: asymmetric faceted crystal growth, connected glass vessels, and etched floor runes.
local function crystal(x,y,r,c)
 -- A faceted six-sided cross-section; three top planes meet at an offset apex.
 local points={{x,y-r},{x+r*.8,y-r*.35},{x+r*.72,y+r*.55},{x,y+r},{x-r*.78,y+r*.48},{x-r*.85,y-r*.35}}
 poly(B,points,'tealDeep','ink',2)
 poly(D,{{x,y-r+2},{x+r*.7,y-r*.32},{x+1,y+1}},c or 'teal','tealDeep')
 poly(D,{{x+r*.7,y-r*.32},{x+r*.62,y+r*.48},{x,y+r-2},{x+1,y+1}},'teal','tealDeep')
 poly(H,{{x,y-r+2},{x+1,y+1},{x,y+r-2},{x-r*.68,y+r*.42},{x-r*.74,y-r*.3}},'tealLight')
 path(H,{{x,y-r+3},{x+1,y},{x-r*.5,y+r*.25}},'ivory')
end
function draw.crystals()
 poly(B,{{16,25},{31,12},{50,17},{64,31},{63,53},{45,65},{23,62},{11,45}},'stoneDeep','ink')
 poly(D,{{18,28},{32,17},{48,21},{59,33},{57,51},{43,60},{25,57},{16,44}},'tealDeep','stone')
 crystal(24,43,16,'teal');crystal(48,45,18,'primary');crystal(37,28,18,'secondary')
 crystal(59,58,7,'teal');crystal(16,58,6,'teal')
 line(H,28,57,32,59,'secondary');line(H,44,61,49,58,'tealLight')
end
function draw.alembic()
 -- Round vessel shoulders and lids are seen from above; a bent condenser joins the vessels.
 box(B,10,14,57,50,'woodDeep');box(D,12,16,53,46,'wood','goldDeep')
 for x=17,62,9 do line(D,x,18,x,60,'woodDeep');line(H,x+1,18,x+1,60,'woodLight') end
 ring(B,29,41,17,'tealDeep','ink');ring(D,29,41,14,'teal','goldDeep')
 ellipse(H,27,39,11,11,'secondary');ellipse(H,30,43,9,9,'teal')
 path(H,{{20,33},{18,39},{20,46}},'ivory',2)
 ring(D,29,40,6,'gold','ink');ring(H,29,40,4,'tealDeep','goldLight');dot(H,28,39,'secondary')
 ring(B,55,46,10,'tealDeep','ink');ring(D,55,46,8,'secondary','goldDeep')
 ring(H,55,46,5,'teal','tealLight');ring(H,55,46,2,'tealDeep','gold');dot(H,52,42,'ivory')
 path(B,{{29,35},{29,24},{34,20},{47,20},{55,27},{55,39}},'ink',6)
 path(D,{{29,35},{29,25},{34,22},{46,22},{53,28},{53,38}},'tealDeep',4)
 path(H,{{28,34},{28,25},{34,21},{46,21},{54,28},{54,38}},'steelLight',2)
 for _,p in ipairs({{25,48},{34,45},{28,30}}) do ring(H,p[1],p[2],2,'acid','teal') end
 box(D,16,18,7,7,'goldDeep');cross(H,19,21,'goldLight');line(H,18,60,44,60,'gold')
end
function draw.rune_circle()
 ring(B,38,38,29,'stoneDeep','ink');ring(D,38,38,27,'tealDeep','stone')
 ring(D,38,38,23,'stoneDeep','tealLight');ring(D,38,38,20,'tealDeep','stone')
 for j=0,7 do
  local a=j*math.pi/4;local x=38+25*math.cos(a);local y=38+25*math.sin(a)
  path(H,{{x-2,y+1},{x,y-2},{x+2,y+1},{x,y+3}},j%2==0 and 'secondary' or 'primary')
 end
 path(H,{{38,18},{55,47},{21,47},{38,18}},'tealLight')
 path(H,{{38,58},{21,29},{55,29},{38,58}},'teal')
 ring(H,38,38,7,'tealDeep','primary');poly(H,{{38,32},{42,38},{38,44},{34,38}},'secondary','ink')
 line(H,37,34,37,40,'ivory')
end

-- Casino: roses in a stone planter, a felt table and stacks of enamel gaming chips.
function draw.rose_planter()
 poly(B,{{15,19},{59,19},{64,26},{64,55},{58,61},{17,61},{11,55},{11,26}},'stoneDeep','ink')
 box(D,16,24,43,32,'woodDeep','goldDeep');box(H,17,25,41,29,'greenDeep','stoneLight')
 for _,q in ipairs({{25,34},{43,32},{53,45},{29,49}}) do
  local x,y=table.unpack(q)
  for _,p in ipairs({{-10,-4},{7,-8},{6,7}}) do
   poly(D,{{x,y},{x+p[1],y+p[2]},{x+p[1]+4,y+p[2]-3},{x+p[1]+6,y+p[2]+2}},'green','greenDeep')
   line(H,x,y,x+p[1]+3,y+p[2],'greenLight')
  end
  poly(D,{{x-8,y-3},{x-4,y-8},{x+3,y-8},{x+8,y-3},{x+7,y+5},{x+2,y+8},{x-5,y+6}},'pinkDeep','ink')
  poly(H,{{x-6,y-2},{x-3,y-6},{x+3,y-5},{x+6,y},{x+2,y+6},{x-4,y+4}},'pink')
  path(H,{{x-5,y+1},{x-5,y-4},{x+2,y-5},{x+5,y-1},{x+3,y+4},{x-2,y+3},{x-2,y-1},{x+1,y-2}},'pinkLight',2)
  dot(H,x,y,'primary')
 end
end
function draw.card_table()
 poly(B,{{19,14},{55,14},{65,24},{65,52},{54,63},{20,63},{10,53},{10,25}},'woodDeep','ink',2)
 poly(D,{{20,18},{53,18},{61,26},{61,50},{52,59},{21,59},{14,51},{14,27}},'goldDeep','gold')
 poly(D,{{23,22},{50,22},{57,29},{57,47},{49,55},{24,55},{18,48},{18,30}},'violetDeep','pinkDeep')
 path(H,{{24,26},{49,26},{53,31},{53,46},{47,51},{26,51},{22,46}},'violet')
 for _,q in ipairs({{25,31,1},{35,28,0},{45,33,1}}) do
  local x,y,red=table.unpack(q);box(H,x,y,10,15,'ivory','ink')
  poly(H,{{x+5,y+4},{x+8,y+7},{x+5,y+10},{x+2,y+7}},red==1 and 'red' or 'ink')
  dot(H,x+2,y+2,red==1 and 'red' or 'ink')
 end
 for _,p in ipairs({{23,48},{48,49},{53,27}}) do ring(H,p[1],p[2],3,'pink','goldLight') end
 for _,p in ipairs({{14,25},{59,24},{16,55},{58,54}}) do dot(H,p[1],p[2],'goldLight') end
end
local function chip(x,y,r,color)
 ring(D,x,y,r,color,'ink');ring(H,x,y,r-2,'ivory',color);ring(H,x,y,r-4,color,'ink')
 for j=0,5 do local a=j*math.pi/3;line(H,x+(r-2)*math.cos(a),y+(r-2)*math.sin(a),x+r*math.cos(a),y+r*math.sin(a),'ivory',2) end
end
function draw.chips()
 for _,q in ipairs({{24,33,'pinkDeep'},{46,29,'blueDeep'},{44,50,'tealDeep'}}) do
  local x,y,c=table.unpack(q)
  for n=8,0,-4 do chip(x,y+n,12,c) end
 end
 chip(20,59,8,'red');chip(60,48,8,'violet')
 box(H,51,10,14,14,'ivory','ink')
 for _,p in ipairs({{54,13},{61,13},{57,17},{54,20},{61,20}}) do rect(H,p[1],p[2],2,2,'ink') end
end

-- Gala: faceted music resonator, vinyl deck and three overhead stage-light lenses.
function draw.music_crystal()
 -- Octahedral top planes sit inside an eight-sided resonator mounting.
 poly(B,{{24,13},{51,13},{64,26},{64,50},{51,63},{24,63},{11,50},{11,26}},'violetDeep','ink',2)
 poly(D,{{25,17},{50,17},{60,27},{60,49},{50,59},{25,59},{15,49},{15,27}},'violet','secondary')
 poly(B,{{38,9},{58,37},{38,65},{18,37}},'violetDeep','ink',2)
 poly(D,{{38,12},{55,37},{38,61},{37,37}},'primary','violetDeep')
 poly(H,{{38,12},{37,37},{38,61},{21,37}},'secondary')
 line(H,38,14,37,35,'ivory');line(H,22,37,36,37,'tealLight')
 path(H,{{33,47},{33,34},{45,30},{45,43}},'ink',2)
 ellipse(H,30,48,4,3,'ink');ellipse(H,42,44,4,3,'ink');line(H,35,34,43,32,'accent')
 for _,p in ipairs({{13,19},{63,16},{64,57}}) do cross(H,p[1],p[2],'secondary') end
 path(H,{{24,57},{31,60}},'primary',2);line(H,49,58,56,52,'primary',2)
end
function draw.turntable()
 box(B,8,16,61,46,'violetDeep');box(D,10,18,57,41,'stoneDeep','violet')
 line(H,12,20,64,20,'secondary');line(H,12,57,64,57,'primary')
 ring(D,33,38,18,'ink','steel');ring(H,33,38,15,'violetDeep','blueDeep')
 ring(H,33,38,11,'ink','violet');ring(H,33,38,6,'primary','ink');ring(H,33,38,2,'secondary','ink')
 path(H,{{21,33},{23,28},{29,25}},'steel');path(H,{{40,47},{45,43},{47,38}},'violetLight')
 ring(D,57,27,4,'steel','ink');path(H,{{57,27},{60,32},{54,45},{45,46}},'steelLight',2)
 box(H,43,44,7,5,'gold','ink')
 for _,y in ipairs({44,49,54}) do box(H,57,y,6,3,y==49 and 'primary' or 'secondary','ink') end
 box(D,13,52,8,3,'gold','ink');dot(H,64,22,'ivory')
end
function draw.stage_lights()
 path(B,{{10,26},{19,19},{56,19},{65,27}},'ink',7)
 path(D,{{10,26},{19,19},{56,19},{65,27}},'steel',3)
 for _,q in ipairs({{19,38,'primary'},{38,46,'secondary'},{57,37,'accent'}}) do
  local x,y,c=table.unpack(q)
  path(B,{{x-7,y-5},{x-10,y-11},{x-10,y-18},{x+10,y-18},{x+10,y-11},{x+7,y-5}},'ink',4)
  path(D,{{x-8,y-6},{x-9,y-16},{x+9,y-16},{x+8,y-6}},'stoneLight',2)
  ring(B,x,y,12,'stoneDeep','ink');ring(D,x,y,10,'violetDeep','steel')
  ring(H,x,y,8,c,'ink');ellipse(H,x-2,y-2,4,4,'ivory')
  line(D,x-6,y+2,x+5,y+2,'violetDeep');line(D,x-4,y+5,x+3,y+5,'violetDeep')
  dot(H,x-5,y-5,'ivory')
 end
 path(D,{{17,58},{29,64},{50,62},{58,57}},'violet',2)
end

local themes={
 {'labyrinth',{'sakura','torii','stone_lantern'}},
 {'guild_house',{'coffee_rug','books','hearth'}},
 {'sanctum',{'reliquary','candles','tracery'}},
 {'mountain',{'fern','pine','mushrooms'}},
 {'bastion',{'forge','anvil','shield_rack'}},
 {'pawnshop',{'crates','lamp','coins'}},
 {'crucible',{'crystals','alembic','rune_circle'}},
 {'casino',{'rose_planter','card_table','chips'}},
 {'gala',{'music_crystal','turntable','stage_lights'}}
}
local layers={'01 Ground shadow','02 Silhouette and structure','03 Material and ornament','04 Light and focal detail'}
local function writejson(path,data)
 local f=assert(io.open(path,'w'));f:write(json.encode(data));f:write('\n');f:close()
end
local function colors_for(row)
 local t=spec.themes[row]
 for i,key in ipairs({'primary','secondary','accent'}) do
  local col=convert(table.unpack(t[key..'_oklch']));C[key]=col.rgbaPixel;palette:setColor(#spec.colors+i,col)
 end
end
app.fs.makeAllDirectories(BASE..'previews');app.fs.makeAllDirectories(OUT)
local atlas=Image(228,684,ColorMode.RGB)
local contact=Image(252,756,ColorMode.RGB)
local metadata={frames={},arenas={},meta={app='Aseprite native Lua API',version=app.version,format='RGBA8888',image='arena_decorations.png',size={w=228,h=684},scale='1',frameTags={},layers={},slices={{name='frame',color='#00000000',keys={{frame=0,bounds={x=0,y=0,w=76,h=76},pivot={x=38,y=38}}}}}},contract={canvas={76,76},pivot={38,38},pixels_per_tile=19,tiles_per_canvas=4,projection='straight-down orthographic',placement='decorative border only; no gameplay footprint or collision',filtering='nearest; no mipmaps; lossless'},palette_source='assets/environment/palette.oklch.json'}
local readback={app='Aseprite',version=app.version,masters={},atlas={width=228,height=684,frames=27},native_readback=true}
for _,name in ipairs(layers) do metadata.meta.layers[#metadata.meta.layers+1]={name=name,opacity=255,blendMode='normal'} end
for row,t in ipairs(themes) do
 local id,props=table.unpack(t);local folder=BASE..id..'/';app.fs.makeAllDirectories(folder)
 local source=folder..id..'_decorations.aseprite'
 colors_for(row)
 if app.params.export_only~='true' then
  local s=Sprite(W,W,ColorMode.RGB);s:setPalette(palette)
  s.layers[1].name=layers[1];for i=2,#layers do s:newLayer().name=layers[i] end
  s:newEmptyFrame(2);s:newEmptyFrame(3)
  for index,prop in ipairs(props) do
   S=Image(W,W,ColorMode.RGB);B=Image(W,W,ColorMode.RGB);D=Image(W,W,ColorMode.RGB);H=Image(W,W,ColorMode.RGB)
   draw[prop]()
   for _,im in ipairs({B,D,H}) do for it in im:pixels() do
    if app.pixelColor.rgbaA(it())>0 and it.x+1<W-3 and it.y+2<W-3 then S:drawPixel(it.x+1,it.y+2,shadowColor) end
   end end
   for i,im in ipairs({S,B,D,H}) do s:newCel(s.layers[i],index,im,Point(0,0)) end
   s.frames[index].duration=1
   local tag=s:newTag(index,index);tag.name=id..'/'..prop
  end
  local slice=s:newSlice(Rectangle(0,0,W,W));slice.name='frame';slice.pivot=Point(38,38)
  s.data=json.encode({arena=id,props=props,canvas={76,76},pivot={38,38},projection='straight-down orthographic',purpose='border decorations; appearance only',palette='assets/environment/palette.oklch.json'})
  s:saveAs(source);s:close()
 end
 -- Always reopen each saved native master: exports come from the saved artwork.
 local saved=assert(app.open(source));assert(saved.width==76 and saved.height==76 and #saved.frames==3)
 assert(#saved.layers==4 and #saved.tags==3)
 local native={source='assets/environment/'..id..'/'..id..'_decorations.aseprite',width=saved.width,height=saved.height,layers={},tags={},frames={},pivot={saved.slices[1].pivot.x,saved.slices[1].pivot.y}}
 for _,l in ipairs(saved.layers) do native.layers[#native.layers+1]=l.name end
 metadata.arenas[#metadata.arenas+1]={id=id,row=row-1,props={}}
 local strip=Image(228,76,ColorMode.RGB)
 for index,prop in ipairs(props) do
  assert(saved.tags[index].name==id..'/'..prop)
  local im=Image(W,W,ColorMode.RGB);im:drawSprite(saved,index)
  local ax,ay=(index-1)*76,(row-1)*76
  atlas:drawImage(im,Point(ax,ay));strip:drawImage(im,Point(ax,0))
  local previewBack=convert(.245,.025,270).rgbaPixel
  for y=(row-1)*84,(row-1)*84+79 do for x=(index-1)*84,(index-1)*84+79 do contact:drawPixel(x,y,previewBack) end end
  contact:drawImage(im,Point((index-1)*84+2,(row-1)*84+2))
  local seq=(row-1)*3+index-1
  metadata.frames[#metadata.frames+1]={filename=id..'/'..prop,frame={x=ax,y=ay,w=76,h=76},rotated=false,trimmed=false,spriteSourceSize={x=0,y=0,w=76,h=76},sourceSize={w=76,h=76},duration=1000,pivot={x=38,y=38},arena=id,prop=prop}
  metadata.meta.frameTags[#metadata.meta.frameTags+1]={name=id..'/'..prop,from=seq,to=seq,direction='forward'}
  table.insert(metadata.arenas[#metadata.arenas].props,{id=prop,rect={ax,ay,76,76}})
  native.tags[#native.tags+1]={name=saved.tags[index].name,from=saved.tags[index].fromFrame.frameNumber,to=saved.tags[index].toFrame.frameNumber}
  local opaque,partial=0,0
  for it in im:pixels() do local a=app.pixelColor.rgbaA(it());if a==255 then opaque=opaque+1 elseif a>0 then partial=partial+1 end end
  assert(opaque>200,'Empty decoration '..id..'/'..prop)
  for it in im:pixels() do
   local a=app.pixelColor.rgbaA(it())
   assert(a==0 or a==90 or a==255,'Unexpected alpha in '..id..'/'..prop)
   if a>0 then assert(it.x>=3 and it.y>=3 and it.x<73 and it.y<73,'Clipped decoration '..id..'/'..prop) end
  end
  native.frames[#native.frames+1]={prop=prop,duration_ms=math.floor(saved.frames[index].duration*1000+.5),opaque_pixels=opaque,shadow_pixels=partial}
 end
 strip:resize(684,228);strip:saveAs(BASE..'previews/'..id..'-3x.png')
 readback.masters[#readback.masters+1]=native
 saved:close()
end
atlas:saveAs(OUT..'arena_decorations.png')
contact:saveAs(BASE..'previews/contact-sheet-1x.png')
contact:resize(756,2268);contact:saveAs(BASE..'previews/contact-sheet-3x.png')
writejson(OUT..'arena_decorations.json',metadata)
writejson(BASE..'native-readback.json',readback)
print('ARENA_DECORATIONS_OK: reopened 9 native masters; 27 tagged 76x76 frames; RGBA atlas 228x684; pivot 38,38')
