import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/health_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/symptom_chip.dart';
import '../widgets/animated_button.dart';
import '../widgets/voice_input_sheet.dart';

class SymptomScreen extends StatefulWidget {
  const SymptomScreen({super.key});

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> {
  int _currentStep = 0; // 0 = Select Symptoms, 1 = Patient Intake Profile
  
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightFocusNode = FocusNode();
  final _heightFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final provider = context.read<HealthProvider>();
    _weightController.text = provider.weight.toStringAsFixed(0);
    _heightController.text = provider.height.toStringAsFixed(0);
    
    // Listen to focus changes to trigger rebuilds for beautiful focus animations
    _weightFocusNode.addListener(_onFocusChange);
    _heightFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _weightFocusNode.removeListener(_onFocusChange);
    _heightFocusNode.removeListener(_onFocusChange);
    _weightFocusNode.dispose();
    _heightFocusNode.dispose();
    super.dispose();
  }

  void _openVoiceInput(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoiceInputSheet(),
    );

    if (result != null && context.mounted) {
      final int matchedCount = result['symptomsMatched'] ?? 0;
      final List<String> matchedNames = List<String>.from(result['matchedNames'] ?? []);
      final String duration = result['duration'] ?? '';
      final String severity = result['severity'] ?? '';

      if (matchedCount > 0) {
        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Input Parsed Successfully!',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  'Detected: ${matchedNames.join(", ")}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                ),
                Text(
                  'Duration: $duration | Severity: $severity',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );

        // Transition to profile intake form step since symptoms were successfully auto-selected
        setState(() {
          _currentStep = 1;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No symptoms detected. Try saying "I have fever and cough" or select symptoms manually.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<HealthProvider>(
      builder: (context, provider, _) {
        final selectedCount = provider.selectedSymptoms.length;
        return Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_currentStep > 0)
                        IconButton(
                          onPressed: () => setState(() => _currentStep = 0),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      const Icon(Icons.favorite_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'AI Health Checker',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pushNamed('/chat'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                        tooltip: 'Health Assistant',
                      ),
                      if (selectedCount > 0 && _currentStep == 0)
                        GestureDetector(
                          onTap: () => provider.clearSelection(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Clear',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentStep == 0 ? 'Select your symptoms' : 'Patient Profile',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentStep == 0
                        ? 'Tap one or more symptoms you are experiencing'
                        : 'Tell us a bit about yourself for personalized AI predictions',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                  if (_currentStep == 0) ...[
                    const SizedBox(height: 16),
                    // Search bar with Voice Input Button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) =>
                                context.read<HealthProvider>().setSearch(v),
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search symptoms…',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Shimmer.fromColors(
                          baseColor: Colors.white,
                          highlightColor: Colors.blue.shade100,
                          period: const Duration(seconds: 3),
                          child: GestureDetector(
                            onTap: () => _openVoiceInput(context),
                            child: Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.mic_rounded,
                                color: AppTheme.primary,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<HealthProvider>(
      builder: (context, provider, _) {
        Widget activeWidget;
        
        if (_currentStep == 1) {
          activeWidget = Stack(
            key: const ValueKey<int>(1),
            children: [
              _buildPatientProfileForm(context, provider),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildPredictBar(context, provider),
              ),
            ],
          );
        } else if (provider.symptomsState == AppState.loading) {
          activeWidget = KeyedSubtree(
            key: const ValueKey<int>(2),
            child: _buildShimmer(),
          );
        } else if (provider.symptomsState == AppState.error) {
          activeWidget = KeyedSubtree(
            key: const ValueKey<int>(3),
            child: _buildError(context, provider),
          );
        } else {
          final symptoms = provider.filteredSymptoms;
          activeWidget = Stack(
            key: const ValueKey<int>(0),
            children: [
              // Symptom grid
              RefreshIndicator(
                onRefresh: () => provider.loadSymptoms(),
                color: AppTheme.primary,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.6,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final s = symptoms[i];
                            return SymptomChipWidget(
                              symptom: s,
                              onTap: () => provider.toggleSymptom(s.id),
                            )
                                .animate()
                                .fadeIn(delay: Duration(milliseconds: i * 15))
                                .scale(
                                    begin: const Offset(0.85, 0.85),
                                    duration: 250.ms);
                          },
                          childCount: symptoms.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom selected bar + predict button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildPredictBar(context, provider),
              ),
            ],
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final keyVal = (child.key as ValueKey<int>?)?.value ?? 0;
            
            // Only perform directional slide-transitions for Step 0 and Step 1
            if (keyVal <= 1) {
              final isEntering = keyVal == _currentStep;
              final slideAnimation = Tween<Offset>(
                begin: Offset(
                  isEntering
                      ? (_currentStep == 1 ? 0.30 : -0.30)
                      : (_currentStep == 1 ? -0.30 : 0.30),
                  0,
                ),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              ));

              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            }
            
            // Shimmer/Error fades in/out standardly
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: activeWidget,
        );
      },
    );
  }

  Widget _buildPatientProfileForm(BuildContext context, HealthProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Demographics & Lifestyle Card ──────────────────────────────────────
          _buildCard(
            title: 'Demographics & Lifestyle',
            icon: Icons.person_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Age Selector
                Row(
                  children: [
                    Text('Age', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: provider.age > 1 ? () => provider.setAge(provider.age - 1) : null,
                            icon: const Icon(Icons.remove, size: 16),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: Text(
                              '${provider.age}',
                              key: ValueKey<int>(provider.age),
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.primary),
                            ),
                          ),
                          IconButton(
                            onPressed: provider.age < 120 ? () => provider.setAge(provider.age + 1) : null,
                            icon: const Icon(Icons.add, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: provider.age.toDouble(),
                  min: 1,
                  max: 100,
                  activeColor: AppTheme.primary,
                  inactiveColor: Colors.grey.shade200,
                  onChanged: (v) => provider.setAge(v.round()),
                ),
                const SizedBox(height: 16),
                
                // Gender Selection
                Text('Sex / Gender', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSegmentButton(
                      label: 'Male',
                      icon: Icons.male_rounded,
                      isSelected: provider.sex == 'Male',
                      onTap: () => provider.setSex('Male'),
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentButton(
                      label: 'Female',
                      icon: Icons.female_rounded,
                      isSelected: provider.sex == 'Female',
                      onTap: () => provider.setSex('Female'),
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentButton(
                      label: 'Other',
                      icon: Icons.transgender_rounded,
                      isSelected: provider.sex == 'Other',
                      onTap: () => provider.setSex('Other'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Smoking Status
                Text('Smoking Status', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSegmentButton(
                      label: 'Smoker',
                      icon: Icons.smoking_rooms_rounded,
                      isSelected: provider.smoker == 'Yes',
                      onTap: () => provider.setSmoker('Yes'),
                    ),
                    const SizedBox(width: 12),
                    _buildSegmentButton(
                      label: 'Non-Smoker',
                      icon: Icons.smoke_free_rounded,
                      isSelected: provider.smoker == 'No',
                      onTap: () => provider.setSmoker('No'),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 16),

          // ── Vitals & Health History Card ───────────────────────────────────────
          _buildCard(
            title: 'Vitals & Health History',
            icon: Icons.favorite_border_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Weight', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: _weightFocusNode.hasFocus
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                            child: TextField(
                              controller: _weightController,
                              focusNode: _weightFocusNode,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.poppins(fontSize: 14),
                              onChanged: (v) => provider.setWeight(double.tryParse(v) ?? 70.0),
                              decoration: InputDecoration(
                                hintText: 'Weight',
                                suffixText: 'kg',
                                prefixIcon: Icon(
                                  Icons.scale_rounded,
                                  color: _weightFocusNode.hasFocus ? AppTheme.primary : AppTheme.textSecondary,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ).animate(target: _weightFocusNode.hasFocus ? 1.0 : 0.0)
                           .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.02, 1.02), duration: 200.ms, curve: Curves.easeOut),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Height', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: _heightFocusNode.hasFocus
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                            child: TextField(
                              controller: _heightController,
                              focusNode: _heightFocusNode,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.poppins(fontSize: 14),
                              onChanged: (v) => provider.setHeight(double.tryParse(v) ?? 170.0),
                              decoration: InputDecoration(
                                hintText: 'Height',
                                suffixText: 'cm',
                                prefixIcon: Icon(
                                  Icons.height_rounded,
                                  color: _heightFocusNode.hasFocus ? AppTheme.primary : AppTheme.textSecondary,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ).animate(target: _heightFocusNode.hasFocus ? 1.0 : 0.0)
                           .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.02, 1.02), duration: 200.ms, curve: Curves.easeOut),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Medical History Chips
                Text('Existing Medical Conditions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Asthma', 'COPD', 'Diabetes', 'Hypertension', 'Heart Disease', 'Allergies'].map((condition) {
                    final isSelected = provider.existingConditions.contains(condition.toLowerCase());
                    return FilterChip(
                      label: Text(condition),
                      selected: isSelected,
                      onSelected: (_) => provider.toggleCondition(condition.toLowerCase()),
                      selectedColor: AppTheme.primary.withOpacity(0.12),
                      checkmarkColor: AppTheme.primary,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ).animate(target: isSelected ? 1.0 : 0.0)
                     .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.04, 1.04), duration: 200.ms, curve: Curves.easeOutBack);
                  }).toList(),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 16),

          // ── Symptom Timeline & Severity Card ──────────────────────────────────
          _buildCard(
            title: 'Symptom Profile',
            icon: Icons.analytics_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Symptom Duration
                Text('How long have you had these symptoms?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['Less than 24h', '1-3 days', '4-7 days', '1-2 weeks', 'More than 2 weeks'].map((dur) {
                    final isSelected = provider.duration == dur;
                    return ChoiceChip(
                      label: Text(dur),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) provider.setDuration(dur);
                      },
                      selectedColor: AppTheme.primary.withOpacity(0.12),
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ).animate(target: isSelected ? 1.0 : 0.0)
                     .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.04, 1.04), duration: 200.ms, curve: Curves.easeOutBack);
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Symptom Severity
                Text('How severe are your symptoms?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSeverityButton(
                      label: 'Mild',
                      color: AppTheme.success,
                      isSelected: provider.severity == 'Mild',
                      onTap: () => provider.setSeverity('Mild'),
                    ),
                    const SizedBox(width: 8),
                    _buildSeverityButton(
                      label: 'Moderate',
                      color: AppTheme.warning,
                      isSelected: provider.severity == 'Moderate',
                      onTap: () => provider.setSeverity('Moderate'),
                    ),
                    const SizedBox(width: 8),
                    _buildSeverityButton(
                      label: 'Severe',
                      color: AppTheme.danger,
                      isSelected: provider.severity == 'Severe',
                      onTap: () => provider.setSeverity('Severe'),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryLight, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                size: 18,
              ).animate(target: isSelected ? 1.0 : 0.0)
               .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.15, 1.15), duration: 200.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ).animate(target: isSelected ? 1.0 : 0.0)
       .scale(begin: const Offset(0.97, 0.97), end: const Offset(1.03, 1.03), duration: 250.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildSeverityButton({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ).animate(target: isSelected ? 1.0 : 0.0)
       .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.04, 1.04), duration: 250.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildPredictBar(BuildContext context, HealthProvider provider) {
    final selected = provider.selectedSymptoms;
    final isPredicting = provider.predictionState == AppState.loading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selected.isNotEmpty && _currentStep == 0) ...[
            Text(
              '${selected.length} symptom${selected.length > 1 ? 's' : ''} selected',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: selected.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    selected[i].displayName,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: AnimatedButton(
              enabled: selected.isNotEmpty && !isPredicting,
              child: ElevatedButton(
                onPressed: selected.isEmpty || isPredicting
                    ? null
                    : () async {
                        if (_currentStep == 0) {
                          setState(() {
                            _currentStep = 1;
                          });
                        } else {
                          final success =
                              await context.read<HealthProvider>().predict();
                          if (success && context.mounted) {
                            Navigator.of(context).pushNamed('/result');
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.predictionError,
                                  style: GoogleFonts.poppins(color: Colors.white),
                                ),
                                backgroundColor: AppTheme.danger,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      selected.isEmpty ? Colors.grey.shade300 : null,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ).copyWith(
                  backgroundColor: selected.isEmpty
                      ? WidgetStateProperty.all(Colors.grey.shade300)
                      : WidgetStateProperty.resolveWith((states) {
                          return AppTheme.primary;
                        }),
                ),
                child: isPredicting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _currentStep == 0
                                ? Icons.arrow_forward_rounded
                                : Icons.auto_awesome_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selected.isEmpty
                                ? 'Select symptoms to continue'
                                : (_currentStep == 0
                                    ? 'Continue to Patient Profile'
                                    : 'Analyze Profile & Symptoms'),
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(
            18,
            (i) => Container(
              width: 120,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, HealthProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              provider.symptomsError,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            AnimatedButton(
              child: ElevatedButton.icon(
                onPressed: () => provider.loadSymptoms(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
