"use client";

import { BrandLogo } from "@/components/brand-mark";
import { cn } from "@/lib/utils";

export function SplashScreen({
  error,
  onRetry,
}: {
  error?: string | null;
  onRetry?: () => void;
}) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background px-4">
      <BrandLogo className="h-10 w-auto max-w-[12rem]" title="Takt" />
      {error ? (
        <div className="mt-6 max-w-sm text-center">
          <p className="text-sm text-[var(--danger)]">{error}</p>
          {onRetry && (
            <button
              type="button"
              className="mt-3 text-sm font-semibold text-[var(--accent)]"
              onClick={onRetry}
            >
              Повторить
            </button>
          )}
        </div>
      ) : (
        <div
          className={cn(
            "mt-8 h-1.5 w-28 overflow-hidden rounded-full bg-[var(--surface-2)]",
            "motion-safe:relative"
          )}
          role="status"
          aria-label="Загрузка"
        >
          <div className="h-full w-1/2 rounded-full bg-[var(--accent)] motion-safe:animate-pulse motion-reduce:w-full" />
        </div>
      )}
    </div>
  );
}
