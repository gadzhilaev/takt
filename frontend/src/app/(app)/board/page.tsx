"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { api } from "@/lib/api";
import type { Project } from "@/lib/types";
import { Skeleton } from "@/components/ui/skeleton";

export default function BoardRedirectPage() {
  const router = useRouter();
  const { data } = useQuery({
    queryKey: ["projects"],
    queryFn: () => api<{ items: Project[] }>("/api/v1/projects"),
  });

  useEffect(() => {
    const items = data?.items ?? [];
    if (!items.length) return;
    const def = items.find((p) => p.is_default) ?? items[0];
    router.replace(`/projects/${def.id}`);
  }, [data, router]);

  return <Skeleton className="h-40 w-full" />;
}
