# API Services Documentation

This directory contains the API service layer for Hospital Appointment App.

## Files

### 1. `api_service.dart`
Core HTTP client service that handles all backend API calls.

**Endpoints Implemented:**
- Authentication: Login, Signup
- Appointments: Book, List, Cancel, Reschedule
- Payments: Create, History, Verify Insurance
- Messaging: Send, Get Messages
- Medical Records: History, Prescriptions, Test Results, Allergies, Medications
- Follow-up: Get Recommendations, Update Status
- Notifications: Register Device Token

### 2. `token_manager.dart`
Secure token storage using `flutter_secure_storage`.

**Features:**
- Securely save/retrieve authentication tokens
- Store user email
- Token validation
- Check login status
- Clear all tokens on logout

### 3. `auth_service.dart`
High-level authentication service.

**Features:**
- Login with email/password
- User signup
- Logout
- Session management
- Token refresh

## Usage Examples

### Login
```dart
import 'services/auth_service.dart';

// Login
final result = await AuthService.login('user@example.com', 'password');
if (result['success']) {
  print('Login successful: ${result['user']}');
} else {
  print('Login failed: ${result['message']}');
}
```

### Book Appointment
```dart
import 'services/api_service.dart';
import 'services/token_manager.dart';

final email = await TokenManager.getUserEmail();
final token = await TokenManager.getToken();

final result = await ApiService.bookAppointment(
  patientEmail: email!,
  authToken: token!,
  doctorName: 'Dr. Maya Patel',
  appointmentDate: DateTime(2026, 6, 15, 10, 30),
  reason: 'Regular checkup',
);

if (result['success'] == true) {
  print('Appointment booked: ${result['appointmentId']}');
} else {
  print('Booking failed: ${result['message']}');
}
```

### Get Appointments
```dart
final result = await ApiService.getAppointments(
  patientEmail: email!,
  authToken: token!,
);

if (result['success'] == true) {
  List appointments = result['appointments'];
  print('Found ${appointments.length} appointments');
}
```

### Send Message to Doctor
```dart
final result = await ApiService.sendMessage(
  patientEmail: email!,
  authToken: token!,
  doctorName: 'Dr. Maya Patel',
  messageText: 'I have a question about my medication',
);

if (result['success'] == true) {
  print('Message sent successfully');
}
```

### Process Payment
```dart
final result = await ApiService.createPayment(
  patientEmail: email!,
  authToken: token!,
  appointmentId: 123,
  amount: 250.0,
  paymentMethod: 'credit_card',
  insuranceCoverage: 100.0,
);

if (result['success'] == true) {
  print('Payment processed: ${result['paymentId']}');
}
```

### Get Medical Records
```dart
// Get prescriptions
final prescriptions = await ApiService.getPrescriptions(
  patientEmail: email!,
  authToken: token!,
);

// Get test results
final results = await ApiService.getTestResults(
  patientEmail: email!,
  authToken: token!,
);

// Get allergies
final allergies = await ApiService.getAllergies(
  patientEmail: email!,
  authToken: token!,
);

// Get medications
final medications = await ApiService.getMedications(
  patientEmail: email!,
  authToken: token!,
);
```

### Get Follow-up Recommendations
```dart
final result = await ApiService.getFollowUpRecommendations(
  patientEmail: email!,
  authToken: token!,
);

if (result['success'] == true) {
  List recommendations = result['recommendations'];
  print('You have ${recommendations.length} follow-up recommendations');
}
```

## Backend API Contract

### Base URL
- Development: `https://localhost:8000` (update as needed)
- Production: `https://api.hospitalapp.com`

### Authentication
All endpoints except `/auth/login` and `/auth/signup` require:
```
Authorization: Bearer {token}
Content-Type: application/json
```

### Sample Endpoint Specifications

#### POST /auth/login
Request:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

Response:
```json
{
  "success": true,
  "token": "eyJhbGc...",
  "refreshToken": "eyJhbGc...",
  "user": {
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

#### POST /appointments/book
Request:
```json
{
  "patient_email": "user@example.com",
  "doctor_name": "Dr. Maya Patel",
  "appointment_date": "2026-06-15T10:30:00Z",
  "reason": "Regular checkup"
}
```

Response:
```json
{
  "success": true,
  "appointmentId": 123,
  "status": "confirmed",
  "appointment": { ... }
}
```

#### GET /payments/history?patient_email={email}
Response:
```json
{
  "success": true,
  "payments": [
    {
      "id": 1,
      "amount": 250.0,
      "payment_date": "2026-06-01T14:30:00Z",
      "status": "completed",
      "insurance_coverage": 100.0,
      "out_of_pocket": 150.0
    }
  ]
}
```

## Configuration

Update the `baseUrl` in `api_service.dart` to point to your backend:

```dart
static const String baseUrl = 'https://your-backend.com';
```

## Error Handling

All API methods return a `Map<String, dynamic>` with:
- `success`: Boolean indicating success
- `message`: Error message (if failed)
- Other fields as per response

Handle network errors gracefully:
```dart
try {
  final result = await ApiService.bookAppointment(...);
  if (result['success'] == true) {
    // Handle success
  } else {
    // Handle API error
    print(result['message']);
  }
} catch (e) {
  // Handle exception
  print('Error: $e');
}
```

## Next Steps

1. **Update `baseUrl`** - Set correct backend URL
2. **Implement Backend APIs** - Create endpoints matching the service methods
3. **Add Error Handling UI** - Display errors to users gracefully
4. **Implement Token Refresh** - Add auto-refresh in ApiService
5. **Add Offline Support** - Cache responses locally
6. **Implement Webhooks** - For real-time updates (appointments, messages)
7. **Add Push Notifications** - Integrate Firebase Cloud Messaging
