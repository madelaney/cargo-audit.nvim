local M = {}

---Create an index of items in the cargo.lock file.
---@param bufnr number the buffer to read the contents of for cargo.lock
---@return table list of packages in cargo.lock {name --> line}
function M.index(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local map = {}

  local current_block = nil
  local block_start = nil

  for i, line in ipairs(lines) do
    if line:match('^%[%[package%]%]') then
      current_block = {}
      block_start = i - 1
    elseif current_block then
      local name = line:match('^name%s*=%s*"([^"]+)"')
      if name then
        current_block.name = name
      end

      local version = line:match('^version%s*=%s*"([^"]+)"')
      if version then
        current_block.version = version
      end

      if current_block.name and current_block.version then
        local key = current_block.name .. '@' .. current_block.version
        map[key] = block_start
        current_block = nil
      end
    end
  end

  return map
end

return M
