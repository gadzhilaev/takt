"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/** Раздел безопасности убран из навигации; журнал доступен через действия в профилях. */
export default function AdminSecurityRedirectPage() {
  const router = useRouter();
  useEffect(() => {
    router.replace("/admin");
  }, [router]);
  return <p className="text-sm text-muted">Переход к обзору…</p>;
}
