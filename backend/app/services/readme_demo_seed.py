"""Idempotent seed: product-style demo board for README screenshots.

Fictional team + project «Запуск продукта». Safe to re-run.
Does not use real employee names. Marks users/project as is_demo.
"""

from __future__ import annotations

import secrets
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.security import hash_password
from app.models.notification import Notification
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.task import Task, TaskAssignee, TaskPriority
from app.models.team import TaskStatus
from app.models.user import User, UserRole
from app.services.notify_service import create_in_app
from app.services.project_service import DEFAULT_STATUS_TEMPLATE
from app.services.ru_names import format_assignment_line

PROJECT_NAME = "Запуск продукта"
PROJECT_DESC = (
    "Демонстрационная доска продуктовой команды для скриншотов README. "
    "Данные условные. [readme-demo]"
)
PROJECT_COLOR = "#315F72"

# (key, display name, email)
README_STAFF: list[tuple[str, str, str]] = [
    ("alina", "Алина Смирнова", "demo.alina@example.com"),
    ("petr", "Пётр Орлов", "demo.petr@example.com"),
    ("maria", "Мария Волкова", "demo.maria@example.com"),
    ("igor", "Игорь Лебедев", "demo.igor@example.com"),
    ("nina", "Нина Соколова", "demo.nina@example.com"),
]

# title, description, priority, column 0..3, staff keys
README_TASKS: list[tuple[str, str, TaskPriority, int, tuple[str, ...]]] = [
    (
        "Собрать сценарии онбординга",
        "Пройти регистрацию и первый проект глазами нового пользователя.",
        TaskPriority.high,
        0,
        ("alina", "maria"),
    ),
    (
        "Подготовить тексты для лендинга",
        "Заголовок, подзаголовок и три блока возможностей без жаргона.",
        TaskPriority.medium,
        0,
        ("nina",),
    ),
    (
        "Согласовать палитру статусов",
        "Четыре стартовых столбца и цвета под бренд Takt.",
        TaskPriority.medium,
        0,
        ("igor", "alina"),
    ),
    (
        "Проверить приглашения по ссылке",
        "Открыть /invite/{token} без аккаунта и после регистрации.",
        TaskPriority.urgent,
        0,
        ("petr",),
    ),
    (
        "Доработать карточки задач",
        "Приоритет, исполнители и время в столбце на одной карточке.",
        TaskPriority.high,
        1,
        ("alina", "igor"),
    ),
    (
        "Настроить Web Push",
        "VAPID, soft-prompt и тост при назначении задачи.",
        TaskPriority.high,
        1,
        ("petr", "maria"),
    ),
    (
        "Сверить mobile с web-доской",
        "Вкладки «Мои задачи» / «Доска», свайп между столбцами.",
        TaskPriority.medium,
        1,
        ("igor",),
    ),
    (
        "Прогнать регрессию DnD",
        "Перенос внутри столбца и между столбцами без скачков position.",
        TaskPriority.urgent,
        1,
        ("petr", "alina"),
    ),
    (
        "Ревью экрана профиля",
        "Смена имени, аватара, тема, выход и удаление аккаунта.",
        TaskPriority.medium,
        2,
        ("nina", "maria"),
    ),
    (
        "Проверить OAuth VK / Яндекс",
        "return_path после входа и вступление в проект только по кнопке.",
        TaskPriority.high,
        2,
        ("petr",),
    ),
    (
        "Собрать скриншоты README",
        "Web light/dark + mobile: вход, доска, мои задачи, профиль.",
        TaskPriority.medium,
        2,
        ("alina", "nina"),
    ),
    (
        "Опубликовать лендинг",
        "Заголовок, CTA «Открыть доску» и блок возможностей.",
        TaskPriority.medium,
        3,
        ("nina",),
    ),
    (
        "Включить CI на main",
        "pytest, Next lint/build, flutter analyze/test — всё зелёное.",
        TaskPriority.high,
        3,
        ("petr", "igor"),
    ),
    (
        "Зафиксировать роли проекта",
        "admin / member / viewer и изоляция demo-проектов.",
        TaskPriority.medium,
        3,
        ("maria",),
    ),
    (
        "Добавить виджеты home screen",
        "iOS/Android без JWT в расширении виджета.",
        TaskPriority.low,
        3,
        ("igor",),
    ),
]


async def _ensure_staff(db: AsyncSession, email: str, name: str) -> User:
    user = await db.scalar(select(User).where(User.email == email))
    if user:
        user.name = name
        user.is_demo = True
        user.is_active = True
        user.role = UserRole.member
        user.must_change_password = False
        return user
    user = User(
        email=email,
        name=name,
        role=UserRole.member,
        password_hash=hash_password(secrets.token_urlsafe(48)),
        is_active=True,
        is_demo=True,
        must_change_password=False,
    )
    db.add(user)
    await db.flush()
    return user


async def _ensure_membership(
    db: AsyncSession, project_id: uuid.UUID, user_id: uuid.UUID, role: ProjectMemberRole
) -> None:
    row = await db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id, ProjectMember.user_id == user_id
        )
    )
    if row:
        row.role = role
        return
    db.add(ProjectMember(project_id=project_id, user_id=user_id, role=role))


async def _ensure_statuses(db: AsyncSession, project: Project) -> list[TaskStatus]:
    existing = list(
        (
            await db.execute(
                select(TaskStatus)
                .where(TaskStatus.project_id == project.id)
                .order_by(TaskStatus.position.asc())
            )
        ).scalars()
    )
    if len(existing) >= 4:
        return existing[:4]
    for i, (name, color, _pos, is_done) in enumerate(DEFAULT_STATUS_TEMPLATE):
        db.add(
            TaskStatus(
                project_id=project.id,
                name=name,
                color=color,
                position=float(i),
                is_done=is_done,
            )
        )
    await db.flush()
    return list(
        (
            await db.execute(
                select(TaskStatus)
                .where(TaskStatus.project_id == project.id)
                .order_by(TaskStatus.position.asc())
            )
        ).scalars()
    )[:4]


async def seed_readme_demo(db: AsyncSession, settings: Settings | None = None) -> dict:
    settings = settings or get_settings()
    report: dict = {
        "staff": 0,
        "tasks_created": 0,
        "tasks_existing": 0,
        "notifications": 0,
        "project_id": None,
    }

    demo_email = (settings.DEMO_USER_EMAIL or "demo@example.com").strip().lower()
    demo_user = await db.scalar(select(User).where(User.email == demo_email))
    if not demo_user:
        raise RuntimeError(
            f"Demo user {demo_email} not found. Run scripts/setup_demo_workspace.py first."
        )
    demo_user.is_demo = True
    demo_user.name = demo_user.name or "Демо пользователь"

    staff: dict[str, User] = {}
    for key, name, email in README_STAFF:
        staff[key] = await _ensure_staff(db, email, name)
    report["staff"] = len(staff)

    project = await db.scalar(
        select(Project).where(Project.name == PROJECT_NAME, Project.is_demo.is_(True))
    )
    if not project:
        project = Project(
            name=PROJECT_NAME,
            description=PROJECT_DESC,
            color=PROJECT_COLOR,
            icon="rocket",
            is_default=False,
            is_archived=False,
            is_demo=True,
        )
        db.add(project)
        await db.flush()
    else:
        project.description = PROJECT_DESC
        project.color = PROJECT_COLOR
        project.is_demo = True
        project.is_archived = False

    report["project_id"] = str(project.id)
    cols = await _ensure_statuses(db, project)
    if len(cols) < 4:
        raise RuntimeError("README project missing standard columns")

    await _ensure_membership(db, project.id, demo_user.id, ProjectMemberRole.admin)
    for u in staff.values():
        await _ensure_membership(db, project.id, u.id, ProjectMemberRole.member)

    existing_titles = {
        t.title
        for t in (
            await db.execute(
                select(Task).where(Task.project_id == project.id, Task.deleted_at.is_(None))
            )
        ).scalars()
    }

    now = datetime.now(UTC)
    created_tasks: list[Task] = []
    for i, (title, desc, priority, col_i, keys) in enumerate(README_TASKS):
        if title in existing_titles:
            report["tasks_existing"] += 1
            continue
        status = cols[col_i]
        task = Task(
            project_id=project.id,
            status_id=status.id,
            title=title,
            description=desc,
            priority=priority,
            position=(i + 1) * -1024,
            author_id=demo_user.id,
            status_entered_at=now - timedelta(hours=2 + i),
            closed_at=now - timedelta(hours=1) if status.is_done else None,
        )
        db.add(task)
        await db.flush()
        for key in keys:
            db.add(TaskAssignee(task_id=task.id, user_id=staff[key].id))
        # Demo viewer also on a couple of open tasks for «Мои задачи»
        if col_i in (0, 1) and i % 3 == 0:
            db.add(TaskAssignee(task_id=task.id, user_id=demo_user.id))
        created_tasks.append(task)
        report["tasks_created"] += 1

    # Refresh demo in-app notifications (clean short copy, no markers in body).
    old = (
        await db.scalars(
            select(Notification).where(
                Notification.user_id == demo_user.id,
                Notification.project_id == project.id,
            )
        )
    ).all()
    for n in old:
        await db.delete(n)

    actor = staff["alina"]
    sample = (
        await db.execute(
            select(Task)
            .where(Task.project_id == project.id, Task.deleted_at.is_(None))
            .order_by(Task.position.asc())
            .limit(3)
        )
    ).scalars().all()
    for task in sample:
        await create_in_app(
            db,
            user_id=demo_user.id,
            actor_id=actor.id,
            kind="task_assigned",
            title=task.title,
            body=f"{format_assignment_line(actor_name=actor.name)}\nПроект {PROJECT_NAME}",
            task_id=task.id,
            project_id=project.id,
        )
        report["notifications"] += 1

    await db.commit()
    return report
