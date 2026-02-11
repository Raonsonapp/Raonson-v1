import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../widgets/raonson_bottom_nav.dart';

class GmailScreen extends StatefulWidget {
  const GmailScreen({super.key});

  @override
  State<GmailScreen> createState() => _GmailScreenState();
}

class _GmailScreenState extends State<GmailScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isValid = false;

  void validateEmail(String value) {
    setState(() {
      isValid = value.endsWith("@gmail.com") && value.length > 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              /// Title
              Center(
                child: Column(
                  children: const [
                    Text(
                      "Raonson",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Connect your Gmail",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              /// Gmail input
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: validateEmail,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "example@gmail.com",
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: RColors.card,
                  suffixIcon: isValid
                      ? const Icon(Icons.check_circle, color: RColors.neon)
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "Only Gmail is supported for now",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),

              const Spacer(),

              /// Finish button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isValid ? RColors.neon : Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isValid
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RaonsonBottomNav(),
                            ),
                          );
                        }
                      : null,
                  child: const Text(
                    "Finish Registration",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
