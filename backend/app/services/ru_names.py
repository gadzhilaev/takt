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


def format_assignment_title(
    *,
    actor_name: str,
    recipient_id: str,
    assignees: list[tuple[str, str]],
    task_title: str,
) -> str:
    """assignees: (user_id, name). Recipient sees «Вам»; others — nominative names."""
    verb = actor_past_verb(actor_name, "назначил", "назначила")
    others = [name for uid, name in assignees if uid != recipient_id]
    quoted = f"«{task_title}»"
    if not others:
        return f"{actor_name} {verb} Вам задачу {quoted}"
    if len(others) == 1:
        return f"{actor_name} {verb} Вам и {others[0]} задачу {quoted}"
    head = ", ".join(others[:-1])
    return f"{actor_name} {verb} Вам, {head} и {others[-1]} задачу {quoted}"


def format_completed_title(*, actor_name: str, task_title: str) -> str:
    verb = actor_past_verb(actor_name, "завершил", "завершила")
    return f"{actor_name} {verb} задачу «{task_title}»"
