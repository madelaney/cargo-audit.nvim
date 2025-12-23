---@class CargoAuditReport
---@field vulnerabilities CargoAuditVulnerabilities
---@field warnings CargoAuditWarnings
---@field metadata CargoAuditMetadata
---@field database CargoAuditDatabase
---@field lockfile CargoAuditLockfile
---@field settings CargoAuditSettings

---@class CargoAuditDatabase
---@field advisory-count number
---@field last-commit string
---@field last-updated string

---@class CargoAuditLockfile
---@field dependency-count number

---@class CargoAuditSettings
---@field target_arch string[]
---@field target_os string[]
---@field severity? string
---@field ignore string[]
---@field informational_warnings string[]

---@class CargoAuditVulnerabilities
---@field found boolean
---@field count integer
---@field list CargoAuditVulnerability[]

---@class CargoAuditVulnerability
---@field advisory CargoAuditAdvisory
---@field package CargoAuditPackage
---@field versions CargoAuditVersions

---@class CargoAuditAdvisory
---@field id string              # e.g. "RUSTSEC-2022-0001"
---@field title string
---@field description string
---@field severity? "critical"|"high"|"medium"|"low"
---@field url string
---@field date string
---@field aliases string[]
---@field categories string[]

---@class CargoAuditPackage
---@field name string
---@field version string
---@field source string

---@class CargoAuditVersions
---@field patched string[]
---@field unaffected string[]

---@class CargoAuditWarnings
---@field yanked CargoAuditYanked[]
---@field unmaintained CargoAuditUnmaintained[]
---@field unsound CargoAuditUnsound[]

---@class CargoAuditYanked
---@field name string
---@field version string
---@field reason? string

---@class CargoAuditUnmaintained
---@field advisory CargoAuditAdvisory
---@field package CargoAuditPackage

---@class CargoAuditUnsound
---@field advisory CargoAuditAdvisory
---@field package CargoAuditPackage

---@class CargoAuditMetadata
---@field cargo_lock_version integer
---@field rustsec_version string
---@field advisory_db CargoAuditAdvisoryDB

---@class CargoAuditAdvisoryDB
---@field path string
---@field revision string
---@field last_fetch string
