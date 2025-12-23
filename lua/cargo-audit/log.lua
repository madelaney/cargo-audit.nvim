local Log = require('plenary.log')

local M = {}

---Plugin wide logger
M.log = Log.new({
  plugin = 'cargo-audit',
  level = 'info',
  use_console = false,
})

---Setup the logger
---@param opts CargoAuditPluginLogger value overrides
function M.setup(opts)
  if opts and opts.log_level then
    M.log.level = opts.level
  end
end

return M
