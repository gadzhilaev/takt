import Link from "next/link";
import { BrandLogo } from "@/components/brand-mark";
import { AppIcon } from "@/components/ui/app-icon";
import { LandingCheckinDemo } from "@/components/landing/landing-checkin-demo";
import { LandingDigestDemo } from "@/components/landing/landing-digest-demo";
import { LandingAutoMoveDemo, LandingMorningDemo } from "@/components/landing/landing-step-visuals";
import { LandingThemeToggle } from "@/components/landing/landing-theme-toggle";
import { paths } from "@/lib/paths";

const SUPPORT_EMAIL = "support@taktapp.ru";

const STEPS = [
  {
    n: "01",
    title: "Утром — чек-ин за 10 секунд",
    text: "Каждый получает вопрос по своим задачам и отвечает одним нажатием: «Сделал», «В работе» или «Застрял». Без отчётов и созвонов.",
    visual: <LandingMorningDemo />,
  },
  {
    n: "02",
    title: "Задачи двигаются сами",
    text: "Ответ переносит карточку в нужный столбец или помечает её «Застряла» с причиной. История изменений остаётся в задаче — обновлять доску вручную не нужно.",
    visual: <LandingAutoMoveDemo />,
  },
  {
    n: "03",
    title: "В пятницу — сводка руководителю",
    text: "Что сделано, что застряло и где узкое место. Сводка приходит в уведомления администраторам проекта — по пятницам или каждый день.",
    visual: <LandingDigestDemo />,
  },
];

const EDU_CASES = [
  {
    title: "Приёмная кампания",
    text: "Сроки жёсткие, участников много, вопросы повторяются каждый день.",
    tasks: ["Подготовить списки абитуриентов", "Сверить оригиналы аттестатов", "Опубликовать приказ о зачислении"],
  },
  {
    title: "Цифровые сервисы колледжа",
    text: "Сайт, электронный журнал, расписание — мелкие задачи, которые теряются в мессенджерах.",
    tasks: ["Обновить расписание на сайте", "Завести учётные записи первокурсников", "Исправить ошибку в личном кабинете"],
  },
  {
    title: "Методический отдел",
    text: "Документы и согласования, где важно видеть, на каком этапе всё застряло.",
    tasks: ["Согласовать рабочие программы", "Собрать отчёты кафедр", "Подготовить материалы к аттестации"],
  },
];

const IPHONE = [
  {
    icon: "my-tasks" as const,
    title: "Виджет «Чек-ин»",
    text: "Кнопка «Сделал» прямо на экране iPhone (iOS 17) — без открытия приложения. Есть и виджеты для экрана блокировки.",
  },
  {
    icon: "notifications" as const,
    title: "Ответ из push",
    text: "Чек-ин приходит уведомлением с кнопками «Сделал», «В работе» и «Застрял» — ответить можно, не заходя в Takt.",
  },
  {
    icon: "timer" as const,
    title: "Live Activity",
    text: "Прогресс чек-ина на экране блокировки. Включается в профиле, по умолчанию выключена.",
  },
  {
    icon: "message" as const,
    title: "Siri и «Быстрые команды»",
    text: "«Пройти чек-ин», «Мои задачи на сегодня» и «Сводка по проекту» — голосом или одной командой.",
  },
];

const FAQ = [
  {
    q: "Сколько стоит Takt?",
    a: "Takt бесплатный: без подписок, платных тарифов и покупок. Зарегистрироваться может любой человек, проекты и приглашения — бесплатно.",
  },
  {
    q: "Где хранятся данные?",
    a: "На инфраструктуре Takt: хостинг, база данных, доставка почты и push. Оператор сервиса обрабатывает персональные данные в соответствии с законодательством РФ. Подробности:",
    link: { href: "/privacy", label: "Политика конфиденциальности" },
  },
  {
    q: "Чем Takt отличается от обычной доски задач?",
    a: "В обычной доске карточки двигает человек, и она быстро устаревает. В Takt команда отвечает на ежедневный чек-ин, а задачи обновляются по ответам. Дополнительно руководитель получает сводку: что сделано, что застряло и где узкое место.",
  },
  {
    q: "Как удалить аккаунт?",
    a: "В приложении: Профиль → «Удалить аккаунт», или на отдельной странице. Можно и написать на support@taktapp.ru с адреса, привязанного к аккаунту. Страница удаления:",
    link: { href: "/account-delete", label: "/account-delete" },
  },
];

const BTN_PRIMARY =
  "inline-flex h-11 items-center justify-center rounded-full bg-[var(--accent)] px-5 text-[14px] font-semibold text-white hover:brightness-[0.96]";
const BTN_SECONDARY =
  "inline-flex h-11 items-center justify-center rounded-full border border-[var(--border-strong)] bg-[var(--surface)] px-5 text-[14px] font-semibold text-foreground hover:bg-[var(--surface-2)]";

export function LandingPage() {
  // NEXT_PUBLIC_* подставляется при сборке; пусто — кнопку не показываем.
  const appStoreUrl = process.env.NEXT_PUBLIC_APP_STORE_URL?.trim() || "";

  return (
    <div className="takt-landing min-h-screen bg-[var(--background)] text-[var(--foreground)]">
      <header className="sticky top-0 z-40 border-b border-[var(--border)]/80 bg-[var(--background)]/90 backdrop-blur-md">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6">
          <Link href={paths.home} className="inline-flex min-w-0" aria-label="Takt — на главную">
            <BrandLogo className="h-7 w-auto max-w-[9.5rem]" />
          </Link>
          <nav className="hidden items-center gap-6 text-[13px] font-medium text-muted md:flex" aria-label="Разделы">
            <a href="#how" className="hover:text-foreground">
              Как работает
            </a>
            <a href="#education" className="hover:text-foreground">
              Для учебных заведений
            </a>
            <a href="#iphone" className="hover:text-foreground">
              На iPhone
            </a>
            <a href="#faq" className="hover:text-foreground">
              FAQ
            </a>
          </nav>
          <div className="flex items-center gap-1.5 sm:gap-2">
            <LandingThemeToggle />
            <Link
              href={paths.login}
              className="hidden h-9 items-center rounded-full px-3 text-[13px] font-semibold text-foreground hover:bg-[var(--surface-2)] sm:inline-flex"
            >
              Войти
            </Link>
            <Link
              href={paths.register}
              className="inline-flex h-9 items-center whitespace-nowrap rounded-full bg-[var(--accent)] px-3.5 text-[13px] font-semibold text-white hover:brightness-[0.96]"
            >
              Начать
            </Link>
          </div>
        </div>
      </header>

      <main>
        <section className="relative overflow-hidden border-b border-[var(--border)]">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,_rgba(49,95,114,0.10),_transparent_55%)]"
          />
          <div className="relative mx-auto grid max-w-6xl gap-10 px-4 pb-14 pt-12 sm:px-6 sm:pb-20 sm:pt-16 lg:grid-cols-[minmax(0,1.05fr)_minmax(0,0.95fr)] lg:items-center lg:gap-14">
            <div>
              <p className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Takt</p>
              <h1 className="mt-3 max-w-xl text-[2rem] font-semibold leading-[1.15] tracking-tight text-[var(--foreground)] sm:text-[2.75rem]">
                Трекер, который не надо обновлять
              </h1>
              <p className="mt-4 max-w-xl text-[15px] leading-relaxed text-muted sm:text-base">
                Команда за 10 секунд отвечает на ежедневный чек-ин, задачи двигаются сами, а руководитель видит
                сводку: что сделано, что застряло и где узкое место.
              </p>
              <div className="mt-7 flex flex-wrap items-center gap-3">
                <Link href={paths.register} className={BTN_PRIMARY}>
                  Начать
                </Link>
                {appStoreUrl && (
                  <a href={appStoreUrl} target="_blank" rel="noopener noreferrer" className={BTN_SECONDARY}>
                    Скачать для iPhone
                  </a>
                )}
                <Link
                  href={paths.login}
                  className="inline-flex h-11 items-center rounded-full px-3 text-[14px] font-semibold text-muted hover:text-foreground"
                >
                  Войти
                </Link>
              </div>
              <p className="mt-4 text-[13px] text-muted">Для учебных групп и небольших команд</p>
            </div>
            <LandingCheckinDemo className="mx-auto w-full max-w-md lg:max-w-none" />
          </div>
        </section>

        <section id="how" className="scroll-mt-20 border-b border-[var(--border)] bg-[var(--surface)] py-16 sm:py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-6">
            <div className="max-w-2xl">
              <h2 className="text-2xl font-semibold tracking-tight sm:text-[1.75rem]">Как работает Takt</h2>
              <p className="mt-2 text-[15px] leading-relaxed text-muted">
                Три шага, в которых от команды нужен только один ответ в день.
              </p>
            </div>
            <ol className="mt-10 space-y-12 sm:space-y-16">
              {STEPS.map((s, i) => (
                <li key={s.n} className="grid gap-6 lg:grid-cols-2 lg:items-center lg:gap-14">
                  <div className={i % 2 === 1 ? "lg:order-2" : undefined}>
                    <span className="text-[12px] font-semibold tabular-nums tracking-wide text-[var(--accent)]">
                      {s.n}
                    </span>
                    <h3 className="mt-2 text-xl font-semibold tracking-tight">{s.title}</h3>
                    <p className="mt-2 max-w-md text-[14px] leading-relaxed text-muted">{s.text}</p>
                  </div>
                  <div className={i % 2 === 1 ? "lg:order-1" : undefined}>
                    <div className="mx-auto w-full max-w-md lg:max-w-none">{s.visual}</div>
                  </div>
                </li>
              ))}
            </ol>
          </div>
        </section>

        <section id="education" className="scroll-mt-20 border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-6">
            <div className="max-w-2xl">
              <h2 className="text-2xl font-semibold tracking-tight sm:text-[1.75rem]">Для учебных заведений</h2>
              <p className="mt-2 text-[15px] leading-relaxed text-muted">
                Небольшие команды, у которых нет времени на ведение трекера. Примеры задач из рабочих проектов.
              </p>
            </div>
            <ul className="mt-10 grid gap-4 md:grid-cols-3">
              {EDU_CASES.map((c) => (
                <li
                  key={c.title}
                  className="flex flex-col rounded-[var(--radius)] border border-[var(--border)] bg-[var(--surface)] p-5"
                >
                  <h3 className="text-[16px] font-semibold tracking-tight">{c.title}</h3>
                  <p className="mt-1.5 text-[13px] leading-relaxed text-muted">{c.text}</p>
                  <ul className="mt-4 space-y-2 border-t border-[var(--border)] pt-4">
                    {c.tasks.map((t) => (
                      <li key={t} className="flex gap-2 text-[13px] text-[var(--foreground)]">
                        <AppIcon name="circle" size={14} className="mt-0.5 shrink-0 text-[var(--accent)]" />
                        <span>{t}</span>
                      </li>
                    ))}
                  </ul>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section id="iphone" className="scroll-mt-20 border-b border-[var(--border)] bg-[var(--surface)] py-16 sm:py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-6">
            <div className="max-w-2xl">
              <h2 className="text-2xl font-semibold tracking-tight sm:text-[1.75rem]">На iPhone</h2>
              <p className="mt-2 text-[15px] leading-relaxed text-muted">
                Чек-ин не требует открывать приложение: ответить можно с экрана, из уведомления или голосом.
              </p>
            </div>
            <ul className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {IPHONE.map((f) => (
                <li
                  key={f.title}
                  className="rounded-[var(--radius)] border border-[var(--border)] bg-[var(--background)] p-5"
                >
                  <span className="inline-flex h-9 w-9 items-center justify-center rounded-[var(--radius-sm)] bg-[var(--accent-soft)] text-[var(--accent)]">
                    <AppIcon name={f.icon} size={18} />
                  </span>
                  <h3 className="mt-4 text-[15px] font-semibold tracking-tight">{f.title}</h3>
                  <p className="mt-1.5 text-[13px] leading-relaxed text-muted">{f.text}</p>
                </li>
              ))}
            </ul>
            {appStoreUrl && (
              <div className="mt-8">
                <a href={appStoreUrl} target="_blank" rel="noopener noreferrer" className={BTN_SECONDARY}>
                  Скачать для iPhone
                </a>
              </div>
            )}
          </div>
        </section>

        <section id="faq" className="scroll-mt-20 border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto max-w-3xl px-4 sm:px-6">
            <h2 className="text-2xl font-semibold tracking-tight sm:text-[1.75rem]">Частые вопросы</h2>
            <div className="mt-8 divide-y divide-[var(--border)] border-y border-[var(--border)]">
              {FAQ.map((item) => (
                <details key={item.q} className="group py-4">
                  <summary className="cursor-pointer list-none text-[15px] font-semibold tracking-tight marker:content-none [&::-webkit-details-marker]:hidden">
                    <span className="flex items-center justify-between gap-4">
                      {item.q}
                      <AppIcon
                        name="chevron-down"
                        size={18}
                        className="shrink-0 text-muted transition group-open:rotate-180"
                      />
                    </span>
                  </summary>
                  <p className="mt-2 pr-8 text-[14px] leading-relaxed text-muted">
                    {item.a}
                    {"link" in item && item.link && (
                      <>
                        {" "}
                        <Link href={item.link.href} className="font-medium text-[var(--accent)] hover:underline">
                          {item.link.label}
                        </Link>
                      </>
                    )}
                  </p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section className="py-16 sm:py-20">
          <div className="mx-auto max-w-6xl px-4 text-center sm:px-6">
            <h2 className="text-2xl font-semibold tracking-tight sm:text-[1.75rem]">Попробуйте с вашей командой</h2>
            <p className="mx-auto mt-3 max-w-lg text-[15px] text-muted">
              Создайте проект, пригласите коллег и включите ежедневный чек-ин — остальное Takt сделает сам.
            </p>
            <div className="mt-7 flex flex-wrap items-center justify-center gap-3">
              <Link href={paths.register} className={BTN_PRIMARY}>
                Начать
              </Link>
              <Link href={paths.login} className={BTN_SECONDARY}>
                Войти
              </Link>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-[var(--border)] bg-[var(--surface)]">
        <div className="mx-auto flex max-w-6xl flex-col gap-8 px-4 py-10 sm:px-6 md:flex-row md:justify-between">
          <div>
            <BrandLogo className="h-6 w-auto max-w-[8rem]" />
            <p className="mt-3 max-w-xs text-[13px] leading-relaxed text-muted">
              Takt — трекер, который не надо обновлять: чек-ин, задачи и сводка для небольших команд.
            </p>
          </div>
          <div className="grid grid-cols-2 gap-8 text-[13px] sm:grid-cols-3">
            <div>
              <p className="font-semibold text-foreground">Продукт</p>
              <ul className="mt-3 space-y-2 text-muted">
                <li>
                  <a href="#how" className="hover:text-foreground">
                    Как работает
                  </a>
                </li>
                <li>
                  <Link href={paths.register} className="hover:text-foreground">
                    Регистрация
                  </Link>
                </li>
                <li>
                  <Link href={paths.login} className="hover:text-foreground">
                    Вход
                  </Link>
                </li>
              </ul>
            </div>
            <div>
              <p className="font-semibold text-foreground">Контакты</p>
              <ul className="mt-3 space-y-2 text-muted">
                <li>
                  <a href={`mailto:${SUPPORT_EMAIL}`} className="break-all hover:text-foreground">
                    {SUPPORT_EMAIL}
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <p className="font-semibold text-foreground">Документы</p>
              <ul className="mt-3 space-y-2 text-muted">
                <li>
                  <Link href="/terms" className="hover:text-foreground">
                    Пользовательское соглашение
                  </Link>
                </li>
                <li>
                  <Link href="/privacy" className="hover:text-foreground">
                    Политика конфиденциальности
                  </Link>
                </li>
                <li>
                  <Link href="/account-delete" className="hover:text-foreground">
                    Удаление аккаунта
                  </Link>
                </li>
              </ul>
            </div>
          </div>
        </div>
        <div className="border-t border-[var(--border)]">
          <p className="mx-auto max-w-6xl px-4 py-4 text-[12px] text-muted sm:px-6">
            © {new Date().getFullYear()} Takt. Все права защищены.
          </p>
        </div>
      </footer>
    </div>
  );
}
