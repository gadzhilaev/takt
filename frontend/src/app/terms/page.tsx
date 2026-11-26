import Link from "next/link";
import type { Metadata } from "next";
import { BrandLogo } from "@/components/brand-mark";

export const metadata: Metadata = {
  title: "Пользовательское соглашение · Takt",
  description: "Условия использования сервиса Takt",
};

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-[var(--bg)] text-foreground">
      <header className="border-b border-hairline">
        <div className="mx-auto flex max-w-3xl items-center justify-between px-4 py-4 sm:px-6">
          <Link href="/" className="inline-flex items-center gap-2" aria-label="Takt">
            <BrandLogo className="h-7 w-auto" />
          </Link>
          <Link href="/login" className="text-[13px] text-muted hover:text-foreground">
            Вход
          </Link>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-4 py-10 sm:px-6 sm:py-14">
        <h1 className="text-[28px] font-semibold tracking-tight sm:text-[32px]">
          Пользовательское соглашение
        </h1>
        <p className="mt-2 text-[14px] text-muted">Актуально на 26 ноября 2026 г.</p>

        <div className="prose-takt mt-8 space-y-7 text-[15px] leading-relaxed text-foreground/90">
          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">1. О сервисе</h2>
            <p>
              Takt — сайт taktapp.ru и мобильное приложение для совместной работы над проектами,
              задачами и комментариями. Используя сервис или создавая аккаунт, вы принимаете условия
              этого соглашения.
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">2. Вход через VK ID</h2>
            <p>
              Регистрация и вход через VK ID осуществляются согласно{" "}
              <a
                className="text-[var(--accent)] underline-offset-2 hover:underline"
                href="https://id.vk.com/terms"
                target="_blank"
                rel="noreferrer"
              >
                Пользовательскому соглашению Экосистемы VK
              </a>{" "}
              и{" "}
              <a
                className="text-[var(--accent)] underline-offset-2 hover:underline"
                href="https://id.vk.com/privacy"
                target="_blank"
                rel="noreferrer"
              >
                Политике конфиденциальности Экосистемы VK
              </a>
              . Используя вход через VK ID, пользователь подтверждает, что ознакомлен с этими
              документами.
            </p>
            <p>
              VK ID передаёт Takt только сведения, необходимые для создания аккаунта и входа,
              согласно выбранным разрешениям. Подробнее о данных и их обработке — в{" "}
              <Link className="text-[var(--accent)] underline-offset-2 hover:underline" href="/privacy">
                Политике конфиденциальности Takt
              </Link>
              .
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">3. Аккаунт и материалы</h2>
            <p>
              Вы отвечаете за сохранность доступа к своему аккаунту и за материалы, которые
              размещаете в Takt. Не размещайте материалы, на которые у вас нет прав, и не используйте
              сервис для нарушения закона, доступа к чужим данным или вмешательства в работу сервиса.
            </p>
            <p>
              Владелец проекта управляет доступом участников к его задачам, комментариям и файлам.
              Не добавляйте в проекты персональные данные, которые не нужны для совместной работы.
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">4. Персональные данные</h2>
            <p>
              Порядок обработки персональных данных описан в{" "}
              <Link className="text-[var(--accent)] underline-offset-2 hover:underline" href="/privacy">
                Политике конфиденциальности Takt
              </Link>
              . Вы можете удалить аккаунт на странице{" "}
              <Link className="text-[var(--accent)] underline-offset-2 hover:underline" href="/account-delete">
                удаления аккаунта
              </Link>
              .
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">5. Работа сервиса и связь</h2>
            <p>
              Мы поддерживаем работу Takt и можем обновлять его функции. В работе могут возникать
              перерывы для обслуживания или по причинам, не зависящим от сервиса.
            </p>
            <p>
              По вопросам соглашения и работы сервиса напишите на{" "}
              <a
                className="text-[var(--accent)] underline-offset-2 hover:underline"
                href="mailto:support@taktapp.ru"
              >
                support@taktapp.ru
              </a>
              .
            </p>
          </section>
        </div>
      </main>

      <footer className="border-t border-hairline">
        <p className="mx-auto max-w-3xl px-4 py-5 text-[12px] text-muted sm:px-6">© 2026 Takt</p>
      </footer>
    </div>
  );
}
