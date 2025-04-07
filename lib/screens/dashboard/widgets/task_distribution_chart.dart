import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/dashboard_chart_models.dart';

class TaskDistributionChart extends StatelessWidget {
  final List<TaskDistributionData> data;
  final String title;
  final bool showLabels;
  final bool animate;

  const TaskDistributionChart({
    Key? key,
    required this.data,
    required this.title,
    this.showLabels = true,
    this.animate = true,
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: data.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune donnée disponible',
                        style: TextStyle(
                          color: const Color.fromARGB(255, 171, 170, 170),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : _buildSyncfusionChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncfusionChart() {
    return SfCircularChart(
      margin: EdgeInsets.zero,
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x : point.y tâches',
        duration: 3000,
      ),
      series: <CircularSeries<TaskDistributionData, String>>[
        DoughnutSeries<TaskDistributionData, String>(
          dataSource: data,
          xValueMapper: (TaskDistributionData data, _) => data.label,
          yValueMapper: (TaskDistributionData data, _) => data.count,
          dataLabelMapper: (TaskDistributionData data, _) => data.count.toString(),
          pointColorMapper: (TaskDistributionData data, _) => data.color,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            connectorLineSettings: ConnectorLineSettings(
              type: ConnectorType.curve,
              length: '15%',
            ),
            textStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          radius: '80%',
          innerRadius: '60%',
          explode: true,
          explodeIndex: 0,
          explodeOffset: '10%',
          enableTooltip: true,
          animationDuration: 1200,
        ),
      ],
      legend: Legend(
        isVisible: showLabels,
        overflowMode: LegendItemOverflowMode.wrap,
        position: LegendPosition.bottom,
        textStyle: const TextStyle(fontSize: 10),
      ),
    );
  }
}
