-- Read saved native sources; write only a review audit beside the artwork.
-- Run from the repository root, or supply root=<repository>.
local root=app.fs.joinPath(app.params.root or app.fs.currentPath,'assets','characters','hunter')
local base=app.open(app.fs.joinPath(root,'hunter.aseprite'))
local directions={'n','e','s','w'}
local actors={hunter={1,200,0},auto_shot={8,700,260},poison_shot={12,1160,500},sniper={10,960,500},trap={6,500,0}}
local files={}
for name,a in pairs(actors) do
 local path=name=='hunter' and 'hunter.aseprite' or 'abilities/'..name..'/hunter_'..name..'.aseprite'
 files[#files+1]={path=path,w=19,h=19,pivot={9,9},actor=name,expected_frames=a[1]*4}
end
for _,name in ipairs({'auto_shot','poison_shot','sniper'}) do
 files[#files+1]={path='abilities/'..name..'/fx/projectile.aseprite',w=19,h=9,pivot={17,4}}
 files[#files+1]={path='abilities/'..name..'/fx/impact.aseprite',w=19,h=19,pivot={9,9}}
end
files[#files+1]={path='abilities/poison_shot/fx/affliction.aseprite',w=19,h=19,pivot={9,9}}
files[#files+1]={path='abilities/sniper/fx/reticle.aseprite',w=19,h=19,pivot={9,9}}
files[#files+1]={path='abilities/trap/fx/trap.aseprite',w=19,h=19,pivot={9,9}}
files[#files+1]={path='abilities/trap/fx/explosion.aseprite',w=38,h=38,pivot={19,19}}
table.sort(files,function(a,b)return a.path<b.path end)
local function rendered(s,f) local im=Image(s.width,s.height,ColorMode.RGB);im:drawSprite(s,f);return im end
local function ms(s,a,b) local total=0;for f=a,b do total=total+math.floor(s.frames[f].duration*1000+.5) end;return total end
local report={camera='strict overhead orthographic',pixels_per_tile=19,source_count=#files,total_frames=0,sources={},final_export=false}
for _,spec in ipairs(files) do
 local s=app.open(app.fs.joinPath(root,spec.path))
 assert(s.width==spec.w and s.height==spec.h,'Wrong canvas: '..spec.path)
 local sl=nil;for _,v in ipairs(s.slices) do if v.name=='frame' then sl=v end end
 assert(sl and sl.pivot.x==spec.pivot[1] and sl.pivot.y==spec.pivot[2],'Wrong center/tip: '..spec.path)
 local edge,partial=0,0
 for f=1,#s.frames do local im=rendered(s,f)
  for y=0,s.height-1 do for x=0,s.width-1 do local a=app.pixelColor.rgbaA(im:getPixel(x,y))
   if a>0 then
    if a<255 then partial=partial+1 end
    if x==0 or y==0 or x==s.width-1 or y==s.height-1 then edge=edge+1 end
   end
  end end
 end
 assert(edge==0 and partial==0,'Alpha or canvas edge issue: '..spec.path)
 local tags={};for _,t in ipairs(s.tags) do tags[t.name]=t end
 if spec.actor then
  local a=actors[spec.actor];assert(#s.frames==spec.expected_frames and #s.layers==7,'Actor structure mismatch')
  for d,dir in ipairs(directions) do
   local name=(spec.actor=='hunter' and 'idle' or spec.actor)..'_'..dir
   local t=assert(tags[name],'Missing cardinal tag '..name)
   local first,last=t.fromFrame.frameNumber,t.toFrame.frameNumber
   assert(last-first+1==a[1] and ms(s,first,last)==a[2],'Actor timing mismatch '..name)
   assert(rendered(s,last):isEqual(rendered(base,d)),'Idle-return mismatch '..name)
   if spec.actor~='hunter' then
    assert(t.repeats==1,'Attack must play once')
    local event=assert(tags[dir..(spec.actor=='trap' and '_place' or '_release')])
    assert(ms(s,first,event.fromFrame.frameNumber-1)==a[3],'Release timing mismatch '..name)
   end
   for f=0,a[1]-1 do
    local north=rendered(s,f+1);local actual=rendered(s,first+f)
    for y=0,18 do for x=0,18 do local xx,yy=x,y;for _=1,d-1 do xx,yy=18-yy,xx end
     assert(north:getPixel(x,y)==actual:getPixel(xx,yy),'Cardinal rotation mismatch '..name)
    end end
   end
  end
 end
 report.sources[spec.path]={frames=#s.frames,layers=#s.layers,canvas={s.width,s.height},pivot=spec.pivot,partial_alpha=partial,edge_pixels=edge}
 report.total_frames=report.total_frames+#s.frames;s:close()
end
local f=assert(io.open(app.fs.joinPath(root,'previews','validation.json'),'w'));f:write(json.encode(report));f:close()
print('Verified '..report.source_count..' sources / '..report.total_frames..' frames: sizes, anchors, alpha, margins, cardinal rotations, idle returns, and attack timing.')
