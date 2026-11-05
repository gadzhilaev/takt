"""Idempotent seed: «Колледж ДГУ» demo board for demo@example.com.

Creates demo-only staff profiles (is_demo=True, random passwords, no login),
~23 college-themed tasks, and in-app notifications for the demo viewer.
Does not send Web Push. Safe to re-run — no duplicate staff/tasks.
"""

from __future__ import annotations

import re
import secrets
import uuid
from datetime import UTC, datetime

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
from app.services.ru_names import format_assignment_line, format_completed_line

COLLEGE_PROJECT_NAME = "Колледж ДГУ"
COLLEGE_PROJECT_DESC = (
    "Демонстрационная доска команды цифровых сервисов колледжа. "
    "Данные условные, не являются распоряжениями Колледжа ДГУ. [demo-workspace]"
)

# Display names only — emails are synthetic demo.*@example.com (not real people).
DEMO_STAFF: list[tuple[str, str, str]] = [
    ("kadachiev", "Кадачиев Алибек", "demo.kadachiev@example.com"),
    ("yagiyaev", "Ягияев Али", "demo.yagiyaev@example.com"),
    ("akhmedova", "Ахмедова Джамиля", "demo.akhmedova@example.com"),
    ("gadzhilaev", "Гаджилаев Магомедгаджи", "demo.gadzhilaev@example.com"),
    ("ragimov", "Рагимов Рахман", "demo.ragimov@example.com"),
    ("abakarov", "Абакаров Магомед", "demo.abakarov@example.com"),
    ("velieva", "Велиева Сабина", "demo.velieva@example.com"),
    ("isaeva", "Исаева Карина", "demo.isaeva@example.com"),
]

TECH_TITLE_RE = re.compile(
    r"^(E2E\b|Mobile\b|Mobile status\b|API move\b|DnD\b|assignee-fix\b|probe saved\b|"
    r"Audit test\b|Audit2\b|Browser smoke\b|Демо:|"
    r"Создать первую задачу\b|Назначить исполнителя\b|Переместить в работу\b|"
    r"Отправить на проверку\b|Завершить задачу\b)",
    re.IGNORECASE,
)

NOTIF_MARKER = "[demo-seed]"

# (title, description, priority, column_index 0..3, staff_keys)
# Columns: К выполнению / В работе / На проверке / Готово
COLLEGE_TASKS: list[tuple[str, str, TaskPriority, int, tuple[str, ...]]] = [
    # —— К выполнению ——
    (
        "Обновить информацию о специальностях на сайте",
        "Сверить карточки направлений (ИБ, разработка ПО, сопровождение ИС, юриспруденция, УПК) "
        "с актуальными текстами на college.dgu.ru и подготовить правки для публикации.",
        TaskPriority.high,
        0,
        ("akhmedova", "isaeva"),
    ),
    (
        "Проверить форму обращения в УПК",
        "Пройти сценарий отправки обращения через раздел УПК: валидация полей, подтверждение, "
        "письмо/запись на стороне приёмной. Зафиксировать найденные сбои.",
        TaskPriority.urgent,
        0,
        ("ragimov", "velieva"),
    ),
    (
        "Подготовить материалы для приёмной кампании",
        "Собрать тексты и визуалы для блока «Абитуриенту»: сроки, контакты колледжа "
        "(ул. Дзержинского 21), ссылки на мобильное приложение и портал.",
        TaskPriority.medium,
        0,
        ("akhmedova", "isaeva", "velieva"),
    ),
    (
        "Проверить актуальность контактной информации",
        "Сверить телефон, email college@dgu.ru и адрес на главной, в футере и в разделе УПК.",
        TaskPriority.medium,
        0,
        ("isaeva",),
    ),
    (
        "Обновить изображения на сайте колледжа",
        "Подобрать и заменить устаревшие фото кампуса/направлений в галерее главной страницы "
        "с сохранением фирменного стиля портала.",
        TaskPriority.medium,
        0,
        ("akhmedova",),
    ),
    (
        "Подготовить макеты информационных материалов",
        "Макеты листовок и экранов киоска для приёмной: QR на App Store / RuStore / Google Play "
        "мобильного приложения «Колледж ДГУ».",
        TaskPriority.medium,
        0,
        ("akhmedova", "velieva"),
    ),
    (
        "Проверить компьютеры в учебных аудиториях",
        "Обход компьютерных классов: включение, вход в учётные записи, доступ к образовательному "
        "порталу. Список неисправных рабочих мест — в комментарии к задаче.",
        TaskPriority.high,
        0,
        ("abakarov", "yagiyaev"),
    ),
    (
        "Проверить работу принтеров",
        "Тестовая печать в ключевых аудиториях и у администраторов; расходники и очередь печати.",
        TaskPriority.medium,
        0,
        ("abakarov",),
    ),
    # —— В работе ——
    (
        "Обновить мобильное приложение колледжа",
        "Подготовить релиз с правками экрана статуса зачисления и уведомлений. "
        "Сборки для App Store, RuStore и Google Play — по чек-листу публикации.",
        TaskPriority.urgent,
        1,
        ("kadachiev", "gadzhilaev", "yagiyaev"),
    ),
    (
        "Исправить отображение расписания занятий",
        "На портале и в приложении расписание «плывёт» на узких экранах. "
        "Нужен стабильный вид на мобильной ширине без горизонтального скролла таблицы.",
        TaskPriority.urgent,
        1,
        ("gadzhilaev", "ragimov"),
    ),
    (
        "Проверить авторизацию студентов",
        "Регрессия входа по СНИЛС в мобильном приложении и на /auth: ошибки, блокировки, "
        "повторный вход после выхода.",
        TaskPriority.high,
        1,
        ("kadachiev", "ragimov", "isaeva"),
    ),
    (
        "Настроить программное обеспечение в компьютерном классе",
        "Установить актуальный стек для лабораторных по разработке ПО и сопровождению ИС "
        "(IDE, браузеры, клиент портала). Документировать образ машины.",
        TaskPriority.high,
        1,
        ("abakarov", "yagiyaev", "gadzhilaev"),
    ),
    (
        "Проверить подключение к интернету в аудиториях",
        "Замеры Wi‑Fi и проводной сети в учебных кабинетах; точки без доступа — на схему этажа.",
        TaskPriority.high,
        1,
        ("abakarov", "ragimov"),
    ),
    (
        "Исправить ошибки мобильной версии сайта",
        "Баги меню и кнопки «Скачать» приложения на ширине <400px. Чек-лист: главная, новости, УПК.",
        TaskPriority.medium,
        1,
        ("gadzhilaev", "akhmedova"),
    ),
    # —— На проверке ——
    (
        "Проверить отправку push-уведомлений",
        "Тестовые пуши о статусе зачисления на стенде приложения. Убедиться, что доставка "
        "идёт только на тестовые устройства, без рассылки реальным абитуриентам.",
        TaskPriority.high,
        2,
        ("kadachiev", "velieva"),
    ),
    (
        "Проверить доступность цифровых сервисов студентам",
        "Смоук: образовательный портал, личный кабинет /auth, ссылки на приложение. "
        "Зафиксировать недоступные разделы и время ответа.",
        TaskPriority.medium,
        2,
        ("ragimov", "isaeva", "yagiyaev"),
    ),
    (
        "Обновить программное обеспечение рабочих компьютеров",
        "Патчи ОС и браузеров на рабочих местах сотрудников IT. Отчёт: что обновлено / что отложено.",
        TaskPriority.medium,
        2,
        ("abakarov", "kadachiev"),
    ),
    (
        "Подготовить оборудование для мероприятия",
        "Демонстрация цифровых сервисов колледжа для абитуриентов: ноутбуки, проектор, "
        "резервный канал интернета, тестовые учётки портала.",
        TaskPriority.high,
        2,
        ("yagiyaev", "abakarov", "akhmedova", "velieva"),
    ),
    # —— Готово ——
    (
        "Выложить актуальные новости на портал",
        "Опубликована подборка новостей колледжа; превью и даты проверены на главной и /news.",
        TaskPriority.medium,
        3,
        ("isaeva", "akhmedova"),
    ),
    (
        "Добавить QR-коды приложения на стенды приёмной",
        "QR на App Store / RuStore / Google Play размещены на информационных стендах; "
        "сканирование проверено на iOS и Android.",
        TaskPriority.medium,
        3,
        ("velieva", "akhmedova"),
    ),
    (
        "Сверить тексты направлений подготовки",
        "Описания 10.02.05, 09.02.11, 09.02.12 и юридических направлений сверены с сайтом; "
        "опечатки исправлены.",
        TaskPriority.medium,
        3,
        ("isaeva",),
    ),
    (
        "Настроить тестовый контур уведомлений приложения",
        "Отдельный стенд для push без доступа к production-подписчикам. Документация для команды.",
        TaskPriority.high,
        3,
        ("kadachiev", "gadzhilaev"),
    ),
    (
        "Провести инвентаризацию техники в УПК",
        "Список рабочих станций и периферии учебно-производственного комплекса актуализирован.",
        TaskPriority.medium,
        3,
        ("abakarov", "yagiyaev", "ragimov"),
    ),
]


async def _ensure_staff_user(db: AsyncSession, email: str, name: str) -> User:
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
    exists = await db.scalar(
        select(ProjectMember.id).where(
            ProjectMember.project_id == project_id, ProjectMember.user_id == user_id
        )
    )
    if exists:
        m = await db.scalar(
            select(ProjectMember).where(
                ProjectMember.project_id == project_id, ProjectMember.user_id == user_id
            )
        )
        if m and m.role != role and role == ProjectMemberRole.admin:
            m.role = role
        return
    db.add(ProjectMember(project_id=project_id, user_id=user_id, role=role))


async def _ensure_statuses(db: AsyncSession, project: Project) -> dict[int, TaskStatus]:
    rows = (
        await db.scalars(
            select(TaskStatus).where(TaskStatus.project_id == project.id).order_by(TaskStatus.position)
        )
    ).all()
    by_name = {s.name: s for s in rows}
    if len(rows) == 0:
        for pos, (sname, scolor, _p, is_done) in enumerate(DEFAULT_STATUS_TEMPLATE):
            s = TaskStatus(
                project_id=project.id,
                name=sname,
                color=scolor,
                position=float(pos),
                is_done=is_done,
            )
            db.add(s)
            await db.flush()
            by_name[sname] = s
    else:
        # Demo board: keep standard column names aligned with current palette.
        for pos, (sname, scolor, _p, is_done) in enumerate(DEFAULT_STATUS_TEMPLATE):
            existing = by_name.get(sname)
            if existing is None:
                continue
            if (existing.color or "").lower() != scolor.lower():
                existing.color = scolor
            existing.is_done = is_done
            existing.position = float(pos)
    return {
        i: by_name[name]
        for i, (name, *_rest) in enumerate(DEFAULT_STATUS_TEMPLATE)
        if name in by_name
    }


async def _soft_delete_tech_tasks(db: AsyncSession, project_ids: list[uuid.UUID]) -> int:
    if not project_ids:
        return 0
    tasks = (
        await db.scalars(
            select(Task).where(Task.project_id.in_(project_ids), Task.deleted_at.is_(None))
        )
    ).all()
    n = 0
    now = datetime.now(UTC)
    for t in tasks:
        if TECH_TITLE_RE.match(t.title or ""):
            t.deleted_at = now
            n += 1
    return n


async def seed_college_demo(db: AsyncSession, settings: Settings | None = None) -> dict:
    settings = settings or get_settings()
    report: dict = {
        "staff": 0,
        "tasks_created": 0,
        "tasks_existing": 0,
        "tech_cleaned": 0,
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
    for key, name, email in DEMO_STAFF:
        staff[key] = await _ensure_staff_user(db, email, name)
    report["staff"] = len(staff)

    # Project
    project = await db.scalar(
        select(Project).where(Project.name == COLLEGE_PROJECT_NAME, Project.is_demo.is_(True))
    )
    if not project:
        project = await db.scalar(select(Project).where(Project.name == COLLEGE_PROJECT_NAME))
    if not project:
        # Prefer renaming «Демо-доска» if it still exists and is demo
        legacy = await db.scalar(
            select(Project).where(Project.name == "Демо-доска", Project.is_demo.is_(True))
        )
        if legacy:
            project = legacy
            project.name = COLLEGE_PROJECT_NAME
            project.description = COLLEGE_PROJECT_DESC
            project.is_demo = True
            project.is_archived = False
        else:
            project = Project(
                name=COLLEGE_PROJECT_NAME,
                description=COLLEGE_PROJECT_DESC,
                color="#172446",
                icon="graduation-cap",
                is_default=False,
                is_archived=False,
                is_demo=True,
            )
            db.add(project)
            await db.flush()
    else:
        project.description = COLLEGE_PROJECT_DESC
        project.is_demo = True
        project.is_archived = False
        project.color = project.color or "#172446"

    report["project_id"] = str(project.id)

    cols = await _ensure_statuses(db, project)
    if len(cols) < 4:
        raise RuntimeError("College project missing standard columns")

    await _ensure_membership(db, project.id, demo_user.id, ProjectMemberRole.admin)
    for u in staff.values():
        await _ensure_membership(db, project.id, u.id, ProjectMemberRole.member)

    # Strip non-demo members from college board
    keep = {demo_user.id, *(u.id for u in staff.values())}
    for m in (
        await db.scalars(select(ProjectMember).where(ProjectMember.project_id == project.id))
    ).all():
        if m.user_id not in keep:
            await db.delete(m)

    # Clean tech titles on this project + old demo boards the demo user owns
    demo_projects = (
        await db.scalars(select(Project).where(Project.is_demo.is_(True), Project.is_archived.is_(False)))
    ).all()
    report["tech_cleaned"] = await _soft_delete_tech_tasks(db, [p.id for p in demo_projects])

    # Ensure tasks (idempotent by title within project)
    for title, desc, priority, col_idx, keys in COLLEGE_TASKS:
        existing = await db.scalar(
            select(Task).where(
                Task.project_id == project.id,
                Task.title == title,
                Task.deleted_at.is_(None),
            )
        )
        status = cols[col_idx]
        assignee_users = [staff[k] for k in keys]
        if existing:
            existing.description = desc
            existing.priority = priority
            existing.status_id = status.id
            if col_idx == 3 and status.is_done and not existing.closed_at:
                existing.closed_at = datetime.now(UTC)
            # sync assignees
            current = {
                a.user_id
                for a in (
                    await db.scalars(select(TaskAssignee).where(TaskAssignee.task_id == existing.id))
                ).all()
            }
            want = {u.id for u in assignee_users}
            for uid in current - want:
                row = await db.scalar(
                    select(TaskAssignee).where(
                        TaskAssignee.task_id == existing.id, TaskAssignee.user_id == uid
                    )
                )
                if row:
                    await db.delete(row)
            for uid in want - current:
                db.add(TaskAssignee(task_id=existing.id, user_id=uid))
            report["tasks_existing"] += 1
            continue

        pos = float(
            (await db.scalar(
                select(Task.position)
                .where(Task.status_id == status.id, Task.deleted_at.is_(None))
                .order_by(Task.position.desc())
                .limit(1)
            ))
            or 0
        ) + 1024
        task = Task(
            project_id=project.id,
            title=title,
            description=desc,
            status_id=status.id,
            priority=priority,
            author_id=demo_user.id,
            position=pos,
            closed_at=datetime.now(UTC) if col_idx == 3 else None,
        )
        db.add(task)
        await db.flush()
        for u in assignee_users:
            db.add(TaskAssignee(task_id=task.id, user_id=u.id))
        report["tasks_created"] += 1

    await _seed_notifications(db, demo_user, staff, project, cols, report)
    await db.commit()
    return report


async def _seed_notifications(
    db: AsyncSession,
    demo_user: User,
    staff: dict[str, User],
    project: Project,
    cols: dict[int, TaskStatus],
    report: dict,
) -> None:
    """In-app only (no Web Push). Idempotent via NOTIF_MARKER in body."""
    # Clear previous demo-seed notifications for this viewer on this project
    old = (
        await db.scalars(
            select(Notification).where(
                Notification.user_id == demo_user.id,
                Notification.project_id == project.id,
                Notification.body.is_not(None),
                Notification.body.contains(NOTIF_MARKER),
            )
        )
    ).all()
    for n in old:
        await db.delete(n)

    # Pick tasks by title for narrative
    async def task_by_title(title: str) -> Task | None:
        return await db.scalar(
            select(Task).where(
                Task.project_id == project.id,
                Task.title == title,
                Task.deleted_at.is_(None),
            )
        )

    # 1) Исаева назначила вам задачу
    t1 = await task_by_title("Проверить актуальность контактной информации")
    isaeva = staff["isaeva"]
    if t1:
        # Ensure demo user is an assignee for «вам»
        has = await db.scalar(
            select(TaskAssignee.id).where(
                TaskAssignee.task_id == t1.id, TaskAssignee.user_id == demo_user.id
            )
        )
        if not has:
            db.add(TaskAssignee(task_id=t1.id, user_id=demo_user.id))
        line = format_assignment_line(actor_name=isaeva.name)
        await create_in_app(
            db,
            user_id=demo_user.id,
            actor_id=isaeva.id,
            kind="task_assigned",
            title=t1.title,
            body=f"{line}\nПроект {project.name} {NOTIF_MARKER}",
            task_id=t1.id,
            project_id=project.id,
        )
        report["notifications"] += 1

    # 2) Велиева назначила задачу нескольким участникам
    t2 = await task_by_title("Подготовить оборудование для мероприятия")
    velieva = staff["velieva"]
    if t2:
        has = await db.scalar(
            select(TaskAssignee.id).where(
                TaskAssignee.task_id == t2.id, TaskAssignee.user_id == demo_user.id
            )
        )
        if not has:
            db.add(TaskAssignee(task_id=t2.id, user_id=demo_user.id))
        line = format_assignment_line(actor_name=velieva.name)
        await create_in_app(
            db,
            user_id=demo_user.id,
            actor_id=velieva.id,
            kind="task_assigned",
            title=t2.title,
            body=f"{line}\nПроект {project.name} {NOTIF_MARKER}",
            task_id=t2.id,
            project_id=project.id,
        )
        report["notifications"] += 1

    # 3) Кадачиев завершил задачу (author = demo user)
    t3 = await task_by_title("Настроить тестовый контур уведомлений приложения")
    kadachiev = staff["kadachiev"]
    if t3:
        t3.author_id = demo_user.id
        done = cols.get(3)
        if done:
            t3.status_id = done.id
            t3.closed_at = t3.closed_at or datetime.now(UTC)
        line = format_completed_line(actor_name=kadachiev.name)
        await create_in_app(
            db,
            user_id=demo_user.id,
            actor_id=kadachiev.id,
            kind="task_completed",
            title=t3.title,
            body=f"{line}\nПроект {project.name} {NOTIF_MARKER}",
            task_id=t3.id,
            project_id=project.id,
        )
        report["notifications"] += 1
