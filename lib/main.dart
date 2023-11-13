import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  String _frequency = "146.520";

  void _changeFrequency(String newFrequency) {
    setState(() {
      _frequency = newFrequency;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HT Radio Simulator'),
        backgroundColor: Colors.grey[850],
      ),
      body: Container(
        color: Colors.black87,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Icon(Icons.settings_input_antenna, size: 60, color: Colors.white),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Frequency: $_frequency MHz',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Expanded(
              child: GridView.builder(
                itemCount: 9,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                itemBuilder: (BuildContext context, int index) {
                  return GestureDetector(
                    onTap: () => _changeFrequency('146.52${index + 1}'),
                    child: Card(
                      color: Colors.blueGrey[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(fontSize: 24, color: Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              child: Icon(Icons.radio_button_checked, color: Colors.white),
              style: ElevatedButton.styleFrom(
                primary: Colors.red,
                shape: CircleBorder(),
                padding: EdgeInsets.all(24),
              ),
            ),
            Icon(Icons.volume_up, size: 60, color: Colors.white),
          ],
        ),
      ),
    );
  }


}
