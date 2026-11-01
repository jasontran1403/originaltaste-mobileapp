import 'package:flutter/material.dart';
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(16,16,16,100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lịch sử', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Lịch sử giao dịch', style: Theme.of(context).textTheme.bodySmall),
      ]),
    )),
  );
}
