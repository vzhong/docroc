local docroc = require 'docroc'
local path = require 'pl.path'
local dir = require 'pl.dir'
local file = require 'pl.file'
local stringx = require 'pl.stringx'

docroc.processors.module = function(body)
  local name
  body:gsub('^%s*(%b{})', function(match)
    name = match:sub(2, -2)
    return ''
  end)
  return {name=name}
end

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
    return '```\n'..el.text..'\n```'
  end,
  module = function(el)
    return '## ' .. el.name
  end
}

local default_writer = function(el)
  return el.text .. '\n'
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
    return '# `' .. context .. '`\n' .. doc
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

local process_dir = function(src_dir, doc_dir, silent)
  local say = function(str)
    if not silent then
      print(str)
    end
  end

  if path.exists(doc_dir) then
    say('removing directory at '..doc_dir)
    dir.rmtree(doc_dir)
  end
  dir.makepath(doc_dir)

  for root, dirs, files in dir.walk(src_dir) do
    for fname in files:iter() do
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
