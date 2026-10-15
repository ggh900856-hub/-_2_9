import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MontajApp());
}

class MontajApp extends StatelessWidget {
  const MontajApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مونتاج',
      locale: const Locale('ar'),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0B0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE7E8EA),
          surface: Color(0xFF16181B),
          onSurface: Color(0xFFF2F3F5),
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const StudioPage(),
    );
  }
}

class StylePreset {
  const StylePreset({
    required this.id,
    required this.label,
    required this.hold,
    required this.transitions,
    required this.contrast,
    required this.saturation,
    required this.letterbox,
  });

  final String id;
  final String label;
  final double hold;
  final List<String> transitions;
  final double contrast;
  final double saturation;
  final bool letterbox;
}

const styles = <StylePreset>[
  StylePreset(id: 'reels', label: 'ريلز', hold: 1.6, transitions: ['fade'], contrast: 1.08, saturation: 1.1, letterbox: false),
  StylePreset(id: 'cinematic', label: 'سينمائي', hold: 2.8, transitions: ['fade'], contrast: 1.04, saturation: 0.92, letterbox: true),
  StylePreset(id: 'ad', label: 'إعلان', hold: 1.8, transitions: ['fade'], contrast: 1.12, saturation: 1.08, letterbox: false),
  StylePreset(id: 'event', label: 'مناسبة', hold: 2.4, transitions: ['fade'], contrast: 1.05, saturation: 1.02, letterbox: false),
  StylePreset(id: 'travel', label: 'سفر', hold: 2.2, transitions: ['fade'], contrast: 1.06, saturation: 1.08, letterbox: false),
  StylePreset(id: 'wedding', label: 'زفاف', hold: 3.0, transitions: ['fade'], contrast: 1.02, saturation: 0.96, letterbox: false),
  StylePreset(id: 'night', label: 'ليلي', hold: 2.6, transitions: ['fade'], contrast: 1.14, saturation: 0.8, letterbox: true),
  StylePreset(id: 'sport', label: 'رياضي', hold: 1.4, transitions: ['fade'], contrast: 1.16, saturation: 1.12, letterbox: false),
  StylePreset(id: 'luxury', label: 'فخم', hold: 2.8, transitions: ['fade'], contrast: 1.05, saturation: 0.98, letterbox: true),
  StylePreset(id: 'vlog', label: 'فلوج', hold: 2.0, transitions: ['fade'], contrast: 1.04, saturation: 1.04, letterbox: false),
];

class CapColor {
  const CapColor(this.name, this.color);
  final String name;
  final Color color;
}

const capColors = <CapColor>[
  CapColor('أبيض', Color(0xFFF4F1EA)),
  CapColor('أسود', Color(0xFF0A0B0C)),
  CapColor('رملي', Color(0xFFD7C4A3)),
  CapColor('وردي', Color(0xFFD9A8A8)),
  CapColor('نعناعي', Color(0xFF9CBFB0)),
  CapColor('سماوي', Color(0xFF9BB4C4)),
];

class Look {
  const Look(this.id, this.label);
  final String id;
  final String label;
}

const looks = <Look>[
  Look('none', 'بدون'),
  Look('bw', 'أبيض وأسود'),
  Look('warm', 'دافئ'),
  Look('cold', 'بارد'),
  Look('punch', 'تباين'),
  Look('glow', 'توهج'),
  Look('dream', 'حالم'),
  Look('vignette', 'حواف غامقة'),
  Look('grain', 'حبيبات'),
  Look('vintage', 'قديم'),
  Look('sepia', 'سيبيا'),
  Look('teal', 'تيل وبرتقالي'),
  Look('matte', 'باهت سينمائي'),
  Look('sharp', 'حدة'),
];

const transitionChoices = <String>['قطع مباشر', 'تلاشي', 'ومضة بيضاء'];

const durationChoices = <(double, String)>[
  (15, '١٥ ثانية'),
  (30, '٣٠ ثانية'),
  (60, 'دقيقة'),
  (120, 'دقيقتين'),
];

class Shot {
  Shot({required this.path, required this.isImage, required this.name, required this.duration});
  final String path;
  final bool isImage;
  final String name;
  final double duration;
}

class Segment {
  Segment({required this.shot, required this.start, required this.length});
  final Shot shot;
  final double start;
  final double length;
}

class StudioPage extends StatefulWidget {
  const StudioPage({super.key});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  final _picker = ImagePicker();
  final _title = TextEditingController();
  final _sub = TextEditingController();
  final _rng = Random();
  final List<Shot> _shots = [];
  final List<Segment> _plan = [];

  int _style = 0;
  int _aspect = 0;
  int _color = 0;
  int _size = 1;
  int _place = 2;
  int _duration = 0;
  int _look = 0;
  int _transition = 1;
  int _index = 0;
  bool _random = true;
  bool _motion = true;
  bool _playing = false;
  bool _exporting = false;
  String _status = '';
  VideoPlayerController? _video;
  Timer? _timer;
  bool _alive = true;

  static const aspects = [
    ('ريلز', 720, 1280),
    ('يوتيوب', 1280, 720),
    ('مربع', 720, 720),
  ];

  // الترميزات بالترتيب: الكود هيجرب كل واحد لحد ما واحد ينجح
  static const List<List<String>> _encoders = [
    ['-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p'],
    ['-c:v', 'h264_mediacodec', '-b:v', '4M', '-pix_fmt', 'yuv420p'],
    ['-c:v', 'mpeg4', '-q:v', '4', '-pix_fmt', 'yuv420p'],
  ];

  StylePreset get style => styles[_style];
  double get targetSeconds => durationChoices[_duration].$1;

  @override
  void dispose() {
    _alive = false;
    _timer?.cancel();
    _video?.dispose();
    _title.dispose();
    _sub.dispose();
    super.dispose();
  }

  void _rebuildPlan() {
    _plan
      ..clear()
      ..addAll(_makePlan());
    _index = 0;
  }

  List<Segment> _makePlan() {
    if (_shots.isEmpty) return [];
    final total = targetSeconds;
    final cuts = total <= 15 ? 5 : total <= 30 ? 6 : total <= 60 ? 8 : 10;
    final length = total / cuts;
    final plan = <Segment>[];
    for (var i = 0; i < cuts; i++) {
      final shot = _random ? _shots[_rng.nextInt(_shots.length)] : _shots[i % _shots.length];
      var start = 0.0;
      if (!shot.isImage && _random && shot.duration > length + 0.3) {
        start = _rng.nextDouble() * (shot.duration - length);
      }
      plan.add(Segment(shot: shot, start: start, length: length));
    }
    return plan;
  }

  Future<void> _add({required bool images}) async {
    if (_shots.length >= 12) {
      _toast('الحد ١٢ ملف');
      return;
    }
    final picked = images ? await _picker.pickMultiImage() : await _picker.pickMultiVideo();
    if (picked.isEmpty) return;
    final room = 12 - _shots.length;
    for (final file in picked.take(room)) {
      final duration = images ? 4.0 : await _probe(file.path);
      if (!mounted) return;
      _shots.add(Shot(
        path: file.path,
        isImage: images,
        name: file.name,
        duration: duration < 0.4 ? 2 : duration,
      ));
    }
    setState(_rebuildPlan);
  }

  Future<double> _probe(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final raw = session.getMediaInformation()?.getDuration();
      final value = double.tryParse(raw ?? '') ?? 0;
      if (value > 0.3) return value;
    } catch (_) {}
    return 4;
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    final video = _video;
    _video = null;
    await video?.pause();
    await video?.dispose();
    if (_alive && mounted) setState(() => _playing = false);
  }

  Future<void> _play() async {
    if (_shots.isEmpty) return;
    await _stop();
    if (_plan.isEmpty) _rebuildPlan();
    if (!mounted) return;
    setState(() {
      _playing = true;
      _index = 0;
    });
    await _showCurrent();
  }

  Future<void> _showCurrent() async {
    if (!_playing || _plan.isEmpty) return;
    final segment = _plan[_index];
    final shot = segment.shot;
    if (!shot.isImage) {
      final controller = VideoPlayerController.file(File(shot.path));
      _video = controller;
      try {
        await controller.initialize();
        await controller.seekTo(Duration(milliseconds: (segment.start * 1000).round()));
        await controller.setLooping(false);
        await controller.play();
        if (mounted) setState(() {});
      } catch (_) {
        _toast('تعذر تشغيل ' + shot.name);
      }
    } else if (mounted) {
      setState(() {});
    }
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: (segment.length * 1000).round()), () async {
      if (!_alive || !_playing) return;
      await _video?.pause();
      await _video?.dispose();
      _video = null;
      if (!_alive) return;
      if (_index >= _plan.length - 1) {
        if (mounted) setState(() => _playing = false);
        return;
      }
      setState(() => _index += 1);
      await _showCurrent();
    });
  }

  Future<void> _export() async {
    if (_shots.isEmpty || _exporting) return;
    if (_plan.isEmpty) _rebuildPlan();
    setState(() {
      _exporting = true;
      _status = 'بيجهّز اللقطات…';
    });
    await _stop();
    try {
      final work = await _workDir();
      final size = aspects[_aspect];
      final width = size.$2;
      final height = size.$3;
      final copied = <String, File>{};
      var n = 0;
      for (final shot in _shots) {
        final ext = _ext(shot.path, shot.isImage);
        final file = File(work.path + '/src_' + n.toString() + '.' + ext);
        await File(shot.path).copy(file.path);
        copied[shot.path] = file;
        n += 1;
      }

      final hasCaption = _title.text.trim().isNotEmpty;
      final png = File(work.path + '/caption.png');
      if (hasCaption) {
        setState(() => _status = 'بيكتب العبارة…');
        await _captionPng(
          text: _title.text,
          sub: _sub.text,
          color: capColors[_color].color,
          fontSize: [72, 104, 140][_size].toDouble() * (width / 720),
          yFactor: [0.22, 0.5, 0.78][_place],
          width: width,
          height: height,
          out: png,
        );
      }

      // المرحلة ١: الفيديو بالمؤثرات من غير العبارة
      setState(() => _status = 'بيمنتج الفيديو بالمؤثرات…');
      final base = File(work.path + '/base.mp4');
      Object? lastError;
      var done = false;
      var usedSafe = false;
      var usedEncoder = _encoders.last;
      for (final encoder in _encoders) {
        for (final safe in [false, true]) {
          try {
            if (await base.exists()) await base.delete();
            await _runFfmpeg(_command(
              segments: _plan,
              files: copied,
              out: base,
              width: width,
              height: height,
              encoder: encoder,
              safe: safe,
            ));
            if (await base.exists() && await base.length() > 1000) {
              done = true;
              usedSafe = safe;
              usedEncoder = encoder;
              break;
            }
          } catch (e) {
            lastError = e;
            if (mounted) setState(() => _status = 'بيجرب طريقة تانية…');
          }
        }
        if (done) break;
      }
      if (!done) {
        throw Exception('فشل مرحلة المقاطع: ' + (lastError?.toString().replaceFirst('Exception: ', '') ?? ''));
      }

      // المرحلة ٢: حط العبارة فوق الفيديو
      var finalFile = base;
      var captionFailed = false;
      if (hasCaption) {
        setState(() => _status = 'بيحط العبارة…');
        final out = File(work.path + '/montaj.mp4');
        try {
          if (await out.exists()) await out.delete();
          await _runFfmpeg(_overlayCommand(
            video: base,
            caption: png,
            out: out,
            encoder: usedEncoder,
          ));
          if (await out.exists() && await out.length() > 1000) {
            finalFile = out;
          } else {
            captionFailed = true;
          }
        } catch (_) {
          captionFailed = true;
        }
      }

      final notes = <String>[];
      if (usedSafe) notes.add('بدون المؤثرات');
      if (captionFailed) notes.add('بدون العبارة');
      final note = notes.isEmpty ? '' : ' (' + notes.join(' و') + ')';
      setState(() => _status = 'جاهز' + note);
      try {
        await Share.shareXFiles([XFile(finalFile.path)], subject: 'مونتاج', text: 'مونتاج');
      } catch (_) {}
      _toast('اتحفظ ملف MP4' + note);
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (mounted) setState(() => _status = message);
      _toast(message.isEmpty ? 'فشل حفظ MP4' : message);
      return;
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Directory> _workDir() async {
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final places = <Directory>[];
    try {
      places.add(await getApplicationDocumentsDirectory());
    } catch (_) {}
    try {
      places.add(await getTemporaryDirectory());
    } catch (_) {}
    try {
      final external = await getExternalStorageDirectory();
      if (external != null) places.add(external);
    } catch (_) {}
    for (final place in places) {
      final work = Directory(place.path + '/montaj_' + stamp);
      try {
        await work.create(recursive: true);
        final probe = File(work.path + '/ok.txt');
        await probe.writeAsString('ok');
        await probe.delete();
        return work;
      } catch (_) {}
    }
    throw Exception('الموبايل مش سامح يكتب الملف');
  }

  Future<void> _runFfmpeg(List<String> args) async {
    final session = await FFmpegKit.executeWithArguments(args);
    final code = await session.getReturnCode();
    if (ReturnCode.isSuccess(code)) return;
    var tail = '';
    try {
      final output = await session.getOutput();
      if (output != null && output.trim().isNotEmpty) {
        final lines = output.split('\n').where((line) => line.trim().isNotEmpty).toList();
        final start = lines.length > 2 ? lines.length - 2 : 0;
        tail = lines.sublist(start).join(' ');
        if (tail.length > 180) tail = tail.substring(tail.length - 180);
      }
    } catch (_) {}
    throw Exception(tail.isEmpty ? 'فشل حفظ MP4' : tail);
  }

  String _ext(String path, bool image) {
    final raw = path.split('.').last.toLowerCase();
    if (!image) return 'mp4';
    if (raw == 'png' || raw == 'webp' || raw == 'jpg' || raw == 'jpeg') {
      return raw == 'jpeg' ? 'jpg' : raw;
    }
    return 'jpg';
  }

  // فلتر المؤثر البصري (ffmpeg). التوهج والحالم بيتبنوا لوحدهم جوه _command
  String _lookFilter(String id) {
    switch (id) {
      case 'bw':
        return 'hue=s=0';
      case 'warm':
        return 'colorbalance=rs=0.12:gs=0.02:bs=-0.12:rm=0.10:bm=-0.10';
      case 'cold':
        return 'colorbalance=rs=-0.10:bs=0.14:rm=-0.08:bm=0.10';
      case 'punch':
        return 'eq=contrast=1.25:saturation=1.3';
      case 'vignette':
        return 'vignette=PI/4';
      case 'grain':
        return 'noise=alls=18:allf=t';
      case 'vintage':
        return 'curves=preset=vintage';
      case 'sepia':
        return 'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131:0';
      case 'teal':
        return 'colorbalance=rs=-0.12:bs=0.15:rh=0.18:gh=0.04:bh=-0.14';
      case 'matte':
        return 'eq=contrast=0.88:brightness=0.04:saturation=0.85';
      case 'sharp':
        return 'unsharp=5:5:1.0:5:5:0.0';
      default:
        return '';
    }
  }

  // المرحلة ٢: بيحط صورة العبارة فوق الفيديو الجاهز
  List<String> _overlayCommand({
    required File video,
    required File caption,
    required File out,
    required List<String> encoder,
  }) {
    return [
      '-y',
      '-i', video.path,
      '-i', caption.path,
      '-filter_complex', '[0:v][1:v]overlay=0:0,format=yuv420p[outv]',
      '-map', '[outv]',
      '-map', '0:a',
      ...encoder,
      '-c:a', 'copy',
      '-movflags', '+faststart',
      out.path,
    ];
  }

  // المرحلة ١: اللقطات والمؤثرات (من غير العبارة)
  List<String> _command({
    required List<Segment> segments,
    required Map<String, File> files,
    required File out,
    required int width,
    required int height,
    required List<String> encoder,
    bool safe = false,
  }) {
    final letterbox = safe ? false : style.letterbox;
    final w = width.toString();
    final h = height.toString();
    final fit = letterbox
        ? 'scale=' + w + ':' + h + ':force_original_aspect_ratio=decrease,pad=' + w + ':' + h + ':(ow-iw)/2:(oh-ih)/2'
        : 'scale=' + w + ':' + h + ':force_original_aspect_ratio=increase,crop=' + w + ':' + h;
    final bigW = ((width * 1.18) / 2).round() * 2;
    final bigH = ((height * 1.18) / 2).round() * 2;
    final totalSeconds = segments.fold<double>(0, (sum, segment) => sum + segment.length);
    final total = totalSeconds.clamp(0.8, 180).toDouble().toStringAsFixed(2);
    final lookId = looks[_look].id;
    final args = <String>['-y'];
    for (final segment in segments) {
      final file = files[segment.shot.path]!;
      final d = segment.length.toStringAsFixed(2);
      if (segment.shot.isImage) {
        args.addAll(['-loop', '1', '-framerate', '30', '-t', d, '-i', file.path]);
      } else {
        final start = segment.start < 0.05 ? 0.0 : segment.start;
        args.addAll(['-ss', start.toStringAsFixed(2), '-t', d, '-i', file.path]);
      }
    }
    final filters = <String>[];
    for (var i = 0; i < segments.length; i++) {
      final d = segments[i].length.toStringAsFixed(2);
      final idx = i.toString();
      var chain = '[' + idx + ':v]';

      // 1) الحجم والحركة
      if (safe) {
        chain = chain + fit + ',fps=30,format=yuv420p';
      } else if (_motion && !letterbox) {
        final scaleUp = 'fps=30,scale=' + bigW.toString() + ':' + bigH.toString() + ':force_original_aspect_ratio=increase';
        String move;
        final mode = i % 3;
        if (mode == 0) {
          move = "crop=" + w + ":" + h + ":x='(iw-ow)*t/" + d + "':y='(ih-oh)/2'";
        } else if (mode == 1) {
          move = "crop=" + w + ":" + h + ":x='(iw-ow)*(1-t/" + d + ")':y='(ih-oh)/2'";
        } else {
          move = "crop=" + w + ":" + h + ":x='(iw-ow)/2':y='(ih-oh)*t/" + d + "'";
        }
        chain = chain + scaleUp + ',' + move + ',format=yuv420p';
      } else {
        chain = chain + 'fps=30,' + fit + ',format=yuv420p';
      }

      // 2) تدرج الأسلوب (تباين وتشبع)
      if (!safe) {
        chain = chain + ',eq=contrast=' + style.contrast.toStringAsFixed(2) + ':saturation=' + style.saturation.toStringAsFixed(2);
      }

      // 3) المؤثر البصري
      if (!safe) {
        if (lookId == 'glow' || lookId == 'dream') {
          final sigma = lookId == 'glow' ? '18' : '30';
          final opacity = lookId == 'glow' ? '0.35' : '0.55';
          chain = chain +
              ',split[ga' + idx + '][gb' + idx + '];[gb' + idx + ']gblur=sigma=' + sigma + '[gc' + idx + '];' +
              '[ga' + idx + '][gc' + idx + ']blend=all_mode=screen:all_opacity=' + opacity;
          if (lookId == 'dream') {
            chain = chain + ',eq=saturation=1.15:brightness=0.02';
          }
        } else {
          final f = _lookFilter(lookId);
          if (f.isNotEmpty) chain = chain + ',' + f;
        }
        chain = chain + ',format=yuv420p';
      }

      chain = chain + ',trim=duration=' + d + ',setpts=PTS-STARTPTS';

      // 4) الانتقال
      if (!safe && segments[i].length > 0.6) {
        final outAt = (segments[i].length - 0.25).toStringAsFixed(2);
        if (_transition == 1) {
          chain = chain + ',fade=t=in:st=0:d=0.2,fade=t=out:st=' + outAt + ':d=0.2';
        } else if (_transition == 2) {
          chain = chain + ',fade=t=in:st=0:d=0.25:color=white';
        }
      }
      filters.add(chain + '[v' + i.toString() + ']');
    }
    var concatIn = '';
    for (var i = 0; i < segments.length; i++) {
      concatIn = concatIn + '[v' + i.toString() + ']';
    }
    filters.add(concatIn + 'concat=n=' + segments.length.toString() + ':v=1:a=0[outv]');
    args.addAll([
      '-f', 'lavfi', '-t', total, '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
      '-filter_complex', filters.join(';'),
      '-map', '[outv]',
      '-map', segments.length.toString() + ':a',
      ...encoder,
      '-c:a', 'aac',
      '-b:a', '128k',
      '-movflags', '+faststart',
      out.path,
    ]);
    return args;
  }

  Future<void> _captionPng({
    required String text,
    required String sub,
    required Color color,
    required double fontSize,
    required double yFactor,
    required int width,
    required int height,
    required File out,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final line = text.trim();
    if (line.isNotEmpty) {
      final main = TextPainter(
        text: TextSpan(
          text: line,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1.12,
            shadows: const [Shadow(color: Colors.black, blurRadius: 16, offset: Offset(0, 2))],
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: width * 0.88);
      TextPainter? extra;
      var block = main.height;
      final second = sub.trim();
      if (second.isNotEmpty) {
        extra = TextPainter(
          text: TextSpan(
            text: second,
            style: TextStyle(color: color, fontSize: fontSize * 0.42, fontWeight: FontWeight.w600, height: 1.2),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          maxLines: 2,
        )..layout(maxWidth: width * 0.8);
        block += 14 + extra.height;
      }
      final top = (height * yFactor - block / 2).clamp(height * 0.06, height - block - height * 0.06).toDouble();
      main.paint(canvas, Offset((width - main.width) / 2, top));
      extra?.paint(canvas, Offset((width - extra.width) / 2, top + main.height + 14));
    }
    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
  }

  // معاينة تقريبية للمؤثر جوه التطبيق
  Widget _graded(Widget child) {
    final id = looks[_look].id;
    Widget body = child;
    if (id == 'bw' || id == 'sepia') {
      body = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: child,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        if (id == 'warm') const ColoredBox(color: Color(0x33C47A3A)),
        if (id == 'cold') const ColoredBox(color: Color(0x333A78C8)),
        if (id == 'glow') const ColoredBox(color: Color(0x22FFFFFF)),
        if (id == 'dream') const ColoredBox(color: Color(0x33FFD6F0)),
        if (id == 'punch') const ColoredBox(color: Color(0x22000000)),
        if (id == 'vintage') const ColoredBox(color: Color(0x33A0784A)),
        if (id == 'sepia') const ColoredBox(color: Color(0x55704214)),
        if (id == 'teal') const ColoredBox(color: Color(0x2A1E8C8C)),
        if (id == 'matte') const ColoredBox(color: Color(0x30FFFFFF)),
        if (id == 'vignette' || id == 'grain' || style.letterbox)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x00000000), Color(0xCC000000)],
                stops: [0.55, 1],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final segment = _plan.isEmpty ? null : _plan[_index.clamp(0, _plan.length - 1)];
    final shot = segment?.shot;
    final ratio = aspects[_aspect].$2 / aspects[_aspect].$3;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0B0C),
        title: const Text('مونتاج'),
        actions: [
          TextButton(
            onPressed: _shots.isEmpty || _exporting ? null : _export,
            child: Text(_exporting ? 'بيحفظ…' : 'احفظ MP4'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          AspectRatio(
            aspectRatio: ratio.clamp(0.45, 1.8).toDouble(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: const Color(0xFF111214),
                child: _graded(
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      if (shot == null)
                        const Center(child: Text('أضف فيديو أو صورة', style: TextStyle(color: Color(0xFF9AA0A6))))
                      else if (!shot.isImage && _video != null && _video!.value.isInitialized)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _video!.value.size.width,
                            height: _video!.value.size.height,
                            child: VideoPlayer(_video!),
                          ),
                        )
                      else if (shot.isImage)
                        Image.file(File(shot.path), fit: BoxFit.cover)
                      else
                        const Center(child: Icon(Icons.movie_outlined)),
                      if (_title.text.trim().isNotEmpty)
                        Align(
                          alignment: [Alignment.topCenter, Alignment.center, Alignment.bottomCenter][_place],
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              _title.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: capColors[_color].color,
                                fontSize: [28, 40, 52][_size].toDouble(),
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                shadows: const [Shadow(color: Colors.black, blurRadius: 12)],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _btn('أضف فيديو', Icons.video_library_outlined, () => _add(images: false))),
              const SizedBox(width: 8),
              Expanded(child: _btn('أضف صورة', Icons.image_outlined, () => _add(images: true))),
              const SizedBox(width: 8),
              _btn(_playing ? 'وقف' : 'شغّل', _playing ? Icons.pause : Icons.play_arrow, () {
                if (_playing) {
                  _stop();
                } else {
                  _play();
                }
              }),
            ],
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_status, style: const TextStyle(color: Color(0xFF9AA0A6))),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _shots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = _shots[i];
                return Container(
                  width: 120,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16181B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.isImage ? 'صورة' : 'فيديو', style: const TextStyle(fontSize: 12, color: Color(0xFF9AA0A6))),
                      const SizedBox(height: 4),
                      Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () async {
                            await _stop();
                            setState(() {
                              _shots.removeAt(i);
                              _rebuildPlan();
                            });
                          },
                          child: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text('المدة'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < durationChoices.length; i++)
                ChoiceChip(
                  label: Text(durationChoices[i].$2),
                  selected: _duration == i,
                  onSelected: (_) => setState(() {
                    _duration = i;
                    _rebuildPlan();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('قص عشوائي'),
            subtitle: Text(
              _random ? 'ياخد حتت مختلفة من الفيديوهات ويرتبها عشوائي، مش بالترتيب' : 'يرتب الملفات ورا بعض زي ما ضفتها',
            ),
            value: _random,
            onChanged: (value) => setState(() {
              _random = value;
              _rebuildPlan();
            }),
          ),
          if (_random)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _shots.isEmpty
                    ? null
                    : () async {
                        await _stop();
                        setState(_rebuildPlan);
                      },
                icon: const Icon(Icons.shuffle),
                label: Text(_plan.isEmpty ? 'اخلط اللقطات' : 'اخلط تاني (' + _plan.length.toString() + ' لقطة)'),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('حركة الكاميرا'),
            subtitle: const Text('تحريك وتقريب خفيف في كل لقطة، بيظهر في الملف المحفوظ'),
            value: _motion,
            onChanged: (value) => setState(() => _motion = value),
          ),
          const SizedBox(height: 8),
          const Text('مؤثر بصري'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < looks.length; i++)
                ChoiceChip(
                  label: Text(looks[i].label),
                  selected: _look == i,
                  onSelected: (_) => setState(() => _look = i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('الانتقال بين اللقطات'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < transitionChoices.length; i++)
                ChoiceChip(
                  label: Text(transitionChoices[i]),
                  selected: _transition == i,
                  onSelected: (_) => setState(() => _transition = i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('الأسلوب'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < styles.length; i++)
                ChoiceChip(
                  label: Text(styles[i].label),
                  selected: _style == i,
                  onSelected: (_) => setState(() {
                    _style = i;
                    _rebuildPlan();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('المقاس'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < aspects.length; i++)
                ChoiceChip(
                  label: Text(aspects[i].$1),
                  selected: _aspect == i,
                  onSelected: (_) => setState(() => _aspect = i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            maxLength: 42,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'عبارة كبيرة', counterText: ''),
          ),
          TextField(
            controller: _sub,
            maxLength: 36,
            decoration: const InputDecoration(labelText: 'سطر تاني'),
          ),
          const SizedBox(height: 8),
          const Text('لون العبارة'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < capColors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: capColors[i].color,
                      shape: BoxShape.circle,
                      border: Border.all(color: _color == i ? Colors.white : Colors.white24, width: _color == i ? 3 : 1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(['كبير', 'أكبر', 'عملاق'][i]),
                  selected: _size == i,
                  onSelected: (_) => setState(() => _size = i),
                ),
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(['أعلى', 'وسط', 'أسفل'][i]),
                  selected: _place == i,
                  onSelected: (_) => setState(() => _place = i),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap) {
    return FilledButton.icon(
      onPressed: _exporting ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE7E8EA),
        foregroundColor: const Color(0xFF0A0B0C),
        minimumSize: const Size(0, 48),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}