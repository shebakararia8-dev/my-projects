import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_manager.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  late Future<Map<String, dynamic>> _paymentHistory;
  double _totalSpent = 0.0;
  double _insuranceCovered = 0.0;
  double _outOfPocket = 0.0;

  @override
  void initState() {
    super.initState();
    _paymentHistory = Future.value({'success': false, 'message': 'Not logged in'});
    _loadPaymentHistory();
  }

  void _loadPaymentHistory() async {
    final email = await TokenManager.getUserEmail();
    final token = await TokenManager.getToken();

    if (email != null && token != null) {
      setState(() {
        _paymentHistory = ApiService.getPaymentHistory(
          patientEmail: email,
          authToken: token,
        );
      });

      // Calculate totals
      final result = await _paymentHistory;
      if (result['success'] == true) {
        final List<dynamic> payments = result['payments'] ?? [];
        double total = 0, insurance = 0, outOfPocket = 0;

        for (var payment in payments) {
          total += (payment['amount'] as num?)?.toDouble() ?? 0;
          insurance += (payment['insurance_coverage'] as num?)?.toDouble() ?? 0;
          outOfPocket += (payment['out_of_pocket'] as num?)?.toDouble() ?? 0;
        }

        setState(() {
          _totalSpent = total;
          _insuranceCovered = insurance;
          _outOfPocket = outOfPocket;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Payments'),
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildBillingSummary(),
              _buildPaymentHistory(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillingSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=800&q=80',
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Billing Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Total Spent', '\$${_totalSpent.toStringAsFixed(2)}'),
          _buildSummaryRow('Insurance Covered', '\$${_insuranceCovered.toStringAsFixed(2)}',
              Colors.green),
          _buildSummaryRow('Out of Pocket', '\$${_outOfPocket.toStringAsFixed(2)}',
              Colors.orange),
          const Divider(height: 16),
          _buildSummaryRow(
            'Remaining Balance',
            '\$${(_outOfPocket).toStringAsFixed(2)}',
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String amount, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _paymentHistory,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data?['success'] != true) {
          return Center(
            child: Text('Error: ${snapshot.data?['message'] ?? 'Unknown error'}'),
          );
        }

        final List<dynamic> payments = snapshot.data?['payments'] ?? [];
        if (payments.isEmpty) {
          return const Center(child: Text('No payment history'));
        }

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        'Appointment #${payment['appointment_id'] ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Date: ${payment['payment_date'] ?? 'Unknown'}\n'
                        'Method: ${payment['payment_method'] ?? 'Unknown'}\n'
                        'Insurance: \$${(payment['insurance_coverage'] as num?)?.toStringAsFixed(2) ?? '0.00'} | Out of Pocket: \$${(payment['out_of_pocket'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${(payment['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: payment['status'] == 'completed'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              payment['status'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 10,
                                color: payment['status'] == 'completed'
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
