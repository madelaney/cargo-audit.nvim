local lock = require('cargo-audit.blocks.cargo_lock')
local severity = require('cargo-audit.severity')
local toml = require('cargo-audit.blocks.cargo_toml')

local M = {}
M.ns = vim.api.nvim_create_namespace('cargo-audit')

---Add diagnostic to the current buffer
---@param bufnr number the bufnr to add the diagnostics to
---@param vulns Vulnerability[] the list of vulnerabilities
local function publish_to_buffer(bufnr, vulns)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local diags = {}

  if name:match('Cargo%.toml$') then
    local index = toml.index(bufnr)

    for _, v in ipairs(vulns) do
      local lnum = index[v.crate]

      if lnum then
        local info = severity.get(v.severity)
        local message = string.format(
          '[%s] %s %s — %s',
          v.kind,
          v.crate,
          v.version,
          v.title or 'No description'
        )
        table.insert(diags, {
          lnum = lnum,
          col = 0,
          prefix = info.icon,
          message = message,
          severity = info.diag,
          source = 'cargo-audit',
          code = v.advisory,
        })
      end
    end
  elseif name:match('Cargo%.lock$') then
    local index = lock.index(bufnr)

    for _, v in ipairs(vulns) do
      local key = v.crate .. '@' .. v.version
      local lnum = index[key]

      if lnum then
        local info = severity.get(v.severity)
        local message = string.format(
          '[%s] %s %s — %s',
          v.kind,
          v.crate,
          v.version,
          v.title or 'No description'
        )
        table.insert(diags, {
          lnum = lnum,
          col = 0,
          prefix = info.icon,
          message = message,
          severity = info.diag,
          source = 'cargo-audit',
          code = v.advisory,
        })
      end
    end
  end

  vim.diagnostic.set(M.ns, bufnr, diags, {
    underline = true,
    -- virtual_text = { spacing = 2, prefix = '●' },
    virtual_text = { spacing = 2, prefix = '' },
    signs = true,
  })
end

---Publish cargo-audit report to the current buffer
---@param vulns CargoAuditReport report from cargo audit
function M.publish(vulns)
  vim.schedule(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        if name:match('Cargo%.toml$') or name:match('Cargo%.lock$') then
          publish_to_buffer(buf, vulns)
        end
      end
    end
  end)
end

function M.clear()
  vim.schedule(function()
    vim.diagnostic.reset(M.ns)
  end)
end

return M
