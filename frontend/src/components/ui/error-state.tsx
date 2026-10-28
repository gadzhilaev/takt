import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export function ErrorState({
  title = "Не удалось загрузить данные",
  message,
  onRetry,
  className,
}: {
  title?: string;
  message?: string;
  onRetry?: () => void;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center rounded-xl border border-red-200 bg-red-50 px-6 py-12 text-center dark:border-red-900/50 dark:bg-red-950/30",
        className
      )}
      role="alert"
    >
      <h3 className="text-base font-semibold text-red-700 dark:text-red-300">{title}</h3>
      {message && <p className="mt-2 max-w-md text-sm text-red-600/90 dark:text-red-200/80">{message}</p>}
      {onRetry && (
        <Button className="mt-4" variant="secondary" onClick={onRetry}>
          Повторить
        </Button>
      )}
    </div>
  );
}
