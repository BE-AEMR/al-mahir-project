import 'package:flutter/material.dart';
import 'package:webxio_new/screens/dashboard/models/dashboard_chart_models.dart';

class PhaseProgressChart extends StatelessWidget {
  final List<PhaseProgressData> data;
  final String title;
  final VoidCallback? onSeeAllPressed;
  final Function(String)? onPhaseTap;

  const PhaseProgressChart({
    Key? key,
    required this.data,
    required this.title,
    this.onSeeAllPressed,
    this.onPhaseTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Grouper les phases par projet
    final Map<String, List<PhaseProgressData>> phasesByProject = {};
    
    for (var phase in data) {
      if (!phasesByProject.containsKey(phase.projectId)) {
        phasesByProject[phase.projectId] = [];
      }
      phasesByProject[phase.projectId]!.add(phase);
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onSeeAllPressed != null)
                  TextButton(
                    onPressed: onSeeAllPressed,
                    child: const Text('Voir tout'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: data.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune phase en cours',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    )
                  : _buildProjectPhasesList(phasesByProject),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectPhasesList(Map<String, List<PhaseProgressData>> phasesByProject) {
    return ListView.builder(
      shrinkWrap: true, // Pour s'adapter au contenu
      physics: const ClampingScrollPhysics(), // Pour éviter les rebonds
      itemCount: phasesByProject.length,
      itemBuilder: (context, index) {
        final projectId = phasesByProject.keys.elementAt(index);
        final phases = phasesByProject[projectId]!;
        final projectName = phases.first.projectName;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                projectName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...phases.map((phase) => _buildPhaseItem(context, phase)).toList(),
            if (index < phasesByProject.length - 1) const Divider(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildPhaseItem(BuildContext context, PhaseProgressData phase) {
    return InkWell(
      onTap: onPhaseTap != null ? () => onPhaseTap!(phase.phaseId) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: phase.statusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          phase.phaseName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${phase.progressPercentage.toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: phase.statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Barre de progression des tâches
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final progressWidth = (availableWidth * phase.progressPercentage / 100).clamp(0.0, availableWidth);
                
                return Container(
                  width: availableWidth,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[200],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        width: progressWidth,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: phase.statusColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Afficher la barre de progression du budget si disponible
            if (phase.budgetAllocated != null && phase.budgetAllocated! > 0 && phase.budgetConsumed != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Budget: ${phase.budgetConsumed!.toStringAsFixed(0)}/${phase.budgetAllocated!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${((phase.budgetConsumed! / phase.budgetAllocated!) * 100).toInt()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: phase.budgetStatusColor ?? Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth;
                        final budgetUsage = (phase.budgetConsumed! / phase.budgetAllocated!);
                        final progressWidth = (availableWidth * budgetUsage).clamp(0.0, availableWidth);
                        
                        return Container(
                          width: availableWidth,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: progressWidth,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: phase.budgetStatusColor ?? Colors.grey,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Text(
                    phase.projectName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _translateStatus(phase.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: phase.statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'in_progress':
        return 'En cours';
      case 'completed':
        return 'Terminée';
      case 'not_started':
        return 'Non démarrée';
      case 'on_hold':
        return 'En attente';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }
}
