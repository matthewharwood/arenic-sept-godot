
local ROOT=(app.params.root or app.fs.currentPath)..app.fs.pathSeparator
local ID="thief"
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
 local cloth,body,quiver,mantle,head,sword,bow,detail=table.unpack(ims)
 local section=math.floor((f-1)/14)+1;local localf=(f-1)%14+1;local blend=math.max(0,localf-8);local mix=blend/7
 for _,name in ipairs({'clothDeep','cloth','clothLight','clothHot'}) do C[name]=C[name..'_'..section..'_'..blend] end
 local phase=(f-1)%8+1;local feather_lag=({0,1,2,1,0,-1,-2,-1})[phase];local breathe=({0,0,-1,-1,-1,0,0,0})[phase];local wave=({0,1,2,2,1,0,-1,-1})[phase];local sway=({0,0,1,1,0,0,-1,-1})[phase]
 local lengths={1,6,3};local nextsection=section%3+1;local length=math.floor(lengths[section]*(1-mix)+lengths[nextsection]*mix+.5)
 -- Long cloth panels sit behind the feather mantle, changing costume weight gradually.
 poly(cloth,{{44,49},{69,48},{76,62},{77+wave,83},{81,92},{72,88},{70,101},{62,95},{59,103},{51,96},{47-wave,99},{43,89},{34,94},{38,79},{34-wave,68}},'clothDeep','ink',3)
 poly(cloth,{{44,57},{61,56},{65,72},{65+wave,88},{61,96},{55,92},{50,95},{46,85}},'cloth','clothDeep')
 poly(cloth,{{40,65},{44,68},{43,85},{39,89}},'clothLight')
 poly(cloth,{{65,58},{72,63},{72,79},{76+wave,88},{70,87},{68,75}},'clothLight')
 path(cloth,{{48,65},{51,80},{53,94}},'clothLight',2);path(cloth,{{60,64},{61,83},{60,96}},'clothDeep',3)
 -- Gold cloth emblems read from above and stay on the same moving fabric.
 poly(cloth,{{56,79},{61,84},{57,91},{52,85}},'goldShadow');poly(cloth,{{56,82},{58,85},{57,88},{54,85}},'clothDeep');dot(cloth,56,80,'gold')
 -- Raven torso is a crouched compact top plane, fully feathered; no front chest or boots.
 poly(body,{{42,48+breathe},{70,48+breathe},{76,64},{68,78},{59,85},{48,82},{39,72},{37,58}},'featherDeep','ink',3)
 poly(body,{{43,53+breathe},{54,51+breathe},{64,56},{66,71},{57,78},{46,72}},'feather','featherDeep')
 poly(body,{{43,55+breathe},{47,56+breathe},{49,67},{46,70},{42,65}},'featherLight')
 path(body,{{43,57},{55,65},{68,76}},'leather',5);path(body,{{43,56},{55,64},{68,75}},'goldShadow',1)
 path(body,{{68,56},{60,66},{48,78}},'leather',5);path(body,{{68,55},{60,65},{48,77}},'goldShadow',1)
 ring(body,57,66,3,'gold','goldDeep');poly(body,{{57,63},{59,66},{57,69},{55,66}},'clothDeep');dot(body,57,63,'goldLight')
 -- Quiver across left back with red fletchings and visible arrow shafts.
 poly(quiver,{{31,51},{39,47},{52,69},{48,76},{42,76}},'leather','ink',3)
 path(quiver,{{33,51},{44,72},{49,72}},'goldShadow',2);line(quiver,37,49,50,70,'gold',2)
 for k=0,3 do local x=29+k*3;local y=37-k%2*3
  line(quiver,x,y,x+10,57,'ink',3);line(quiver,x,y,x+10,57,'goldShadow')
  poly(quiver,{{x,y-7},{x-2,y-3},{x,y+2},{x+3,y+4},{x+2,y-3}},'arrowRed','ink')
  line(quiver,x,y-5,x+1,y+1,'goldShadow');dot(quiver,x,y-6,'gold')
 end
 poly(quiver,{{30,48},{38,44},{43,50},{34,54}},'gold','ink');line(quiver,31,48,37,46,'goldLight')
 -- Feather mantle. Each overlapping feather has a deliberate point and one ridge highlight.
 local function feather(im,x,y,w,h,lean,tone)
  h=h+feather_lag
  poly(im,{{x-w,y},{x,y-3},{x+w,y+1},{x+lean+math.floor(w*.4),y+h-3},{x+lean,y+h},{x+lean-w,y+h-5}},tone,'ink')
  path(im,{{x,y},{x+math.floor(lean*.5),y+math.floor(h*.5)},{x+lean,y+h-3}},'featherLight')
  line(im,x-1,y+1,x+math.floor(lean*.4)-1,y+math.floor(h*.45),'featherHot')
 end
 for j=3,0,-1 do
  feather(mantle,38-j*3,51+j*4+breathe,5,15+length, -6-wave,j%2==0 and 'feather' or 'featherDeep')
  feather(mantle,76+j*3,51+j*4+breathe,5,15+length,6+wave,j%2==0 and 'feather' or 'featherDeep')
 end
 for j=0,3 do feather(mantle,38+j*5,49+j%2*3+breathe,5,19, -2+j,'feather') end
 for j=0,3 do feather(mantle,61+j*5,49+(j+1)%2*3+breathe,5,19, -1+j,'feather') end
 -- Flat crescent gold clasps over the shoulder feathers.
 path(mantle,{{30,51+breathe},{37,46+breathe},{46,48+breathe}},'ink',5);path(mantle,{{30,50+breathe},{37,45+breathe},{46,47+breathe}},'goldShadow',3);line(mantle,32,49+breathe,38,47+breathe,'goldLight')
 path(mantle,{{69,48+breathe},{77,46+breathe},{85,51+breathe}},'ink',5);path(mantle,{{69,47+breathe},{77,45+breathe},{85,50+breathe}},'goldShadow',3);line(mantle,72,47+breathe,77,47+breathe,'gold')
 -- Skull crown and backward sweeping feather crest. Beak projects north; eyes are hidden from this view.
 poly(head,{{46,35+breathe},{50,28+breathe},{58,25+breathe},{65,29+breathe},{70,36+breathe},{69,48+breathe},{62,56+breathe},{52,55+breathe},{45,47+breathe}},'featherDeep','ink',3)
 poly(head,{{48,36+breathe},{53,30+breathe},{59,29+breathe},{64,33+breathe},{66,41+breathe},{61,49+breathe},{53,48+breathe},{48,43+breathe}},'feather','featherDeep')
 poly(head,{{49,36+breathe},{52,32+breathe},{55,31+breathe},{56,39+breathe},{52,44+breathe}},'featherLight')
 -- Raven beak ridge is seen only from above, with no face mask or eye slits drawn frontally.
 poly(head,{{54,29+breathe},{57,22+breathe},{60,29+breathe},{58,35+breathe},{55,35+breathe}},'goldDeep','ink');line(head,57,24+breathe,56,30+breathe,'gold')
 for j=0,4 do local x=49+j*4;local y=42+(j%2)*2+breathe;feather(head,x,y,3,15+(j%3),j<2 and -2 or 2,'featherDeep') end
 -- Bandanna and two long ribbons are edited separately from the crown.
 path(detail,{{46,39+breathe},{51,36+breathe},{61,36+breathe},{68,39+breathe}},'clothDeep',7)
 path(detail,{{46,38+breathe},{52,35+breathe},{60,35+breathe},{68,38+breathe}},'cloth',4)
 path(detail,{{49,36+breathe},{55,35+breathe},{61,36+breathe}},'clothLight',2)
 poly(detail,{{67,39+breathe},{73,40+breathe},{83,47+wave},{94,49+wave},{103,58+wave+length},{94,57+wave},{84,56+wave},{75,49+breathe},{68,45+breathe}},'clothDeep','ink',2)
 path(detail,{{69,41+breathe},{79,47+wave},{90,52+wave},{99,56+wave+length}},'cloth',3)
 line(detail,76,46+wave,85,50+wave,'clothLight',2)
 poly(detail,{{65,50+breathe},{74,54+breathe},{81,65+wave},{94,69+wave},{102,81+wave+length},{94,78+wave},{82,77+wave},{76,67+breathe},{66,57+breathe}},'clothDeep','ink',2)
 path(detail,{{68,54+breathe},{77,62+wave},{83,70+wave},{94,74+wave}},'cloth',3);line(detail,81,68+wave,89,72+wave,'clothLight',2)
 poly(detail,{{92,72+wave},{96,76+wave},{94,79+wave},{90,75+wave}},'goldShadow');dot(detail,93,74+wave,'gold')
 -- Feathered forearms with gold bracers and taloned grips are cropped in plan view.
 poly(detail,{{29,64},{36,69},{33,77+sway},{27,80+sway},{22,76+sway},{23,70}},'featherDeep','ink',2)
 path(detail,{{26,68},{32,71},{29,77+sway}},'goldShadow',3);line(detail,26,68,31,70,'goldLight')
 poly(detail,{{78,67},{85,64},{91,71-sway},{90,79-sway},{84,81-sway},{79,75}},'featherDeep','ink',2)
 path(detail,{{82,69},{87,68},{89,76-sway}},'goldShadow',3);line(detail,84,69,87,70,'goldLight')
 -- Sword rests outward to port; the bright edge is a long distinct silhouette.
 poly(sword,{{15,28+sway},{21,37+sway},{27,73+sway},{32,78+sway},{25,81+sway},{19,77+sway},{22,73+sway}},'steelDark','ink',2)
 poly(sword,{{16,31+sway},{18,37+sway},{25,73+sway},{23,74+sway}},'steel');line(sword,16,32+sway,23,71+sway,'steelLight')
 poly(sword,{{18,73+sway},{24,74+sway},{31,72+sway},{34,75+sway},{26,80+sway},{19,78+sway}},'gold','ink');line(sword,19,74+sway,24,76+sway,'goldLight')
 line(sword,26,80+sway,29,90+sway,'ink',6);line(sword,26,80+sway,29,90+sway,'clothDeep',4)
 for k=0,2 do line(sword,25+k,81+k*3+sway,28+k,81+k*3+sway,'goldShadow') end
 ring(sword,30,92+sway,3,'gold','ink');dot(sword,29,91+sway,'goldLight')
 -- Tall recurved bow and taut string. They remain idle; no arrow is nocked.
 local q=-sway
 path(bow,{{89,31+q},{96,42+q},{100,53+q},{98,64+q},{91,75+q},{88,87+q},{92,96+q}},'ink',5)
 path(bow,{{89,31+q},{96,42+q},{100,53+q},{98,64+q},{91,75+q},{88,87+q},{92,96+q}},'goldShadow',3)
 path(bow,{{90,32+q},{97,43+q},{100,52+q}},'goldLight',1);path(bow,{{90,78+q},{88,87+q},{92,94+q}},'gold',1)
 line(bow,89,31+q,83,63+q,'steel');line(bow,83,63+q,92,96+q,'steel')
 path(bow,{{98,60+q},{95,68+q},{92,73+q}},'clothDeep',5);path(bow,{{97,60+q},{94,68+q}},'cloth',3)
 for k=0,2 do line(bow,96-k,61+k*3+q,98-k,63+k*3+q,'goldShadow') end
 if phase==3 or phase==4 then dot(detail,36,47+breathe,'goldHot') end
end
local durations={};for section=1,3 do for f=1,8 do durations[#durations+1]=200 end;for f=1,6 do durations[#durations+1]=300 end end
create(draw,{'01 Changing outfit robe panels','02 Raven back and harness','03 Quiver and red fletched arrows','04 Layered feather mantle','05 Raven crown crest and beak roof','06 Idle sword','07 Recurved bow and string','08 Bandanna ribbons bracers and clasps'},{name='Thief',description='A raven ninja seen from directly above, wearing a feather mantle, gold-trimmed cloth, long trailing ribbons and a quiver while carrying a sword and bow.',count=42,durations=durations,default_state='cycle',states={{id='cycle',first=1,last=42},{id='obsidian',first=1,last=8},{id='crimson',first=15,last=22},{id='indigo',first=29,last=36}},visual_states={{id='cycle',name='Outfit cycle',tag='idle',description='A 10.2-second continuous sequence across all three costumes, with six gradual transition poses between each.'},{id='obsidian',name='Obsidian',tag='obsidian',description='Compact dark neutral robes and short feather drape; gold equipment and raven crest stay readable.'},{id='crimson',name='Crimson',tag='crimson',description='Burgundy cloth and longer trailing drape echo the portrait scarf.'},{id='indigo',name='Indigo',tag='indigo',description='Cool indigo cloth and medium feather drape retain the same raven and weapons.'}},notes={'Portrait establishes raven feathers, burgundy scarf, gold trim, sword, bow and red-fletched quiver. Obsidian and indigo are requested outfit variants.','Each outfit has eight distinct 200-ms poses per direction. Six 300-ms transition frames interpolate authored OKLCH cloth ramps and cloth/feather silhouette length between outfits.','cycle_n/e/s/w and idle_n/e/s/w are aliases over the same 42-frame, 10200-ms continuous outfit cycle. Single-outfit tags loop independently at 1600 ms.','All four cardinal directions are exact rotations. No frontal eyes, face, standing legs, attacks, collision or stats are included.','Native source remains authoritative after manual edits; this construction script is retained as provenance and is not an automatic rebuild step.'}})
