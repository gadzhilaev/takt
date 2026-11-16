"""Idempotent seed for the App Review account.

Fills one real (loginable) account with plausible data of an educational organization:
3 projects, ~20 tasks with demo-only assignees (``is_demo=True``, cannot log in),
deadlines relative to *now* (some overdue, some due soon), stub attachments,
comments, task history and a few in-app notifications.

Re-running is safe: projects/staff/tasks are matched by name/email/title, deadlines are
re-anchored to the current time, comments/attachments/history are not duplicated,
review notifications are replaced. No Web Push / FCM / email is sent.

Credentials are never stored in code: email/password come from the caller (CLI/ENV).

Safety: ``plan_review_seed`` is read-only (the CLI runs it by default as a dry-run).
``seed_review_account`` refuses to touch an existing account that shares projects with
other real (non-demo) users unless ``force_foreign_projects=True``.
"""

from __future__ import annotations

import io
import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from PIL import Image, ImageDraw
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.notification import Notification
from app.models.project import Project, ProjectMember, ProjectMemberRole
from app.models.task import ActivityLog, Attachment, Comment, Task, TaskAssignee, TaskPriority
from app.models.team import TaskStatus
from app.models.user import User, UserRole
from app.services.account_service import exit_projects, plan_project_exits
from app.services.attachment_service import attachments_dir, remove_dirs
from app.services.project_service import DEFAULT_STATUS_TEMPLATE
from app.services.ru_names import format_assignment_line, format_completed_line

P = TaskPriority

# Demo-only colleagues (synthetic emails, fictional names, no login).
REVIEW_STAFF: list[tuple[str, str, str]] = [
    ("sokolova", "Соколова Анна", "demo.review.sokolova@example.com"),
    ("morozov", "Морозов Дмитрий", "demo.review.morozov@example.com"),
    ("belova", "Белова Ольга", "demo.review.belova@example.com"),
    ("kuznetsov", "Кузнецов Артём", "demo.review.kuznetsov@example.com"),
    ("lebedeva", "Лебедева Марина", "demo.review.lebedeva@example.com"),
    ("orlov", "Орлов Сергей", "demo.review.orlov@example.com"),
]

ME = "me"  # the review account itself as an assignee


@dataclass(frozen=True)
class SeedTask:
    title: str
    description: str
    priority: TaskPriority
    column: int  # 0 К выполнению / 1 В работе / 2 На проверке / 3 Готово
    assignees: tuple[str, ...]
    author: str
    created_days_ago: float
    due_in_hours: float | None = None  # negative = overdue
    in_status_days: float = 1.0
    attachment: str | None = None  # "image" | "pdf"
    attachment_name: str | None = None
    comments: tuple[tuple[str, str], ...] = ()


@dataclass(frozen=True)
class SeedProject:
    name: str
    description: str
    color: str
    icon: str
    tasks: tuple[SeedTask, ...]


REVIEW_PROJECTS: tuple[SeedProject, ...] = (
    SeedProject(
        name="Приёмная кампания",
        description="Подготовка и проведение приёма абитуриентов.",
        color="#315F72",
        icon="graduation-cap",
        tasks=(
            SeedTask(
                "Обновить правила приёма на сайте",
                "Опубликовать актуальную версию правил приёма и перечень специальностей. "
                "Проверить даты начала и окончания подачи документов.",
                P.urgent, 1, (ME, "sokolova"), "sokolova", 6,
                due_in_hours=-20, in_status_days=3,
                attachment="pdf", attachment_name="Правила приёма — проект.pdf",
                comments=(
                    ("sokolova", "Юристы прислали правки по разделу о целевом обучении."),
                    (ME, "Внесу правки сегодня и отправлю на проверку."),
                ),
            ),
            SeedTask(
                "Подготовить график дня открытых дверей",
                "Расписание по аудиториям, ответственные за экскурсии, регистрация гостей.",
                P.high, 0, ("belova", ME), "belova", 2,
                due_in_hours=30, in_status_days=2,
            ),
            SeedTask(
                "Собрать ответы на частые вопросы абитуриентов",
                "Вопросы из приёмной и чата за прошлый год: общежитие, проходной балл, "
                "документы, сроки. Сформулировать короткие ответы.",
                P.medium, 0, ("lebedeva",), ME, 3,
                due_in_hours=24 * 6,
            ),
            SeedTask(
                "Напечатать буклеты для приёмной комиссии",
                "Тираж 500 шт., макет согласован. Нужен счёт от типографии.",
                P.medium, 1, ("orlov",), "sokolova", 5,
                due_in_hours=40, in_status_days=2,
                attachment="image", attachment_name="Макет буклета.png",
            ),
            SeedTask(
                "Проверить работу телефона горячей линии",
                "Переадресация на дежурного, автоответчик в нерабочее время.",
                P.high, 2, ("kuznetsov",), ME, 4,
                due_in_hours=10, in_status_days=1,
                comments=(
                    ("kuznetsov", "Переадресацию настроил, осталось записать автоответчик."),
                ),
            ),
            SeedTask(
                "Утвердить состав приёмной комиссии",
                "Приказ подписан, состав доведён до сотрудников.",
                P.medium, 3, ("sokolova", ME), "sokolova", 12, in_status_days=4,
            ),
            SeedTask(
                "Разместить объявление о приёме в соцсетях",
                "Пост и сторис с датами подачи документов и ссылкой на правила приёма.",
                P.low, 3, ("lebedeva",), ME, 9, in_status_days=2,
            ),
        ),
    ),
    SeedProject(
        name="Цифровые сервисы колледжа",
        description="Сайт, электронный журнал, учебные аудитории и техника.",
        color="#347FA4",
        icon="monitor",
        tasks=(
            SeedTask(
                "Перенести расписание занятий в электронный журнал",
                "Расписание на весенний семестр по всем группам. Сверить с учебной частью.",
                P.urgent, 1, ("morozov", ME), "morozov", 7,
                due_in_hours=-4, in_status_days=4,
                comments=(
                    ("morozov", "Осталось три группы второго курса."),
                    ("belova", "Учебная часть пришлёт исправления по субботам."),
                ),
            ),
            SeedTask(
                "Настроить проектор в актовом зале",
                "Не определяется ноутбук по HDMI. Проверить кабель и переходник.",
                P.high, 0, ("kuznetsov",), ME, 1,
                due_in_hours=20,
                attachment="image", attachment_name="Фото подключения.png",
            ),
            SeedTask(
                "Выдать преподавателям доступ к электронному журналу",
                "12 новых преподавателей. Логины отправить на рабочую почту.",
                P.high, 2, ("morozov",), "belova", 5,
                due_in_hours=48, in_status_days=1,
            ),
            SeedTask(
                "Обновить раздел «Студенту» на сайте",
                "Ссылки на расписание, стипендии, справки, контакты кураторов.",
                P.medium, 0, ("lebedeva", "orlov"), "sokolova", 4,
                due_in_hours=24 * 9,
            ),
            SeedTask(
                "Заменить картриджи в кабинете 204",
                "Два принтера, модели указаны в заявке.",
                P.low, 3, ("kuznetsov",), "kuznetsov", 8, in_status_days=5,
            ),
            SeedTask(
                "Проверить Wi‑Fi в библиотеке",
                "Жалобы студентов на обрывы связи. Замерить скорость в читальном зале.",
                P.medium, 1, ("orlov",), ME, 3,
                due_in_hours=60, in_status_days=1,
                comments=(("orlov", "Нужна ещё одна точка доступа у окна."),),
            ),
            SeedTask(
                "Сделать резервную копию журнала успеваемости",
                "Копия за осенний семестр, хранение на сервере колледжа.",
                P.medium, 3, ("morozov",), ME, 10, in_status_days=3,
            ),
        ),
    ),
    SeedProject(
        name="Методический отдел",
        description="Рабочие программы, повышение квалификации, открытые уроки.",
        color="#9062B8",
        icon="book",
        tasks=(
            SeedTask(
                "Собрать рабочие программы на новый учебный год",
                "Программы по всем дисциплинам от предметно-цикловых комиссий.",
                P.urgent, 1, ("belova", ME), "belova", 10,
                due_in_hours=-30, in_status_days=6,
                attachment="pdf", attachment_name="Список дисциплин.pdf",
                comments=(
                    ("belova", "Не хватает программ по трём дисциплинам."),
                    (ME, "Напомню председателям комиссий на планёрке."),
                ),
            ),
            SeedTask(
                "Составить график открытых уроков",
                "Не меньше одного открытого урока от каждой комиссии в семестре.",
                P.medium, 0, ("sokolova",), "belova", 2,
                due_in_hours=24 * 5,
            ),
            SeedTask(
                "Оформить заявки на курсы повышения квалификации",
                "Список преподавателей, у которых истекает срок удостоверения.",
                P.high, 2, ("lebedeva", ME), "sokolova", 6,
                due_in_hours=16, in_status_days=2,
                comments=(("lebedeva", "Заявки готовы, нужна подпись директора."),),
            ),
            SeedTask(
                "Подготовить отчёт по успеваемости за семестр",
                "Сводная таблица по группам и пояснительная записка.",
                P.high, 0, (ME,), "belova", 1,
                due_in_hours=36,
            ),
            SeedTask(
                "Провести семинар для молодых преподавателей",
                "Тема: оценивание практических работ. Материалы разосланы.",
                P.medium, 3, ("sokolova", "belova"), ME, 14, in_status_days=7,
            ),
        ),
    ),
)

# Notifications for the review account (kind, project name, task title, actor key).
_METHOD = "Методический отдел"
_ADMISSION = "Приёмная кампания"
_DIGITAL = "Цифровые сервисы колледжа"
REVIEW_NOTIFICATIONS: tuple[tuple[str, str, str, str], ...] = (
    ("task_assigned", _METHOD, "Подготовить отчёт по успеваемости за семестр", "belova"),
    ("task_assigned", _ADMISSION, "Подготовить график дня открытых дверей", "belova"),
    ("task_assigned", _DIGITAL, "Перенести расписание занятий в электронный журнал", "morozov"),
    ("task_completed", _DIGITAL, "Сделать резервную копию журнала успеваемости", "morozov"),
)


def _stub_png(label_color: str) -> bytes:
    """Simple placeholder image (no text, no personal data)."""
    img = Image.new("RGB", (960, 640), "#E4EEF1")
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((80, 80, 880, 560), radius=36, fill=label_color)
    d.rounded_rectangle((140, 150, 620, 200), radius=16, fill="#FFFFFF")
    d.rounded_rectangle((140, 240, 820, 270), radius=12, fill="#F3F6F8")
    d.rounded_rectangle((140, 300, 760, 330), radius=12, fill="#F3F6F8")
    d.rounded_rectangle((140, 360, 700, 390), radius=12, fill="#F3F6F8")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _webp_preview(png: bytes) -> bytes:
    img = Image.open(io.BytesIO(png)).convert("RGB")
    buf = io.BytesIO()
    img.save(buf, format="WEBP", quality=80)
    return buf.getvalue()


def _stub_pdf(title: str) -> bytes:
    """Minimal valid one-page PDF (ASCII body)."""
    text = "Takt - attachment placeholder"
    stream = f"BT /F1 18 Tf 72 720 Td ({text}) Tj ET".encode()
    objs = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
        b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream",
    ]
    out = io.BytesIO()
    out.write(b"%PDF-1.4\n")
    offsets = []
    for i, body in enumerate(objs, start=1):
        offsets.append(out.tell())
        out.write(f"{i} 0 obj\n".encode() + body + b"\nendobj\n")
    xref = out.tell()
    out.write(f"xref\n0 {len(objs) + 1}\n0000000000 65535 f \n".encode())
    for off in offsets:
        out.write(f"{off:010d} 00000 n \n".encode())
    out.write(
        f"trailer\n<< /Size {len(objs) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    )
    return out.getvalue()


async def _ensure_review_user(
    db: AsyncSession, email: str, password: str | None, name: str | None
) -> tuple[User, bool]:
    user = await db.scalar(select(User).where(User.email == email))
    created = False
    if user is None:
        if not password:
            raise RuntimeError(
                f"Аккаунт {email} не найден. Передайте пароль (--password / "
                "REVIEW_ACCOUNT_PASSWORD), чтобы создать его."
            )
        user = User(
            email=email,
            name=name or "Ковалёва Ирина",
            role=UserRole.member,
            password_hash=hash_password(password),
            is_active=True,
            is_demo=False,  # reviewer must be able to log in and delete the account
            must_change_password=False,
        )
        db.add(user)
        await db.flush()
        created = True
    else:
        if user.is_demo:
            raise RuntimeError("Аккаунт помечен как is_demo — для ревьюера нужен обычный аккаунт.")
        if password:
            user.password_hash = hash_password(password)
        if name:
            user.name = name
        user.is_active = True
        user.blocked_until = None
        user.must_change_password = False
    return user, created


async def _ensure_staff(db: AsyncSession) -> dict[str, User]:
    staff: dict[str, User] = {}
    for key, name, email in REVIEW_STAFF:
        u = await db.scalar(select(User).where(User.email == email))
        if u is None:
            u = User(
                email=email,
                name=name,
                role=UserRole.member,
                password_hash=hash_password(secrets.token_urlsafe(48)),
                is_active=True,
                is_demo=True,
                must_change_password=False,
            )
            db.add(u)
            await db.flush()
        else:
            u.name = name
            u.is_demo = True
            u.is_active = True
        staff[key] = u
    return staff


async def _ensure_project(db: AsyncSession, spec: SeedProject, owner: User) -> Project:
    project = await db.scalar(
        select(Project)
        .join(ProjectMember, ProjectMember.project_id == Project.id)
        .where(
            Project.name == spec.name,
            ProjectMember.user_id == owner.id,
            ProjectMember.role == ProjectMemberRole.admin,
        )
    )
    if project is None:
        project = Project(
            name=spec.name,
            description=spec.description,
            color=spec.color,
            icon=spec.icon,
            is_default=False,
            is_archived=False,
            is_demo=True,
        )
        db.add(project)
        await db.flush()
    else:
        project.description = spec.description
        project.is_archived = False
        project.is_demo = True
    return project


async def _ensure_columns(db: AsyncSession, project: Project) -> list[TaskStatus]:
    rows = list(
        (
            await db.scalars(
                select(TaskStatus)
                .where(TaskStatus.project_id == project.id)
                .order_by(TaskStatus.position)
            )
        ).all()
    )
    if not rows:
        for pos, (name, color, _p, is_done) in enumerate(DEFAULT_STATUS_TEMPLATE):
            s = TaskStatus(
                project_id=project.id, name=name, color=color, position=float(pos), is_done=is_done
            )
            db.add(s)
            rows.append(s)
        await db.flush()
    by_name = {s.name: s for s in rows}
    cols = [by_name.get(name) for name, *_ in DEFAULT_STATUS_TEMPLATE]
    if any(c is None for c in cols):
        raise RuntimeError(f"В проекте «{project.name}» нет стандартных столбцов")
    return cols  # type: ignore[return-value]


async def _ensure_member(
    db: AsyncSession, project_id: uuid.UUID, user_id: uuid.UUID, role: ProjectMemberRole
) -> None:
    m = await db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id, ProjectMember.user_id == user_id
        )
    )
    if m is None:
        db.add(ProjectMember(project_id=project_id, user_id=user_id, role=role))
    elif role == ProjectMemberRole.admin:
        m.role = role


class ReviewSeedRefused(RuntimeError):
    """Seed would affect projects shared with real users; needs explicit consent."""


async def _foreign_plans(db: AsyncSession, me: User) -> list[dict]:
    """Projects outside the seed set, with the same exit rules as account deletion."""
    seed_names = {p.name for p in REVIEW_PROJECTS}
    admin_of = set(
        (
            await db.scalars(
                select(ProjectMember.project_id).where(
                    ProjectMember.user_id == me.id,
                    ProjectMember.role == ProjectMemberRole.admin,
                )
            )
        ).all()
    )
    return [
        p
        for p in await plan_project_exits(db, me)
        if not (p["name"] in seed_names and uuid.UUID(p["id"]) in admin_of)
    ]


async def _projects_shared_with_real_users(db: AsyncSession, me: User) -> list[str]:
    """Names of the account's projects that have other real (non-demo) members."""
    my_projects = select(ProjectMember.project_id).where(ProjectMember.user_id == me.id)
    rows = (
        await db.execute(
            select(Project.name)
            .join(ProjectMember, ProjectMember.project_id == Project.id)
            .join(User, User.id == ProjectMember.user_id)
            .where(
                Project.id.in_(my_projects),
                ProjectMember.user_id != me.id,
                User.is_demo.is_(False),
            )
            .distinct()
            .order_by(Project.name)
        )
    ).scalars().all()
    return list(rows)


async def plan_review_seed(db: AsyncSession, *, email: str) -> dict:
    """Read-only preview of what ``seed_review_account`` would do to an account."""
    email = email.strip().lower()
    me = await db.scalar(select(User).where(User.email == email))
    if me is None:
        return {"user_exists": False, "foreign": [], "shared_with_real": []}
    return {
        "user_exists": True,
        "is_demo": bool(me.is_demo),
        "foreign": await _foreign_plans(db, me),
        "shared_with_real": await _projects_shared_with_real_users(db, me),
    }


async def _exit_foreign_projects(db: AsyncSession, me: User) -> tuple[list[dict], list]:
    """Leave every project outside the seed set (App Review must see only seed data).

    Returns (report rows, attachment folders to remove after commit).
    """
    plans = await _foreign_plans(db, me)
    if not plans:
        return [], []
    file_dirs = await exit_projects(
        db,
        me,
        plans,
        notify_reason="Прежний администратор вышел из проекта, права перешли к вам.",
    )
    left_ids = [uuid.UUID(p["id"]) for p in plans if p["action"] != "delete"]
    if left_ids:
        task_ids = select(Task.id).where(Task.project_id.in_(left_ids))
        await db.execute(
            delete(TaskAssignee).where(
                TaskAssignee.user_id == me.id, TaskAssignee.task_id.in_(task_ids)
            )
        )
    await db.flush()
    rows = [
        {"name": p["name"], "action": p["action"], "new_admin": p.get("new_admin")}
        for p in plans
    ]
    return rows, file_dirs


def _log(task_id, user_id, action, at, field=None, old=None, new=None) -> ActivityLog:
    return ActivityLog(
        task_id=task_id,
        user_id=user_id,
        action=action,
        field=field,
        old_value=old,
        new_value=new,
        created_at=at,
    )


async def seed_review_account(
    db: AsyncSession,
    *,
    email: str,
    password: str | None = None,
    name: str | None = None,
    now: datetime | None = None,
    force_foreign_projects: bool = False,
) -> dict:
    now = now or datetime.now(UTC)
    email = email.strip().lower()

    existing = await db.scalar(select(User).where(User.email == email))
    if existing is not None and not force_foreign_projects:
        shared = await _projects_shared_with_real_users(db, existing)
        if shared:
            raise ReviewSeedRefused(
                "Аккаунт состоит в проектах с другими реальными участниками: "
                + ", ".join(f"«{n}»" for n in shared)
                + ". Похоже, это не аккаунт ревьюера. Если всё верно, "
                "запустите с --force-foreign-projects."
            )
    report: dict = {
        "user_created": False,
        "projects": [],
        "tasks_created": 0,
        "tasks_updated": 0,
        "comments": 0,
        "attachments": 0,
        "notifications": 0,
        "removed_projects": [],
    }

    me, report["user_created"] = await _ensure_review_user(db, email, password, name)
    report["removed_projects"], file_dirs = await _exit_foreign_projects(db, me)
    staff = await _ensure_staff(db)
    people: dict[str, User] = {ME: me, **staff}

    tasks_by_title: dict[tuple[str, str], Task] = {}
    projects_by_name: dict[str, Project] = {}

    for spec in REVIEW_PROJECTS:
        project = await _ensure_project(db, spec, me)
        projects_by_name[spec.name] = project
        report["projects"].append({"id": str(project.id), "name": project.name})
        cols = await _ensure_columns(db, project)

        await _ensure_member(db, project.id, me.id, ProjectMemberRole.admin)
        used = {k for t in spec.tasks for k in (*t.assignees, t.author) if k != ME}
        for key in sorted(used):
            await _ensure_member(db, project.id, staff[key].id, ProjectMemberRole.member)

        # Newest first inside a column: later tasks in the list get lower positions.
        for idx, st in enumerate(spec.tasks):
            status = cols[st.column]
            created_at = now - timedelta(days=st.created_days_ago)
            entered_at = max(created_at, now - timedelta(days=st.in_status_days))
            due = now + timedelta(hours=st.due_in_hours) if st.due_in_hours is not None else None
            closed = entered_at if status.is_done else None
            author = people[st.author]

            task = await db.scalar(
                select(Task).where(
                    Task.project_id == project.id,
                    Task.title == st.title,
                    Task.deleted_at.is_(None),
                )
            )
            is_new = task is None
            if is_new:
                task = Task(
                    project_id=project.id,
                    title=st.title,
                    author_id=author.id,
                    status_id=status.id,
                    position=-1024.0 * (idx + 1),
                    created_at=created_at,
                )
                db.add(task)
            task.description = st.description
            task.priority = st.priority
            task.status_id = status.id
            task.status_entered_at = entered_at
            task.closed_at = closed
            # Re-anchor deadlines to "now" on every run so overdue/soon stays meaningful.
            task.due_date = due
            task.due_basis_at = created_at if due else None
            task.due_soon_notified_at = None
            task.overdue_notified_at = None
            task.archived_at = None
            await db.flush()
            tasks_by_title[(spec.name, st.title)] = task
            report["tasks_created" if is_new else "tasks_updated"] += 1

            # Assignees: exact set
            want = {people[k].id for k in st.assignees}
            current = {
                a.user_id: a
                for a in (
                    await db.scalars(select(TaskAssignee).where(TaskAssignee.task_id == task.id))
                ).all()
            }
            for uid, row in current.items():
                if uid not in want:
                    await db.delete(row)
            for uid in want - current.keys():
                db.add(TaskAssignee(task_id=task.id, user_id=uid))

            # History — only for newly created tasks (no duplicates on re-run).
            if is_new:
                db.add(_log(task.id, author.id, "created", created_at))
                if st.column > 0:
                    mover = people[st.assignees[0]]
                    prev = cols[0]
                    step_at = created_at
                    for col_i in range(1, st.column + 1):
                        nxt = cols[col_i]
                        step_at = (
                            entered_at
                            if col_i == st.column
                            else created_at + (entered_at - created_at) * col_i / (st.column + 1)
                        )
                        db.add(
                            _log(
                                task.id, mover.id, "moved", step_at,
                                "status_id", str(prev.id), str(nxt.id),
                            )
                        )
                        prev = nxt

            # Comments (idempotent by author + body)
            for i, (who, body) in enumerate(st.comments):
                author_c = people[who]
                exists = await db.scalar(
                    select(Comment.id).where(
                        Comment.task_id == task.id,
                        Comment.author_id == author_c.id,
                        Comment.body == body,
                    )
                )
                if not exists:
                    at = created_at + (now - created_at) * (i + 1) / (len(st.comments) + 1)
                    db.add(
                        Comment(
                            task_id=task.id, author_id=author_c.id, body=body,
                            created_at=at, updated_at=at,
                        )
                    )
                    report["comments"] += 1

            # Attachment stub (idempotent by filename)
            if st.attachment and st.attachment_name:
                exists = await db.scalar(
                    select(Attachment.id).where(
                        Attachment.task_id == task.id, Attachment.filename == st.attachment_name
                    )
                )
                if not exists:
                    att_id = uuid.uuid4()
                    folder = attachments_dir(task.id)
                    preview_name = None
                    if st.attachment == "image":
                        data = _stub_png(spec.color)
                        stored = f"{att_id}.png"
                        ctype = "image/png"
                        preview_name = f"{att_id}_preview.webp"
                        (folder / preview_name).write_bytes(_webp_preview(data))
                    else:
                        data = _stub_pdf(st.attachment_name)
                        stored = f"{att_id}.pdf"
                        ctype = "application/pdf"
                    (folder / stored).write_bytes(data)
                    uploader = people[st.author]
                    at = created_at + timedelta(hours=2)
                    db.add(
                        Attachment(
                            id=att_id,
                            task_id=task.id,
                            uploaded_by_id=uploader.id,
                            filename=st.attachment_name,
                            stored_name=stored,
                            preview_stored_name=preview_name,
                            size_bytes=len(data),
                            content_type=ctype,
                            created_at=at,
                            updated_at=at,
                        )
                    )
                    db.add(
                        _log(
                            task.id, uploader.id, "attachment_added", at,
                            "filename", None, st.attachment_name,
                        )
                    )
                    report["attachments"] += 1

    # Notifications: replace previous review notifications in these projects.
    project_ids = [p.id for p in projects_by_name.values()]
    await db.execute(
        delete(Notification).where(
            Notification.user_id == me.id, Notification.project_id.in_(project_ids)
        )
    )
    for i, (kind, pname, title, actor_key) in enumerate(REVIEW_NOTIFICATIONS):
        task = tasks_by_title.get((pname, title))
        actor = staff[actor_key]
        if task is None:
            continue
        line = (
            format_completed_line(actor_name=actor.name)
            if kind == "task_completed"
            else format_assignment_line(actor_name=actor.name)
        )
        db.add(
            Notification(
                user_id=me.id,
                actor_id=actor.id,
                kind=kind,
                title=task.title,
                body=f"{line}\nПроект {pname}",
                task_id=task.id,
                project_id=projects_by_name[pname].id,
                is_read=i >= 2,  # первые два — непрочитанные
                created_at=now - timedelta(hours=3 * (i + 1)),
            )
        )
        report["notifications"] += 1

    await db.commit()
    remove_dirs(file_dirs)  # only after a successful commit
    return report
