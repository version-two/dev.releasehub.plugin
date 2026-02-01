import 'package:flutter/material.dart';

import '../config.dart';

/// A customizable download progress widget.
///
/// Can be used standalone or inside a dialog.
class DownloadProgressWidget extends StatelessWidget {
  final Stream<DownloadProgress> progressStream;
  final VoidCallback? onCancel;
  final DownloadProgressStyle style;

  const DownloadProgressWidget({
    super.key,
    required this.progressStream,
    this.onCancel,
    this.style = const DownloadProgressStyle(),
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DownloadProgress>(
      stream: progressStream,
      builder: (context, snapshot) {
        final progress = snapshot.data;
        final progressValue = progress?.progress ?? 0.0;
        final status = progress?.status ?? 'Preparing...';

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status,
              style: style.statusTextStyle ??
                  Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: style.spacing),
            LinearProgressIndicator(
              value: progressValue > 0 ? progressValue : null,
              minHeight: style.progressBarHeight,
              backgroundColor: style.progressBarBackgroundColor ??
                  Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                style.progressBarColor ?? Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: style.spacing / 2),
            Text(
              '${(progressValue * 100).toStringAsFixed(0)}%',
              style: style.percentageTextStyle ??
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (progress != null && progress.totalBytes > 0) ...[
              SizedBox(height: style.spacing / 4),
              Text(
                '${progress.formattedDownloaded} / ${progress.formattedTotal}',
                style: style.bytesTextStyle ??
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
            if (onCancel != null) ...[
              SizedBox(height: style.spacing),
              TextButton(
                onPressed: onCancel,
                child: Text(style.cancelText),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Style configuration for [DownloadProgressWidget]
class DownloadProgressStyle {
  final TextStyle? statusTextStyle;
  final TextStyle? percentageTextStyle;
  final TextStyle? bytesTextStyle;
  final double progressBarHeight;
  final Color? progressBarColor;
  final Color? progressBarBackgroundColor;
  final double spacing;
  final String cancelText;

  const DownloadProgressStyle({
    this.statusTextStyle,
    this.percentageTextStyle,
    this.bytesTextStyle,
    this.progressBarHeight = 6.0,
    this.progressBarColor,
    this.progressBarBackgroundColor,
    this.spacing = 16.0,
    this.cancelText = 'Cancel',
  });
}

/// A simple update available banner widget.
class UpdateAvailableBanner extends StatelessWidget {
  final VersionInfo versionInfo;
  final VoidCallback onUpdate;
  final VoidCallback? onDismiss;
  final UpdateBannerStyle style;

  const UpdateAvailableBanner({
    super.key,
    required this.versionInfo,
    required this.onUpdate,
    this.onDismiss,
    this.style = const UpdateBannerStyle(),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.backgroundColor ?? Theme.of(context).primaryColor,
      elevation: style.elevation,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: style.padding,
          child: Row(
            children: [
              if (style.showIcon)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    style.icon,
                    color: style.iconColor ?? Colors.white,
                    size: style.iconSize,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      style.title,
                      style: style.titleStyle ??
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      style.messageBuilder?.call(versionInfo) ??
                          'Version ${versionInfo.displayVersion} is available',
                      style: style.messageStyle ??
                          TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onUpdate,
                style: TextButton.styleFrom(
                  foregroundColor: style.buttonColor ?? Colors.white,
                ),
                child: Text(
                  style.updateButtonText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close,
                    color: style.dismissButtonColor ?? Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Style configuration for [UpdateAvailableBanner]
class UpdateBannerStyle {
  final Color? backgroundColor;
  final double elevation;
  final EdgeInsets padding;
  final bool showIcon;
  final IconData icon;
  final Color? iconColor;
  final double iconSize;
  final String title;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final String Function(VersionInfo)? messageBuilder;
  final String updateButtonText;
  final Color? buttonColor;
  final Color? dismissButtonColor;

  const UpdateBannerStyle({
    this.backgroundColor,
    this.elevation = 4.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.showIcon = true,
    this.icon = Icons.system_update,
    this.iconColor,
    this.iconSize = 28,
    this.title = 'Update Available',
    this.titleStyle,
    this.messageStyle,
    this.messageBuilder,
    this.updateButtonText = 'UPDATE',
    this.buttonColor,
    this.dismissButtonColor,
  });
}

/// A version check button widget with loading state.
class VersionCheckButton extends StatelessWidget {
  final bool isChecking;
  final VoidCallback onCheck;
  final String? currentVersion;
  final String? buildNumber;
  final VersionCheckButtonStyle style;

  const VersionCheckButton({
    super.key,
    required this.isChecking,
    required this.onCheck,
    this.currentVersion,
    this.buildNumber,
    this.style = const VersionCheckButtonStyle(),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isChecking ? null : onCheck,
      borderRadius: BorderRadius.circular(style.borderRadius),
      child: Container(
        padding: style.padding,
        decoration: style.decoration,
        child: Row(
          children: [
            if (style.showIcon)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: isChecking
                    ? SizedBox(
                        width: style.iconSize,
                        height: style.iconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: style.loadingColor ??
                              Theme.of(context).primaryColor,
                        ),
                      )
                    : Icon(
                        style.icon,
                        size: style.iconSize,
                        color: style.iconColor,
                      ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    style.title,
                    style: style.titleStyle ??
                        Theme.of(context).textTheme.titleSmall,
                  ),
                  if (currentVersion != null)
                    Text(
                      buildNumber != null
                          ? '$currentVersion (build $buildNumber)'
                          : currentVersion!,
                      style: style.versionStyle ??
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  Text(
                    isChecking ? style.checkingText : style.hintText,
                    style: style.hintStyle ??
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: style.chevronColor ?? Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

/// Style configuration for [VersionCheckButton]
class VersionCheckButtonStyle {
  final EdgeInsets padding;
  final BoxDecoration? decoration;
  final double borderRadius;
  final bool showIcon;
  final IconData icon;
  final Color? iconColor;
  final double iconSize;
  final Color? loadingColor;
  final String title;
  final TextStyle? titleStyle;
  final TextStyle? versionStyle;
  final String hintText;
  final String checkingText;
  final TextStyle? hintStyle;
  final Color? chevronColor;

  const VersionCheckButtonStyle({
    this.padding = const EdgeInsets.all(16),
    this.decoration,
    this.borderRadius = 8.0,
    this.showIcon = true,
    this.icon = Icons.info_outline,
    this.iconColor,
    this.iconSize = 24,
    this.loadingColor,
    this.title = 'Version',
    this.titleStyle,
    this.versionStyle,
    this.hintText = 'Tap to check for updates',
    this.checkingText = 'Checking...',
    this.hintStyle,
    this.chevronColor,
  });
}
