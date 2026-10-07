import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/sign_in_controller.dart';

class SignInView extends GetView<SignInController> {
  const SignInView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Plan your events', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sign in to save events, contact vendors and track bookings.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            Obx(
              () => AppButton(
                label: 'Continue with Google',
                icon: Icons.account_circle_outlined,
                variant: AppButtonVariant.secondary,
                isBusy: controller.busy.value == 'google',
                onPressed: controller.busy.value == null
                    ? controller.signInWithGoogle
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text('or', style: theme.textTheme.bodySmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Obx(
              () => AppTextField(
                label: 'Mobile number',
                hintText: '98765 43210',
                prefixText: '+91 ',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                maxLength: 16,
                errorText: controller.phoneError,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                onChanged: (v) => controller.phone.value = v,
                onSubmitted: (_) {
                  if (controller.busy.value == null && controller.phoneValid) {
                    controller.continueWithPhone();
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'We’ll send a 6-digit code by SMS. Standard rates may apply. '
              'Start with + to use a number from another country.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => AppButton(
                label: 'Send code',
                isBusy: controller.busy.value == 'phone',
                onPressed:
                    controller.busy.value == null && controller.phoneValid
                    ? controller.continueWithPhone
                    : null,
              ),
            ),
            Obx(() {
              final error = controller.error.value;
              if (error == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
