local cargo = require('cargo-audit.cargo')
local diagnostics = require('cargo-audit.diagnostics')
local log = require('cargo-audit.log')
local parser = require('cargo-audit.parser')
local util = require('cargo-audit.util')

local M = {}

---Run cargo-audit in an async fashion
---@param cb fun(result: CargoAuditReport|nil, err: string|nil)
function M.scan_async(cb)
  local root = util.find_root()
  if not root then
    log.log.warn('could not find Cargo.lock, or Cargo.toml')
    cb(nil, 'No Cargo.toml or Cargo.lock found')
    return
  end

  log.log.debug('calling cargo.audit module')
  cargo.audit(root, function(data, err)
    ---@class data CargoAuditReport
    vim.schedule(function()
      if err or data == nil then
        log.log.debug('cargo.audit returned an error, or data is nill')
        cb(nil, err)
        return
      end

      ---@diagnostic disable-next-line:param-type-mismatch
      local vulns = parser.collect_vulnerabilities(data)

      cb(vulns)
    end)
  end)
end

---Run `cargo-audit` and add diagnostics to the buffer.
function M.scan_and_diagnose()
  diagnostics.clear()
  log.log.info('running cargo audit ...')

  M.scan_async(function(vulns, err)
    if err then
      log.log.error(err)
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    if vulns == nil then
      log.log.warn('vulns is nil, please check the log for an error')
    elseif #vulns == 0 then
      log.log.info('no rust dependency issues found')
      vim.notify('No Rust dependency issues found', vim.log.levels.INFO)
      return
    else
      log.log.info('publishing ' .. #vulns .. ' to buffer')
      diagnostics.publish(vulns)
      vim.notify(
        string.format('Found %d Rust dependency issues', #vulns),
        vim.log.levels.WARN
      )
    end
  end)
end

---Setup the plugin scaffolding
---@param config CargoAuditPluginSettings list of options to override
function M.setup(config)
  local default_config = {
    toml = {
      enabled = true,
    },
    lock = {
      enabled = true,
    },
  }

  M.opts = vim.tbl_deep_extend('force', default_config, config)

  log.setup(config.log or {})

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
