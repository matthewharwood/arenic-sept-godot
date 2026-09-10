
local ROOT=(app.params.root or app.fs.currentPath)..app.fs.pathSeparator
local ID="forager"
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
 local legs,abdomen,claws,head,tail,detail=table.unpack(ims)
 local p=({0,1,1,0,-1,-1,0,1})[f];local breathe=({0,0,1,1,1,0,0,0})[f];local curl=({0,1,2,2,1,0,-1,-1})[f]
 -- Eight articulated walking legs. Alternating toes settle without translating the creature.
 local walks={{{43,47},{29,43},{18,49},{12,57}},{{40,55},{26,53},{17,63},{12,69}},{{41,65},{27,65},{20,77},{14,82}},{{45,74},{32,79},{28,89},{23,94}}}
 for side=0,1 do
  for j,base in ipairs(walks) do
   local pts={};for k,v in ipairs(base) do pts[k]={side==0 and v[1] or 113-v[1],v[2]} end
   local step=(j+side)%2==0 and p or -p;pts[3][2]=pts[3][2]+step;pts[4][2]=pts[4][2]+step
   path(legs,pts,'ink',7);path(legs,{pts[1],pts[2]},'goldDeep',5);path(legs,{pts[2],pts[3]},'green',5);path(legs,{pts[3],pts[4]},'jawDark',4)
   line(legs,pts[1][1],pts[1][2]-1,pts[2][1],pts[2][2]-1,'gold',2)
   line(legs,pts[2][1],pts[2][2]-1,pts[3][1],pts[3][2]-1,'greenLight',2)
   ring(legs,pts[2][1],pts[2][2],3,'gold','goldDeep');dot(legs,pts[2][1]-1,pts[2][2]-1,'goldLight')
   ring(legs,pts[3][1],pts[3][2],2,'goldShadow','ink');dot(legs,pts[3][1]-1,pts[3][2]-1,'goldLight')
   line(legs,pts[3][1],pts[3][2],pts[4][1],pts[4][2],'jawLight')
  end
 end
 -- Broad dorsal abdomen. Five overlapping carapace plates keep the scorpion anatomical.
 poly(abdomen,{{43,45},{52,39},{64,40},{74,48},{78,61},{75,75},{68,85},{58,91},{47,85},{39,74},{36,61}},'greenDeep','ink',3)
 for j=4,0,-1 do local y=48+j*8;local half=({16,19,19,16,11})[j+1]+breathe
  poly(abdomen,{{57-half,y-4},{49,y-8},{63,y-8},{57+half,y-4},{58+half,y+4},{65,y+8},{51,y+8},{56-half,y+4}},'green','goldDeep',2)
  poly(abdomen,{{58-half,y-3},{50,y-6},{56,y-5},{53,y+3},{48,y+4},{57-half,y+2}},'greenLight')
  path(abdomen,{{57-half,y-4},{49,y-8},{63,y-8},{57+half,y-4}},'gold',2)
  path(abdomen,{{58-half,y-4},{50,y-7},{54,y-7}},'goldLight')
  poly(abdomen,{{57,y-9},{60,y-3},{57,y},{54,y-3}},'gold','goldDeep');dot(abdomen,57,y-7,'goldLight')
  dot(abdomen,59+half-3,y+1,'gold');dot(abdomen,58-half+2,y+1,'goldLight')
  path(abdomen,{{62,y-3},{65,y-1},{63,y+2}},'greenDeep')
 end
 -- Claw arms are positioned ahead of the walking legs.
 for side=0,1 do
  local function shape(points,c,o,w) poly(claws,side==0 and points or flip(points),c,o,w) end
  local function seg(points,c,w) path(claws,side==0 and points or flip(points),c,w) end
  local function pt(x,y) return side==0 and x or 113-x,y end
  shape({{42,46},{33,46},{25,39},{22,29},{29,26},{35,36},{43,38}},'green','ink',3)
  seg({{39,44},{32,41},{27,33}},'gold',4);seg({{38,40},{33,38},{28,29}},'greenLight',2)
  local x,y=pt(31,37);ring(claws,x,y,5,'gold','goldDeep');ring(claws,x,y,3,'greenLight','greenDeep')
  -- Hand-carved pincer shell silhouette; each pointed jaw is independently animated.
  local opening=(side==0 and p or -p)
  shape({{26,37},{16,37},{9,31},{6,23},{9,14},{16,8},{21,11},{18,20},{19,27},{25,28},{29,23},{29,14},{34,18},{38,27},{35,34}},'greenDeep','ink',3)
  shape({{23,34},{16,34},{10,29},{9,22},{12,15},{17,12},{15,21},{17,29},{24,30},{31,25},{32,18},{35,24},{34,30},{30,34}},'green','gold',2)
  shape({{13,19},{16,14},{14,24},{17,29},{21,30},{19,32},{13,28},{11,24}},'greenLight')
  shape({{17,10},{21+opening,5},{24+opening,6},{22+opening,16},{19,24},{17,20}},'gold','ink',2)
  shape({{20+opening,8},{22+opening,7},{21+opening,14},{18,20}},'goldLight')
  shape({{29,24},{29-opening,14},{25-opening,7},{29-opening,8},{34,15},{36,23},{33,28}},'goldShadow','ink',2)
  seg({{28-opening,10},{32,16},{33,23},{31,26}},'goldLight',2)
  seg({{10,22},{12,17},{16,14}},'goldLight',2)
  local x,y=pt(13,27);ring(claws,x,y,2,'gold','goldDeep');dot(claws,x-1,y-1,'goldHot')
  local x,y=pt(30,30);dot(claws,x,y,'goldLight')
  -- Fine serrations on the inward edges.
  for j=0,2 do local x,y=pt(21+j%2,15+j*3);dot(claws,x+opening,y,'jawDark') end
 end
 -- Cephalothorax roof and paired eyes visible from straight above.
 poly(head,{{42,35},{48,29},{63,29},{70,34},{73,43},{68,50},{58,54},{47,51},{40,44}},'greenDeep','ink',3)
 poly(head,{{44,36},{49,31},{62,31},{68,36},{69,43},{64,47},{55,50},{46,46},{43,42}},'green','gold',2)
 poly(head,{{47,34},{53,32},{55,36},{52,43},{46,43},{44,40}},'greenLight')
 path(head,{{43,36},{50,30},{62,30},{69,36}},'goldLight',2)
 poly(head,{{56,29},{61,33},{58,41},{55,46},{52,39},{52,33}},'gold','goldDeep',2)
 line(head,56,31,54,38,'goldLight',2)
 for _,x in ipairs({47,65}) do ring(head,x,38,3,'eye','goldDeep');dot(head,x-1,37,'eyeGlint');dot(head,x,36,'greenHot') end
 for _,x in ipairs({52,60}) do ring(head,x,33,2,'eye','goldShadow');dot(head,x,32,'eyeGlint') end
 -- Small feeding pincers project ahead of the shell, not a frontal mouth.
 poly(head,{{50,31},{46,27},{45,21},{48,18},{49,25},{54,29}},'jaw','ink',2);path(head,{{47,23},{48,27},{51,29}},'gold',2)
 poly(head,{{60,30},{65,26},{66,20},{63,18},{62,24},{58,28}},'jaw','ink',2);path(head,{{64,23},{63,27},{60,29}},'gold',2)
 -- Raised tail is drawn in plan view with a curved segmented path and a tapered stinger.
 local centers={{58,83},{61,92},{72,99},{84,97},{93,89},{96,77},{92+curl,65},{86+curl,55},{79+curl,49}}
 for j,v in ipairs(centers) do local r=({8,8,8,8,7,7,6,6,5})[j]
  local x,y=v[1],v[2]
  poly(tail,{{x-r,y-3},{x-3,y-r},{x+3,y-r},{x+r,y-2},{x+r,y+3},{x+3,y+r},{x-3,y+r},{x-r,y+2}},'greenDeep','ink',3)
  poly(tail,{{x-r+2,y-3},{x-2,y-r+2},{x+3,y-r+2},{x+r-2,y},{x+2,y+r-2},{x-3,y+r-2},{x-r+2,y+1}},'green','goldShadow')
  poly(tail,{{x-r+2,y-3},{x-2,y-r+2},{x+2,y-r+2},{x-1,y-1},{x-4,y+2},{x-r+2,y}},'greenLight')
  path(tail,{{x-r+1,y-2},{x-3,y-r+1},{x+3,y-r+1},{x+r-1,y-2}},'gold',2)
  line(tail,x-2,y-r+1,x+1,y-r+1,'goldLight')
  dot(tail,x-r+2,y+1,'goldLight');dot(tail,x+3,y+2,'goldShadow')
 end
 poly(tail,{{75+curl,50},{74+curl,43},{77+curl,36},{85+curl,33},{82+curl,39},{81+curl,46},{78+curl,52}},'gold','ink',2)
 poly(tail,{{76+curl,44},{79+curl,38},{83+curl,35},{80+curl,42},{79+curl,47}},'goldLight')
 line(tail,76+curl,45,76+curl,49,'goldHot')
 -- Sparse mottled carapace chips read as worn mineral shell, not noise.
 for _,v in ipairs({{45,54},{49,57},{67,57},{42,63},{52,72},{67,68},{61,80},{83,96},{94,76},{89,63},{12,24},{103,24}}) do dot(detail,v[1],v[2],'goldShadow');dot(detail,v[1]+1,v[2]+1,'greenHot') end
 if f==3 or f==4 then dot(detail,82+curl,35,'goldHot') end
end
create(draw,{'01 Eight articulated legs','02 Segmented dorsal carapace','03 Armored claws and pincer jaws','04 Head roof eyes and mandibles','05 Curled segmented tail and stinger','06 Worn shell chips and glints'},{name='Forager',description='A mineral-green and brass armored scorpion viewed directly from above, with eight legs, huge gold-edged pincers and a curling articulated tail.',notes={'Portrait establishes dark green mineral shell, battered brass bands, large claws, eight legs, segmented tail and hooked stinger.','Eight distinct idle poses per direction coordinate pincer flex, alternating toe shifts, dorsal breathing and a delayed tail curl.','114 pixels equals six 19-pixel cells. Art footprint is separate from collision and stats.','Exact cardinal rotations preserve anatomy and equipment. This source has idle animation only.'}})
