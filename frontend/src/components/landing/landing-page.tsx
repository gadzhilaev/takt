import Link from "next/link";
import { BrandLogo } from "@/components/brand-mark";
import { AppIcon } from "@/components/ui/app-icon";
import { LandingKanbanDemo } from "@/components/landing/landing-kanban-demo";
import { LandingThemeToggle } from "@/components/landing/landing-theme-toggle";
import { paths } from "@/lib/paths";

const FEATURES = [
  {
    icon: "inbox" as const,
    title: "Проекты и доски",
    text: "Отдельная Kanban-доска на каждый проект. Четыре понятных столбца с первого дня.",
  },
  {
    icon: "my-tasks" as const,
    title: "Задачи и приоритеты",
    text: "Название, описание, срочность и порядок в столбце. Новая задача встаёт в начало.",
  },
  {
    icon: "invite" as const,
    title: "Исполнители",
    text: "Назначайте одного или нескольких участников. Видно, кто ведёт работу.",
  },
  {
    icon: "notifications" as const,
    title: "Уведомления",
    text: "In-app, браузерный Web Push и push в мобильном приложении — по желанию.",
  },
];

const STEPS = [
  {
    n: "01",
    title: "Создайте проект",
    text: "Получите готовую доску: к выполнению, в работе, на проверке, готово.",
  },
  {
    n: "02",
    title: "Пригласите команду",
    text: "Добавьте участников по email — приглашение появится у них в приложении.",
  },
  {
    n: "03",
    title: "Ведите задачи",
    text: "Перетаскивайте карточки, назначайте исполнителей и следите за срочностью.",
  },
];

const FAQ = [
  {
    q: "Takt — это что?",
    a: "Простой менеджер проектов и задач вокруг Kanban-доски: регистрация, проекты, участники и задачи без лишних отчётов.",
  },
  {
    q: "Нужна ли карта для старта?",
    a: "Нет. Можно зарегистрироваться и сразу создать первый проект.",
  },
  {
    q: "Есть ли мобильное приложение?",
    a: "Да, есть клиент на Flutter для iOS и Android с теми же проектами и доской. Публикация в магазинах — по мере готовности релиза.",
  },
  {
    q: "Как пригласить коллег?",
    a: "Из проекта отправьте приглашение на email. После регистрации или входа человек увидит его в приложении и сможет принять.",
  },
  {
    q: "Где хранятся данные?",
    a: "На вашем рабочем пространстве Takt: аккаунт, проекты и задачи доступны только участникам проекта.",
  },
];

export function LandingPage() {
  return (
    <div className="takt-landing min-h-screen bg-[var(--background)] text-[var(--foreground)]">
      <header className="sticky top-0 z-40 border-b border-[var(--border)]/80 bg-[var(--background)]/90 backdrop-blur-md">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6">
          <Link href={paths.home} className="inline-flex min-w-0" aria-label="Takt — на главную">
            <BrandLogo className="h-7 w-auto max-w-[9.5rem]" />
          </Link>
          <nav className="hidden items-center gap-6 text-[13px] font-medium text-muted md:flex" aria-label="Разделы">
            <a href="#features" className="hover:text-foreground">
              Возможности
            </a>
            <a href="#how" className="hover:text-foreground">
              Как работает
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
              className="inline-flex h-9 items-center rounded-full bg-[var(--accent)] px-3.5 text-[13px] font-semibold text-white hover:brightness-[0.96]"
            >
              Начать бесплатно
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
          <div className="relative mx-auto grid max-w-6xl gap-10 px-4 pb-14 pt-12 sm:px-6 sm:pb-20 sm:pt-16 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)] lg:items-center lg:gap-12">
            <div>
              <p className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[var(--accent)]">Takt</p>
              <h1 className="mt-3 max-w-xl text-[2rem] font-semibold leading-[1.15] tracking-tight text-[var(--foreground)] sm:text-[2.75rem]">
                Работа команды.
                <br />
                В одном ритме.
              </h1>
              <p className="mt-4 max-w-md text-[15px] leading-relaxed text-muted sm:text-base">
                Простой Kanban для проектов и задач: доска, исполнители, приоритеты и уведомления — без
                перегруженных дашбордов.
              </p>
              <div className="mt-7 flex flex-wrap items-center gap-3">
                <Link
                  href={paths.register}
                  className="inline-flex h-11 items-center justify-center rounded-full bg-[var(--accent)] px-5 text-[14px] font-semibold text-white hover:brightness-[0.96]"
                >
                  Начать бесплатно
                </Link>
                <Link
                  href={paths.login}
                  className="inline-flex h-11 items-center justify-center rounded-full border border-[var(--border-strong)] bg-[var(--surface)] px-5 text-[14px] font-semibold text-foreground hover:bg-[var(--surface-2)]"
                >
                  Войти
                </Link>
              </div>
            </div>
            <LandingKanbanDemo className="lg:translate-y-2" />
          </div>
        </section>

        <section id="features" className="scroll-mt-20 border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-6">
            <div className="max-w-2xl">
              <h2 className="text-2xl font-semibold tracking-tight sm:text-[1.75rem]">Возможности без лишнего</h2>
              <p className="mt-2 text-[15px] leading-relaxed text-muted">
                Только то, что нужно, чтобы вести работу команды на доске.
              </p>
            </div>
            <ul className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {FEATURES.map((f) => (
                <li key={f.title} className="rounded-[var(--radius)] border border-[var(--border)] bg-[var(--surface)] p-5">
                  <span className="inline-flex h-9 w-9 items-center justify-center rounded-[var(--radius-sm)] bg-[var(--accent-soft)] text-[var(--accent)]">
                    <AppIcon name={f.icon} size={18} />
                  </span>
                  <h3 className="mt-4 text-[15px] font-semibold tracking-tight">{f.title}</h3>
                  <p className="mt-1.5 text-[13px] leading-relaxed text-muted">{f.text}</p>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section id="how" className="scroll-mt-20 border-b border-[var(--border)] bg-[var(--surface)] py-16 sm:py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-6">
            <div className="max-w-2xl">
              <h2 className="text-2xl font-semibold tracking-tight sm:text-[1.75rem]">Как работает Takt</h2>
              <p className="mt-2 text-[15px] leading-relaxed text-muted">Три шага от регистрации до общей доски.</p>
            </div>
            <ol className="mt-10 grid gap-6 md:grid-cols-3">
              {STEPS.map((s) => (
                <li key={s.n} className="relative border-t border-[var(--border)] pt-5">
                  <span className="text-[12px] font-semibold tabular-nums tracking-wide text-[var(--accent)]">{s.n}</span>
                  <h3 className="mt-2 text-[16px] font-semibold tracking-tight">{s.title}</h3>
                  <p className="mt-1.5 text-[13px] leading-relaxed text-muted">{s.text}</p>
                </li>
              ))}
            </ol>
          </div>
        </section>

        <section className="border-b border-[var(--border)] py-16 sm:py-20">
          <div className="mx-auto grid max-w-6xl gap-10 px-4 sm:px-6 lg:grid-cols-2 lg:items-center">
            <div>
              <h2 className="text-2xl font-semibold tracking-tight sm:text-[1.75rem]">Web и мобильное приложение</h2>
              <p className="mt-3 max-w-md text-[15px] leading-relaxed text-muted">
                Одна учётная запись для браузера и приложения на телефоне. Доска, проекты и уведомления — там, где вам
                удобнее работать.
              </p>
              <ul className="mt-6 space-y-3 text-[14px] text-foreground">
                <li className="flex gap-2.5">
                  <AppIcon name="check" size={18} className="mt-0.5 shrink-0 text-[var(--accent)]" />
                  <span>Веб-приложение на taktapp.ru — полный Kanban и приглашения.</span>
                </li>
                <li className="flex gap-2.5">
                  <AppIcon name="check" size={18} className="mt-0.5 shrink-0 text-[var(--accent)]" />
                  <span>Мобильный клиент Flutter с той же доской и виджетами.</span>
                </li>
                <li className="flex gap-2.5">
                  <AppIcon name="check" size={18} className="mt-0.5 shrink-0 text-[var(--accent)]" />
                  <span>Опциональные push-уведомления на устройствах команды.</span>
                </li>
              </ul>
            </div>
            <div className="rounded-[var(--radius)] border border-[var(--border)] bg-[var(--surface)] p-6 sm:p-8">
              <p className="text-[12px] font-semibold uppercase tracking-[0.12em] text-muted">Платформы</p>
              <div className="mt-5 grid gap-4 sm:grid-cols-2">
                <div className="rounded-[var(--radius-sm)] border border-[var(--border)] bg-[var(--surface-2)] p-4">
                  <AppIcon name="monitor" size={20} className="text-[var(--accent)]" />
                  <p className="mt-3 text-[15px] font-semibold">Web</p>
                  <p className="mt-1 text-[13px] text-muted">Работает в современном браузере, один домен для входа и доски.</p>
                </div>
                <div className="rounded-[var(--radius-sm)] border border-[var(--border)] bg-[var(--surface-2)] p-4">
                  <AppIcon name="profile" size={20} className="text-[var(--accent)]" />
                  <p className="mt-3 text-[15px] font-semibold">iOS и Android</p>
                  <p className="mt-1 text-[13px] text-muted">
                    Нативное приложение в разработке и тестировании. Ссылки на магазины появятся после публикации.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section id="faq" className="scroll-mt-20 border-b border-[var(--border)] bg-[var(--surface)] py-16 sm:py-20">
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
                  <p className="mt-2 pr-8 text-[14px] leading-relaxed text-muted">{item.a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section className="py-16 sm:py-20">
          <div className="mx-auto max-w-6xl px-4 text-center sm:px-6">
            <h2 className="text-2xl font-semibold tracking-tight sm:text-[1.75rem]">Соберите команду в одном ритме</h2>
            <p className="mx-auto mt-3 max-w-lg text-[15px] text-muted">
              Создайте аккаунт, откройте первую доску и пригласите участников.
            </p>
            <div className="mt-7 flex flex-wrap items-center justify-center gap-3">
              <Link
                href={paths.register}
                className="inline-flex h-11 items-center rounded-full bg-[var(--accent)] px-5 text-[14px] font-semibold text-white hover:brightness-[0.96]"
              >
                Начать бесплатно
              </Link>
              <Link
                href={paths.login}
                className="inline-flex h-11 items-center rounded-full border border-[var(--border-strong)] bg-[var(--surface)] px-5 text-[14px] font-semibold hover:bg-[var(--surface-2)]"
              >
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
              Takt — менеджер проектов и задач вокруг Kanban-доски.
            </p>
          </div>
          <div className="grid grid-cols-2 gap-8 text-[13px] sm:grid-cols-3">
            <div>
              <p className="font-semibold text-foreground">Продукт</p>
              <ul className="mt-3 space-y-2 text-muted">
                <li>
                  <a href="#features" className="hover:text-foreground">
                    Возможности
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
                  <a href="mailto:support@taktapp.ru" className="hover:text-foreground">
                    support@taktapp.ru
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <p className="font-semibold text-foreground">Документы</p>
              <ul className="mt-3 space-y-2 text-muted">
                <li>
                  <Link href="/privacy" className="hover:text-foreground">
                    Политика конфиденциальности
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
