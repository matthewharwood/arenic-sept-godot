-- Native Aseprite authoring/export. Existing hand-edited masters remain authority.
-- aseprite --batch --script-param root=/absolute/repo --script assets/pipeline/build-ghost-death.lua
-- Pass rebuild=true only to deliberately replace the master from this pixel score.
local root=assert(app.params.root,'root is required')..'/'
local folder=root..'assets/fx/ghost_death/'
local runtime=root..'arenic-game/assets/fx/ghost_death/'
local preview=folder..'previews/'
for _,path in ipairs({folder,runtime,preview}) do app.fs.makeAllDirectories(path) end
local source=folder..'ghost_death.aseprite'
local W,N,BURST=57,28,12
local palette={
 {name='smoke edge',oklch={.42,.032,285},alpha=48},
 {name='smoke violet',oklch={.59,.043,292},alpha=78},
 {name='spirit shadow',oklch={.60,.030,278},alpha=100},
 {name='spirit body',oklch={.76,.025,282},alpha=146},
 {name='spirit fold',oklch={.90,.014,268},alpha=184},
 {name='spirit glimmer',oklch={.97,.013,240},alpha=206},
 {name='hollow',oklch={.27,.036,282},alpha=82},
 {name='blood dark',oklch={.35,.115,23},alpha=245},
 {name='blood red',oklch={.49,.180,27},alpha=255},
 {name='blood light',oklch={.67,.145,31},alpha=255},
 {name='bone shadow',oklch={.60,.038,72},alpha=255},
 {name='bone ivory',oklch={.88,.035,89},alpha=255},
 {name='bone gleam',oklch={.98,.019,94},alpha=255},
 {name='preview ground only',oklch={.23,.024,278},alpha=255},
}
local function color(index,opacity)
 local p=palette[index];local L,C,H=table.unpack(p.oklch)
 local a=C*math.cos(math.rad(H));local b=C*math.sin(math.rad(H))
 local l=(L+.3963377774*a+.2158037573*b)^3
 local m=(L-.1055613458*a-.0638541728*b)^3
 local s=(L-.0894841775*a-1.291485548*b)^3
 local function enc(v) return math.floor(math.max(0,math.min(1,v<=.0031308 and 12.92*v or 1.055*v^(1/2.4)-.055))*255+.5) end
 return Color{r=enc(4.0767416621*l-3.3077115913*m+.2309699292*s),g=enc(-1.2684380046*l+2.6097574011*m-.3413193965*s),b=enc(-.0041960863*l-.7034186147*m+1.707614701*s),a=math.floor(p.alpha*(opacity or 1)+.5)}.rgbaPixel
end
local function pixel(im,x,y,c)
 x=math.floor(x+.5);y=math.floor(y+.5)
 assert(x>=0 and y>=0 and x<W and y<W,'particle left its transparent canvas')
 im:drawPixel(x,y,c)
end
local function line(im,x0,y0,x1,y1,c)
 local steps=math.max(math.abs(x1-x0),math.abs(y1-y0),1)
 for i=0,steps do pixel(im,x0+(x1-x0)*i/steps,y0+(y1-y0)*i/steps,c) end
end
-- An asymmetric, torn shroud with a curled tail. Letters are deliberate pixel
-- clusters; no ellipses, smoothing, stochastic noise, or per-frame resampling.
local shroud={
 '.........abbbb..........',
 '.......abbccdcba........',
 '......abcdeddedcb.......',
 '.....abcdeeffedccba.....',
 '....abcdeffeedddcba.....',
 '...abbcdeeddddddccb.....',
 '...abcdedddcccdddcb.....',
 '..abcdeedccbbcccddcba...',
 '..abcdedcbbaabccddccb...',
 '.abbcddcbba..abccddcba..',
 '.abcdddcba....abccddcb..',
 'abccdddcba....abccddcba.',
 '.bcddddccba..abbccddcba.',
 '..bcddddccbaabbccdddcb..',
 '...bcdddccccbccddddcb...',
 '...abccddddccddddccb....',
 '....abbccddddddccba.....',
 '.....abbcdddddccba......',
 '......abccddddcba.......',
 '.......abcdedcba.......a',
 '.......abcdedcb......aba',
 '......abccddcba.....abba',
 '.....abbccdcba....abbba.',
 '.....abccdcba...abbcba..',
 '......bccdcbaabbcccba...',
 '.......bccddccccccba....',
 '........bbcccccbbba.....',
 '..........bbbbbaa.......',
}
local symbols={a=1,b=2,c=3,d=4,e=5,f=6}
local function spirit(images,phase,opacity,rise)
 local mist,body,fold=images[1],images[4],images[5]
 local angle=phase*math.pi*2/16
 for row,pattern in ipairs(shroud) do
  -- Opposing upper/lower currents reshape the hem without moving the anchor.
  local dx=math.floor(math.sin(angle+(row-1)*.13)*.85+.5)
  local dy=math.floor(math.sin(angle)*.65+.5)+(rise or 0)
  for col=1,#pattern do
   local index=symbols[pattern:sub(col,col)]
   if index then
    local target=index<=2 and mist or (index>=5 and fold or body)
    pixel(target,16+col+dx,10+row+dy,color(index,opacity))
   end
  end
 end
 -- Detached hooked vapour curls, staggered so the loop breathes, not flickers.
 for side=-1,1,2 do
  local shift=math.floor(math.sin(angle+side)*1.1+.5)
  local points=side<0 and {{15,23},{14,22},{13,22},{12,23},{12,25},{13,26},{14,26},{14,28}}
   or {{40,26},{42,26},{43,25},{43,23},{42,22},{41,22}}
  for i=1,#points-1 do
   line(mist,points[i][1],points[i][2]+shift,points[i+1][1],points[i+1][2]+shift,color(2,opacity*.75))
  end
 end
end
local particles={
 {angle=-166,radius=17,kind='bone',spin=0},
 {angle=-119,radius=21,kind='blood',spin=1},
 {angle=-70,radius=16,kind='bone',spin=2},
 {angle=-26,radius=21,kind='blood',spin=3},
 {angle=13,radius=15,kind='bone',spin=1},
 {angle=54,radius=21,kind='blood',spin=0},
 {angle=99,radius=18,kind='bone',spin=3},
 {angle=144,radius=21,kind='blood',spin=2},
 {angle=-144,radius=10,kind='blood',spin=1},
 {angle=-41,radius=11,kind='blood',spin=2},
 {angle=75,radius=12,kind='blood',spin=0},
}
local bone={
 {{-2,-1},{-2,0},{-1,-1},{-1,0},{0,0},{1,0},{2,0},{2,1},{3,0},{3,1}},
 {{-1,-2},{0,-2},{-1,-1},{0,0},{1,1},{1,2},{2,1},{2,2}},
 {{-1,-2},{0,-2},{0,-1},{0,0},{0,1},{-1,2},{0,2},{1,2}},
 {{-2,1},{-1,1},{-1,0},{0,0},{1,-1},{1,-2},{2,-1},{2,-2}},
}
local function burst(images,f)
 local progress=(f-1)/10
 local fade=math.max(0,math.min(1,(11-f)/4))
 if fade<=0 then return end
 for i,p in ipairs(particles) do
  local t=math.min(1,progress*(1.10+(i%3)*.08))
  local radius=2+p.radius*(1-(1-t)^2)
  local a=math.rad(p.angle)
  local x=28+math.cos(a)*radius
  local y=28+math.sin(a)*radius+3*t*t
  if p.kind=='bone' then
   local shape=bone[(p.spin+math.floor(t*3))%4+1]
   for j,point in ipairs(shape) do pixel(images[3],x+point[1],y+point[2],color(j%3==0 and 11 or 12,fade)) end
   pixel(images[3],x,y,color(13,fade))
  else
   local dx,dy=math.cos(a),math.sin(a)
   line(images[2],x-dx*2,y-dy*2,x,y,color(8,fade))
   pixel(images[2],x,y,color(9,fade));pixel(images[2],x+1,y,color(9,fade))
   pixel(images[2],x,y-1,color(10,fade))
   if f>=3 and f<=7 then pixel(images[2],x-dx*4+1,y-dy*4,color(9,fade*.7)) end
  end
 end
 -- Four ragged impact shards appear briefly at the core; they dissolve as the
 -- hollow shroud rises, so the last burst cel is exactly the first loop cel.
 if f<=4 then
  local alpha=(5-f)/4
  for i=0,3 do
   local a=math.rad(i*90+25)
   line(images[5],28+math.cos(a)*2,28+math.sin(a)*2,28+math.cos(a)*(6+f),28+math.sin(a)*(6+f),color(12,alpha))
  end
 end
end
if not app.fs.isFile(source) or app.params.rebuild=='true' then
 local s=Sprite(W,W,ColorMode.RGB)
 local names={'Smoke wisps','Blood droplets','Bone fragments','Spirit shroud','Rim and impact light'}
 s.layers[1].name=names[1]
 for i=2,#names do local layer=s:newLayer();layer.name=names[i] end
 for f=1,N do
  if f>1 then s:newEmptyFrame() end
  s.frames[f].duration=f<=BURST and .065 or .125
  local images={}
  for i=1,#names do images[i]=Image(W,W,ColorMode.RGB) end
  if f<=BURST then
   if f>=3 then spirit(images,0,math.min(1,(f-2)/8),math.max(0,7-f)) end
   burst(images,f)
  else spirit(images,f-BURST-1,1,0) end
  for i,image in ipairs(images) do s:newCel(s.layers[i],f,image,Point(0,0)) end
 end
 for _,row in ipairs({{'burst',1,BURST},{'spirit',BURST+1,N}}) do local tag=s:newTag(row[2],row[3]);tag.name=row[1] end
 local slice=s:newSlice(Rectangle(0,0,W,W));slice.name='frame';slice.pivot=Point(28,28)
 s.data='57px hero death FX. burst is one-shot; spirit loops until the authoritative arena cycle resets. Fixed ground anchor (28,28).'
 local colors=Palette(#palette+1);colors:setColor(0,Color{r=0,g=0,b=0,a=0})
 for i=1,#palette do colors:setColor(i,Color(color(i))) end
 s:setPalette(colors)
 s:saveAs(source);s:close()
end
local sprite=app.open(source)
assert(sprite.width==W and sprite.height==W and #sprite.frames==N,'unexpected saved source contract')
assert(#sprite.tags==2 and sprite.tags[1].name=='burst' and sprite.tags[2].name=='spirit','unexpected tags')
assert(sprite.tags[1].fromFrame.frameNumber==1 and sprite.tags[1].toFrame.frameNumber==12
 and sprite.tags[2].fromFrame.frameNumber==13 and sprite.tags[2].toFrame.frameNumber==28,'unexpected saved tag ranges')
assert(#sprite.slices==1 and sprite.slices[1].name=='frame'
 and sprite.slices[1].bounds==Rectangle(0,0,W,W)
 and sprite.slices[1].pivot==Point(28,28),'unexpected saved frame slice or pivot')
local atlas=Image(W*7,W*4,ColorMode.RGB)
local frames={}
for f=1,N do
 local im=Image(W,W,ColorMode.RGB);im:drawSprite(sprite,f)
 local x=((f-1)%7)*W;local y=math.floor((f-1)/7)*W
 atlas:drawImage(im,Point(x,y))
 frames[f]={filename='ghost_death '..(f-1),frame={x=x,y=y,w=W,h=W},rotated=false,trimmed=false,spriteSourceSize={x=0,y=0,w=W,h=W},sourceSize={w=W,h=W},duration=math.floor(sprite.frames[f].duration*1000+.5)}
end
local tags={{name='burst',from=0,to=11,direction='forward'},{name='spirit',from=12,to=27,direction='forward'}}
local layers={};for _,layer in ipairs(sprite.layers) do table.insert(layers,{name=layer.name,opacity=layer.opacity,blendMode='normal'}) end
local metadata={frames=frames,meta={
 app='Aseprite native Lua',version=tostring(app.version),image='ghost_death.png',
 format='RGBA8888',size={w=W*7,h=W*4},scale='1',frameTags=tags,layers=layers,
 slices={{name='frame',keys={{frame=0,bounds={x=0,y=0,w=W,h=W},pivot={x=28,y=28}}}}},
}}
local function write(path,value) local file=assert(io.open(path,'w'));file:write(value);file:close() end
for _,target in ipairs({runtime,preview}) do atlas:saveAs(target..'ghost_death.png');write(target..'ghost_death.json',json.encode(metadata)) end
write(folder..'palette.oklch.json',json.encode({space='oklch',colors=palette}))
local lines={'[gd_resource type="SpriteFrames" load_steps=30 format=3]','','[ext_resource type="Texture2D" path="res://assets/fx/ghost_death/ghost_death.png" id="1"]',''}
for i=0,N-1 do table.insert(lines,string.format('[sub_resource type="AtlasTexture" id="Frame_%d"]\natlas = ExtResource("1")\nregion = Rect2(%d, %d, 57, 57)\nfilter_clip = true\n',i,(i%7)*W,math.floor(i/7)*W)) end
table.insert(lines,'[resource]\nanimations = [')
for ti,tag in ipairs(tags) do
 local sequence={}
 for i=tag.from,tag.to do table.insert(sequence,string.format('{"duration": %d.0, "texture": SubResource("Frame_%d")}',frames[i+1].duration,i)) end
 table.insert(lines,string.format('{"frames": [%s], "loop": %s, "name": &"%s", "speed": 1000.0}%s',table.concat(sequence,', '),tag.name=='spirit' and 'true' or 'false',tag.name,ti==#tags and '' or ','))
end
table.insert(lines,']\n');write(runtime..'ghost_death_frames.tres',table.concat(lines,'\n'))
local import=runtime..'ghost_death.png.import'
if not app.fs.isFile(import) then write(import,'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\nmipmaps/generate=false\ndetect_3d/compress_to=0\nprocess/fix_alpha_border=false\nprocess/premult_alpha=false\nprocess/size_limit=0\n') end
-- GIF cannot retain graded alpha: composite a separate review copy onto slate
-- in Aseprite. The runtime PNG and editable source remain fully transparent.
for _,tag in ipairs(tags) do
 local review=Sprite(W,W,ColorMode.RGB)
 for index=tag.from,tag.to do
  local f=index-tag.from+1
  if f>1 then review:newEmptyFrame() end
  -- GIF uses centiseconds; alternate the two nearest holds to retain each
  -- tag's total duration while the master/PNG metadata keep exact milliseconds.
  local duration=sprite.frames[index+1].duration*100
  review.frames[f].duration=(f%2==1 and math.floor(duration) or math.ceil(duration))/100
  local im=Image(W,W,ColorMode.RGB)
  for it in im:pixels() do it(color(14)) end
  im:drawSprite(sprite,index+1)
  review:newCel(review.layers[1],f,im,Point(0,0))
 end
 review:resize(W*6,W*6)
 review:saveCopyAs(preview..tag.name..'.gif');review:close()
end
local html=[=[<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ghost death · Arenic FX</title><style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:oklch(0.17 .018 278);color:oklch(.9 .012 278)}
body{max-width:1000px;margin:40px auto;padding:0 24px}h1{font-size:32px;margin-bottom:8px}p{line-height:1.5;color:oklch(.73 .02 278)}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}.view{padding:20px;background:oklch(.23 .024 278);border:1px solid oklch(.4 .03 278)}
.light{background:oklch(.77 .021 81);color:oklch(.23 .024 278)}canvas,img{image-rendering:pixelated;display:block;margin:auto}canvas{width:342px;height:342px;max-width:100%}
.native{width:57px;height:57px}.controls{display:flex;gap:12px;flex-wrap:wrap;margin:20px 0}button{font:inherit;padding:10px 16px;cursor:pointer;background:oklch(.32 .04 278);color:inherit;border:1px solid oklch(.58 .06 278)}
label{display:flex;gap:10px;align-items:center}.caption{font-size:13px}details{margin-top:28px}a{color:oklch(.8 .09 285)}@media(max-width:700px){.grid{grid-template-columns:1fr}}
</style><h1>Ghost death</h1><p>A brief fracture of ivory and red settles into a hollow, wind-torn spirit.<br>57 × 57 native pixels · fixed pivot (28, 28) · five editable layers.</p>
<div class="controls"><button id="restart">Replay death</button><button id="pause">Pause</button><label>Frame <input id="scrub" type="range" min="0" max="27" value="0"><output id="readout"></output></label></div>
<div class="grid"><section class="view"><canvas width="57" height="57"></canvas><p class="caption">6× • graded alpha against slate</p></section><section class="view light"><canvas width="57" height="57"></canvas><p class="caption">6× • graded alpha against warm arena stone</p></section></div>
<section class="view" style="margin-top:20px"><canvas class="native" width="57" height="57"></canvas><p class="caption">Native 1× • a hero occupies a 19 × 19 cell. The canvas is transparent breathing room, not a gameplay footprint.</p></section>
<p><b>Burst:</b> 12 frames, 780 ms, once. <b>Spirit:</b> 16 frames, 2 seconds, repeats until the arena loop resets. Final burst and first spirit frame are identical. No residual blood or bone remains in the looping tag.</p>
<details><summary>Editable source and motion references</summary><p><a href="../ghost_death.aseprite">Native Aseprite master</a> · <a href="ghost_death.png">Transparent atlas</a> · <a href="ghost_death.json">Metadata</a></p><div class="grid"><img src="burst.gif" width="342" height="342" alt="Burst timing on slate"><img src="spirit.gif" width="342" height="342" alt="Looping spirit on slate"></div><p class="caption">GIF references use a slate matte because GIF cannot preserve graded transparency. The canvas player uses the actual RGBA runtime atlas.</p></details>
<script>const data=__DATA__;const atlas=new Image();atlas.src='ghost_death.png';const canvases=[...document.querySelectorAll('canvas')];const scrub=document.querySelector('#scrub'),readout=document.querySelector('#readout');let frame=0,elapsed=0,last=0,paused=false;function render(){for(const canvas of canvases){const c=canvas.getContext('2d');c.imageSmoothingEnabled=false;c.clearRect(0,0,57,57);const r=data.frames[frame].frame;c.drawImage(atlas,r.x,r.y,r.w,r.h,0,0,57,57)}scrub.value=frame;readout.value=`${frame+1} / 28 · ${frame<12?'burst':'spirit'}`;}function tick(now){if(last&&!paused){elapsed+=Math.min(now-last,100);while(elapsed>=data.frames[frame].duration){elapsed-=data.frames[frame].duration;frame=frame===27?12:frame+1}}last=now;if(atlas.complete)render();requestAnimationFrame(tick)}document.querySelector('#restart').onclick=()=>{frame=0;elapsed=0;paused=false;document.querySelector('#pause').textContent='Pause'};document.querySelector('#pause').onclick=e=>{paused=!paused;e.target.textContent=paused?'Play':'Pause'};scrub.oninput=()=>{frame=Number(scrub.value);elapsed=0;paused=true;document.querySelector('#pause').textContent='Play';render()};requestAnimationFrame(tick);</script></html>]=]
html=html:gsub('__DATA__',function() return json.encode(metadata) end)
write(preview..'index.html',html)
print('Ghost death exported: '..W..'x'..W..', 28 frames, five editable layers; burst=780ms, spirit=2000ms; pivot28,28; 399x228 RGBA atlas.')
sprite:close()
