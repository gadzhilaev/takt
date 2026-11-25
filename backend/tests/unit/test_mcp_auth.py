from app.mcp_server import TaktMCPAuth


async def test_mcp_rejects_requests_without_a_takt_access_token():
    async def downstream(scope, receive, send):
        raise AssertionError("Unauthenticated request reached MCP")

    messages = []

    async def receive():
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message):
        messages.append(message)

    app = TaktMCPAuth(downstream)
    await app(
        {"type": "http", "method": "POST", "headers": []},
        receive,
        send,
    )

    assert messages[0]["status"] == 401
    challenge = dict(messages[0]["headers"])[b"www-authenticate"].decode()
    assert challenge.startswith('Bearer realm="Takt MCP"')
    assert "resource_metadata=" in challenge
