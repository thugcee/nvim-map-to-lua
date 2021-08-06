# nvim-map-to-lua

In-place converter of Vim's `:map` commands family to Neovim's Lua
function `vim.api.nvim_set_keymap` or other custom mapping handling
functions.

### Limitations

- Processes only a single line but you can always create a vim macro for mass execution.
- There has to be only one `map` command in a processed line.

## Usage

Put your cursor in a line with some `:map` and call:
```
:ConvertMapToLua
```
or
```
:lua require("map-to-lua").convert_line()
```

this will convert something like this:
```
inoremap <silent><expr> <C-d>f     compe#scroll({ 'delta': -4 })
```
into this:
```lua
vim.api.nvim_set_keymap("i", "<C-d>f", "compe#scroll({ 'delta': -4 })", { expr = true, noremap = true, silent = true, })
```

## Requirements

Neovim 0.5.0 or newer.

## Install

Example for `packer.nvim`:
```lua
    use {
        "~/lab/progr/nvim-map-to-lua",
        ft = "lua",
        config = function ()
            require("map-to-lua").setup {
                default_formatter = "mapper"
            }
            local M = require("util-map")
            M.map("n", "<leader>cm", '<cmd>lua require("map-to-lua").convert_line()<cr>', { }, "Misc", "-C-m--cmd-lua-require--nvim-map-to-lua-map-to-lua---convert-line---cr--1628254156", "cmdluarequirenvimmaptoluamaptoluaconvertlinecr")
        end
    }
```
