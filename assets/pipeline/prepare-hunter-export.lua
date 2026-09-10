-- Configure saved Hunter sources without saving artwork or exporting textures/data.
-- From the repository root:
--   aseprite --batch --script-param all=true --script assets/pipeline/prepare-hunter-export.lua
-- One source: pass source=<path>, or run inside Aseprite with the saved source active.
-- Add verify_only=true to read back persisted presets without changing them.
-- An optional root=<repository path> supports all=true from another directory.

local function enabled(name)
  return app.params[name] == 'true' or app.params[name] == '1'
end

local function absolute(path)
  if not path:match('^[/\\]') and not path:match('^%a:[/\\]') then
    path = app.fs.joinPath(app.fs.currentPath, path)
  end
  return app.fs.normalizePath(path)
end

local function repository_from(path)
  local folder = app.fs.isDirectory(path) and path or app.fs.filePath(path)
  while folder ~= '' do
    if app.fs.isFile(app.fs.joinPath(folder, 'arenic-game', 'project.godot'))
        and app.fs.isDirectory(app.fs.joinPath(folder, 'assets', 'characters', 'hunter')) then
      return folder
    end
    local parent = app.fs.filePath(folder)
    if parent == folder then break end
    folder = parent
  end
  error('Expected Hunter sources beneath assets/characters/hunter beside arenic-game.')
end

local all = enabled('all')
local verify_only = enabled('verify_only')
local active = app.activeSprite
local selected = app.params.source
if not selected and not all then
  assert(active and active.hasAssociatedFile, 'Open a saved Hunter .aseprite source first.')
  selected = active.filename
end
local root = repository_from(absolute(app.params.root or selected or app.fs.currentPath))
local source_root = app.fs.joinPath(root, 'assets', 'characters', 'hunter')
local output_root = app.fs.joinPath(root, 'arenic-game', 'assets', 'characters', 'hunter')
local prefix = source_root .. app.fs.pathSeparator
local sources = {}

local function collect(folder)
  local names = app.fs.listFiles(folder)
  table.sort(names)
  for _, name in ipairs(names) do
    local path = app.fs.joinPath(folder, name)
    if app.fs.isDirectory(path) then
      if name ~= 'previews' and name:sub(1, 1) ~= '.' then collect(path) end
    elseif app.fs.fileExtension(name):lower() == 'aseprite' then
      sources[#sources + 1] = path
    end
  end
end

if all then collect(source_root) else sources[1] = absolute(selected) end
assert(#sources > 0, 'No saved Hunter .aseprite sources found.')

local common = {
  defined = true,
  type = SpriteSheetType.HORIZONTAL,
  data_format = SpriteSheetDataFormat.JSON_ARRAY,
  filename_format = '{title}_{tag}_{frame}',
  columns = 0, rows = 0, width = 0, height = 0,
  border_padding = 0, shape_padding = 0, inner_padding = 0,
  trim_sprite = false, trim = false, trim_by_grid = false,
  extrude = false, merge_duplicates = false, ignore_empty = false,
  power_of_two_size = false, open_generated = false,
  layer = '', layer_index = -1, frame_tag = '',
  split_layers = false, split_tags = false, split_grid = false,
  list_layers = true, list_frame_tags = true, list_slices = true,
}

-- Each document is processed sequentially because preferences are host-owned state.
local readback = {}
for _, path in ipairs(sources) do
  path = absolute(path)
  assert(path:sub(1, #prefix) == prefix, 'Source must remain beneath ' .. source_root)
  assert(app.fs.fileExtension(path):lower() == 'aseprite' and app.fs.isFile(path),
         'Expected an existing saved .aseprite file: ' .. path)
  local relative = path:sub(#prefix + 1)
  assert(not relative:match('^previews[/\\]') and not relative:match('[/\\]previews[/\\]'),
         'Review previews are not runtime sources.')
  local output = app.fs.joinPath(output_root, app.fs.filePath(relative))
  local title = app.fs.fileTitle(path)
  local expected_texture = app.fs.joinPath(output, title .. '.png')
  local expected_data = app.fs.joinPath(output, title .. '.json')
  local use_active = not all and not app.params.source and active
  local sprite = use_active and active or app.open(path)
  assert(sprite and sprite.hasAssociatedFile, 'Cannot open source: ' .. path)
  local width, height, modified = sprite.width, sprite.height, sprite.isModified
  local p = app.preferences.document(sprite).sprite_sheet
  if not verify_only then
    app.fs.makeAllDirectories(output)
    for field, value in pairs(common) do p[field] = value end
    p.texture_filename = expected_texture
    p.data_filename = expected_data
  end
  for field, value in pairs(common) do
    assert(p[field] == value, 'Preset mismatch for ' .. relative .. ': ' .. field)
  end
  assert(p.texture_filename == expected_texture, 'Texture destination mismatch: ' .. relative)
  assert(p.data_filename == expected_data, 'Metadata destination mismatch: ' .. relative)
  assert(sprite.width == width and sprite.height == height and sprite.isModified == modified,
         'Preset setup must not modify artwork: ' .. relative)
  readback[#readback + 1] = {
    source = path, width = width, height = height,
    texture = p.texture_filename, data = p.data_filename,
    frame_count = #sprite.frames, preset_fields_verified = true,
  }
  if not use_active then sprite:close() end
end

print(json.encode({mode = verify_only and 'verified' or 'configured',
                   source_count = #readback, exported = false, sources = readback}))
