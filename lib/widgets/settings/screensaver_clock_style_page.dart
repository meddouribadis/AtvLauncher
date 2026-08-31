/*
 * FLauncher
 * Copyright (C) 2024 LeanBitLab
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flauncher/l10n/app_localizations.dart';
import '../../providers/settings_service.dart';

class ScreensaverClockStylePage extends StatelessWidget {
  static const String routeName = "screensaver_clock_style_panel";

  const ScreensaverClockStylePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsService, String>(
      selector: (_, settingsService) => settingsService.screensaverClockStyle,
      builder: (context, currentStyle, _) {
        final settingsService = context.read<SettingsService>();

        return Column(
          children: [
            Text(AppLocalizations.of(context)!.screensaverClockStyle, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _StyleRadioTile(
                      title: 'Minimal',
                      subtitle: 'Thin, elegant font (Default)',
                      value: 'minimal',
                      groupValue: currentStyle,
                      onChanged: (value) => settingsService.setScreensaverClockStyle(value!),
                      autofocus: currentStyle == 'minimal',
                    ),
                    _StyleRadioTile(
                      title: 'Bold',
                      subtitle: 'Thick, highly visible font',
                      value: 'bold',
                      groupValue: currentStyle,
                      onChanged: (value) => settingsService.setScreensaverClockStyle(value!),
                      autofocus: currentStyle == 'bold',
                    ),
                    _StyleRadioTile(
                      title: 'Retro',
                      subtitle: 'Monospaced, retro terminal style',
                      value: 'retro',
                      groupValue: currentStyle,
                      onChanged: (value) => settingsService.setScreensaverClockStyle(value!),
                      autofocus: currentStyle == 'retro',
                    ),
                    _StyleRadioTile(
                      title: 'Elegant',
                      subtitle: 'Classic serif typeface',
                      value: 'elegant',
                      groupValue: currentStyle,
                      onChanged: (value) => settingsService.setScreensaverClockStyle(value!),
                      autofocus: currentStyle == 'elegant',
                    ),
                    _StyleRadioTile(
                      title: 'Neon',
                      subtitle: 'Ultra-thin, glowing style',
                      value: 'neon',
                      groupValue: currentStyle,
                      onChanged: (value) => settingsService.setScreensaverClockStyle(value!),
                      autofocus: currentStyle == 'neon',
                    ),
                    _StyleRadioTile(
                      title: 'Pixel',
                      subtitle: 'Bold monospaced, arcade feel',
                      value: 'pixel',
                      groupValue: currentStyle,
                      onChanged: (value) => settingsService.setScreensaverClockStyle(value!),
                      autofocus: currentStyle == 'pixel',
                    ),
                    _StyleRadioTile(
                      title: 'Digital',
                      subtitle: 'Clean monospaced display',
                      value: 'digital',
                      groupValue: currentStyle,
                      onChanged: (value) => settingsService.setScreensaverClockStyle(value!),
                      autofocus: currentStyle == 'digital',
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StyleRadioTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;
  final bool autofocus;

  const _StyleRadioTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  State<_StyleRadioTile> createState() => _StyleRadioTileState();
}

class _StyleRadioTileState extends State<_StyleRadioTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.value == widget.groupValue;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return RepaintBoundary(
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onChanged(widget.value);
            return null;
          }),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) {
            widget.onChanged(widget.value);
            return null;
          }),
        },
        child: Focus(
          autofocus: widget.autofocus,
          onFocusChange: (hasFocus) {
            setState(() {
              _hasFocus = hasFocus;
            });
            if (hasFocus) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          },
          child: InkWell(
            onTap: () {
              widget.onChanged(widget.value);
            },
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _hasFocus ? Colors.white.withOpacity(0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: _hasFocus
                    ? Border.all(color: primaryColor, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: primaryColor)
                  else
                    Icon(Icons.circle_outlined, color: Colors.white38),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
