String ledgerLabel(String reason) {
  switch (reason) {
    case 'starter_grant':
      return 'Starter credits';
    case 'session_hold':
      return 'Session booked';
    case 'session_release':
      return 'Session cancelled';
    case 'teach_completed':
      return 'Taught a session';
    default:
      return reason;
  }
}
