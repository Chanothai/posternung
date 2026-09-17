import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../domain/entities/shipping_address.dart';

/// The 7-field shipping-address form (SCR-07 AC-1) — one page, no
/// progress indicator (`ADR-0035` D4 Amendment 1). Client-side `maxLength`
/// mirrors `ShippingAddressInput` in `docs/api/openapi.yaml` exactly
/// (120/20/‒/80/80/80/10) so a 422 from exceeding one is not reachable
/// through this UI at all; `invalidFields` still exists for the case the
/// backend rejects something this client's own validation missed.
///
/// Every field's fill, borders and padding come from
/// `AppTheme.inputDecorationTheme` (SCR-07 B9); the form declares only what
/// differs per field — see [_Field].
class CheckoutAddressForm extends StatelessWidget {
  const CheckoutAddressForm({
    required this.formKey,
    required this.recipientNameController,
    required this.recipientPhoneController,
    required this.addressLineController,
    required this.subDistrictController,
    required this.districtController,
    required this.provinceController,
    required this.postalCodeController,
    required this.invalidFields,
    required this.enabled,
    required this.onPrivacyTap,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController recipientNameController;
  final TextEditingController recipientPhoneController;
  final TextEditingController addressLineController;
  final TextEditingController subDistrictController;
  final TextEditingController districtController;
  final TextEditingController provinceController;
  final TextEditingController postalCodeController;

  /// `details[].field` names from a 422 `OrderException.validationFields`
  /// (ADR-0017 D3 — the corresponding English `.message` is never rendered;
  /// only the fixed [AppStrings.checkoutFormRequiredError] copy is shown).
  final Set<String> invalidFields;

  final bool enabled;
  final VoidCallback onPrivacyTap;

  static ShippingAddress read({
    required TextEditingController recipientName,
    required TextEditingController recipientPhone,
    required TextEditingController addressLine,
    required TextEditingController subDistrict,
    required TextEditingController district,
    required TextEditingController province,
    required TextEditingController postalCode,
  }) => ShippingAddress(
    recipientName: recipientName.text.trim(),
    recipientPhone: recipientPhone.text.trim(),
    addressLine: addressLine.text.trim(),
    subDistrict: subDistrict.text.trim().isEmpty
        ? null
        : subDistrict.text.trim(),
    district: district.text.trim().isEmpty ? null : district.text.trim(),
    province: province.text.trim(),
    postalCode: postalCode.text.trim(),
  );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: AppSectionCard(
        title: AppStrings.checkoutFormSectionTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Field(
              label: AppStrings.checkoutFormRecipientNameLabel,
              controller: recipientNameController,
              maxLength: 120,
              required: true,
              highlighted: invalidFields.contains('recipient_name'),
              enabled: enabled,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              label: AppStrings.checkoutFormRecipientPhoneLabel,
              controller: recipientPhoneController,
              maxLength: 20,
              required: true,
              keyboardType: TextInputType.phone,
              highlighted: invalidFields.contains('recipient_phone'),
              enabled: enabled,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              label: AppStrings.checkoutFormAddressLineLabel,
              controller: addressLineController,
              required: true,
              maxLines: 2,
              highlighted: invalidFields.contains('address_line'),
              enabled: enabled,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              label:
                  '${AppStrings.checkoutFormSubDistrictLabel}'
                  '${AppStrings.checkoutFormOptionalSuffix}',
              controller: subDistrictController,
              maxLength: 80,
              highlighted: invalidFields.contains('sub_district'),
              enabled: enabled,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              label:
                  '${AppStrings.checkoutFormDistrictLabel}'
                  '${AppStrings.checkoutFormOptionalSuffix}',
              controller: districtController,
              maxLength: 80,
              highlighted: invalidFields.contains('district'),
              enabled: enabled,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              label: AppStrings.checkoutFormProvinceLabel,
              controller: provinceController,
              maxLength: 80,
              required: true,
              highlighted: invalidFields.contains('province'),
              enabled: enabled,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              label: AppStrings.checkoutFormPostalCodeLabel,
              controller: postalCodeController,
              maxLength: 10,
              required: true,
              keyboardType: TextInputType.number,
              highlighted: invalidFields.contains('postal_code'),
              enabled: enabled,
            ),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onTap: onPrivacyTap,
              child: Text(
                AppStrings.checkoutPrivacyLinkText,
                style: AppTextStyles.linkBold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One labelled input. Fill, resting/focused/disabled/error borders, content
/// padding and hint style are all the theme's; the only decoration this
/// widget sets is what the theme cannot know per field:
///
/// - `counterText: ''` — `maxLength` would otherwise render a "0/120"
///   counter under every field.
/// - the [highlighted] override — a backend 422 named this field, but there
///   is no `errorText` to show (ADR-0017 D3: the validator prose is never
///   rendered), so the theme's error state never engages on its own. The
///   resting/focused/disabled borders are pointed at the theme's **own**
///   `errorBorder` for that one field; no colour is restated here.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    this.maxLength,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.highlighted = false,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final int? maxLength;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final InputBorder? highlightBorder = highlighted
        ? Theme.of(context).inputDecorationTheme.errorBorder
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.formLabel),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLength: maxLength,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: AppTextStyles.inputTextOnDark,
          decoration: InputDecoration(
            counterText: '',
            // `null` = the theme's value (`InputDecoration.applyDefaults`
            // fills only what is left unset). Material 3 resolves these
            // per-state borders, never the plain `border:` (SCR-02 N-1), so
            // the highlight has to be set on exactly these three.
            enabledBorder: highlightBorder,
            focusedBorder: highlightBorder,
            disabledBorder: highlightBorder,
          ),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return AppStrings.checkoutFormRequiredError;
            }
            return null;
          },
        ),
      ],
    );
  }
}
