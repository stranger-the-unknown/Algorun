import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

final class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s6, AppSpace.s5, AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ALGORUN',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                      color: AppColors.fg,
                    ),
              ),
              const SizedBox(height: AppSpace.s3),
              const Text(
                'Construct the algorithm.\nNever type it.',
                style: TextStyle(
                  color: AppColors.muted,
                  height: 1.45,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.s4),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MILESTONE 3',
                      style: TextStyle(
                        color: AppColors.faint,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppSpace.s2),
                    Text(
                      'Typed blocks on a vertical script. Tap a slot, pick a piece that fits. No syntax. The interpreter still comes later.',
                      style: TextStyle(color: AppColors.muted, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s5),
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/worlds'),
                child: const Text('ENTER'),
              ),
              const SizedBox(height: AppSpace.s3),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  child: const Text('Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
