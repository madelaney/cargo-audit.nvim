local util = require('cargo-audit.util')
local log = require('cargo-audit.log').log

local M = {}

---Runs cargo-audit
---@param root string the root directory of our rust code.
---@param cb fun(result: CargoAuditReport|nil, err: string|nil)
function M.audit(root, cb)
  util.async_cmd(
    {
      'cargo',
      'audit',
      '--json',
    },
    root,
    function(out, err, code)
      -- cargo audit exits with 1 when vulnerabilities are found
      if not out or out == '' then
        log.error('cargo audit produced no output (code=%s)', code)
        cb(nil, err or 'cargo audit failed')
        return
      end

      local ok, decoded = pcall(vim.json.decode, out)
      if not ok then
        log.error('Failed to decode cargo audit JSON')
        cb(nil, 'Invalid cargo audit output')
        return
      end

      cb(decoded)
    end
  )
end

---Get cargo-metadata content
---@param root string the root directory to run `cargo-metadata` in.
---@param cb function the funtion to call when cargo-metadata finishes
function M.metadata(root, cb)
  local cmd = { 'cargo', 'metadata', '--format-version=1', '--locked' }
  util.async_cmd(cmd, root, function(out, err)
    ---@class out CargoMetadata
    if not out then
      cb(nil, err)
      return
    end
    cb(vim.json.decode(out))
  end)
end

return M
