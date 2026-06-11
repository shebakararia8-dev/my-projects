import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_manager.dart';

class MedicalRecordsPage extends StatefulWidget {
  const MedicalRecordsPage({super.key});

  @override
  State<MedicalRecordsPage> createState() => _MedicalRecordsPageState();
}

class _MedicalRecordsPageState extends State<MedicalRecordsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> _medicalHistory;
  late Future<Map<String, dynamic>> _prescriptions;
  late Future<Map<String, dynamic>> _testResults;
  late Future<Map<String, dynamic>> _allergies;
  late Future<Map<String, dynamic>> _medications;

  static final Map<String, dynamic> _notLoggedIn = {
    'success': false,
    'message': 'Not logged in',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _medicalHistory = Future.value(_notLoggedIn);
    _prescriptions = Future.value(_notLoggedIn);
    _testResults = Future.value(_notLoggedIn);
    _allergies = Future.value(_notLoggedIn);
    _medications = Future.value(_notLoggedIn);
    _loadMedicalRecords();
  }

  void _loadMedicalRecords() async {
    final email = await TokenManager.getUserEmail();
    final token = await TokenManager.getToken();

    if (email != null && token != null) {
      setState(() {
        _medicalHistory = ApiService.getMedicalHistory(
          patientEmail: email,
          authToken: token,
        );
        _prescriptions = ApiService.getPrescriptions(
          patientEmail: email,
          authToken: token,
        );
        _testResults = ApiService.getTestResults(
          patientEmail: email,
          authToken: token,
        );
        _allergies = ApiService.getAllergies(
          patientEmail: email,
          authToken: token,
        );
        _medications = ApiService.getMedications(
          patientEmail: email,
          authToken: token,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Medications'),
            Tab(text: 'Prescriptions'),
            Tab(text: 'Test Results'),
            Tab(text: 'Allergies'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMedicalHistoryTab(),
          _buildMedicationsTab(),
          _buildPrescriptionsTab(),
          _buildTestResultsTab(),
          _buildAllergiesTab(),
        ],
      ),
    );
  }

  Widget _buildMedicalHistoryTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _medicalHistory,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data?['success'] != true) {
          return Center(
            child: Text('Error: ${snapshot.data?['message'] ?? 'Unknown error'}'),
          );
        }

        final List<dynamic> history = snapshot.data?['history'] ?? [];
        if (history.isEmpty) {
          return const Center(child: Text('No medical history found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(item['condition'] ?? 'Unknown'),
                subtitle: Text(
                  'Status: ${item['status'] ?? 'Unknown'}\n'
                  'Diagnosed: ${item['diagnosis_date'] ?? 'Unknown'}',
                ),
                trailing: const Icon(Icons.medical_information),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMedicationsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _medications,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data?['success'] != true) {
          return Center(
            child: Text('Error: ${snapshot.data?['message'] ?? 'Unknown error'}'),
          );
        }

        final List<dynamic> medications = snapshot.data?['medications'] ?? [];
        if (medications.isEmpty) {
          return const Center(child: Text('No medications found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: medications.length,
          itemBuilder: (context, index) {
            final med = medications[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(med['medication_name'] ?? 'Unknown'),
                subtitle: Text(
                  'Dosage: ${med['dosage'] ?? 'Unknown'}\n'
                  'Frequency: ${med['frequency'] ?? 'Unknown'}',
                ),
                trailing: const Icon(Icons.medication),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrescriptionsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _prescriptions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data?['success'] != true) {
          return Center(
            child: Text('Error: ${snapshot.data?['message'] ?? 'Unknown error'}'),
          );
        }

        final List<dynamic> prescriptions = snapshot.data?['prescriptions'] ?? [];
        if (prescriptions.isEmpty) {
          return const Center(child: Text('No prescriptions found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: prescriptions.length,
          itemBuilder: (context, index) {
            final rx = prescriptions[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(rx['medication'] ?? 'Unknown'),
                subtitle: Text(
                  'Prescribed by: ${rx['doctor_name'] ?? 'Unknown'}\n'
                  'Refills: ${rx['refills_remaining'] ?? 0}',
                ),
                trailing: const Icon(Icons.description),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTestResultsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _testResults,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data?['success'] != true) {
          return Center(
            child: Text('Error: ${snapshot.data?['message'] ?? 'Unknown error'}'),
          );
        }

        final List<dynamic> results = snapshot.data?['results'] ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('No test results found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final test = results[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(test['test_name'] ?? 'Unknown'),
                subtitle: Text(
                  'Result: ${test['result_value'] ?? 'Unknown'} ${test['unit'] ?? ''}\n'
                  'Status: ${test['status'] ?? 'Unknown'}',
                ),
                trailing: const Icon(Icons.assignment),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAllergiesTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _allergies,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data?['success'] != true) {
          return Center(
            child: Text('Error: ${snapshot.data?['message'] ?? 'Unknown error'}'),
          );
        }

        final List<dynamic> allergies = snapshot.data?['allergies'] ?? [];
        if (allergies.isEmpty) {
          return const Center(child: Text('No allergies found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allergies.length,
          itemBuilder: (context, index) {
            final allergy = allergies[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: _getSeverityColor(allergy['severity'] ?? 'mild'),
              child: ListTile(
                title: Text(allergy['allergen'] ?? 'Unknown'),
                subtitle: Text(
                  'Reaction: ${allergy['reaction'] ?? 'Unknown'}\n'
                  'Severity: ${allergy['severity'] ?? 'Unknown'}',
                ),
                trailing: const Icon(Icons.warning),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return Colors.red.shade100;
      case 'moderate':
        return Colors.orange.shade100;
      default:
        return Colors.yellow.shade100;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
