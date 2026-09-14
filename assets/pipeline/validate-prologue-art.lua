-- Read-only validation of saved native sources, before runtime export.
local root=assert(app.params.root)..'/'
local function check(identifier,path,w,h,pivot,definitions)
  local s=assert(app.open(root..path))
  assert(s.width==w and s.height==h,identifier..': wrong canvas')
  assert(#s.layers==6,identifier..': keep six independently editable layers')
  assert(#s.slices==1 and s.slices[1].name=='frame',identifier..': frame slice required')
  assert(s.slices[1].pivot.x==pivot[1] and s.slices[1].pivot.y==pivot[2],identifier..': wrong pivot')
  local tags={};for _,t in ipairs(s.tags) do tags[t.name]=t end
  assert(#s.tags==#definitions,identifier..': unexpected tags')
  local coverage={}
  for _,definition in ipairs(definitions) do
    local t=assert(tags[definition[1]],identifier..': missing '..definition[1])
    assert(t.fromFrame.frameNumber==definition[2] and t.toFrame.frameNumber==definition[3],identifier..': tag bounds '..t.name)
    local total=0
    for f=definition[2],definition[3] do
      assert(not coverage[f],identifier..': overlapping tags');coverage[f]=true
      total=total+math.floor(s.frames[f].duration*1000+.5)
    end
    assert(total==definition[4],identifier..': native timing '..t.name)
  end
  assert(#coverage==#s.frames,identifier..': uncovered frames')
  local images={}
  for f=1,#s.frames do
    local im=Image(w,h,ColorMode.RGB);im:drawSprite(s,f);images[f]=im
    local pixels=0
    for it in im:pixels() do
      if app.pixelColor.rgbaA(it())>0 then
        pixels=pixels+1
        assert(it.x>0 and it.x<w-1 and it.y>0 and it.y<h-1,identifier..': clipped canvas edge')
      end
    end
    assert(pixels>40,identifier..': missing artwork')
  end
  local function equal(a,b,rotate)
    for it in a:pixels() do
      local x,y=it.x,it.y
      if rotate then x,y=w-1-y,x end
      assert(it()==b:getPixel(x,y),identifier..': mismatched rotation/endpoint')
    end
  end
  if identifier=='keeper' then
    for phase=1,4 do for direction=0,2 do equal(images[phase+direction*4],images[phase+(direction+1)*4],true) end end
    for phase=1,8 do for direction=0,2 do equal(images[16+phase+direction*8],images[16+phase+(direction+1)*8],true) end end
    for direction=0,3 do
      equal(images[1+direction*4],images[17+direction*8],false)
      equal(images[1+direction*4],images[24+direction*8],false)
    end
  else
    equal(images[1],images[3],false);equal(images[12],images[13],false)
  end
  print(identifier..': '..#s.frames..' frames; canvas/pivot/tags/timing/alpha and motion endpoints verified')
  s:close()
end
check('keeper','assets/npcs/keeper/keeper.aseprite',19,19,{9,9},{
  {'idle_n',1,4,1200},{'idle_e',5,8,1200},{'idle_s',9,12,1200},{'idle_w',13,16,1200},
  {'beckon_n',17,24,1400},{'beckon_e',25,32,1400},{'beckon_s',33,40,1400},{'beckon_w',41,48,1400}})
check('guild_gate','assets/environment/guild_gate/guild_gate.aseprite',57,38,{28,28},{
  {'locked',1,2,1600},{'opening',3,12,1400},{'open',13,13,1000}})
print('PROLOGUE_ART_VALIDATION_OK')
