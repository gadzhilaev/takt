import { describe, expect, it } from "vitest";
import { deletePreviewLines, type DeletePreview } from "./account-delete";

const preview: DeletePreview = {
  can_delete: true,
  blocked: null,
  projects: [
    { id: "1", name: "Общий", action: "leave", new_admin: null },
    { id: "2", name: "Команда", action: "transfer", new_admin: { id: "u", name: "Иванова Анна" } },
    { id: "3", name: "Личный", action: "delete", new_admin: null },
  ],
};

describe("deletePreviewLines", () => {
  it("описывает последствия по каждому проекту, удаление — первым", () => {
    expect(deletePreviewLines(preview)).toEqual([
      "Проект «Личный» будет удалён.",
      "Права администратора в проекте «Команда» перейдут к Иванова Анна.",
      "Вы выйдете из проекта «Общий», данные команды сохранятся.",
    ]);
  });

  it("пусто без проектов или без ответа", () => {
    expect(deletePreviewLines({ ...preview, projects: [] })).toEqual([]);
    expect(deletePreviewLines(null)).toEqual([]);
  });
});
