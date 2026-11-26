import Link from "next/link";

export function AuthLegalNotice() {
  return (
    <p className="mt-4 text-center text-[11px] leading-relaxed text-muted">
      Продолжая, вы принимаете{" "}
      <Link href="/terms" className="underline underline-offset-2 hover:text-foreground">
        Пользовательское соглашение
      </Link>{" "}
      и{" "}
      <Link href="/privacy" className="underline underline-offset-2 hover:text-foreground">
        Политику конфиденциальности
      </Link>
      .
    </p>
  );
}
