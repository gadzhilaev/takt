"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AppShell } from "@/components/app-shell";
import { SplashScreen } from "@/components/splash-screen";
import { api } from "@/lib/api";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [bootError, setBootError] = useState<string | null>(null);
  const me = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: { must_change_password: boolean } }>("/api/v1/auth/me"),
    retry: false,
  });
  const projects = useQuery({
    queryKey: ["projects"],
    queryFn: () => api<{ items: unknown[] }>("/api/v1/projects"),
    enabled: !!me.data && !me.isError,
    retry: 1,
  });

  useEffect(() => {
    if (me.isError) {
      const next = typeof window !== "undefined" ? window.location.pathname + window.location.search : "/app/projects";
      router.replace(`/login?next=${encodeURIComponent(next)}`);
    }
    if (me.data?.user.must_change_password) router.replace("/change-password");
  }, [me.isError, me.data, router]);

  useEffect(() => {
    if (projects.isError) setBootError((projects.error as Error)?.message || "Не удалось загрузить проекты");
    else setBootError(null);
  }, [projects.isError, projects.error]);

  const ready = !!me.data && !me.isError && (projects.isSuccess || projects.isError);

  if (me.isLoading || (me.data && projects.isLoading && !projects.isFetched)) {
    return <SplashScreen />;
  }

  if (me.isError) {
    return <SplashScreen />;
  }

  if (!ready) {
    return <SplashScreen />;
  }

  if (bootError && !projects.data) {
    return (
      <SplashScreen
        error={bootError}
        onRetry={() => {
          setBootError(null);
          projects.refetch();
        }}
      />
    );
  }

  return <AppShell>{children}</AppShell>;
}
