import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Verify current PIN first
    final isCurrentCorrect = await auth.verifyPin(_currentPinController.text);
    if (!isCurrentCorrect) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رمز المرور الحالي غير صحيح'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Save new PIN
    await auth.updatePin(_newPinController.text);

    if (mounted) {
      setState(() => _isLoading = false);
      _currentPinController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تغيير رمز المرور بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات العامة'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PIN Settings Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'أمان الحساب وتغيير الرمز',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        
                        Text(
                          'رمز المرور الحالي',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _currentPinController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, letterSpacing: 6),
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '••••',
                            prefixIcon: Icon(Icons.lock_open),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال رمز المرور الحالي';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'رمز المرور الجديد',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _newPinController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, letterSpacing: 6),
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '••••',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال الرمز الجديد';
                            }
                            if (value.length != 4 || int.tryParse(value) == null) {
                              return 'يجب أن يتكون الرمز من 4 أرقام';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'تأكيد رمز المرور الجديد',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPinController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, letterSpacing: 6),
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '••••',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى تأكيد الرمز';
                            }
                            if (value != _newPinController.text) {
                              return 'الرمز غير متطابق';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _changePin,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'تحديث رمز المرور',
                                  style: GoogleFonts.cairo(
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
    );
  }
}
