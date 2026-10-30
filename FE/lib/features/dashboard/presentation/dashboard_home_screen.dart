import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardHomeScreen extends ConsumerStatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  ConsumerState<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends ConsumerState<DashboardHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Responsive Header Welcome & Actions
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 740;
              final welcomeTitle = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang, ${user?.name ?? "Administrator"} 👋',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ringkasan eksekutif pencapaian target dan insentif penjualan periode Oktober 2026',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              );

              final actionButtons = Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.textPrimary,
                      side: BorderSide(color: context.colors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(LucideIcons.uploadCloud, size: 16),
                    label: const Text('Bulk Upload'),
                    onPressed: () => context.go('/bulk-upload'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(LucideIcons.calculator, size: 16),
                    label: const Text('Hitung Insentif'),
                    onPressed: () => context.go('/incentives/calculate'),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    welcomeTitle,
                    const SizedBox(height: 16),
                    actionButtons,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: welcomeTitle),
                  const SizedBox(width: 16),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // 4 Main KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final crossAxisCount = isWide ? 4 : (constraints.maxWidth >= 600 ? 2 : 1);

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isWide ? 1.55 : 2.0,
                children: [
                  _buildKpiCard(
                    title: 'Total Target Kuota',
                    value: '185.400 Unit',
                    icon: LucideIcons.target,
                    color: AppColors.primaryLight,
                    subtitle: 'Periode 202610 (3 Skema)',
                    trend: '+4.2% dari bln lalu',
                    trendPositive: true,
                  ),
                  _buildKpiCard(
                    title: 'Total Realisasi Aktual',
                    value: '198.850 Unit',
                    icon: LucideIcons.checkCircle2,
                    color: AppColors.success,
                    subtitle: 'Akumulasi seluruh depo',
                    trend: '+7.1% vs target',
                    trendPositive: true,
                  ),
                  _buildKpiCard(
                    title: 'Rata-rata Pencapaian',
                    value: '107,25 %',
                    icon: LucideIcons.percent,
                    color: AppColors.warning,
                    subtitle: 'Kategori Tier A-C',
                    trend: 'Di atas batas minimal',
                    trendPositive: true,
                  ),
                  _buildKpiCard(
                    title: 'Akumulasi Reward Insentif',
                    value: CurrencyFormatter.formatRupiah(248500000),
                    icon: LucideIcons.coins,
                    color: const Color(0xFF8B5CF6),
                    subtitle: '32 Personil Sales',
                    trend: 'Siap diajukan ke payroll',
                    trendPositive: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // Charts Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildBarChartCard()),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _buildDonutChartCard()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildBarChartCard(),
                    const SizedBox(height: 20),
                    _buildDonutChartCard(),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 28),

          // Quick Leaderboard & Shortcut Actions
          _buildQuickActionCards(context),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required String trend,
    required bool trendPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    trendPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                    size: 13,
                    color: trendPositive ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trend,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: trendPositive ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perbandingan Target vs Realisasi',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Pencapaian berdasarkan 3 Kategori Skema Utama',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.colors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chartLegend('Target', context.colors.borderStrong),
                  const SizedBox(width: 14),
                  _chartLegend('Realisasi', AppColors.primaryLight),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 120,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        switch (val.toInt()) {
                          case 0:
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('KONSUMSI', style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
                            );
                          case 1:
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('INDUSTRI', style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
                            );
                          case 2:
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('SURABAYA', style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
                            );
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (val, meta) {
                        return Text('${val.toInt()}k', style: TextStyle(color: context.colors.textFaint, fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: context.colors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(toY: 80, color: context.colors.borderStrong, width: 18, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: 92, color: AppColors.primaryLight, width: 18, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(toY: 60, color: context.colors.borderStrong, width: 18, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: 65, color: AppColors.primaryLight, width: 18, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(toY: 45, color: context.colors.borderStrong, width: 18, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: 41.8, color: AppColors.primaryLight, width: 18, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChartCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribusi Insentif',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          Text(
            'Proporsi nominal reward per skema',
            style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 46,
                sections: [
                  PieChartSectionData(
                    value: 48,
                    title: '48%',
                    color: AppColors.primary,
                    radius: 38,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: 32,
                    title: '32%',
                    color: AppColors.success,
                    radius: 38,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: 20,
                    title: '20%',
                    color: AppColors.warning,
                    radius: 38,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chartLegend('Konsumsi', AppColors.primary),
              const SizedBox(width: 14),
              _chartLegend('Industri', AppColors.success),
              const SizedBox(width: 14),
              _chartLegend('Surabaya', AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _buildQuickActionCards(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: context.colors.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alur Kerja Utama Sistem',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(
                'Langkah 1 s/d 3',
                style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 768;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildWorkflowStep(
                    stepNumber: '1',
                    title: 'Upload Data Penjualan',
                    desc: 'Upload file Excel Sell-In / Sell-Out per periode. Sistem memvalidasi batch transaksi otomatis.',
                    buttonText: 'Buka Bulk Upload',
                    icon: LucideIcons.fileSpreadsheet,
                    onTap: () => context.go('/bulk-upload'),
                    width: isDesktop ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                  ),
                  _buildWorkflowStep(
                    stepNumber: '2',
                    title: 'Hitung Kalkulasi Insentif',
                    desc: 'Jalankan kalkulasi multi-tier (Grade, Bobot, Capped Realisasi, Rate vs Lump Sum).',
                    buttonText: 'Mulai Hitung',
                    icon: LucideIcons.calculator,
                    onTap: () => context.go('/incentives/calculate'),
                    width: isDesktop ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                  ),
                  _buildWorkflowStep(
                    stepNumber: '3',
                    title: 'Atur Skema & Master',
                    desc: 'Sesuaikan ambang batas kuota, nilai reward per unit, dan struktur hierarki organisasi depo.',
                    buttonText: 'Buka Skema',
                    icon: LucideIcons.sliders,
                    onTap: () => context.go('/settings/incentives'),
                    width: isDesktop ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep({
    required String stepNumber,
    required String title,
    required String desc,
    required String buttonText,
    required IconData icon,
    required VoidCallback onTap,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  stepNumber,
                  style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: context.colors.textMuted),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buttonText,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(LucideIcons.arrowRight, size: 14, color: AppColors.primaryLight),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
