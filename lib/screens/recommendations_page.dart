import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_manager.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  late Future<Map<String, dynamic>> _recommendations;

  @override
  void initState() {
    super.initState();
    _recommendations = Future.value({'success': false, 'message': 'Not logged in'});
    _loadRecommendations();
  }

  void _loadRecommendations() async {
    final email = await TokenManager.getUserEmail();
    final token = await TokenManager.getToken();

    if (email != null && token != null) {
      setState(() {
        _recommendations = ApiService.getFollowUpRecommendations(
          patientEmail: email,
          authToken: token,
        );
      });
    }
  }

  Future<void> _updateRecommendationStatus(
    int recId,
    String newStatus,
  ) async {
    final token = await TokenManager.getToken();

    if (token != null) {
      final result = await ApiService.updateRecommendationStatus(
        recommendationId: recId,
        authToken: token,
        status: newStatus,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
        _loadRecommendations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result['message']}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-up Recommendations'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _recommendations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data?['success'] != true) {
            return Center(
              child: Text('Error: ${snapshot.data?['message'] ?? 'Unknown error'}'),
            );
          }

          final List<dynamic> recommendations =
              snapshot.data?['recommendations'] ?? [];
          if (recommendations.isEmpty) {
            return const Center(
              child: Text('No follow-up recommendations'),
            );
          }

          final pending = recommendations
              .where((r) => r['status'] == 'pending')
              .toList();
          final completed = recommendations
              .where((r) => r['status'] == 'completed')
              .toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                if (pending.isNotEmpty) ...[
                  _buildRecommendationSection('Pending', pending, Colors.orange),
                ],
                if (completed.isNotEmpty) ...[
                  _buildRecommendationSection(
                    'Completed',
                    completed,
                    Colors.green,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendationSection(
    String title,
    List<dynamic> recommendations,
    Color statusColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(rec['recommendation'] ?? 'Unknown'),
                  subtitle: Text(
                    'By: ${rec['doctor_name'] ?? 'Unknown'} | '
                    'Due: ${rec['due_date'] ?? 'Unknown'}',
                  ),
                  leading: Icon(
                    _getCategoryIcon(rec['category']),
                    color: statusColor,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category: ${rec['category'] ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Status: ${rec['status'] ?? 'Unknown'}',
                            style: TextStyle(
                              color: rec['status'] == 'pending'
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (rec['status'] == 'pending')
                            ElevatedButton(
                              onPressed: () => _updateRecommendationStatus(
                                rec['id'] ?? 0,
                                'completed',
                              ),
                              child: const Text('Mark as Completed'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'test':
        return Icons.assignment;
      case 'medication':
        return Icons.medication;
      case 'lifestyle':
        return Icons.favorite;
      case 'followup':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }
}
