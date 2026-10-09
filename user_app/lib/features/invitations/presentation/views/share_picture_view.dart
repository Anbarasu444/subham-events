import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

import '../../../../core/platform/external_actions.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../widgets/invitation_card.dart';

/// Draws the invitation as a picture on the phone and shares it with the
/// reply link in the text (M19 answer 2; nothing stored on a server).
class SharePictureView extends StatefulWidget {
  const SharePictureView({super.key, required this.card, required this.link});

  final InvitationCard card;
  final String? link;

  @override
  State<SharePictureView> createState() => _SharePictureViewState();
}

class _SharePictureViewState extends State<SharePictureView> {
  final _boundary = GlobalKey();
  bool _busy = false;

  ExternalActions get _external => Get.isRegistered<ExternalActions>()
      ? Get.find<ExternalActions>()
      : const PlatformExternalActions();

  Future<void> _share(Rect? origin) async {
    setState(() => _busy = true);
    try {
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await _external.shareImage(
        data.buffer.asUint8List(),
        fileName: 'invitation.png',
        text: widget.link == null
            ? 'You’re invited!'
            : 'You’re invited! Please reply here: ${widget.link}',
        origin: origin,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share as picture')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        RepaintBoundary(key: _boundary, child: widget.card),
        const SizedBox(height: AppSpacing.md),
        Builder(
          builder: (buttonContext) => AppButton(
            label: 'Share picture',
            icon: Icons.ios_share,
            isBusy: _busy,
            onPressed: () {
              final box = buttonContext.findRenderObject() as RenderBox?;
              _share(
                box == null ? null : box.localToGlobal(Offset.zero) & box.size,
              );
            },
          ),
        ),
      ],
    ),
  );
}
