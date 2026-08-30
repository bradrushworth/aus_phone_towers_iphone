/// Pure helper for the user-visible message shown after a user-initiated
/// "Restore purchases" tap completes. Kept separate from [PurchaseHelper] so
/// it can be unit tested without touching the `InAppPurchase` platform channel.
String restoreOutcomeMessage({required bool isSubscribed}) {
  return isSubscribed
      ? 'Purchases restored — you are ad-free.'
      : 'Restore complete. No ad-free purchase was found for this store account.';
}
