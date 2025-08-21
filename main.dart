import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

void main() {
  runApp(GameApp());
}

class GameApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catch the Stars',
      home: GameWidget.controlled(gameFactory: CatchStarsGame.new),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CatchStarsGame extends FlameGame with HasKeyboardHandlerComponents {
  late Player player;
  late TextComponent scoreText;
  late TextComponent timeText;
  int score = 0;
  double gameTime = 60.0; // 60 seconds game
  bool gameOver = false;
  double starSpawnTimer = 0;
  double starSpawnInterval = 1.5;
  double bombSpawnTimer = 0;
  double bombSpawnInterval = 3.0;

  @override
  Future<void> onLoad() async {
    // Set dark blue background first so other components render on top
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFF001122),
    ));

    // Create player
    player = Player()
      ..position = Vector2(size.x / 2 - 25, size.y - 100);
    add(player);

    // Add score display
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(20, 30),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(scoreText);

    // Add time display
    timeText = TextComponent(
      text: 'Time: 60',
      position: Vector2(size.x - 150, 30),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(timeText);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameOver) return;

    // Update game time
    gameTime -= dt;
    timeText.text = 'Time: ${gameTime.ceil()}';

    if (gameTime <= 0) {
      endGame();
      return;
    }

    // Spawn stars
    starSpawnTimer += dt;
    if (starSpawnTimer >= starSpawnInterval) {
      spawnStar();
      starSpawnTimer = 0;
    }

    // Spawn bombs less frequently
    bombSpawnTimer += dt;
    if (bombSpawnTimer >= bombSpawnInterval) {
      spawnBomb();
      bombSpawnTimer = 0;
    }

    // Check collisions
    checkCollisions();
  }

  void spawnStar() {
    final star = Star();
    star.position = Vector2(
      math.Random().nextDouble() * (size.x - 30),
      -30,
    );
    add(star);
  }

  void spawnBomb() {
    final bomb = Bomb();
    bomb.position = Vector2(
      math.Random().nextDouble() * (size.x - 25),
      -25,
    );
    add(bomb);
  }

  void checkCollisions() {
    final playerRect = player.toRect();

    // Check star collisions
    children.whereType<Star>().toList().forEach((star) {
      if (playerRect.overlaps(star.toRect())) {
        score += 10;
        scoreText.text = 'Score: $score';
        star.removeFromParent();
      }
    });

    // Check bomb collisions
    children.whereType<Bomb>().toList().forEach((bomb) {
      if (playerRect.overlaps(bomb.toRect())) {
        score = math.max(0, score - 20);
        scoreText.text = 'Score: $score';
        bomb.removeFromParent();
      }
    });
  }

  void endGame() {
    gameOver = true;
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.black54,
    ));

    add(TextComponent(
      text: 'GAME OVER!\nFinal Score: $score\nPress R to restart',
      position: size / 2,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    ));
  }

  void restartGame() {
    if (!gameOver) return;

    // Reset game state
    score = 0;
    gameTime = 60.0;
    gameOver = false;
    starSpawnTimer = 0;
    bombSpawnTimer = 0;

    // Remove all game objects (stars, bombs, game over screen elements)
    removeWhere((component) =>
        component is Star ||
        component is Bomb ||
        (component is TextComponent && component.text.contains('GAME OVER')) ||
        (component is RectangleComponent && component.paint.color == Colors.black54));

    // Reset displays
    scoreText.text = 'Score: 0';
    timeText.text = 'Time: 60';

    // Reset player position
    player.position = Vector2(size.x / 2 - 25, size.y - 100);
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (gameOver && keysPressed.contains(LogicalKeyboardKey.keyR)) {
      restartGame();
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }
}

class Player extends RectangleComponent with HasGameRef<CatchStarsGame> {
  static const double speed = 250;

  @override
  Future<void> onLoad() async {
    size = Vector2(50, 30);
    paint = Paint()..color = Colors.cyan;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameRef.gameOver) return;

    // Simple keyboard input handling
    if (RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.keyA)) {
      position.x = math.max(0, position.x - speed * dt);
    }
    if (RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.keyD)) {
      position.x = math.min(gameRef.size.x - size.x, position.x + speed * dt);
    }
  }
}

class Star extends CircleComponent with HasGameRef<CatchStarsGame> {
  static const double fallSpeed = 100;

  @override
  Future<void> onLoad() async {
    radius = 15;
    paint = Paint()..color = Colors.yellow;
  }

  @override
  void update(double dt) {
    super.update(dt);

    position.y += fallSpeed * dt;

    // Add rotation for visual appeal
    angle += dt * 2;

    // Remove if off screen
    if (position.y > gameRef.size.y + 50) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // Draw a simple star shape
    final paint = Paint()..color = Colors.yellow;
    final center = size / 2;

    // Draw star using triangles
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      final outerRadius = radius;
      final innerRadius = radius * 0.4;

      final outerX = center.x + outerRadius * math.cos(angle);
      final outerY = center.y + outerRadius * math.sin(angle);

      final innerAngle = angle + math.pi / 5;
      final innerX = center.x + innerRadius * math.cos(innerAngle);
      final innerY = center.y + innerRadius * math.sin(innerAngle);

      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();

    canvas.drawPath(path, paint);
  }
}

class Bomb extends RectangleComponent with HasGameRef<CatchStarsGame> {
  static const double fallSpeed = 120;

  @override
  Future<void> onLoad() async {
    size = Vector2(25, 25);
    paint = Paint()..color = Colors.red;
  }

  @override
  void update(double dt) {
    super.update(dt);

    position.y += fallSpeed * dt;

    // Add pulsing effect
    final pulse = math.sin(gameRef.gameTime * 8) * 0.1 + 1.0;
    scale = Vector2.all(pulse);

    // Remove if off screen
    if (position.y > gameRef.size.y + 50) {
      removeFromParent();
    }
  }
}
