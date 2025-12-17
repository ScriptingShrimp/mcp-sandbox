# MCP Server Addition Guide

This guide provides comprehensive instructions for adding MCP servers to MCPHost. MCPHost supports three types of servers: **local**, **remote**, and **builtin**.

## Table of Contents

- [Configuration File Location](#configuration-file-location)
- [Server Types Overview](#server-types-overview)
- [Local Servers](#local-servers)
- [Remote Servers](#remote-servers)
- [Builtin Servers](#builtin-servers)
- [Tool Filtering](#tool-filtering)
- [Environment Variable Substitution](#environment-variable-substitution)
- [Legacy Configuration Support](#legacy-configuration-support)
- [Best Practices](#best-practices)
- [Examples](#examples)

## Configuration File Location

MCPHost looks for configuration files in this order:
1. `.mcphost.yml` or `.mcphost.json` (preferred)
2. `.mcp.yml` or `.mcp.json` (backwards compatibility)

**Config file locations by OS:**
- **Linux/macOS**: `~/.mcphost.yml`, `~/.mcphost.json`, `~/.mcp.yml`, `~/.mcp.json`
- **Windows**: `%USERPROFILE%\.mcphost.yml`, `%USERPROFILE%\.mcphost.json`, `%USERPROFILE%\.mcp.yml`, `%USERPROFILE%\.mcp.json`

You can also specify a custom location using the `--config` flag:
```bash
mcphost --config /path/to/custom-config.json
```

## Server Types Overview

MCPHost supports three server types:

| Type | Transport | Use Case | Performance |
|------|-----------|----------|-------------|
| **local** | stdio | Run MCP servers as local processes | Good |
| **remote** | streamable/sse | Connect to remote MCP servers via HTTP | Good |
| **builtin** | inprocess | Use builtin servers (fs, bash, todo, http, fetch) | Excellent |

## Local Servers

Local servers run MCP server processes on your machine and communicate via stdin/stdout (stdio transport).

### Basic Configuration

**Required Fields:**
- `type`: Must be `"local"`
- `command`: Array containing the command and all its arguments

**Optional Fields:**
- `environment`: Object with environment variables as key-value pairs
- `allowedTools`: Array of tool names to include (whitelist)
- `excludedTools`: Array of tool names to exclude (blacklist)

### Example 1: NPX-based Server

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    }
  }
}
```

**YAML Format:**
```yaml
mcpServers:
  filesystem:
    type: local
    command:
      - npx
      - -y
      - "@modelcontextprotocol/server-filesystem"
      - /tmp
```

### Example 2: Docker-based Server

```json
{
  "mcpServers": {
    "github": {
      "type": "local",
      "command": [
        "docker",
        "run",
        "-i",
        "--rm",
        "-e",
        "GITHUB_PERSONAL_ACCESS_TOKEN=${env://GITHUB_TOKEN}",
        "ghcr.io/github/github-mcp-server"
      ],
      "environment": {
        "DEBUG": "${env://DEBUG:-false}"
      }
    }
  }
}
```

### Example 3: Python/UV-based Server

```json
{
  "mcpServers": {
    "sqlite": {
      "type": "local",
      "command": ["uvx", "mcp-server-sqlite", "--db-path", "${env://DB_PATH:-/tmp/foo.db}"],
      "environment": {
        "SQLITE_DEBUG": "${env://DEBUG:-0}",
        "DATABASE_URL": "${env://DATABASE_URL:-sqlite:///tmp/foo.db}"
      }
    }
  }
}
```

### Example 4: Custom Binary Server

```json
{
  "mcpServers": {
    "custom-server": {
      "type": "local",
      "command": ["/usr/local/bin/my-mcp-server", "--config", "/etc/mcp/config.json"],
      "environment": {
        "API_KEY": "${env://API_KEY}",
        "LOG_LEVEL": "${env://LOG_LEVEL:-info}"
      }
    }
  }
}
```

### Environment Variables

You can pass environment variables to local servers:

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "local",
      "command": ["npx", "@modelcontextprotocol/server-filesystem", "/tmp"],
      "environment": {
        "DEBUG": "${env://DEBUG:-false}",
        "LOG_LEVEL": "${env://LOG_LEVEL:-info}",
        "API_TOKEN": "${env://FS_API_TOKEN}"
      }
    }
  }
}
```

### Common Local Server Patterns

**NPX Servers (Node.js):**
```json
{
  "command": ["npx", "-y", "@modelcontextprotocol/server-name"]
}
```

**Docker Containers:**
```json
{
  "command": ["docker", "run", "-i", "--rm", "image-name"]
}
```

**Python/UV Servers:**
```json
{
  "command": ["uvx", "mcp-server-name", "--arg", "value"]
}
```

**Bun Servers:**
```json
{
  "command": ["bun", "x", "mcp-server-name"]
}
```

## Remote Servers

Remote servers connect to MCP servers accessible via HTTP using the StreamableHTTP transport.

### Basic Configuration

**Required Fields:**
- `type`: Must be `"remote"`
- `url`: The URL where the MCP server is accessible

**Optional Fields:**
- `headers`: Array of HTTP headers for authentication and custom headers
- `allowedTools`: Array of tool names to include (whitelist)
- `excludedTools`: Array of tool names to exclude (blacklist)

### Example 1: Basic Remote Server

```json
{
  "mcpServers": {
    "weather": {
      "type": "remote",
      "url": "https://weather-mcp.example.com"
    }
  }
}
```

### Example 2: Remote Server with Authentication

```json
{
  "mcpServers": {
    "websearch": {
      "type": "remote",
      "url": "${env://WEBSEARCH_URL:-https://api.example.com/mcp}",
      "headers": [
        "Authorization: Bearer ${env://WEBSEARCH_TOKEN}",
        "X-API-Version: v1"
      ]
    }
  }
}
```

### Example 3: Remote Server with Custom Headers

```json
{
  "mcpServers": {
    "custom-api": {
      "type": "remote",
      "url": "https://api.example.com/mcp",
      "headers": [
        "Authorization: Bearer ${env://API_TOKEN}",
        "Content-Type: application/json",
        "X-Client-ID: ${env://CLIENT_ID}"
      ]
    }
  }
}
```

### Header Format

Headers are specified as strings in the format `"Header-Name: value"`:
- `"Authorization: Bearer token"`
- `"X-Custom-Header: value"`
- Multiple headers can be provided in an array

### Remote Server Best Practices

1. **Use HTTPS** for production deployments
2. **Store tokens in environment variables** using `${env://VAR}` syntax
3. **Use default URLs** with `${env://VAR:-default}` for flexibility
4. **Test connectivity** before adding to production config

## Builtin Servers

Builtin servers run in-process for optimal performance. MCPHost includes several builtin servers that don't require external processes.

### Available Builtin Servers

| Name | Description | Options |
|------|-------------|---------|
| `fs` | Filesystem access with security restrictions | `allowed_directories` (array) |
| `bash` | Execute bash commands with security restrictions | None |
| `todo` | Manage ephemeral todo lists | None |
| `http` | Fetch and process web content | None |
| `fetch` | Fetch web content (legacy name for http) | None |

### Filesystem Server (fs)

Provides secure filesystem access with configurable allowed directories.

**Configuration:**
```json
{
  "mcpServers": {
    "filesystem": {
      "type": "builtin",
      "name": "fs",
      "options": {
        "allowed_directories": ["/tmp", "/home/user/documents", "${env://WORK_DIR:-/tmp}"]
      }
    }
  }
}
```

**Minimal Configuration (uses current working directory):**
```json
{
  "mcpServers": {
    "filesystem": {
      "type": "builtin",
      "name": "fs"
    }
  }
}
```

**Options:**
- `allowed_directories`: Array of directory paths the server can access
  - If not specified, defaults to current working directory
  - Supports environment variable substitution
  - Can be a single string or array of strings

### Bash Server

Executes bash commands with security restrictions and timeout controls.

**Configuration:**
```json
{
  "mcpServers": {
    "bash-commands": {
      "type": "builtin",
      "name": "bash"
    }
  }
}
```

**No options required** - bash server works out of the box.

### Todo Server

Manages ephemeral todo lists for task tracking during sessions.

**Configuration:**
```json
{
  "mcpServers": {
    "task-manager": {
      "type": "builtin",
      "name": "todo"
    }
  }
}
```

**Note:** Todos are stored in memory and reset on restart.

### HTTP Server

Fetches web content and converts to text, markdown, or HTML formats. Also provides AI-powered summarization and extraction.

**Configuration:**
```json
{
  "mcpServers": {
    "web-fetcher": {
      "type": "builtin",
      "name": "http"
    }
  }
}
```

**Available Tools:**
- `fetch` - Fetch and convert web content
- `fetch_summarize` - Fetch and summarize web content using AI
- `fetch_extract` - Fetch and extract specific data using AI
- `fetch_filtered_json` - Fetch JSON and filter using gjson path syntax

### Builtin Server Examples

**Multiple Builtin Servers:**
```json
{
  "mcpServers": {
    "filesystem": {
      "type": "builtin",
      "name": "fs",
      "options": {
        "allowed_directories": ["/tmp", "/home/user/documents"]
      }
    },
    "bash-commands": {
      "type": "builtin",
      "name": "bash"
    },
    "task-manager": {
      "type": "builtin",
      "name": "todo"
    },
    "web-fetcher": {
      "type": "builtin",
      "name": "http"
    }
  }
}
```

## Tool Filtering

All MCP server types support tool filtering to restrict which tools are available from a server.

### Allowed Tools (Whitelist)

Only specified tools are available from the server. Use this for security when you want to limit access.

```json
{
  "mcpServers": {
    "filesystem-readonly": {
      "type": "builtin",
      "name": "fs",
      "allowedTools": ["read_file", "list_directory"]
    }
  }
}
```

### Excluded Tools (Blacklist)

All tools except specified ones are available. Use this when you want to block specific dangerous tools.

```json
{
  "mcpServers": {
    "filesystem-safe": {
      "type": "local",
      "command": ["npx", "@modelcontextprotocol/server-filesystem", "/tmp"],
      "excludedTools": ["delete_file"]
    }
  }
}
```

### Important Rules

1. **Mutually Exclusive**: `allowedTools` and `excludedTools` cannot be used together on the same server
2. **Tool Names**: Use exact tool names as provided by the MCP server
3. **Case Sensitive**: Tool names are case-sensitive

### When to Use Each

**Use `allowedTools` (whitelist) when:**
- You want maximum security
- You only need a few specific tools
- You're unsure what tools a server provides

**Use `excludedTools` (blacklist) when:**
- You want most tools but need to block a few
- You're confident about the server's tool set
- You want to allow new tools automatically

## Environment Variable Substitution

MCPHost supports environment variable substitution in configuration files using two syntaxes:

### Required Variables

```json
{
  "mcpServers": {
    "github": {
      "type": "local",
      "command": ["gh", "api"],
      "environment": {
        "GITHUB_TOKEN": "${env://GITHUB_TOKEN}"
      }
    }
  }
}
```

**Behavior:**
- Variable must be set in environment
- Configuration fails if variable is not set
- Error: `required environment variable GITHUB_TOKEN not set`

### Optional Variables with Defaults

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "local",
      "command": ["npx", "@modelcontextprotocol/server-filesystem", "${env://WORK_DIR:-/tmp}"],
      "environment": {
        "DEBUG": "${env://DEBUG:-false}",
        "LOG_LEVEL": "${env://LOG_LEVEL:-info}"
      }
    }
  }
}
```

**Behavior:**
- Uses default value if variable is not set
- Uses environment value if variable is set
- Supports empty defaults: `${env://VAR:-}`

### Usage Example

```bash
# Set required variables
export GITHUB_TOKEN="ghp_your_token_here"
export OPENAI_API_KEY="your_openai_key"

# Optionally override defaults
export DEBUG="true"
export WORK_DIR="/home/user/projects"
export LOG_LEVEL="debug"

# Run mcphost
mcphost
```

### Variable Substitution in Different Contexts

**In Command Arguments:**
```json
{
  "command": ["npx", "@modelcontextprotocol/server-filesystem", "${env://WORK_DIR:-/tmp}"]
}
```

**In Environment Variables:**
```json
{
  "environment": {
    "API_KEY": "${env://API_KEY}",
    "DEBUG": "${env://DEBUG:-false}"
  }
}
```

**In URLs:**
```json
{
  "url": "${env://API_URL:-https://api.example.com/mcp}"
}
```

**In Headers:**
```json
{
  "headers": ["Authorization: Bearer ${env://TOKEN}"]
}
```

**In Builtin Server Options:**
```json
{
  "options": {
    "allowed_directories": ["${env://WORK_DIR:-/tmp}", "${env://HOME}/documents"]
  }
}
```

## Legacy Configuration Support

MCPHost maintains backward compatibility with legacy configuration formats. However, the new simplified format is recommended.

### Legacy STDIO Format

```json
{
  "mcpServers": {
    "sqlite": {
      "command": "uvx",
      "args": ["mcp-server-sqlite", "--db-path", "/tmp/foo.db"],
      "env": {
        "DEBUG": "true"
      }
    }
  }
}
```

**Note:** This format is automatically converted to the new format internally.

### Legacy SSE Format

```json
{
  "mcpServers": {
    "server_name": {
      "url": "http://some_host:8000/sse",
      "headers": ["Authorization: Bearer my-token"]
    }
  }
}
```

**Note:** SSE transport is legacy; use `"type": "remote"` for new configurations.

### Legacy Docker/Container Format

```json
{
  "mcpServers": {
    "phalcon": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "ghcr.io/mark3labs/phalcon-mcp:latest",
        "serve"
      ]
    }
  }
}
```

**Modern Equivalent:**
```json
{
  "mcpServers": {
    "phalcon": {
      "type": "local",
      "command": ["docker", "run", "-i", "--rm", "ghcr.io/mark3labs/phalcon-mcp:latest", "serve"]
    }
  }
}
```

## Best Practices

### 1. Use Environment Variables for Secrets

**Bad:**
```json
{
  "mcpServers": {
    "api": {
      "type": "remote",
      "url": "https://api.example.com",
      "headers": ["Authorization: Bearer secret-token-12345"]
    }
  }
}
```

**Good:**
```json
{
  "mcpServers": {
    "api": {
      "type": "remote",
      "url": "https://api.example.com",
      "headers": ["Authorization: Bearer ${env://API_TOKEN}"]
    }
  }
}
```

### 2. Use Defaults for Flexibility

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "local",
      "command": ["npx", "@modelcontextprotocol/server-filesystem", "${env://WORK_DIR:-/tmp}"]
    }
  }
}
```

### 3. Prefer Builtin Servers When Available

Builtin servers offer better performance and don't require external processes:

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "builtin",
      "name": "fs"
    }
  }
}
```

### 4. Use Tool Filtering for Security

Restrict dangerous tools:

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "builtin",
      "name": "fs",
      "allowedTools": ["read_file", "list_directory"]
    }
  }
}
```

### 5. Test Configuration Before Deployment

Enable debug mode to verify configuration:

```bash
mcphost --debug
```

Check for:
- Server status (should show "loaded" not "failed")
- Environment variable substitution
- Connection success

### 6. Use Descriptive Server Names

**Bad:**
```json
{
  "mcpServers": {
    "s1": { ... },
    "s2": { ... }
  }
}
```

**Good:**
```json
{
  "mcpServers": {
    "github-api": { ... },
    "filesystem-readonly": { ... }
  }
}
```

### 7. Document Complex Configurations

Add comments in YAML or maintain a separate documentation file:

```yaml
mcpServers:
  # GitHub API server using Docker
  github:
    type: local
    command:
      - docker
      - run
      - -i
      - --rm
      - ghcr.io/github/github-mcp-server
```

## Examples

### Complete Configuration Example

```json
{
  "mcpServers": {
    "filesystem": {
      "type": "builtin",
      "name": "fs",
      "options": {
        "allowed_directories": ["/tmp", "/home/user/documents"]
      },
      "allowedTools": ["read_file", "write_file", "list_directory"]
    },
    "github": {
      "type": "local",
      "command": ["docker", "run", "-i", "--rm", "ghcr.io/github/github-mcp-server"],
      "environment": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${env://GITHUB_TOKEN}"
      }
    },
    "websearch": {
      "type": "remote",
      "url": "${env://WEBSEARCH_URL:-https://api.example.com/mcp}",
      "headers": ["Authorization: Bearer ${env://WEBSEARCH_TOKEN}"]
    },
    "bash": {
      "type": "builtin",
      "name": "bash"
    },
    "todo": {
      "type": "builtin",
      "name": "todo"
    }
  },
  "model": "${env://MODEL:-anthropic:claude-sonnet-4-20250514}",
  "debug": false
}
```

### YAML Configuration Example

```yaml
mcpServers:
  filesystem:
    type: builtin
    name: fs
    options:
      allowed_directories:
        - /tmp
        - "${env://HOME}/documents"
    allowedTools:
      - read_file
      - write_file
      - list_directory

  github:
    type: local
    command:
      - docker
      - run
      - -i
      - --rm
      - ghcr.io/github/github-mcp-server
    environment:
      GITHUB_PERSONAL_ACCESS_TOKEN: "${env://GITHUB_TOKEN}"
      DEBUG: "${env://DEBUG:-false}"

  websearch:
    type: remote
    url: "${env://WEBSEARCH_URL:-https://api.example.com/mcp}"
    headers:
      - "Authorization: Bearer ${env://WEBSEARCH_TOKEN}"

model: "${env://MODEL:-anthropic:claude-sonnet-4-20250514}"
debug: false
```

### Script Configuration Example

Scripts can define MCP servers in their frontmatter:

```yaml
#!/usr/bin/env -S mcphost script
---
mcpServers:
  github:
    type: local
    command: ["gh", "api"]
    environment:
      GITHUB_TOKEN: "${env://GITHUB_TOKEN}"
      DEBUG: "${env://DEBUG:-false}"
  
  filesystem:
    type: builtin
    name: fs
    options:
      allowed_directories: ["${env://WORK_DIR:-/tmp}"]

model: "${env://MODEL:-anthropic:claude-sonnet-4-20250514}"
---
List repositories for user ${username}.
```

## Troubleshooting

### Server Not Loading

1. **Check debug output:**
   ```bash
   mcphost --debug
   ```

2. **Verify server status:**
   - Look for "loaded" vs "failed" in debug config display

3. **Check required fields:**
   - Local servers need `command`
   - Remote servers need `url`
   - Builtin servers need `name`

### Environment Variable Issues

1. **Check if variables are set:**
   ```bash
   echo $GITHUB_TOKEN
   ```

2. **Test substitution:**
   ```bash
   mcphost --debug 2>&1 | grep "environment variable"
   ```

3. **Use defaults for optional variables:**
   ```json
   "${env://VAR:-default}"
   ```

### Connection Failures

1. **For local servers:**
   - Verify command exists and is executable
   - Check server logs
   - Test command manually

2. **For remote servers:**
   - Verify URL is accessible
   - Check authentication headers
   - Test with curl or similar tool

3. **For builtin servers:**
   - Verify server name is correct (fs, bash, todo, http, fetch)
   - Check options format

### Tool Filtering Issues

1. **Verify tool names:**
   - Use exact tool names from server
   - Check case sensitivity

2. **Don't mix allowedTools and excludedTools:**
   - Use only one filtering method per server

For more troubleshooting help, see [repository-rules.md](./repository-rules.md#troubleshooting-deployment).

