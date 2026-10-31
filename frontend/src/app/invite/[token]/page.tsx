"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useRef } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { loginWithNext, paths } from "@/lib/paths";
import { setLastProjectId } from "@/lib/last-project";
import { BrandLogo } from "@/components/brand-mark";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";

type InvitePublic = {
  project_id: string;
  project_name: string | null;
  email: string | null;
  status: string;
  invited_by_name: string | null;
  requires_email_match: boolean;
};

export default function InviteAcceptPage() {
  const { token } = useParams<{ token: string }>();
  const router = useRouter();
  const invitePath = paths.invite(token);
  const autoTried = useRef(false);

  const me = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: { id: string; email: string } }>("/api/v1/auth/me"),
    retry: false,
  });

  const invite = useQuery({
    queryKey: ["invite-token", token],
    enabled: !!token,
    queryFn: () => api<InvitePublic>(`/api/v1/invites/token/${token}`),
    retry: false,
  });

  const accept = useMutation({
    mutationFn: () =>
      api<{ ok: boolean; project_id: string }>(`/api/v1/invites/token/${token}/accept`, {
        method: "POST",
      }),
    onSuccess: (res) => {
      setLastProjectId(res.project_id);
      router.replace(paths.project(res.project_id));
    },
  });

  const loggedIn = me.isSuccess && !!me.data?.user;
  const emailMismatch =
    loggedIn &&
    invite.data?.requires_email_match &&
    invite.data.email &&
    me.data!.user.email.toLowerCase() !== invite.data.email.toLowerCase();

  // После входа / регистрации сразу вступаем, без второго клика.
  useEffect(() => {
    if (autoTried.current) return;
    if (!loggedIn || !invite.isSuccess || !invite.data || emailMismatch) return;
    autoTried.current = true;
    accept.mutate();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- однократный auto-accept
  }, [loggedIn, invite.isSuccess, invite.data, emailMismatch]);

  const joining =
    loggedIn && !emailMismatch && !accept.isError && (accept.isPending || accept.isIdle);

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-background p-4">
      <div className="w-full max-w-md space-y-5 rounded-[var(--radius-lg)] border border-hairline bg-[var(--surface)] p-6 shadow-sm">
        <BrandLogo className="h-8" />
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Приглашение в проект</h1>
          <p className="mt-1 text-sm text-muted">Откройте ссылку и вступите в команду.</p>
        </div>

        {invite.isLoading || me.isLoading || joining ? (
          <div className="space-y-2">
            <Skeleton className="h-24 w-full" />
            {joining && <p className="text-center text-sm text-muted">Вступаем в проект…</p>}
          </div>
        ) : invite.isError ? (
          <p className="text-sm text-[var(--danger)]">
            {(invite.error as Error).message || "Приглашение не найдено или уже недействительно"}
          </p>
        ) : (
          <>
            <div className="rounded-[var(--radius)] border border-hairline bg-[var(--surface-2)] px-3 py-3 text-sm">
              <p className="font-medium">{invite.data?.project_name || "Проект"}</p>
              {invite.data?.invited_by_name && (
                <p className="mt-0.5 text-xs text-muted">Пригласил: {invite.data.invited_by_name}</p>
              )}
              {invite.data?.requires_email_match && invite.data.email && (
                <p className="mt-1 text-xs text-muted">Для email: {invite.data.email}</p>
              )}
            </div>

            {!loggedIn ? (
              <div className="space-y-2">
                <Button asChild className="w-full">
                  <Link href={loginWithNext(invitePath)}>Войти и вступить</Link>
                </Button>
                <Button asChild variant="secondary" className="w-full">
                  <Link href={`${paths.register}?next=${encodeURIComponent(invitePath)}`}>
                    Зарегистрироваться
                  </Link>
                </Button>
              </div>
            ) : emailMismatch ? (
              <p className="text-sm text-[var(--danger)]">
                Это приглашение для {invite.data?.email}. Войдите под этим email или попросите новую ссылку.
              </p>
            ) : (
              <div className="space-y-2">
                <Button
                  className="w-full"
                  disabled={accept.isPending}
                  onClick={() => accept.mutate()}
                >
                  {accept.isPending ? "Вступаем…" : "Вступить в проект"}
                </Button>
                {accept.isError && (
                  <p className="text-sm text-[var(--danger)]">{(accept.error as Error).message}</p>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
