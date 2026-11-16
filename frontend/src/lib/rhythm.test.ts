import { describe, expect, it } from "vitest";
import {
  answeredCount,
  bannerText,
  buildAnswers,
  initialSelection,
  startProjectId,
  tasksWord,
  timezoneOptions,
  toggleDay,
  type Checkin,
} from "./rhythm";

const item = (id: string, extra: Partial<Checkin["items"][number]> = {}) => ({
  task_id: id,
  title: `Задача ${id}`,
  priority: "medium" as const,
  due_date: null,
  status: null,
  blocked_reason: null,
  answer: null,
  reason: null,
  answered_at: null,
  ...extra,
});

const checkin: Checkin = {
  id: "c1",
  project: { id: "p", name: "Колледж" },
  date: "2026-11-16",
  status: "pending",
  created_at: "",
  answered_at: null,
  items: [item("a"), item("b", { answer: "in_progress" }), item("c")],
};

describe("rhythm helpers", () => {
  it("buildAnswers отправляет только новые ответы и обрезает причину", () => {
    const sel = initialSelection(checkin);
    sel.a = { answer: "done" };
    sel.c = { answer: "blocked", reason: `  ${"x".repeat(300)} ` };
    const out = buildAnswers(checkin, sel);
    expect(out.map((a) => a.task_id)).toEqual(["a", "c"]);
    expect(out[1].reason).toHaveLength(280);
    expect(out[0]).toEqual({ task_id: "a", answer: "done" });
  });

  it("застрял без причины — без поля reason", () => {
    expect(buildAnswers(checkin, { a: { answer: "blocked", reason: "  " } })).toEqual([
      { task_id: "a", answer: "blocked" },
    ]);
  });

  it("счётчик ответов и текст баннера", () => {
    expect(answeredCount(checkin, {})).toBe(1);
    expect(bannerText({ checkins: [checkin], pending: 1 })).toBe("Чек-ин на сегодня · 2 задачи");
    expect(bannerText({ checkins: [{ ...checkin, status: "answered" }], pending: 0 })).toBeNull();
    expect(bannerText(undefined)).toBeNull();
  });

  it("склонение «задача»", () => {
    expect([1, 2, 5, 11, 21, 22, 25].map(tasksWord)).toEqual([
      "задача",
      "задачи",
      "задач",
      "задач",
      "задача",
      "задачи",
      "задач",
    ]);
  });

  it("дни недели: нельзя снять последний", () => {
    expect(toggleDay([1, 2], 2)).toEqual([1]);
    expect(toggleDay([1], 1)).toEqual([1]);
    expect(toggleDay([5, 1], 3)).toEqual([1, 3, 5]);
  });

  it("неизвестный часовой пояс остаётся в списке", () => {
    expect(timezoneOptions("Europe/Berlin").at(-1)?.value).toBe("Europe/Berlin");
    expect(timezoneOptions("Europe/Moscow").some((t) => t.value === "Europe/Berlin")).toBe(false);
  });
});

describe("startProjectId", () => {
  it("кнопка только без активного чек-ина; приоритет — текущий проект", () => {
    const data = { checkins: [], pending: 0, startable_project_ids: ["p1", "p2"] };
    expect(startProjectId(data, "p2")).toBe("p2");
    expect(startProjectId(data, "other")).toBe("p1");
    expect(startProjectId({ ...data, startable_project_ids: [] })).toBeNull();
    expect(startProjectId({ checkins: [checkin], pending: 1, startable_project_ids: ["p1"] })).toBeNull();
    expect(startProjectId(undefined)).toBeNull();
  });
});
