-- Native authoring of the Keeper and the Guild Gate. Saved masters always win.
-- aseprite --batch --script-param root=/absolute/repository --script-param asset=gate --script assets/pipeline/build-prologue-art.lua
-- Reconstruct only into an empty destination. After manual edits, export the master.
local root = assert(app.params.root, 'root is required') .. '/'
local chosen = assert(app.params.asset, 'asset must be gate or keeper')
local function read(path)
  local file = assert(io.open(path, 'r')); local data = file:read('*a'); file:close(); return data
end
local function palette(path)
  local result, swatches = {}, {}
  for _, entry in ipairs(json.decode(read(path)).colors) do
    local L,C,H = table.unpack(entry.oklch)
    local a,b = C*math.cos(math.rad(H)), C*math.sin(math.rad(H))
    local l = (L+.3963377774*a+.2158037573*b)^3
    local m = (L-.1055613458*a-.0638541728*b)^3
    local s = (L-.0894841775*a-1.291485548*b)^3
    local function encode(v)
      return math.floor(math.max(0,math.min(1,v<=.0031308 and 12.92*v or 1.055*v^(1/2.4)-.055))*255+.5)
    end
    local color = Color{r=encode(4.0767416621*l-3.3077115913*m+.2309699292*s),
      g=encode(-1.2684380046*l+2.6097574011*m-.3413193965*s),
      b=encode(-.0041960863*l-.7034186147*m+1.707614701*s),a=math.floor((entry.alpha or 1)*255+.5)}
    result[entry.id] = color.rgbaPixel; table.insert(swatches, color)
  end
  return result,swatches
end
local function setup(w,h,names,swatches)
  local sprite=Sprite(w,h,ColorMode.RGB); sprite.gridBounds=Rectangle(0,0,19,19)
  sprite.layers[1].name=names[1]
  for i=2,#names do local layer=sprite:newLayer();layer.name=names[i] end
  local p=sprite.palettes[1];p:resize(#swatches+1);p:setColor(0,Color{r=0,g=0,b=0,a=0})
  for i,color in ipairs(swatches) do p:setColor(i,color) end
  return sprite
end
local function pixel(im,x,y,color)
  if x>=0 and x<im.width and y>=0 and y<im.height then im:drawPixel(x,y,color) end
end
local function rect(im,x,y,w,h,color)
  for yy=y,y+h-1 do for xx=x,x+w-1 do pixel(im,xx,yy,color) end end
end
local function diamond(im,x,y,r,color)
  for yy=-r,r do for xx=-(r-math.abs(yy)),r-math.abs(yy) do pixel(im,x+xx,y+yy,color) end end
end
local function tag(sprite,name,first,last,loop)
  local t=sprite:newTag(first,last);t.name=name;t.data=json.encode({loop=loop})
end
local function finish(sprite,source,pivot)
  local slice=sprite:newSlice(Rectangle(0,0,sprite.width,sprite.height))
  slice.name='frame';slice.pivot=Point(pivot[1],pivot[2])
  sprite.data=json.encode({perspective='true overhead orthographic',pixel_scale=1,save_authority=false})
  sprite:saveAs(source);sprite:close();print('Saved native master: '..source)
end

local function gate()
  local folder=root..'assets/environment/guild_gate/'
  app.fs.makeAllDirectories(folder)
  local source=folder..'guild_gate.aseprite'
  if app.fs.isFile(source) then print('Preserving existing master: '..source);return end
  local p,swatches=palette(folder..'palette.oklch.json')
  local sprite=setup(57,38,{'Ground shadow','Threshold stone','Left gold leaf','Right gold leaf','Carved hinge posts','Lock and clasp'},swatches)
  -- Each carved leaf is drawn in its own local 23x7 coordinates, then sampled
  -- once onto the native grid around a fixed hinge. There is no camera tilt.
  local function leaf_pixel(u,v)
    if u<0 or u>22 or math.abs(v)>3 then return nil end
    if u==0 or u==22 or math.abs(v)==3 then return p.ink end
    if u==1 or u==21 then return v<1 and p.gold_light or p.gold_dark end
    if v==-2 then return p.gold_light end
    if v==2 then return p.gold_dark end
    if v==0 and u>=3 and u<=19 then
      if u%4==0 then return p.gold_light end
      return p.gold
    end
    if math.abs(v)==1 and (u==4 or u==8 or u==12 or u==16 or u==19) then return p.gold end
    if v==-1 then return p.violet_light end
    return p.recess
  end
  local function leaf(im,hinge_x,mirror,angle)
    local c,s=math.cos(angle),math.sin(angle)
    for y=2,34 do for x=0,56 do
      local dx=(x-hinge_x)*mirror;local dy=y-28
      local u=math.floor(dx*c-dy*s+.5)
      local v=math.floor(dx*s+dy*c+.5)
      local color=leaf_pixel(u,v)
      if color then pixel(im,x,y,color) end
    end end
  end
  -- Two quiet locked holds; ten 140ms opening frames; a stable open endpoint.
  for f=1,13 do
    if f>1 then sprite:newEmptyFrame() end
    sprite.frames[f].duration = f<=2 and .8 or (f==13 and 1 or .14)
    local images={};for _=1,6 do table.insert(images,Image(57,38,ColorMode.RGB)) end
    local S,T,L,R,P,C=table.unpack(images)
    rect(S,2,27,53,10,p.shadow)
    -- Worn threshold slabs have deliberate joints and chipped outer corners.
    rect(T,4,28,49,8,p.ink);rect(T,3,30,51,5,p.stone_shadow)
    rect(T,5,29,47,5,p.stone);rect(T,6,29,45,1,p.stone_light)
    rect(T,5,34,47,1,p.ink)
    for _,x in ipairs({14,28,42}) do rect(T,x,30,1,4,p.stone_shadow) end
    for _,q in ipairs({{9,32},{20,31},{37,33},{46,31}}) do pixel(T,q[1],q[2],p.stone_light) end
    local progress = f<=2 and 0 or (f==13 and 1 or (f-3)/9)
    local angle=(progress*progress*(3-2*progress))*math.pi/2
    leaf(L,6,1,angle);leaf(R,50,-1,angle)
    for _,x in ipairs({6,50}) do
      rect(P,x-3,24,7,9,p.ink);rect(P,x-2,24,5,7,p.gold_dark)
      rect(P,x-2,24,5,1,p.gold_light);rect(P,x-2,25,1,5,p.gold)
      diamond(P,x,27,3,p.ink);diamond(P,x,27,2,p.gold);diamond(P,x,27,1,p.violet)
      pixel(P,x,26,p.gold_light);pixel(P,x-1,27,p.glint);pixel(P,x,28,p.gold_dark)
      rect(P,x-2,31,5,1,p.gold)
    end
    if progress==0 then
      diamond(C,28,28,3,p.ink);diamond(C,28,28,2,p.gold);diamond(C,28,28,1,p.gold_dark)
      pixel(C,28,27,f==2 and p.glint or p.gold_light);pixel(C,28,29,p.ink)
    end
    for i,im in ipairs(images) do sprite:newCel(sprite.layers[i],f,im,Point(0,0)) end
  end
  tag(sprite,'locked',1,2,true);tag(sprite,'opening',3,12,false);tag(sprite,'open',13,13,true)
  finish(sprite,source,{28,28})
end

local function keeper()
  local folder=root..'assets/npcs/keeper/'
  app.fs.makeAllDirectories(folder)
  local source=folder..'keeper.aseprite'
  if app.fs.isFile(source) then print('Preserving existing master: '..source);return end
  assert(app.fs.isFile(folder..'portrait.png'),'Review the selected portrait before constructing the Keeper')
  local p,swatches=palette(folder..'palette.oklch.json')
  local sprite=setup(19,19,{'Ground shadow','Ink violet mantle','Ivory collar','Beckoning sleeve and hand','Gold clasp and eightfold stitching','Silver crown and topknot'},swatches)
  local function stamp(im,x,y,rows,colors)
    for yy,row in ipairs(rows) do for xx=1,#row do
      local color=colors[row:sub(xx,xx)]
      if color then pixel(im,x+xx-1,y+yy-1,color) end
    end end
  end
  local inkmap={i=p.ink,s=p.robe_shadow,r=p.robe,l=p.robe_light,e=p.robe_edge}
  local durations={180,140,140,220,140,180,160,240}
  local directions={'n','e','s','w'}
  local tags={}
  local frame=0
  for mode=1,2 do
    local count=mode==1 and 4 or 8
    for d=0,3 do
      local first=frame+1
      for phase=1,count do
        frame=frame+1;if frame>1 then sprite:newEmptyFrame() end
        sprite.frames[frame].duration=(mode==1 and ({450,150,450,150})[phase] or durations[phase])/1000
        local images={};for _=1,6 do table.insert(images,Image(19,19,ColorMode.RGB)) end
        local S,B,I,A,G,H=table.unpack(images)
        stamp(S,3,7,{'  sssssssss',' sssssssssss','sssssssssssss','sssssssssssss',' sssssssssss','  sssssssss','   sssssss'},{s=p.shadow})
        -- Crown occludes the collar. The short bell-shaped mantle is seen from
        -- directly above; there are no facial pixels, frontal torso or boots.
        stamp(B,3,7,{
          '    iiiii    ',
          '  iirrlrrii  ',
          ' ilerlrlrrli ',
          'ilrrrsrsrrrli',
          'ilrssrssrsrri',
          ' isrsrlrsrsi ',
          '  irslrlrsi  ',
          '  ilrlslrri  ',
          '   issrssi   ',
          '    iiiii    '
        },inkmap)
        if mode==1 and (phase==2 or phase==3) then
          pixel(B,6,13,p.robe_light);pixel(B,12,14,p.robe_light);pixel(B,8,15,p.robe)
        end
        stamp(I,6,8,{' c   c ','ci   ic',' ciiic ','  ccc  '},{c=p.ivory_shadow,i=p.ivory})
        -- At rest the open hand sits just ahead of the right shoulder. The
        -- beckon extends the elbow, then curls the hand inward, with a long hold.
        local hand_y=7;local hand_x=15
        if mode==2 then
          hand_y=({7,6,5,4,5,5,6,7})[phase]
          hand_x=({15,15,15,14,14,15,15,15})[phase]
        end
        stamp(A,12,8,{' iii ','irlli','islri',' isri','  ii '},inkmap)
        for y=hand_y+2,9 do
          pixel(A,14,y,p.ink);pixel(A,15,y,p.robe_light);pixel(A,16,y,p.robe_shadow)
        end
        stamp(A,hand_x-1,hand_y,{' h ','hhk',' ch','iri'},{h=p.skin,k=p.skin_shadow,c=p.ivory,i=p.ink,r=p.robe})
        -- A three-pixel shoulder brooch echoes the portrait's eight spokes.
        stamp(G,4,9,{' gg','gog',' gg'},{g=p.gold,o=p.gold_shadow})
        pixel(G,5,9,p.gold_light)
        for _,q in ipairs({{6,12},{7,13},{8,14},{9,15},{10,14},{11,13},{12,12},{13,11}}) do
          pixel(G,q[1],q[2],p.gold_shadow)
        end
        -- Silver crown, asymmetric swept part and a tiny rear knot. Highlights
        -- follow the authored head, so cardinal variants are exact rotations.
        stamp(H,6,3,{
          '  hhh  ',
          ' hlllsh',
          'hlllhsh',
          'hllhhsh',
          'hhlhssh',
          ' hhhsh ',
          '  hsh  ',
          '  slh  ',
          '  hsh  ',
          '   h   '
        },{h=p.hair,s=p.hair_shadow,l=p.hair_light})
        for i,im in ipairs(images) do
          for _=1,d do
            local turned=Image(19,19,ColorMode.RGB)
            for it in im:pixels() do turned:drawPixel(18-it.y,it.x,it()) end
            im=turned
          end
          sprite:newCel(sprite.layers[i],frame,im,Point(0,0))
        end
      end
      table.insert(tags,{(mode==1 and 'idle_' or 'beckon_')..directions[d+1],first,frame,mode==1})
    end
  end
  -- Aseprite extends a tag ending at the current final frame when appending
  -- another frame, so define ranges only after the complete timeline exists.
  for _,definition in ipairs(tags) do tag(sprite,table.unpack(definition)) end
  finish(sprite,source,{9,9})
end

if chosen=='gate' then gate()
elseif chosen=='keeper' then keeper()
else error('asset must be gate or keeper') end
