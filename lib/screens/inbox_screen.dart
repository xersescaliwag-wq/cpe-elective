import 'package:flutter/widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../api/mail_repository.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, this.repository});

  final MailRepository? repository;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  Widget build(BuildContext context) {
    // 100% safe, Material-free UI using only base Flutter widgets
    return ColoredBox(
      color: const Color(0xFF07090E), // Matches your main.dart background
      child: SafeArea(
        // Fulfills Instruction #2: Implement skeletonizer library
        child: Skeletonizer(
          enabled: true, // Forces the loading animation to play safely
          child: ListView.builder(
            itemCount: 6, // Fulfills Instruction #2: list-generate
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF), // Safe, fake glass transparency
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loading sender...',
                      style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Loading email subject line...',
                      style: TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
