local M = {}

---@class Vulnerability
---@field crate string
---@field version string
---@field advisory? number
---@field severity? number
---@field kind string
---@field url? string
---@field title? string

---Collect the vulnerabilities returned by `cargo-audit`
---@param audit CargoAuditReport the json data returned by cargo-audit
---@return Vulnerability[] collected cargo vulnerabilities
function M.collect_vulnerabilities(audit)
  local findings = {}

  if audit.vulnerabilities then
    for _, v in ipairs(audit.vulnerabilities.list or {}) do
      table.insert(findings, {
        crate = v.package.name,
        version = v.package.version,
        advisory = v.advisory.id,
        severity = v.advisory.severity,
        title = v.advisory.title,
        kind = 'vulnerability',
        url = v.advisory.url,
      })
    end
  end

  if audit.warnings then
    for _, y in ipairs(audit.warnings.yanked or {}) do
      table.insert(findings, {
        crate = y.name,
        version = y.version,
        kind = 'yanked',
      })
    end

    for _, u in ipairs(audit.warnings.unmaintained or {}) do
      table.insert(findings, {
        crate = u.package.name,
        version = u.package.version,
        kind = 'unmaintained',
        title = u.advisory.title,
      })
    end

    for _, u in ipairs(audit.warnings.unsound or {}) do
      table.insert(findings, {
        crate = u.package.name,
        version = u.package.version,
        kind = 'unsound',
        title = u.advisory.title,
      })
    end
  end

  return findings
end

return M
