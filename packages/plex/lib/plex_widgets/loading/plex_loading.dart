import 'package:flutter/widgets.dart';
import 'package:plex/plex_widgets/loading/plex_loader_v1.dart';
import 'package:plex/plex_widgets/loading/plex_loader_v2.dart';
import 'package:plex/plex_widgets/loading/plex_loading_enum.dart';

typedef PlexLoadingWidgetBuilder = Widget Function(BuildContext context);

/// When set, [PlexState.showLoading] and [PlexViewState.showLoading] use this
/// widget instead of PlexLoader V1/V2.
PlexLoadingWidgetBuilder? plexLoadingWidgetBuilder;

Widget plexResolveLoadingWidget(BuildContext context, PlexLoadingEnum type) {
  final custom = plexLoadingWidgetBuilder;
  if (custom != null) return custom(context);
  return type == PlexLoadingEnum.version1
      ? const PlexLoaderV1()
      : const PlexLoaderV2();
}
