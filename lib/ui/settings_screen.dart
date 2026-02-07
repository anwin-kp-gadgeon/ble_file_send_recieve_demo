import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../utils/log_service.dart';
import '../viewmodels/settings_view_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _serviceController;
  late TextEditingController _firmwareController;
  late TextEditingController _logController;

  // Track values to detect external changes (like Reset)
  String? _lastServiceM;
  String? _lastFirmwareM;
  String? _lastLogM;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsViewModel>(context, listen: false);
    _initControllers(settings);
  }

  void _initControllers(SettingsViewModel settings) {
    _serviceController = TextEditingController(text: settings.serviceUuid);
    _firmwareController = TextEditingController(
      text: settings.firmwareInputCharUuid,
    );
    _logController = TextEditingController(text: settings.logOutputCharUuid);
    _updateLastValues(settings);
  }

  void _updateLastValues(SettingsViewModel settings) {
    _lastServiceM = settings.serviceUuid;
    _lastFirmwareM = settings.firmwareInputCharUuid;
    _lastLogM = settings.logOutputCharUuid;
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _firmwareController.dispose();
    _logController.dispose();
    super.dispose();
  }

  void _restoreDefaults() async {
    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(AppStrings.resetDefaultsTitle),
        content: const Text(AppStrings.resetDefaultsMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(AppStrings.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(AppStrings.resetAction),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final settings = Provider.of<SettingsViewModel>(context, listen: false);
      await settings.resetToDefaults();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.restoredDefaults),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _saveSettings() async {
    // 1. Unfocus any active text field to ensure pending changes are committed
    FocusManager.instance.primaryFocus?.unfocus();

    // 2. Validate the form
    final isValid = _formKey.currentState?.validate() ?? false;

    if (isValid) {
      try {
        final settings = Provider.of<SettingsViewModel>(context, listen: false);

        debugPrint(AppStrings.savingSettingsLog);

        // Prevent Consumer from overwriting our correct values during the notifyListeners() cycle
        _lastServiceM = _serviceController.text;
        _lastFirmwareM = _firmwareController.text;
        _lastLogM = _logController.text;

        // 3. Update settings
        await settings.updateUuids(
          service: _serviceController.text,
          firmware: _firmwareController.text,
          log: _logController.text,
        );

        // 4. Show success and exit
        if (mounted) {
          _showTopToast(AppStrings.configSaved);
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint("${AppStrings.errorSavingConfig}$e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${AppStrings.errorSavingConfig}$e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // 5. If invalid, inform the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.validationFixErrors),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  void _showTopToast(String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(AppStrings.settingsTitle),
          elevation: 0,
          backgroundColor: AppColors.surface,
          actions: [
            TextButton.icon(
              onPressed: () => _restoreDefaults(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(AppStrings.resetAction),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        body: Consumer<SettingsViewModel>(
          builder: (context, settings, child) {
            // Sync controllers if model changed externally (e.g. Reset or Init Load)
            if (settings.serviceUuid != _lastServiceM ||
                settings.firmwareInputCharUuid != _lastFirmwareM ||
                settings.logOutputCharUuid != _lastLogM) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _serviceController.text = settings.serviceUuid;
                  _firmwareController.text = settings.firmwareInputCharUuid;
                  _logController.text = settings.logOutputCharUuid;
                  _updateLastValues(settings);
                }
              });
            }

            if (settings.isLoading) {
              // Optional: Show loading overlay, but keep form visible if possible
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoCard(theme),
                    const SizedBox(height: 24),

                    Text(
                      AppStrings.serviceConfigTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildUuidField(
                      controller: _serviceController,
                      label: AppStrings.serviceUuidLabel,
                      hint: AppStrings.serviceUuidHint,
                      icon: Icons.bluetooth_connected,
                      theme: theme,
                    ),

                    const SizedBox(height: 24),
                    Text(
                      AppStrings.characteristicsTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildUuidField(
                      controller: _firmwareController,
                      label: AppStrings.firmwareCharLabel,
                      hint: AppStrings.firmwareCharHint,
                      icon: Icons.upload_file,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                    _buildUuidField(
                      controller: _logController,
                      label: AppStrings.logCharLabel,
                      hint: AppStrings.logCharHint,
                      icon: Icons.terminal,
                      theme: theme,
                    ),

                    const SizedBox(height: 32),
                    Text(
                      'Crash Logs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await LogService().shareLogs();
                            },
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('Share Logs'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await LogService().clearLogs();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Crash logs cleared'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_sweep_rounded),
                            label: const Text('Clear Logs'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_rounded),
            label: const Text(AppStrings.saveConfigAction),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppStrings.settingsInfo,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUuidField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(fontFamily: "monospace", fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (value) {
            return Provider.of<SettingsViewModel>(
              context,
              listen: false,
            ).validateUuid(value);
          },
        ),
      ],
    );
  }
}
