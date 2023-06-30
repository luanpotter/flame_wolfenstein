import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame_wolfenstein/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Flame.device.setLandscape();
    await Flame.device.fullScreen();
  }

  runApp(GameWidget(game: FlameWolfenstein()));
}
