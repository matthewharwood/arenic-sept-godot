
local ROOT=(app.params.root or app.fs.currentPath)..app.fs.pathSeparator
local ID="merchant"
local folder=ROOT..'assets/bosses/'..ID..'/'
local pf=assert(io.open(folder..'palette.oklch.json','r'));local spec=json.decode(pf:read('*a'));pf:close()
local palette=Palette(#spec.colors+1);palette:setColor(0,Color{r=0,g=0,b=0,a=0});local C={}
local function convert(L,ch,hue)
 local a=ch*math.cos(hue*math.pi/180);local b=ch*math.sin(hue*math.pi/180)
 local x=(L+.3963377774*a+.2158037573*b)^3;local y=(L-.1055613458*a-.0638541728*b)^3;local z=(L-.0894841775*a-1.291485548*b)^3
 local function enc(v) v=v<=.0031308 and 12.92*v or 1.055*v^(1/2.4)-.055;return math.floor(math.max(0,math.min(1,v))*255+.5) end
 return Color{r=enc(4.0767416621*x-3.3077115913*y+.2309699292*z),g=enc(-1.2684380046*x+2.6097574011*y-.3413193965*z),b=enc(-.0041960863*x-.7034186147*y+1.707614701*z),a=255}
end
for i,v in ipairs(spec.colors) do local col=convert(table.unpack(v.oklch));C[v.id]=col.rgbaPixel;palette:setColor(i,col) end
local function dot(im,x,y,c) x=math.floor(x+.5);y=math.floor(y+.5);if x>=1 and y>=1 and x<113 and y<113 then im:drawPixel(x,y,type(c)=='number' and c or C[c]) end end
local function disk(im,x,y,r,c) for yy=math.floor(y-r),math.ceil(y+r) do for xx=math.floor(x-r),math.ceil(x+r) do if (xx-x)^2+(yy-y)^2<=r*r then dot(im,xx,yy,c) end end end end
local function line(im,x0,y0,x1,y1,c,w)
 x0=math.floor(x0+.5);y0=math.floor(y0+.5);x1=math.floor(x1+.5);y1=math.floor(y1+.5)
 local dx,dy=math.abs(x1-x0),-math.abs(y1-y0);local sx=x0<x1 and 1 or -1;local sy=y0<y1 and 1 or -1;local e=dx+dy
 while true do if w and w>1 then disk(im,x0,y0,(w-1)/2,c) else dot(im,x0,y0,c) end;if x0==x1 and y0==y1 then break end;local e2=2*e;if e2>=dy then e=e+dy;x0=x0+sx end;if e2<=dx then e=e+dx;y0=y0+sy end end
end
local function poly(im,p,c,edge,w)
 local low,high=113,0;for _,pt in ipairs(p) do low=math.min(low,pt[2]);high=math.max(high,pt[2]) end
 for y=math.floor(low),math.ceil(high) do local xs={};local j=#p
  for i=1,#p do local a,b=p[i],p[j];if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then xs[#xs+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2]) end;j=i end
  table.sort(xs);for i=1,#xs-1,2 do for x=math.ceil(xs[i]),math.floor(xs[i+1]) do dot(im,x,y,c) end end
 end
 if edge then for i=1,#p do local a,b=p[i],p[(i%#p)+1];line(im,a[1],a[2],b[1],b[2],edge,w or 1) end end
end
local function rect(im,x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(im,xx,yy,c) end end end
local function ring(im,x,y,r,c,edge) disk(im,x,y,r,edge);disk(im,x,y,r-1,c) end
local function path(im,p,c,w) for i=1,#p-1 do line(im,p[i][1],p[i][2],p[i+1][1],p[i+1][2],c,w) end end
local function shift(p,dx,dy) local q={};for i,v in ipairs(p) do q[i]={v[1]+dx,v[2]+dy} end;return q end
local function flip(p) local q={};for i,v in ipairs(p) do q[i]={113-v[1],v[2]} end;return q end
local function star(im,x,y,c) line(im,x-2,y,x+2,y,c);line(im,x,y-2,x,y+2,c) end
local function rotate(im,n) local out=Image(114,114,ColorMode.RGB);for it in im:pixels() do local x,y=it.x,it.y;for _=1,n do x,y=113-y,x end;out:drawPixel(x,y,it()) end;return out end
local function writejson(path,obj) local f=assert(io.open(path,'w'));f:write(json.encode(obj));f:close() end
local function create(draw,layernames,opt)
 app.fs.makeAllDirectories(folder..'previews')
 local s=Sprite(114,114,ColorMode.RGB);s:setPalette(palette)
 s.layers[1].name=layernames[1];for i=2,#layernames do s:newLayer().name=layernames[i] end
 local count=opt.count or 8;local durations=opt.durations or {200,200,200,200,200,200,200,200}
 for i=2,count*4 do s:newEmptyFrame(i) end
 local source={};for f=1,count do local ims={};for i=1,#layernames do ims[i]=Image(114,114,ColorMode.RGB) end;draw(ims,f);source[f]=ims end
 for d,dir in ipairs({'n','e','s','w'}) do
  for f=1,count do local n=(d-1)*count+f;s.frames[n].duration=durations[f]/1000;for j,im in ipairs(source[f]) do s:newCel(s.layers[j],n,rotate(im,d-1),Point(0,0)) end end
  local t=s:newTag((d-1)*count+1,d*count);t.name='idle_'..dir;t.repeats=0
  for _,st in ipairs(opt.states or {}) do local t=s:newTag((d-1)*count+st.first,(d-1)*count+st.last);t.name=st.id..'_'..dir;t.repeats=0 end
 end
 local sl=s:newSlice(Rectangle(0,0,114,114));sl.name='frame';sl.pivot=Point(57,57)
 s.data=json.encode({id=ID,kind='boss',projection='true straight-down orthographic',canvas={114,114},pivot={57,57},display_diameter=114,pixels_per_tile=19,cardinal='exact clockwise ninety degree rotations',art_reference='assets/bosses/portraits/'..ID..'.png',notes=opt.notes})
 s:saveAs(folder..ID..'.aseprite')
 local contact=Image(114*8,114*math.ceil(count/8),ColorMode.RGB)
 for f=1,count do local im=Image(114,114,ColorMode.RGB);im:drawSprite(s,f);contact:drawImage(im,Point(((f-1)%8)*114,math.floor((f-1)/8)*114)) end
 contact:resize(contact.width*2,contact.height*2);contact:saveAs(folder..'previews/'..ID..'-contact.png')
 local dirs=Image(456,114,ColorMode.RGB);for d=1,4 do local im=Image(114,114,ColorMode.RGB);im:drawSprite(s,(d-1)*count+1);dirs:drawImage(im,Point((d-1)*114,0)) end;dirs:resize(1368,342);dirs:saveAs(folder..'previews/'..ID..'-directions.png')
 local frame=Image(114,114,ColorMode.RGB);frame:drawSprite(s,1);frame:resize(456,456);frame:saveAs(folder..'previews/'..ID..'-north-4x.png')
 local manifest={id=ID,name=opt.name,kind='boss',description=opt.description,canvas={114,114},pivot={57,57},source='assets/bosses/'..ID..'/'..ID..'.aseprite',portrait='arenic-game/assets/portraits/bosses/'..ID..'.png',default_state=opt.default_state or 'idle',visual_states=opt.visual_states or {{id='idle',name='Idle',tag='idle',description=opt.description}},notes=opt.notes,animation={frames_per_direction=count,durations_ms=durations,loop_ms=0,directions={'n','e','s','w'}}}
 for _,ms in ipairs(durations) do manifest.animation.loop_ms=manifest.animation.loop_ms+ms end
 writejson(folder..'boss.json',manifest);s:close();print(ID..': '..(count*4)..' frames saved, loop '..manifest.animation.loop_ms..' ms.')
end
local function draw(ims,f)
 local engines,arms,hull,gear,dome,pilot,accents=table.unpack(ims)
 local bob=({0,0,-1,-1,-1,0,0,0})[f];local pinch=({0,1,2,2,1,0,-1,-1})[f]
 -- Four exposed radial drive pods and engine petals are visible in plan view.
 for j=0,3 do local a=(45+j*90)*math.pi/180;local x=57+math.floor(28*math.cos(a));local y=51+math.floor(28*math.sin(a))
  ring(engines,x,y,10,'goldDeep','ink');ring(engines,x,y,8,'plumDeep','goldShadow');ring(engines,x,y,5,'tealDeep','ink');ring(engines,x,y,3,'teal','tealDark')
  if (f+j)%4<2 then dot(engines,x-1,y-1,'tealHot');dot(engines,x,y+1,'tealLight') end
 end
 -- Mechanical arms: narrow exposed pistons keep negative space around the expensive tool heads.
 path(arms,{{33,65},{24,73},{20,83}},'ink',12);path(arms,{{33,65},{24,73},{20,83}},'goldShadow',9)
 path(arms,{{32,65},{25,72}},'steelDark',5);path(arms,{{32,64},{25,71}},'steelLight',2)
 ring(arms,24,73,6,'gold','goldDeep');ring(arms,24,73,3,'plum','ink');dot(arms,22,71,'goldHot')
 path(arms,{{81,64},{91,70},{94,83}},'ink',12);path(arms,{{81,64},{91,70},{94,83}},'goldShadow',9)
 path(arms,{{83,64},{91,70}},'steelDark',5);path(arms,{{83,63},{90,68}},'steelLight',2)
 ring(arms,91,70,6,'gold','goldDeep');ring(arms,91,70,3,'plum','ink');dot(arms,89,68,'goldHot')
 poly(arms,{{89,74},{94,72},{99,77},{101,83},{96,87},{92,83}},'gold','ink',2)
 poly(arms,{{92,76},{95,75},{98,80},{97,84},{94,81}},'teal','tealDeep');line(arms,93,76,96,80,'tealLight')
 -- Circular saucer deck. No ellipse or front face; every rim ornament is on the top plane.
 ring(hull,57,51+bob,35,'goldDeep','ink');ring(hull,57,51+bob,33,'gold','goldShadow');ring(hull,57,51+bob,31,'plumDeep','goldLight');ring(hull,57,51+bob,29,'plum','goldDeep')
 for j=0,7 do
  local a=(j*45-90)*math.pi/180;local ca,sa=math.cos(a),math.sin(a)
  local ax,ay=57+23*ca,51+bob+23*sa;local bx,by=57+31*ca,51+bob+31*sa
  line(hull,ax,ay,bx,by,'goldDeep',3);line(hull,ax-1,ay-1,bx-1,by-1,'gold',1)
  local x,y=57+math.floor(27*math.cos(a+.20)),51+bob+math.floor(27*math.sin(a+.20))
  ring(hull,x,y,2,'goldLight','goldDeep')
 end
 -- Symmetric fins and stylized gilded trade ornament identify the ship without front-facing signage.
 poly(gear,{{29,43+bob},{22,38+bob},{21,24+bob},{27,18+bob},{35,36+bob}},'plumDeep','ink',2)
 poly(gear,{{27,38+bob},{24,35+bob},{24,26+bob},{27,22+bob},{32,36+bob}},'plum','gold',2)
 line(gear,26,23+bob,24,31+bob,'goldLight',2)
 poly(gear,{{85,43+bob},{92,38+bob},{93,24+bob},{87,18+bob},{79,36+bob}},'plumDeep','ink',2)
 poly(gear,{{87,38+bob},{90,35+bob},{90,26+bob},{87,22+bob},{82,36+bob}},'plum','gold',2)
 line(gear,87,23+bob,90,31+bob,'goldLight',2)
 -- Deck vents have dark cavities and three purposeful brass slats.
 for _,pos in ipairs({{34,55},{80,55},{46,77},{67,77}}) do local x,y=pos[1],pos[2]+bob;ring(gear,x,y,5,'dark','gold');for k=-2,2,2 do line(gear,x+k,y-3,x+k,y+3,'goldShadow') end;dot(gear,x-2,y-3,'goldLight') end
 -- Teal faceted crystals embedded in the top rim.
 for _,pos in ipairs({{39,32},{75,32},{29,62},{85,62},{57,79}}) do local x,y=pos[1],pos[2]+bob
  poly(gear,{{x,y-5},{x+4,y-1},{x+3,y+4},{x,y+6},{x-4,y+1}},'teal','goldDeep',2)
  poly(gear,{{x,y-3},{x+2,y},{x,y+4},{x-2,y}},'tealLight');line(gear,x,y-3,x-2,y,'tealHot')
 end
 -- Center dome is a true top-down circular canopy; pilot crown and hands are seen through it.
 ring(dome,57,49+bob,22,'goldDeep','ink');ring(dome,57,49+bob,20,'gold','goldLight');ring(dome,57,49+bob,18,'tealDeep','goldDeep');ring(dome,57,49+bob,17,'glass','tealDark')
 poly(dome,{{42,44+bob},{46,37+bob},{55,33+bob},{65,36+bob},{70,43+bob},{69,51+bob},{64,45+bob},{55,40+bob},{48,42+bob}},'glassLight')
 poly(dome,{{44,45+bob},{46,39+bob},{51,36+bob},{53,36+bob},{48,41+bob},{46,46+bob}},'glassHot')
 line(dome,49,37+bob,52,36+bob,'ivory',2);dot(dome,67,40+bob,'tealHot');dot(dome,68,42+bob,'tealHot')
 -- Tiny merchant: plum hat viewed from the crown, angular gold band, two control grips.
 poly(pilot,{{47,49+bob},{50,44+bob},{57,42+bob},{64,45+bob},{67,50+bob},{64,56+bob},{53,57+bob},{48,54+bob}},'plumDeep','tealDeep',2)
 poly(pilot,{{49,49+bob},{53,44+bob},{59,45+bob},{63,49+bob},{61,53+bob},{53,54+bob}},'plum','goldShadow')
 path(pilot,{{49,51+bob},{56,54+bob},{64,51+bob}},'gold',2);dot(pilot,59,46+bob,'goldLight')
 ring(pilot,57,45+bob,2,'teal','gold');dot(pilot,57,44+bob,'tealHot')
 rect(pilot,47,58+bob,3,4,'leather');rect(pilot,64,58+bob,3,4,'leather');dot(pilot,48,58+bob,'goldLight');dot(pilot,65,58+bob,'goldLight')
 path(pilot,{{45,64+bob},{45,60+bob},{47,59+bob}},'goldDeep',2);path(pilot,{{69,64+bob},{69,60+bob},{67,59+bob}},'goldDeep',2)
 -- A single narrow facet at the pole, aligned with north.
 poly(accents,{{57,10+bob},{62,18+bob},{57,23+bob},{52,18+bob}},'teal','ink',2);poly(accents,{{57,12+bob},{58,18+bob},{54,18+bob}},'tealLight');line(accents,57,12+bob,55,16+bob,'tealHot')
 ring(accents,57,25+bob,4,'gold','goldDeep');line(accents,54,24+bob,58,23+bob,'goldLight')
 -- Pincer tool: two sculpted metallic jaws, idle opening only.
 poly(accents,{{20,81},{12,80},{7,86},{6,95},{11,103},{21,107},{30+pinch,104},{22,101},{17,97},{16,91},{20,87}},'plumDeep','ink',2)
 poly(accents,{{13,83},{9,88},{9,95},{14,102},{22,105},{25+pinch,104},{18,100},{14,95},{14,89},{17,85}},'plum','gold',2)
 poly(accents,{{23,81},{31,82},{37,89},{39,97},{34-pinch,105},{33,96},{28,92},{24,91},{20,86}},'plumDeep','ink',2)
 poly(accents,{{25,83},{30,84},{35,90},{36,97},{34-pinch,101},{31,94},{25,89},{23,86}},'plum','gold',2)
 path(accents,{{10,88},{9,94},{14,101},{21,104}},'goldLight',2);path(accents,{{27,83},{33,87},{37,94}},'goldLight',2)
 ring(accents,21,85,4,'gold','goldDeep');ring(accents,21,85,2,'plum','ink');dot(accents,20,84,'goldLight')
 -- Rotating saw tooth profile. Two tick angles alternate continuously across the idle loop.
 local cx,cy=91,93;local teeth={};for j=0,31 do local a=(j*360/32+f*5.625)*math.pi/180;local r=j%2==0 and 15 or 12;teeth[#teeth+1]={cx+math.floor(r*math.cos(a)+.5),cy+math.floor(r*math.sin(a)+.5)} end
 poly(accents,teeth,'steel','ink',2);ring(accents,cx,cy,10,'steelDark','dark');ring(accents,cx,cy,7,'gold','goldDeep');ring(accents,cx,cy,4,'goldShadow','goldLight');ring(accents,cx,cy,2,'steelDark','goldDeep')
 for j=0,3 do local a=(j*90+f*12)*math.pi/180;line(accents,cx+9*math.cos(a),cy+9*math.sin(a),cx+12*math.cos(a),cy+12*math.sin(a),'steelLight',2) end
 dot(accents,cx-2,cy-3,'goldHot')
 -- Small deck glints and exposed coils. All alpha remains binary.
 for _,x in ipairs({22,90}) do for y=46,51,2 do line(accents,x,y+bob,x+2,y+bob,'goldShadow') end end
 if f==3 or f==4 then star(accents,75,31+bob,'tealHot') end
end
create(draw,{'01 Radial engine pods','02 Brass articulated tool arms','03 Circular purple and gold hull','04 Deck fins vents and teal jewels','05 Overhead glass canopy','06 Tiny pilot crown and controls','07 Pincer saw crystal and highlights'},{name='Merchant',description='An extravagant purple-and-gold circular gadget ship with a mint glass canopy, tiny merchant pilot, brass pincer and slowly turning saw.',notes={'Portrait is translated to a circular top-down saucer; no oval front face or side-facing cockpit.','Eight distinct idle poses coordinate subtle hull breathing, pincer flex, turning saw teeth and crystal glints. No attack or gameplay effect is implied.','The pilot is seen only from the crown through the canopy. All colors and glass highlights are opaque pixel clusters with transparent background.','114 pixels equals six 19-pixel cells; pivot remains 57,57 and each direction is an exact ninety-degree rotation.'}})
