import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/medicine_form.dart';

/// Maps each canonical [MedicineForm] to a distinct Material icon and accent
/// colour. Lives in the widget layer so the pure model stays Flutter-free.
/// Every category the "Add Medicine" dropdown offers gets its own glyph, per
/// the requirement that different medicine types show different icons.
abstract final class MedicineFormIcon {
  static final Map<MedicineForm, ({IconData icon, Color color})> _map = {
    MedicineForm.tablet: (
      icon: Icons.medication,
      color: const Color(0xFF2563EB),
    ),
    MedicineForm.capsule: (
      icon: Icons.local_pharmacy,
      color: const Color(0xFF2563EB),
    ),
    MedicineForm.syrup: (
      icon: Icons.local_drink,
      color: const Color(0xFF2563EB),
    ),
    MedicineForm.suspension: (
      icon: Icons.opacity,
      color: const Color(0xFF2563EB),
    ),
    MedicineForm.suppository: (icon: Icons.wc, color: const Color(0xFF2563EB)),
    MedicineForm.injection: (
      icon: Icons.vaccines,
      color: const Color(0xFF2563EB),
    ),
    MedicineForm.ointment: (
      icon: Icons.healing,
      color: const Color(0xFF2563EB),
    ),
    MedicineForm.cream: (icon: Icons.spa, color: const Color(0xFF2563EB)),
    MedicineForm.gel: (icon: Icons.water, color: const Color(0xFF2563EB)),
    MedicineForm.drop: (icon: Icons.visibility, color: const Color(0xFF2563EB)),
    MedicineForm.inhaler: (icon: Icons.air, color: const Color(0xFF2563EB)),
    MedicineForm.saline: (icon: Icons.science, color: const Color(0xFF2563EB)),
    MedicineForm.spray: (icon: Icons.sanitizer, color: const Color(0xFF2563EB)),
    MedicineForm.powder: (icon: Icons.terrain, color: const Color(0xFF2563EB)),
    MedicineForm.lotion: (icon: Icons.soap, color: const Color(0xFF2563EB)),
    MedicineForm.other: (
      icon: Icons.medical_services_outlined,
      color: const Color(0xFF2563EB),
    ),
  };

  static ({IconData icon, Color color}) _entry(MedicineForm form) =>
      _map[form] ?? _map[MedicineForm.other]!;

  static IconData of(MedicineForm form) => _entry(form).icon;

  static Color colorOf(MedicineForm form) => _entry(form).color;
}

class MedicineFormGlyph extends StatelessWidget {
  const MedicineFormGlyph({super.key, required this.form, this.size = 48});

  final MedicineForm form;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = MedicineFormIcon.colorOf(form);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(size * .28),
      ),
      alignment: Alignment.center,
      child: SizedBox.square(
        dimension: size * .62,
        child: CustomPaint(
          painter: _MedicineFormPainter(form: form, accent: accent),
          child:
              form == MedicineForm.syrup ||
                  form == MedicineForm.tablet ||
                  form == MedicineForm.capsule ||
                  form == MedicineForm.suppository
              ? null
              : Icon(
                  MedicineFormIcon.of(form),
                  size: size * .52,
                  color: accent,
                ),
        ),
      ),
    );
  }
}

class _MedicineFormPainter extends CustomPainter {
  const _MedicineFormPainter({required this.form, required this.accent});

  final MedicineForm form;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    switch (form) {
      case MedicineForm.tablet:
        _paintTablet(canvas, size);
        break;
      case MedicineForm.capsule:
        _paintCapsule(canvas, size);
        break;
      case MedicineForm.syrup:
        _paintBottle(canvas, size);
        break;
      case MedicineForm.suppository:
        _paintSuppository(canvas, size);
        break;
      default:
        break;
    }
  }

  void _paintTablet(Canvas canvas, Size size) {
    final bounds = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * .78,
      height: size.height * .78,
    );
    canvas.drawCircle(
      bounds.center,
      bounds.width / 2,
      Paint()..color = accent.withValues(alpha: .18),
    );
    canvas.drawCircle(
      bounds.center,
      bounds.width / 2,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(bounds.left + bounds.width * .18, bounds.center.dy),
      Offset(bounds.right - bounds.width * .18, bounds.center.dy),
      Paint()
        ..color = accent
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintCapsule(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .9,
      height: size.height * .43,
    );
    final capsule = RRect.fromRectAndRadius(rect, Radius.circular(rect.height));
    canvas.drawRRect(capsule, Paint()..color = accent);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(rect.left, rect.top - 1, 0, rect.bottom + 1));
    canvas.drawRRect(capsule, Paint()..color = accent.withValues(alpha: .35));
    canvas.restore();
    canvas.drawRRect(
      capsule,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(0, rect.top + 2),
      Offset(0, rect.bottom - 2),
      Paint()
        ..color = Colors.white.withValues(alpha: .9)
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  void _paintBottle(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * .36, h * .12)
      ..lineTo(w * .64, h * .12)
      ..lineTo(w * .64, h * .31)
      ..lineTo(w * .76, h * .40)
      ..quadraticBezierTo(w * .82, h * .45, w * .82, h * .53)
      ..lineTo(w * .82, h * .83)
      ..quadraticBezierTo(w * .82, h * .91, w * .74, h * .91)
      ..lineTo(w * .26, h * .91)
      ..quadraticBezierTo(w * .18, h * .91, w * .18, h * .83)
      ..lineTo(w * .18, h * .53)
      ..quadraticBezierTo(w * .18, h * .45, w * .24, h * .40)
      ..lineTo(w * .36, h * .31)
      ..close();
    canvas.drawPath(path, Paint()..color = accent.withValues(alpha: .18));
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      Offset(w * .2, h * .61),
      Offset(w * .8, h * .61),
      Paint()
        ..color = accent
        ..strokeWidth = 1.6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * .32, h * .05, w * .68, h * .16),
        const Radius.circular(2),
      ),
      Paint()..color = accent,
    );
  }

  void _paintSuppository(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * .5, h * .08)
      ..quadraticBezierTo(w * .57, h * .3, w * .74, h * .52)
      ..quadraticBezierTo(w * .91, h * .76, w * .68, h * .9)
      ..quadraticBezierTo(w * .5, h, w * .32, h * .9)
      ..quadraticBezierTo(w * .09, h * .76, w * .26, h * .52)
      ..quadraticBezierTo(w * .43, h * .3, w * .5, h * .08)
      ..close();
    canvas.drawPath(path, Paint()..color = accent.withValues(alpha: .2));
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_MedicineFormPainter oldDelegate) =>
      form != oldDelegate.form || accent != oldDelegate.accent;
}
