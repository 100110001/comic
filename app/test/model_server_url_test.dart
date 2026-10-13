import 'package:comic/models/comic.dart';
import 'package:comic/models/image_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('封面文件名中的保留字符按路径编码且不改变文件名', () {
    const filename = '第1話 #2 100%25 ? & +.jpg';
    const comic = Comic(
      id: 1,
      title: '编码回归',
      coverPath: 'E:\\comic\\测试 #1\\$filename',
      serverUrl: 'http://library.test:8888',
    );
    final uri = Uri.parse(comic.coverUrl!);
    expect(uri.pathSegments, ['static', '测试 #1', filename]);
    expect(uri.hasFragment, isFalse);
    expect(uri.hasQuery, isFalse);
  });

  test('已编码章节地址不二次编码并独立保留版本', () {
    final image = ImageItem.fromJson({
      'id': 2,
      'filename': '#1 100%.jpg',
      'pageNumber': 0,
      'url': '/static/%23%31%20%31%30%30%25.jpg?v=123-456',
    }, serverUrl: 'http://library.test');
    final uri = Uri.parse(image.url);
    expect(uri.pathSegments.last, '#1 100%.jpg');
    expect(uri.queryParameters['v'], '123-456');
    expect(uri.hasFragment, isFalse);
  });

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
