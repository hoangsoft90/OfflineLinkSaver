# Simplenote MCP Skill

> Use this skill when the user asks to read, create, update, search, or delete Simplenote notes.

## Quick Reference

| What | Command |
|------|---------|
| **MCP config** | `~/mcp.json` |
| **Auth** | `~/.config/simplenote-mcp/auth.json` |
| **User** | `kd.hoangweb@gmail.com` |
| **Package** | `@automattic/simplenote-mcp` v2.0.1 |

## How to Call Simplenote MCP

The Simplenote MCP server communicates via **stdio JSON-RPC**. Here's the exact pattern:

### Step 1: Send initialize

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"buffy","version":"1.0"}}}' | timeout 5 npx -y @automattic/simplenote-mcp
```

### Step 2: Full workflow (initialize → call tool → result)

```bash
# Pipe all messages via heredoc or printf
(
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"buffy","version":"1.0"}}}'
sleep 1
echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
sleep 0.5
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_notes","arguments":{"limit":10}}}'
sleep 4
) | timeout 12 npx -y @automattic/simplenote-mcp 2>/dev/null
```

**IMPORTANT**: The `sleep` delays are critical — the MCP server needs time to process each message. Use `sleep 1` after init, `sleep 0.5` after initialized notification, and `sleep 3-5` after tool calls.

## Available Tools

| Tool | Read/Write | Arguments |
|------|-----------|-----------|
| `list_notes` | R | `{tag?, limit?, include_deleted?}` |
| `search_notes` | R | `{query, limit?, include_deleted?}` |
| `get_note` | R | `{id, include_deleted?}` |
| `create_note` | W | `{content, tags?, markdown?, pinned?}` |
| `update_note` | W | `{id, content?, tags?, markdown?, pinned?}` |
| `trash_note` | W | `{id}` |
| `restore_note` | W | `{id}` |
| `list_tags` | R | `{}` |
| `get_note_history` | R | `{id, limit?}` |
| `get_note_version` | R | `{id, version}` |
| `revert_note` | W | `{id, version}` |

## Examples

### List notes

```bash
(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"buffy","version":"1.0"}}}'; sleep 1; echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'; sleep 0.5; echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_notes","arguments":{"limit":20}}}'; sleep 4) | timeout 12 npx -y @automattic/simplenote-mcp 2>/dev/null
```

### Create a note

```bash
(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"buffy","version":"1.0"}}}'; sleep 1; echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'; sleep 0.5; echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_note","arguments":{"content":"My note title\n\nBody content here...","tags":["project","todo"],"markdown":true}}}'; sleep 5) | timeout 15 npx -y @automattic/simplenote-mcp 2>/dev/null
```

### Search notes

```bash
(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"buffy","version":"1.0"}}}'; sleep 1; echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'; sleep 0.5; echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"search_notes","arguments":{"query":"search term","limit":5}}}'; sleep 4) | timeout 12 npx -y @automattic/simplenote-mcp 2>/dev/null
```

### Update a note (FULL content replacement!)

```bash
# IMPORTANT: Get note first, then modify content, then update
# content field REPLACES the entire note
(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"buffy","version":"1.0"}}}'; sleep 1; echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'; sleep 0.5; echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"update_note","arguments":{"id":"NOTE_ID_HERE","content":"Updated full content"}}}'; sleep 4) | timeout 12 npx -y @automattic/simplenote-mcp 2>/dev/null
```

## Parsing Response

The response is JSON-RPC. To extract the result:

```bash
# Pipe through python3 to parse
| python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        if d.get('id') == 2:  # tool call response
            content = d.get('result',{}).get('content',[])
            for c in content:
                if c.get('type') == 'text':
                    print(c['text'])
    except: pass
"
```

## Gotchas

1. **`content` replaces entire note** — always `get_note` first, modify, then `update_note`
2. **Tags replace entire list** — provide full tag list on update
3. **`sleep` delays are required** — skip them and messages get lost
4. **Write operations need `writeMode: true`** in `~/.config/simplenote-mcp/config.json`
5. **Token can expire** — if list_notes returns empty but account has notes, re-run `npx @automattic/simplenote-mcp setup`
