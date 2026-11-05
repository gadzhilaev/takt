import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_task_activity_created_and_moved(admin_client: AsyncClient):
    project = await admin_client.post(
        "/api/v1/projects",
        json={
            "name": "History Proj",
            "description": None,
            "color": "#315F72",
            "icon": "folder",
            "member_ids": [],
        },
    )
    assert project.status_code == 200, project.text
    pid = project.json()["project"]["id"]
    statuses_resp = await admin_client.get(f"/api/v1/settings/statuses?project_id={pid}")
    statuses = statuses_resp.json()["items"]
    assert len(statuses) >= 2
    todo = statuses[0]
    doing = statuses[1]
    me = (await admin_client.get("/api/v1/auth/me")).json()["user"]

    created = await admin_client.post(
        "/api/v1/tasks",
        json={
            "title": "История",
            "status_id": todo["id"],
            "project_id": pid,
            "assignee_ids": [me["id"]],
            "priority": "medium",
        },
    )
    assert created.status_code == 200, created.text
    task_id = created.json()["task"]["id"]

    moved = await admin_client.post(
        f"/api/v1/tasks/{task_id}/move",
        json={"status_id": doing["id"], "position": 0},
    )
    assert moved.status_code == 200, moved.text

    activity = await admin_client.get(f"/api/v1/tasks/{task_id}/activity")
    assert activity.status_code == 200, activity.text
    items = activity.json()["items"]
    assert len(items) >= 2
    assert items[0]["action"] == "moved"
    assert items[0]["old_label"] == todo["name"]
    assert items[0]["new_label"] == doing["name"]
    assert "перенёс" in items[0]["summary"]
    assert items[0]["user"]["id"] == me["id"]
    assert any(i["action"] == "created" and "создал" in i["summary"] for i in items)
