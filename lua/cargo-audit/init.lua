local M = {}

M.ns = vim.api.nvim_create_namespace('cargo-audit')

function M.cargo_metadata(cwd, cb)
  M.log.debug('starting cargo_metadata')
  vim.system({ 'cargo', 'metadata', '--format-version', '1', '--no-deps' }, { cwd = cwd, text = true }, function(res)
    if not res.stdout then
      M.log.error(res.stderr)
      vim.schedule(function()
        cb(nil, res.stderr)
      end)
      return
    end

    M.log.debug(res.stdout)
    local ok, data = pcall(vim.json.decode, res.stdout)
    vim.schedule(function()
      if ok then
        M.log.debug(data)
        cb(data, nil)
      else
        M.log.error(ok)
        cb(nil, 'failed to parse cargo metadata')
      end
    end)
  end)
end

function M.index_workspace_dependencies(metadata)
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

  local name = dep.rename or dep.name

  for i, line in ipairs(lines) do
    if line:match('^%s*' .. name .. '%s*=') then
      return bufnr, i - 1
    end
  end

  return bufnr, 0
end

function M.on_audit_complete(metadata, audit_json)
  local dep_index = M.index_workspace_dependencies(metadata)
  local vulns = audit_json.vulnerabilities and audit_json.vulnerabilities.list or {}

  -- Clear existing diagnostics
  for _, pkg in ipairs(metadata.packages) do
    local bufnr = vim.fn.bufnr(pkg.manifest_path, true)
    vim.diagnostic.reset(M.ns, bufnr)
  end

  for _, v in ipairs(vulns) do
    local adv = v.advisory
    local pkg = v.package
    local dependents = dep_index[pkg.name] or {}

    M.log.debug('adding ' .. pkg.name)

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
end

function M.run(opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()

  M.log.debug('calling cargo_metadata')
  M.cargo_metadata(cwd, function(metadata, err)
    if err then
      M.log.error('running cargo metadata failed')
      M.log.error(err)
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    M.log.debug('calling cargo-audit')
    vim.system({ 'cargo', 'audit', '--json' }, { cwd = cwd, text = true }, function(res)
      if not res.stdout then
        M.log.error('running cargo audit failed')
        M.log.error(res.stderr)
        return
      end

      local ok, audit_json = pcall(vim.json.decode, res.stdout)
      if not ok then
        M.log.error('failed to parse cargo-audit JSON')
        return
      end

      vim.schedule(function()
        M.on_audit_complete(metadata, audit_json)
        M.log.debug('finished on_audit_complete')
      end)
    end)
  end)
end

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

return M
