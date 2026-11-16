/** Ответ `GET /api/v1/users/me/delete-preview`. */
export type DeletePlanAction = "delete" | "transfer" | "leave";

export type DeletePlanProject = {
  id: string;
  name: string;
  action: DeletePlanAction;
  new_admin: { id: string; name: string } | null;
  summary?: string;
};

export type DeletePreview = {
  can_delete: boolean;
  blocked: { code: string; message: string } | null;
  projects: DeletePlanProject[];
};

export const DELETE_PREVIEW_PATH = "/api/v1/users/me/delete-preview";

/** Строки «что произойдёт с проектами»: сначала удаление и передача прав, потом выход. */
export function deletePreviewLines(preview: DeletePreview | null | undefined): string[] {
  if (!preview) return [];
  const order: Record<DeletePlanAction, number> = { delete: 0, transfer: 1, leave: 2 };
  return [...preview.projects]
    .sort((a, b) => order[a.action] - order[b.action] || a.name.localeCompare(b.name, "ru"))
    .map((p) => {
      if (p.action === "delete") return `Проект «${p.name}» будет удалён.`;
      if (p.action === "transfer" && p.new_admin) {
        return `Права администратора в проекте «${p.name}» перейдут к ${p.new_admin.name}.`;
      }
      return `Вы выйдете из проекта «${p.name}», данные команды сохранятся.`;
    });
}
