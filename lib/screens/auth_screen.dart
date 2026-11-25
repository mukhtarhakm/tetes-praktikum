import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/app_ui.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!email.text.contains('@') || password.text.length < 6) {
      showAppMessage(
        context,
        'Isi email yang benar dan kata sandi minimal 6 karakter.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      if (register) {
        final hasSession = await widget.controller.register(
          email.text,
          password.text,
        );
        if (mounted && !hasSession) {
          showAppMessage(
            context,
            'Periksa email untuk mengonfirmasi akun, lalu masuk.',
          );
          setState(() => register = false);
        }
      } else {
        await widget.controller.login(email.text, password.text);
      }
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'Akun belum bisa diakses. Periksa data dan koneksi internet.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.ink,
                  child: Icon(
                    Icons.water_drop_rounded,
                    color: AppColors.olive,
                    size: 34,
                  ),
                ),
                const SizedBox(height: AppSpace.section),
                Text('Tetes', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Jurnal seduh V60 milikmu.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSpace.section),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        register ? 'Buat akun' : 'Selamat datang',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpace.xxl),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextField(
                        controller: password,
                        obscureText: true,
                        autofillHints: [
                          register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onSubmitted: (_) => submit(),
                        decoration: const InputDecoration(
                          labelText: 'Kata sandi',
                        ),
                      ),
                      const SizedBox(height: AppSpace.xxl),
                      AppButton(
                        label: register ? 'Daftar' : 'Masuk',
                        onPressed: submit,
                        busy: busy,
                      ),
                      const SizedBox(height: AppSpace.md),
                      Center(
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => register = !register),
                          child: Text(
                            register
                                ? 'Sudah punya akun? Masuk'
                                : 'Belum punya akun? Daftar',
                          ),
                        ),
                      ),
                    ],
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
