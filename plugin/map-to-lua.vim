if exists('g:loaded_map_to_lua')
  finish
endif

command! -nargs=? ConvertMapToLua lua require("map-to-lua").convert_line(<f-args>)

let g:loaded_map_to_lua = 1
