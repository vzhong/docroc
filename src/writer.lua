local docroc = require 'docroc'
local path = require 'pl.path'
local dir = require 'pl.dir'
local file = require 'pl.file'
local stringx = require 'pl.stringx'

--- @module docroc.writer
-- Utilities for converting parsed comments to Markdown files.

local writers = {
  arg = function(el)
    local d = ' - `' .. el.name .. '` (`' .. el.type .. '`): ' .. el.description
    if not stringx.endswith(d, '.') then d = d .. '.' end
    if el.optional or el.default then
      d = d .. ' Optional, default: `' .. (el.default or 'nil') .. '`.'
    end
    return d
  end,
  code = function(el)
    return '```\n'..(el.language or '')..el.code..'\n```'
  end,
  module = function(el)
    return '# ' .. el.text:gsub('^%s+', ''):gsub('%s$', '')
  end
}

local default_writer = function(el)
  return el.text .. '\n'
end

local process_context = function(context)
  local name = context:match('^[local]*%s*[function]*%s*(.*)'):gsub('[^)%w]*$', '')
  return '## ' .. name .. '\n```lua\n' .. context:gsub('%s*=%s*[^%w]+$', '') .. '\n```\n'
end

local process_comment = function(context, tags)
  local doc = ''
  local is_module = false
  for _, tag in ipairs(tags) do
    is_module = is_module or (tag.tag == 'module')
    local process_tag = writers[tag.tag] or default_writer
    doc = doc .. process_tag(tag) .. '\n'
  end
  if is_module then
    return doc
  else
    return process_context(context) .. '\n' .. doc
  end
end

local process_file = function(fname)
  assert(fname, 'file '..fname.. ' doesnt exist!')
  local comments = docroc.process(fname)
  local doc = ''
  for _, comment in ipairs(comments) do
    doc = doc .. process_comment(comment.context, comment.tags) .. '\n'
  end
  return doc
end

--- Builds Markdown docs based on source file comments.
-- 
-- @arg {string} src_dir - Source directory.
-- @arg {string} doc_dir - Directory to store the generated markdown files.
-- @arg {boolean=} silent - Whether to print progress to stdout.
--
-- A Markdown file will be generated for each `.lua` source file found in `src_dir`
-- at the corresponding location in `doc_dir`. For example, `src/foo/bar.lua` will
-- have a corresponding `src/foo/bar.md`.
local process_dir = function(src_dir, doc_dir, silent)
  local say = function(str)
    if not silent then
      print(str)
    end
  end

  if not path.exists(doc_dir) then
    say('making directory at '..doc_dir)
    dir.makepath(doc_dir)
  end

  for root, dirs, files in dir.walk(src_dir) do
    for _, fname in ipairs(files) do
      if stringx.endswith(fname, '.lua') then
        local src_file = path.join(root, fname)
        say('processing '..src_file)
        local proc = process_file(src_file)
        local doc_file = src_file:gsub(src_dir, doc_dir):gsub('.lua', '.md')
        local parent_dir = path.dirname(doc_file)
        if not path.exists(parent_dir) then dir.makepath(parent_dir) end
        say('writing '..doc_file)
        file.write(doc_file, proc)
      end
    end
  end
end

return {
  process_dir=process_dir,
}
