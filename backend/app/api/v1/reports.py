import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.task import Task, TaskAssignee
from app.models.team import TeamSettings
from app.models.user import User
from app.services.excel_export import build_report_workbook
from app.services.report_service import (
    by_employee,
    closed_by_day,
    history_for_export,
    period_range,
    recent_completed,
    report_metrics,
)
from app.services import task_service

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("")
async def report(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    preset: str = "month",
    start: datetime | None = None,
    end: datetime | None = None,
    user_ids: str | None = None,
):
    p_start, p_end = period_range(preset, start, end)
    uids = [uuid.UUID(x) for x in user_ids.split(",")] if user_ids else None
    metrics = await report_metrics(db, p_start, p_end, uids)
    chart = await closed_by_day(db, p_start, p_end)
    employees = await by_employee(db, p_start, p_end)
    recent = await recent_completed(db)
    return {
        "period": {"start": p_start, "end": p_end, "preset": preset},
        "metrics": metrics,
        "closed_by_day": chart,
        "by_employee": employees,
        "recent_completed": recent,
    }


@router.get("/export")
async def export_excel(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    preset: str = "month",
    start: datetime | None = None,
    end: datetime | None = None,
):
    p_start, p_end = period_range(preset, start, end)
    team = await db.get(TeamSettings, 1)
    team_name = team.team_name if team else "Команда"
    metrics = await report_metrics(db, p_start, p_end)
    tasks, _ = await task_service.list_tasks(db, page_size=10000)
    now = datetime.now(p_start.tzinfo)
    task_rows = []
    for t in tasks:
        assignees = ", ".join(a.user.name for a in t.assignees if a.user)
        labels = ", ".join(tl.label.name for tl in t.labels if tl.label)
        overdue = bool(t.due_date and t.due_date < now and not t.closed_at)
        task_rows.append(
            {
                "id": str(t.id),
                "title": t.title,
                "status": t.status.name if t.status else "",
                "priority": t.priority.value,
                "assignees": assignees,
                "author": t.author.name if t.author else "",
                "created_at": t.created_at,
                "due_date": t.due_date,
                "closed_at": t.closed_at,
                "labels": labels,
                "overdue": overdue,
            }
        )
    employees = await by_employee(db, p_start, p_end)
    history = await history_for_export(db, p_start, p_end)
    period_label = f"{p_start.date()} — {p_end.date()}"
    data = build_report_workbook(team_name, period_label, metrics, task_rows, employees, history)
    filename = f"Отчёт_{team_name}_{datetime.now().strftime('%Y-%m-%d')}.xlsx"
    return Response(
        content=data,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
