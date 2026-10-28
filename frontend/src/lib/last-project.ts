const KEY = "takt:lastProjectId";

export function getLastProjectId(): string | null {
  if (typeof window === "undefined") return null;
  try {
    return localStorage.getItem(KEY);
  } catch {
    return null;
  }
}

export function setLastProjectId(id: string) {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(KEY, id);
  } catch {
    /* ignore quota / private mode */
  }
}
