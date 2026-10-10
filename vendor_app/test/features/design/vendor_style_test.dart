import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_app/core/assets/app_illustrations.dart';
import 'package:vendor_app/core/theme/app_style.dart';
import 'package:vendor_app/core/theme/app_theme.dart';
import 'package:vendor_app/core/widgets/festive.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('one style file (AC-3)', () {
    test('the theme takes its font and colours from app_style.dart', () {
      final theme = AppTheme.light();
      expect(theme.textTheme.bodyMedium!.fontFamily, AppFonts.body);
      expect(theme.textTheme.headlineSmall!.fontFamily, AppFonts.heading);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
    });

    test('the user\'s vendor gradient is #11998E → #38EF7D', () {
      expect(AppGradients.festive.colors, [
        const Color(0xFF11998E),
        const Color(0xFF38EF7D),
      ]);
    });

    test('white text on brand fills meets WCAG AA (4.5:1)', () {
      for (final c in [
        ...AppGradients.brand.colors,
        ...AppGradients.hero.colors,
      ]) {
        expect(_ratio(AppColors.onGradient, c), greaterThanOrEqualTo(4.5));
      }
      expect(_ratio(AppColors.primary, AppColors.background), greaterThan(4.5));
      expect(_ratio(AppColors.text, AppColors.background), greaterThan(4.5));
      expect(_ratio(AppColors.textMuted, AppColors.surface), greaterThan(4.5));
    });

    test('illustration paths are unique and live in assets/illustrations', () {
      expect(AppIllustrations.all.toSet().length, AppIllustrations.all.length);
      for (final path in AppIllustrations.all) {
        expect(path, startsWith('assets/illustrations/'));
      }
      // Pictures are supplied later by the user; list what is still missing.
      final missing = [
        for (final p in AppIllustrations.all)
          if (!File(p).existsSync()) p,
      ];
      if (missing.isNotEmpty) {
        // ignore: avoid_print
        print('Illustrations not supplied yet: ${missing.length}');
      }
    });

    test('no screen hard-codes colours, fonts or picture paths', () {
      final offenders = <String>[];
      final literal = RegExp(
        r'Color\(0x|fontFamily:\s*[\x27"]|[\x27"]assets/illustrations/',
      );
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.contains('core/theme/') ||
            f.path.endsWith('app_illustrations.dart')) {
          continue;
        }
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (literal.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
        }
      }
      expect(offenders, isEmpty);
    });
  });

  testWidgets('a missing illustration falls back to an icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: Illustration(
              AppIllustrations.menuListings,
              fallback: Icons.list_alt_outlined,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.list_alt_outlined), findsOneWidget);
  });
}
