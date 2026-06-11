import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_manager.dart';

class MessagesPage extends StatefulWidget {
  final String? initialDoctorName;

  const MessagesPage({super.key, this.initialDoctorName});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late TextEditingController _messageController;
  late Future<Map<String, dynamic>> _messages;
  String? _selectedDoctor;
  late List<String> _doctorList;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messages = Future.value({'success': false, 'message': 'Select a doctor'});
    _selectedDoctor = widget.initialDoctorName;
    _doctorList = [
      'Dr. Maya Patel',
      'Dr. Noah Kim',
      'Dr. Sophia Lopez',
      'Dr. James Miller',
      'Dr. Emily Chen',
      'Dr. Robert Garcia',
      'Dr. Jennifer Wilson',
      'Dr. Marcus Thompson',
      'Dr. Alexandra Rodriguez',
      'Dr. David Chang',
      'Dr. Lisa Anderson',
      'Dr. Christopher Martinez',
      'Dr. Susan Lee',
    ];

    if (_selectedDoctor != null) {
      _loadMessages();
    }
  }

  void _loadMessages() async {
    if (_selectedDoctor == null) return;

    final email = await TokenManager.getUserEmail();
    final token = await TokenManager.getToken();

    if (email != null && token != null) {
      setState(() {
        _messages = ApiService.getMessages(
          patientEmail: email,
          authToken: token,
          doctorName: _selectedDoctor!,
        );
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty || _selectedDoctor == null) return;

    final email = await TokenManager.getUserEmail();
    final token = await TokenManager.getToken();

    if (email != null && token != null) {
      final result = await ApiService.sendMessage(
        patientEmail: email,
        authToken: token,
        doctorName: _selectedDoctor!,
        messageText: _messageController.text,
      );

      _messageController.clear();

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully')),
        );
        _loadMessages(); // Refresh messages
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
        title: const Text('Messages with Doctors'),
      ),
      body: Column(
        children: [
          _buildDoctorSelector(),
          if (_selectedDoctor != null) ...[
            Expanded(child: _buildMessagesView()),
            _buildMessageInput(),
          ] else
            const Expanded(
              child: Center(
                child: Text('Select a doctor to start messaging'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDoctorSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButton<String>(
        isExpanded: true,
        hint: const Text('Select a doctor'),
        value: _selectedDoctor,
        items: _doctorList.map((doctor) {
          return DropdownMenuItem(
            value: doctor,
            child: Text(doctor),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedDoctor = value;
            if (value != null) {
              _loadMessages();
            }
          });
        },
      ),
    );
  }

  Widget _buildMessagesView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _messages,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data?['success'] != true) {
          return Center(
            child: Text('Error: ${snapshot.data?['message'] ?? 'Unknown error'}'),
          );
        }

        final List<dynamic> messages = snapshot.data?['messages'] ?? [];
        if (messages.isEmpty) {
          return const Center(child: Text('No messages yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isSentByMe = message['sender'] == 'patient';

            return Align(
              alignment:
                  isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSentByMe ? Colors.blue : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: isSentByMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      message['message_text'] ?? '',
                      style: TextStyle(
                        color: isSentByMe ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message['timestamp'] ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        color: isSentByMe
                            ? Colors.white70
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: _sendMessage,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
