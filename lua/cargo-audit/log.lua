local Log = require('plenary.log')

local M = {}

---Plugin wide logger
M.log = Log.new({
  plugin = 'cargo-audit',
  level = 'debug',
  use_console = false,
})

---Setup the logger
---@param opts CargoAuditPluginLogger value overrides
function M.setup(opts)
  if opts then
    if opts.level then
      M.log.level = opts.level
    end
    M.log.use_console = opts.use_console
  end
end

return M
