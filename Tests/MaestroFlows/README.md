# Maestro UI Test Flows

This directory is a placeholder for [Maestro](https://maestro.mobile.dev) YAML test flows.

## Setup

1. Install the Maestro CLI:
   ```
   curl -Ls "https://get.maestro.mobile.dev" | bash
   ```

2. Verify installation:
   ```
   maestro --version
   ```

## Running flows

```bash
# Run a single flow
maestro test Tests/MaestroFlows/login_flow.yaml

# Run all flows in this directory
maestro test Tests/MaestroFlows/
```

## Example flow structure

```yaml
# login_flow.yaml
appId: com.personal.s3gallery
---
- launchApp
- tapOn:
    id: "accessKeyIdField"
- inputText: "AKIATESTKEY"
- tapOn:
    id: "connectButton"
- assertVisible: "S3 Gallery"
```

## MCP integration

Maestro flows can be triggered from Claude Code via an MCP server. Add the Maestro MCP server to your Claude Code configuration to enable AI-driven test execution.
