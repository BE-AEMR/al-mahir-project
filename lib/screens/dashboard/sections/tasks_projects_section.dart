import 'package:flutter/material.dart';
import '../widgets/task_distribution_chart.dart';
import '../widgets/project_progress_chart.dart';
import '../widgets/task_timeline_chart.dart';
import '../models/dashboard_chart_models.dart';

class TasksProjectsSection extends StatelessWidget {
  final List<TaskDistributionData> tasksByStatusData;
  final List<TaskDistributionData> tasksByPriorityData;
  final List<ProjectProgressData> projectProgressData;
  final List<TaskTimelineData> upcomingTasksData;
  final Function(String)? onProjectTap;
  final Function(String)? onTaskTap;
  final VoidCallback? onSeeAllProjects;
  final VoidCallback? onSeeAllTasks;

  const TasksProjectsSection({
    Key? key,
    required this.tasksByStatusData,
    required this.tasksByPriorityData,
    required this.projectProgressData,
    required this.upcomingTasksData,
    this.onProjectTap,
    this.onTaskTap,
    this.onSeeAllProjects,
    this.onSeeAllTasks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Utiliser la même disposition pour tous les écrans (empilé verticalement)
    // Adapte dynamiquement certaines valeurs en fonction de la taille d'écran
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth >= 600;
    
    // Ajuster les hauteurs en fonction de la taille d'écran
    final double chartsHeight = isLargeScreen ? 250 : 230;
    final double progressHeight = isLargeScreen ? 240 : 220;
    final double timelineHeight = isLargeScreen ? 260 : 240;
    
    return Column(
      children: [
        SizedBox(
          height: chartsHeight,
          child: Row(
            children: [
              Expanded(
                child: TaskDistributionChart(
                  data: tasksByStatusData,
                  title: 'Tâches par statut',
                ),
              ),
              SizedBox(width: isLargeScreen ? 16 : 10),
              Expanded(
                child: TaskDistributionChart(
                  data: tasksByPriorityData,
                  title: 'Tâches par priorité',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: progressHeight,
          child: ProjectProgressChart(
            data: projectProgressData,
            title: 'Progression des projets',
            onSeeAllPressed: onSeeAllProjects,
            onProjectTap: onProjectTap,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: timelineHeight,
          child: TaskTimelineChart(
            data: upcomingTasksData,
            title: 'Tâches à venir',
            onSeeAllPressed: onSeeAllTasks,
            onTaskTap: onTaskTap,
          ),
        ),
      ],
    );
  }
}
