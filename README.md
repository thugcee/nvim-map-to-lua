# nvim-map-to-lua

In-place converter of Vim's `:map` commands family to Neovim's Lua
function `vim.api.nvim_set_keymap` or other custom mapping handling
functions.

### Limitations

- Processes only a single line but you can always create a vim macro for mass execution.
- There has to be only one `map` command in a processed line.
- ~~No support for `<buffer>` mapping, but it is planned.~~ Already added.

## Usage

Put your cursor in a line with some `:map` and call:
```
:ConvertMapToLua
```
or
```
:lua require("map-to-lua").convert_line()
```
Map it to some key if you like: `:nmap <leader>cm <cmd>lua require("map-to-lua").convert_line()<cr>`

This will convert something like this:
```
inoremap <silent><expr> <C-d>f     compe#scroll({ 'delta': -4 })
```
into this:
```lua
vim.api.nvim_set_keymap("i", "<C-d>f", "compe#scroll({ 'delta': -4 })", { expr = true, noremap = true, silent = true, })
```

### Selecting formatter

Default formatter produces direct call to Neovim's `vim.api.nvim_set_keymap` or `vim.api.nvim_buf_set_keymap`. This can be changed
by supplying formatter name to the call, like this:
```
:ConvertMapToLua FORMATTER
:lua require("map-to-lua").convert_line("FORMATTER")
```

Currently supported formatters are: `neovim` (default) and `mapper`. The latter one is for
`lazytanuki/nvim-mapper` plugin. Both formatters support special case of buffer mapping.

### Configuration
Default configuration looks like this:
```lua
config = {
    default_formatter = "neovim",
    mapper = {
        package = "M",    -- maybe you should change it to "require('nvim-mapper')"
        category = "Misc"
    }
}
```

Put any part of this table into `require("map-to-lua").setup` and it will be deep merged
with default config. See [Install](#Install) for example.

`mapper.package = "M"` is useful when you have a lot of mappings and add
```
local M = require("nvim-mapper")
```
at the beginning of your mapping definitions list.

Ad hoc configuration:
```
:lua require("map-to-lua").setup {mapper = {package = "require('util-map')"}}
```

## Requirements

Neovim 0.5.0 or newer.

## Install

Example for `packer.nvim`:
```lua
    use {
        "thugcee/nvim-map-to-lua",
        ft = "lua",
        config = function ()
            require("map-to-lua").setup {
                default_formatter = "mapper"
            }
            vim.api.nvim_set_keymap("n", "<leader>cm", '<cmd>lua require("map-to-lua").convert_line()<cr>', { })
        end
    }
```

Or you can just drop `map-to-lua/init.lua` file into your `nvim/lua` folder. There 
will be no `ConvertMapToLua` command (it's not needed, I've added it just for 
convenience) but you can call plug-in's main function by 
```
:lua require("map-to-lua").convert_line()
; or
:lua require("map-to-lua").convert_line("neovim")
; or
:lua require("map-to-lua").convert_line("mapper")
```
When using `mapper` don't forget to add `local M = require("util-map")` to your Lua file or change `mapper.package` to `require("util-map")` like this:
```
require("map-to-lua").setup {
                default_formatter = "mapper",
                mapper = {
                    package = 'require("util-map")'
                }
            }
```
