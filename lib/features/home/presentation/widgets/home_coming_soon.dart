import 'package:flutter/material.dart';

/// Shared placeholder feedback for Home affordances that aren't backed by
/// real data/navigation yet (search, wishlist, cart, "View all", "Load
/// More"...). Matches the copy already used elsewhere in the app
/// (`login_screen.dart`'s forgot-password link).
void showComingSoonSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('ฟีเจอร์นี้กำลังจะมาเร็ว ๆ นี้')),
  );
}
