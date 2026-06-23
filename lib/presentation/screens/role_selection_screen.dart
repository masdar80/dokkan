import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/auth_provider.dart';
import 'package:dokkan/presentation/screens/pos_screen.dart';
import 'package:dokkan/presentation/screens/home_screen.dart';
import 'package:dokkan/presentation/widgets/admin_pin_dialog.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/App Info Header
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
                      Icons.storefront,
                      size: 72,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'دكــان',
                    style: GoogleFonts.cairo(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                  Text(
                    'نظام إدارة المبيعات والمخازن',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  const SizedBox(height: 48),

                  Text(
                    'اختر وضع التشغيل للبدء:',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Selection Layout (Responsive Row or Column)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.maxWidth;
                      if (width > 600) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(child: _buildRoleCard(context, isCashier: true)),
                            const SizedBox(width: 20),
                            Expanded(child: _buildRoleCard(context, isCashier: false)),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildRoleCard(context, isCashier: true),
                            const SizedBox(height: 20),
                            _buildRoleCard(context, isCashier: false),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, {required bool isCashier}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final title = isCashier ? 'وضع الكاشير' : 'وضع المدير (المالك)';
    final desc = isCashier
        ? 'إجراء عمليات البيع المباشر، قراءة الباركود، وإنشاء فواتير مبيعات سريعة.'
        : 'إدارة المواد والمخزون، الموردين، كشوفات الزبائن، والتقارير المالية والأرباح.';
    final icon = isCashier ? Icons.shopping_basket : Icons.admin_panel_settings;
    final color = isCashier ? Colors.teal.shade600 : Theme.of(context).primaryColor;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        onTap: () async {
          if (isCashier) {
            auth.logout(); // Set isAdminMode = false
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const POSScreen()),
            );
          } else {
            final pinCorrect = await showAdminPinDialog(context);
            if (pinCorrect && context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: color,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: Colors.blueGrey.shade500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
