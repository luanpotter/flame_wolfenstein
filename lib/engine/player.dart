import 'dart:math';

import 'package:flame/extensions.dart';
import 'package:flame_wolfenstein/engine/utils.dart';
import 'package:flame_wolfenstein/game.dart';

class Player {
  static const moveSpeed = 3;
  static const rotationSpeed = 1 / 3 * tau;

  FlameWolfenstein gameRef;

  Player(this.gameRef);

  Vector2 position = Vector2.zero();
  double get x => position.x;
  double get y => position.y;
  double angle = 0;

  Vector2 move = Vector2.zero();

  void update(double dt) {
    // Player will move this far along the current direction vector
    final moveStep = -move.y * moveSpeed * dt;

    // Add rotation if player is rotating (player.dir != 0)
    angle += move.x * rotationSpeed * dt;

    // make sure the angle is between 0 and tau
    while (angle < 0) {
      angle += tau;
    }
    while (angle >= tau) {
      angle -= tau;
    }

    // Calculate new player position with simple trigonometry
    final newPosition = position + Vector2(cos(angle), sin(angle)) * moveStep;

    // Set new position
    if (!isBlocking(newPosition)) {
      position.setFrom(newPosition);
    }
  }

  bool isBlocking(Vector2 position) {
    // check boundaries of the level
    if (position.y < 0 || position.y >= gameRef.mapSize.y) {
      return true;
    }
    if (position.x < 0 || position.x >= gameRef.mapSize.x) {
      return true;
    }
    return gameRef.map[position.y.floor()][position.x.floor()] != 0;
  }
}
