
local ROOT=(app.params.root or app.fs.currentPath)..app.fs.pathSeparator
local ID="warrior"
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
 local cloth,body,arms,helmet,sword,boomerang,trim=table.unpack(ims)
 local breath=({0,0,-1,-1,-1,0,0,0})[f];local wave=({0,1,2,2,1,0,-1,-1})[f];local sway=({0,0,1,1,0,0,-1,-1})[f]
 -- The cape lies behind the shoulders in plan view. Its broken hem moves independently.
 poly(cloth,{{43,45},{70,44},{78,58},{83,76},{84+wave,91},{78,88},{74+wave,101},{66,96},{63,104},{55,99},{48,103},{43-wave,95},{34,97},{36,86},{29-wave,90},{32,71},{36,55}},'redDark','ink',3)
 poly(cloth,{{44,49},{68,48},{75,60},{78+wave,86},{72+wave,95},{66,91},{60,99},{54,95},{48,98},{41,89},{35-wave,87},{36,69}},'red','redDark')
 poly(cloth,{{41,62},{45,63},{43,81},{44+wave,92},{39,89},{38,81}},'redLight')
 poly(cloth,{{52,63},{56,65},{58,91},{56,96},{52,86}},'redLight')
 poly(cloth,{{65,61},{69,63},{72+wave,88},{68,92},{66,82}},'redLight')
 path(cloth,{{46,69},{48,84},{48-wave,94}},'redDark',3);path(cloth,{{62,68},{61,83},{63,97}},'redDark',3)
 line(cloth,36,85,41,89,'redHot');line(cloth,55,87,57,91,'redHot');line(cloth,71,86,72,90,'redHot')
 -- Armor top plane: backplate and waist assembly, obscured by the crown and pauldrons.
 poly(body,{{41,49+breath},{71,49+breath},{76,66},{71,82},{62,87},{50,85},{39,77},{37,64}},'plumDeep','ink',3)
 poly(body,{{43,54+breath},{69,52+breath},{71,71},{65,78},{48,78},{42,69}},'plum','goldShadow',2)
 poly(body,{{43,54+breath},{54,53+breath},{51,69},{44,71}},'plumLight')
 path(body,{{42,54+breath},{54,52+breath},{68,52+breath},{72,64}},'gold',2)
 path(body,{{45,73},{56,79},{68,72}},'gold',2)
 for _,x in ipairs({45,68}) do ring(body,x,60+breath,2,'gold','goldDeep');dot(body,x-1,59+breath,'goldHot') end
 -- Clockwork back ornament is a flat inset; there is no frontal chest face.
 ring(body,57,70+breath,9,'goldDeep','ink');ring(body,57,70+breath,8,'gold','goldShadow');ring(body,57,70+breath,6,'goldLight','goldDeep')
 for j=0,7 do local a=j*math.pi/4;dot(body,57+5*math.cos(a),70+breath+5*math.sin(a),'goldShadow') end
 local hand=({-3,-2,-1,0,1,0,-1,-2})[f];line(body,57,70+breath,57+hand,65+breath,'ink',2);disk(body,57,70+breath,1,'dark');dot(body,54,65+breath,'goldHot')
 -- Independent shouldercaps with polygonal gold rims and irregular highlight clusters.
 local left={{34,43+breath},{44,46+breath},{47,56+breath},{40,65+breath},{27,61+breath},{25,50+breath}}
 poly(arms,left,'goldDeep','ink',3);poly(arms,{{34,45+breath},{42,48+breath},{44,56+breath},{38,62+breath},{29,59+breath},{28,51+breath}},'plum','gold',2)
 poly(arms,{{30,50+breath},{35,47+breath},{40,49+breath},{35,54+breath},{29,55+breath}},'plumLight')
 path(arms,{{27,50+breath},{34,43+breath},{44,47+breath}},'goldLight',2)
 poly(arms,{{35,49+breath},{38,54+breath},{35,58+breath},{32,54+breath}},'gold','goldDeep');dot(arms,34,52+breath,'goldHot')
 local right={{80,43+breath},{89,48+breath},{88,60+breath},{76,65+breath},{68,57+breath},{70,47+breath}}
 poly(arms,right,'goldDeep','ink',3);poly(arms,{{80,46+breath},{86,50+breath},{85,58+breath},{77,61+breath},{71,56+breath},{73,49+breath}},'plum','gold',2)
 poly(arms,{{74,48+breath},{80,47+breath},{84,50+breath},{76,55+breath},{72,54+breath}},'plumLight')
 path(arms,{{72,47+breath},{80,44+breath},{88,48+breath}},'goldLight',2)
 for _,p in ipairs({{29,57},{41,51},{74,53},{83,57}}) do ring(arms,p[1],p[2]+breath,1,'goldLight','goldDeep') end
 -- Bent forearms are seen from above; hands stay clearly separated from the torso.
 poly(arms,{{28,59},{36,63},{33,73+sway},{25,75+sway},{21,69+sway}},'plumDeep','ink',3)
 poly(arms,{{26,61},{33,64},{30,72+sway},{24,72+sway},{23,68+sway}},'plumLight','goldShadow')
 path(arms,{{24,64},{31,68},{25,73+sway}},'gold',2)
 poly(arms,{{79,63},{87,59},{94,67-sway},{93,75-sway},{86,77-sway},{81,70-sway}},'plumDeep','ink',3)
 poly(arms,{{83,64},{88,63},{91,68-sway},{90,73-sway},{86,73-sway}},'plumLight','goldShadow')
 path(arms,{{86,65},{91,68-sway},{89,74-sway}},'gold',2)
 -- Crown roof, rectangular gorget, and sagittal golden crest: no visible face or visor.
 poly(helmet,{{45,34+breath},{50,29+breath},{64,29+breath},{70,35+breath},{70,50+breath},{64,58+breath},{50,58+breath},{44,50+breath}},'goldDeep','ink',3)
 poly(helmet,{{48,35+breath},{53,31+breath},{63,32+breath},{67,36+breath},{67,48+breath},{62,53+breath},{51,53+breath},{47,48+breath}},'plum','gold',2)
 poly(helmet,{{48,36+breath},{53,33+breath},{56,35+breath},{55,49+breath},{51,51+breath},{48,47+breath}},'plumLight')
 poly(helmet,{{58,24+breath},{63,35+breath},{60,53+breath},{57,58+breath},{54,52+breath},{54,35+breath}},'gold','goldDeep',2)
 poly(helmet,{{58,27+breath},{59,37+breath},{57,51+breath},{56,36+breath}},'goldLight');line(helmet,58,29+breath,57,47+breath,'goldHot')
 line(helmet,49,35+breath,52,32+breath,'goldHot');line(helmet,65,35+breath,67,37+breath,'goldLight')
 for _,p in ipairs({{48,40},{49,49},{65,40},{64,49}}) do dot(helmet,p[1],p[2]+breath,'goldLight') end
 -- Cloth collar wraps around the rear, still flat against the shoulder plane.
 poly(trim,{{41,50+breath},{46,54+breath},{54,57+breath},{60,57+breath},{68,53+breath},{73,49+breath},{71,60+breath},{63,64+breath},{53,65+breath},{42,58+breath}},'redDark','ink')
 path(trim,{{43,53+breath},{51,59+breath},{60,61+breath},{70,54+breath}},'red',4)
 path(trim,{{43,51+breath},{51,57+breath},{57,59+breath}},'redLight',2);line(trim,65,59+breath,69,56+breath,'redLight')
 ring(trim,59,62+breath,3,'gold','goldDeep');dot(trim,58,60+breath,'goldHot')
 -- Straight sword at port, held idle. Contour is deliberately faceted, with a bright edge.
 local sy=sway;local sx=0
 poly(sword,{{21,18+sy},{27,29+sy},{28,66+sy},{31,70+sy},{23,75+sy},{17,70+sy},{21,66+sy}},'steelDark','ink',2)
 poly(sword,{{21,22+sy},{24,30+sy},{25,65+sy},{22,68+sy}},'steel');poly(sword,{{21,22+sy},{22,66+sy},{20,64+sy}},'steelLight')
 line(sword,21,27+sy,21,61+sy,'ivory');line(sword,24,37+sy,25,54+sy,'steelDark')
 poly(sword,{{15,66+sy},{21,68+sy},{29,65+sy},{33,68+sy},{25,73+sy},{18,72+sy},{14,70+sy}},'gold','ink')
 line(sword,16,67+sy,20,69+sy,'goldHot');line(sword,26,68+sy,30,67+sy,'goldLight')
 rect(sword,22,73+sy,4,12,'leather');path(sword,{{21,74+sy},{21,84+sy},{24,88+sy},{27,84+sy},{27,74+sy}},'ink',2)
 for y=75+sy,81+sy,3 do line(sword,22,y,25,y+1,'goldShadow') end
 poly(sword,{{24,84+sy},{28,88+sy},{24,92+sy},{20,88+sy}},'gold','ink');dot(sword,23,87+sy,'goldLight')
 -- Large crescent returning blade, recognizable from the portrait without playing an attack.
 local q=-sway
 poly(boomerang,shift({{84,24},{94,29},{103,40},{106,53},{103,65},{97,75},{92,81},{89,93},{79,99},{83,87},{83,80},{87,69},{94,59},{97,50},{95,40},{91,34}},0,q),'goldDeep','ink',3)
 poly(boomerang,shift({{87,27},{94,31},{100,41},{103,53},{100,63},{94,73},{90,79},{87,91},{82,96},{86,85},{86,79},{91,68},{97,58},{100,50},{98,39},{94,33}},0,q),'plum','gold',2)
 path(boomerang,shift({{86,26},{94,30},{102,41},{105,53},{102,64}},0,q),'goldLight',2)
 path(boomerang,shift({{85,28},{91,34},{96,40}},0,q),'steelLight',2)
 poly(boomerang,shift({{100,44},{102,53},{99,61},{98,56}},0,q),'plumLight')
 poly(boomerang,shift({{89,80},{89,89},{83,95},{87,84}},0,q),'steelLight')
 for _,p in ipairs({{99,46},{101,56},{96,66}}) do ring(boomerang,p[1],p[2]+q,1,'goldLight','goldDeep') end
 -- Red wraps break the crescent into readable blade and hand grip regions.
 path(boomerang,shift({{90,68},{96,72}},0,q),'ink',6);path(boomerang,shift({{90,68},{96,72}},0,q),'red',4)
 for k=0,2 do line(boomerang,90+k*2,67+k+q,88+k*2,71+k+q,'redLight') end
 poly(trim,{{86,71-sway},{91,69-sway},{95,73-sway},{93,78-sway},{87,79-sway},{84,75-sway}},'plum','ink',2)
 for k=0,2 do line(trim,87+k*2,72-sway,88+k*2,76-sway,'goldShadow') end
 -- Sparse deliberate edge glints, not random texture noise.
 if f==3 or f==4 then line(trim,31,46+breath,34,44+breath,'goldHot') end
 if f==6 or f==7 then dot(trim,65,34+breath,'goldHot');dot(sword,21,43+sy,'ivory') end
end
create(draw,{'01 Trailing crimson cape','02 Clockwork backplate','03 Pauldrons and articulated arms','04 Helmet roof and crown crest','05 Straight sword','06 Crescent boomerang','07 Collar hands and edge accents'},{name='Warrior',description='A massive plum-and-gold clockwork armored knight, seen from directly above, bearing a straight sword and crescent returning blade with a breathing crimson cape.',notes={'Portrait establishes plum armor, gold trim, clockwork ornament, crimson cloth, sword and crescent boomerang. This idle source contains no attack animation.','Eight distinct idle poses per cardinal direction: shoulders rise, clock hand ticks, cloth hem lags, and weapons counterbalance.','114 pixels equals six 19-pixel cells. Canvas and pivot are presentation dimensions, not collision or stats.','Cardinal directions are exact clockwise rotations of north; there is no visible frontal face, chest, standing boot or oblique camera.'}})
