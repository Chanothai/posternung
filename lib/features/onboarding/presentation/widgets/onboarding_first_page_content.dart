import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

/// Content for onboarding's first page ("Own a Piece of Cinema History").
///
/// Figma: node 6:2, frame "Onboarding - Vintage Hero".
class OnboardingFirstPageContent extends StatelessWidget {
  const OnboardingFirstPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'เป็นเจ้าของชิ้นส่วนหนึ่งของ\n',
                  style: AppTextStyles.heroTitle,
                ),
                TextSpan(
                  text: 'ประวัติศาสตร์ภาพยนตร์',
                  style: AppTextStyles.heroTitleEmphasis,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Text(
              'ค้นพบและสะสมโปสเตอร์ภาพยนตร์ต้นฉบับหายากที่ผ่านการรับรอง '
              'จากยุคที่คุณชื่นชอบ',
              style: AppTextStyles.bodyDescription,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
