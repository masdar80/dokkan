import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.updatePin(_pinController.text);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إعداد رمز المرور الجديد بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.05),
              Theme.of(context).primaryColor.withOpacity(0.15),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon container with gradient
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.security,
                      size: 72,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Welcome and Instructions
                  Text(
                    'تأمين التطبيق',
                    style: GoogleFonts.cairo(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'لحماية بيانات المواد والتقارير والزبائن، يرجى تعيين رمز مرور جديد للمدير بدلاً من الرمز الافتراضي.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        color: Colors.blueGrey.shade600,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form Card
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'رمز المرور الجديد (4 أرقام)',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 4,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                letterSpacing: 8,
                              ),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال رمز المرور الجديد';
                              }
                              if (value.length != 4 || int.tryParse(value) == null) {
                                return 'يجب أن يتكون الرمز من 4 أرقام فقط';
                              }
                              if (value == '1234') {
                                return 'يرجى اختيار رمز مختلف عن الرمز الافتراضي 1234';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'تأكيد رمز المرور',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPinController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 4,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                letterSpacing: 8,
                              ),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى تأكيد رمز المرور';
                              }
                              if (value != _pinController.text) {
                                return 'الرمز غير متطابق';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'حفظ وتفعيل الرمز الجديد',
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
