---@class CargoMetadata
---@field packages CargoMetadataPackage[]
---@field resolve CargoMetadataResolve
---@field workspace_members string[]
---@field workspace_root string
---@field target_directory string
---@field version integer

---@class CargoMetadataPackage
---@field name string
---@field version string
---@field id string
---@field source? string
---@field description? string
---@field dependencies CargoMetadataDependency[]
---@field targets CargoMetadataTarget[]
---@field features table<string, string[]>
---@field manifest_path string
---@field edition string
---@field license? string
---@field repository? string
---@field homepage? string
---@field documentation? string

---@class CargoMetadataDependency
---@field name string
---@field source? string
---@field req string              # version requirement (e.g. "^1.0")
---@field kind? "normal"|"dev"|"build"
---@field rename? string
---@field optional boolean
---@field uses_default_features boolean
---@field features string[]
---@field target? string

---@class CargoMetadataTarget
---@field name string
---@field kind string[]           # e.g. ["lib"], ["bin"]
---@field crate_types string[]
---@field src_path string
---@field edition string
---@field doctest boolean
---@field test boolean

---@class CargoMetadataResolve
---@field nodes CargoMetadataNode[]
---@field root? string

---@class CargoMetadataNode
---@field id string
---@field dependencies string[]   # package IDs
---@field deps CargoMetadataNodeDep[]
---@field features string[]

---@class CargoMetadataNodeDep
---@field name string
---@field pkg string              # package ID
---@field dep_kinds CargoMetadataDepKind[]

---@class CargoMetadataDepKind
---@field kind? "normal"|"dev"|"build"
---@field target? string
