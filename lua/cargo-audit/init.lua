local M = {}

M.cargo_toml_ns = vim.api.nvim_create_namespace('cargo_toml')
M.cargo_lock_ns = vim.api.nvim_create_namespace('cargo_lock')

function M.setup(opts)
  M.opts = opts or {}

  vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost' }, {
    pattern = 'Cargo.toml',
    callback = function()
      M.cargo_toml_audit()
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufReadPost', 'FileChangedShellPost' }, {
    pattern = 'Cargo.lock',
    callback = function()
      M.cargo_lock_audit()
    end,
  })
end

--- Search a Cargo.toml for a line that defines a dependency
---@param cargo_toml string Cargo,tink to parse
---@param package_name string Name of the package to search for
---@return number|nil Line number (-1) of the dependency or nil
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

function M.find_file(file, parent)
  for path in vim.fs.parents(parent) do
    local cargo = path .. '/' .. file
    if vim.fn.filereadable(cargo) == 1 then
      return cargo
    end
  end
  return nil
end

--- Search up the tree for a Cargo.toml
---@param start string Directory to start looking for a Cargo.toml for
---@return string|nil The path to Cargo.toml or nil
function M.find_cargo_toml(start)
  return M.find_file('Cargo.toml', start)
end

--- Search up the tree for a Cargo.lock
---@param start string Directory to start looking for a Cargo.lock for
---@return string|nil The path to Cargo.lock or nil
function M.find_cargo_lock(start)
  return M.find_file('Cargo.lock', start)
end

--- Convert `cargo-audit` json to diagnostics table
---@param cargo string Cargo.toml file to parse
---@param report table JSON response from `cargo-audit`
---@return table Diagnostics table set
function M.advisories_to_diagnostics(cargo, report)
  local diags = {}

  if not report or not report.vulnerabilities then
    return diags
  end

  local list = report.vulnerabilities.list or {}

  local dependencies = 0

  M.lines = M.read_file(cargo)
  for i, line in ipairs(M.lines) do
    if line == '[dependencies]' then
      dependencies = i - 1
    end
  end

  for _, vuln in ipairs(list) do
    local advisory = vuln.advisory or {}
    local pkg = vuln.package or {}

    table.insert(diags, {
      lnum = M.find_dependency_lnum(cargo, pkg.name) or dependencies,
      end_lnum = 0,
      col = 0,
      end_col = 0,
      severity = vim.diagnostic.severity.WARN,
      message = string.format(
        '[%s] %s (pkg: %s %s)',
        advisory.id or 'UNKNOWN',
        advisory.title or 'No title',
        pkg.name or 'unknown',
        pkg.version or 'unknown'
      ),
      source = 'cargo-audit',
    })
  end

  local advisories = {
    yanked = {
      message = 'Package %s %s has been YANKED from crates.io',
      severity = vim.diagnostic.severity.WARN,
    },
    unsound = {
      severity = vim.diagnostic.severity.HINT,
    },
    unmaintained = {
      message = 'Package %s is not maintained on crates.io',
      severity = vim.diagnostic.severity.WARN,
    },
    other = {
      message = 'Cargo-audit warning for %s %s: %s',
      severity = vim.diagnostic.severity.HINT,
    },
  }

  local warnings = report.warnings or {}

  for key, config in pairs(advisories) do
    for _, entry in ipairs(warnings[key] or {}) do
      local pkg = entry.package or {}
      local advisory = entry.advisory or {}

      local name = pkg.name or 'unknown'
      local version = pkg.version or 'unknown'

      local lnum = M.find_dependency_lnum(cargo, name) or 0

      local message
      if key == 'yanked' then
        message = config.message:format(version, name)
      elseif key == 'unmaintained' then
        message = config.message:format(name)
      else
        message = string.format('%s %s', version, advisory.title)
      end

      table.insert(diags, {
        lnum = lnum,
        end_lnum = lnum,
        col = 0,
        severity = config.severity,
        message = message,
        source = 'cargo-audit',
      })
    end
  end

  return diags
end

--- Run `cargo-audit` and add results to diagnostics
function M.cargo_toml_audit()
  local current_file = vim.api.nvim_buf_get_name(0)
  local cargo_toml = current_file
  local cargo_lock = M.find_cargo_lock(current_file)

  --- since this is triggered by a nvim_create_autocmd event on the Cargo.toml,
  --- it's unlikely we won't find a Cargo.toml but lets be sure.
  if not cargo_toml then
    vim.notify('cargo-audit: Could not find Cargo.toml', vim.log.levels.ERROR)
    return
  --- Cargo.lock may *not* be in the same directory as Cargo.toml so we'll have
  --- to search the tree for a Cargo.lock
  elseif not cargo_lock then
    vim.notify('cargo-audit: Could not find Cargo.lock', vim.log.levels.ERROR)
    return
  end

  vim.system({ 'cargo', 'audit', '--json', '--file', cargo_lock }, { text = true }, function(res)
    if res.code ~= 0 and res.code ~= 1 then
      vim.schedule(function()
        vim.notify('cargo-audit failed: ' .. res.stderr, vim.log.levels.ERROR)
      end)
      return
    end

    local decoded = nil
    pcall(function()
      decoded = vim.json.decode(res.stdout)
    end)

    if not decoded then
      vim.schedule(function()
        vim.notify('cargo-audit: failed to parse JSON', vim.log.levels.ERROR)
      end)
      return
    end

    local diagnostics = M.advisories_to_diagnostics(cargo_toml, decoded)

    vim.schedule(function()
      vim.diagnostic.set(M.cargo_toml_ns, 0, diagnostics, {})
      vim.notify('cargo-audit: diagnostics updated', vim.log.levels.INFO)
    end)
  end)
end

--- Read a file in a safe async behavior
---@param path string file to read
---@return table Lines of the file
function M.read_file(path)
  local uv = vim.uv or vim.loop

  local fd = uv.fs_open(path, 'r', 438)
  if not fd then
    return {}
  end

  local stat = uv.fs_fstat(fd)
  if not stat then
    uv.fs_close(fd)
    return {}
  end

  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)

  if not data then
    return {}
  end

  local lines = {}
  for line in data:gmatch('([^\n]*)\n?') do
    table.insert(lines, line)
  end
  return lines
end

--- Parse the Cargo.lock toml file
---@param lines string[] lines from the cargo.lock file
---@return table list of packages
function M.parse_cargo_lock(lines)
  local packages = {}
  local current = {}

  for i, line in ipairs(lines) do
    local name = line:match('^%s*name%s*=%s*"(.-)"')
    if name then
      current = { name = name, line = i }
    end

    local version = line:match('^%s*version%s*=%s*"(.-)"')
    if version and current.name then
      current.version = version
      table.insert(packages, current)
      current = {}
    end
  end

  return packages
end

--- Convert a list of packages to diagnostics entries
---@param packages table list of packages from Cargo.lock
---@param audits table list of audits from `cargo-audit`
---@return table diagnostics entries
function M.build_diagnostics(packages, audits)
  local diags = {}

  for _, vuln in ipairs(audits) do
    local name = vuln.package.name
    local version = vuln.package.version
    local match = nil

    -- match package in parsed Cargo.lock
    for _, pkg in ipairs(packages) do
      if pkg.name == name and pkg.version == version then
        match = pkg
        break
      end
    end

    if match then
      table.insert(diags, {
        lnum = match.line - 1, -- 0-based for diagnostics
        col = 0,
        severity = vim.diagnostic.severity.WARN,
        source = 'cargo-audit',
        message = string.format(
          'Vulnerability %s: %s (%s %s)\n%s',
          vuln.advisory.id,
          vuln.advisory.title or '',
          name,
          version,
          vuln.advisory.description or ''
        ),
      })
    end
  end

  return diags
end

--- Run diagnostics checks
function M.cargo_lock_audit()
  local lockfile = vim.api.nvim_buf_get_name(0)

  local lock_str = M.read_file_as_str(lockfile)
  if not lock_str then
    vim.notify('cargo-audit: Could not read ' .. lockfile, vim.log.levels.ERROR)
    return
  end

  vim.system({ 'cargo', 'audit', '--json', '--file', lockfile }, { text = true }, function(res)
    if res.code ~= 0 and res.code ~= 1 then
      vim.schedule(function()
        vim.notify('cargo-audit failed: ' .. res.stderr, vim.log.levels.ERROR)
      end)
      return
    end

    local decoded = nil
    pcall(function()
      decoded = vim.json.decode(res.stdout)
    end)

    if not decoded then
      vim.schedule(function()
        vim.notify('cargo-audit: failed to parse JSON', vim.log.levels.ERROR)
      end)
      return
    end

    local lines = vim.split(lock_str, '\n', { plain = true })
    local packages = M.parse_cargo_lock(lines)
    local audits = decoded.vulnerabilities.list
    if not audits then
      vim.notify('cargo-audit: JSON parse error', vim.log.levels.ERROR)
      return
    end

    M.log.info(packages)
    M.log.info(audits)
    M.log.info('running build_diagnostics')
    local diags = M.build_diagnostics(packages, audits)
    M.log.info('finished build_diagnostics')

    vim.schedule(function()
      vim.diagnostic.set(M.cargo_lock_ns, 0, diags, {})
      vim.notify('cargo-audit: diagnostics updated', vim.log.levels.INFO)
    end)
  end)
end

--- Read a file as a string
---@param path string path to the file to read in
---@return string|nil lines from the file
function M.read_file_as_str(path)
  local fd = io.open(path, 'r')
  if not fd then
    return nil
  end
  local data = fd:read('*a')
  fd:close()
  return data
end

return M
