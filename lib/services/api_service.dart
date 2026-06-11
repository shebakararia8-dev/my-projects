import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://api.hospitalapp.com'; // Replace with actual backend URL
  static const Duration timeout = Duration(seconds: 30);

  // Authentication APIs
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Login failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Signup failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Appointments APIs
  static Future<Map<String, dynamic>> bookAppointment({
    required String patientEmail,
    required String authToken,
    required String doctorName,
    required DateTime appointmentDate,
    required String reason,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/appointments/book'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'patient_email': patientEmail,
              'doctor_name': doctorName,
              'appointment_date': appointmentDate.toIso8601String(),
              'reason': reason,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Failed to book appointment: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getAppointments({
    required String patientEmail,
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/appointments?patient_email=$patientEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'appointments': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch appointments: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> cancelAppointment({
    required int appointmentId,
    required String authToken,
    required String cancellationReason,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/appointments/$appointmentId/cancel'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'cancellation_reason': cancellationReason,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Failed to cancel appointment: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> rescheduleAppointment({
    required int appointmentId,
    required String authToken,
    required DateTime newDate,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/appointments/$appointmentId/reschedule'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'new_date': newDate.toIso8601String(),
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Failed to reschedule appointment: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Payments APIs
  static Future<Map<String, dynamic>> createPayment({
    required String patientEmail,
    required String authToken,
    required int appointmentId,
    required double amount,
    required String paymentMethod,
    required double insuranceCoverage,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/payments/create'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'patient_email': patientEmail,
              'appointment_id': appointmentId,
              'amount': amount,
              'payment_method': paymentMethod,
              'insurance_coverage': insuranceCoverage,
              'out_of_pocket': amount - insuranceCoverage,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Payment failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getPaymentHistory({
    required String patientEmail,
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payments/history?patient_email=$patientEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'payments': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch payments: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyInsurance({
    required String patientEmail,
    required String authToken,
    required String insuranceProvider,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/insurance/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'patient_email': patientEmail,
          'insurance_provider': insuranceProvider,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Insurance verification failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Messaging APIs
  static Future<Map<String, dynamic>> sendMessage({
    required String patientEmail,
    required String authToken,
    required String doctorName,
    required String messageText,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/messages/send'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'patient_email': patientEmail,
              'doctor_name': doctorName,
              'message': messageText,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Failed to send message: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getMessages({
    required String patientEmail,
    required String authToken,
    required String doctorName,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/messages?patient_email=$patientEmail&doctor_name=$doctorName',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'messages': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch messages: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Medical Records APIs
  static Future<Map<String, dynamic>> getMedicalHistory({
    required String patientEmail,
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/medical-records/history?patient_email=$patientEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'history': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch medical history: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getPrescriptions({
    required String patientEmail,
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/medical-records/prescriptions?patient_email=$patientEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'prescriptions': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch prescriptions: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getTestResults({
    required String patientEmail,
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/medical-records/test-results?patient_email=$patientEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'results': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch test results: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getAllergies({
    required String patientEmail,
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/medical-records/allergies?patient_email=$patientEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'allergies': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch allergies: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getMedications({
    required String patientEmail,
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/medical-records/medications?patient_email=$patientEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'medications': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch medications: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Follow-up Recommendations APIs
  static Future<Map<String, dynamic>> getFollowUpRecommendations({
    required String patientEmail,
    required String authToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recommendations?patient_email=$patientEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'recommendations': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch recommendations: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> updateRecommendationStatus({
    required int recommendationId,
    required String authToken,
    required String status,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/recommendations/$recommendationId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'status': status,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Failed to update recommendation: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Push Notification Registration
  static Future<Map<String, dynamic>> registerPushNotification({
    required String patientEmail,
    required String authToken,
    required String deviceToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/notifications/register'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'patient_email': patientEmail,
              'device_token': deviceToken,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Failed to register notifications: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}
