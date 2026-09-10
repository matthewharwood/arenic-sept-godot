-- Derived preview only: compose saved idle frames using native Aseprite rendering.
local root=app.params.root or app.fs.currentPath
local roster={'hunter','warrior','thief','alchemist','cardinal','bard','forager','merchant'}
local sheet=Image(116,58,ColorMode.RGB)
for index,hero in ipairs(roster) do
  local sprite=app.open(app.fs.joinPath(root,'assets','characters',hero,hero..'.aseprite'))
  assert(sprite and sprite.width==19 and sprite.height==19,hero)
  local frame=nil
  for _,tag in ipairs(sprite.tags) do if tag.name=='idle_e' then frame=tag.fromFrame.frameNumber end end
  assert(frame,hero..' idle_e')
  local image=Image(19,19,ColorMode.RGB);image:drawSprite(sprite,frame)
  local folder=app.fs.joinPath(root,'assets','previews',hero);app.fs.makeAllDirectories(folder)
  image:saveAs(app.fs.joinPath(folder,'idle.png'))
  sheet:drawImage(image,Point(5+((index-1)%4)*29,5+math.floor((index-1)/4)*29))
  sprite:close()
end
sheet:saveAs(app.fs.joinPath(root,'assets','previews','roster.png'))
print('Rendered eight native idle previews without modifying source files.')
