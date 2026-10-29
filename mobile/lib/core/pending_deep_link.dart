/// Holds a widget/push deep link across auth bootstrap without coupling router ↔ app.
class PendingDeepLink {
  PendingDeepLink._();

  static String? value;
  static void Function()? onChanged;

  static void set(String? raw) {
    value = raw;
    onChanged?.call();
  }

  static void clear() {
    value = null;
  }
}
