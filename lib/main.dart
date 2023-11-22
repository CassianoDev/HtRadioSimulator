import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
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
  double gain = 0.5; // Defina o ganho desejado aqui

  double meterlevel = 0;
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
    double lastRMS = 0.0;
    double alpha = 0.1; // Fator de suavização
    var recordingDataController = StreamController<Food>();
    _mRecordingDataSubscription = recordingDataController.stream.listen((buffer) {
          if (buffer is FoodData) {
            Uint8List audioSamples = buffer.data!;
            // Aplicando o ganho às amostras de áudio
            for (int i = 0; i < audioSamples.length; i += 2) {

              int sample = (audioSamples[i + 1] << 8) | audioSamples[i];
              if (sample > 32767) sample -= 65536;

              double amplifiedSample = sample * (gain * 1.5);
              amplifiedSample = max(-32768, min(amplifiedSample, 32767));

              audioSamples[i] = amplifiedSample.toInt() & 0xFF;
              audioSamples[i + 1] = (amplifiedSample.toInt() >> 8) & 0xFF;
            }

            // Calcula o número total de amostras.
            // Cada amostra PCM16 tem 2 bytes, então dividimos por 2 para obter o número de amostras.
            int numSamples = audioSamples.length ~/ 2;

            double sumOfSquares = 0.0;

            // Itera sobre cada amostra de áudio.
            for (int i = 0; i < numSamples; i++) {
              // Calcula o índice da amostra atual no array Uint8List.
              int sampleIndex = i * 2;

              // Converte duas entradas de 8 bits (bytes) em uma amostra de 16 bits.
              // Isso é feito deslocando o segundo byte 8 bits para a esquerda e fazendo um OR com o primeiro byte.
              int sample = (audioSamples[sampleIndex + 1] << 8) | audioSamples[sampleIndex];

              // Corrige a representação de sinal se a amostra for um número negativo.
              // Em PCM16, -os valores variam de 32768 a 32767.
              // Subtrair 65536 de valores acima de 32767 os converte corretamente.
              if (sample > 32767) sample -= 65536;

              // Adiciona o quadrado da amostra ao somatório.
              sumOfSquares += pow(sample, 2);

            }

            // Calcula a média dos quadrados das amostras.
            double meanSquare = sumOfSquares / numSamples;

            // Calcula a raiz quadrada da média, que é o valor RMS.
            double rms = sqrt(meanSquare);

            lastRMS = alpha * rms + (1 - alpha) * lastRMS;

            updateMeter(mapRmsToVU(lastRMS));
            String base64Data = base64Encode(buffer.data!);
            var packet = AudioPacket(_channel, base64Data);
            channel.sink.add(jsonEncode(packet.toJson()));
          }
    });
    await _mRecorder.startRecorder(
      toStream: recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 22100, //<< 22.1Khz 20hz - 20Khz
    );

  }
  void _desligarMicrofone() async {
    updateMeter(0);
    // Cancela a inscrição para parar a gravação
    _mRecordingDataSubscription?.cancel();
    await _mRecorder.closeRecorder();
    await _mRecorder.stopRecorder();
  }
  int mapRmsToVU(double rmsValue) {
    double minRms = 100;
    double maxRms = 20000;
    double minVU = 0;
    double maxVU = 255;

    // Calcula o valor mapeado
    double mappedValue = (rmsValue - minRms) * (maxVU - minVU) / (maxRms - minRms);

    // Garante que o valor está dentro do intervalo de 0 a 255
    return max(0, min(mappedValue.round(), 255));
  }
  void updateMeter(int value) {
    setState(() {
      meterlevel = value.toDouble();
    });
  }
  @override
  void initState(){
    Timer? resetTimer;
    super.initState();
    FlutterSoundPlayer player = FlutterSoundPlayer();
    player.openPlayer(enableVoiceProcessing: false).then((value) {
      double lastRMS = 0.0;
      double alpha = 0.1; // Fator de suavização
      player.startPlayerFromStream(codec: Codec.pcm16, numChannels:1, sampleRate: 22100).then((value) {
        channel.stream.listen((event) async {

          var packet = AudioPacket.fromJson(jsonDecode(event));

          if (packet.channel == _channel) {
            Uint8List audioData = base64Decode(packet.data);// 'selectedChannel' é o canal escolhido pelo usuário
            // Calcula o número total de amostras.
            // Cada amostra PCM16 tem 2 bytes, então dividimos por 2 para obter o número de amostras.
            int numSamples = audioData.length ~/ 2;
            double sumOfSquares = 0.0;

            // Itera sobre cada amostra de áudio.
            for (int i = 0; i < numSamples; i++) {
              // Calcula o índice da amostra atual no array Uint8List.
              int sampleIndex = i * 2;

              // Converte duas entradas de 8 bits (bytes) em uma amostra de 16 bits.
              // Isso é feito deslocando o segundo byte 8 bits para a esquerda e fazendo um OR com o primeiro byte.
              int sample = (audioData[sampleIndex + 1] << 8) | audioData[sampleIndex];

              // Corrige a representação de sinal se a amostra for um número negativo.
              // Em PCM16, os valores variam de -32768 a 32767.
              // Subtrair 65536 de valores acima de 32767 os converte corretamente.
              if (sample > 32767) sample -= 65536;

              // Adiciona o quadrado da amostra ao somatório.
              sumOfSquares += pow(sample, 2);
            }

            // Calcula a média dos quadrados das amostras.
            double meanSquare = sumOfSquares / numSamples;

            // Calcula a raiz quadrada da média, que é o valor RMS.
            double rms = sqrt(meanSquare);

            lastRMS = alpha * rms + (1 - alpha) * lastRMS;
            updateMeter(mapRmsToVU(lastRMS));
            player.foodSink!.add(FoodData(audioData));
            // Reinicia o temporizador a cada novo dado recebido
            resetTimer?.cancel();
            resetTimer = Timer(const Duration(milliseconds:100), () {
              // Código para resetar o VU
              updateMeter(mapRmsToVU(0));
            });

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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SfSlider.vertical(
                  value: gain,
                  onChanged: (dynamic newValue){
                    setState(() {
                      gain = newValue;
                    });
                  },
                ),
                Container(
                    width: 200,
                    height: 190,
                    child: SfRadialGauge(
                        enableLoadingAnimation: true, animationDuration: 2500,
                        axes: <RadialAxis>[
                          RadialAxis(minimum: 0, maximum: 110,startAngle:180,endAngle: 360,
                            axisLabelStyle: const GaugeTextStyle(
                              color: Colors.white70, // Cor dos números
                              fontSize: 12, // Tamanho da fonte
                              // Outras propriedades de estilo, como fontWeight, fontFamily, etc.
                            ),
                            ranges: <GaugeRange>[
                              GaugeRange(startValue: 0, endValue: 60, color:Colors.blueAccent),
                              GaugeRange(startValue: 60, endValue: 90, color:Colors.blue,endWidth: 15,),
                              GaugeRange(startValue: 90,endValue: 110,color: Colors.red,startWidth: 15,endWidth: 20,)],
                            pointers: <GaugePointer>[
                              NeedlePointer(value: meterlevel,needleColor: Colors.white70,enableAnimation: false,animationDuration: 300,)
                            ],

                          )]
                    )
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


class RMSBuffer {
  final Queue<double> _buffer;
  final int size;

  RMSBuffer(this.size) : _buffer = Queue<double>();

  void add(double value) {
    if (_buffer.length == size) {
      _buffer.removeFirst();
    }
    _buffer.addLast(value);
  }

  double get average => _buffer.isNotEmpty ? _buffer.reduce((a, b) => a + b) / _buffer.length : 0.0;
}