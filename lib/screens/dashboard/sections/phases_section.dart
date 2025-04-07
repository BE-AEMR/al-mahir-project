import 'package:flutter/material.dart';
import '../widgets/phase_progress_chart.dart';
import '../models/dashboard_chart_models.dart';

class PhasesSection extends StatelessWidget {
  final List<PhaseProgressData> phaseProgressData;
  final VoidCallback? onSeeAllPhases;
  final Function(String)? onPhaseTap;

  const PhasesSection({
    Key? key,
    required this.phaseProgressData,
    this.onSeeAllPhases,
    this.onPhaseTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: double.infinity, // Utilise toute la hauteur disponible
      child: PhaseProgressChart(
        data: phaseProgressData,
        title: 'Phases en cours',
        onSeeAllPressed: onSeeAllPhases,
        onPhaseTap: onPhaseTap,
      ),
    );
  }
}
