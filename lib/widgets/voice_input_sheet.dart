import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/health_provider.dart';
import '../utils/app_theme.dart';

class VoiceInputSheet extends StatefulWidget {
  const VoiceInputSheet({super.key});

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isInitialized = false;
  String _speechError = '';
  final TextEditingController _textController = TextEditingController();
  
  Timer? _simulationTimer;
  bool _isSimulating = false;
  late AnimationController _micPulseController;

  // Quick simulation options
  final List<String> _simulations = [
    "I have fever and headache for 3 days.",
    "Severe chest pain and difficulty breathing.",
    "Mild sneezing and runny nose since yesterday.",
    "I have stomach ache and nausea.",
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  void _updatePulseState() {
    if (_isListening) {
      _micPulseController.repeat(reverse: true);
    } else {
      _micPulseController.stop();
      _micPulseController.reset();
    }
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'listening') {
            setState(() {
              _isListening = true;
              _speechError = '';
            });
            _updatePulseState();
          } else if (status == 'notListening' || status == 'done') {
            setState(() {
              _isListening = false;
            });
            _updatePulseState();
          }
        },
        onError: (val) {
          debugPrint('Speech error: ${val.errorMsg}');
          setState(() {
            _isListening = false;
            _speechError = val.errorMsg;
          });
          _updatePulseState();
        },
      );
      setState(() {
        _isInitialized = available;
      });
    } catch (e) {
      debugPrint('Speech exception: $e');
      setState(() {
        _isInitialized = false;
        _speechError = 'Not supported or permissions denied';
      });
    }
  }

  void _startSimulation() {
    setState(() {
      _isListening = true;
      _isSimulating = true;
      _speechError = 'Microphone not detected. Running demo simulation...';
      _textController.text = '';
    });
    _updatePulseState();

    const simulatedText = "I have fever and headache for 3 days.";
    int charIndex = 0;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!_isSimulating || !mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < simulatedText.length) {
        setState(() {
          _textController.text += simulatedText[charIndex];
        });
        charIndex++;
      } else {
        timer.cancel();
        setState(() {
          _isListening = false;
          _isSimulating = false;
          _speechError = 'Demo finished. You can now tap Apply below!';
        });
        _updatePulseState();
      }
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isListening = false;
      _isSimulating = false;
    });
    _updatePulseState();
  }

  void _startListening() async {
    if (!_isInitialized) {
      // Try initializing again
      await _initSpeech();
      if (!_isInitialized) {
        _startSimulation();
        return;
      }
    }

    setState(() {
      _isListening = true;
      _speechError = '';
    });
    _updatePulseState();

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isListening = false;
        _speechError = 'Error starting microphone: $e';
      });
      _updatePulseState();
    }
  }

  void _stopListening() async {
    if (_isSimulating) {
      _stopSimulation();
      return;
    }
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Error stopping: $e');
    }
    setState(() {
      _isListening = false;
    });
    _updatePulseState();
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _simulationTimer?.cancel();
    _micPulseController.dispose();
    try {
      _speech.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboardHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          
          // Sheet Title
          Row(
            children: [
              const Icon(Icons.mic_none_rounded, color: AppTheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Voice Symptom Input',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 8),
          
          Text(
            'Describe what symptoms you have and for how long. The AI will auto-select them.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Transcription text box
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _textController,
              maxLines: 3,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: _isListening ? 'Listening… Speak now' : 'Spoken text will appear here. Or type manually...',
                hintStyle: GoogleFonts.poppins(
                  color: _isListening ? AppTheme.primary.withOpacity(0.5) : Colors.grey.shade400,
                  fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                ),
                border: InputBorder.none,
              ),
            ),
          ),

          if (_speechError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _speechError,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Microphone recorder button with pulse animation
          Center(
            child: GestureDetector(
              onTap: _toggleListening,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isListening)
                    AnimatedBuilder(
                      animation: _micPulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + _micPulseController.value * 0.35,
                          child: Opacity(
                            opacity: 1.0 - _micPulseController.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: _isListening
                          ? const LinearGradient(colors: [AppTheme.danger, Colors.redAccent])
                          : AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.redAccent : AppTheme.primary).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _isListening ? 'Tap to Stop' : 'Tap to Speak',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isListening ? AppTheme.danger : AppTheme.textSecondary,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Simulation Examples
          Text(
            'Try simulating a voice query:',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _simulations.length,
              itemBuilder: (context, idx) {
                final query = _simulations[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      query,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primary,
                      ),
                    ),
                    backgroundColor: AppTheme.primary.withOpacity(0.06),
                    side: BorderSide(color: AppTheme.primary.withOpacity(0.12), width: 1),
                    onPressed: () {
                      // Animate the text matching typing
                      setState(() {
                        _textController.text = query;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Apply Button
          ElevatedButton(
            onPressed: () {
              final text = _textController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please record or enter text first.',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    backgroundColor: AppTheme.danger,
                  ),
                );
                return;
              }
              
              // Stop speech if listening
              if (_isListening) {
                _stopListening();
              }

              // Parse matching symptoms
              final provider = context.read<HealthProvider>();
              final result = provider.parseVoiceInput(text);
              
              Navigator.pop(context, result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Apply & Select Symptoms',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
