import 'package:flutter/material.dart';
import 'package:headshotx/configuration_page.dart';
import 'package:headshotx/head_gear_page.dart';
import 'package:headshotx/sensor_data.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:percent_indicator/circular_percent_indicator.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _timer;
  String userName = "Ricky B.";
  String detectedM = "";
  String detectedL = "";
  String detectedH = '';
  int totalHits = 0;
  double totalGForce = 0.0; // Accumulate total G-force here
  double gForce = 0.0;
  int highImpact = 0;
  int mediumImpact = 0;
  int lowImpact = 0;
  int _seconds = 0;
  int heightFt = 0;
  int heightInch = 0;
  bool isConnected = false;
  String status = "not connected";
  int weight = 0;
  int age = 0;
  bool _isRunning = false;
  bool _isStopped = false;

  // Function to show the dialog for editing stats
  void _showEditDialog() {
    TextEditingController weightController =
        TextEditingController(text: '$weight');
    TextEditingController heightFtController =
        TextEditingController(text: '$heightFt');
    TextEditingController heightInchController =
        TextEditingController(text: '$heightInch');
    TextEditingController ageController = TextEditingController(text: '$age');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Fighter Stats'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                decoration: InputDecoration(labelText: 'Weight (lbs)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: heightFtController,
                decoration: InputDecoration(labelText: 'Height (feet)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: heightInchController,
                decoration: InputDecoration(labelText: 'Height (inches)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: ageController,
                decoration: InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  weight = int.parse(weightController.text);
                  heightFt = int.parse(heightFtController.text);
                  heightInch = int.parse(heightInchController.text);
                  age = int.parse(ageController.text);
                });
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Function to format the time as hh:mm:ss
  String _formatTime(int seconds) {
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    print('Initializing connection to fetch sensor data...');
    _startFetchingSensorData(); // Start fetching data when the app starts
  }

  void _startFetchingSensorData() async {
    try {
      print('Sending request to Pico W...');
      final request =
          http.Request('GET', Uri.parse('http://192.168.4.1/events'));
      final response = await request.send();

      print('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        setState(() {
          status = "connected";
        });
        print('Successfully connected to Pico W.');

        // Listen to the stream and process data as it comes in
        await response.stream.listen((data) {
          final message = String.fromCharCodes(data);
          print('Data chunk received: $message');
          _handlePartialJson(
              message, updateData); // Pass updateData as the callback
        }).asFuture(); // Wait for the stream to finish
      } else {
        setState(() {
          status = "disconnected";
        });
        print('Disconnected: Status code ${response.statusCode}');
      }
    } catch (e) {
      print('Error connecting to Pico W: $e');
      setState(() {
        status = "disconnected";
      });
      // Retry after a short delay
      Future.delayed(Duration(seconds: 3), () {
        _startFetchingSensorData(); // Retry connecting after 3 seconds
      });
    }
  }

// Function to handle partial JSON updates
  void _handlePartialJson(String rawJson, Function(double) onDataReceived) {
    print('Handling partial JSON data: $rawJson');

    // Strip the 'data: ' prefix if present
    if (rawJson.startsWith('data: ')) {
      rawJson = rawJson.substring(6); // Remove the 'data: ' part
    }

    // Try to decode the accumulated buffer
    try {
      // Parse the JSON
      var parsedData = jsonDecode(rawJson);

      // Process the parsed data
      List<double> totalAccelG = List<double>.from(
          parsedData.map((entry) => entry['total_acceleration_g']));
      double gForce = totalAccelG.reduce((a, b) => a + b) / totalAccelG.length;

      print('Complete data processed. G-force = $gForce');

      // Call the onDataReceived callback to update the UI
      onDataReceived(gForce);
    } catch (e) {
      // If parsing fails, print the error
      print('Error processing partial JSON: $e');
    }
  }

  void updateData(double newGForce) {
    bool updateRequired = false;

    // Accumulate G-force and gyro data if there is a meaningful change
    if (newGForce >= 2) {
      gForce = newGForce;
      totalGForce += newGForce;
      updateRequired = true;

      if (gForce >= 50) {
        highImpact++;
        detectedH = 'High impact detected. gForce = $gForce';
      } else if (gForce >= 25) {
        mediumImpact++;
        detectedM = 'Medium impact detected. gForce = $gForce';
      } else if (gForce >= 2) {
        lowImpact++;
        detectedL = 'Low impact detected. gForce = $gForce';
      }
      totalHits++;
    }

    // Only update UI when required
    if (updateRequired) {
      setState(() {}); // Trigger a rebuild of the UI
    }
  }

  double calculateProgressBarPercentage() {
    // Assuming 1000 G is the maximum value for the progress bar.
    double maxGForce = 1000.0;

    // Check if totalGForce surpasses the threshold
    if (totalGForce > maxGForce) {
      // Show alert box
      _showAlertDialog();
    }

    // Return the progress percentage (clamp between 0.0 and 1.0)
    return (totalGForce / maxGForce).clamp(0.0, 1.0);
  }

  void _showAlertDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Warning!"),
          content: Text(
              "The cumulative G-force has surpassed 1000 Gs! Serious health risk detected, it is advised you stop the spar now!"),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  double calculateImpactProgress(int impactCount) {
    if (totalHits == 0) return 0.0;
    return (impactCount / totalHits)
        .clamp(0.0, 1.0); // Ensuring value is between 0 and 1
  }

  // Function to start the timer
  void _startTimer() {
    if (_isRunning) return; // Prevent multiple timers from starting
    setState(() {
      _isRunning = true;
      _isStopped = false;
    });
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  // Function to stop the timer
  void _stopTimer() {
    if (_isRunning) {
      _timer.cancel();
      setState(() {
        _isRunning = false;
        _isStopped = true;
      });
    }
  }

  // Function to reset the timer
  void _resetTimer() {
    setState(() {
      _seconds = 0;
      _isStopped = false;
    });
  }

  @override
  void dispose() {
    if (_isRunning) {
      _timer
          .cancel(); // Ensure the timer is stopped when the widget is disposed
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Add the AppBar with a dynamic title and profile icon
      appBar: AppBar(
        title: Text(
          userName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 30,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.blue,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue, // Blue at the top
              Colors.black, // Black at the bottom
            ],
            stops: [0.0, 0.25], // Gradient transition points
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment
                .start, // Align the content to the start of the page
            children: [
              // First container with overall impact graph
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0), // Add padding to the sides
                child: Container(
                  padding: const EdgeInsets.only(left: 20.0, top: 15),
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 28, 28, 30),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Row(
                    children: [
                      // Column for text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overall Impact',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Total hits: ${totalHits}',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      // Circular Graph with text in the center using CircularPercentIndicator
                      Container(
                        margin: EdgeInsets.only(
                            right: 20,
                            bottom: 20), // Optional margin for spacing
                        child: CircularPercentIndicator(
                          radius:
                              50.0, // This controls the size of the circular graph
                          lineWidth: 6.0,
                          percent:
                              calculateProgressBarPercentage(), // Calculate the percentage (0.0 to 1.0) and ensure it's between 0 and 1
                          center: Text(
                            "${totalGForce.toStringAsFixed(1)}g", // Display the gForce value with 1 decimal place
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          progressColor: Color.fromARGB(255, 11, 234,
                              22), // Color of the progress indicator
                          backgroundColor:
                              Colors.grey, // Background circle color
                          circularStrokeCap:
                              CircularStrokeCap.round, // Rounded stroke edges
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              // Second container for Round Clock (with Timer and Buttons)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0), // Add padding to the sides
                child: Container(
                  padding: const EdgeInsets.only(left: 20.0, top: 15),
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 28, 28, 30),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Round Clock',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      // Timer in the center
                      Center(
                        child: Text(
                          _formatTime(_seconds), // Display the formatted timer
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30, // Timer font size
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // Buttons for Start and Stop/Reset
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _startTimer,
                            child: Text(
                              'Start',
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue, // Button color
                            ),
                          ),
                          SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: _isStopped ? _resetTimer : _stopTimer,
                            child: Text(
                              _isStopped ? 'Reset' : 'Stop',
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue, // Button color
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              // Third container with High Impact title, progress bar, and high impact count
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0), // Add padding to the sides
                child: Container(
                  padding: const EdgeInsets.only(
                      left: 20.0,
                      top: 15,
                      right: 20.0), // Added padding on the right
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 28, 28, 30),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row to align title and high impact count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Title "High Impact"
                          Text(
                            'High Impact',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          // High Impact Count on the same row
                          Text(
                            '$highImpact', // Display the high impact count
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      // Red horizontal progress bar wrapped inside a container to adjust thickness
                      ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(
                            20)), // Circular border for the progress bar
                        child: Container(
                          height:
                              10, // Set the thickness of the progress bar here
                          child: LinearProgressIndicator(
                            value: calculateImpactProgress(
                                highImpact), // Set the progress value here (0.0 to 1.0)
                            color: Colors.red, // Red color for the progress bar
                            backgroundColor:
                                Colors.grey, // Background color for the bar
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0), // Add padding to the sides
                child: Container(
                  padding:
                      const EdgeInsets.only(left: 20.0, top: 15, right: 20.0),
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 28, 28, 30),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Medium Impact',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$mediumImpact', // Display the high impact count
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        child: Container(
                          height: 10,
                          child: LinearProgressIndicator(
                            value: calculateImpactProgress(mediumImpact),
                            color: Colors.yellow, // Yellow for medium impact
                            backgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              // Fifth container for Low Impact
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0), // Add padding to the sides
                child: Container(
                  padding:
                      const EdgeInsets.only(left: 20.0, top: 15, right: 20.0),
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 28, 28, 30),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Low Impact',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$lowImpact',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        child: Container(
                          height: 10,
                          child: LinearProgressIndicator(
                            value: calculateImpactProgress(lowImpact),
                            color: Colors.green, // Green for low impact
                            backgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              // Fighter Stats container with "Edit" clickable text
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0), // Add padding to the sides
                child: Container(
                  padding: const EdgeInsets.only(
                      left: 20.0, top: 15, right: 20.0, bottom: 15.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 28, 28, 30),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row for Fighter Stats title and "Edit" button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fighter Stats',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _showEditDialog(); // Show the edit dialog
                            },
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        ],
                      ),
                      SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Weight',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '${weight} lbs',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Height',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '${heightFt}\' ${heightInch}"',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Age',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "${age}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home,
              color: Colors.white,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.health_and_safety,
              color: Colors.white,
            ),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              color: Colors.white,
            ),
            label: 'Config',
          ),
        ],
        unselectedItemColor: Colors.white,
        selectedItemColor: Colors.white,
        onTap: (int index) {
          if (index == 0) {
            // Navigate to Home Page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else if (index == 1) {
            // Navigate to Head Gear Page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HeadGearPage()),
            );
          } else if (index == 2) {
            // Navigate to Configuration Page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ConfigurationPage()),
            );
          }
        },
      ),
    );
  }
}
