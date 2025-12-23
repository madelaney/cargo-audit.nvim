local log = require('cargo-audit.log').log

local M = {}

---Find the root of our cargo project
---@return string|nil
function M.find_root()
  local markers = { 'Cargo.toml', 'Cargo.lock' }
  local cwd = vim.fn.getcwd()

  for _, marker in ipairs(markers) do
    local found = vim.fs.find(marker, {
      upward = true,
      path = cwd,
      stop = vim.loop.os_homedir(),
    })
    if #found > 0 then
      return vim.fs.dirname(found[1])
    end
  end

  return nil
end

---Wrapper for running async commands
---@param cmd table the command to run
---@param cwd string the directory to run the command in
---@param cb fun(out: string, err: string, status: number) callback for when the command finishes
function M.async_cmd(cmd, cwd, cb)
  log.debug('running command: %s', table.concat(cmd, ' '))

  vim.system(cmd, { cwd = cwd, text = true }, function(result)
    log.debug(
      'command exited code=%d stdout=%d stderr=%d',
      result.code,
      #(result.stdout or ''),
      #(result.stderr or '')
    )

    cb(result.stdout, result.stderr, result.code)
  end)
end

return M
