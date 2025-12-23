local has_telescope, _ = pcall(require, 'telescope')
if not has_telescope then
  return {}
end

local action_state = require('telescope.actions.state')
local actions = require('telescope.actions')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')

local diag = require('cargo-audit.diagnostics')
local icons = require('cargo-audit.severity')

local M = {}

---Group vulnerabilities by their severity
---@param diags table vulnerabilities to sort
---@return table sorted vulnerabilities
local function severity_grouped_items(diags)
  local items = {}
  for _, d in ipairs(diags) do
    local item = icons.get(d.severity)
    table.insert(items, {
      display = string.format(
        '%s %s:%d %s',
        item.icon,
        vim.api.nvim_buf_get_name(d.buf):match('^.+/(.+)$') or d.buf,
        d.lnum + 1,
        d.message
      ),
      buf = d.buf,
      lnum = d.lnum,
      col = d.col,
      weight = item.icon,
      severity = d.severity,
    })
  end

  table.sort(items, function(a, b)
    if a.weight ~= b.weight then
      return a.weight < b.weight
    end
    if a.buf ~= b.buf then
      return a.buf < b.buf
    end
    return a.lnum < b.lnum
  end)

  local grouped = {}
  local last_weight = nil
  local severity_names = { 'Critical', 'High', 'Medium', 'Low', 'Hint' }
  for _, item in ipairs(items) do
    if item.weight ~= last_weight then
      table.insert(grouped, {
        display = string.format(
          '=== %s ===',
          severity_names[item.weight] or 'Other'
        ),
        is_header = true,
      })
      last_weight = item.weight
    end
    table.insert(grouped, item)
  end

  return grouped
end

---Show the vulnerabilities in telescope
function M.show_vulns()
  vim.schedule(function()
    local all_diags = {}
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      ---@class buf integer
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        if buf_name:match('Cargo%.toml$') or buf_name:match('Cargo%.lock$') then
          local diags = vim.diagnostic.get(bufnr, { namespace = diag.ns })
          for _, d in ipairs(diags) do
            ---@class d vim.Diagnostics
            ---@diagnostic disable-next-line:assign-type-mismatch
            d.bufnr = math.floor(bufnr)
            table.insert(all_diags, d)
          end
        end
      end
    end

    if #all_diags == 0 then
      vim.notify('No RustSec vulnerabilities found', vim.log.levels.INFO)
      return
    end

    local items = severity_grouped_items(all_diags)

    pickers
      .new({}, {
        prompt_title = 'RustSec Vulnerabilities',
        finder = finders.new_table({
          results = items,
          entry_maker = function(entry)
            if entry.is_header then
              return {
                value = entry,
                display = entry.display,
                ordinal = '',
              }
            else
              return {
                value = entry,
                display = entry.display,
                ordinal = entry.display,
              }
            end
          end,
        }),
        sorter = sorters.get_fuzzy_file(),
        attach_mappings = function(prompt_bufnr, map)
          local function open_selected()
            local selection = action_state.get_selected_entry()
            if selection and not selection.value.is_header then
              actions.close(prompt_bufnr)
              vim.api.nvim_set_current_buf(selection.value.buf)
              vim.api.nvim_win_set_cursor(
                0,
                { selection.value.lnum + 1, selection.value.col }
              )
            end
          end

          map('i', '<CR>', open_selected)
          map('n', '<CR>', open_selected)
          return true
        end,
      })
      :find()
  end)
end

return M
