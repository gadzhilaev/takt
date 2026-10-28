# 04. Целевой продукт и UX

Ориентиры: скорость/чистота Linear + понятность YouGile + гибкость GitHub Projects — **без копирования UI**.

Принцип: сначала сделать **надёжный single-team board**, затем **Projects**, затем advanced views/integrations.

---

## 1. Продуктовая рамка (что строим)

**Для кого:** небольшая команда (5–50), задачи и проекты в одном инстансе.  
**Не цель v1:** enterprise multi-org, Gantt-конструктор, полноценный GitHub clone.

### Must-have после стабилизации

1. Рабочая доска + создание/редактирование/перенос задач
2. Полноценная карточка задачи (свойства + комментарии + чеклист + история)
3. Мои задачи как inbox дня
4. Поиск и базовые фильтры
5. Уведомления in-app (минимум: назначения, упоминания, комментарии)
6. Проекты с собственной доской (колонки = статусы проекта)

### Explicit non-goals на ближайшие итерации

- Календарь / Timeline (после due-date adoption)
- GitHub sync
- Real-time CRDT collaborative editing
- Автоматизации/боты

---

## 2. Целевая информационная архитектура

```text
/[home]           Обзор: мои дедлайны, назначенные, недавно обновлённые
/my               Inbox / мои задачи (фильтры: assigned to me, created by me, watching)
/projects         Список проектов
/projects/:id     Доска проекта (+ tabs: Board | List | Table)
/tasks/:id        Детальная задача (shareable URL) — drawer на desktop как overlay того же route
/search           Результаты / или command palette
/inbox            Уведомления
/settings/team    Команда, статусы по умолчанию, роли
/admin/users      Пользователи (как сейчас)
/reports          Отчёты (команда / проект)
```

Текущие `/board`, `/list` мапятся на **дефолтный проект «Общее»** или personal views, чтобы не ломать привычку.

---

## 3. Ключевые экраны

### 3.1 Home / Overview

- Блоки: «На сегодня», «Просрочено», «Ждут меня», «Недавняя активность»
- CTA: «Новая задача» (с выбором проекта)
- Пустой онбординг: 3 шага (создать проект → пригласить → первая задача)

### 3.2 Project Board (primary)

Шапка: имя проекта · view switcher (Board/List) · Filter · Search · `+ Задача` · members  
Колонки: статус + count + inline add  
Карточка: title, priority, due, assignees, labels, checklist progress, comment count  
DnD: между колонками **и** reorder внутри; optimistic + rollback toast

### 3.3 Task detail (обязательный deep link)

Левая колонка: title, description (markdown), checklist, comments  
Правая колонка свойств: Status, Assignees, Priority, Due, Labels, Project, Created/Author  
Низ/таб: Activity  
Actions: Copy link, Duplicate (P1), Delete/Archive (с правом)

Клавиатура: `Esc` close, `E` focus title, `Cmd/Ctrl+Enter` comment.

### 3.4 List / Table

Сортируемые колонки; клик → task route; bulk select (P1): смена статуса/assignee.

### 3.5 My tasks

Группы: Overdue / Today / Upcoming / No date.  
Не «ещё один flat list».

### 3.6 Notifications

Список: «Вас назначили», «Упомянули», «Комментарий».  
Mark read; клик → task.

### 3.7 Settings

- Team name/logo (есть)
- Default statuses template
- Project create permissions
- Notification preferences (позже)

---

## 4. Основные пользовательские сценарии

| # | Сценарий | Шаги (целевые) | Критерий успеха |
|---|----------|----------------|-----------------|
| S1 | Создать задачу за ≤3 сек | `C` или `+` → title → Enter | задача в колонке, URL копируем |
| S2 | Назначить и поставить срок | открыть задачу → assignee + due | видно на карточке и в My |
| S3 | Перенести статус | drag или свойство Status | closed_at корректен; realtime у второго юзера |
| S4 | Обсудить | comment + @mention | уведомление у упомянутого |
| S5 | Найти | `/` или поиск → фильтр | ≤2 клика до задачи |
| S6 | Новый сотрудник | admin создаёт → temp password → first login | как сейчас, сохранить |
| S7 | Проект | создать проект → доска → задачи только в нём | изоляция списка |

---

## 5. Дизайн-принципы UI

1. **Одна главная поверхность** — доска проекта; остальное вокруг неё  
2. **Скорость > декора** — мало chrome, много keyboard  
3. **Свойства всегда видны** в detail; не прятать за «ещё» без нужды  
4. **Честная обратная связь** — toast ошибок, skeleton, empty с CTA  
5. **Shareable everything** — задача и проект имеют URL  
6. **Не плодить views** без сценария — Calendar/Timeline только после спроса

Визуальный язык: сохранить slate/indigo dark mode, но усилить иерархию (project name как hero на доске, не generic «Доска»). Добавить Toast, Dropdown, Dialog, Command palette в UI kit.

---

## 6. Модель данных (целевая, эволюционно)

```text
Team (есть как settings)
  └── Project (новое)
        ├── ProjectMember (user, role: admin|member|viewer)
        ├── Status (перенос с global → per-project; seed из template)
        └── Task (+ project_id; остальное почти как сейчас)
              ├── Assignees, Labels (labels можно project-scoped)
              ├── Checklist, Comments, Activity
              └── Attachments (оживить)

Notification (новое)
SavedView / Filter (P2)
```

Миграция: существующие tasks → проект «Общее» (`is_default=true`).

---

## 7. Интеграции (когда)

| Когда | Что |
|-------|-----|
| После P0/P1 core | Incoming webhook create task |
| После Projects + Notifications | GitHub Issues link (manual URL field сначала) |
| Позже | двусторонняя sync статусов — только если команда реально в GitHub Issues |

Не строить sync «на всякий случай».
