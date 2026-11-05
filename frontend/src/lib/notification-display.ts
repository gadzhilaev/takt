import type { NotificationItem } from "@/lib/types";

export function sanitizeNotificationText(text: string | null | undefined) {
  if (!text) return "";
  return text.replace(/\[demo-seed\]\s*/gi, "").replace(/\s+/g, " ").trim();
}

export function notificationKindLabel(kind: string): string {
  switch (kind) {
    case "task_assigned":
    case "assignee_added":
      return "Новая задача";
    case "task_completed":
      return "Задача выполнена";
    case "task_due_soon":
      return "Скоро срок";
    case "task_overdue":
      return "Срок просрочен";
    case "status_changed":
    case "task_moved":
      return "Изменение задачи";
    case "comment":
    case "mention":
      return "Комментарий";
    case "project_invite":
    case "invite":
      return "Приглашение";
    case "leave_request":
      return "Заявка на выход";
    case "leave_approved":
    case "member_removed":
      return "Участник удалён";
    case "leave_rejected":
      return "Заявка отклонена";
    default:
      return "Уведомление";
  }
}

export type NotificationIconName =
  | "invite"
  | "circle-check"
  | "status"
  | "message"
  | "mail"
  | "profile"
  | "notifications"
  | "timer"
  | "alert";

export function notificationIconName(kind: string): NotificationIconName {
  switch (kind) {
    case "task_assigned":
    case "assignee_added":
      return "invite";
    case "task_completed":
      return "circle-check";
    case "task_due_soon":
      return "timer";
    case "task_overdue":
      return "alert";
    case "status_changed":
    case "task_moved":
      return "status";
    case "comment":
    case "mention":
      return "message";
    case "project_invite":
    case "invite":
      return "mail";
    case "leave_request":
    case "member_removed":
    case "leave_approved":
    case "leave_rejected":
      return "profile";
    default:
      return "notifications";
  }
}

export function notificationRelativeTime(iso: string, now = Date.now()): string {
  const dt = new Date(iso);
  if (Number.isNaN(dt.getTime())) return "";
  const diff = now - dt.getTime();
  const min = Math.floor(diff / 60000);
  if (min < 1) return "сейчас";
  if (min < 60) return `${min} мин`;
  const h = Math.floor(min / 60);
  if (h < 24) return `${h} ч`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d} дн.`;
  return dt.toLocaleDateString("ru-RU", { day: "2-digit", month: "2-digit" });
}

export type DateGroupKey = "today" | "yesterday" | "earlier";

export function notificationDateGroup(iso: string, now = new Date()): DateGroupKey {
  const dt = new Date(iso);
  if (Number.isNaN(dt.getTime())) return "earlier";
  const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startDay = new Date(dt.getFullYear(), dt.getMonth(), dt.getDate());
  const dayDiff = Math.round((startToday.getTime() - startDay.getTime()) / 86_400_000);
  if (dayDiff === 0) return "today";
  if (dayDiff === 1) return "yesterday";
  return "earlier";
}

export const DATE_GROUP_LABEL: Record<DateGroupKey, string> = {
  today: "Сегодня",
  yesterday: "Вчера",
  earlier: "Ранее",
};

/** Split body into detail line + optional project line. */
export function parseNotificationBody(body: string | null | undefined): {
  detail: string;
  projectLine: string;
} {
  const raw = (body ?? "").replace(/\[demo-seed\]\s*/gi, "").trim();
  if (!raw) return { detail: "", projectLine: "" };
  const lines = raw
    .split(/\n+/)
    .map((l) => l.trim())
    .filter(Boolean);
  if (lines.length >= 2 && /^Проект\s+/i.test(lines[lines.length - 1])) {
    return { detail: lines.slice(0, -1).join(" "), projectLine: lines[lines.length - 1] };
  }
  const projectInline = lines.find((l) => /^Проект\s+/i.test(l));
  if (projectInline) {
    return {
      detail: lines.filter((l) => l !== projectInline).join(" "),
      projectLine: projectInline,
    };
  }
  return { detail: lines.join(" "), projectLine: "" };
}

export type NotificationCardModel = {
  kindLabel: string;
  subject: string;
  detail: string;
  project: string;
  time: string;
  isRead: boolean;
  icon: NotificationIconName;
};

/** Card fields matching mobile `taktNotificationCardParts`. */
export function notificationCardModel(
  n: NotificationItem & { project_name?: string | null }
): NotificationCardModel {
  const kindLabel = notificationKindLabel(n.kind);
  const cleanTitle = sanitizeNotificationText(n.title);
  const parsed = parseNotificationBody(n.body);
  let detail = parsed.detail;
  if (/открывается по ссылке/i.test(detail)) detail = "";
  const project = parsed.projectLine || (n.project_name ? `Проект ${n.project_name}` : "");

  const quote = cleanTitle.match(/[«"](.+?)[»"]/);
  const assign = cleanTitle.match(/^(.+?)\s+(назначил[аи]?)\b/i);
  const complete = cleanTitle.match(/^(.+?)\s+(завершил[аи]?)\b/i);

  if ((n.kind === "task_assigned" || n.kind === "assignee_added") && assign && quote) {
    return {
      kindLabel,
      subject: quote[1].trim(),
      detail: `${assign[1].trim()} ${assign[2].toLowerCase()} вам задачу`,
      project,
      time: notificationRelativeTime(n.created_at),
      isRead: n.is_read,
      icon: notificationIconName(n.kind),
    };
  }
  if (n.kind === "task_completed" && complete && quote) {
    return {
      kindLabel,
      subject: quote[1].trim(),
      detail: `${complete[1].trim()} ${complete[2].toLowerCase()} задачу`,
      project,
      time: notificationRelativeTime(n.created_at),
      isRead: n.is_read,
      icon: notificationIconName(n.kind),
    };
  }

  return {
    kindLabel,
    subject: cleanTitle || kindLabel,
    detail,
    project,
    time: notificationRelativeTime(n.created_at),
    isRead: n.is_read,
    icon: notificationIconName(n.kind),
  };
}
