local audit = require('cargo-audit.audit')
local diagnostics = require('cargo-audit.diagnostics')
local log = require('cargo-audit.log')
local parser = require('cargo-audit.parser')
local util = require('cargo-audit.util')

local M = {}

---Merge two tables
---@param lhv table the left hand values
---@param rhv table the right hand values; will overwrite left values
---@return table merges content
local function config_merge(lhv, rhv)
  local result = vim.deepcopy(lhv)

  for k, v in pairs(rhv) do
    if type(v) == 'table' and type(result[k]) == 'table' then
      result[k] = config_merge(result[k], v)
    else
      result[k] = v
    end
  end

  return result
end

---Run cargo-audit in an async fashion
---@param cb function the callback to run when cargo-audit finishes
function M.scan_async(cb)
  local root = util.find_root()
  if not root then
    log.log.warn('could not find Cargo.lock, or Cargo.toml')
    cb(nil, 'No Cargo.toml or Cargo.lock found')
    return
  end

  audit.cargo_audit(root, function(data, err)
    ---@class data CargoAuditReport
    vim.schedule(function()
      if err then
        cb(nil, err)
        return
      end

      local vulns = parser.collect_vulnerabilities(data)
      cb(vulns)
    end)
  end)
end

---Run `cargo-audit` and add diagnostics to the buffer.
function M.scan_and_diagnose()
  diagnostics.clear()
  vim.notify('Running cargo audit…', vim.log.levels.INFO)
  log.log.info('running cargo audit ...')

  M.scan_async(function(vulns, err)
    ---@class vulns CargoAuditReport
    if err then
      log.log.error(err)
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    if #vulns == 0 then
      log.log.info('no rust dependency issues found')
      vim.notify('No Rust dependency issues found', vim.log.levels.INFO)
      return
    end

    diagnostics.publish(vulns)

    vim.notify(
      string.format('Found %d Rust dependency issues', #vulns),
      vim.log.levels.WARN
    )
  end)
end

---Setup the plugin scaffolding
---@param opts CargoAuditPluginSettings list of options to override
function M.setup(opts)
  M.opts = config_merge({
    toml = {
      enabled = true,
    },
    lock = {
      enabled = true,
    },
  }, opts)

  log.setup(opts.log or {})

  log.log.info('cargo-audit initialized')

  local icons = require('cargo-audit.severity')

  vim.fn.sign_define(
    'CargoAuditError',
    { text = icons.icons.critical, texthl = 'DiagnosticSignError' }
  )
  vim.fn.sign_define(
    'CargoAuditWarn',
    { text = icons.icons.medium, texthl = 'DiagnosticSignWarn' }
  )
  vim.fn.sign_define(
    'CargoAuditInfo',
    { text = icons.icons.low, texthl = 'DiagnosticSignInfo' }
  )
  vim.fn.sign_define(
    'CargoAuditHint',
    { text = icons.icons.hint, texthl = 'DiagnosticSignHint' }
  )

  if M.opts.toml.enabled then
    vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost' }, {
      pattern = 'Cargo.toml',
      callback = function()
        M.scan_and_diagnose()
      end,
    })
  end

  if M.opts.lock.enabled then
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'FileChangedShellPost' }, {
      pattern = 'Cargo.lock',
      callback = function()
        M.scan_and_diagnose()
      end,
    })
  end

  local telescope = require('cargo-audit.telescope')
  vim.api.nvim_create_user_command('CargoAudit', function()
    telescope.show_vulns()
  end, { desc = 'Show RustSec vulnerabilities in Telescope' })
end

return M
