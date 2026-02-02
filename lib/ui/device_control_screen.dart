import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../viewmodels/device_view_model.dart';
import 'widgets/loading_overlay.dart';

class DeviceControlScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceControlScreen({super.key, required this.device});

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  late DeviceViewModel _deviceViewModel;
  late ScaffoldMessengerState _scaffoldMessenger;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use the cached viewmodel if available, or look it up since context is valid here
      final viewModel = Provider.of<DeviceViewModel>(context, listen: false);
      viewModel.connect(widget.device);

      // Monitor for unexpected events
      _eventSubscription = viewModel.events.listen((event) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearMaterialBanners();

        switch (event) {
          case DeviceEvent.reconnecting:
            messenger.showMaterialBanner(
              MaterialBanner(
                content: const Text(AppStrings.reconnecting),
                leading: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textPrimary, // On Amber
                  ),
                ),
                backgroundColor: AppColors.warning,
                contentTextStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                actions: [
                  TextButton(
                    onPressed: () => messenger.hideCurrentMaterialBanner(),
                    child: const Text(
                      AppStrings.hideBanner,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            );
            break;

          case DeviceEvent.reconnectSuccess:
            messenger.showMaterialBanner(
              MaterialBanner(
                content: const Text(AppStrings.reconnectSuccess),
                leading: const Icon(
                  Icons.check_circle,
                  color: AppColors.textLight,
                ),
                backgroundColor: AppColors.success,
                contentTextStyle: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.bold,
                ),
                actions: [
                  TextButton(
                    onPressed: () => messenger.hideCurrentMaterialBanner(),
                    child: const Text(
                      AppStrings.dismissBanner,
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ),
                ],
              ),
            );
            // Auto hide after 2 seconds
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) messenger.clearMaterialBanners();
            });
            break;

          case DeviceEvent.reconnectFailed:
          case DeviceEvent
              .connectionFailed: // Handle initial connection failure too
          case DeviceEvent.unexpectedDisconnect: // Fallback
            messenger.showMaterialBanner(
              MaterialBanner(
                content: Text(
                  event == DeviceEvent.connectionFailed
                      ? AppStrings.connectionFailed
                      : AppStrings.reconnectFailed,
                ),
                leading: const Icon(
                  Icons.error_outline,
                  color: AppColors.textLight,
                ),
                backgroundColor: AppColors.error,
                contentTextStyle: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.bold,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      messenger.hideCurrentMaterialBanner();
                      // Provide an escape if reconnection fails
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text(
                      AppStrings.goBack,
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ),
                ],
              ),
            );
            break;
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference to ViewModel and ScaffoldMessenger safely for use in dispose
    _deviceViewModel = Provider.of<DeviceViewModel>(context, listen: false);
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _scaffoldMessenger.clearMaterialBanners();
    // Disconnect when leaving the screen to ensure clean state
    _deviceViewModel.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<DeviceViewModel>(
      builder: (context, viewModel, child) {
        // Determine loading state
        bool isBusy =
            viewModel.connectionState == DeviceState.connecting ||
            viewModel.connectionState == DeviceState.disconnecting;
        String busyMessage = viewModel.connectionState == DeviceState.connecting
            ? AppStrings.connectingMessage
            : AppStrings.disconnectingMessage;

        return LoadingOverlay(
          isLoading: isBusy,
          message: busyMessage,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 2,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: AppColors.cardBorder, height: 1),
              ),
              title: Text(
                widget.device.platformName.isEmpty
                    ? AppStrings.deviceControlTitle
                    : widget.device.platformName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              automaticallyImplyLeading: false,
              leading: viewModel.connectionState == DeviceState.disconnected
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              actions: [
                if (viewModel.connectionState == DeviceState.connected) ...[
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded),
                    tooltip: AppStrings.deviceDetailsTitle,
                    onPressed: () => _showDeviceInfo(context, widget.device),
                  ),
                  IconButton(
                    icon: const Icon(Icons.power_settings_new_rounded),
                    tooltip: AppStrings.disconnect,
                    color: AppColors.error,
                    onPressed: () async {
                      final shouldDisconnect = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          icon: const Icon(
                            Icons.link_off_rounded,
                            size: 48,
                            color: AppColors.error,
                          ),
                          title: const Text(
                            AppStrings.disconnectConfirmationTitle,
                            textAlign: TextAlign.center,
                          ),
                          content: const Text(
                            AppStrings.disconnectConfirmationMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          actionsAlignment: MainAxisAlignment.center,
                          actions: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(AppStrings.cancelAction),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(AppStrings.disconnect),
                            ),
                          ],
                        ),
                      );

                      if (shouldDisconnect == true && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Card
                  _buildStatusCard(theme, viewModel),

                  const SizedBox(height: 16),

                  // Helpful Hint
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warningBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppStrings.uuidHint,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // UPLOAD SECTION
                  Text(
                    AppStrings.firmwareSectionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionCard(
                    theme,
                    title: AppStrings.updateFirmwareTitle,
                    subtitle: AppStrings.updateFirmwareSubtitle,
                    icon: Icons.system_update_alt_rounded,
                    color: theme.colorScheme.primary,
                    isLoading: viewModel.isUploading,
                    progress: viewModel.uploadProgress,
                    statusText: viewModel.uploadStatus,
                    onTap:
                        viewModel.connectionState == DeviceState.connected &&
                            !viewModel.isUploading
                        ? viewModel.pickAndUploadFirmware
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // DOWNLOAD SECTION
                  Text(
                    AppStrings.diagnosticsSectionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionCard(
                    theme,
                    title: AppStrings.downloadLogsTitle,
                    subtitle: AppStrings.downloadLogsSubtitle,
                    icon: Icons.download_rounded,
                    color: theme.colorScheme.secondary,
                    isLoading: viewModel.isDownloading,
                    statusText: viewModel.downloadStatus,
                    buttonText: viewModel.isDownloading
                        ? AppStrings.stopAndSave
                        : AppStrings.startDownload,
                    onTap: viewModel.connectionState == DeviceState.connected
                        ? () {
                            if (viewModel.isDownloading) {
                              viewModel.stopLogDownload();
                            } else {
                              viewModel.startLogDownload();
                            }
                          }
                        : null,
                    isStopAction: viewModel.isDownloading,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeviceInfo(BuildContext context, BluetoothDevice device) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bluetooth_audio_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.deviceDetailsTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildInfoRow(
                context,
                Icons.devices_other_rounded,
                AppStrings.deviceNameLabel,
                device.platformName.isEmpty
                    ? AppStrings.unknownDevice
                    : device.platformName,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              _buildInfoRow(
                context,
                Icons.perm_identity_rounded,
                AppStrings.deviceIdLabel,
                device.remoteId.toString(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    AppStrings.okAction,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.replaceAll(":", ""),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18),
          color: AppColors.textSecondary,
          onPressed: () {
            // Placeholder: In a real app, integrate Clipboard.setData
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Copied $value"),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusCard(ThemeData theme, DeviceViewModel viewModel) {
    bool isConnected = viewModel.connectionState == DeviceState.connected;
    Color statusColor = isConnected ? theme.colorScheme.secondary : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.neutralGrey),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_disabled_rounded,
              color: statusColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.connectionStatus,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.neutralGreyDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                viewModel.connectionState.name.toUpperCase(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
    double? progress,
    String? statusText,
    String? buttonText,
    bool isStopAction = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (isLoading && progress != null) ...[
              LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withValues(alpha: 0.1),
                color: color,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "${(progress * 100).toStringAsFixed(0)}${AppStrings.percentSymbol}",
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],

            if (statusText != null && statusText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.neutralGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontFamily: AppStrings.monospaceFont,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: isStopAction
                      ? AppColors.error.withValues(alpha: 0.8)
                      : color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading && progress == null
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        buttonText ?? AppStrings.selectFile,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
