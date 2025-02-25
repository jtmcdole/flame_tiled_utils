import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flame_tiled_utils/flame_tiled_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MapRenderingMode { standard, optimizedOnlyStatic, optimizedWithAnimation }

void main(List<String> args) async {
  final game = TestGame(MapRenderingMode.optimizedWithAnimation);
  runApp(GameWidget(game: game));
}

class TestGame extends FlameGame with KeyboardEvents, ScrollDetector {
  TestGame(this.renderingMode);

  MapRenderingMode renderingMode;

  @override
  Future<void> onLoad() async {
    final tiledComponent =
        await TiledComponent.load('example.tmx', Vector2.all(8));

    if (renderingMode == MapRenderingMode.standard) {
      add(tiledComponent);
    } else {
      final imageCompiler = ImageBatchCompiler();
      // Adding separate ground layer
      final ground = await imageCompiler.compileMapLayer(
          tileMap: tiledComponent.tileMap, layerNames: ['ground']);
      ground.priority = -1;
      add(ground);

      // Adding separate tree layer
      final tree = await imageCompiler.compileMapLayer(
          tileMap: tiledComponent.tileMap, layerNames: ['tree']);
      tree.priority = 3;
      add(tree);

      if (renderingMode == MapRenderingMode.optimizedOnlyStatic) {
        //Process every tile of layer "water"
        TileProcessor.processTileType(
            tileMap: tiledComponent.tileMap,
            processorByType: <String, TileProcessorFunc>{
              // Working with tiles of "water" type
              'water': ((tile, position, size) async {
                // Reading animation for the tile
                final animation = await tile.getSpriteAnimation();
                // Creating animation object for every found tile.
                // Simple but very expensive approach.
                add(SpriteAnimationComponent(
                    animation: animation,
                    position: position,
                    size: Vector2.all(8),
                    priority: 2));
              }),
            },
            layersToLoad: [
              'water',
            ]);
      } else if (renderingMode == MapRenderingMode.optimizedWithAnimation) {
        // Optimal way to work with big number of animated tiles
        // Creating compiler to save all tiles to be merged;
        final animationCompiler = AnimationBatchCompiler();
        TileProcessor.processTileType(
            tileMap: tiledComponent.tileMap,
            processorByType: <String, TileProcessorFunc>{
              'water': ((tile, position, size) {
                // saving tile for merge
                animationCompiler.addTile(position, tile);
              }),
            },
            layersToLoad: [
              'water',
            ]);
        // Compile SpriteAnimation component from list of animated tiles.
        final animatedWater = await animationCompiler.compile();
        animatedWater.priority = 2;
        add(animatedWater);
      }
    }

    add(FpsTextComponent());
    camera.viewport = FixedResolutionViewport(Vector2(500, 250));
    camera.snapTo(Vector2(0, 500));
    camera.zoom = 1;
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    for (final key in keysPressed) {
      if (key == LogicalKeyboardKey.keyW) {
        camera.translateBy(Vector2(0, -300));
      }
      if (key == LogicalKeyboardKey.keyA) {
        camera.translateBy(Vector2(-300, 0));
      }
      if (key == LogicalKeyboardKey.keyS) {
        camera.translateBy(Vector2(0, 300));
      }
      if (key == LogicalKeyboardKey.keyD) {
        camera.translateBy(Vector2(300, 0));
      }
    }

    return KeyEventResult.handled;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    camera.zoom += info.scrollDelta.game.y.sign * 0.08;
    camera.zoom = camera.zoom.clamp(0.05, 5.0);
  }
}
