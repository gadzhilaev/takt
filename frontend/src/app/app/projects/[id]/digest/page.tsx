import { redirect } from "next/navigation";

/** Старый адрес сводки → вкладка «Сводка» в проекте. */
export default function ProjectDigestRedirect({
  params,
  searchParams,
}: {
  params: { id: string };
  searchParams: { period?: string };
}) {
  const period = searchParams.period ? `&period=${encodeURIComponent(searchParams.period)}` : "";
  redirect(`/app/projects/${encodeURIComponent(params.id)}?view=digest${period}`);
}
