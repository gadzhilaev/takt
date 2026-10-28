import { cn } from "@/lib/utils";

type BrandProps = {
  className?: string;
  title?: string;
};

/** Display aspect for full logo (symbol + wordmark). Keep HTML attrs small so a
 *  CSS miss can't blow the layout (SVG viewBox is 3256×1226). */
const LOGO_W = 163;
const LOGO_H = 61;

const SYMBOL_W = 42;
const SYMBOL_H = 49;

const WORD_W = 140;
const WORD_H = 48;

/** Official Takt symbol. Height-driven via className (default h-8). */
export function BrandMark({ className, title = "Takt" }: BrandProps) {
  return (
    // eslint-disable-next-line @next/next/no-img-element -- static brand asset; preserve exact SVG
    <img
      src="/brand/takt-symbol.svg"
      alt={title}
      width={SYMBOL_W}
      height={SYMBOL_H}
      decoding="async"
      className={cn("block h-8 w-auto shrink-0 object-contain object-left", className)}
    />
  );
}

/** Full horizontal logo (symbol + wordmark). Swaps to on-dark asset for contrast. */
export function BrandLogo({ className, title = "Takt" }: BrandProps) {
  const imgClass = cn(
    "block w-auto object-contain object-left",
    className
  );
  return (
    <span className="inline-flex max-w-full items-center leading-none">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/brand/takt-logo.svg"
        alt={title}
        width={LOGO_W}
        height={LOGO_H}
        decoding="async"
        className={cn(imgClass, "dark:hidden")}
      />
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/brand/takt-logo-on-dark.svg"
        alt=""
        aria-hidden
        width={LOGO_W}
        height={LOGO_H}
        decoding="async"
        className={cn(imgClass, "hidden dark:block")}
      />
    </span>
  );
}

/** Wordmark only (no symbol). */
export function BrandText({ className, title = "Takt" }: BrandProps) {
  const imgClass = cn("block w-auto object-contain object-left", className);
  return (
    <span className="inline-flex max-w-full items-center leading-none">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/brand/takt-wordmark.svg"
        alt={title}
        width={WORD_W}
        height={WORD_H}
        decoding="async"
        className={cn(imgClass, "dark:hidden")}
      />
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/brand/takt-wordmark-on-dark.svg"
        alt=""
        aria-hidden
        width={WORD_W}
        height={WORD_H}
        decoding="async"
        className={cn(imgClass, "hidden dark:block")}
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
