"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { AppShell } from "@/components/app-shell";
import { api } from "@/lib/api";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { data, isError, isLoading } = useQuery({
    queryKey: ["me"],
    queryFn: () => api<{ user: { must_change_password: boolean } }>("/api/v1/auth/me"),
    retry: false,
  });

  useEffect(() => {
    if (isError) router.replace("/login");
    if (data?.user.must_change_password) router.replace("/change-password");
  }, [isError, data, router]);

  if (isLoading || isError) {
    return (
      <div className="flex min-h-screen items-center justify-center text-slate-500">Загрузка…</div>
    );
  }

  return <AppShell>{children}</AppShell>;
}
