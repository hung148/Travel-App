import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel/viewmodels/auth_viewmodel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.
      watch<AuthViewModel>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context
              .read<AuthViewModel>()
              .logout(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.travel_explore, 
              size: 80, 
              color: Color(0xFF2E7DFF)
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome, '
              '${user?.name ?? 'Traveler'}!',
              style: const TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: const TextStyle(
                color: Colors.black54
              ),
            ),
          ],
        ),
      ),
    );
  }
}