# pi MCP bridge (+ TalkToFigma)

Bridges Claude/Cursor-compatible MCP servers into pi tools.

## Config

`~/.pi/agent/mcp.json`:

```json
{
  "mcpServers": {
    "TalkToFigma": {
      "command": "bunx",
      "args": ["cursor-talk-to-figma-mcp@latest"]
    }
  }
}
```

## TalkToFigma runtime

Three parts must be up:

1. **MCP server** — started automatically by this extension on `session_start`
2. **WebSocket relay on :3055** — auto-started if free (`bunx cursor-talk-to-figma-socket@latest`), or run manually:
   ```bash
   bunx cursor-talk-to-figma-socket@latest
   # or from the local clone:
   cd ~/tools/cursor-talk-to-figma-mcp && bun socket
   ```
3. **Figma plugin** — install from [community](https://www.figma.com/community/plugin/1485687494525374295/cursor-talk-to-figma-mcp-plugin) or link local `~/tools/cursor-talk-to-figma-mcp/src/cursor_mcp_plugin/manifest.json`

In Figma: run the plugin → join a channel (e.g. `mempriv`)  
In pi: call `TalkToFigma_join_channel` with the same channel, then use the other tools.

## Commands

| Command | Action |
|---------|--------|
| `/mcp` | List connected servers and tools |
| `/mcp-reconnect` | Reload config and reconnect |
| `/figma-socket` | Ensure websocket relay on :3055 |

## Tool names

`{ServerName}_{tool}` — e.g. `TalkToFigma_get_document_info`, `TalkToFigma_join_channel`.
