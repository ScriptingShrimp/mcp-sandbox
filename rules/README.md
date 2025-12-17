# MCPHost Rules and Guidelines

This directory contains rules and guidelines for using MCPHost effectively. These rules help navigate the codebase, add MCP servers, validate configurations, and troubleshoot deployment issues.

## Overview

These rules are extracted from the MCPHost documentation and codebase to provide:
- **Configuration validation rules** - How to detect and fix configuration errors
- **MCP server addition guides** - Step-by-step instructions for adding servers
- **Debug and troubleshooting** - How to enable debug mode and diagnose issues

## Files

- **[repository-rules.md](./repository-rules.md)** - Configuration file linting, error detection, debug flags, and troubleshooting guides
- **[mcp-servers.md](./mcp-servers.md)** - Comprehensive guide for adding local, remote, and builtin MCP servers with examples

## Quick Start

1. **Adding a new MCP server?** → See [mcp-servers.md](./mcp-servers.md)
2. **Configuration errors?** → See [repository-rules.md](./repository-rules.md#configuration-validation-rules)
3. **Troubleshooting deployment?** → See [repository-rules.md](./repository-rules.md#debug-and-troubleshooting)

## Purpose

These rules are designed for **using MCPHost**, not for contributing to the upstream project. They help you:
- Navigate the MCPHost configuration system
- Add and configure MCP servers correctly
- Validate configuration files before deployment
- Debug issues during deployment and operation

## Source

Rules are extracted from:
- `doc-src/mcphost/README.md` - Official documentation
- `doc-src/mcphost/internal/config/` - Configuration validation code
- `doc-src/mcphost/internal/tools/` - MCP connection and debugging code
- `doc-src/mcphost/examples/` - Example configurations and scripts

