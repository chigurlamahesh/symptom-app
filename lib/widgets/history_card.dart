import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class HistoryCard extends StatefulWidget {
  final Prediction prediction;

  const HistoryCard({super.key, required this.prediction});

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.prediction;
    final color = AppTheme.confidenceColor(p.confidence);
    final dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(p.timestamp.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Color dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    // Disease name
                    Expanded(
                      child: Text(
                        p.disease,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // Confidence badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${p.confidence.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.medical_information_outlined,
                        size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      '${p.symptoms.length} symptom${p.symptoms.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    if (p.age != null && p.sex != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.person_outline_rounded,
                          size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        '${p.age}y • ${p.sex![0]}',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                    const Spacer(),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade400, size: 20),
                    ),
                  ],
                ),

                // Expandable section
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _buildExpanded(p),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded(Prediction p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        
        // Dynamic Specialist Recommendation
        if (p.recommendation != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.medical_services_rounded, color: AppTheme.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.recommendation!,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Patient Intake Profile
        if (p.age != null) ...[
          Text(
            'Patient Intake Profile',
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHistoryProfileItem('Age/Sex', '${p.age}y • ${p.sex}'),
                    _buildHistoryProfileItem('Smoking', p.smoker == 'Yes' ? 'Smoker' : 'Non-smoker'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHistoryProfileItem('Weight/Height', '${p.weight?.toStringAsFixed(0) ?? 'N/A'} kg • ${p.height?.toStringAsFixed(0) ?? 'N/A'} cm'),
                    _buildHistoryProfileItem('Severity', p.severity ?? 'N/A'),
                  ],
                ),
                if (p.existingConditions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildHistoryProfileItem('Existing Conditions', p.existingConditions.map((e) => e.toUpperCase()).join(', ')),
                ],
              ],
            ),
          ),
        ],
        
        // Symptoms
        Text(
          'Symptoms',
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: p.symptoms.map((s) {
            final display = s
                .split('_')
                .map((w) => w[0].toUpperCase() + w.substring(1))
                .join(' ');
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                display,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Precautions
        Text(
          'Precautions',
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        ...p.precautions.map((pr) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                        color: AppTheme.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pr,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => _downloadReport(context, p.id),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: Text(
              'Download PDF Report',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Future<void> _downloadReport(BuildContext context, int? id) async {
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report ID is not available.')),
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

  Widget _buildHistoryProfileItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 11.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
