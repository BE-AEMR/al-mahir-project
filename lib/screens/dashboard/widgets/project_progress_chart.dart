import 'package:flutter/material.dart';
import '../models/dashboard_chart_models.dart';

class ProjectProgressChart extends StatelessWidget {
  final List<ProjectProgressData> data;
  final String title;
  final VoidCallback? onSeeAllPressed;
  final Function(String)? onProjectTap;
  
  const ProjectProgressChart({
    Key? key,
    required this.data,
    required this.title,
    this.onSeeAllPressed,
    this.onProjectTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        'Aucun projet en cours',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return _buildProjectProgressItem(context, data[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectProgressItem(BuildContext context, ProjectProgressData project) {
    return InkWell(
      onTap: onProjectTap != null ? () => onProjectTap!(project.projectId) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    project.projectName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${project.progressPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: project.progressColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Barre de progression
            Stack(
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width: (project.progressPercentage / 100) * (MediaQuery.of(context).size.width - 64),
                  decoration: BoxDecoration(
                    color: project.progressColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Indicateur du budget
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 16,
                      color: _getBudgetStatusColor(project.budgetUsagePercentage),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatCurrency(project.usedBudgetAmount)} / ${_formatCurrency(project.budgetAmount)} • Consommation du Budget réel: ${project.budgetUsagePercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 16,
                      color: _getBudgetStatusColor(project.plannedBudgetUsagePercentage),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatCurrency(project.usedBudgetAmount)} / ${_formatCurrency(project.plannedBudgetAmount)} • Consommation du Budget prévu: ${project.plannedBudgetUsagePercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }
  
  Color _getBudgetStatusColor(double percentage) {
    if (percentage < 70) {
      return Colors.green;
    } else if (percentage < 90) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Fonction pour formater les montants en devise
  String _formatCurrency(double amount) {
    // Formatter les montants en K€ si > 1000
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K€';
    } else {
      return '${amount.toStringAsFixed(0)}€';
    }
  }
}
