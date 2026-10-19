/// Same join window as server `call.CanJoin`.
bool canJoin(DateTime now, String status, DateTime starts) {
  if (status != 'scheduled') {
    return false;
  }
  final open = starts.subtract(const Duration(minutes: 10));
  return !now.isBefore(open);
}
