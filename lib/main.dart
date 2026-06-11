import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'screens/billing_page.dart';
import 'screens/medical_records_page.dart';
import 'screens/messages_page.dart';
import 'screens/recommendations_page.dart';

class AppDatabase {
  AppDatabase._privateConstructor();
  static final AppDatabase instance = AppDatabase._privateConstructor();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, 'hospital_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_name TEXT,
        doctor_specialty TEXT,
        doctor_room TEXT,
        doctor_availability TEXT,
        doctor_phone TEXT,
        doctor_bio TEXT,
        doctor_practice TEXT,
        doctor_rating REAL,
        doctor_review_count INTEGER,
        doctor_distance TEXT,
        doctor_insurance TEXT,
        doctor_telehealth INTEGER,
        patient_name TEXT,
        reason TEXT,
        date_time TEXT,
        booked_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE doctor_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_name TEXT NOT NULL,
        reviewer TEXT NOT NULL,
        rating REAL NOT NULL,
        comment TEXT,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE appointment_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointment_id INTEGER,
        status TEXT,
        cost REAL,
        cancellation_reason TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE medical_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_email TEXT NOT NULL,
        condition TEXT NOT NULL,
        diagnosis_date TEXT,
        status TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE medications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_email TEXT NOT NULL,
        medication_name TEXT NOT NULL,
        dosage TEXT,
        frequency TEXT,
        start_date TEXT,
        end_date TEXT,
        prescribed_by TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE allergies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_email TEXT NOT NULL,
        allergen TEXT NOT NULL,
        reaction TEXT,
        severity TEXT,
        date_added TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE prescriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_email TEXT NOT NULL,
        doctor_name TEXT NOT NULL,
        medication TEXT NOT NULL,
        dosage TEXT,
        instructions TEXT,
        date_issued TEXT,
        refills_remaining INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE test_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_email TEXT NOT NULL,
        test_name TEXT NOT NULL,
        result_value TEXT,
        unit TEXT,
        normal_range TEXT,
        date_tested TEXT,
        status TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_email TEXT NOT NULL,
        doctor_name TEXT NOT NULL,
        sender TEXT,
        message_text TEXT NOT NULL,
        timestamp TEXT,
        is_read INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_email TEXT NOT NULL,
        appointment_id INTEGER,
        amount REAL,
        payment_date TEXT,
        payment_method TEXT,
        status TEXT,
        insurance_coverage REAL,
        out_of_pocket REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE follow_up_recommendations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_email TEXT NOT NULL,
        doctor_name TEXT NOT NULL,
        recommendation TEXT NOT NULL,
        category TEXT,
        due_date TEXT,
        status TEXT
      )
    ''');
  }

  Future<int> createAppointment(Appointment appointment) async {
    final db = await database;
    return await db.insert('appointments', appointment.toMap());
  }

  Future<List<Appointment>> getAppointments({required String patientName}) async {
    final db = await database;
    final maps = await db.query(
      'appointments',
      where: 'patient_name = ?',
      whereArgs: [patientName],
      orderBy: 'date_time ASC',
    );
    return maps.map((m) => Appointment.fromMap(m)).toList();
  }

  Future<int> updateAppointment(Appointment appointment) async {
    final db = await database;
    return await db.update('appointments', appointment.toMap(), where: 'id = ?', whereArgs: [appointment.id]);
  }

  Future<int> deleteAppointment(int id) async {
    final db = await database;
    return await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> createPatient(Patient patient) async {
    final db = await database;
    return await db.insert('patients', patient.toMap());
  }

  Future<Patient?> getPatientByEmailAndPassword(String email, String password) async {
    final db = await database;
    final maps = await db.query('patients', where: 'email = ?', whereArgs: [email]);
    if (maps.isEmpty) return null;
    final patient = Patient.fromMap(maps.first);
    final hashed = _hashPassword(password, patient.passwordSalt);
    if (hashed == patient.passwordHash) return patient;
    return null;
  }

  Future<Patient?> getPatientByEmail(String email) async {
    final db = await database;
    final maps = await db.query('patients', where: 'email = ?', whereArgs: [email]);
    if (maps.isEmpty) return null;
    return Patient.fromMap(maps.first);
  }

  Future<int> createReview(String doctorName, DoctorReview review) async {
    final db = await database;
    return await db.insert('doctor_reviews', {
      'doctor_name': doctorName,
      'reviewer': review.reviewer,
      'rating': review.rating,
      'comment': review.comment,
      'date': review.date,
    });
  }

  Future<List<DoctorReview>> getReviewsForDoctor(String doctorName) async {
    final db = await database;
    final maps = await db.query('doctor_reviews', where: 'doctor_name = ?', whereArgs: [doctorName], orderBy: 'id DESC');
    return maps
        .map((m) => DoctorReview(
              reviewer: m['reviewer'] as String,
              rating: (m['rating'] as num).toDouble(),
              comment: m['comment'] as String? ?? '',
              date: m['date'] as String? ?? '',
            ))
        .toList();
  }

  // Medical History Methods
  Future<int> createMedicalHistory(String patientEmail, MedicalHistory history) async {
    final db = await database;
    return await db.insert('medical_history', {
      'patient_email': patientEmail,
      ...history.toMap(),
    });
  }

  Future<List<MedicalHistory>> getMedicalHistory(String patientEmail) async {
    final db = await database;
    final maps = await db.query('medical_history', where: 'patient_email = ?', whereArgs: [patientEmail]);
    return maps.map((m) => MedicalHistory(
      id: m['id'] as int?,
      condition: m['condition'] as String,
      diagnosisDate: DateTime.parse(m['diagnosis_date'] as String),
      status: m['status'] as String,
      notes: m['notes'] as String? ?? '',
    )).toList();
  }

  // Medication Methods
  Future<int> createMedication(String patientEmail, Medication medication) async {
    final db = await database;
    return await db.insert('medications', {
      'patient_email': patientEmail,
      ...medication.toMap(),
    });
  }

  Future<List<Medication>> getMedications(String patientEmail) async {
    final db = await database;
    final maps = await db.query('medications', where: 'patient_email = ?', whereArgs: [patientEmail]);
    return maps.map((m) => Medication(
      id: m['id'] as int?,
      name: m['medication_name'] as String,
      dosage: m['dosage'] as String,
      frequency: m['frequency'] as String,
      startDate: DateTime.parse(m['start_date'] as String),
      endDate: m['end_date'] != null ? DateTime.parse(m['end_date'] as String) : null,
      prescribedBy: m['prescribed_by'] as String? ?? '',
    )).toList();
  }

  // Allergy Methods
  Future<int> createAllergy(String patientEmail, Allergy allergy) async {
    final db = await database;
    return await db.insert('allergies', {
      'patient_email': patientEmail,
      ...allergy.toMap(),
    });
  }

  Future<List<Allergy>> getAllergies(String patientEmail) async {
    final db = await database;
    final maps = await db.query('allergies', where: 'patient_email = ?', whereArgs: [patientEmail]);
    return maps.map((m) => Allergy(
      id: m['id'] as int?,
      allergen: m['allergen'] as String,
      reaction: m['reaction'] as String,
      severity: m['severity'] as String,
      dateAdded: DateTime.parse(m['date_added'] as String),
    )).toList();
  }

  // Prescription Methods
  Future<int> createPrescription(String patientEmail, Prescription prescription) async {
    final db = await database;
    return await db.insert('prescriptions', {
      'patient_email': patientEmail,
      ...prescription.toMap(),
    });
  }

  Future<List<Prescription>> getPrescriptions(String patientEmail) async {
    final db = await database;
    final maps = await db.query('prescriptions', where: 'patient_email = ?', whereArgs: [patientEmail]);
    return maps.map((m) => Prescription(
      id: m['id'] as int?,
      doctorName: m['doctor_name'] as String,
      medication: m['medication'] as String,
      dosage: m['dosage'] as String,
      instructions: m['instructions'] as String,
      dateIssued: DateTime.parse(m['date_issued'] as String),
      refillsRemaining: m['refills_remaining'] as int? ?? 0,
    )).toList();
  }

  // Test Result Methods
  Future<int> createTestResult(String patientEmail, TestResult result) async {
    final db = await database;
    return await db.insert('test_results', {
      'patient_email': patientEmail,
      ...result.toMap(),
    });
  }

  Future<List<TestResult>> getTestResults(String patientEmail) async {
    final db = await database;
    final maps = await db.query('test_results', where: 'patient_email = ?', whereArgs: [patientEmail]);
    return maps.map((m) => TestResult(
      id: m['id'] as int?,
      testName: m['test_name'] as String,
      resultValue: m['result_value'] as String,
      unit: m['unit'] as String,
      normalRange: m['normal_range'] as String,
      dateTested: DateTime.parse(m['date_tested'] as String),
      status: m['status'] as String? ?? 'normal',
    )).toList();
  }

  // Message Methods
  Future<int> createMessage(String patientEmail, Message message) async {
    final db = await database;
    return await db.insert('messages', {
      'patient_email': patientEmail,
      ...message.toMap(),
    });
  }

  Future<List<Message>> getMessages(String patientEmail, String doctorName) async {
    final db = await database;
    final maps = await db.query('messages',
      where: 'patient_email = ? AND doctor_name = ?',
      whereArgs: [patientEmail, doctorName],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => Message(
      id: m['id'] as int?,
      doctorName: m['doctor_name'] as String,
      sender: m['sender'] as String,
      text: m['message_text'] as String,
      timestamp: DateTime.parse(m['timestamp'] as String),
      isRead: (m['is_read'] as int?) == 1,
    )).toList();
  }

  // Payment Methods
  Future<int> createPayment(String patientEmail, Payment payment) async {
    final db = await database;
    return await db.insert('payments', {
      'patient_email': patientEmail,
      ...payment.toMap(),
    });
  }

  Future<List<Payment>> getPayments(String patientEmail) async {
    final db = await database;
    final maps = await db.query('payments', where: 'patient_email = ?', whereArgs: [patientEmail]);
    return maps.map((m) => Payment(
      id: m['id'] as int?,
      appointmentId: m['appointment_id'] as int,
      amount: (m['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(m['payment_date'] as String),
      paymentMethod: m['payment_method'] as String,
      status: m['status'] as String? ?? 'completed',
      insuranceCoverage: (m['insurance_coverage'] as num?)?.toDouble() ?? 0.0,
      outOfPocket: (m['out_of_pocket'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  // Follow-up Recommendation Methods
  Future<int> createFollowUpRecommendation(String patientEmail, FollowUpRecommendation rec) async {
    final db = await database;
    return await db.insert('follow_up_recommendations', {
      'patient_email': patientEmail,
      ...rec.toMap(),
    });
  }

  Future<List<FollowUpRecommendation>> getFollowUpRecommendations(String patientEmail) async {
    final db = await database;
    final maps = await db.query('follow_up_recommendations',
      where: 'patient_email = ?',
      whereArgs: [patientEmail],
      orderBy: 'due_date ASC',
    );
    return maps.map((m) => FollowUpRecommendation(
      id: m['id'] as int?,
      doctorName: m['doctor_name'] as String,
      recommendation: m['recommendation'] as String,
      category: m['category'] as String,
      dueDate: DateTime.parse(m['due_date'] as String),
      status: m['status'] as String? ?? 'pending',
    )).toList();
  }
}

String _generateSalt() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  return base64Url.encode(bytes);
}

String _hashPassword(String password, String salt) {
  final key = utf8.encode(salt);
  final bytes = utf8.encode(password);
  final hmacSha256 = Hmac(sha256, key);
  return base64Url.encode(hmacSha256.convert(bytes).bytes);
}

String? _sessionEmail;

Future<void> saveSessionEmail(String email) async {
  _sessionEmail = email;
}

Future<String?> readSessionEmail() async => _sessionEmail;

Future<void> clearSession() async {
  _sessionEmail = null;
}

Set<String> _favoriteDoctorsStore = <String>{};

Future<Set<String>> readFavoriteDoctors() async => Set<String>.from(_favoriteDoctorsStore);

Future<void> writeFavoriteDoctors(Set<String> favorites) async {
  _favoriteDoctorsStore = Set<String>.from(favorites);
}
// (functions above provide read/write access to the in-memory favorites store)

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HospitalAppointmentApp());
}

class HospitalAppointmentApp extends StatelessWidget {
  const HospitalAppointmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hospital Appointment App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final patient = await AppDatabase.instance.getPatientByEmailAndPassword(email, password);

    if (!mounted) return;

    if (patient == null) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Invalid email or password. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await saveSessionEmail(patient.email);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    Navigator.of(this.context).pushReplacement(
      MaterialPageRoute(
        builder: (BuildContext context) => DashboardPage(patientName: patient.name),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text(
                  'Welcome Back',
                  style: Theme.of(this.context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign in to manage your appointments and access your care dashboard.',
                  style: Theme.of(this.context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your password';
                          }
                          if (value.trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submitLogin,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Log In'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('New patient?'),
                          TextButton(
                            onPressed: () {
                              Navigator.of(this.context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (BuildContext context) => const RegisterPage(),
                                ),
                              );
                            },
                            child: const Text('Register'),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(this.context).pushReplacement(
                            MaterialPageRoute(
                              builder: (BuildContext context) => const DashboardPage(patientName: 'Guest'),
                            ),
                          );
                        },
                        child: const Text('Continue as guest'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final existingPatient = await AppDatabase.instance.getPatientByEmail(email);

    if (!mounted) return;

    if (existingPatient != null) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('This email is already registered. Please sign in instead.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final patient = Patient.fromPlainPassword(name: name, email: email, password: password);
    await AppDatabase.instance.createPatient(patient);
    await saveSessionEmail(patient.email);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    Navigator.of(this.context).pushReplacement(
      MaterialPageRoute(
        builder: (BuildContext context) => DashboardPage(patientName: name),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Create your patient account',
                  style: Theme.of(this.context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Register now to book appointments, track care, and access your patient portal.',
                  style: Theme.of(this.context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Create a password';
                          }
                          if (value.trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Confirm your password';
                          }
                          if (value.trim() != _passwordController.text.trim()) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submitRegistration,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Sign Up'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: () {
                          Navigator.of(this.context).pushReplacement(
                            MaterialPageRoute(
                              builder: (BuildContext context) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final String patientName;

  const DashboardPage({super.key, this.patientName = 'patient'});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final int _doctorCount = 4;
  int _appointmentCount = 0;
  Appointment? _nextAppointment;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final appointments = await AppDatabase.instance.getAppointments(
      patientName: widget.patientName,
    );

    final upcoming = appointments.where((appointment) => appointment.dateTime.isAfter(DateTime.now()));

    if (!mounted) return;
    setState(() {
      _appointmentCount = appointments.length;
      _nextAppointment = upcoming.isNotEmpty ? upcoming.first : null;
    });
  }

  Future<void> _logout() async {
    await clearSession();
    if (!mounted) return;
    Navigator.of(this.context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (BuildContext context) => const LoginPage()),
      (route) => false,
    );
  }

  void _openDoctors() {
    Navigator.of(this.context).push(
      MaterialPageRoute(builder: (BuildContext context) => AppointmentHomePage(initialTab: 0, patientName: widget.patientName)),
    );
  }

  void _openAppointments() {
    Navigator.of(this.context).push(
      MaterialPageRoute(builder: (BuildContext context) => AppointmentHomePage(initialTab: 1, patientName: widget.patientName)),
    );
  }

  void _openMedicalRecords() {
    Navigator.of(this.context).push(
      MaterialPageRoute(builder: (BuildContext context) => const MedicalRecordsPage()),
    );
  }

  void _openBilling() {
    Navigator.of(this.context).push(
      MaterialPageRoute(builder: (BuildContext context) => const BillingPage()),
    );
  }

  void _openMessages() {
    Navigator.of(this.context).push(
      MaterialPageRoute(builder: (BuildContext context) => const MessagesPage()),
    );
  }

  void _openRecommendations() {
    Navigator.of(this.context).push(
      MaterialPageRoute(builder: (BuildContext context) => const RecommendationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: 'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=800&q=80',
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.local_hospital, size: 60, color: Colors.teal),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Hello, ${widget.patientName}!',
                style: Theme.of(this.context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Your care dashboard helps you stay on top of upcoming appointments and doctors.',
                style: Theme.of(this.context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.medical_services, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                const Text('Doctors'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$_doctorCount',
                              style: Theme.of(this.context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_month, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                const Text('Appointments'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$_appointmentCount',
                              style: Theme.of(this.context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_nextAppointment != null)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.event, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            const Text('Next appointment'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('${_nextAppointment!.doctor.name} • ${_nextAppointment!.doctor.specialty}'),
                        const SizedBox(height: 6),
                        Text('Date: ${_nextAppointment!.dateTime.toLocal()}'.split('.').first),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _appointmentCount == 0
                          ? 'No appointments scheduled yet. Book a doctor to get started.'
                          : 'No upcoming appointments found.',
                      style: Theme.of(this.context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openDoctors,
                icon: const Icon(Icons.medical_services),
                label: const Text('Browse Doctors'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openAppointments,
                icon: const Icon(Icons.event),
                label: const Text('My Appointments'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openMedicalRecords,
                icon: const Icon(Icons.folder_open),
                label: const Text('Medical Records'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openBilling,
                icon: const Icon(Icons.receipt_long),
                label: const Text('Billing & Payments'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openMessages,
                icon: const Icon(Icons.message),
                label: const Text('Messages'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openRecommendations,
                icon: const Icon(Icons.recommend),
                label: const Text('Follow-up Recommendations'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Appointment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to CareLink',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Book doctors, manage appointments, and stay connected with your care team.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                childAspectRatio: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.medical_services),
                    label: const Text('Browse Doctors'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (BuildContext context) => const AppointmentHomePage(),
                        ),
                      );
                    },
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.event),
                    label: const Text('My Appointments'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (BuildContext context) => const AppointmentHomePage(initialTab: 1),
                        ),
                      );
                    },
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.info),
                    label: const Text('About the Hospital'),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('About CareLink Hospital'),
                            content: const Text(
                              'CareLink Hospital helps you book appointments, view doctor profiles, and manage your health care easily.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Patient {
  Patient({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
  });

  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final String passwordSalt;

  factory Patient.fromPlainPassword({
    int? id,
    required String name,
    required String email,
    required String password,
  }) {
    final salt = _generateSalt();
    return Patient(
      id: id,
      name: name,
      email: email,
      passwordSalt: salt,
      passwordHash: _hashPassword(password, salt),
    );
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      passwordSalt: map['password_salt'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email.trim().toLowerCase(),
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
    };
  }
}

class Doctor {
  const Doctor({
    required this.name,
    required this.specialty,
    required this.room,
    required this.availability,
    required this.phone,
    required this.bio,
    required this.practice,
    required this.rating,
    required this.reviewCount,
    required this.distance,
    required this.insuranceAccepted,
    required this.telehealth,
    this.yearsOfExperience = 10,
    this.qualifications = const [],
    this.consultationCost = 0.0,
    this.imageUrl = '',
  });

  final String name;
  final String specialty;
  final String room;
  final String availability;
  final String phone;
  final String bio;
  final String practice;
  final double rating;
  final int reviewCount;
  final String distance;
  final List<String> insuranceAccepted;
  final bool telehealth;
  final int yearsOfExperience;
  final List<String> qualifications;
  final double consultationCost;
  final String imageUrl;

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      name: json['name'] as String,
      specialty: json['specialty'] as String,
      room: json['room'] as String,
      availability: json['availability'] as String,
      phone: json['phone'] as String,
      bio: json['bio'] as String,
      practice: json['practice'] as String? ?? 'Care Center',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: json['reviewCount'] as int? ?? 10,
      distance: json['distance'] as String? ?? '1.2 mi',
      insuranceAccepted: json['insuranceAccepted'] != null
          ? List<String>.from(json['insuranceAccepted'] as List<dynamic>)
          : const ['Aetna', 'Blue Cross'],
      telehealth: json['telehealth'] as bool? ?? false,
      yearsOfExperience: json['yearsOfExperience'] as int? ?? 10,
      qualifications: json['qualifications'] != null
          ? List<String>.from(json['qualifications'] as List<dynamic>)
          : const [],
      consultationCost: (json['consultationCost'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  factory Doctor.fromMap(Map<String, dynamic> map) {
    return Doctor(
      name: map['doctor_name'] as String,
      specialty: map['doctor_specialty'] as String,
      room: map['doctor_room'] as String,
      availability: map['doctor_availability'] as String,
      phone: map['doctor_phone'] as String,
      bio: map['doctor_bio'] as String,
      practice: map['doctor_practice'] as String? ?? 'Care Center',
      rating: (map['doctor_rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: map['doctor_review_count'] as int? ?? 10,
      distance: map['doctor_distance'] as String? ?? '1.2 mi',
      insuranceAccepted: map['doctor_insurance'] != null
          ? (map['doctor_insurance'] as String)
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList()
          : const ['Aetna', 'Blue Cross'],
      telehealth: (map['doctor_telehealth'] as int?) == 1,
      yearsOfExperience: map['years_of_experience'] as int? ?? 10,
      qualifications: map['qualifications'] != null
          ? (map['qualifications'] as String).split(',').map((s) => s.trim()).toList()
          : const [],
      consultationCost: (map['consultation_cost'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['doctor_image_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'specialty': specialty,
      'room': room,
      'availability': availability,
      'phone': phone,
      'bio': bio,
      'practice': practice,
      'rating': rating,
      'reviewCount': reviewCount,
      'distance': distance,
      'insuranceAccepted': insuranceAccepted,
      'telehealth': telehealth,
      'yearsOfExperience': yearsOfExperience,
      'qualifications': qualifications,
      'consultationCost': consultationCost,
      'imageUrl': imageUrl,
    };
  }
}

class DoctorReview {
  const DoctorReview({
    required this.reviewer,
    required this.rating,
    required this.comment,
    required this.date,
  });

  final String reviewer;
  final double rating;
  final String comment;
  final String date;
}

final Map<String, List<DoctorReview>> _doctorReviews = {
  'Dr. Maya Patel': [
    DoctorReview(
      reviewer: 'Alex K.',
      rating: 4.9,
      comment: 'Very attentive and explained everything clearly. I felt comfortable throughout the visit.',
      date: 'May 10, 2026',
    ),
    DoctorReview(
      reviewer: 'Sofia L.',
      rating: 4.8,
      comment: 'Great follow-up care and easy scheduling. Highly recommend.',
      date: 'Apr 23, 2026',
    ),
  ],
  'Dr. Noah Kim': [
    DoctorReview(
      reviewer: 'Brandon M.',
      rating: 4.7,
      comment: 'Helpful with my knee injury and very professional.',
      date: 'May 4, 2026',
    ),
    DoctorReview(
      reviewer: 'Mina C.',
      rating: 4.6,
      comment: 'Great bedside manner and follow-up tips were very useful.',
      date: 'Apr 28, 2026',
    ),
  ],
  'Dr. Sophia Lopez': [
    DoctorReview(
      reviewer: 'Emily T.',
      rating: 4.9,
      comment: 'Loved the warm environment and the doctor was excellent with children.',
      date: 'May 12, 2026',
    ),
    DoctorReview(
      reviewer: 'Carlos H.',
      rating: 4.7,
      comment: 'Very patient and thorough with every question.',
      date: 'Apr 21, 2026',
    ),
  ],
  'Dr. James Miller': [
    DoctorReview(
      reviewer: 'Nina P.',
      rating: 4.8,
      comment: 'Explained treatment options clearly and gave good skincare advice.',
      date: 'May 6, 2026',
    ),
  ],
};

List<DoctorReview> _reviewsForDoctor(Doctor doctor) => _doctorReviews[doctor.name] ?? const [];

void _addDoctorReview(Doctor doctor, DoctorReview review) {
  final list = _doctorReviews.putIfAbsent(doctor.name, () => <DoctorReview>[]);
  list.insert(0, review);
}

class Appointment {
  Appointment({
    this.id,
    required this.doctor,
    required this.patientName,
    required this.reason,
    required this.dateTime,
    DateTime? bookedAt,
  }) : bookedAt = bookedAt ?? DateTime.now();

  final int? id;
  final Doctor doctor;
  final String patientName;
  final String reason;
  final DateTime dateTime;
  final DateTime bookedAt;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      doctor: Doctor.fromJson(json['doctor'] as Map<String, dynamic>),
      patientName: json['patientName'] as String,
      reason: json['reason'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      bookedAt: DateTime.parse(json['bookedAt'] as String),
    );
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    final doctor = Doctor.fromMap(map);
    return Appointment(
      id: map['id'] as int?,
      doctor: doctor,
      patientName: map['patient_name'] as String,
      reason: map['reason'] as String,
      dateTime: DateTime.parse(map['date_time'] as String),
      bookedAt: DateTime.parse(map['booked_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctor': doctor.toJson(),
      'patientName': patientName,
      'reason': reason,
      'dateTime': dateTime.toIso8601String(),
      'bookedAt': bookedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'doctor_name': doctor.name,
      'doctor_specialty': doctor.specialty,
      'doctor_room': doctor.room,
      'doctor_availability': doctor.availability,
      'doctor_phone': doctor.phone,
      'doctor_bio': doctor.bio,
      'patient_name': patientName,
      'reason': reason,
      'date_time': dateTime.toIso8601String(),
      'booked_at': bookedAt.toIso8601String(),
    };
  }

  Appointment copyWith({
    int? id,
    Doctor? doctor,
    String? patientName,
    String? reason,
    DateTime? dateTime,
    DateTime? bookedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      doctor: doctor ?? this.doctor,
      patientName: patientName ?? this.patientName,
      reason: reason ?? this.reason,
      dateTime: dateTime ?? this.dateTime,
      bookedAt: bookedAt ?? this.bookedAt,
    );
  }
}

// Enhanced Appointment Status Tracking
enum AppointmentStatus { pending, confirmed, completed, cancelled, rescheduled }

class MedicalHistory {
  const MedicalHistory({
    this.id,
    required this.condition,
    required this.diagnosisDate,
    required this.status,
    this.notes = '',
  });

  final int? id;
  final String condition;
  final DateTime diagnosisDate;
  final String status; // active, resolved, monitoring
  final String notes;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'condition': condition,
    'diagnosis_date': diagnosisDate.toIso8601String(),
    'status': status,
    'notes': notes,
  };
}

class Medication {
  const Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.prescribedBy = '',
  });

  final int? id;
  final String name;
  final String dosage;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final String prescribedBy;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'medication_name': name,
    'dosage': dosage,
    'frequency': frequency,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'prescribed_by': prescribedBy,
  };
}

class Allergy {
  const Allergy({
    this.id,
    required this.allergen,
    required this.reaction,
    required this.severity,
    required this.dateAdded,
  });

  final int? id;
  final String allergen;
  final String reaction;
  final String severity; // mild, moderate, severe
  final DateTime dateAdded;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'allergen': allergen,
    'reaction': reaction,
    'severity': severity,
    'date_added': dateAdded.toIso8601String(),
  };
}

class Prescription {
  const Prescription({
    this.id,
    required this.doctorName,
    required this.medication,
    required this.dosage,
    required this.instructions,
    required this.dateIssued,
    this.refillsRemaining = 0,
  });

  final int? id;
  final String doctorName;
  final String medication;
  final String dosage;
  final String instructions;
  final DateTime dateIssued;
  final int refillsRemaining;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'doctor_name': doctorName,
    'medication': medication,
    'dosage': dosage,
    'instructions': instructions,
    'date_issued': dateIssued.toIso8601String(),
    'refills_remaining': refillsRemaining,
  };
}

class TestResult {
  const TestResult({
    this.id,
    required this.testName,
    required this.resultValue,
    required this.unit,
    required this.normalRange,
    required this.dateTested,
    this.status = 'normal', // normal, abnormal, pending
  });

  final int? id;
  final String testName;
  final String resultValue;
  final String unit;
  final String normalRange;
  final DateTime dateTested;
  final String status;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'test_name': testName,
    'result_value': resultValue,
    'unit': unit,
    'normal_range': normalRange,
    'date_tested': dateTested.toIso8601String(),
    'status': status,
  };
}

class Message {
  const Message({
    this.id,
    required this.doctorName,
    required this.sender, // 'patient' or doctor name
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  final int? id;
  final String doctorName;
  final String sender;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'doctor_name': doctorName,
    'sender': sender,
    'message_text': text,
    'timestamp': timestamp.toIso8601String(),
    'is_read': isRead ? 1 : 0,
  };
}

class Payment {
  const Payment({
    this.id,
    required this.appointmentId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.status = 'completed',
    this.insuranceCoverage = 0.0,
    this.outOfPocket = 0.0,
  });

  final int? id;
  final int appointmentId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod; // 'credit_card', 'insurance', 'cash'
  final String status;
  final double insuranceCoverage;
  final double outOfPocket;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'appointment_id': appointmentId,
    'amount': amount,
    'payment_date': paymentDate.toIso8601String(),
    'payment_method': paymentMethod,
    'status': status,
    'insurance_coverage': insuranceCoverage,
    'out_of_pocket': outOfPocket,
  };
}

class FollowUpRecommendation {
  const FollowUpRecommendation({
    this.id,
    required this.doctorName,
    required this.recommendation,
    required this.category, // 'test', 'medication', 'lifestyle', 'followup'
    required this.dueDate,
    this.status = 'pending', // pending, completed
  });

  final int? id;
  final String doctorName;
  final String recommendation;
  final String category;
  final DateTime dueDate;
  final String status;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'doctor_name': doctorName,
    'recommendation': recommendation,
    'category': category,
    'due_date': dueDate.toIso8601String(),
    'status': status,
  };
}

enum AppointmentFilter { all, upcoming, past }

class AppointmentHomePage extends StatefulWidget {
  const AppointmentHomePage({super.key, this.initialTab = 0, this.patientName = 'Guest'});

  final int initialTab;
  final String patientName;

  @override
  State<AppointmentHomePage> createState() => _AppointmentHomePageState();
}

class _AppointmentHomePageState extends State<AppointmentHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _appointmentSearchController = TextEditingController();
  String _doctorSearchQuery = '';
  String _selectedSpecialty = 'All';
  bool _telehealthOnly = false;
  String _selectedInsurance = 'All';
  String _sortBy = 'Best match';
  Set<String> _favoriteDoctors = <String>{};
  String _appointmentSearchQuery = '';
  AppointmentFilter _selectedAppointmentFilter = AppointmentFilter.upcoming;

  List<String> get _specialtyOptions {
    final specialties = _doctors.map((doctor) => doctor.specialty).toSet().toList()..sort();
    return ['All', ...specialties];
  }

  List<String> get _insuranceOptions {
    final ins = _doctors.expand((d) => d.insuranceAccepted).toSet().toList()..sort();
    return ['All', ...ins];
  }

  List<String> get _sortOptions => ['Best match', 'Rating', 'Distance'];

  Future<void> _loadFavorites() async {
    _favoriteDoctors = await readFavoriteDoctors();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleFavorite(Doctor doctor) async {
    if (_favoriteDoctors.contains(doctor.name)) {
      _favoriteDoctors.remove(doctor.name);
    } else {
      _favoriteDoctors.add(doctor.name);
    }
    await writeFavoriteDoctors(_favoriteDoctors);
    if (!mounted) return;
    setState(() {});
  }

  final List<Doctor> _doctors = const [
    Doctor(
      name: 'Dr. Maya Patel',
      specialty: 'Cardiology',
      room: 'Room 112',
      availability: 'Mon · Wed · Fri',
      phone: '(555) 208-1142',
      bio: 'Experienced cardiologist focused on preventive care and heart health.',
      practice: 'Riverside Heart Clinic',
      rating: 4.9,
      reviewCount: 128,
      distance: '1.1 mi',
      insuranceAccepted: ['Aetna', 'Cigna', 'United Healthcare'],
      telehealth: true,
      yearsOfExperience: 18,
      qualifications: ['MD - Cardiology', 'Fellowship - Johns Hopkins', 'Board Certified'],
      consultationCost: 250.0,
      imageUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. Noah Kim',
      specialty: 'Orthopedics',
      room: 'Room 205',
      availability: 'Tue · Thu',
      phone: '(555) 303-2234',
      bio: 'Specializes in sports injuries and joint replacement therapy.',
      practice: 'Orthopedic Care Center',
      rating: 4.7,
      reviewCount: 92,
      distance: '2.3 mi',
      insuranceAccepted: ['Blue Cross', 'Aetna', 'Kaiser'],
      telehealth: false,
      yearsOfExperience: 15,
      qualifications: ['MD - Orthopedic Surgery', 'Sports Medicine Fellowship', 'Board Certified'],
      consultationCost: 200.0,
      imageUrl: 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. Sophia Lopez',
      specialty: 'Pediatrics',
      room: 'Room 320',
      availability: 'Daily',
      phone: '(555) 417-9910',
      bio: 'Caring pediatrician for children and adolescent health.',
      practice: 'Sunrise Children’s Health',
      rating: 4.8,
      reviewCount: 104,
      distance: '0.9 mi',
      insuranceAccepted: ['United Healthcare', 'Cigna'],
      telehealth: true,
    ),
    Doctor(
      name: 'Dr. James Miller',
      specialty: 'Dermatology',
      room: 'Room 404',
      availability: 'Mon · Wed',
      phone: '(555) 507-6601',
      bio: 'Dermatology expert treating skin conditions and cosmetic care.',
      practice: 'ClearSkin Dermatology',
      rating: 4.6,
      reviewCount: 76,
      distance: '1.8 mi',
      insuranceAccepted: ['Aetna', 'Blue Cross', 'Humana'],
      telehealth: false,
      yearsOfExperience: 14,
      qualifications: ['MD - Dermatology', 'Board Certified', 'Cosmetic Dermatology'],
      consultationCost: 180.0,
      imageUrl: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. Emily Chen',
      specialty: 'Neurology',
      room: 'Room 215',
      availability: 'Tue · Thu · Fri',
      phone: '(555) 612-3847',
      bio: 'Board-certified neurologist specializing in migraines and neurological disorders.',
      practice: 'NeuroHealth Clinic',
      rating: 4.8,
      reviewCount: 156,
      distance: '1.5 mi',
      insuranceAccepted: ['United Healthcare', 'Cigna', 'Blue Cross'],
      telehealth: true,
      yearsOfExperience: 16,
      qualifications: ['MD - Neurology', 'Board Certified', 'Migraine Specialist'],
      consultationCost: 220.0,
      imageUrl: 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. Robert Garcia',
      specialty: 'General Practice',
      room: 'Room 101',
      availability: 'Mon · Tue · Wed · Thu · Fri',
      phone: '(555) 721-4556',
      bio: 'Comprehensive primary care for all ages with focus on preventive medicine.',
      practice: 'Community Health Clinic',
      rating: 4.7,
      reviewCount: 203,
      distance: '0.5 mi',
      insuranceAccepted: ['Aetna', 'Blue Cross', 'Cigna', 'Kaiser', 'Humana'],
      telehealth: true,
      yearsOfExperience: 20,
      qualifications: ['MD - Family Medicine', 'Board Certified', 'Preventive Medicine'],
      consultationCost: 120.0,
      imageUrl: 'https://images.unsplash.com/photo-1582750433449-648ed127bb54?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. Jennifer Wilson',
      specialty: 'Psychiatry',
      room: 'Room 350',
      availability: 'Mon · Wed · Fri',
      phone: '(555) 834-2109',
      bio: 'Mental health specialist providing therapy and medication management.',
      practice: 'MindCare Mental Health',
      rating: 4.9,
      reviewCount: 87,
      distance: '2.1 mi',
      insuranceAccepted: ['United Healthcare', 'Aetna', 'Cigna'],
      telehealth: true,
      yearsOfExperience: 17,
      qualifications: ['MD - Psychiatry', 'Board Certified', 'Psychotherapy Specialist'],
      consultationCost: 200.0,
      imageUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. Marcus Thompson',
      specialty: 'Gastroenterology',
      room: 'Room 310',
      availability: 'Tue · Wed · Thu',
      phone: '(555) 945-7621',
      bio: 'Digestive system specialist with expertise in endoscopy and disease management.',
      practice: 'Digestive Health Center',
      rating: 4.7,
      reviewCount: 111,
      distance: '1.9 mi',
      insuranceAccepted: ['Blue Cross', 'Kaiser', 'Humana'],
      telehealth: false,
      yearsOfExperience: 19,
      qualifications: ['MD - Gastroenterology', 'Board Certified', 'Endoscopy Specialist'],
      consultationCost: 230.0,
      imageUrl: 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. Alexandra Rodriguez',
      specialty: 'ENT',
      room: 'Room 222',
      availability: 'Mon · Thu · Fri',
      phone: '(555) 623-5834',
      bio: 'Ear, nose, and throat specialist treating all ages with advanced techniques.',
      practice: 'ENT Associates',
      rating: 4.6,
      reviewCount: 98,
      distance: '1.4 mi',
      insuranceAccepted: ['Aetna', 'Blue Cross', 'United Healthcare'],
      telehealth: false,
      yearsOfExperience: 13,
      qualifications: ['MD - Otolaryngology', 'Board Certified', 'Pediatric ENT'],
      consultationCost: 170.0,
      imageUrl: 'https://images.unsplash.com/photo-1594824476967-48c8b964273f?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. David Chang',
      specialty: 'Urology',
      room: 'Room 305',
      availability: 'Wed · Thu · Fri',
      phone: '(555) 756-1029',
      bio: 'Urinary system specialist with surgical and non-surgical treatment options.',
      practice: 'Advanced Urology Center',
      rating: 4.8,
      reviewCount: 82,
      distance: '2.2 mi',
      insuranceAccepted: ['United Healthcare', 'Cigna', 'Kaiser'],
      telehealth: false,
      yearsOfExperience: 16,
      qualifications: ['MD - Urology', 'Board Certified', 'Robotic Surgery Specialist'],
      consultationCost: 210.0,
      imageUrl: 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. Lisa Anderson',
      specialty: 'Ophthalmology',
      room: 'Room 401',
      availability: 'Mon · Tue · Thu',
      phone: '(555) 482-6194',
      bio: 'Eye care specialist providing comprehensive vision and eye health services.',
      practice: 'Vision Care Clinic',
      rating: 4.7,
      reviewCount: 134,
      distance: '0.8 mi',
      insuranceAccepted: ['Blue Cross', 'Aetna', 'Humana', 'Cigna'],
      telehealth: true,
      yearsOfExperience: 14,
      qualifications: ['MD - Ophthalmology', 'Board Certified', 'Cataract Surgery Specialist'],
      consultationCost: 190.0,
      imageUrl: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. Christopher Martinez',
      specialty: 'Pulmonology',
      room: 'Room 330',
      availability: 'Tue · Wed · Fri',
      phone: '(555) 591-3847',
      bio: 'Respiratory system specialist treating asthma, COPD, and lung diseases.',
      practice: 'Respiratory Health Institute',
      rating: 4.9,
      reviewCount: 119,
      distance: '1.7 mi',
      insuranceAccepted: ['United Healthcare', 'Blue Cross', 'Kaiser'],
      telehealth: true,
      yearsOfExperience: 15,
      qualifications: ['MD - Pulmonology', 'Board Certified', 'Sleep Medicine Fellow'],
      consultationCost: 215.0,
      imageUrl: 'https://images.unsplash.com/photo-1582750433449-648ed127bb54?auto=format&fit=crop&w=400&q=80',
    ),
    Doctor(
      name: 'Dr. Susan Lee',
      specialty: 'Oncology',
      room: 'Room 450',
      availability: 'Mon · Wed · Thu',
      phone: '(555) 712-4856',
      bio: 'Cancer specialist providing comprehensive treatment and support care.',
      practice: 'Cancer Care Center',
      rating: 4.9,
      reviewCount: 76,
      distance: '2.6 mi',
      insuranceAccepted: ['Aetna', 'United Healthcare', 'Cigna'],
      telehealth: false,
      yearsOfExperience: 22,
      qualifications: ['MD - Medical Oncology', 'Board Certified', 'Clinical Researcher'],
      consultationCost: 280.0,
      imageUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&w=400&q=80',
    ),
  ];
  final List<Appointment> _appointments = [];

  List<Doctor> get _filteredDoctors {
    final query = _doctorSearchQuery.toLowerCase();
    final results = _doctors.where((doctor) {
      final matchesSearch = _doctorSearchQuery.isEmpty ||
          doctor.name.toLowerCase().contains(query) ||
          doctor.specialty.toLowerCase().contains(query) ||
          doctor.room.toLowerCase().contains(query) ||
          doctor.practice.toLowerCase().contains(query);
      final matchesSpecialty = _selectedSpecialty == 'All' || doctor.specialty == _selectedSpecialty;
      final matchesTelehealth = !_telehealthOnly || doctor.telehealth;
      final matchesInsurance = _selectedInsurance == 'All' || doctor.insuranceAccepted.contains(_selectedInsurance);
      return matchesSearch && matchesSpecialty && matchesTelehealth && matchesInsurance;
    }).toList();

    // Apply sorting
    if (_sortBy == 'Rating') {
      results.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == 'Distance') {
      double parseDist(String s) {
        try {
          return double.parse(s.split(' ').first.replaceAll('mi', '').trim());
        } catch (_) {
          return 9999.0;
        }
      }
      results.sort((a, b) => parseDist(a.distance).compareTo(parseDist(b.distance)));
    }

    return results;
  }

  bool _isUpcoming(Appointment appointment) {
    return appointment.dateTime.isAfter(DateTime.now());
  }

  List<Appointment> get _filteredAppointments {
    final filteredBySearch = _appointments.where((appointment) {
      if (_appointmentSearchQuery.isEmpty) {
        return true;
      }
      final query = _appointmentSearchQuery.toLowerCase();
      return appointment.doctor.name.toLowerCase().contains(query) ||
          appointment.reason.toLowerCase().contains(query) ||
          appointment.patientName.toLowerCase().contains(query);
    }).toList();

    switch (_selectedAppointmentFilter) {
      case AppointmentFilter.upcoming:
        return filteredBySearch.where(_isUpcoming).toList();
      case AppointmentFilter.past:
        return filteredBySearch.where((appointment) => !_isUpcoming(appointment)).toList();
      case AppointmentFilter.all:
        return filteredBySearch;
    }
  }

  void _cancelAppointment(int index) async {
    final removed = _appointments.removeAt(index);
    if (removed.id != null) {
      await AppDatabase.instance.deleteAppointment(removed.id!);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text('Cancelled appointment with ${removed.doctor.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {});
  }

  Future<void> _loadAppointments() async {
    final loaded = await AppDatabase.instance.getAppointments(
      patientName: widget.patientName,
    );

    if (!mounted) return;

    setState(() {
      _appointments
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _openBookingSheet(Doctor doctor,
      {Appointment? existingAppointment, int? existingIndex}) async {
    final result = await showModalBottomSheet<Appointment>(
      context: this.context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AppointmentBookingSheet(
            doctor: doctor,
            appointment: existingAppointment,
            defaultPatientName: widget.patientName,
          ),
        );
      },
    );

    if (!mounted) return;

    if (result != null) {
      if (existingIndex == null) {
        final id = await AppDatabase.instance.createAppointment(result);
        final persisted = result.copyWith(id: id);
        setState(() {
          _appointments.add(persisted);
        });
      } else {
        await AppDatabase.instance.updateAppointment(result);
        setState(() {
          _appointments[existingIndex] = result;
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(existingIndex == null
              ? 'Appointment booked successfully'
              : 'Appointment updated successfully'),
          duration: const Duration(seconds: 2),
        ),
      );
      _tabController.animateTo(1);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() {});
        }
      });
    _loadAppointments();
    _loadFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _appointmentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Appointment App'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Doctors'),
                  Tab(text: 'My Appointments'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _buildSearchBar(),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDoctorList(),
          _buildAppointmentHistory(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    switch (_tabController.index) {
      case 0:
        return TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search doctors',
            hintText: 'Search by name, specialty, or room',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _doctorSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _doctorSearchQuery = '';
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _doctorSearchQuery = value.trim();
            });
          },
        );
      case 1:
        return TextField(
          controller: _appointmentSearchController,
          decoration: InputDecoration(
            labelText: 'Search appointments',
            hintText: 'Search by patient, doctor, or reason',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _appointmentSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _appointmentSearchController.clear();
                      setState(() {
                        _appointmentSearchQuery = '';
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _appointmentSearchQuery = value.trim();
            });
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDoctorList() {
    final doctors = _filteredDoctors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters',
                style: Theme.of(this.context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _specialtyOptions.map((specialty) {
                      return ChoiceChip(
                        label: Text(specialty),
                        selected: _selectedSpecialty == specialty,
                        onSelected: (_) {
                          setState(() {
                            _selectedSpecialty = specialty;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Telehealth only'),
                        selected: _telehealthOnly,
                        onSelected: (selected) {
                          setState(() {
                            _telehealthOnly = selected;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _selectedInsurance,
                        items: _insuranceOptions
                            .map((ins) => DropdownMenuItem(value: ins, child: Text(ins)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedInsurance = v ?? 'All';
                          });
                        },
                        underline: const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _sortBy,
                        items: _sortOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _sortBy = v ?? 'Best match';
                          });
                        },
                        underline: const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 12),
                      if (_selectedSpecialty != 'All' || _telehealthOnly || _selectedInsurance != 'All' || _sortBy != 'Best match')
                        ActionChip(
                          label: const Text('Clear filters'),
                          onPressed: () {
                            setState(() {
                              _selectedSpecialty = 'All';
                              _telehealthOnly = false;
                              _selectedInsurance = 'All';
                              _sortBy = 'Best match';
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (doctors.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _doctorSearchQuery.isNotEmpty
                      ? 'No doctors match your search or filters.'
                      : 'No doctors are available right now. Try changing your filters.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: doctors.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doctor = doctors[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (BuildContext context) => DoctorDetailPage(doctor: doctor),
                      ),
                    );
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              doctor.imageUrl.isNotEmpty 
                                  ? doctor.imageUrl 
                                  : 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=400&q=80',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.person, size: 40, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor.name,
                                  style: Theme.of(this.context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.star, size: 18, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${doctor.rating.toStringAsFixed(1)} • ${(_reviewsForDoctor(doctor).isNotEmpty ? _reviewsForDoctor(doctor).length : doctor.reviewCount)} reviews',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: Icon(
                                        _favoriteDoctors.contains(doctor.name) ? Icons.favorite : Icons.favorite_border,
                                        color: _favoriteDoctors.contains(doctor.name) ? Colors.red : null,
                                      ),
                                      onPressed: () => _toggleFavorite(doctor),
                                      tooltip: 'Favorite',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    if (doctor.telehealth)
                                      Chip(
                                        label: const Text('Telehealth'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('${doctor.specialty} • ${doctor.room}'),
                                const SizedBox(height: 6),
                                Text('${doctor.practice} • ${doctor.distance}'),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month, size: 18, color: Colors.teal),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Next: ${doctor.availability}',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: () => _openBookingSheet(doctor),
                                    icon: const Icon(Icons.calendar_month),
                                    label: const Text('Book Appointment'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAppointmentHistory() {
    final filteredAppointments = _filteredAppointments;

    if (_appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.event_available, size: 88, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No appointments yet.\nBook a doctor to see your upcoming schedule here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Upcoming'),
                  selected: _selectedAppointmentFilter == AppointmentFilter.upcoming,
                  onSelected: (_) {
                    setState(() {
                      _selectedAppointmentFilter = AppointmentFilter.upcoming;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Past'),
                  selected: _selectedAppointmentFilter == AppointmentFilter.past,
                  onSelected: (_) {
                    setState(() {
                      _selectedAppointmentFilter = AppointmentFilter.past;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedAppointmentFilter == AppointmentFilter.all,
                  onSelected: (_) {
                    setState(() {
                      _selectedAppointmentFilter = AppointmentFilter.all;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        if (filteredAppointments.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _appointmentSearchQuery.isNotEmpty
                      ? 'No appointments match your search.'
                      : 'No appointments found for this filter.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredAppointments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final appointment = filteredAppointments[index];
                final status = _isUpcoming(appointment) ? 'Upcoming' : 'Past';
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(appointment.doctor.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text('${appointment.doctor.specialty} • ${appointment.doctor.room}'),
                        const SizedBox(height: 6),
                        Text('Patient: ${appointment.patientName}'),
                        const SizedBox(height: 4),
                        Text('Reason: ${appointment.reason}'),
                        const SizedBox(height: 4),
                        Text('Date: ${_formatAppointmentDate(appointment.dateTime)}'),
                        const SizedBox(height: 4),
                        Text('Status: $status'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.teal),
                          tooltip: 'Edit appointment',
                          onPressed: () {
                            final originalIndex = _appointments.indexOf(appointment);
                            if (originalIndex >= 0) {
                              _openBookingSheet(
                                appointment.doctor,
                                existingAppointment: appointment,
                                existingIndex: originalIndex,
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.redAccent),
                          tooltip: 'Cancel appointment',
                          onPressed: () {
                            final originalIndex = _appointments.indexOf(appointment);
                            if (originalIndex >= 0) {
                              _cancelAppointment(originalIndex);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _formatAppointmentDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class AppointmentBookingSheet extends StatefulWidget {
  const AppointmentBookingSheet({
    super.key,
    required this.doctor,
    this.appointment,
    this.defaultPatientName = 'Guest',
  });

  final Doctor doctor;
  final Appointment? appointment;
  final String defaultPatientName;

  @override
  State<AppointmentBookingSheet> createState() => _AppointmentBookingSheetState();
}

class _AppointmentBookingSheetState extends State<AppointmentBookingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _patientNameController;
  late final TextEditingController _reasonController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _selectedSlot;
  final List<String> _timeSlots = const ['09:00 AM', '10:30 AM', '12:00 PM', '02:00 PM', '03:30 PM'];

  @override
  void initState() {
    super.initState();
    _patientNameController = TextEditingController(
      text: widget.appointment?.patientName ?? widget.defaultPatientName,
    );
    _reasonController = TextEditingController(
      text: widget.appointment?.reason ?? '',
    );
    final existingDateTime = widget.appointment?.dateTime;
    if (existingDateTime != null) {
      _selectedDate = DateTime(
        existingDateTime.year,
        existingDateTime.month,
        existingDateTime.day,
      );
      _selectedTime = TimeOfDay(
        hour: existingDateTime.hour,
        minute: existingDateTime.minute,
      );
    } else {
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _selectedTime = const TimeOfDay(hour: 10, minute: 0);
    }
    _selectedSlot = _formatTimeSlot(_selectedTime);
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() {
        _selectedDate = selected;
      });
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (selected != null) {
      setState(() {
        _selectedTime = selected;
      });
    }
  }

  void _submitBooking() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final appointmentDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final appointment = Appointment(
      id: widget.appointment?.id,
      doctor: widget.doctor,
      patientName: _patientNameController.text.trim(),
      reason: _reasonController.text.trim(),
      dateTime: appointmentDateTime,
      bookedAt: widget.appointment?.bookedAt,
    );

    Navigator.of(this.context).pop(appointment);
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Book with ${widget.doctor.name}',
              style: Theme.of(this.context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(widget.doctor.specialty),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _patientNameController,
                    decoration: const InputDecoration(
                      labelText: 'Patient name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a patient name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason for visit',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please add a reason';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (widget.doctor.telehealth)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Chip(
                        backgroundColor: Colors.blue.shade50,
                        label: const Text('Telehealth available'),
                        avatar: const Icon(Icons.video_call, size: 18, color: Colors.blue),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Suggested slots',
                      style: Theme.of(this.context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _timeSlots.map((slot) {
                      return ChoiceChip(
                        label: Text(slot),
                        selected: _selectedSlot == slot,
                        onSelected: (_) {
                          setState(() {
                            _selectedSlot = slot;
                            _selectedTime = _timeOfDayFromSlot(slot);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _pickDate,
                          child: Text('Date: ${_formatDate(_selectedDate)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _pickTime,
                          child: Text('Time: ${_formatTime(_selectedTime)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitBooking,
                      child: const Text('Confirm Appointment'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _timeOfDayFromSlot(String slot) {
    final parts = slot.split(' ');
    final timeParts = parts[0].split(':');
    var hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;
    final period = parts.length > 1 ? parts[1] : 'AM';
    if (period == 'PM' && hour < 12) {
      hour += 12;
    }
    if (period == 'AM' && hour == 12) {
      hour = 0;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeSlot(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class DoctorDetailPage extends StatefulWidget {
  const DoctorDetailPage({super.key, required this.doctor});

  final Doctor doctor;

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage> {
  List<DoctorReview> get _reviews => _reviewsForDoctor(widget.doctor);

  Future<void> _leaveReview() async {
    final reviewerController = TextEditingController();
    final commentController = TextEditingController();
    double rating = 5.0;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave a review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reviewerController,
                decoration: const InputDecoration(labelText: 'Your name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(labelText: 'Comment'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Rating'),
                  const SizedBox(width: 8),
                  DropdownButton<double>(
                    value: rating,
                    items: [5, 4.5, 4, 3.5, 3, 2.5, 2, 1.5, 1]
                        .map((v) => DropdownMenuItem(value: v.toDouble(), child: Text(v.toString())))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      rating = v;
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(this.context).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final reviewer = reviewerController.text.trim().isEmpty ? 'Anonymous' : reviewerController.text.trim();
                final comment = commentController.text.trim();
                final review = DoctorReview(reviewer: reviewer, rating: rating, comment: comment, date: DateTime.now().toLocal().toString().split(' ').first);
                _addDoctorReview(widget.doctor, review);
                Navigator.of(this.context).pop(true);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Thanks for your review')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final reviews = _reviews;
    return Scaffold(
      appBar: AppBar(
        title: Text(doctor.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    doctor.imageUrl.isNotEmpty 
                        ? doctor.imageUrl 
                        : 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=400&q=80',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person, size: 60, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                doctor.name,
                style: Theme.of(this.context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                doctor.specialty,
                style: Theme.of(this.context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${(reviews.isNotEmpty ? (reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length) : doctor.rating).toStringAsFixed(1)} • ${reviews.isNotEmpty ? reviews.length : doctor.reviewCount} reviews',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(doctor.distance),
                ],
              ),
              const SizedBox(height: 12),
              Text(doctor.practice),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Room: ${doctor.room}')),
                  Chip(label: Text('Available: ${doctor.availability}')),
                  if (doctor.telehealth)
                    Chip(
                      label: const Text('Telehealth'),
                      avatar: const Icon(Icons.video_call, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'About',
                style: Theme.of(this.context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(doctor.bio),
              const SizedBox(height: 24),
              Text(
                'Insurance accepted',
                style: Theme.of(this.context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: doctor.insuranceAccepted
                    .map((insurance) => Chip(label: Text(insurance)))
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Patient reviews',
                style: Theme.of(this.context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              if (reviews.isEmpty)
                const Text('No patient reviews yet. Book an appointment to leave feedback.')
              else
                Column(
                  children: reviews.map((review) {
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  review.reviewer,
                                  style: Theme.of(this.context).textTheme.bodyLarge,
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    const Icon(Icons.star, size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(review.rating.toStringAsFixed(1)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(review.comment),
                            const SizedBox(height: 6),
                            Text(
                              review.date,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _leaveReview,
                child: const Text('Leave a review'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final appointment = await showModalBottomSheet<Appointment>(
                      context: this.context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (BuildContext context) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: AppointmentBookingSheet(
                            doctor: doctor,
                            defaultPatientName: 'Guest',
                          ),
                        );
                      },
                    );

                    if (appointment != null) {
                      await AppDatabase.instance.createAppointment(appointment);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Booked appointment with ${doctor.name}'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Book Appointment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
