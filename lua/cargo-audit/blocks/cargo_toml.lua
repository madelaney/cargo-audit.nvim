local M = {}

---Creates an index of packages in the Cargo.toml
---@param bufnr number the buffer number to read in the Cargo.toml from.
---@return table list of packages in cargo.toml {name --> line}
function M.index(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local map = {}

  for i, line in ipairs(lines) do
    local name = line:match('^%s*([%w_-]+)%s*=%s*"')
      or line:match('^%s*([%w_-]+)%s*=%s*{')

    if name then
      map[name] = i - 1
    end
  end

  return map
end

return M
