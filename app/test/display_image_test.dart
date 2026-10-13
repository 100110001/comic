import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:comic/utils/display_image_provider.dart';
import 'package:comic/widgets/display_network_image.dart';
import 'package:comic/theme.dart';
import 'package:comic/widgets/loading_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/image_http.dart';

Future<Uint8List> imageBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

Future<ImageInfo> decodeImage(ImageProvider provider) {
  final result = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (image, synchronous) {
      stream.removeListener(listener);
      result.complete(image.clone());
    },
    onError: (Object error, StackTrace? stack) {
      stream.removeListener(listener);
      result.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return result.future;
}

void main() {
  final fixture = ImageHttpOverrides();
  setUpAll(() => HttpOverrides.global = fixture);

  testWidgets('慢封面延迟启用动效，首帧后呈现，缓存命中不闪骨架', (tester) async {
    const url = 'http://example.com/delayed.png';
    final release = Completer<void>();
    fixture.delays[url] = release;
    await tester.runAsync(() async {
      fixture.images[url] = await imageBytes(64, 64);
    });
    Widget page({bool reduceMotion = false}) => MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: DisplayNetworkImage(url),
          ),
        ),
      ),
    );
    await tester.pumpWidget(page());
    expect(find.byType(SkeletonPulse), findsOneWidget);
    final fade = find.descendant(
      of: find.byType(SkeletonPulse),
      matching: find.byType(FadeTransition),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<FadeTransition>(fade).opacity.value, lessThan(1));
    await tester.pumpWidget(page(reduceMotion: true));
    await tester.pumpAndSettle();
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    release.complete();
    await tester.runAsync(() async {
      final image = tester.widget<Image>(find.byType(Image));
      final decoded = await decodeImage(image.image);
      decoded.dispose();
    });
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonPulse), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    expect(find.byType(SkeletonPulse), findsNothing);
    expect(fixture.requests[url], 1);
  });

  testWidgets('封面错误不会被首帧骨架覆盖', (tester) async {
    const url = 'http://example.com/loading-error.png';
    fixture.failOnce.add(url);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: DisplayNetworkImage(
              url,
              errorBuilder: (_, _, _) => const Text('重试'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
    expect(find.byType(SkeletonPulse), findsNothing);
  });

  test('同档复用缓存，跨档和来源版本变化隔离，DPR 使用物理像素', () async {
    ImageProvider provider(String url, double width, {double ratio = 1}) =>
        displayImageProvider(
          url,
          logicalSize: Size(width, double.infinity),
          devicePixelRatio: ratio,
          fit: BoxFit.fitWidth,
        );
    const url = 'http://example.com/page.png?v=1';
    Future<Object> key(ImageProvider p) =>
        p.obtainKey(ImageConfiguration.empty);
    expect(await key(provider(url, 100)), await key(provider(url, 120)));
    expect(await key(provider(url, 100)), isNot(await key(provider(url, 129))));
    expect(
      await key(provider(url, 100)),
      isNot(await key(provider(url, 100, ratio: 2))),
    );
    expect(
      await key(provider(url, 100)),
      isNot(await key(provider('http://other.com/page.png?v=1', 100))),
    );
    expect(
      await key(provider(url, 100)),
      isNot(await key(provider('http://example.com/page.png?v=2', 100))),
    );
    expect(provider(url, 5000), isA<NetworkImage>());
  });

  testWidgets('真实解码保比例并满足横向封面 cover 的裁切清晰度', (tester) async {
    await tester.runAsync(() async {
      const url = 'http://example.com/wide.png';
      fixture.images[url] = await imageBytes(800, 400);
      final cover = await decodeImage(
        displayImageProvider(
          url,
          logicalSize: const Size(128, 128),
          devicePixelRatio: 1,
        ),
      );
      expect((cover.image.width, cover.image.height), (256, 128));
      cover.dispose();
      final contained = await decodeImage(
        displayImageProvider(
          url,
          logicalSize: const Size(128, 128),
          devicePixelRatio: 1,
          fit: BoxFit.contain,
        ),
      );
      expect((contained.image.width, contained.image.height), (128, 64));
      contained.dispose();
    });
  });

  testWidgets('移动长条页完整保留比例，小图不放大解码', (tester) async {
    await tester.runAsync(() async {
      const longUrl = 'http://example.com/long.png';
      fixture.images[longUrl] = await imageBytes(256, 2560);
      final long = await decodeImage(
        displayImageProvider(
          longUrl,
          logicalSize: const Size(128, 300),
          devicePixelRatio: 1,
          fit: BoxFit.fitWidth,
        ),
      );
      expect((long.image.width, long.image.height), (128, 1280));
      long.dispose();
      const smallUrl = 'http://example.com/small.png';
      fixture.images[smallUrl] = await imageBytes(32, 16);
      final small = await decodeImage(
        displayImageProvider(
          smallUrl,
          logicalSize: const Size(128, 128),
          devicePixelRatio: 2,
        ),
      );
      expect((small.image.width, small.image.height), (32, 16));
      small.dispose();
    });
  });

  testWidgets('包装尺寸失败不留下坏缓存，重试能再次请求并解码', (tester) async {
    await tester.runAsync(() async {
      const url = 'http://example.com/retry.png';
      fixture.images[url] = await imageBytes(512, 512);
      fixture.failOnce.add(url);
      final provider = displayImageProvider(
        url,
        logicalSize: const Size(128, 128),
        devicePixelRatio: 1,
      );
      await expectLater(
        decodeImage(provider),
        throwsA(isA<NetworkImageLoadException>()),
      );
      await provider.evict();
      final image = await decodeImage(provider);
      expect(image.image.width, 128);
      expect(fixture.requests[url], 2);
      image.dispose();
    });
  });

  testWidgets('封面解码使用实际受约束尺寸与设备像素比', (tester) async {
    const url = 'http://example.com/widget.png';
    await tester.runAsync(() async {
      fixture.images[url] = await imageBytes(256, 256);
    });
    await tester.pumpWidget(
      Theme(
        data: buildAppTheme(Brightness.light),
        child: const MediaQuery(
          data: MediaQueryData(devicePixelRatio: 2),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: DisplayNetworkImage(url, width: 300, height: 300),
              ),
            ),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as DisplaySizedNetworkImage;
    expect((provider.width, provider.height), (256, 256));
    await tester.runAsync(() async {
      final decoded = await decodeImage(provider);
      decoded.dispose();
    });
    await tester.pumpAndSettle();
  });
}
