import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:async';

// Buffer to accumulate incomplete JSON data
String _buffer = '';

// Function to handle partial JSON updates
void _handlePartialJson(String rawJson, Function(double) onDataReceived) {
  print('Handling partial JSON data...');

  // Append the new data chunk to the buffer
  _buffer += rawJson;

  // Try to decode the accumulated buffer
  try {
    // Attempt to parse the accumulated buffer
    var parsedData = jsonDecode(_buffer);

    // Process the parsed data
    List<double> totalAccelG = List<double>.from(
        parsedData.map((entry) => entry['total_acceleration_g']));
    double gForce = totalAccelG.reduce((a, b) => a + b) / totalAccelG.length;

    print('Complete data processed. G-force = $gForce');

    // Call the onDataReceived callback to update the UI
    onDataReceived(gForce);

    // Clear the buffer after successful parsing
    _buffer = '';
  } catch (e) {
    // If parsing fails, print the error but do not clear the buffer
    // This likely means the JSON is incomplete and more data is coming
    print('Error parsing JSON: $e');
  }
}

Future<void> fetchSensorData(
    Function(double) onDataReceived, Function(String) onStatusUpdate) async {
  HttpClient client = HttpClient();
  try {
    print('Attempting to connect to Pico W for streaming...');

    final request = await client.getUrl(Uri.parse('http://192.168.4.1/events'));
    print('Request created successfully.');

    final response = await request.close();
    print('Response received. Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      print('Successfully connected to Pico W.');
      onStatusUpdate("connected");

      // Listen to the stream and process data as it comes in
      await response.listen(
        (data) {
          final message = String.fromCharCodes(data);
          print('Data chunk received: $message');

          // Use _handlePartialJson() to handle the streamed data and buffer it
          try {
            _handlePartialJson(message, onDataReceived);
          } catch (parseError) {
            print('Error handling partial JSON: $parseError');
          }
        },
        onError: (e) {
          print('Stream error: $e');
        },
        onDone: () {
          print('Stream closed.');
          onStatusUpdate("disconnected");
        },
        cancelOnError: true,
      ).asFuture();

      print('Stream finished successfully.');
    } else {
      print('Failed to connect to Pico W. Status Code: ${response.statusCode}');
      onStatusUpdate("disconnected");
    }
  } catch (e) {
    print('Error connecting to Pico W: $e');
    onStatusUpdate("disconnected");
  } finally {
    print('Closing the client.');
    client.close(); // Close the client when done
  }
}
