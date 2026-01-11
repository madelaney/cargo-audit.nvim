# Cargo Audit

Runs `cargo audit` on `Cargo.toml` save and open operations

## Installation

### lazy.git

```lua
  {
    'madelaney/cargo-audit.nvim',
    version = '^0.1',
    opts = {
      toml = {
        -- Run cargo-check on Cargo.toml files
        enabled = true,
      },
      lock = {
        -- Run cargo-check on Cargo.lock files
        enabled = true,
      },
    }
  },
```
