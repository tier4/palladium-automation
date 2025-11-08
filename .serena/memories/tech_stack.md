# Tech Stack

## Hardware Description Languages
- **Verilog**: RTL design language
- **SystemVerilog**: Extended verification and testbench language

## EDA Tools (on ga53pd01)
- **Xcelium**: Cadence simulation tool
- **Palladium**: Hardware emulation platform
- **IXCOM**: Palladium control interface

## Automation Stack
- **Bash**: Shell scripting for automation
- **SSH**: Remote execution via ProxyJump (bastion → ga53pd01)
- **Git**: Version control for both projects
- **Serena MCP**: Verilog code analysis and editing

## Development Environment
- **Local**: RHEL8 on ip-172-17-34-126
- **Remote**: RHEL8 on ga53pd01 (Palladium chamber)
- **Network**: SSH ProxyJump through 10.108.64.1 bastion
