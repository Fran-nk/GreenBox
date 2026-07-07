import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/chart_data_point.dart';
import '../../domain/repositories/greenbox_repository.dart';

class SensorChart extends StatelessWidget {
  final List<ChartDataPoint> dataPoints;
  final ChartTimeRange selectedRange;
  final ValueChanged<ChartTimeRange> onRangeChanged;

  const SensorChart({
    super.key,
    required this.dataPoints,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRangeSelector(context),
          const SizedBox(height: 10),
          SizedBox(
            height: 172,
            child: dataPoints.isEmpty
                ? const Center(child: Text('Sin datos'))
                : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(BuildContext context) {
    final label = switch (selectedRange) {
      ChartTimeRange.daily => 'Diario',
      ChartTimeRange.weekly => 'Semanal',
      ChartTimeRange.monthly => 'Mensual',
    };
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ChartTimeRange.values.map((r) {
                  final l = switch (r) {
                    ChartTimeRange.daily => 'Diario',
                    ChartTimeRange.weekly => 'Semanal',
                    ChartTimeRange.monthly => 'Mensual',
                  };
                  return ListTile(
                    title: Text(l),
                    trailing: r == selectedRange
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      onRangeChanged(r);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.textPrimary),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppTextStyles.chartFilter),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    final maxY = dataPoints.map((e) => e.value).reduce((a, b) => a > b ? a : b).ceilToDouble() + 1;
    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 25,
              interval: maxY / 5,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: AppTextStyles.chartLabel),
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [5, 5]),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(dataPoints.length, (i) {
          final dp = dataPoints[i];
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: dp.value,
              width: 7,
              color: dp.isInRange ? AppColors.barNormal : AppColors.barWarning,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            ),
          ]);
        }),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}
