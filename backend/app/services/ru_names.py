"""Pragmatic Russian name helpers for notification copy (dative / verb gender)."""


def _dative_word(word: str) -> str:
    w = word.strip()
    if not w:
        return w
    lower = w.lower()
    # Feminine surnames / names ending in -ова/-ева/-ина/-ая
    for suf, repl in (
        ("ова", "овой"),
        ("ева", "евой"),
        ("ёва", "ёвой"),
        ("ина", "иной"),
        ("ына", "ыной"),
        ("ая", "ой"),
        ("яя", "ей"),
    ):
        if lower.endswith(suf) and len(w) > len(suf) + 1:
            return w[: -len(suf)] + repl
    # Masculine surnames -ов/-ев/-ин
    for suf in ("ов", "ев", "ёв", "ин", "ын"):
        if lower.endswith(suf) and len(w) > len(suf) + 1:
            return w + "у"
    # First names ending in -а/-я (Сабина, Карина, Джамиля)
    if lower.endswith("а") and not lower.endswith(("га", "ка", "ха", "ша", "ща")):
        return w[:-1] + "е"
    if lower.endswith("я") and not lower.endswith("ия"):
        return w[:-1] + "е"
    if lower.endswith("ия"):
        return w[:-1] + "и"
    # Consonant-ending masculine (Алибек, Рахман, Магомед)
    if lower[-1] not in "аеёиоуыэюяь":
        return w + "у"
    return w


def dative_name(full_name: str) -> str:
    return " ".join(_dative_word(p) for p in full_name.split() if p)


def actor_past_verb(full_name: str, masculine: str, feminine: str) -> str:
    """Pick past-tense verb by rough surname gender (…ва/…на → feminine)."""
    parts = full_name.split()
    surname = (parts[0] if parts else "").lower()
    if surname.endswith(("ова", "ева", "ёва", "ина", "ына", "ая", "яя", "ская", "цкая")):
        return feminine
    if surname.endswith("а") and not surname.endswith(("ов", "ев", "ёв", "ин", "ын")):
        # e.g. Велиева already handled; lone -а surnames
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
    """assignees: list of (user_id, name). Recipient sees «вам» for self."""
    verb = actor_past_verb(actor_name, "назначил", "назначила")
    others = [dative_name(name) for uid, name in assignees if uid != recipient_id]
    quoted = f"«{task_title}»"
    if not others:
        return f"{actor_name} {verb} вам задачу {quoted}"
    if len(others) == 1:
        return f"{actor_name} {verb} вам и {others[0]} задачу {quoted}"
    head = ", ".join(others[:-1])
    return f"{actor_name} {verb} вам, {head} и {others[-1]} задачу {quoted}"


def format_completed_title(*, actor_name: str, task_title: str) -> str:
    verb = actor_past_verb(actor_name, "завершил", "завершила")
    return f"{actor_name} {verb} задачу «{task_title}»"
