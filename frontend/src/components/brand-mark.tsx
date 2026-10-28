import { cn } from "@/lib/utils";

type BrandProps = {
  className?: string;
  title?: string;
};

/** Official Takt symbol (approved SVG). Aspect ~1055×1226 — height-driven, never stretched. */
export function BrandMark({ className, title = "Takt" }: BrandProps) {
  return (
    // eslint-disable-next-line @next/next/no-img-element -- static brand asset; preserve exact SVG
    <img
      src="/brand/takt-symbol.svg"
      alt={title}
      width={1055}
      height={1226}
      decoding="async"
      className={cn("h-8 w-auto shrink-0 object-contain object-left", className)}
    />
  );
}

/** Full horizontal logo (symbol + wordmark). Swaps to on-dark asset for contrast. */
export function BrandLogo({ className, title = "Takt" }: BrandProps) {
  return (
    <span className={cn("inline-flex items-center", className)}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/brand/takt-logo.svg"
        alt={title}
        width={3256}
        height={1226}
        decoding="async"
        className="h-full w-auto max-h-full object-contain object-left dark:hidden"
      />
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/brand/takt-logo-on-dark.svg"
        alt=""
        aria-hidden
        width={3256}
        height={1226}
        decoding="async"
        className="hidden h-full w-auto max-h-full object-contain object-left dark:block"
      />
    </span>
  );
}

/** Wordmark only (no symbol). */
export function BrandText({ className, title = "Takt" }: BrandProps) {
  return (
    <span className={cn("inline-flex items-center", className)}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/brand/takt-wordmark.svg"
        alt={title}
        width={2158}
        height={745}
        decoding="async"
        className="h-full w-auto max-h-full object-contain object-left dark:hidden"
      />
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/brand/takt-wordmark-on-dark.svg"
        alt=""
        aria-hidden
        width={2158}
        height={745}
        decoding="async"
        className="hidden h-full w-auto max-h-full object-contain object-left dark:block"
      />
    </span>
  );
}

/** Sidebar / chrome: full logo + short product line. */
export function BrandWordmark({ className }: { className?: string }) {
  return (
    <div className={cn("min-w-0", className)}>
      <BrandLogo className="h-7 w-auto max-w-full" title="Takt" />
      <div className="mt-1 text-[11px] font-medium text-muted">Задачи команды</div>
    </div>
  );
}
