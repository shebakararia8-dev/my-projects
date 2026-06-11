import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hospital_appointment_app/main.dart';

void main() {
  testWidgets('Hospital appointment app loads login page', (WidgetTester tester) async {
    await tester.pumpWidget(const HospitalAppointmentApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets('Hospital appointment app dashboard / doctor list does not overflow on narrow screen', (WidgetTester tester) async {
    // Set screen size to 360x1200 (tall, narrow mobile device)
    tester.binding.window.physicalSizeTestValue = const Size(360 * 3, 1200 * 3);
    tester.binding.window.devicePixelRatioTestValue = 3.0;

    await tester.pumpWidget(const MaterialApp(
      home: AppointmentHomePage(initialTab: 0, patientName: 'Guest'),
    ));
    await tester.pumpAndSettle();

    // Verify no overflow errors occurred
    expect(tester.takeException(), isNull);
  });

  testWidgets('DoctorDetailPage does not overflow for any doctor on narrow screen', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(360 * 3, 1200 * 3);
    tester.binding.window.devicePixelRatioTestValue = 3.0;

    final doctors = [
      const Doctor(
        name: 'Dr. Maya Patel',
        specialty: 'Cardiology',
        room: 'Room 112',
        availability: 'Mon · Wed · Fri',
        phone: '(555) 208-1142',
        bio: 'Preventive care',
        practice: 'Riverside Heart Clinic',
        rating: 4.9,
        reviewCount: 128,
        distance: '1.1 mi',
        insuranceAccepted: ['Aetna', 'Cigna'],
        telehealth: true,
      ),
      const Doctor(
        name: 'Dr. Noah Kim',
        specialty: 'Orthopedics',
        room: 'Room 205',
        availability: 'Tue · Thu',
        phone: '(555) 303-2234',
        bio: 'Sports injuries',
        practice: 'Orthopedic Care Center',
        rating: 4.7,
        reviewCount: 92,
        distance: '2.3 mi',
        insuranceAccepted: ['Blue Cross'],
        telehealth: false,
      ),
    ];

    for (final doctor in doctors) {
      await tester.pumpWidget(MaterialApp(
        home: DoctorDetailPage(doctor: doctor),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
