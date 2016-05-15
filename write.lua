#!/usr/bin/env th

local lapp = require 'pl.lapp'
local opt = lapp [[
Generate documentations recursively for a directory.
  <src_dir> (string) Source directory
  <doc_dir> (string) Documentation directory
  --site_name (default '') Name of Documentation site. Defaults to name of doc_dir.
  --repo_name (default '')
  --site_description (default '')
  --site_author (default '')
  --index (default '')  File to use to create homepage.
]]

local path = require 'pl.path'
local dir = require 'pl.dir'
local file = require 'pl.file'
local yaml = require 'yaml'

for k, v in pairs(opt) do
  if v == '' then opt[k] = nil end
end

local config = {pages={}}
for _, k in ipairs{'site_name', 'repo_name', 'site_author', 'site_description'} do
  config[k] = opt[k]
end
config.site_name = opt.site_name or path.basename(path.dirname(path.abspath(opt.src_dir)))
config.site_description = opt.site_description or ('Documentation for ' .. config.site_name)
if config.site_author then
  config.copyright = 'Copyright '..os.date('%Y')..' '..config.site_author
end

local writer = require 'writer'
writer.process_dir(opt.src_dir, opt.doc_dir)

local name2category = {}

local tl = require 'torchlib'

for root, dirs, files in dir.walk(opt.doc_dir) do
  for fname in files:iter() do
    local name, ext = path.splitext(fname)
    if ext == '.md' then
      local fpath = path.join(root, fname):gsub(opt.doc_dir..'/', '')
      local dirname, _ = path.splitpath(fpath)
      if not name2category[dirname] and dirname ~= '' then
        local entry = {}
        entry[dirname] = {}
        table.insert(config.pages, entry)
        name2category[dirname] = config.pages[#config.pages][dirname]
      end
      local entry = {}
      entry[name] = fpath
      if dirname == '' then
        if name ~= 'index' then
          table.insert(config.pages, entry)
        end
      else
        table.insert(name2category[dirname], entry)
      end
    end
  end
end

-- copy readme
if path.exists(opt.index) then
  file.copy(opt.index, path.join(opt.doc_dir, 'index.md'))
end
table.insert(config.pages, {Home='index.md'})

content = yaml.dump(config)

-- this hack is for mkdocs weirdness
content = content:gsub('%- (%w+): ([^\n]+)', function(a, b)
  return "- '"..a.."': '"..b.."'"
end)

print(content)

file.write('mkdocs.yml', content)

--file.write('mkdocs.yml', content)