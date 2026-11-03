import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() {
  runApp(const AudisatApp());
}

class AudisatApp extends StatelessWidget {
  const AudisatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audisat X80 Plus Controller',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const BluetoothScanScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al escanear: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Audisat X80 Plus'),
        actions: [
          if (_isScanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startScan,
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          final result = _scanResults[index];
          final name = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : 'Dispositivo Desconocido';
          
          return ListTile(
            title: Text(name),
            subtitle: Text(result.device.remoteId.toString()),
            trailing: ElevatedButton(
              child: const Text('Conectar'),
              onPressed: () async {
                await FlutterBluePlus.stopScan();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ControlScreen(device: result.device),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? () => FlutterBluePlus.stopScan() : _startScan,
        label: Text(_isScanning ? 'Detener Búsqueda' : 'Escanear Bluetooth'),
        icon: Icon(_isScanning ? Icons.stop : Icons.radar),
      ),
    );
  }
}

class ControlScreen extends StatefulWidget {
  final BluetoothDevice device;
  const ControlScreen({super.key, required this.device});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  BluetoothCharacteristic? _targetCharacteristic;
  bool _isConnected = false;
  Color _currentColor = Colors.red;

  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }

  Future<void> _connectToDevice() async {
    try {
      await widget.device.connect();
      setState(() {
        _isConnected = true;
      });

      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            _targetCharacteristic = characteristic;
            break;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  Future<void> _sendColorCommand(Color color) async {
    if (_targetCharacteristic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Característica de escritura Bluetooth no encontrada')),
      );
      return;
    }

    List<int> packet = [0xAA, color.red, color.green, color.blue, 0x55];

    try {
      await _targetCharacteristic!.write(packet);
      setState(() {
        _currentColor = color;
      });
    } catch (e) {
      print('Error al enviar comando: $e');
    }
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName.isNotEmpty ? widget.device.platformName : 'Audisat X80 Plus'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Control de Luces LED',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ColorPicker(
              pickerColor: _currentColor,
              onColorChanged: (color) => _sendColorCommand(color),
              colorPickerWidth: 300.0,
              pickerAreaHeightPercent: 0.7,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsv,
            ),
            const SizedBox(height: 30),
            const Text(
              'Modos Preestablecidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Modo Estrobo'),
                  onPressed: () => _sendColorCommand(const Color(0xFFFFFF00)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.music_note),
                  label: const Text('Ritmo Musical'),
                  onPressed: () => _sendColorCommand(const Color(0xFF00FFFF)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.palette),
                  label: const Text('Transición RGB'),
                  onPressed: () => _sendColorCommand(const Color(0xFFFF00FF)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('Apagar Luces'),
                  onPressed: () => _sendColorCommand(const Color(0xFF000000)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
