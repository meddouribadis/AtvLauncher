
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class MiscPanelPage extends StatelessWidget {
  static const String routeName = "misc_panel";

  const MiscPanelPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    SettingsService settingsService = Provider.of(context);

    return Column(
      children: [
        Text("Miscellaneous", style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              RoundedSwitchListTile(
                autofocus: true,
                value: settingsService.appHighlightAnimationEnabled,
                onChanged: (value) => settingsService.setAppHighlightAnimationEnabled(value),
                title: Text(localizations.appCardHighlightAnimation, style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.filter_center_focus),
              ),
              RoundedSwitchListTile(
                value: settingsService.appKeyClickEnabled,
                onChanged: (value) => settingsService.setAppKeyClickEnabled(value),
                title: Text(localizations.appKeyClick, style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.notifications_active),
              ),
              RoundedSwitchListTile(
                value: settingsService.showCategoryTitles,
                onChanged: (value) => settingsService.setShowCategoryTitles(value),
                title: Text(localizations.showCategoryTitles, style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.abc),
              ),
              RoundedSwitchListTile(
                value: settingsService.showAppNamesBelowIcons,
                onChanged: (value) => settingsService.setShowAppNamesBelowIcons(value),
                title: Text("Show App Names Below Icons", style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.subtitles),
              ),
              RoundedSwitchListTile(
                value: settingsService.dockBackdropFilterDisabled,
                onChanged: (value) => settingsService.setDockBackdropFilterDisabled(value),
                title: Text("Disable Dock Backdrop Blur", style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.blur_off),
              ),
              RoundedSwitchListTile(
                value: settingsService.dockDarkBackground,
                onChanged: (value) => settingsService.setDockDarkBackground(value),
                title: Text("Dark Dock Background", style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.dark_mode),
              ),
              RoundedSwitchListTile(
                value: settingsService.dockShadowEnabled,
                onChanged: (value) => settingsService.setDockShadowEnabled(value),
                title: Text("Dock Shadow", style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.layers),
              ),
              RoundedSwitchListTile(
                value: settingsService.showWatchNextSection,
                onChanged: (value) async {
                  await settingsService.setShowWatchNextSection(value);
                  if (value && context.mounted) {
                    final watchNextService = context.read<WatchNextService>();
                    if (!watchNextService.hasPermission) {
                      await watchNextService.requestPermission();
                    }
                  }
                },
                title: Text(localizations.showWatchNextSection, style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.play_circle_outline),
              ),
              if (settingsService.showWatchNextSection)
                Consumer<WatchNextService>(
                  builder: (context, watchNextService, _) {
                    if (watchNextService.hasPermission) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                localizations.watchNextPermissionTitle,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                localizations.watchNextPermissionBody,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => watchNextService.requestPermission(),
                                icon: const Icon(Icons.lock_open),
                                label: Text(localizations.watchNextGrantPermission),
                              ),
                              TextButton.icon(
                                onPressed: () => watchNextService.refreshPermissionAndItems(),
                                icon: const Icon(Icons.refresh),
                                label: Text(localizations.watchNextCheckPermission),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
