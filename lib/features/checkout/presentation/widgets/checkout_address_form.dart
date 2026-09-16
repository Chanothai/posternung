import 'package:flutter/material.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/shipping_address.dart';

/// The 7-field shipping-address form (SCR-07 AC-1) — one page, no
/// progress indicator (`ADR-0035` D4 Amendment 1). Client-side `maxLength`
/// mirrors `ShippingAddressInput` in `docs/api/openapi.yaml` exactly
/// (120/20/‒/80/80/80/10) so a 422 from exceeding one is not reachable
/// through this UI at all; `invalidFields` still exists for the case the
/// backend rejects something this client's own validation missed.
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.checkoutFormSectionTitle,
            style: AppTextStyles.authCardHeading,
          ),
          const SizedBox(height: AppSpacing.md),
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
    );
  }
}

OutlineInputBorder _outlineBorder(bool highlighted) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadius.xs),
  borderSide: BorderSide(
    color: highlighted ? AppColors.accentRed : AppColors.borderMuted,
  ),
);

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.inputLabel),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLength: maxLength,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: AppTextStyles.inputText,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            counterText: '',
            // Material 3's `InputDecorator` never falls back to `border:`
            // when it has a Material 3 theme (it replaces the side with the
            // theme's `activeIndicatorBorder` instead) — every state used by
            // this field must be set explicitly or the red-highlight case
            // never renders.
            enabledBorder: _outlineBorder(highlighted),
            focusedBorder: _outlineBorder(highlighted),
            disabledBorder: _outlineBorder(highlighted),
            errorBorder: _outlineBorder(true),
            focusedErrorBorder: _outlineBorder(true),
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
