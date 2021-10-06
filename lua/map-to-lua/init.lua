local map_converter = {}

-- list of supported special arguments
local specials = {"buffer", "nowait", "silent", "script", "expr", "unique"}

-- supported formatters
local formatters = {}

-- default settings
map_converter.config = {
    default_formatter = "neovim",
    mapper = {
        package = "M",
        category = "Misc"
    }
}

-- useful for troubleshooting
local enable_debug = false
local function debug (...)
    if enable_debug then
        return print(unpack({...}))
    end
end

-- used to merge default and user config
function map_converter.merge(a, b)
    if type(a) == 'table' and type(b) == 'table' then
        for b_key, b_val in pairs(b) do
            if type(b_val) == 'table' and type(a[b_key] or false) == 'table' then
                map_converter.merge(a[b_key], b_val)
            else
                a[b_key] = b_val
            end
        end
    end
    return a
end

--- Detect map command mode and recursiveness
-- @param command           str     mapping command to be analyzed
-- @return mode             str     for which mode this mapping is (n, i, v ...)
-- @return recursiveness    bool    is it `nore` version or not
local function parse_map_command(command)
    if string.find(command, "^map") then
        return "", false
    end
    if string.find(command, "^nore") then
        return "", true
    end
    return string.sub(command, 1, 1), string.find(command, "nore", 2, true) and true or false
end

--- Check if there is a special argument at given position at line
---There can be spaces before special argument. Returned nil means that there are no more
---special arguments in the map and you should start looking for keys.
---@param line       string   the parsed line
---@param start      number   the position in line to be checked
---@return string, number  string is the name of a special argument if there was one found, nil otherwise, number is the position where this special argument ends and where next check should start
local function check_special(line, start)
    local special, spec_end = nil, nil
    for _, spec in ipairs(specials) do
        _, spec_end = string.find(line, "^[%s]*<"..spec..">", start)
        if spec_end then
            special = spec
            break
        end
    end
    return special, spec_end
end

--- Look for special arguments like '<silent>' or '<expr>'
---@param line            string   the parsed line
---@param start           number   where to start looking for special arguments, should be just after map command
---@return table, number  Table has form of {'special_arg_name' = true, ...} and the number is a position in the line where special keys end and real keys start
local function consume_specials(line, start)
    local opts = {}
    local cursor = start
    local spec_end = start
    local fuse = #specials
    repeat
        local spec
        spec, cursor = check_special(line, cursor + 1)
        debug("result of check_special: ", spec, cursor)
        if not spec then
            break
        else
            opts[string.lower(spec)] = true
            spec_end = cursor
        end
        fuse = fuse - 1
    until fuse == 0
    return opts, spec_end
end

local function opts_to_str(opts)
    local opts_str = "{ "
    for name, val in pairs(opts) do
        opts_str = opts_str..string.format("%s = %s, ", name, val)
    end
    opts_str = opts_str.."}"
    return opts_str
end

local function gen_id(text)
    return string.gsub(text, "%W", "-")..tostring(os.time())
end

local function gen_desc(text)
    return string.gsub(text, "%W", "")
end

--- "Buffer" is a special option, it changes API call so it should be detected and removed.
---@param opts  table   list of options for nvim_set_keymap
---@return      boolean true if there was an "buffer" option on the list and it was removed
local function remove_buffer(opts)
    local key_name = "buffer"
    if opts[key_name] then
        opts[key_name] = nil
        return true
    else
        return false
    end
end

function formatters.neovim(indent_str, mode, key, rhs, opts)
    local line = indent_str
    local is_buffer = remove_buffer(opts)
    print("opts: ", vim.inspect(opts))
    local opts_str = opts_to_str(opts)
    if is_buffer then
        debug("buffer mapping detected")
        line = line..string.format("vim.api.nvim_buf_set_keymap(0, %q, %q, %q, %s)", mode, key, rhs, opts_str)
    else
        line = line..string.format("vim.api.nvim_set_keymap(%q, %q, %q, %s)", mode, key, rhs, opts_str)
    end
    return line
end

function formatters.mapper(indent_str, mode, key, rhs, opts)
    local line = indent_str
    local is_buffer = remove_buffer(opts)
    print("opts: ", vim.inspect(opts))
    local opts_str = opts_to_str(opts)
    local map_type = is_buffer and "map_buf(0, " or "map("
    line = line..string.format('%s.%s%q, %q, %q, %s, %q, %q, %q)',
        map_converter.config.mapper.package,
        map_type,
        mode, key, rhs, opts_str,
        map_converter.config.mapper.category,
        gen_id(mode..key..rhs),
        gen_desc(rhs))
    return line
end

--- Gets vim mapping from current line and converts it to lua mapping
-- Current line from current buffer. Whole line is replaced.
-- Indention is kept. There should be only one mapping command in this line.
-- Currently only full map command names are supported.
function map_converter.convert_line(formatter_name)
    -- select formatter
    if not formatter_name then
        formatter_name = map_converter.config.default_formatter
    end
    local formatter = formatters[formatter_name]
    if not formatter then
        print("Error: unknown formatter: ", formatter_name)
        return
    end

    -- get text from current line in current buffer
    local line = vim.api.nvim_get_current_line()

    -- save the indent
    local indent, _ = string.find(line, "[%S]")
    local indent_str = string.sub(line, 1, indent - 1)
    debug("indent: ", indent)

    -- verify if this is a map command
    if not string.find(line, "[nvxsomilct]?n?o?r?e?map", indent) then
        print("error: unrecognized mapping: ", line)
        return
    end

    -- process the command
    local _, commands_end = string.find(line, "map ", indent, true)
    if not commands_end then
        print("Sorry, no map command has been detected.")
        return
    end
    local command = string.sub(line, indent, commands_end)
    local mode, nonrecursive = parse_map_command(command)
    debug("mode: ", mode, "nonrecursive: ", nonrecursive)

    -- process special arguments
    local opts, spec_end = consume_specials(line, commands_end)
    if nonrecursive then
        opts.noremap = true
    end
    debug(vim.inspect(opts), spec_end)

    -- process lhs
    local lhs_start, lhs_end = string.find(line, "%S+%s", spec_end + 1)
    local lhs = vim.trim(string.sub(line, lhs_start, lhs_end))
    debug("key2: ", lhs, "lhs_start: ", lhs_start, "lhs_end: ", lhs_end)

    -- process rhs
    local rhs = string.sub(line, lhs_end + 1)
    rhs = string.gsub(rhs, "^%s+", "")
    debug("rhs: ", rhs)

    -- format line with converted command
    local new_map = formatter(indent_str, mode, lhs, rhs, opts)
    debug("new map: ", new_map)

    -- replace current line with new one
    vim.api.nvim_set_current_line(new_map)
end

function map_converter.setup(user_config)
    map_converter.merge(map_converter.config, user_config)
end

return map_converter
