local M = {}

M.cargo_toml_ns = vim.api.nvim_create_namespace('cargo_toml')
M.cargo_lock_ns = vim.api.nvim_create_namespace('cargo_lock')

function M.setup(opts)
  M.opts = opts or {}
  M.log = opts.logger or require('plenary.log').new({
    plugin = 'cargo-audit',
    level = 'debug',
  })

  M.log.debug('adding call back for cargo.toml files')
  vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost' }, {
    pattern = 'Cargo.toml',
    callback = function()
      -- M.cargo_toml_audit()
      M.run()
    end,
  })

  M.log.debug('adding call back for cargo.lock files')
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'FileChangedShellPost' }, {
    pattern = 'Cargo.lock',
    callback = function()
      M.run()
    end,
  })
end

function M.cargo_metadata(cwd, cb)
  vim.system({ 'cargo', 'metadata', '--format-version', '1', '--no-deps' }, { cwd = cwd, text = true }, function(res)
    if not res.stdout then
      vim.schedule(function()
        cb(nil, res.stderr)
      end)
      return
    end

    local ok, data = pcall(vim.json.decode, res.stdout)
    vim.schedule(function()
      if not ok then
        cb(nil, 'failed to parse cargo metadata')
      else
        cb(data, nil)
      end
    end)
  end)
end

function M.index_workspace_dependencies(metadata)
  -- map: crate_name -> { { pkg, dep } }
  local index = {}

  for _, pkg in ipairs(metadata.packages) do
    for _, dep in ipairs(pkg.dependencies) do
      local name = dep.rename or dep.name

      index[name] = index[name] or {}
      table.insert(index[name], {
        package = pkg,
        dependency = dep,
      })
    end
  end

  return index
end

function M.find_dependency_line(manifest_path, dep)
  local bufnr = vim.fn.bufnr(manifest_path, true)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local dep_name = dep.rename or dep.name

  for i, line in ipairs(lines) do
    if line:match('^%s*' .. dep_name .. '%s*=') then
      return bufnr, i - 1
    end
  end

  return bufnr, 0
end

function M.run(opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()

  M.cargo_metadata(cwd, function(metadata, meta_err)
    if meta_err then
      return
    end

    local dep_index = M.index_workspace_dependencies(metadata)

    vim.system({ 'cargo', 'audit', '--json' }, { cwd = cwd, text = true }, function(audit)
      if not audit.stdout then
        return
      end

      local ok, data = pcall(vim.json.decode, audit.stdout)
      if not ok then
        return
      end

      vim.schedule(function()
        local vulns = data.vulnerabilities and data.vulnerabilities.list or {}

        -- clear all Cargo.toml diagnostics
        for _, pkg in ipairs(metadata.packages) do
          local bufnr = vim.fn.bufnr(pkg.manifest_path, true)
          vim.diagnostic.reset(M.ns, bufnr)
        end

        for _, v in ipairs(vulns) do
          local adv = v.advisory
          local pkg = v.package
          local dependents = dep_index[pkg.name] or {}

          for _, entry in ipairs(dependents) do
            local bufnr, lnum = M.find_dependency_line(entry.package.manifest_path, entry.dependency)

            vim.diagnostic.set(M.ns, bufnr, {
              {
                lnum = lnum,
                col = 0,
                severity = vim.diagnostic.severity.ERROR,
                source = 'cargo-audit',
                code = adv.id,
                message = string.format('%s (%s %s)', adv.title, pkg.name, pkg.version),
              },
            }, { append = true })
          end
        end
      end)
    end)
  end)
end

----Search a Cargo.toml for a line that defines a dependency
----@param cargo_toml string Cargo,tink to parse
----@param package_name string Name of the package to search for
----@return number|nil Line number (-1) of the dependency or nil
function M.find_dependency_lnum(cargo_toml, package_name)
  if not M.lines then
    M.lines = M.read_file(cargo_toml)
  end

  local lines = M.lines
  local in_deps_section = false

  for i, line in ipairs(lines) do
    local section = line:match('^%s*%[(.-)%]%s*$')
    if section then
      in_deps_section = (section == 'dependencies' or section == 'dev-dependencies' or section == 'build-dependencies')
    end

    if in_deps_section then
      -- match lines like:
      -- serde = "1.0"
      -- serde = { version = "1.0" }
      -- serde = { git = "...", rev = "..." }
      if line:match('^%s*' .. package_name .. '%s*=') then
        return i - 1
      end
    end
  end

  return nil
end

return M
