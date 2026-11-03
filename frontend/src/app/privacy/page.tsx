import Link from "next/link";
import type { Metadata } from "next";
import { BrandLogo } from "@/components/brand-mark";

export const metadata: Metadata = {
  title: "Политика конфиденциальности · Takt",
  description: "Как Takt обрабатывает персональные данные пользователей",
};

export default function PrivacyPage() {
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
          Политика конфиденциальности
        </h1>
        <p className="mt-2 text-[14px] text-muted">Актуально на 2 ноября 2026 г.</p>

        <div className="prose-takt mt-8 space-y-7 text-[15px] leading-relaxed text-foreground/90">
          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">1. Кто мы</h2>
            <p>
              Сервис Takt (сайт taktapp.ru и мобильное приложение) помогает командам вести проекты и
              задачи на Kanban-доске. Оператор сервиса обрабатывает данные, необходимые для работы
              аккаунта и доски.
            </p>
            <p>
              По вопросам персональных данных:{" "}
              <a className="text-[var(--accent)] underline-offset-2 hover:underline" href="mailto:support@taktapp.ru">
                support@taktapp.ru
              </a>
              .
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">2. Какие данные обрабатываем</h2>
            <ul className="list-disc space-y-1.5 pl-5 text-foreground/90">
              <li>данные аккаунта: имя, email, аватар, способ входа (пароль и/или OAuth);</li>
              <li>данные проектов и задач: названия, описания, статусы, исполнители, сроки;</li>
              <li>технические данные: IP, user-agent, журналы ошибок, токены сессии;</li>
              <li>токены push-уведомлений на устройстве (если вы их разрешили);</li>
              <li>данные провайдеров входа (Apple, VK ID, Яндекс ID), если вы их привязали.</li>
            </ul>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">3. Для чего нужны данные</h2>
            <ul className="list-disc space-y-1.5 pl-5">
              <li>создание и вход в аккаунт, восстановление доступа;</li>
              <li>работа доски, приглашений и уведомлений;</li>
              <li>безопасность (сессии, CSRF, защита от злоупотреблений);</li>
              <li>улучшение стабильности сервиса по обезличенным техническим сигналам.</li>
            </ul>
            <p>Мы не продаём персональные данные и не используем их для сторонней рекламы.</p>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">4. Правовые основания</h2>
            <p>
              Обработка ведётся для исполнения пользовательского соглашения (оказание сервиса), а
              также при необходимости для соблюдения требований законодательства РФ о персональных
              данных.
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">5. Передача и хранение</h2>
            <p>
              Данные хранятся на инфраструктуре, необходимой для работы Takt (хостинг, база данных,
              доставка почты и push). Передача третьим лицам ограничена такими подрядчиками и
              случаями, когда это требует закон.
            </p>
            <p>
              При входе через Apple, VK или Яндекс соответствующие провайдеры обрабатывают данные
              по своим политикам. Takt получает только то, что нужно для входа и профиля (например,
              идентификатор и email).
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">6. Сроки хранения</h2>
            <p>
              Данные аккаунта и проектов хранятся, пока аккаунт активен. После удаления аккаунта
              данные удаляются или обезличиваются в разумный срок, кроме сведений, которые закон
              требует хранить дольше.
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">7. Ваши права</h2>
            <p>Вы можете:</p>
            <ul className="list-disc space-y-1.5 pl-5">
              <li>запросить доступ к своим данным и их уточнение через профиль или поддержку;</li>
              <li>отвязать способы входа и сменить пароль в разделе «Вход и безопасность»;</li>
              <li>отозвать согласие на push в настройках устройства;</li>
              <li>запросить удаление аккаунта, написав на support@taktapp.ru.</li>
            </ul>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">8. Cookies и сессии</h2>
            <p>
              На сайте используются cookies для входа (JWT access/refresh) и защиты CSRF. Они нужны
              для работы кабинета, а не для рекламного трекинга.
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">9. Изменения</h2>
            <p>
              Мы можем обновлять эту политику. Актуальная версия всегда доступна по адресу{" "}
              <Link href="/privacy" className="text-[var(--accent)] underline-offset-2 hover:underline">
                taktapp.ru/privacy
              </Link>
              .
            </p>
          </section>
        </div>
      </main>

      <footer className="border-t border-hairline">
        <p className="mx-auto max-w-3xl px-4 py-5 text-[12px] text-muted sm:px-6">
          © {new Date().getFullYear()} Takt
        </p>
      </footer>
    </div>
  );
}
