-- docroc v0.1.0 - Lua documentation generator
-- https://github.com/bjornbytes/docroc
-- License - MIT, see LICENSE for details.

local docroc = {}

--- Extracts comments from a file
-- @arg {string} filename - path of the file to extract comments from.
function docroc.process(filename)
  local file = io.open(filename, 'r')
  local text = file:read('*a')
  file:close()

  local comments = {}
  text:gsub('%s*%-%-%-(.-)\n([%w\n][^\n%-]*)', function(chunk, context)
    chunk = chunk:gsub('%-%-', '\n'):gsub('\n ', '')
    chunk = chunk:gsub('^[^@]', '@summary %1')
    context = context:match('[^\n]+')

    -- catch descriptions denoted by multiple linebreaks
    chunk = chunk:gsub('\n\n\n[^@]', '\n\n@description %1')

    local tags = {}
    chunk:gsub('[\n@](%w+)%s?([^@]*)', function(name, body)
      body = body:gsub('(%s+)$', '')
      local processor = docroc.processors[name]
      local tag = processor and processor(body) or {}
      tag.tag = name
      tag.text = body:gsub('\n+', '\n'):gsub('^%s+', ''):gsub('%s+$', '')
      tags[name] = tags[name] or {}
      table.insert(tags[name], tag)
      table.insert(tags, tag)
    end)

    local before_context = text:sub(1, text:find(context, 1, true))
    local _, before_nlines = before_context:gsub('\n', '')

    table.insert(comments, {
      tags = tags,
      context = context,
      filename = filename,
      linenum = before_nlines + 1,
    })
  end)

  return comments
end

--- Defines how different tags are parsed.
docroc.processors = {
  arg = function(body)
    local name = body:match('^%s*(%w+)') or body:match('^%s*%b{}%s*(%w+)')
    local description = body:match('%-%s*(.*)$')
    local optional, default
    local type = body:match('^%s*(%b{})'):sub(2, -2):gsub('(%=)(.*)', function(_, value)
      optional = true
      default = value
      return ''
    end)

    return {
      type = type,
      name = name,
      description = description,
      optional = optional,
      default = default
    }
  end,

  module = function(body)
    return {name=body:match('^%s*(.*)')}
  end,

  returns = function(body)
    local type 
    body = body:gsub('^%s*(%b{})', function(match)
      type = match:sub(2, -2)
      return ''
    end)
    local description = body:match('^%s*(.*)')
    return {type=type, description=description}
  end,

  code = function(body)
    local language
    body = body:gsub('^%s*(%b{})', function(match)
      language = match:sub(2, -2)
      return ''
    end)
    local code = body:match('^%s*(.*)')
    return {language=language, code=code}
  end,
}

return docroc
