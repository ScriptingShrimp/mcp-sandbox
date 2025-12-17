# Repository Rules: Configuration Validation and Troubleshooting

This document provides rules for validating MCPHost configuration files, detecting errors, and troubleshooting deployment issues.

## Table of Contents

- [Configuration Validation Rules](#configuration-validation-rules)
- [Environment Variable Validation](#environment-variable-validation)
- [Hook Configuration Validation](#hook-configuration-validation)
- [Debug and Troubleshooting](#debug-and-troubleshooting)
- [Common Configuration Errors](#common-configuration-errors)

## Configuration Validation Rules

MCPHost validates configuration files to ensure all required fields are present and correctly formatted. The validation is performed by `config.Validate()` and `config.LoadAndValidateConfig()`.

### MCP Server Configuration Validation

#### 1. Local Servers (stdio transport)

**Required Fields:**
- `command` array (or legacy `command` + `args`)

**Validation Rules:**
- Command array cannot be empty
- If using new format: `command` must be an array with at least one element
- If using legacy format: `command` (string) + `args` (array) must be provided
- Environment variables are validated for substitution syntax

**Example Valid Configuration:**
```json
{
  "mcpServers": {
    "filesystem": {
      "type": "local",
      "command": ["npx", "@modelcontextprotocol/server-filesystem", "/tmp"]
    }
  }
}
```

**Example Invalid Configuration:**
```json
{
  "mcpServers": {
    "filesystem": {
      "type": "local"
      // Missing command - will fail validation
    }
  }
}
```

**Error Message:**
```
server filesystem: command is required for stdio transport
```

#### 2. Remote Servers (sse/streamable transport)

**Required Fields:**
- `url` field

**Validation Rules:**
- URL must be provided and non-empty
- Headers array is optional but validated if provided
- URL format is not strictly validated by MCPHost (relies on transport layer)

**Example Valid Configuration:**
```json
{
  "mcpServers": {
    "websearch": {
      "type": "remote",
      "url": "https://api.example.com/mcp",
      "headers": ["Authorization: Bearer ${env://TOKEN}"]
    }
  }
}
```

**Example Invalid Configuration:**
```json
{
  "mcpServers": {
    "websearch": {
      "type": "remote"
      // Missing url - will fail validation
    }
  }
}
```

**Error Message:**
```
server websearch: url is required for streamable transport
```

#### 3. Builtin Servers (inprocess transport)

**Required Fields:**
- `name` field

**Validation Rules:**
- Name must be provided and non-empty
- Name must be a valid builtin server: `fs`, `bash`, `todo`, `http`, or `fetch`
- Options are validated per server type (if provided)

**Example Valid Configuration:**
```json
{
  "mcpServers": {
    "filesystem": {
      "type": "builtin",
      "name": "fs",
      "options": {
        "allowed_directories": ["/tmp", "/home/user/docs"]
      }
    }
  }
}
```

**Example Invalid Configuration:**
```json
{
  "mcpServers": {
    "filesystem": {
      "type": "builtin"
      // Missing name - will fail validation
    }
  }
}
```

**Error Message:**
```
server filesystem: name is required for builtin servers
```

#### 4. Tool Filtering Validation

**Rule:**
- `allowedTools` and `excludedTools` are **mutually exclusive**
- Both cannot be specified for the same server

**Example Invalid Configuration:**
```json
{
  "mcpServers": {
    "filesystem": {
      "type": "builtin",
      "name": "fs",
      "allowedTools": ["read_file", "write_file"],
      "excludedTools": ["delete_file"]
      // Both specified - will fail validation
    }
  }
}
```

**Error Message:**
```
server filesystem: allowedTools and excludedTools are mutually exclusive
```

**Valid Alternatives:**
```json
// Option 1: Use allowedTools (whitelist)
{
  "allowedTools": ["read_file", "write_file"]
}

// Option 2: Use excludedTools (blacklist)
{
  "excludedTools": ["delete_file"]
}
```

#### 5. Transport Type Validation

**Supported Transport Types:**
- `stdio` - Local process communication via stdin/stdout
- `sse` - Server-Sent Events (legacy)
- `streamable` - Streamable HTTP protocol
- `inprocess` - Builtin servers running in-process

**Validation:**
- Invalid transport types are rejected
- Transport type is inferred from server configuration if not explicitly set

**Example Invalid Configuration:**
```json
{
  "mcpServers": {
    "custom": {
      "type": "invalid_transport"
      // Invalid transport type - will fail validation
    }
  }
}
```

**Error Message:**
```
server custom: unsupported transport type 'invalid_transport'. Supported types: stdio, sse, streamable, inprocess
```

## Environment Variable Validation

MCPHost supports environment variable substitution in configuration files using the syntax:
- `${env://VAR}` - Required environment variable (fails if not set)
- `${env://VAR:-default}` - Optional environment variable with default value

### Validation Rules

1. **Required Variables:**
   - Variables without defaults (${env://VAR}) must be set in the environment
   - Missing required variables cause validation to fail

2. **Optional Variables:**
   - Variables with defaults (${env://VAR:-default}) use the default if not set
   - Empty defaults are allowed: `${env://VAR:-}`

3. **Syntax Validation:**
   - Invalid substitution syntax is caught during parsing
   - Pattern: `${env://[A-Za-z_][A-Za-z0-9_]*([:-][^}]*)?}`

**Example Valid Configuration:**
```json
{
  "mcpServers": {
    "github": {
      "type": "local",
      "command": ["gh", "api"],
      "environment": {
        "GITHUB_TOKEN": "${env://GITHUB_TOKEN}",
        "DEBUG": "${env://DEBUG:-false}",
        "LOG_LEVEL": "${env://LOG_LEVEL:-info}"
      }
    }
  }
}
```

**Example Invalid Configuration:**
```json
{
  "mcpServers": {
    "github": {
      "type": "local",
      "command": ["gh", "api"],
      "environment": {
        "GITHUB_TOKEN": "${env://GITHUB_TOKEN}"
        // If GITHUB_TOKEN is not set, validation fails
      }
    }
  }
}
```

**Error Message:**
```
environment variable substitution failed: required environment variable GITHUB_TOKEN not set in ${env://GITHUB_TOKEN}
```

### Environment Variable Case Sensitivity

MCPHost handles environment variable case sensitivity issues that can occur with Viper configuration loading. The configuration system automatically fixes case issues for environment variables in server configurations.

## Hook Configuration Validation

Hooks allow executing custom commands at specific points during MCPHost execution. Hook configurations are validated by `hooks.ValidateHookConfig()`.

### Validation Rules

#### 1. Event Type Validation

**Valid Event Types:**
- `PreToolUse` - Before any tool execution
- `PostToolUse` - After tool execution completes
- `UserPromptSubmit` - When user submits a prompt
- `Stop` - When the agent finishes responding
- `SubagentStop` - When a subagent (Task tool) finishes
- `Notification` - When MCPHost sends notifications

**Error Message for Invalid Event:**
```
invalid event: InvalidEventName
```

#### 2. Regex Pattern Validation

If a matcher includes a regex pattern, it must be valid and compilable.

**Example Valid Configuration:**
```yaml
hooks:
  PreToolUse:
    - matcher: "bash"
      hooks:
        - type: command
          command: "/usr/local/bin/validate-bash.py"
```

**Example Invalid Configuration:**
```yaml
hooks:
  PreToolUse:
    - matcher: "[invalid(regex"
      hooks:
        - type: command
          command: "/usr/local/bin/validate.sh"
```

**Error Message:**
```
invalid regex pattern in matcher 0 for event PreToolUse: error parsing regexp: missing closing ): `[invalid(regex`
```

#### 3. Hook Entry Validation

**Required Fields:**
- `type` - Must be "command" (only supported type)
- `command` - Must be non-empty

**Validation Rules:**
- Hook type must be "command"
- Command cannot be empty
- Timeout must be between 0 and 600 seconds (10 minutes max)
- Timeout cannot be negative

**Example Invalid Configuration:**
```yaml
hooks:
  PreToolUse:
    - hooks:
        - type: invalid_type
          command: "/usr/bin/echo"
```

**Error Message:**
```
invalid hook type: invalid_type (only 'command' is supported)
```

**Example Invalid Timeout:**
```yaml
hooks:
  PreToolUse:
    - hooks:
        - type: command
          command: "/usr/bin/echo"
          timeout: 700  # Exceeds 600 second limit
```

**Error Message:**
```
timeout too large: 700 (max 600 seconds)
```

#### 4. Security Validation

Hook commands are validated for security issues:

**Detected Security Issues:**
- Command injection attempts (multiple separators: `;`, `&&`, `||`, `|`)
- Path traversal (`../`)
- Command substitution (`$(...)` or backticks)
- Dangerous patterns (`rm`, `dd`, `/dev/null 2>&1`)

**Example Invalid Configuration:**
```yaml
hooks:
  PreToolUse:
    - hooks:
        - type: command
          command: "echo test; rm -rf /"
```

**Error Message:**
```
command validation failed: potential command injection detected
```

**Example Invalid Path Traversal:**
```yaml
hooks:
  PreToolUse:
    - hooks:
        - type: command
          command: "cat ../../etc/passwd"
```

**Error Message:**
```
command validation failed: path traversal detected
```

#### 5. Matcher Validation

Each matcher must have at least one hook defined.

**Example Invalid Configuration:**
```yaml
hooks:
  PreToolUse:
    - matcher: "bash"
      hooks: []  # Empty hooks array
```

**Error Message:**
```
no hooks defined for matcher 0 in event PreToolUse
```

## Debug and Troubleshooting

### Enable Debug Mode

Debug mode provides detailed logging and configuration information to help troubleshoot issues.

#### Command Line

```bash
mcphost --debug
```

#### Configuration File

```yaml
debug: true
```

#### What Debug Mode Shows

When debug mode is enabled, MCPHost displays:

1. **Detailed Logging:**
   - Log messages include file locations (`log.LstdFlags | log.Lshortfile`)
   - Format: `YYYY/MM/DD HH:MM:SS filename.go:line: message`

2. **Debug Configuration Display:**
   - Model configuration (model, max-steps, max-tokens, temperature, top-p, top-k)
   - Provider settings (provider-url, provider-api-key status as `[SET]`)
   - System prompt location
   - TLS skip verify status
   - Ollama-specific parameters (num-gpu-layers, main-gpu) if using Ollama
   - Stop sequences (if configured)
   - MCP server status (loaded/failed) with masked sensitive data

### Debug Message Types

Debug messages are prefixed with tags to indicate their source:

#### [DEBUG] - General Debug Information

Shows general debugging information about MCP server connections:

```
[DEBUG] Connecting to MCP server: filesystem
[DEBUG] Transport type: stdio
[DEBUG] Command: npx [@modelcontextprotocol/server-filesystem /tmp]
[DEBUG] Environment variables: 2
```

#### [POOL] - Connection Pool Operations

Shows connection pool lifecycle events:

```
[POOL] Creating new connection for filesystem
[POOL] Reusing connection for filesystem
[POOL] Connection filesystem unhealthy, removing
```

#### [HEALTH_CHECK] - Connection Health Check Results

Shows results of periodic health checks:

```
[HEALTH_CHECK] Connection filesystem marked as unhealthy due to inactivity
[HEALTH_CHECK] Connection filesystem marked as unhealthy due to errors
[HEALTH_CHECK] Connection filesystem failed health check: connection timeout
```

### Connection Pool Debugging

The connection pool manages MCP server connections and provides detailed debugging information.

#### Connection Lifecycle

**Connection Creation:**
```
[POOL] Creating new connection for filesystem
[POOL] Created connection for filesystem
```

**Connection Reuse:**
```
[POOL] Reusing connection for filesystem
```

**Connection Removal:**
```
[POOL] Connection filesystem unhealthy, removing
```

#### Health Check Monitoring

Health checks run periodically and log:
- Connections marked unhealthy due to inactivity (exceeds MaxIdleTime)
- Connections marked unhealthy due to errors (exceeds MaxErrorCount)
- Failed health check attempts

**Example Debug Output:**
```
[HEALTH_CHECK] Connection filesystem marked as unhealthy due to inactivity
[HEALTH_CHECK] Connection github marked as unhealthy due to errors
```

#### Error Tracking

Connection errors are tracked and logged:
- Error count increments for each error
- Last error message is stored
- Connection marked unhealthy after threshold

**404 Error Handling:**
```
[POOL] 404 error for websearch, will recreate on next request
```

### MCP Server Connection Debugging

When connecting to MCP servers, debug mode shows:

#### Local Servers (stdio)
```
[DEBUG] Connecting to MCP server: filesystem
[DEBUG] Transport type: stdio
[DEBUG] Command: npx [@modelcontextprotocol/server-filesystem /tmp]
[DEBUG] Environment variables: 2
```

#### Remote Servers (sse/streamable)
```
[DEBUG] Connecting to MCP server: websearch
[DEBUG] Transport type: streamable
[DEBUG] URL: https://api.example.com/mcp
[DEBUG] Headers: [Authorization: Bearer ***]
```

### Connection Statistics

Connection statistics can be accessed programmatically via `GetConnectionStats()`. The statistics include:

- `is_healthy` - Boolean indicating connection health
- `last_used` - Timestamp of last usage
- `error_count` - Number of errors encountered
- `last_error` - Last error message (if any)
- `server_name` - Name of the MCP server

**Example Statistics:**
```json
{
  "filesystem": {
    "is_healthy": true,
    "last_used": "2024-01-15T10:30:00Z",
    "error_count": 0,
    "last_error": null,
    "server_name": "filesystem"
  },
  "github": {
    "is_healthy": false,
    "last_used": "2024-01-15T09:00:00Z",
    "error_count": 5,
    "last_error": "connection timeout",
    "server_name": "github"
  }
}
```

### Troubleshooting Deployment

#### Step 1: Enable Debug Mode

```bash
mcphost --debug
```

Or in config file:
```yaml
debug: true
```

#### Step 2: Check Debug Configuration Display

At startup, debug mode displays the full configuration. Verify:
- MCP server status (should show "loaded" not "failed")
- Model configuration is correct
- Environment variables are properly substituted
- Provider settings are correct

#### Step 3: Monitor Connection Pool

Watch for connection pool messages:
- `[POOL] Creating new connection` - Normal on first use
- `[POOL] Reusing connection` - Good, connection is healthy
- `[POOL] Connection unhealthy, removing` - Problem detected

#### Step 4: Review Error Counts

Check connection statistics for:
- High error counts
- Recent errors in `last_error`
- Connections marked as unhealthy

#### Step 5: Validate Environment Variables

Ensure required environment variables are set:
```bash
# Check if required variables are set
echo $GITHUB_TOKEN
echo $OPENAI_API_KEY

# Test substitution
mcphost --debug -p "test" 2>&1 | grep "environment variable"
```

#### Step 6: Check Transport Type Compatibility

Verify the transport type matches the server configuration:
- Local servers → `stdio` transport
- Remote servers → `streamable` or `sse` transport
- Builtin servers → `inprocess` transport

#### Step 7: Review MCP Server Logs

For local servers, check the server's own logs:
```bash
# If using npx, check npm logs
npm config get cache

# If using docker, check container logs
docker logs <container-id>
```

#### Common Issues and Solutions

**Issue: "server X: command is required for stdio transport"**
- **Solution:** Ensure `command` array is provided for local servers

**Issue: "server X: url is required for streamable transport"**
- **Solution:** Provide `url` field for remote servers

**Issue: "server X: name is required for builtin servers"**
- **Solution:** Provide `name` field (fs, bash, todo, http, or fetch)

**Issue: "allowedTools and excludedTools are mutually exclusive"**
- **Solution:** Use only one tool filtering method per server

**Issue: "environment variable substitution failed"**
- **Solution:** Set required environment variables or provide defaults

**Issue: Connection pool shows "unhealthy" connections**
- **Solution:** Check server accessibility, network connectivity, and error messages

**Issue: "invalid regex pattern" in hooks**
- **Solution:** Fix regex syntax or remove invalid patterns

**Issue: "command validation failed" in hooks**
- **Solution:** Remove dangerous patterns from hook commands

## Common Configuration Errors

### Missing Required Fields

**Error:** `server X: command is required for stdio transport`
- **Cause:** Local server missing `command` field
- **Fix:** Add `command` array to server configuration

**Error:** `server X: url is required for streamable transport`
- **Cause:** Remote server missing `url` field
- **Fix:** Add `url` field to server configuration

**Error:** `server X: name is required for builtin servers`
- **Cause:** Builtin server missing `name` field
- **Fix:** Add `name` field (must be: fs, bash, todo, http, or fetch)

### Tool Filtering Errors

**Error:** `server X: allowedTools and excludedTools are mutually exclusive`
- **Cause:** Both tool filtering methods specified
- **Fix:** Use only `allowedTools` OR `excludedTools`, not both

### Environment Variable Errors

**Error:** `environment variable substitution failed: required environment variable VAR not set`
- **Cause:** Required environment variable not set
- **Fix:** Set the environment variable or use default syntax: `${env://VAR:-default}`

### Transport Type Errors

**Error:** `server X: unsupported transport type 'X'`
- **Cause:** Invalid transport type specified
- **Fix:** Use one of: stdio, sse, streamable, inprocess

### Hook Configuration Errors

**Error:** `invalid event: X`
- **Cause:** Invalid event type in hooks configuration
- **Fix:** Use valid event types: PreToolUse, PostToolUse, UserPromptSubmit, Stop, SubagentStop, Notification

**Error:** `invalid regex pattern`
- **Cause:** Invalid regex syntax in matcher
- **Fix:** Fix regex pattern or remove matcher

**Error:** `timeout too large: X (max 600 seconds)`
- **Cause:** Timeout exceeds 600 second limit
- **Fix:** Reduce timeout to 600 seconds or less

**Error:** `command validation failed: potential command injection detected`
- **Cause:** Hook command contains dangerous patterns
- **Fix:** Remove command injection patterns from hook commands

## Validation Functions

### Using `config.Validate()`

```go
config := &config.Config{
    MCPServers: map[string]config.MCPServerConfig{
        // ... server configs
    },
}

if err := config.Validate(); err != nil {
    log.Fatalf("Configuration validation failed: %v", err)
}
```

### Using `config.LoadAndValidateConfig()`

This function loads configuration from Viper, fixes environment variable case issues, and validates:

```go
mcpConfig, err := config.LoadAndValidateConfig()
if err != nil {
    return fmt.Errorf("failed to load MCP config: %v", err)
}
```

### Using `hooks.ValidateHookConfig()`

```go
hookConfig := &hooks.HookConfig{
    Hooks: map[hooks.HookEvent][]hooks.Matcher{
        // ... hook configuration
    },
}

if err := hooks.ValidateHookConfig(hookConfig); err != nil {
    log.Fatalf("Hook configuration validation failed: %v", err)
}
```

## Best Practices

1. **Always validate configuration before deployment**
   - Use `--debug` flag to see configuration at startup
   - Check for validation errors in logs

2. **Use environment variable defaults**
   - Prefer `${env://VAR:-default}` for optional variables
   - Only use `${env://VAR}` for truly required variables

3. **Monitor connection pool health**
   - Watch for `[HEALTH_CHECK]` messages in debug output
   - Review connection statistics regularly

4. **Test hook configurations**
   - Validate regex patterns before deployment
   - Test hook commands in safe environment first

5. **Check MCP server status**
   - Verify servers show "loaded" status in debug config
   - Investigate "failed" server status immediately

6. **Use tool filtering carefully**
   - Prefer `allowedTools` for security (whitelist)
   - Use `excludedTools` only when necessary (blacklist)

