local M = {}

---Severity icons
M.icons = {
  critical = '🔥',
  high = '❗',
  medium = '⚠️',
  low = 'ℹ️',
  hint = '💡',
  unknown = '?',
}

---@class CargoAuditSeverityEntry
---@field diag integer   # vim.diagnostic.severity.*
---@field icon string    # Icon shown in signs / virtual text
---@field weight integer # Lower = higher severity

---@type table<string, CargoAuditSeverityEntry>
M.map = {
  critical = {
    diag = vim.diagnostic.severity.ERROR,
    icon = M.icons.critical,
    weight = 1,
  },
  high = {
    diag = vim.diagnostic.severity.ERROR,
    icon = M.icons.high,
    weight = 2,
  },
  medium = {
    diag = vim.diagnostic.severity.WARN,
    icon = M.icons.medium,
    weight = 3,
  },
  low = {
    diag = vim.diagnostic.severity.INFO,
    icon = M.icons.low,
    weight = 4,
  },
  hint = {
    diag = vim.diagnostic.severity.HINT,
    icon = M.icons.hint,
    weight = 5,
  },
  unknown = {
    diag = vim.diagnostic.severity.HINT,
    icon = M.icons.hint,
    weight = 6,
  },
}

--- Convert NeoVim diagnostic security to RustSec value.
M.num_to_rustsec = {
  [vim.diagnostic.severity.ERROR] = 'critical',
  [vim.diagnostic.severity.WARN] = 'medium',
  [vim.diagnostic.severity.INFO] = 'low',
  [vim.diagnostic.severity.HINT] = 'hint',
}

---Get the weight of a given severity
---@param sev string|number severity to get the weight of
---@return number the severity weight
---@see M.num_to_rustsec
---@see M.get
function M.weight(sev)
  if type(sev) == 'number' then
    local key = M.num_to_rustsec[sev] or 'unknown'
    return M.map[key].weight or 6
  elseif type(sev) == 'string' then
    return M.map[sev:lower()].weight or 6
  end
  return 6
end

---Setup the severity config.
---@param overrides table the values to override.
function M.setup(overrides)
  if overrides then
    for k, v in pairs(overrides) do
      M.icons[k] = v
      if M.map[k] then
        M.map[k].icon = v
      end
    end
  end
end

---Get a table of severity based on name or diags value
---@param sev string|number name or diagnostic value to look up
---@return table severity { icon, weight, and diagnostic id }
function M.get(sev)
  local key = sev
  if type(sev) == 'number' then
    key = M.num_to_rustsec[sev] or 'unknown'
  elseif type(sev) == 'string' then
    key = sev:lower()
  end
  return M.map[key] or M.map.unknown
end

return M
