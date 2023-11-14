import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mic_stream/mic_stream.dart';

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

class _MyHomePageState extends State<MyHomePage> {
  String _channel = "1";
  bool ocupado = true;
  StreamSubscription<List<int>>? _audioSubscription;

  void _changeChannel(String newChannel) {
    setState(() {
      _channel = newChannel;
    });
  }

  Future<void> _ligarMicrofone() async {
    // Inicia a captura de áudio do microfone com uma taxa de amostragem específica
    Stream<Uint8List>? audioStream = await MicStream.microphone(sampleRate: 44100);

    // Ouve o stream de áudio
    _audioSubscription = audioStream?.listen((samples) {
      print(samples);
    });
  }
  void _desligarMicrofone() {
    // Cancela a inscrição para parar a gravação
    _audioSubscription?.cancel();
  }
  @override
  void initState(){
    super.initState();
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
            Expanded(
              child: GridView.builder(
                itemCount: 9,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                itemBuilder: (BuildContext context, int index) {
                  return GestureDetector(
                    onTap: () => _changeChannel('${index + 1}'),
                    child: Card(
                      color: Colors.blueGrey[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 24, color: Colors.white),
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
