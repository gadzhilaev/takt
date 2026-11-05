"""Russian name helpers for notification copy (nominative names / verb gender)."""


def actor_past_verb(full_name: str, masculine: str, feminine: str) -> str:
    """Pick past-tense verb by rough surname gender (…ва/…на → feminine)."""
    parts = full_name.split()
    surname = (parts[0] if parts else "").lower()
    if surname.endswith(("ова", "ева", "ёва", "ина", "ына", "ая", "яя", "ская", "цкая")):
        return feminine
    if surname.endswith("а") and not surname.endswith(("ов", "ев", "ёв", "ин", "ын")):
        if surname.endswith(("ва", "на", "ма", "та")):
            return feminine
    return masculine


def format_assignment_line(*, actor_name: str) -> str:
    """Short line for notification card: «Сабина назначила вам задачу»."""
    verb = actor_past_verb(actor_name, "назначил", "назначила")
    return f"{actor_name} {verb} вам задачу"


def format_assignment_title(
    *,
    actor_name: str,
    recipient_id: str,
    assignees: list[tuple[str, str]],
    task_title: str,
) -> str:
    """Deprecated long form — kept for callers; returns short subject without co-assignees."""
    _ = (recipient_id, assignees, task_title)
    return format_assignment_line(actor_name=actor_name)


def format_completed_line(*, actor_name: str) -> str:
    verb = actor_past_verb(actor_name, "завершил", "завершила")
    return f"{actor_name} {verb} задачу"


def format_completed_title(*, actor_name: str, task_title: str) -> str:
    """Legacy: actor + verb + task. Prefer title=task + body=format_completed_line."""
    _ = task_title
    return format_completed_line(actor_name=actor_name)
