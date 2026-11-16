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
        <p className="mt-2 text-[14px] text-muted">Актуально на 16 ноября 2026 г.</p>

        <div className="prose-takt mt-8 space-y-7 text-[15px] leading-relaxed text-foreground/90">
          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">1. Кто мы</h2>
            <p>
              Сервис Takt (сайт taktapp.ru и мобильное приложение) помогает командам вести проекты и
              задачи. Оператор сервиса обрабатывает только те данные, которые нужны для работы
              аккаунта, проектов и задач.
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
              <li>имя и email;</li>
              <li>
                идентификатор аккаунта Takt, а также идентификаторы Apple ID, VK ID или Яндекс ID,
                если вы входите через них;
              </li>
              <li>аватар и фотографии, которые вы прикладываете к задачам;</li>
              <li>
                проекты, задачи и комментарии: названия, описания, сроки, срочность, исполнители и
                история изменений;
              </li>
              <li>файлы, которые вы прикладываете к задачам;</li>
              <li>push-токен устройства, если вы разрешили уведомления;</li>
              <li>технические данные: IP-адрес, user-agent, журналы ошибок, токены сессии.</li>
            </ul>
          </section>

          <section className="space-y-2">
            <h2 className="text-[17px] font-semibold tracking-tight">3. Для чего нужны данные</h2>
            <ul className="list-disc space-y-1.5 pl-5">
              <li>создание аккаунта, вход и восстановление доступа;</li>
              <li>работа проектов, задач, комментариев, вложений, приглашений и уведомлений;</li>
              <li>безопасность: сессии, защита от CSRF и злоупотреблений;</li>
              <li>разбор ошибок по техническим журналам, чтобы сервис работал стабильно.</li>
            </ul>
            <p>
              Все эти данные используются только для работы сервиса. Мы не отслеживаем вас в
              приложениях и на сайтах других компаний, не показываем рекламу, не передаём данные
              рекламным сетям и брокерам данных и не продаём их.
            </p>
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
              Для доставки push-уведомлений push-токен устройства передаётся Google (Firebase Cloud
              Messaging) и Apple (Apple Push Notification service).
            </p>
            <p>
              При входе через Apple, VK или Яндекс соответствующие провайдеры обрабатывают данные
              по своим политикам. Takt получает только то, что нужно для входа и профиля:
              идентификатор, email и имя.
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
              <li>
                удалить аккаунт в профиле (web и мобильное приложение) или на странице{" "}
                <Link href="/account-delete" className="text-[var(--accent)] underline-offset-2 hover:underline">
                  /account-delete
                </Link>
                ; также можно написать на support@taktapp.ru.
              </li>
            </ul>
            <p>При удалении аккаунта:</p>
            <ul className="list-disc space-y-1.5 pl-5">
              <li>
                профиль обезличивается: имя и email заменяются, аватар удаляется, войти в аккаунт
                больше нельзя;
              </li>
              <li>сессии, push-токены, уведомления и привязки Apple / VK ID / Яндекс ID удаляются;</li>
              <li>
                проекты, где кроме вас нет других участников, удаляются целиком вместе с задачами,
                комментариями и файлами;
              </li>
              <li>
                если вы были единственным администратором общего проекта, права администратора
                переходят к участнику, который вступил в проект раньше остальных;
              </li>
              <li>
                задачи, комментарии и файлы в общих проектах остаются у команды, автором
                показывается «Удалённый аккаунт».
              </li>
            </ul>
            <p>Перед удалением сайт и приложение показывают, что произойдёт с каждым вашим проектом.</p>
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
