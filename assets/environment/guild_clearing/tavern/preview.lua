-- Native Aseprite context preview only. No scene or gameplay placement authority.
local root=assert(app.params.root,'root required')..'/'
local dir=root..'assets/environment/guild_clearing/tavern/previews/'
local ground=Image{fromFile=root..'arenic-game/assets/environment/guild_clearing/ground/grass_tiles.png'}
local grass={}
for f=0,3 do grass[f+1]=Image(19,19,ColorMode.RGB);grass[f+1]:drawImage(ground,Point(-19*f,0)) end
local scene=Image(380,247,ColorMode.RGB)
for y=0,12 do for x=0,19 do scene:drawImage(grass[(x+y*3)%4+1],Point(x*19,y*19)) end end
scene:drawImage(Image{fromFile=root..'arenic-game/assets/environment/guild_clearing/tavern/tavern.png'},Point(66,9))
local keeper=Image(38,38,ColorMode.RGB);keeper:drawImage(Image{fromFile=root..'arenic-game/assets/npcs/keeper/seated/keeper_seated.png'},Point(0,0))
scene:drawImage(keeper,Point(170,158))
scene:saveAs(dir..'tavern-and-keeper-native.png');scene:resize(1140,741);scene:saveAs(dir..'tavern-and-keeper-3x.png')
print('Native context preview exported; not a runtime placement test.')
