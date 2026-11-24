"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo } from "react";
import {
  AlertCircle,
  Archive,
  Check,
  CheckCircle2,
  CircleDashed,
  Clock3,
  FolderKanban,
  ListTodo,
  ShieldCheck,
  UsersRound,
} from "lucide-react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { DataTable, type DataTableColumn } from "@/components/admin/data-table";

type Member = {
  user_id: string;
  name: string;
  email: string;
  role: string;
  joined_at?: string | null;
  digest_subscribed: boolean;
};

type ProjectCard = {
  id: string;
  name: string;
  description?: string | null;
  color?: string;
  icon?: string;
  is_default: boolean;
  member_count: number;
  owner?: { id: string; name: string; email: string } | null;
  task_count: number;
  task_stats: {
    active: number;
    done: number;
    archived: number;
    overdue: number;
    blocked: number;
    unassigned: number;
  };
  statuses: { id: string; name: string; color: string; is_done: boolean; task_count: number }[];
  settings: {
    auto_urgency_from_due: boolean;
    rhythm: { enabled: boolean; time: string; timezone: string; days: number[] };
    digest: { daily: boolean; weekly: boolean; time: string };
  };
  restricted: boolean;
  restriction_reason?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  is_demo?: boolean;
  is_archived?: boolean;
  members: Member[];
};

const ROLE_LABELS: Record<string, string> = {
  admin: "Администратор",
  member: "Участник",
  viewer: "Наблюдатель",
};
const WEEKDAYS = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];
const safeColor = (value?: string | null, fallback = "#315f72") =>
  value && /^#[0-9a-f]{6}$/i.test(value) ? value : fallback;

function Metric({
  label,
  value,
  hint,
  tone = "default",
  icon: Icon,
}: {
  label: string;
  value: number;
  hint?: string;
  tone?: "default" | "warning" | "danger" | "success";
  icon: typeof UsersRound;
}) {
  const iconClass = {
    default: "bg-[#e8eef1] text-[#315f72]",
    warning: "bg-[#f7f0e0] text-[#9a6700]",
    danger: "bg-[#f8e9e8] text-[#b42318]",
    success: "bg-[#e8f3ec] text-[#2f6b4f]",
  }[tone];
  return (
    <div className="rounded-xl border border-[#dce2e7] bg-white p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[12px] font-medium text-[#667485]">{label}</p>
          <p className="mt-2 text-[1.75rem] font-semibold leading-none tracking-tight tabular-nums text-[#202938]">
            {value.toLocaleString("ru-RU")}
          </p>
          {hint ? <p className="mt-2 text-[11px] text-[#81909d]">{hint}</p> : null}
        </div>
        <span className={`flex size-9 shrink-0 items-center justify-center rounded-lg ${iconClass}`}>
          <Icon size={17} strokeWidth={1.8} aria-hidden />
        </span>
      </div>
    </div>
  );
}

function InfoRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-4 border-b border-[#edf0f2] py-3 last:border-0">
      <span className="text-[12px] text-[#667485]">{label}</span>
      <span className="text-right text-[13px] font-medium text-[#202938]">{children}</span>
    </div>
  );
}

function formatDate(value?: string | null, withTime = false) {
  if (!value) return "—";
  return new Date(value).toLocaleString("ru-RU", {
    day: "numeric",
    month: "short",
    year: "numeric",
    ...(withTime ? { hour: "2-digit", minute: "2-digit" } : {}),
  });
}

export default function AdminProjectDetailPage() {
  const { id } = useParams<{ id: string }>();
  const qc = useQueryClient();
  const { data, isLoading, error } = useQuery({
    queryKey: ["platform-project", id],
    queryFn: () => api<ProjectCard>(`/api/v1/platform/projects/${id}`),
  });

  const restrict = useMutation({
    mutationFn: (reason: string) =>
      api(`/api/v1/platform/projects/${id}/restrict`, { method: "POST", json: { reason } }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["platform-project", id] });
      qc.invalidateQueries({ queryKey: ["platform-projects"] });
    },
  });
  const unrestrict = useMutation({
    mutationFn: () => api(`/api/v1/platform/projects/${id}/unrestrict`, { method: "POST" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["platform-project", id] });
      qc.invalidateQueries({ queryKey: ["platform-projects"] });
    },
  });

  const columns = useMemo<DataTableColumn<Member>[]>(
    () => [
      {
        id: "name",
        label: "Участник",
        width: 190,
        cell: (member) => (
          <Link href={`/admin/users/${member.user_id}`} className="font-semibold text-[#315f72] hover:underline">
            {member.name}
          </Link>
        ),
      },
      { id: "email", label: "Email", width: 220, className: "text-muted", cell: (m) => m.email },
      {
        id: "role",
        label: "Роль",
        width: 140,
        cell: (m) => ROLE_LABELS[m.role] ?? m.role,
      },
      {
        id: "digest",
        label: "Сводка",
        width: 120,
        cell: (m) => (m.digest_subscribed ? "Получает" : "Отключена"),
      },
      {
        id: "joined_at",
        label: "В проекте с",
        width: 150,
        className: "tabular-nums text-muted",
        cell: (m) => formatDate(m.joined_at),
      },
    ],
    []
  );

  if (isLoading) return <p className="text-sm text-muted">Загружаем проект…</p>;
  if (error) return <p className="text-sm text-[var(--danger)]">{(error as Error).message}</p>;
  if (!data) return null;

  const rhythmDays = data.settings.rhythm.days
    .map((day) => WEEKDAYS[day - 1])
    .filter(Boolean)
    .join(" · ");
  const digestCadence = [
    data.settings.digest.daily ? "каждый день" : null,
    data.settings.digest.weekly ? "по пятницам" : null,
  ]
    .filter(Boolean)
    .join(" и ");

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0">
          <Link href="/admin/projects" className="inline-flex items-center gap-1 text-[13px] font-medium text-[#315f72] hover:underline">
            ← Все проекты
          </Link>
          <div className="mt-3 flex items-start gap-3">
            <span
              className="mt-0.5 flex size-11 shrink-0 items-center justify-center rounded-xl"
              style={{ backgroundColor: `${safeColor(data.color)}18`, color: safeColor(data.color) }}
            >
              <FolderKanban size={21} strokeWidth={1.8} aria-hidden />
            </span>
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <h1 className="text-[1.65rem] font-semibold leading-tight tracking-tight text-[#202938]">
                  {data.name}
                </h1>
                {data.is_demo ? <span className="rounded-full bg-[#e8eef1] px-2 py-0.5 text-[11px] font-semibold text-[#315f72]">Демо</span> : null}
                {data.is_archived ? <span className="rounded-full bg-[#f1f3f5] px-2 py-0.5 text-[11px] font-semibold text-[#667485]">Архив</span> : null}
                {data.is_default ? <span className="rounded-full bg-[#f1f3f5] px-2 py-0.5 text-[11px] font-semibold text-[#667485]">По умолчанию</span> : null}
              </div>
              <p className="mt-1 max-w-3xl text-[13px] leading-5 text-[#667485]">
                {data.description || "Описание проекта не задано."}
              </p>
            </div>
          </div>
        </div>
        <div className="flex shrink-0 flex-wrap items-center gap-2">
          {data.restricted ? (
            <>
              <span className="inline-flex items-center gap-1.5 rounded-full bg-[#f8e9e8] px-3 py-1.5 text-[12px] font-semibold text-[#b42318]">
                <AlertCircle size={14} /> Доска ограничена
              </span>
              <Button type="button" size="sm" variant="secondary" disabled={unrestrict.isPending} onClick={() => unrestrict.mutate()}>
                Снять ограничение
              </Button>
            </>
          ) : (
            <Button
              type="button"
              size="sm"
              variant="secondary"
              disabled={restrict.isPending}
              onClick={() => {
                const reason = window.prompt("Причина ограничения проекта");
                if (reason && reason.trim().length >= 3) restrict.mutate(reason.trim());
              }}
            >
              Ограничить доску
            </Button>
          )}
        </div>
      </div>

      {data.restricted && data.restriction_reason ? (
        <div className="flex items-start gap-2 rounded-xl border border-[#f0d6d6] bg-[#fdf6f6] px-4 py-3 text-[13px] text-[#8e2c25]">
          <AlertCircle size={16} className="mt-0.5 shrink-0" />
          <span>{data.restriction_reason}</span>
        </div>
      ) : null}

      <section aria-label="Сводка проекта" className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Metric label="Участники" value={data.member_count} hint="В команде проекта" icon={UsersRound} />
        <Metric label="Активные задачи" value={data.task_stats.active} hint={`${data.task_count} всего, включая архив`} icon={ListTodo} />
        <Metric label="Завершено" value={data.task_stats.done} hint="В незакрытых архивах не учитываются" tone="success" icon={CheckCircle2} />
        <Metric label="Требуют внимания" value={data.task_stats.overdue + data.task_stats.blocked} hint={`${data.task_stats.overdue} просрочено · ${data.task_stats.blocked} застряли`} tone={data.task_stats.overdue + data.task_stats.blocked ? "warning" : "default"} icon={AlertCircle} />
      </section>

      <div className="grid gap-4 xl:grid-cols-[minmax(0,1.35fr)_minmax(19rem,0.85fr)]">
        <section className="min-w-0 rounded-xl border border-[#dce2e7] bg-white p-4 sm:p-5">
          <div className="flex flex-wrap items-end justify-between gap-2">
            <div>
              <h2 className="text-[15px] font-semibold text-[#202938]">Поток задач</h2>
              <p className="mt-1 text-[12px] text-[#667485]">Количество задач по колонкам доски</p>
            </div>
            <span className="text-[12px] tabular-nums text-[#667485]">{data.task_stats.unassigned} без исполнителя</span>
          </div>
          {data.statuses.length ? (
            <div className="mt-5 space-y-4">
              {data.statuses.map((status) => {
                const count = status.task_count;
                const progress = data.task_count ? Math.min(100, (count / data.task_count) * 100) : 0;
                return (
                  <div key={status.id}>
                    <div className="mb-1.5 flex items-center justify-between gap-3 text-[13px]">
                      <span className="flex min-w-0 items-center gap-2 font-medium text-[#303b49]">
                        <span className="size-2.5 shrink-0 rounded-full" style={{ backgroundColor: safeColor(status.color) }} />
                        <span className="truncate">{status.name}</span>
                        {status.is_done ? <Check size={13} className="shrink-0 text-[#2f6b4f]" aria-label="Завершающая колонка" /> : null}
                      </span>
                      <span className="shrink-0 font-semibold tabular-nums text-[#202938]">{count}</span>
                    </div>
                    <div className="h-2 overflow-hidden rounded-full bg-[#edf0f2]">
                      <div className="h-full rounded-full" style={{ width: `${progress}%`, backgroundColor: safeColor(status.color) }} />
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="mt-4 rounded-lg bg-[#f7f8fa] px-4 py-6 text-center text-[13px] text-[#667485]">
              Колонки для проекта не настроены.
            </div>
          )}
          <div className="mt-5 grid grid-cols-2 gap-2 border-t border-[#edf0f2] pt-4 sm:grid-cols-3">
            <p className="flex items-center gap-2 text-[12px] text-[#667485]"><Archive size={14} /> В архиве: <b className="text-[#303b49]">{data.task_stats.archived}</b></p>
            <p className="flex items-center gap-2 text-[12px] text-[#667485]"><CircleDashed size={14} /> Застряли: <b className="text-[#303b49]">{data.task_stats.blocked}</b></p>
            <p className="flex items-center gap-2 text-[12px] text-[#667485]"><Clock3 size={14} /> Просрочены: <b className="text-[#303b49]">{data.task_stats.overdue}</b></p>
          </div>
        </section>

        <section className="rounded-xl border border-[#dce2e7] bg-white p-4 sm:p-5">
          <h2 className="text-[15px] font-semibold text-[#202938]">Настройки проекта</h2>
          <p className="mt-1 text-[12px] text-[#667485]">Текущие параметры доски и уведомлений</p>
          <div className="mt-3">
            <InfoRow label="Ежедневный чек-ин">
              {data.settings.rhythm.enabled ? (
                <span className="inline-flex items-center gap-1.5 text-[#2f6b4f]"><CheckCircle2 size={14} /> {data.settings.rhythm.time}</span>
              ) : "Выключен"}
            </InfoRow>
            {data.settings.rhythm.enabled ? <InfoRow label="Дни и часовой пояс">{rhythmDays || "—"}<br /><span className="text-[11px] font-normal text-[#81909d]">{data.settings.rhythm.timezone}</span></InfoRow> : null}
            <InfoRow label="Сводка руководителю">
              {digestCadence ? `${digestCadence}, ${data.settings.digest.time}` : "Выключена"}
            </InfoRow>
            <InfoRow label="Владелец">
              {data.owner ? (
                <Link href={`/admin/users/${data.owner.id}`} className="text-[#315f72] hover:underline">
                  {data.owner.name}
                </Link>
              ) : "—"}
            </InfoRow>
            <InfoRow label="Авто-срочность">{data.settings.auto_urgency_from_due ? "Включена" : "Выключена"}</InfoRow>
            <InfoRow label="Создан">{formatDate(data.created_at)}</InfoRow>
            <InfoRow label="Обновлён">{formatDate(data.updated_at, true)}</InfoRow>
            <InfoRow label="ID проекта"><span className="font-mono text-[11px]">{data.id}</span></InfoRow>
          </div>
          <div className="mt-4 flex items-start gap-2 rounded-lg bg-[#f4f6f8] px-3 py-2.5 text-[11px] leading-4 text-[#667485]">
            <ShieldCheck size={14} className="mt-0.5 shrink-0 text-[#315f72]" />
            В админке видны только агрегаты и состав команды. Тексты задач и комментарии скрыты.
          </div>
        </section>
      </div>

      <section className="rounded-xl border border-[#dce2e7] bg-white p-4 sm:p-5">
        <div className="mb-3 flex flex-wrap items-end justify-between gap-2">
          <div>
            <h2 className="text-[15px] font-semibold text-[#202938]">Команда проекта</h2>
            <p className="mt-1 text-[12px] text-[#667485]">Роли, участие и настройки получения сводки</p>
          </div>
          <span className="inline-flex items-center gap-1.5 text-[12px] font-medium text-[#667485]"><UsersRound size={14} /> {data.member_count}</span>
        </div>
        <DataTable
          storageKey="takt-admin-project-members-cols"
          columns={columns}
          rows={data.members}
          rowKey={(member) => member.user_id}
          empty="В проекте пока нет участников"
        />
      </section>
    </div>
  );
}
