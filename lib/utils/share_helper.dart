import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/plant.dart';

/// Captures the widget tree under [repaintKey] and shares it.
class ShareHelper {
  ShareHelper._();

  // ── Individual plant share ────────────────────────────────────────────────

  static Future<void> captureAndShare({
    required GlobalKey repaintKey,
    required Plant plant,
    double pixelRatio = 3.0,
  }) async {
    final raw = await _capture(repaintKey, pixelRatio);
    final composited = await _buildPlantCard(raw, plant);
    await _share(composited, '\uD83C\uDF3F ${plant.species}  \u2022  ${plant.rarity.name.toUpperCase()}\n#TinyBreathe');
  }

  // ── Full garden share ─────────────────────────────────────────────────────

  static Future<void> captureGarden({
    required GlobalKey gardenKey,
    double pixelRatio = 2.0,
  }) async {
    final raw = await _capture(gardenKey, pixelRatio);
    await _share(raw, '\uD83C\uDF3F \ub098\ub9cc\uc758 \uc815\uc6d0  \u2022  #TinyBreathe');
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  static Future<ui.Image> _capture(GlobalKey key, double ratio) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('RepaintBoundary not found.');
    return boundary.toImage(pixelRatio: ratio);
  }

  static Future<void> _share(ui.Image img, String text) async {
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('Failed to encode image.');
    final bytes = byteData.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/tiny_breathe_share.png');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
      ),
    );
  }

  // ── Plant Card compositor ─────────────────────────────────────────────────

  static Future<ui.Image> _buildPlantCard(ui.Image source, Plant plant) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final w = source.width.toDouble();
    final h = source.height.toDouble();

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = plant.color.toColor().withValues(alpha: 0.12),
    );
    canvas.drawImage(source, Offset.zero, Paint());

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 5, w - 10, h - 10),
        const Radius.circular(28),
      ),
      Paint()
        ..color = plant.color.toColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    if (plant.rarity == PlantRarity.holographic) {
      final shimmerH = h * 0.10;
      final shimmerY = h * 0.70;
      canvas.drawRect(
        Rect.fromLTWH(0, shimmerY, w, shimmerH),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, shimmerY), Offset(w, shimmerY),
            [
              Colors.purple.withValues(alpha: 0.45),
              Colors.cyan.withValues(alpha: 0.45),
              Colors.pink.withValues(alpha: 0.45),
              Colors.yellow.withValues(alpha: 0.35),
            ],
            [0.0, 0.33, 0.66, 1.0],
          ),
      );
    }

    _drawRarityBadge(canvas, plant, w);
    _drawLabel(canvas, plant, w, h);

    final picture = recorder.endRecording();
    return picture.toImage(source.width, source.height);
  }

  static void _drawRarityBadge(Canvas canvas, Plant plant, double w) {
    final badgeColor = switch (plant.rarity) {
      PlantRarity.holographic => Colors.amber,
      PlantRarity.rare        => Colors.purple,
      PlantRarity.uncommon    => Colors.teal,
      PlantRarity.common      => Colors.grey,
    };
    final fontSize = w * 0.045;
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: fontSize, textAlign: TextAlign.right),
    )
      ..pushStyle(ui.TextStyle(
        color: badgeColor, fontSize: fontSize, fontWeight: FontWeight.w800,
        shadows: const [ui.Shadow(color: Colors.black54, blurRadius: 4)],
      ))
      ..addText('\u2605 ${plant.rarity.name.toUpperCase()}');
    final p = pb.build()..layout(ui.ParagraphConstraints(width: w - 24));
    canvas.drawParagraph(p, const Offset(12, 18));
  }

  static void _drawLabel(Canvas canvas, Plant plant, double w, double h) {
    final fontSize = w * 0.055;
    final dateStr = DateFormat('MMM d, yyyy').format(plant.createdAt);
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: fontSize, textAlign: TextAlign.center),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold,
        shadows: const [ui.Shadow(color: Colors.black87, blurRadius: 6)],
      ))
      ..addText('${plant.species}\n')
      ..pushStyle(ui.TextStyle(color: Colors.white70, fontSize: fontSize * 0.70))
      ..addText(dateStr);
    final p = pb.build()..layout(ui.ParagraphConstraints(width: w - 32));
    canvas.drawParagraph(p, Offset(16, h - p.height - 20));
  }
}
