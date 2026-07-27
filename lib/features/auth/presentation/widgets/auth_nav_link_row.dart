import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

/// `promptText` + `actionText` tappable link row shared by login and
/// register to navigate to the other screen (e.g. "ยังไม่มีบัญชี? สร้างบัญชีใหม่").
class AuthNavLinkRow extends StatelessWidget {
  const AuthNavLinkRow({
    required this.promptText,
    required this.actionText,
    required this.onTap,
    super.key,
  });

  final String promptText;
  final String actionText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: promptText, style: AppTextStyles.cardSubtitle),
              TextSpan(text: actionText, style: AppTextStyles.linkBold),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
