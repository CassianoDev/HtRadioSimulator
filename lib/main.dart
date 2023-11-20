import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'misc/AudioPacket.dart';
import 'misc/VUMeterPainter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin{
  late AnimationController _controller;
  late Animation<double> _needleAnimation;

  int _channel = 1;
  bool ocupado = true;
  StreamSubscription? _mRecordingDataSubscription;
  Timer? _inactivityTimer;

  final FlutterSoundRecorder _mRecorder = FlutterSoundRecorder();
  String chNow = "0";
  var channel = WebSocketChannel.connect(
    Uri.parse('ws://168.138.149.216:7070/websocket'),
  );
  void _handleInactivity(int channel) {
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        chNow = chNow.replaceAll(channel.toString(), ""); // Remove o canal da string
        if (chNow.isEmpty) {
          // Se não houver mais canais ativos, você pode executar outras ações aqui
        }
      });
    });
  }

  void _changeChannel(int newChannel) {
    setState(() {
      _channel = newChannel;
    });
  }


  Future<void> _ligarMicrofone() async {

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }

    await _mRecorder.openRecorder();
    var recordingDataController = StreamController<Food>();
    _mRecordingDataSubscription = recordingDataController.stream.listen((buffer) {
          if (buffer is FoodData) {
            int maxValue = buffer.data!.reduce(max);
            int minValue = buffer.data!.reduce(min);
            double amplitude = (maxValue - minValue).toDouble();
            print(amplitude);
            updateMeter(amplitude);
            String base64Data = base64Encode(buffer.data!);
            var packet = AudioPacket(_channel, base64Data);
            channel.sink.add(jsonEncode(packet.toJson()));
          }
    });
    await _mRecorder.startRecorder(
      toStream: recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 22100,
    );

  }
  void _desligarMicrofone() async {
    updateMeter(0);
    // Cancela a inscrição para parar a gravação
    _mRecordingDataSubscription?.cancel();
    await _mRecorder.closeRecorder();
    await _mRecorder.stopRecorder();
  }
  void updateMeter(double value) {
    _needleAnimation = Tween<double>(begin: _needleAnimation.value, end: value / 255).animate(_controller);
    _controller.forward(from: 0);
  }
  @override
  void initState(){
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this, //<this = esta classe como um todo
    );

    _needleAnimation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    FlutterSoundPlayer player = FlutterSoundPlayer();

    player.openPlayer(enableVoiceProcessing: false).then((value) {

      player.startPlayerFromStream(codec: Codec.pcm16, numChannels:1, sampleRate: 22100).then((value) {
        channel.stream.listen((event) async {

          var packet = AudioPacket.fromJson(jsonDecode(event));

          if (packet.channel == _channel) {
            Uint8List audioData = base64Decode(packet.data);// 'selectedChannel' é o canal escolhido pelo usuário
            player.foodSink!.add(FoodData(audioData));
          } else {
            if(chNow != packet.channel.toString()){
              setState(() {
                chNow = chNow + packet.channel.toString();

              });
              _handleInactivity(packet.channel);
            }
          }
        },onError: (error) {
          setState(() {
            ocupado = true;
          });
          Fluttertoast.showToast(
              msg: "Houve um erro ao tentar conectar ao servidor.",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0
          );
        },onDone: () {
          setState(() {
            ocupado = true;
          });
          Fluttertoast.showToast(
              msg: "Conexão encerrada.",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0
          );
        });
      });
    });

    Future.delayed(const Duration(seconds: 2)).then((value) {
      setState(() {
        ocupado = false;
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HT Radio Simulator'),
        backgroundColor: Colors.grey[850],
      ),
      body: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Icon(Icons.settings_input_antenna, size: 60, color: Colors.white),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Canal: $_channel',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CustomPaint(
                  painter: VUMeterPainter(_needleAnimation.value),
                  child: Container(width: 300, height: 150),
                ),
              ],
            ),
            Expanded(
              child: GridView.builder(
                itemCount: 9,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                itemBuilder: (BuildContext context, int index) {

                  return GestureDetector(
                    onTap: () => _changeChannel(index + 1),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 500),
                      decoration: BoxDecoration(
                        color:  chNow.contains((index + 1).toString()) ? Colors.blue : Colors.blueGrey[800],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Card(
                        color: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 24, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
           Opacity(
             opacity: ocupado == true ? 0.5 : 1,
             child: ocupado == true ? Container(
               decoration: const BoxDecoration(
                 color: Colors.red, // cor de fundo
                 shape: BoxShape.circle, // forma circular
               ),
               padding: const EdgeInsets.all(24), // preenchimento
               child: const Icon(
                 Icons.radio_button_checked,
                 color: Colors.white, // cor do ícone
               ),
             ) : GestureDetector(
               onLongPress: () {
                 if (!ocupado) {
                   _ligarMicrofone();
                 }
               },
               onLongPressUp: () {
                 _desligarMicrofone();
               },
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.red,
                   shape: const CircleBorder(),
                   padding: const EdgeInsets.all(24),
                 ),
                 onPressed: () {  }, // Mantenha este vazio se não for necessário um comportamento para um clique rápido.
                 child: const Icon(Icons.radio_button_checked, color: Colors.white),
               ),
             ),
           )
          ],
        ),
      ),
    );
  }
}


