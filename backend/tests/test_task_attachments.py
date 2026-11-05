import io

import pytest
from httpx import AsyncClient
from PIL import Image


def _png_bytes(color=(49, 95, 114)) -> bytes:
    img = Image.new("RGB", (64, 48), color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


@pytest.mark.asyncio
async def test_upload_image_attachment_with_webp_preview(admin_client: AsyncClient):
    project = await admin_client.post(
        "/api/v1/projects",
        json={
            "name": "Attach Proj",
            "description": None,
            "color": "#315F72",
            "icon": "folder",
            "member_ids": [],
        },
    )
    assert project.status_code == 200, project.text
    pid = project.json()["project"]["id"]
    statuses = await admin_client.get(f"/api/v1/settings/statuses?project_id={pid}")
    assert statuses.status_code == 200
    status_id = statuses.json()["items"][0]["id"]
    me = await admin_client.get("/api/v1/auth/me")
    uid = me.json()["user"]["id"]

    created = await admin_client.post(
        "/api/v1/tasks",
        json={
            "title": "With file",
            "status_id": status_id,
            "project_id": pid,
            "assignee_ids": [uid],
            "priority": "medium",
        },
    )
    assert created.status_code == 200, created.text
    task_id = created.json()["task"]["id"]

    data = _png_bytes()
    uploaded = await admin_client.post(
        f"/api/v1/tasks/{task_id}/attachments",
        files={"file": ("фото отчёт.png", data, "image/png")},
    )
    assert uploaded.status_code == 200, uploaded.text
    body = uploaded.json()
    att = body["attachment"]
    assert att["filename"] == "фото отчёт.png"
    assert att["is_image"] is True
    assert att["preview_url"]
    assert any(a["id"] == att["id"] for a in body["task"]["attachments"])

    preview = await admin_client.get(att["preview_url"])
    assert preview.status_code == 200
    assert preview.headers["content-type"].startswith("image/webp")
    assert len(preview.content) > 0

    original = await admin_client.get(att["url"])
    assert original.status_code == 200
    assert original.content == data

    deleted = await admin_client.delete(f"/api/v1/tasks/{task_id}/attachments/{att['id']}")
    assert deleted.status_code == 200, deleted.text
    assert deleted.json()["task"]["attachments"] == []
