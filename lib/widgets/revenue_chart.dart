import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

class RevenueChart extends StatelessWidget {
  final Map<String, double> data;

  const RevenueChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (data.isEmpty) {
      return Center(
        child: Text(
          'No revenue data available',
          style: AppTextStyles.bodySmall.copyWith(
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
      );
    }

    final keys = data.keys.toList();

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, _) {
                  return Text(
                    value.toInt().toString(),
                    style: AppTextStyles.caption.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= keys.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      keys[index],
                      style: AppTextStyles.caption.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(
            keys.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[keys[i]]!,
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                  color: cs.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
