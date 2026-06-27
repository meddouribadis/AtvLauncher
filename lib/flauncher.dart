/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
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

import 'dart:math';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flauncher/actions.dart';
import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/cached_blur_backdrop.dart';
import 'package:flauncher/widgets/category_clean_row.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/launcher_alternative_view.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flauncher/widgets/wallpaper_video_background.dart';
import 'package:flauncher/widgets/watch_next_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import 'models/app.dart';
import 'models/category.dart';

const _kDockOuterPadding = EdgeInsets.only(
  left: kLauncherSectionHorizontalPadding,
  right: kLauncherSectionHorizontalPadding,
  bottom: 6,
);

class FLauncher extends StatefulWidget {
  const FLauncher({super.key});

  @override
  State<FLauncher> createState() => _FLauncherState();
}

class _FLauncherState extends State<FLauncher> with WidgetsBindingObserver {
  final GlobalKey<FocusAwareAppBarState> _appBarKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _dockKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<WatchNextService>().refreshPermissionAndItems();
    }
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      MoveFocusToSettingsIntent: CallbackAction<MoveFocusToSettingsIntent>(
        onInvoke: (_) => _appBarKey.currentState?.focusSettings(),
      ),
    },
    child: FocusTraversalGroup(
      policy: RowByRowTraversalPolicy(),
      child: Stack(
        children: [
          RepaintBoundary(
            child: Consumer<WallpaperService>(
              builder: (_, wallpaperService, __) => _wallpaper(context, wallpaperService),
            ),
          ),
          Consumer<LauncherState>(
            builder:
                (_, state, child) => Visibility(
                  replacement: const Center(child: AlternativeLauncherView()),
                  visible: state.launcherVisible,
                  child: child!,
                ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: FocusAwareAppBar(key: _appBarKey),
              // (initialized (data.$1), layoutVersion (data.$2), showAppNamesBelowIcons (data.$3))
              body: Selector2<AppsService, SettingsService, (bool, int, bool)>(
                selector: (_, appsService, settingsService) =>
                    (appsService.initialized, appsService.layoutVersion, settingsService.showAppNamesBelowIcons),
                builder: (context, data, _) {
                  if (data.$1) {
                    return _tvOSLayout(context, context.read<AppsService>(), showAppNames: data.$3);
                  } else {
                    return _emptyState(context);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tvOSLayout(BuildContext context, AppsService appsService, {required bool showAppNames}) {
    final favoritesCategory = appsService.categories.firstWhereOrNull((c) => c.name == 'Favorites');
    final favoriteApps = favoritesCategory?.applications ?? const [];

    final otherSections =
        appsService.launcherSections.where((section) {
          if (section is Category && section.name == 'Favorites') return false;
          return true;
        }).toList();

    final showWatchNextSection = context.select<SettingsService, bool>((s) => s.showWatchNextSection);

    if (favoriteApps.isEmpty && otherSections.isEmpty) return _emptyState(context);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (favoriteApps.isNotEmpty || showWatchNextSection) ...[
          SliverToBoxAdapter(
            child: SizedBox(
              height:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  (showWatchNextSection ? 450 : 150),
            ),
          ),
          if (showWatchNextSection)
            const SliverToBoxAdapter(child: WatchNextRow(isFirstSection: false, isAboveDock: true)),
          if (favoriteApps.isNotEmpty)
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: _dockKey,
                child: Padding(
                  padding: _kDockOuterPadding,
                  child: _dock(context, favoritesCategory!, favoriteApps, appsService),
                ),
              ),
            ),
        ],
        ..._buildSectionSlivers(
          otherSections,
          firstCategoryAlreadyFound: favoriteApps.isNotEmpty,
          showAppNames: showAppNames,
          onFirstSectionFocused: favoriteApps.isNotEmpty ? _scrollDockToTop : null,
        ),
        SliverToBoxAdapter(child: SizedBox(height: _bottomScrollPadding(context, hasDock: favoriteApps.isNotEmpty))),
      ],
    );
  }

  double _bottomScrollPadding(BuildContext context, {required bool hasDock}) {
    if (!hasDock) {
      return 64;
    }
    return MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - kToolbarHeight;
  }

  List<Widget> _buildSectionSlivers(
    List<LauncherSection> sections, {
    bool firstCategoryAlreadyFound = false,
    required bool showAppNames,
    VoidCallback? onFirstSectionFocused,
  }) {
    final List<Widget> slivers = [];
    bool firstCategoryFound = firstCategoryAlreadyFound;
    bool firstBuiltSectionFound = false;

    for (final section in sections) {
      final Key sectionKey = Key(section.id.toString());

      if (section is LauncherSpacer) {
        slivers.add(SliverToBoxAdapter(key: sectionKey, child: SizedBox(height: section.height.toDouble())));
        continue;
      }

      final category = section as Category;
      final filteredApps = category.applications;
      if (filteredApps.isEmpty) continue;

      final bool isFirstSection = !firstCategoryFound;
      if (isFirstSection) firstCategoryFound = true;
      final onAppFocused = !firstBuiltSectionFound ? onFirstSectionFocused : null;
      firstBuiltSectionFound = true;

      slivers.add(
        SliverToBoxAdapter(
          child: Selector<SettingsService, bool>(
            selector: (context, service) => service.showCategoryTitles,
            builder: (context, showTitle, _) {
              if (showTitle) {
                return Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 8, top: 8),
                  child: Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      shadows: const [Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 8)],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      switch (category.type) {
        case CategoryType.row:
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: kLauncherSectionHorizontalPadding,
                  right: kLauncherSectionHorizontalPadding,
                  bottom: 8,
                ),
                child: CategoryRow(
                  key: sectionKey,
                  category: category,
                  applications: filteredApps,
                  isFirstSection: isFirstSection,
                  showTitle: false,
                  onAppFocused: onAppFocused,
                ),
              ),
            ),
          );
          break;
        case CategoryType.grid:
          final gridContentWidth = MediaQuery.sizeOf(context).width - 2 * kLauncherSectionHorizontalPadding;
          final gridAspectRatio = showAppNames
              ? appCardGridAspectRatio(gridContentWidth, category.columnsCount)
              : kAppCardAspectRatio;
          slivers.add(
            SliverPadding(
              padding: const EdgeInsets.only(
                left: kLauncherSectionHorizontalPadding,
                right: kLauncherSectionHorizontalPadding,
                bottom: 8,
              ),
              sliver: SliverGrid(
                key: sectionKey,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: category.columnsCount,
                  childAspectRatio: gridAspectRatio,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 0,
                ),
                delegate: SliverChildBuilderDelegate(
                  childCount: filteredApps.length,
                  findChildIndexCallback: (Key key) {
                    final valueKey = key as ValueKey<String>;
                    final index = filteredApps.indexWhere((app) => app.packageName == valueKey.value);
                    return index >= 0 ? index : null;
                  },
                  (context, index) => Padding(
                    key: Key(filteredApps[index].packageName),
                    padding: const EdgeInsets.symmetric(
                      horizontal: kAppCardHorizontalPadding,
                      vertical: kAppCardVerticalPadding,
                    ),
                    child: AppCard(
                      category: category,
                      application: filteredApps[index],
                      autofocus: index == 0,
                      handleUpNavigationToSettings: isFirstSection && index < category.columnsCount,
                      enforceAspectRatio: false,
                      onFocused: index < category.columnsCount ? onAppFocused : null,
                      ensureVisibleOnFocus: onAppFocused == null || index >= category.columnsCount,
                      onlyScrollWhenNearBottom: true,
                      onMove: (direction) => _onGridMove(context, category, index, direction, filteredApps),
                      onMoveEnd: () => context.read<AppsService>().saveApplicationOrderInCategory(category),
                    ),
                  ),
                ),
              ),
            ),
          );
          break;
      }
    }

    return slivers;
  }

  Future<void> _scrollDockToTop() async {
    final targetOffset = _dockTopScrollOffset();
    if (targetOffset == null) {
      return;
    }

    final position = _scrollController.position;
    if ((targetOffset - position.pixels).abs() < 16) {
      return;
    }

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
    );
  }

  double? _dockTopScrollOffset() {
    final dockContext = _dockKey.currentContext;
    final renderObject = dockContext?.findRenderObject();
    if (!_scrollController.hasClients || renderObject == null) {
      return null;
    }

    final viewport = RenderAbstractViewport.of(renderObject);
    final position = _scrollController.position;
    return viewport.getOffsetToReveal(renderObject, 0).offset.clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  // TO DO : refractor duplicate _onMove code
  void _onGridMove(
    BuildContext context,
    Category category,
    int index,
    AxisDirection direction,
    List<App> filteredApps,
  ) {
    final currentRow = (index / category.columnsCount).floor();
    final totalRows = ((filteredApps.length - 1) / category.columnsCount).floor();

    int? newIndex;
    switch (direction) {
      case AxisDirection.up:
        if (currentRow > 0) newIndex = index - category.columnsCount;
        break;
      case AxisDirection.right:
        if (index < filteredApps.length - 1) newIndex = index + 1;
        break;
      case AxisDirection.down:
        if (currentRow < totalRows) newIndex = min(index + category.columnsCount, filteredApps.length - 1);
        break;
      case AxisDirection.left:
        if (index > 0) newIndex = index - 1;
        break;
    }

    if (newIndex != null) {
      final appsService = context.read<AppsService>();
      final movingApp = filteredApps[index];
      final realOldIndex = category.applications.indexOf(movingApp);
      final realNewIndex = category.applications.indexOf(filteredApps[newIndex]);
      if (realOldIndex >= 0 && realNewIndex >= 0) {
        appsService.reorderApplication(category, realOldIndex, realNewIndex);
        appsService.setPendingReorderFocus(movingApp.packageName, category.id);
      }
    }
  }

  Widget _dock(BuildContext context, Category category, List<App> apps, AppsService appsService) {
    final backdropDisabled = context.select<SettingsService, bool>((s) => s.dockBackdropFilterDisabled);
    final darkBackground = context.select<SettingsService, bool>((s) => s.dockDarkBackground);
    final shadowEnabled = context.select<SettingsService, bool>((s) => s.dockShadowEnabled);

    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: darkBackground ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: darkBackground ? Colors.black.withOpacity(0.15) : Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: CategoryCleanRow(category: category, applications: apps, isFirstSection: false, scrollAlignment: 1.0),
    );

    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: shadowEnabled
              ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: backdropDisabled ? content : CachedBlurBackdrop(sigma: 5, child: content),
        ),
      ),
    );
  }

  Widget _wallpaper(BuildContext context, WallpaperService wallpaperService) {
    final screenSize = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final videoFile = wallpaperService.wallpaperVideoFile;
    if (videoFile != null) {
      return SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: WallpaperVideoBackground(
          key: ValueKey("background_video_${wallpaperService.wallpaperRevision}"),
          file: videoFile,
        ),
      );
    }
    if (wallpaperService.wallpaper != null) {
      return Image(
        image: ResizeImage(wallpaperService.wallpaper!, height: (screenSize.height * dpr).round()),
        key: ValueKey("background_${wallpaperService.wallpaperRevision}"),
        fit: BoxFit.cover,
        height: screenSize.height,
        width: screenSize.width,
      );
    } else {
      return _CachedGradientBackground(key: const Key("background"), gradient: wallpaperService.gradient.gradient);
    }
  }

  Widget _emptyState(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(localizations.loading, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// Renders a [Gradient] once into a rasterized [ui.Image] and blits it as a
/// texture instead of evaluating the gradient shader every frame.
///
/// On low-end GPUs (e.g. Android TV sticks) a full-screen live gradient is
/// noticeably more expensive to raster than a cached texture, so this keeps the
/// background as cheap as a static image wallpaper.
class _CachedGradientBackground extends StatefulWidget {
  final Gradient gradient;

  const _CachedGradientBackground({super.key, required this.gradient});

  @override
  State<_CachedGradientBackground> createState() => _CachedGradientBackgroundState();
}

class _CachedGradientBackgroundState extends State<_CachedGradientBackground> {
  ui.Image? _image;
  Size _renderedSize = Size.zero;
  Gradient? _renderedGradient;
  bool _rendering = false;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _render(Size size) async {
    if (_rendering) {
      return;
    }
    _rendering = true;
    final recorder = ui.PictureRecorder();
    final rect = Offset.zero & size;
    Canvas(recorder).drawRect(rect, Paint()..shader = widget.gradient.createShader(rect));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.round(), size.height.round());
    picture.dispose();
    _rendering = false;
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = image;
      _renderedSize = size;
      _renderedGradient = widget.gradient;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final needsRender = size != _renderedSize || widget.gradient != _renderedGradient;
        if (needsRender && size.width > 0 && size.height > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (size != _renderedSize || widget.gradient != _renderedGradient)) {
              _render(size);
            }
          });
        }
        final image = _image;
        if (image != null && !needsRender) {
          return RawImage(image: image, width: size.width, height: size.height, fit: BoxFit.fill);
        }
        // First frame (and while re-rendering): paint the gradient live once to avoid a flash.
        return DecoratedBox(decoration: BoxDecoration(gradient: widget.gradient));
      },
    );
  }
}
