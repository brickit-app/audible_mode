import 'dart:async';

import 'package:audible_mode/audible_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

/// Headless isolate for the iOS engine lifecycle tests.
///
/// Listen and cancel go through the real event channels so the Flutter engine
/// delivers them to the plugin. The example UI is not started here.
@pragma('vm:entry-point')
Future<void> engineProbeMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final messenger = ServicesBinding.instance.defaultBinaryMessenger;
  const probe = MethodChannel('audible_mode_engine_probe');
  const volume = MethodChannel('CURRENT_VOLUME_EVENT');
  const profile = MethodChannel('CURRENT_PROFILE_EVENT');
  const codec = StandardMethodCodec();
  var volumeEvents = 0;
  var profileEvents = 0;

  void countEvents(String channel, void Function() record) {
    messenger.setMessageHandler(channel, (ByteData? reply) async {
      if (reply != null) {
        codec.decodeEnvelope(reply);
        record();
      }
      return null;
    });
  }

  probe.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'listenVolume':
        countEvents('CURRENT_VOLUME_EVENT', () {
          volumeEvents += 1;
        });
        await volume.invokeMethod<void>('listen');
      case 'cancelVolume':
        await volume.invokeMethod<void>('cancel');
      case 'listenProfile':
        countEvents('CURRENT_PROFILE_EVENT', () {
          profileEvents += 1;
        });
        await profile.invokeMethod<void>('listen');
      case 'cancelProfile':
        await profile.invokeMethod<void>('cancel');
      case 'volumeCount':
        return volumeEvents;
      case 'profileCount':
        return profileEvents;
      default:
        throw PlatformException(code: 'unknown', message: call.method);
    }
  });
  await Completer<void>().future;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  double volume = 0.0;
  double maxVolume = 0.0;
  late Stream<double> currentVolume;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await Audible.getCurrentVolume.then((value) => setState(() {
          volume = value;
        }));
    await Audible.getMaxVolume.then((value) => setState(() {
          maxVolume = value;
        }));

    Audible.currentVolumeStream.listen((event) {
      setState(() {
        volume = event;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Audible Mode'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                StreamBuilder<AudibleProfile?>(
                  initialData: AudibleProfile.UNDEFINED,
                  stream: Audible.currentProfileStream,
                  builder: (context, snapshot) {
                    switch (snapshot.connectionState) {
                      case ConnectionState.none:
                        return const CircularProgressIndicator();
                      case ConnectionState.waiting:
                      case ConnectionState.active:
                      case ConnectionState.done:
                        return Column(
                          children: [
                            Icon(
                              _generateIcon(
                                  snapshot.data ?? AudibleProfile.UNDEFINED),
                              size: 60,
                            ),
                            Text(
                              _generateText(
                                  snapshot.data ?? AudibleProfile.UNDEFINED),
                              style: const TextStyle(
                                fontSize: 30,
                              ),
                            ),
                          ],
                        );
                    }
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    "Set volume",
                    style: TextStyle(fontSize: 30),
                  ),
                ),
                Text(
                  "${(volume / maxVolume * 100).toInt()}%",
                  style: const TextStyle(fontSize: 20),
                ),
                Slider(
                  value: volume,
                  onChanged: (value) => setState(() {
                    volume = value;
                  }),
                  min: 0,
                  max: maxVolume,
                  onChangeEnd: (value) => Audible.setVolume(volume),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _generateText(AudibleProfile profile) {
    switch (profile) {
      case AudibleProfile.SILENT_MODE:
        return "Silent mode";
      case AudibleProfile.VIBRATE_MODE:
        return "Vibration mode";
      case AudibleProfile.NORMAL_MODE:
        return "Normal mode";
      case AudibleProfile.UNDEFINED:
        return "Undefinded";
    }
  }

  IconData _generateIcon(AudibleProfile profile) {
    switch (profile) {
      case AudibleProfile.SILENT_MODE:
        return Icons.volume_off;
      case AudibleProfile.VIBRATE_MODE:
        return Icons.vibration;
      case AudibleProfile.NORMAL_MODE:
        return Icons.volume_up;
      case AudibleProfile.UNDEFINED:
        return Icons.clear;
    }
  }
}
