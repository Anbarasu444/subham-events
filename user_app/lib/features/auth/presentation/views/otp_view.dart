import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../controllers/otp_controller.dart';

class OtpView extends GetView<OtpController> {
  const OtpView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Enter code')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'We sent a 6-digit code to ${controller.args.phoneE164}.',
              style: theme.textTheme.bodyLarge,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: Get.back,
                child: const Text('Wrong number? Edit'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller.codeField,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Verification code',
                helperText: 'The code is checked automatically',
                counterText: '',
              ),
              onChanged: controller.onCodeChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            Obx(
              () => AppButton(
                label: 'Verify',
                isBusy: controller.busy.value,
                onPressed: controller.canSubmit ? controller.submit : null,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Obx(() {
              final seconds = controller.secondsLeft.value;
              return TextButton(
                onPressed: seconds == 0 && !controller.busy.value
                    ? controller.resend
                    : null,
                child: Text(
                  seconds == 0 ? 'Resend code' : 'Resend code in ${seconds}s',
                ),
              );
            }),
            Obx(() {
              final error = controller.error.value;
              if (error == null) return const SizedBox.shrink();
              return Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
