import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/dashboard_chart_models.dart';
import '../../../models/task_model.dart';

class TaskTimelineChart extends StatelessWidget {
  final List<TaskTimelineData> data;
  final String title;
  final VoidCallback? onSeeAllPressed;
  final Function(String)? onTaskTap;

  const TaskTimelineChart({
    Key? key,
    required this.data,
    required this.title,
    this.onSeeAllPressed,
    this.onTaskTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Trier les tâches par date d'échéance
    final sortedData = List<TaskTimelineData>.from(data)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    
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
            const SizedBox(height: 4),
            Expanded(
              child: sortedData.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune tâche à venir',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    )
                  : _buildTimeline(context, sortedData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<TaskTimelineData> sortedData) {
    // Regrouper les tâches par jour
    final Map<String, List<TaskTimelineData>> tasksByDay = {};
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    for (var task in sortedData) {
      final dateKey = dateFormat.format(task.dueDate);
      if (!tasksByDay.containsKey(dateKey)) {
        tasksByDay[dateKey] = [];
      }
      tasksByDay[dateKey]!.add(task);
    }
    
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: tasksByDay.length,
      itemBuilder: (context, index) {
        final dateKey = tasksByDay.keys.elementAt(index);
        final tasksForDay = tasksByDay[dateKey]!;
        final isToday = _isToday(tasksForDay.first.dueDate);
        final isTomorrow = _isTomorrow(tasksForDay.first.dueDate);
        
        String dateLabel;
        if (isToday) {
          dateLabel = "Aujourd'hui";
        } else if (isTomorrow) {
          dateLabel = "Demain";
        } else {
          dateLabel = dateKey;
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isToday 
                          ? Colors.blue.withOpacity(0.2) 
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dateLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.blue : Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...tasksForDay.map((task) => _buildTaskTimelineItem(context, task)).toList(),
            if (index < tasksByDay.length - 1) const Divider(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildTaskTimelineItem(BuildContext context, TaskTimelineData task) {
    final priorityColor = _getPriorityColor(task.priority);
    
    return InkWell(
      onTap: onTaskTap != null ? () => onTaskTap!(task.taskId) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: priorityColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.taskTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          TaskStatus.fromValue(task.status).displayName,
                          style: TextStyle(
                            fontSize: 10,
                            color: _getStatusColor(task.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('HH:mm').format(task.dueDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 0: // Basse
        return Colors.green;
      case 1: // Moyenne
        return Colors.blue;
      case 2: // Haute
        return Colors.orange;
      case 3: // Urgente
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'à faire':
      case 'todo':
        return Colors.grey;
      case 'en cours':
      case 'in progress':
      case 'inprogress':
      case 'in_progress':
      case 'inProgress':
        return Colors.blue;
      case 'terminée':
      case 'completed':
        return Colors.green;
      case 'en revision':
      case 'review':
        return Colors.orange;
      case 'annulée':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  bool _isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
  }
}
