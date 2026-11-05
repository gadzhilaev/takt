const NEVER_KEY = "takt_push_prompt_never";

export function isPushPromptNever(): boolean {
  if (typeof window === "undefined") return true;
  try {
    return localStorage.getItem(NEVER_KEY) === "1";
  } catch {
    return false;
  }
}

export function setPushPromptNever(): void {
  try {
    localStorage.setItem(NEVER_KEY, "1");
  } catch {
    /* ignore */
  }
}

/** Should we show the soft prompt after a page load? */
export function shouldShowPushPrompt(): boolean {
  if (typeof window === "undefined") return false;
  if (!("Notification" in window)) return false;
  if (isPushPromptNever()) return false;
  // Already decided at OS level — no soft prompt.
  if (Notification.permission !== "default") return false;
  return true;
}
