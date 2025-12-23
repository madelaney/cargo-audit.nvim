local util = require('cargo-audit.util')

local M = {}

---Get cargo-metadata content
---@param root string the root directory to run `cargo-metadata` in.
---@param cb function the funtion to call when cargo-metadata finishes
function M.get_metadata(root, cb)
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
