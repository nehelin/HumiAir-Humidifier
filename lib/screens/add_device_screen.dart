import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/language_service.dart';

class AddDeviceScreen extends StatefulWidget {
  final String userId;
  const AddDeviceScreen({super.key, required this.userId});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();

  bool _isTesting = false;
  bool _isAdding = false;
  bool? _testPassed;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  String get _activeUserId =>
      widget.userId.isNotEmpty ? widget.userId : FirestoreService.currentUserId;

  Future<void> _testConnection() async {
    final id = _idCtrl.text.trim().toLowerCase();
    if (id.isEmpty) {
      _showSnack(Tr.enterNameAndIdPrompt, isError: true);
      return;
    }

    setState(() {
      _isTesting = true;
      _testPassed = null;
    });

    try {
      final service = FirestoreService(userId: _activeUserId);
      final exists = await service.deviceExists(id);

      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testPassed = exists;
      });

      if (exists) {
        _showSnack(Tr.deviceFound);
      } else {
        _showSnack(Tr.deviceNotFound, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testPassed = false;
      });
      _showSnack('Test error: $e', isError: true);
    }
  }

  Future<void> _addDevice() async {
    final name = _nameCtrl.text.trim();
    final id = _idCtrl.text.trim().toLowerCase();
    final room = _roomCtrl.text.trim();

    if (name.isEmpty || id.isEmpty) {
      _showSnack(Tr.enterNameAndIdPrompt, isError: true);
      return;
    }

    if (_activeUserId.isEmpty) {
      _showSnack('Please sign in first to add a device.', isError: true);
      return;
    }

    setState(() => _isAdding = true);

    try {
      final service = FirestoreService(userId: _activeUserId);
      await service.addDevice(DeviceModel(
        id: id,
        name: name,
        deviceId: id,
        room: room,
        createdAt: DateTime.now(),
      ));

      if (!mounted) return;
      _showSnack(Tr.success);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      _showSnack('Add device error: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.instance.currentLanguage,
      builder: (context, _, _) {
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
              Tr.addNewDevice,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideCard(),
                const SizedBox(height: 18),
                _buildFormCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideCard() {
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
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_tethering_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    Tr.howToFindIdTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _guideStep('1', Tr.step1),
            _guideStep('2', Tr.step2),
            _guideStep('3', Tr.step3),
            _guideStep('4', Tr.step4),
            _guideStep('5', Tr.step5),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: Colors.yellow, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Tr.deviceIdHintNote,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.deviceDetails,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 16),

            // Device ID field with Test button
            Text(
              Tr.deviceIdLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _idCtrl,
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    onChanged: (_) => setState(() => _testPassed = null),
                    decoration: InputDecoration(
                      hintText: 'humiair_aabbccddeeff',
                      hintStyle: TextStyle(
                        color: Colors.blue.shade300,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: Colors.blue.shade50.withValues(alpha: 0.5),
                      prefixIcon: Icon(Icons.fingerprint_rounded,
                          color: Colors.blue.shade400, size: 18),
                      suffixIcon: _testPassed == true
                          ? Icon(Icons.check_circle_rounded,
                              color: Colors.green.shade500, size: 20)
                          : _testPassed == false
                              ? Icon(Icons.error_outline_rounded,
                                  color: Colors.red.shade400, size: 20)
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade100),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _testPassed == true
                              ? Colors.green.shade300
                              : _testPassed == false
                                  ? Colors.red.shade300
                                  : Colors.blue.shade100,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.blue.shade400, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isTesting ? null : _testConnection,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: _isTesting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue.shade400,
                            ),
                          )
                        : Text(
                            Tr.testConnection,
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            if (_testPassed == false) ...[
              const SizedBox(height: 6),
              Text(
                Tr.deviceNotFound,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade500,
                  height: 1.4,
                ),
              ),
            ] else if (_testPassed == true) ...[
              const SizedBox(height: 6),
              Text(
                Tr.deviceFound,
                style: TextStyle(fontSize: 12, color: Colors.green.shade600),
              ),
            ],
            const SizedBox(height: 14),

            // Device Name
            _buildTextField(
              controller: _nameCtrl,
              label: Tr.deviceNameLabel,
              hint: Tr.deviceNameHint,
              icon: Icons.label_outline_rounded,
            ),
            const SizedBox(height: 12),

            // Room
            _buildTextField(
              controller: _roomCtrl,
              label: Tr.roomLabel,
              hint: Tr.roomHint,
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 20),

            // Add Button
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade500, Colors.cyan.shade500],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isAdding ? null : _addDevice,
                  icon: _isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_rounded, color: Colors.white),
                  label: Text(
                    _isAdding ? Tr.adding : Tr.addDeviceBtn,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(color: Colors.blue.shade900, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.blue.shade300, fontSize: 13),
            filled: true,
            fillColor: Colors.blue.shade50.withValues(alpha: 0.5),
            prefixIcon: Icon(icon, color: Colors.blue.shade400, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade100),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.blue.shade400, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
