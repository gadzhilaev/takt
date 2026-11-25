"""Фоновый цикл сроков: проход реально повышает срочность (ловит разрыв цикл ↔ функция)."""

import asyncio
import logging
from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from sqlalchemy import select

from app.core.config import get_settings
from app.db.session import AsyncSessionLocal, engine
from app.models.project import Project
from app.models.task import Task, TaskPriority
from app.models.team import TaskStatus
from app.models.user import User
from app.services.due_reminder_service import due_reminder_loop, run_due_pass


@pytest_asyncio.fixture(autouse=True)
async def _fresh_app_pool():
    # Пул приложения не должен переносить соединения между event loop разных тестов.
    await engine.dispose()
    yield
    await engine.dispose()


async def _task_close_to_deadline() -> str:
    """Задача со сроком через час при окне в 10 дней → должна стать urgent."""
    now = datetime.now(UTC)
    async with AsyncSessionLocal() as db:
        admin = await db.scalar(select(User).where(User.email == "admin@test.com"))
        project = Project(name="Цикл сроков", auto_urgency_from_due=True)
        db.add(project)
        await db.flush()
        status = TaskStatus(
            project_id=project.id,
            name="К выполнению",
            color="#607FA4",
            position=0.0,
            is_done=False,
        )
        db.add(status)
        await db.flush()
        task = Task(
            project_id=project.id,
            title="Сдать отчёт",
            status_id=status.id,
            priority=TaskPriority.low,
            author_id=admin.id,
            position=0.0,
            due_date=now + timedelta(hours=1),
            due_basis_at=now - timedelta(days=10),
        )
        db.add(task)
        await db.commit()
        return str(task.id)


async def _priority(task_id: str) -> TaskPriority:
    async with AsyncSessionLocal() as db:
        return (await db.get(Task, task_id)).priority


@pytest.mark.asyncio
async def test_run_due_pass_escalates_priority(caplog):
    task_id = await _task_close_to_deadline()
    with caplog.at_level(logging.INFO, logger="app.services.due_reminder_service"):
        result = await run_due_pass(get_settings())
    assert result["urgency_bumped"] >= 1
    assert await _priority(task_id) == TaskPriority.urgent
    assert "auto urgency pass failed" not in caplog.text
    assert "due pass ok" in caplog.text


@pytest.mark.asyncio
async def test_loop_iteration_escalates_priority(monkeypatch):
    """Сам due_reminder_loop: одна итерация доходит до автосрочности без исключений."""
    task_id = await _task_close_to_deadline()
    settings = get_settings()
    monkeypatch.setattr(settings, "DUE_REMINDER_ENABLED", True)
    monkeypatch.setattr(settings, "DUE_REMINDER_INTERVAL_SECONDS", 30)

    stop = asyncio.Event()
    loop_task = asyncio.create_task(due_reminder_loop(stop))
    for _ in range(100):
        if await _priority(task_id) == TaskPriority.urgent:
            break
        await asyncio.sleep(0.05)
    stop.set()
    await asyncio.wait_for(loop_task, timeout=5)
    assert await _priority(task_id) == TaskPriority.urgent
