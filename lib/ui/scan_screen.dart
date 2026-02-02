import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../viewmodels/scan_view_model.dart';
import 'device_control_screen.dart';
import 'settings_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    // Automatically start scanning when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ScanViewModel>(context, listen: false).startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Using Consumer here to rebuild when scan logic changes
    return Consumer<ScanViewModel>(
      builder: (context, scanViewModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.scanTitle),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: AppStrings.configureUuidsTooltip,
                onPressed: () async {
                  final scanViewModel = Provider.of<ScanViewModel>(
                    context,
                    listen: false,
                  );
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  // Refresh scan results with new settings
                  scanViewModel.startScan();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Progress Bar Logic
              if (scanViewModel.isScanning)
                LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                ),

              // Empty/Off State Layer
              if (!scanViewModel.isScanning &&
                  scanViewModel.adapterState == BluetoothAdapterState.off)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_disabled_rounded,
                          size: 60,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.bluetoothOff,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.turnOnBluetooth,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (scanViewModel.scanResults.isEmpty &&
                  !scanViewModel.isScanning)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.radar_rounded,
                          size: 60,
                          color: AppColors.neutralGrey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.noDevicesFound,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Scan Results List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: scanViewModel.scanResults.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final result = scanViewModel.scanResults[index];
                    final deviceName = result.device.platformName.isNotEmpty
                        ? result.device.platformName
                        : AppStrings.unknownDevice;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.bluetooth_rounded,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            deviceName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                result.device.remoteId.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.signal_cellular_alt,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${result.rssi}${AppStrings.dBmLabel}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final shouldConnect = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  icon: const Icon(
                                    Icons.bluetooth_audio_rounded,
                                    size: 48,
                                    color: AppColors.primary,
                                  ),
                                  title: const Text(
                                    AppStrings.connectConfirmationTitle,
                                    textAlign: TextAlign.center,
                                  ),
                                  content: Text(
                                    "${AppStrings.connectConfirmationMessage}$deviceName?",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  actionsAlignment: MainAxisAlignment.center,
                                  actions: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text(
                                        AppStrings.cancelAction,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text(
                                        AppStrings.connectAction,
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (shouldConnect == true) {
                                scanViewModel.stopScan();
                                if (!context.mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DeviceControlScreen(
                                      device: result.device,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text(AppStrings.connectAction),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Beautiful Bottom Button Area
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scanViewModel.isScanning
                        ? AppColors.error
                        : theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.shadow.withValues(alpha: 0.3),
                  ),
                  onPressed: scanViewModel.isScanning
                      ? scanViewModel.stopScan
                      : scanViewModel.startScan,
                  icon: Icon(
                    scanViewModel.isScanning
                        ? Icons.stop_rounded
                        : Icons.refresh_rounded,
                  ),
                  label: Text(
                    scanViewModel.isScanning
                        ? AppStrings.stopScanning
                        : AppStrings.startScanning,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
