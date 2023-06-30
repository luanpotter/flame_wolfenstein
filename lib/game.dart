import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/palette.dart';
import 'package:flame/sprite.dart';
import 'package:flame_wolfenstein/engine/player.dart';
import 'package:flame_wolfenstein/engine/utils.dart';
import 'package:flame_wolfenstein/engine/world_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FlameWolfenstein extends Game with KeyboardEvents {
  static final Paint _whitePaint = BasicPalette.white.paint();

  late List<List<int>> map;
  List<Vector2> castedRays = [];
  int? pictureOnSight;
  late Vector2 mapSize;
  double miniMapScale = 8;

  late WorldRenderer worldRenderer;

  late Player player;

  late SpriteSheet textures;

  late Vector2 viewport;
  static const stripWidth = 2;

  static const fov = 60 * pi / 180;
  static const fovHalf = fov / 2;

  late int numRays;
  late double viewDist;

  final linePaint = Paint()
    ..color = const Color(0xFFFF0000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  final miniMapPlayerPaint = Paint()..color = const Color(0xFF0000FF);

  final miniMapRayPaint = Paint()
    ..color = const Color(0xFF00FF00)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;

  final floorPaint = Paint()..color = const Color(0xFFac3000);

  late Rect floorRect;

  final ceilingPaint = Paint()..color = const Color(0xFF523c23);

  late Rect ceilingRect;

  final TextPaint textPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFFFFF),
    ),
  );

  @override
  Future<void> onLoad() async {
    viewport = Vector2(size.x / 2, 320);
    floorRect = Rect.fromLTWH(0, size.y / 2, size.x, size.y / 2);
    ceilingRect = Rect.fromLTWH(0, 0, size.x, size.y / 2);

    final image = await images.load('walls.png');
    textures = SpriteSheet.fromColumnsAndRows(
      image: image,
      columns: 4,
      rows: 1,
    );

    miniMapScale = (size.y * 0.01).ceilToDouble();

    numRays = (viewport.x / stripWidth).ceil();
    viewDist = (viewport.y / 2) / tan(fov / 2);

    map = [
      [1, 2, 1, 1, 1, 2, 1, 1],
      [1, 0, 0, 1, 0, 0, 0, 2],
      [1, 0, 0, 2, 0, 1, 0, 1],
      [2, 0, 0, 1, 2, 1, 0, 1],
      [1, 0, 0, 1, 0, 0, 0, 1],
      [1, 0, 0, 2, 0, 1, 1, 2],
      [1, 0, 0, 1, 0, 0, 0, 1],
      [2, 0, 0, 1, 0, 0, 0, 1],
      [2, 0, 0, 2, 0, 0, 0, 1],
      [1, 0, 0, 1, 0, 1, 0, 1],
      [1, 0, 0, 0, 0, 1, 0, 2],
      [1, 0, 0, 0, 0, 1, 0, 1],
      [1, 2, 1, 1, 1, 1, 2, 1],
    ];

    mapSize = Vector2(
      map[0].length.toDouble(),
      map.length.toDouble(),
    );

    player = Player(this)
      ..angle = -tau / 4
      ..position = Vector2(2, 10);

    worldRenderer = WorldRenderer(this)..init();
  }

  @override
  void update(double dt) {
    player.update(dt);
    castRays();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(ceilingRect, ceilingPaint);
    canvas.drawRect(floorRect, floorPaint);
    canvas.save();
    worldRenderer.render(canvas);
    canvas.restore();
    drawMiniMap(canvas);
  }

  void castRays() {
    castedRays.clear();
    worldRenderer.reset();

    var stripIdx = 0;
    for (var i = 0; i < numRays; i++) {
      // Where on the screen does ray go through?
      final rayScreenPos = (-numRays / 2 + i) * stripWidth;

      // The distance from the viewer to the point
      // on the screen, simply Pythagoras.
      final rayViewDist = sqrt(
        rayScreenPos * rayScreenPos + viewDist * viewDist,
      );

      // The angle of the ray, relative to the viewing direction
      // Right triangle: a = sin(A) * c
      final rayAngle = asin(rayScreenPos / rayViewDist);
      castSingleRay(
        // Add the players viewing direction to get the angle in world space
        player.angle + rayAngle,
        stripIdx++,
      );
    }
  }

  void castSingleRay(double rayAngle, int stripIdx) {
    // Make sure the angle is between 0 and 360 degrees
    final normalizedAngle = rayAngle % tau;

    // Moving right/left? up/down? Determined by
    // which quadrant the angle is in
    final right = normalizedAngle > tau * 0.75 || normalizedAngle < tau * 0.25;
    final up = normalizedAngle < 0 || normalizedAngle > pi;

    final angleSin = sin(normalizedAngle);
    final angleCos = cos(normalizedAngle);

    // The distance to the block we hit
    var dist = 0.0;
    // The x and y coord of where the ray hit the block
    var xHit = 0.0;
    var yHit = 0.0;
    // The x-coord on the texture of the block,
    // i.e. what part of the texture are we going to render
    double? textureX;

    // First check against the vertical map/wall lines
    // we do this by moving to the right or left edge
    // of the block we’re standing in and then moving
    // in 1 map unit steps horizontally. The amount we have
    // to move vertically is determined by the slope of
    // the ray, which is simply defined as sin(angle) / cos(angle).

    // The slope of the straight line made by the ray
    var slope = angleSin / angleCos;
    // We move either 1 map unit to the left or right
    var dX = right ? 1.0 : -1.0;
    // How much to move up or down
    var dY = dX * slope;

    // Starting horizontal position, at one
    // of the edges of the current map block
    var x = (right ? player.x.ceil() : player.x.floor()).toDouble();
    // Starting vertical position. We add the small horizontal
    // step we just made, multiplied by the slope
    var y = player.y + (x - player.x) * slope;

    int? wallType;

    while (x >= 0 && x < mapSize.x && y >= 0 && y < mapSize.y) {
      final wallX = (x + (right ? 0 : -1)).floor();
      final wallY = y.floor();

      // Is this point inside a wall block?
      if (map[wallY][wallX] > 0) {
        final distX = x - player.x;
        final distY = y - player.y;
        // The distance from the player to this point, squared
        dist = distX * distX + distY * distY;
        // we'll remember the type of wall we hit for later
        wallType = map[wallY][wallX];

        // where exactly are we on the wall? textureX is the x coordinate
        //on the texture that we'll use when texturing the wall.
        textureX = y % 1;
        if (!right) {
          // if we're looking to the left side of the map,
          //the texture should be reversed
          textureX = 1 - textureX;
        }

        // Save the coordinates of the hit. We only really
        // use these to draw the rays on minimap
        xHit = x;
        yHit = y;

        break;
      }
      x += dX;
      y += dY;
    }

    // Horizontal run snipped, basically the same as vertical run

    slope = angleCos / angleSin;
    dY = up ? -1 : 1;
    dX = dY * slope;

    y = (up ? player.y.floor() : player.y.ceil()).toDouble();
    x = player.x + (y - player.y) * slope;

    while (x >= 0 && x < mapSize.x && y >= 0 && y < mapSize.y) {
      final wallY = (y + (up ? -1 : 0)).floor();
      final wallX = x.floor();
      if (map[wallY][wallX] > 0) {
        final distX = x - player.x;
        final distY = y - player.y;
        final blockDist = distX * distX + distY * distY;
        if (dist == 0 || blockDist < dist) {
          dist = blockDist;
          xHit = x;
          yHit = y;

          wallType = map[wallY][wallX];
          textureX = x % 1;
          if (up) {
            textureX = 1 - textureX;
          }
        }
        break;
      }
      x += dX;
      y += dY;
    }

    if (dist != 0) {
      castedRays.add(Vector2(xHit, yHit));
      if (wallType != null && textureX != null) {
        worldRenderer.updateStrip(
          stripIdx: stripIdx,
          dist: dist,
          rayAngle: normalizedAngle,
          wallType: wallType,
          textureX: textureX,
        );
      }
    }
  }

  void drawMiniMap(Canvas canvas) {
    for (var y = 0; y < mapSize.y; y++) {
      for (var x = 0; x < mapSize.x; x++) {
        final wall = map[y][x];
        if (wall > 0) {
          final r = Rect.fromLTWH(
            x * miniMapScale,
            y * miniMapScale,
            miniMapScale,
            miniMapScale,
          );
          canvas.drawRect(r, _whitePaint);
        }
      }
    }

    // Draw rays
    castedRays.forEach((p) {
      final path = Path()
        ..moveTo(player.x * miniMapScale, player.y * miniMapScale)
        ..lineTo(p.x * miniMapScale, p.y * miniMapScale)
        ..close();

      canvas.drawPath(path, miniMapRayPaint);
    });

    final playerRect = Rect.fromLTWH(
      player.x * miniMapScale - 2,
      player.y * miniMapScale - 2,
      miniMapScale / 2,
      miniMapScale / 2,
    );

    final path = Path()
      ..moveTo(player.x * miniMapScale, player.y * miniMapScale)
      ..lineTo(
        (player.x + cos(player.angle) * miniMapScale / 2) * miniMapScale,
        (player.y + sin(player.angle) * miniMapScale / 2) * miniMapScale,
      )
      ..close();

    canvas.drawRect(playerRect, miniMapPlayerPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    readArrowLikeKeysIntoVector2(
      event,
      keysPressed,
      player.move,
      up: LogicalKeyboardKey.keyW,
      left: LogicalKeyboardKey.keyA,
      down: LogicalKeyboardKey.keyS,
      right: LogicalKeyboardKey.keyD,
    );
    return KeyEventResult.handled;
  }
}
