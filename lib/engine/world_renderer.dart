import 'dart:math';
import 'dart:ui';

import 'package:flame/sprite.dart';
import 'package:flame_wolfenstein/game.dart';

class WorldRenderer {
  List<Strip> strips = [];
  FlameWolfenstein gameRef;

  WorldRenderer(this.gameRef);

  void init() {
    for (var i = 0; i < gameRef.viewport.x; i += FlameWolfenstein.stripWidth) {
      strips.add(Strip(i)..reset());
    }
  }

  void reset() {
    strips.forEach((s) => s.reset());
  }

  void render(Canvas canvas) {
    strips.forEach((s) => s.drawStrip(canvas));
  }

  void updateStrip({
    required int stripIdx,
    required double dist,
    required double rayAngle,
    required int wallType,
    required double textureX,
  }) {
    final strip = strips[stripIdx];

    final lookDist = sqrt(dist) * cos(gameRef.player.rotation - rayAngle);
    final height = gameRef.viewDist / lookDist;
    final width = height * FlameWolfenstein.stripWidth;

    final top = (gameRef.size.y - height) / 2;

    var texX = textureX * width;

    if (texX > width - FlameWolfenstein.stripWidth) {
      texX = width - FlameWolfenstein.stripWidth;
    }

    final texture = gameRef.textures.getSprite(0, wallType - 1);

    strip.updateContainer(
      top: top,
      height: height,
      texture: texture,
      textureX: texX,
    );
  }
}

class Strip {
  int i;

  Rect? container;
  Sprite? texture;
  Rect? textureRect;

  Strip(this.i);

  void reset() {
    container = Rect.fromLTWH(
      (i * FlameWolfenstein.stripWidth).toDouble(),
      0,
      FlameWolfenstein.stripWidth.toDouble() * 2,
      0,
    );
  }

  void updateContainer({
    required double top,
    required double height,
    required Sprite texture,
    required double textureX,
  }) {
    container = Rect.fromLTWH(
      (i * FlameWolfenstein.stripWidth).toDouble(),
      top,
      FlameWolfenstein.stripWidth.toDouble() * 2,
      height,
    );

    this.texture = texture;
    textureRect = Rect.fromLTWH(
      (i * FlameWolfenstein.stripWidth).toDouble() - textureX,
      top,
      height * 2,
      height,
    );
  }

  void drawStrip(Canvas canvas) {
    if (texture != null && container != null && textureRect != null) {
      canvas.save();
      canvas.clipRect(container!);
      texture!.renderRect(canvas, textureRect!);
      canvas.restore();
    }
  }
}
