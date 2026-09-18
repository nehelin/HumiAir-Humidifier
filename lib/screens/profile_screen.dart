import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/language_service.dart';
import 'devices_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    final email = user?.email ?? 'user@humiair.com';
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : email.split('@').first;
    final firestoreService = FirestoreService(userId: uid);

    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.instance.currentLanguage,
      builder: (context, currentLang, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF0F9FF),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.blue.shade700, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              Tr.profileAndSettings,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User Card Header
              _buildUserHeaderCard(displayName, email, uid),
              const SizedBox(height: 16),

              // Linked Devices Summary Card
              _buildDevicesSummaryCard(firestoreService),
              const SizedBox(height: 16),

              // Preferences Section
              _buildPreferencesCard(),
              const SizedBox(height: 16),

              // App Info Section
              _buildAppInfoCard(),
              const SizedBox(height: 20),

              // Sign Out Button
              _buildSignOutButton(context),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserHeaderCard(String name, String email, String uid) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade600, Colors.cyan.shade500],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'H',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesSummaryCard(FirestoreService firestoreService) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<DeviceModel>>(
          stream: firestoreService.streamDevices(),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.devices_rounded,
                      color: Colors.blue.shade600, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Tr.linkedDevices,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Text(
                        '$count ${LanguageService.instance.isBengali ? 'টি ডিভাইস' : 'Device(s)'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DevicesScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    LanguageService.instance.isBengali ? 'দেখুন' : 'View',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    final isBn = LanguageService.instance.isBengali;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.appSettings,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 14),

            // Language Switcher Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.language_rounded,
                      color: Colors.cyan.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Tr.language,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Text(
                        isBn ? 'বাংলা নির্বাচিত' : 'English Selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _langChoiceButton('English', 'en', !isBn),
                      _langChoiceButton('বাংলা', 'bn', isBn),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Notifications Toggle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.notifications_active_outlined,
                      color: Colors.orange.shade600, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Tr.notifications,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Text(
                        Tr.notificationsDesc,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _notificationsEnabled,
                  activeThumbColor: Colors.blue.shade600,
                  activeTrackColor: Colors.blue.shade200,
                  onChanged: (val) {
                    setState(() => _notificationsEnabled = val);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _langChoiceButton(String label, String code, bool selected) {
    return GestureDetector(
      onTap: () => LanguageService.instance.setLanguage(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.blue.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(Icons.info_outline_rounded, Tr.appVersion, 'v1.0.0'),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _infoRow(Icons.memory_rounded, Tr.firmwareSupport,
                'ESP8266 v2.0 (MAC-ID)'),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _infoRow(Icons.cloud_done_rounded, 'Backend', 'Google Cloud Firestore'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade400),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.blue.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmSignOut(context),
        icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
        label: Text(
          Tr.signOut,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.shade200, width: 1.2),
          backgroundColor: Colors.red.shade50.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(Tr.signOutConfirmTitle,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          Tr.signOutConfirmDesc,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Tr.cancel,
                style: TextStyle(color: Colors.blue.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(Tr.signOut),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await _authService.signOut();
    }
  }
}
