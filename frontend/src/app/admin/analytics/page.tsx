"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/** Аналитика перенесена на вкладку «Обзор». */
export default function AdminAnalyticsRedirectPage() {
  const router = useRouter();
  useEffect(() => {
    router.replace("/admin");
  }, [router]);
  return <p className="text-sm text-muted">Переход к обзору…</p>;
}
