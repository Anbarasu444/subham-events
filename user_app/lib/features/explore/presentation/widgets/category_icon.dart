import 'package:flutter/material.dart';

/// Icon per seeded category slug (M11 seed); listing photos come in M28.
IconData categoryIcon(String slug) => switch (slug) {
  'venue' => Icons.location_city_outlined,
  'catering' => Icons.restaurant_outlined,
  'decoration' => Icons.local_florist_outlined,
  'photography' => Icons.photo_camera_outlined,
  'videography' => Icons.videocam_outlined,
  'makeup-mehendi' => Icons.face_retouching_natural_outlined,
  'music-dj' => Icons.music_note_outlined,
  'invitations-printing' => Icons.mail_outline,
  'transport' => Icons.directions_car_outlined,
  'gifts-return-gifts' => Icons.card_giftcard_outlined,
  'priest-rituals' => Icons.temple_hindu_outlined,
  _ => Icons.storefront_outlined,
};
