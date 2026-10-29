"use client";

import type { LucideIcon, LucideProps } from "lucide-react";
import {
  ArrowLeft,
  ArrowLeftRight,
  Bell,
  Camera,
  Check,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Circle,
  CircleAlert,
  CircleCheck,
  ClipboardList,
  Contrast,
  Copy,
  Ellipsis,
  Eye,
  EyeOff,
  Inbox,
  ListChecks,
  Lock,
  LogOut,
  Mail,
  Menu,
  MessageCircle,
  MessagesSquare,
  Monitor,
  Moon,
  Pencil,
  Plus,
  Search,
  Settings,
  House,
  Sun,
  Trash2,
  User,
  UserPlus,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";

/** Semantic names shared with `shared/icons/manifest.json` and Flutter AppIcon. */
export const APP_ICON_NAMES = [
  "home",
  "my-tasks",
  "profile",
  "back",
  "close",
  "more",
  "add",
  "edit",
  "delete",
  "check",
  "chevron-down",
  "chevron-right",
  "chevron-left",
  "notifications",
  "search",
  "settings",
  "lock",
  "logout",
  "invite",
  "theme",
  "mail",
  "eye",
  "eye-off",
  "menu",
  "camera",
  "copy",
  "monitor",
  "moon",
  "sun",
  "alert",
  "message",
  "status",
  "inbox",
  "circle",
  "circle-check",
  "assignment",
  "forum",
] as const;

export type AppIconName = (typeof APP_ICON_NAMES)[number];

const ICONS: Record<AppIconName, LucideIcon> = {
  home: House,
  "my-tasks": ListChecks,
  profile: User,
  back: ArrowLeft,
  close: X,
  more: Ellipsis,
  add: Plus,
  edit: Pencil,
  delete: Trash2,
  check: Check,
  "chevron-down": ChevronDown,
  "chevron-right": ChevronRight,
  "chevron-left": ChevronLeft,
  notifications: Bell,
  search: Search,
  settings: Settings,
  lock: Lock,
  logout: LogOut,
  invite: UserPlus,
  theme: Contrast,
  mail: Mail,
  eye: Eye,
  "eye-off": EyeOff,
  menu: Menu,
  camera: Camera,
  copy: Copy,
  monitor: Monitor,
  moon: Moon,
  sun: Sun,
  alert: CircleAlert,
  message: MessageCircle,
  status: ArrowLeftRight,
  inbox: Inbox,
  circle: Circle,
  "circle-check": CircleCheck,
  assignment: ClipboardList,
  forum: MessagesSquare,
};

export const APP_ICON_STROKE = 1.75;

export type AppIconSize = 16 | 20 | 24 | number;

type AppIconProps = Omit<LucideProps, "ref" | "size" | "strokeWidth"> & {
  name: AppIconName;
  size?: AppIconSize;
  /** Active / selected — uses currentColor; pass accent via className. */
  active?: boolean;
  strokeWidth?: number;
};

export function AppIcon({
  name,
  size = 20,
  active = false,
  strokeWidth = APP_ICON_STROKE,
  className,
  absoluteStrokeWidth = false,
  ...rest
}: AppIconProps) {
  const Icon = ICONS[name];
  return (
    <Icon
      size={size}
      strokeWidth={strokeWidth}
      absoluteStrokeWidth={absoluteStrokeWidth}
      aria-hidden={rest["aria-label"] ? undefined : true}
      className={cn(active ? "text-[var(--accent)]" : undefined, className)}
      {...rest}
    />
  );
}
