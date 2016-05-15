local docroc = require 'docroc'
local path = require 'pl.path'
local dir = require 'pl.dir'
local file = require 'pl.file'
local stringx = require 'pl.stringx'

--- @module docroc.writer
-- Utilities for converting parsed comments to Markdown files.

local writers = {
  arg = function(el)
    local d = '- `' .. el.name .. '` (`' .. el.type .. '`): ' .. el.description
    if not stringx.endswith(d, '.') then d = d .. '.' end
    if el.optional then
      d = d .. ' Optional, default: `' .. (el.default or 'nil') .. '`.'
    end
    return d
  end,
  code = function(el)
    return '```\n'..(el.language or '')..el.code..'\n```'
  end,
  returns = function(el)
    return '- '..('`'..el.type..'`' or '')..el.description
  end,
  module = function(el)
    return '# ' .. el.text:gsub('^%s+', ''):gsub('%s$', '')
  end,
}

local default_writer = function(el)
  return el.text
end

local new_section = function(doc)
  doc = doc .. '\n'
  doc = doc:gsub('\n+$', '\n\n')
  return doc
end

local process_comment = function(tags)
  local sections = {
    summary={},
    arg={},
    returns={},
    other={},
  }
  for _, tag in ipairs(tags) do
    if tag.tag ~= 'module' then
      local process_tag = writers[tag.tag] or default_writer
      local section = sections[tag.tag] or sections.other
      table.insert(section, process_tag(tag) .. '\n')
    end
  end
  local doc = ''
  for _, s in ipairs(sections.summary) do doc = doc .. s end

  doc = new_section(doc)
  if #sections.arg > 0 then doc = doc .. 'Arguments:\n\n' end
  for _, s in ipairs(sections.arg) do doc = doc .. s end

  doc = new_section(doc)
  if #sections.returns > 0 then doc = doc .. 'Returns:\n\n' end
  for _, s in ipairs(sections.returns) do doc = doc .. s end

  for _, s in ipairs(sections.other) do
    doc = new_section(doc)
    doc = doc .. s
  end
  print(doc)
  return doc
end

local process_header = function(comment, opt)
  local doc = ''
  if comment.tags.module then
    doc = doc .. writers.module(comment.tags.module[1]) .. '\n'
  else
    local name = comment.context:match('^[local]*%s*[function]*%s*(.*)'):gsub('[^)%w]*$', '')
    doc = doc .. '## ' .. name .. '\n'
    doc = doc .. 'Definition'
    if opt.github_src_dir then
      doc = doc .. ' ([view source](' .. comment.filename:gsub(opt.src_dir, opt.github_src_dir) .. '#L' .. comment.linenum .. '))\n'
    end
    doc = doc .. ':\n```\n' .. comment.context:gsub('%s*=%s*[^%w]+$', '') .. '\n```\n'
  end
  return doc
end

local process_file = function(fname, opt)
  assert(fname, 'file '..fname.. ' doesnt exist!')
  local comments = docroc.process(fname)
  local doc = ''
  for _, comment in ipairs(comments) do
    doc = doc .. process_header(comment, opt) .. '\n'
    doc = doc .. process_comment(comment.tags, opt) .. '\n'
  end
  return doc
end

--- Builds Markdown docs based on source file comments.
-- 
-- @arg {string} src_dir - Source directory.
-- @arg {string} doc_dir - Directory to store the generated markdown files.
-- @arg {string=} github_src_dir - URL to the Github source directory.
-- @arg {boolean=} silent - Whether to print progress to stdout.
--
-- @returns {table[string]} A table of generated Markdown files.
--
-- A Markdown file will be generated for each `.lua` source file found in `src_dir`
-- at the corresponding location in `doc_dir`. For example, `src/foo/bar.lua` will
-- have a corresponding `src/foo/bar.md`.
local process_dir = function(src_dir, doc_dir, github_src_dir, silent)
  local opt = {github_src_dir=github_src_dir, silent=silent, src_dir=src_dir}
  local say = function(str)
    if not silent then
      print(str)
    end
  end

  if not path.exists(doc_dir) then
    say('making directory at '..doc_dir)
    dir.makepath(doc_dir)
  end

  local generated = {}
  for root, dirs, files in dir.walk(src_dir) do
    for _, fname in ipairs(files) do
      if stringx.endswith(fname, '.lua') then
        local src_file = path.join(root, fname)
        say('processing '..src_file)
        local proc = process_file(src_file, opt)
        local doc_file = src_file:gsub(src_dir, doc_dir):gsub('.lua', '.md')
        local parent_dir = path.dirname(doc_file)
        if not path.exists(parent_dir) then dir.makepath(parent_dir) end
        say('writing '..doc_file)
        file.write(doc_file, proc)
        table.insert(generated, doc_file)
      end
    end
  end
  return generated
end

return {
  process_dir=process_dir,
}
