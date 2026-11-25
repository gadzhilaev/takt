# Takt MCP

Takt exposes a remote Streamable HTTP MCP endpoint at `/mcp`. Requests are
authorized as the connected Takt user and every tool reuses existing project
membership and role checks.

## Tools

- `list_projects` — list projects the current user belongs to.
- `get_project_board` — read a project, columns, and active tasks.
- `list_tasks` / `get_task` — search or read tasks.
- `create_task`, `update_task`, `move_task` — create and modify tasks.
- `list_task_comments` / `add_task_comment` — read and add comments.
- `add_checklist_item` / `update_checklist_item` — maintain task checklists.
- `delete_task` — soft-delete a task authored by the current user.

## ChatGPT

After the OAuth-enabled server version is deployed, add it in ChatGPT web:

1. Open **Settings → Apps/Plugins** and choose **Add → Add custom MCP server**.
2. Enter name `Takt`, optional description `Проекты и задачи Takt`, and URL
   `https://taktapp.ru/mcp`.
3. Choose **OAuth**. Leave advanced OAuth settings on automatic discovery.
4. Review the risk notice and create the plugin. ChatGPT will open the Takt
   sign-in and consent page when it scans or first calls a tool.
5. Sign into Takt and review the permissions. Allowing grants this ChatGPT app
   access to the projects available to your Takt account and task/comment/checklist
   operations. You can deny or revoke the connection from ChatGPT.

The server implements OAuth 2.1 authorization code with PKCE S256, dynamic
client registration, protected-resource and authorization-server metadata,
short-lived access tokens, and rotating refresh tokens. Takt passwords are never
sent to ChatGPT. A database migration creates OAuth client, authorization-code,
and refresh-grant storage.

The MCP initialize response advertises the Takt website and app icon. After
updating the server, refresh the Takt app connection in ChatGPT settings so its
card picks up the latest metadata. The HTTP transport keeps DNS-rebinding
protection enabled and allows the public `taktapp.ru` host used by the reverse
proxy.

## Cursor and Claude Code

Use the deployment's HTTPS endpoint and a Takt access token as Bearer
credential. Do not put the token in a repository or share it in chat. Access
tokens expire; renew through the normal Takt login flow.

Example Cursor remote MCP entry:

```json
{
  "mcpServers": {
    "takt": {
      "url": "https://taktapp.ru/mcp",
      "headers": {
        "Authorization": "Bearer <Takt access token>"
      }
    }
  }
}
```

For Claude Code, use the same endpoint and header with its remote Streamable HTTP
MCP configuration.

## Local development

Run the API and point the client at `http://localhost:8000/mcp`. Use a
development access token from the local Takt login flow. OAuth metadata uses
`APP_PUBLIC_URL`; set it to the public API origin in deployed environments.
