import 'package:flutter/material.dart';
import '../../../models/task_history_model.dart';
import '../../../models/task_model.dart';

class TaskHistorySection extends StatelessWidget {
  final List<TaskHistory> taskHistoryData;
  final Map<String, String> userDisplayNames;
  final Map<String, Task> tasksMap;
  final VoidCallback? onSeeAllHistory;
  final Function(String)? onTaskTap;

  const TaskHistorySection({
    Key? key,
    required this.taskHistoryData,
    required this.userDisplayNames,
    required this.tasksMap,
    this.onSeeAllHistory,
    this.onTaskTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: _buildTaskHistoryCard(),
    );
  }

  Widget _buildTaskHistoryCard() {
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
                Expanded(
                  child: const Text(
                    'Historique des modifications de tâches',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onSeeAllHistory != null)
                  TextButton(
                    onPressed: onSeeAllHistory,
                    child: const Text('Voir tout'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: taskHistoryData.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune modification récente',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    )
                  : _buildHistoryList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    // Trier l'historique par date (plus récent en premier)
    final sortedHistory = List<TaskHistory>.from(taskHistoryData)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      itemCount: sortedHistory.length,
      itemBuilder: (context, index) {
        final historyEntry = sortedHistory[index];
        final userName = userDisplayNames[historyEntry.userId] ?? 'Utilisateur';
        final taskName = tasksMap[historyEntry.taskId]?.title ?? 'Tâche inconnue';
        
        return Column(
          children: [
            InkWell(
              onTap: onTaskTap != null ? () => onTaskTap!(historyEntry.taskId) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: historyEntry.getColor().withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        historyEntry.getIcon(),
                        size: 16,
                        color: historyEntry.getColor(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            taskName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            historyEntry.getDescription(),
                            style: const TextStyle(
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Par $userName le ${_formatDateTime(historyEntry.createdAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (index < sortedHistory.length - 1)
              const Divider(height: 2),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return "Aujourd'hui ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (dateToCheck == yesterday) {
      return 'Hier ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }
}
