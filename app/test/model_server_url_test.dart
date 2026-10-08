import 'package:comic/models/comic.dart';
import 'package:comic/models/image_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('漫画封面绑定响应所属服务器', () {
    final comic = Comic.fromJson({
      'id': 1,
      'title': '测试漫画',
      'cover_path': r'D:\Comics\comic\测试漫画\001.jpg',
    }, serverUrl: 'http://new-server.test:9999');

    final uri = Uri.parse(comic.coverUrl!);
    expect(uri.host, 'new-server.test');
    expect(uri.port, 9999);
    expect(uri.pathSegments, containsAllInOrder(['static', '测试漫画', '001.jpg']));
    expect(comic.withFavorited(true).coverUrl, comic.coverUrl);
  });

  test('章节图片绑定服务器并保留版本参数', () {
    final image = ImageItem.fromJson({
      'id': 2,
      'filename': '001.jpg',
      'pageNumber': 0,
      'url': '/static/测试漫画/001.jpg?v=123-456',
    }, serverUrl: 'https://new-server.test');

    final uri = Uri.parse(image.url);
    expect(uri.host, 'new-server.test');
    expect(uri.pathSegments, containsAllInOrder(['static', '测试漫画', '001.jpg']));
    expect(uri.queryParameters['v'], '123-456');
  });
}
