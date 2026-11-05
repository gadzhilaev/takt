"use client";

import { BrandLogo } from "@/components/brand-mark";
import { cn } from "@/lib/utils";

/** Matches mobile SplashPage: gradient, logo, tagline, accent spinner. */
export function SplashScreen({
  error,
  onRetry,
}: {
  error?: string | null;
  onRetry?: () => void;
}) {
  return (
    <div
      className={cn(
        "flex min-h-screen flex-col items-center justify-center px-4",
        "bg-[linear-gradient(135deg,#F4F7F8_0%,#E4EEF1_45%,#D7E6EA_100%)]",
        "dark:bg-[linear-gradient(135deg,#12151A_0%,#1A2830_45%,#152028_100%)]"
      )}
    >
      <BrandLogo className="h-11 w-auto max-w-[14rem]" title="Takt" />
      <p className="mt-3.5 text-sm font-medium tracking-wide text-[color-mix(in_srgb,var(--accent)_85%,transparent)] dark:text-[#9BB0BC]">
        Задачи команды
      </p>
      {error ? (
        <div className="mt-8 max-w-sm text-center">
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
          className="mt-9 h-[22px] w-[22px] animate-spin rounded-full border-2 border-[var(--accent)] border-t-transparent dark:border-[#6A9AAB] dark:border-t-transparent"
          role="status"
          aria-label="Загрузка"
        />
      )}
    </div>
  );
}
