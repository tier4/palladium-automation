# Codebase Structure

## Top-Level Directories

```
palladium-automation/
├── hornet/              # Cloned hornet GPU/GPGPU project
│   ├── src/            # RTL source files (Verilog/SystemVerilog)
│   ├── eda/            # EDA tool configs, testbenches
│   ├── tb/             # Testbench files
│   ├── doc/            # Documentation
│   └── .serena/        # Serena project configuration
│
├── scripts/            # Automation scripts
│   ├── claude_to_ga53pd01.sh       # Main SSH execution script
│   ├── start_serena_hornet.sh      # Serena MCP launcher
│   └── .legacy/                     # Old xdotool-based scripts
│
├── workspace/          # Execution workspace
│   └── etx_results/
│       └── .archive/                # Archived execution results
│
├── docs/               # Documentation
│   ├── setup.md                     # SSH setup guide
│   ├── ssh_direct_retrieval_test.md # Performance comparison
│   ├── .legacy/                     # Legacy docs
│   └── integration_plans/           # Future integration plans
│
├── mcp-servers/        # Legacy MCP servers (no longer used)
├── .serena/            # Serena project configuration
├── CLAUDE.md           # Claude Code project instructions
└── README.md           # Project overview
```

## Key File Locations

### Hornet RTL
- `hornet/src/*.sv` - Main RTL modules
- `hornet/src/debug-spec/*.sv` - Debug interface modules
- `hornet/src/trace/*.sv` - Trace modules
- `hornet/src/fpu/*.sv` - Floating-point unit

### Hornet EDA
- `hornet/eda/palladium-t4-sba/Makefile` - Palladium build configuration
- `hornet/eda/xcelium-verifore/` - Xcelium testbenches

### Automation
- `scripts/claude_to_ga53pd01.sh` - Primary automation script
- `.serena/project.yml` - Serena configuration with project context
