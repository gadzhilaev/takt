import io
from datetime import UTC, datetime
from typing import Any

import xlsxwriter

PRIORITY_RU = {"low": "Низкий", "medium": "Средний", "high": "Высокий", "urgent": "Срочный"}


def _fmt_date(dt: datetime | None) -> str:
    if not dt:
        return ""
    if dt.tzinfo:
        dt = dt.astimezone(UTC)
    return dt.strftime("%d.%m.%Y")


def build_report_workbook(
    team_name: str,
    period_label: str,
    summary: dict[str, Any],
    tasks: list[dict[str, Any]],
    by_user: list[dict[str, Any]],
    history: list[dict[str, Any]],
) -> bytes:
    output = io.BytesIO()
    wb = xlsxwriter.Workbook(output, {"in_memory": True, "strings_to_urls": False})
    brand = "#4f46e5"
    header_fmt = wb.add_format(
        {
            "bold": True,
            "font_name": "Calibri",
            "font_size": 11,
            "font_color": "white",
            "bg_color": brand,
            "border": 1,
            "align": "center",
            "valign": "vcenter",
        }
    )
    cell_fmt = wb.add_format(
        {"font_name": "Calibri", "font_size": 10, "border": 1, "text_wrap": True}
    )
    alt_fmt = wb.add_format(
        {"font_name": "Calibri", "font_size": 10, "border": 1, "bg_color": "#f8fafc", "text_wrap": True}
    )
    title_fmt = wb.add_format({"bold": True, "font_size": 16, "font_name": "Calibri", "font_color": brand})
    metric_fmt = wb.add_format(
        {"bold": True, "font_size": 14, "font_name": "Calibri", "align": "center", "border": 1}
    )

    ws = wb.add_worksheet("Сводка")
    ws.write(0, 0, team_name, title_fmt)
    ws.write(1, 0, f"Период: {period_label}")
    ws.write(2, 0, f"Сформирован: {_fmt_date(datetime.now(UTC))}")
    metrics = [
        ("Создано", summary.get("created", 0)),
        ("Закрыто", summary.get("closed", 0)),
        ("В работе", summary.get("in_progress", 0)),
        ("Просрочено", summary.get("overdue", 0)),
        ("Среднее время (дн.)", summary.get("avg_days", 0)),
    ]
    for i, (label, val) in enumerate(metrics):
        ws.write(4, i * 2, label, header_fmt)
        ws.write(5, i * 2, val, metric_fmt)
    if summary.get("by_status"):
        chart = wb.add_chart({"type": "pie"})
        chart.add_series(
            {
                "categories": ["Сводка", 8, 0, 8 + len(summary["by_status"]) - 1, 0],
                "values": ["Сводка", 8, 1, 8 + len(summary["by_status"]) - 1, 1],
            }
        )
        row = 8
        ws.write(row - 1, 0, "Статус", header_fmt)
        ws.write(row - 1, 1, "Кол-во", header_fmt)
        for name, cnt in summary["by_status"]:
            ws.write(row, 0, name)
            ws.write(row, 1, cnt)
            row += 1
        ws.insert_chart("H4", chart)

    wt = wb.add_worksheet("Задачи")
    wt.set_landscape()
    wt.repeat_rows(0, 0)
    wt.freeze_panes(1, 0)
    headers = [
        "ID",
        "Название",
        "Статус",
        "Приоритет",
        "Исполнители",
        "Автор",
        "Создано",
        "Срок",
        "Закрыто",
        "Метки",
    ]
    for col, h in enumerate(headers):
        wt.write(0, col, h, header_fmt)
    for r, t in enumerate(tasks, start=1):
        fmt = alt_fmt if r % 2 == 0 else cell_fmt
        overdue = t.get("overdue") and wb.add_format(
            {"font_name": "Calibri", "font_size": 10, "border": 1, "font_color": "red", "text_wrap": True}
        )
        row_fmt = overdue or fmt
        wt.write(r, 0, str(t.get("id", "")), row_fmt)
        wt.write(r, 1, t.get("title", ""), row_fmt)
        wt.write(r, 2, t.get("status", ""), row_fmt)
        wt.write(r, 3, PRIORITY_RU.get(t.get("priority", ""), t.get("priority", "")), row_fmt)
        wt.write(r, 4, t.get("assignees", ""), row_fmt)
        wt.write(r, 5, t.get("author", ""), row_fmt)
        wt.write(r, 6, _fmt_date(t.get("created_at")), row_fmt)
        wt.write(r, 7, _fmt_date(t.get("due_date")), row_fmt)
        wt.write(r, 8, _fmt_date(t.get("closed_at")), row_fmt)
        wt.write(r, 9, t.get("labels", ""), row_fmt)
    wt.autofilter(0, 0, max(len(tasks), 1), len(headers) - 1)
    wt.set_column(0, 0, 12)
    wt.set_column(1, 1, 40)
    wt.set_column(2, 9, 14)

    wu = wb.add_worksheet("По сотрудникам")
    uheaders = ["Сотрудник", "Назначено", "Закрыто", "В работе", "Просрочено", "% в срок"]
    for col, h in enumerate(uheaders):
        wu.write(0, col, h, header_fmt)
    for r, u in enumerate(by_user, start=1):
        fmt = alt_fmt if r % 2 == 0 else cell_fmt
        wu.write(r, 0, u.get("name", ""), fmt)
        wu.write(r, 1, u.get("assigned", 0), fmt)
        wu.write(r, 2, u.get("closed", 0), fmt)
        wu.write(r, 3, u.get("in_progress", 0), fmt)
        wu.write(r, 4, u.get("overdue", 0), fmt)
        wu.write(r, 5, u.get("on_time_pct", 0), fmt)
    total_row = len(by_user) + 1
    wu.write(total_row, 0, "Итого", header_fmt)
    for c in range(1, 5):
        col_letter = chr(ord("A") + c)
        wu.write_formula(
            total_row,
            c,
            f"=SUM({col_letter}2:{col_letter}{total_row})",
            cell_fmt,
        )

    wh = wb.add_worksheet("История")
    hheaders = ["Дата", "Задача", "Пользователь", "Действие", "Поле", "Было", "Стало"]
    for col, h in enumerate(hheaders):
        wh.write(0, col, h, header_fmt)
    for r, h in enumerate(history, start=1):
        fmt = alt_fmt if r % 2 == 0 else cell_fmt
        wh.write(r, 0, _fmt_date(h.get("created_at")), fmt)
        wh.write(r, 1, h.get("task_title", ""), fmt)
        wh.write(r, 2, h.get("user_name", ""), fmt)
        wh.write(r, 3, h.get("action", ""), fmt)
        wh.write(r, 4, h.get("field", "") or "", fmt)
        wh.write(r, 5, h.get("old_value", "") or "", fmt)
        wh.write(r, 6, h.get("new_value", "") or "", fmt)

    wb.close()
    return output.getvalue()
