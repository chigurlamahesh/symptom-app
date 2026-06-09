import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/health_provider.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../widgets/confidence_gauge.dart';
import '../widgets/animated_button.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<HealthProvider>();
    final prediction = provider.currentPrediction;

    if (prediction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const Center(child: Text('No prediction available.')),
      );
    }

    final color = AppTheme.confidenceColor(prediction.confidence);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Gradient header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppTheme.primaryGradient),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Disease name
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          prediction.disease,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideY(begin: 0.2, end: 0),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withOpacity(0.4), width: 1),
                        ),
                        child: Text(
                          '${prediction.confidenceLabel} Confidence',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Confidence gauge ─────────────────────────────────
                  ConfidenceGauge(
                    confidence: prediction.confidence,
                    color: color,
                  ).animate().fadeIn(delay: 300.ms).scale(
                      begin: const Offset(0.8, 0.8), duration: 500.ms),

                  const SizedBox(height: 24),

                  // ── Top predictions ──────────────────────────────────
                  if (prediction.topPredictions.length > 1) ...[
                    _SectionTitle(title: 'Differential Diagnosis'),
                    const SizedBox(height: 12),
                    ...prediction.topPredictions.asMap().entries.map((e) {
                      final tp = e.value;
                      final c = AppTheme.confidenceColor(tp.confidence);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tp.disease,
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                ),
                                Text(
                                  '${tp.confidence.toStringAsFixed(1)}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: c,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: tp.confidence / 100,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade100,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(c),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(
                          delay: Duration(milliseconds: 400 + e.key * 80));
                    }),
                    const SizedBox(height: 8),
                  ],

                  // ── Clinical Specialist Recommendation ────────────────
                  if (prediction.recommendation != null) ...[
                    _SectionTitle(title: 'Clinical Recommendation'),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Specialist Action Plan',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  prediction.recommendation!,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: AppTheme.primaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 450.ms).scale(begin: const Offset(0.95, 0.95)),
                    const SizedBox(height: 24),
                  ],

                  // ── Patient Intake Profile ───────────────────────────
                  _SectionTitle(title: 'Patient Intake Profile'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                        )
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildProfileRowItem('Age', '${prediction.age ?? 'N/A'} yrs'),
                            _buildProfileRowItem('Gender', prediction.sex ?? 'N/A'),
                          ],
                        ),
                        const Divider(height: 16, thickness: 0.5),
                        Row(
                          children: [
                            _buildProfileRowItem('Weight', '${prediction.weight?.toStringAsFixed(0) ?? 'N/A'} kg'),
                            _buildProfileRowItem('Height', '${prediction.height?.toStringAsFixed(0) ?? 'N/A'} cm'),
                          ],
                        ),
                        const Divider(height: 16, thickness: 0.5),
                        Row(
                          children: [
                            _buildProfileRowItem('Smoking', prediction.smoker == 'Yes' ? 'Smoker' : 'Non-smoker'),
                            _buildProfileRowItem('Duration', prediction.duration ?? 'N/A'),
                          ],
                        ),
                        const Divider(height: 16, thickness: 0.5),
                        Row(
                          children: [
                            _buildProfileRowItem(
                              'Medical History',
                              prediction.existingConditions.isEmpty
                                  ? 'None Reported'
                                  : prediction.existingConditions.map((e) => e.toUpperCase()).join(', '),
                            ),
                            _buildProfileRowItem('Severity', prediction.severity ?? 'N/A', isSeverity: true),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 480.ms),
                  const SizedBox(height: 24),

                  // ── Symptoms used ────────────────────────────────────
                  _SectionTitle(title: 'Symptoms Analyzed'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: prediction.symptoms.map((s) {
                      final display = s
                          .split('_')
                          .map((w) => w[0].toUpperCase() + w.substring(1))
                          .join(' ');
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          display,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 24),

                  // ── Precautions ──────────────────────────────────────
                  _SectionTitle(title: 'Health Precautions'),
                  const SizedBox(height: 12),
                  ...prediction.precautions.asMap().entries.map((e) {
                    return _PrecautionCard(
                      index: e.key,
                      text: e.value,
                    ).animate().fadeIn(
                        delay: Duration(milliseconds: 600 + e.key * 80));
                  }),

                  const SizedBox(height: 24),

                  // ── Disclaimer ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This is an AI-assisted prediction and should not replace professional medical diagnosis. Please consult a qualified healthcare provider.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 800.ms),

                  const SizedBox(height: 24),

                  // ── Actions ──────────────────────────────────────────
                  AnimatedButton(
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadReport(context, prediction.id),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                      label: const Text('Download Medical Report (PDF)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                    ),
                  ).animate().fadeIn(delay: 850.ms),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: AnimatedButton(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Check Again'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: const BorderSide(color: AppTheme.primary),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedButton(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).popUntil(
                                  (route) => route.isFirst);
                            },
                            icon: const Icon(Icons.home_rounded),
                            label: const Text('Home'),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 900.ms),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReport(BuildContext context, int? id) async {
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report ID is not available. Please try again.')),
      );
      return;
    }
    final urlStr = ApiService.getReportUrl(id);
    final url = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch $urlStr';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not download report: $e')),
      );
    }
  }

  Widget _buildProfileRowItem(String label, String value, {bool isSeverity = false}) {
    Color? valColor;
    if (isSeverity) {
      if (value.toLowerCase() == 'severe') valColor = AppTheme.danger;
      else if (value.toLowerCase() == 'moderate') valColor = AppTheme.warning;
      else if (value.toLowerCase() == 'mild') valColor = AppTheme.success;
    }
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PrecautionCard extends StatelessWidget {
  final int index;
  final String text;
  const _PrecautionCard({required this.index, required this.text});

  static const List<IconData> _icons = [
    Icons.medical_services_outlined,
    Icons.local_drink_outlined,
    Icons.bedtime_outlined,
    Icons.warning_amber_outlined,
    Icons.directions_walk_rounded,
    Icons.masks_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _icons[index % _icons.length],
              size: 18,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
