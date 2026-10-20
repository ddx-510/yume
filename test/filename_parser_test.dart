import 'package:flutter_test/flutter_test.dart';
import 'package:yume/danmaku/danmaku_models.dart';
import 'package:yume/services/library_scanner.dart';
import 'package:yume/util/filename_parser.dart';

void main() {
  group('parseFileName', () {
    final cases = <String, (String, double?, int?)>{
      '[SubsPlease] Sousou no Frieren - 03 (1080p) [ABCD1234].mkv': (
        'Sousou no Frieren',
        3,
        null,
      ),
      '[Erai-raws] Spy x Family Season 2 - 05 [1080p][Multiple Subtitle].mkv': (
        'Spy x Family Season 2',
        5,
        2,
      ),
      'Frieren.S01E03.1080p.WEB-DL.x264.mkv': ('Frieren', 3, 1),
      'Bocchi the Rock! S01E12.mp4': ('Bocchi the Rock!', 12, 1),
      '[LoliHouse] Kusuriya no Hitorigoto [07][WebRip 1080p HEVC-10bit AAC].mkv':
          ('Kusuriya no Hitorigoto', 7, null),
      '葬送的芙莉莲 第03话.mp4': ('葬送的芙莉莲', 3, null),
      'Episode 04.mkv': ('', 4, null),
      'One Piece 1089.mkv': ('One Piece', 1089, null),
      '[Group] Mushoku Tensei - 07.5 [720p].mkv': ('Mushoku Tensei', 7.5, null),
      'Your Name (2016) [BD 1080p].mkv': ('Your Name', null, null),
      'Oshi no Ko - 11v2 [1080p].mkv': ('Oshi no Ko', 11, null),
    };
    cases.forEach((name, expected) {
      test(name, () {
        final r = parseFileName(name);
        expect(r.title, expected.$1, reason: r.toString());
        expect(r.episode, expected.$2, reason: r.toString());
        expect(r.season, expected.$3, reason: r.toString());
      });
    });

    test('group is extracted', () {
      expect(parseFileName('[SubsPlease] X - 01.mkv').group, 'SubsPlease');
    });
  });

  group('groupFiles', () {
    const root = '/lib';
    List<String> names(List<String> l) => l.map((e) => '$root/$e').toList();

    test('groups release files by title and sorts episodes', () {
      final shows = groupFiles(
        names([
          '[SubsPlease] Sousou no Frieren - 02 (1080p).mkv',
          '[SubsPlease] Sousou no Frieren - 01 (1080p).mkv',
          'Frieren/[Other] Sousou no Frieren - 03.mkv',
          'Bocchi the Rock/Episode 01.mkv',
          'Bocchi the Rock/Episode 02.mkv',
        ]),
        [root],
        exists: (_) => false,
      );
      final byTitle = {for (final s in shows) s.title: s};
      expect(
        byTitle.keys,
        containsAll(['Bocchi the Rock', 'Sousou no Frieren']),
      );
      expect(byTitle['Bocchi the Rock']!.episodes.map((e) => e.episode), [
        1,
        2,
      ]);
      expect(byTitle['Sousou no Frieren']!.episodes.map((e) => e.episode), [
        1,
        2,
        3,
      ]);
    });

    test('folder title wins when file title is a variant of it', () {
      final shows = groupFiles(
        names([
          'Spy x Family/Spy x Family - 01.mkv',
          'Spy x Family/Spy x Family - 02.mkv',
        ]),
        [root],
        exists: (_) => false,
      );
      expect(shows, hasLength(1));
      expect(shows.single.episodes, hasLength(2));
    });

    test('seasons are separate shows', () {
      final shows = groupFiles(names(['Show S01E01.mkv', 'Show S02E01.mkv']), [
        root,
      ], exists: (_) => false);
      expect(shows.map((s) => s.title), ['Show', 'Show Season 2']);
    });

    test('picks up sidecar subtitles and danmaku xml', () {
      final shows = groupFiles(names(['A/A - 01.mkv']), [
        root,
      ], exists: (p) => p == '$root/A/A - 01.ass' || p == '$root/A/A - 01.xml');
      final ep = shows.single.episodes.single;
      expect(ep.subtitlePaths, ['$root/A/A - 01.ass']);
      expect(ep.danmakuPath, '$root/A/A - 01.xml');
    });
  });

  group('danmaku parsing', () {
    test('bilibili xml', () {
      final list = parseBilibiliXml('''<?xml version="1.0"?><i>
        <d p="12.5,1,25,16777215,0,0,0,0">hello</d>
        <d p="3.0,5,25,16711680,0,0,0,0">top red</d>
        <d p="7,4,25,65280,0,0,0,0">bottom</d></i>''');
      expect(list.map((c) => c.time), [3.0, 7, 12.5]);
      expect(list.first.mode, DanmakuMode.top);
      expect(list.first.color.toARGB32(), 0xFFFF0000);
      expect(list[1].mode, DanmakuMode.bottom);
    });

    test('dandanplay json', () {
      final list = parseDandanComments({
        'count': 2,
        'comments': [
          {'cid': 1, 'p': '5.10,1,16777215,u1', 'm': 'b'},
          {'cid': 2, 'p': '1.00,5,255,u2', 'm': 'a'},
        ],
      });
      expect(list.map((c) => c.text), ['a', 'b']);
      expect(list.first.mode, DanmakuMode.top);
    });
  });
}
