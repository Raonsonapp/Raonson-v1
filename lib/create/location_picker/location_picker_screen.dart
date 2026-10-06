import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/i18n/strings.dart';
import '../../core/places/device_location.dart';
import '../../core/places/place.dart';
import '../../core/places/places_repository.dart';
import '../../core/ui/app_icons.dart';

/// Интихоби корбар. [place] == null — «Бе ҷой» (ҷой тоза шуд).
/// Агар экран бе интихоб баста шавад, натиҷа худаш null аст.
class LocationPickResult {
  final Place? place;
  const LocationPickResult(this.place);
}

/// «Ҷой» — мисли Instagram: ҷустуҷӯ, «Ҷойи ҳозираи ман», охиринҳо,
/// «Бе ҷой» ва ҷойи дастӣ.
Future<LocationPickResult?> showLocationPicker(BuildContext context,
    {Place? current}) {
  return Navigator.of(context).push<LocationPickResult>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => LocationPickerScreen(current: current),
  ));
}

class LocationPickerScreen extends StatefulWidget {
  final Place? current;
  final PlacesSource? source;
  final DeviceLocation? device;
  final PlaceRecents? recents;

  const LocationPickerScreen({
    super.key,
    this.current,
    this.source,
    this.device,
    this.recents,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final PlacesSource _source = widget.source ?? PlacesRepository.instance;
  late final DeviceLocation _device =
      widget.device ?? const GeolocatorDeviceLocation();
  late final PlaceRecents _recentsStore = widget.recents ?? PlaceRecents.instance;

  final _ctrl = TextEditingController();
  Timer? _debounce;
  int _req = 0;

  String _query = '';
  List<Place> _results = [];
  List<Place> _popular = [];
  List<Place> _recents = [];
  bool _loading = false;
  bool _offline = false;

  // «Ҷойи ҳозираи ман»
  bool _gpsBusy = false;
  LocationFailure? _gpsFailure;
  bool _gpsNoNearby = false;
  Place? _here;
  List<Place> _nearby = [];
  double? _lat, _lon;

  @override
  void initState() {
    super.initState();
    _recentsStore.load().then((r) {
      if (mounted) setState(() => _recents = r);
    });
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(v));
    setState(() => _query = v.trim());
  }

  Future<void> _runSearch(String v) async {
    final q = v.trim();
    final id = ++_req;
    setState(() => _loading = true);
    final r = await _source.search(q, lat: _lat, lon: _lon);
    // Ҷавоби дархости кӯҳна натиҷаи навро иваз накунад.
    if (!mounted || id != _req) return;
    setState(() {
      _loading = false;
      _offline = r.offline;
      if (q.isEmpty) {
        _popular = r.places;
        _results = [];
      } else {
        _results = r.places;
      }
    });
  }

  Future<void> _useGps() async {
    if (_gpsBusy) return;
    setState(() {
      _gpsBusy = true;
      _gpsFailure = null;
      _gpsNoNearby = false;
    });
    final out = await _device.current();
    if (!mounted) return;
    if (!out.ok) {
      setState(() {
        _gpsBusy = false;
        _gpsFailure = out.failure;
      });
      return;
    }
    _lat = out.lat;
    _lon = out.lon;
    final near = await _source.nearest(out.lat!, out.lon!);
    if (!mounted) return;
    setState(() {
      _gpsBusy = false;
      _here = near.place;
      _nearby = near.nearby.where((p) => p != near.place).toList();
      _gpsNoNearby = near.place == null;
    });
    // Акнун ҷойҳои наздик дар ҷустуҷӯ боло мебароянд.
    _runSearch(_ctrl.text);
  }

  Future<void> _pick(Place p) async {
    await _recentsStore.add(p);
    if (mounted) Navigator.of(context).pop(LocationPickResult(p));
  }

  void _clear() => Navigator.of(context).pop(const LocationPickResult(null));

  String _gpsMessage(LocationFailure f) {
    switch (f) {
      case LocationFailure.serviceOff:
        return tr('place.gpsServiceOff');
      case LocationFailure.denied:
        return tr('place.gpsDenied');
      case LocationFailure.deniedForever:
        return tr('place.gpsDeniedForever');
      case LocationFailure.timeout:
        return tr('place.gpsTimeout');
      case LocationFailure.error:
        return tr('place.gpsError');
    }
  }

  Widget? _gpsAction() {
    final f = _gpsFailure;
    if (f == null) return null;
    final String label;
    final VoidCallback onTap;
    switch (f) {
      case LocationFailure.serviceOff:
        label = tr('place.enableGps');
        onTap = _device.openLocationSettings;
      case LocationFailure.deniedForever:
        label = tr('place.openSettings');
        onTap = _device.openAppSettings;
      case LocationFailure.denied:
      case LocationFailure.timeout:
      case LocationFailure.error:
        label = tr('place.retry');
        onTap = _useGps;
    }
    return TextButton(
      key: const ValueKey('place-gps-action'),
      onPressed: onTap,
      child: Text(label,
          style: const TextStyle(
              color: AppColors.neonBlue, fontWeight: FontWeight.w600)),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(text,
            style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  Widget _tile(Place p, {IconData? icon, Key? key, String? title}) {
    final sub = <String>[
      if (p.region.isNotEmpty) p.region,
      if (p.distanceKm != null)
        tr('place.km', {'n': p.distanceKm! < 10
            ? p.distanceKm!.toStringAsFixed(1)
            : p.distanceKm!.round()}),
    ].join(' · ');
    return ListTile(
      key: key ?? ValueKey('place-${p.id.isEmpty ? p.name : p.id}'),
      leading: Icon(icon ?? AppIcons.location_on_outlined,
          color: AppColors.textSecondary, size: 22),
      title: Text(title ?? p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      subtitle: sub.isEmpty
          ? null
          : Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
      onTap: () => _pick(p),
    );
  }

  List<Widget> _gpsSection() {
    final f = _gpsFailure;
    final String sub;
    if (_gpsBusy) {
      sub = tr('place.locating');
    } else if (f != null) {
      sub = _gpsMessage(f);
    } else if (_gpsNoNearby) {
      sub = tr('place.gpsNoNearby');
    } else {
      sub = tr('place.currentHint');
    }
    return [
      ListTile(
        key: const ValueKey('place-gps'),
        leading: const Icon(AppIcons.my_location,
            color: AppColors.neonBlue, size: 22),
        title: Text(tr('place.current'),
            style: const TextStyle(
                color: AppColors.neonBlue, fontWeight: FontWeight.w600)),
        subtitle: Text(sub,
            key: const ValueKey('place-gps-status'),
            style: TextStyle(
                color: f != null ? AppColors.red : AppColors.textTertiary,
                fontSize: 12.5)),
        trailing: _gpsBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : _gpsAction(),
        onTap: _gpsBusy ? null : _useGps,
      ),
      if (_here != null)
        _tile(_here!,
            title: tr('place.youAreIn', {'name': _here!.name}),
            icon: AppIcons.location_on,
            key: const ValueKey('place-here')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    final q = _query;
    final children = <Widget>[
      if (current != null && current.name.isNotEmpty)
        ListTile(
          key: const ValueKey('place-none'),
          leading: Icon(AppIcons.block_rounded,
              color: AppColors.textSecondary, size: 22),
          title: Text(tr('place.none'),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          subtitle: Text(tr('place.noneHint'),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
          onTap: _clear,
        ),
      ..._gpsSection(),
      if (_offline)
        Padding(
          key: const ValueKey('place-offline'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(tr('place.offline'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
        ),
    ];
    if (q.isEmpty) {
      if (_nearby.isNotEmpty) {
        children.add(_header(tr('place.nearby')));
        children.addAll(_nearby.take(8).map((p) => _tile(p)));
      }
      if (_recents.isNotEmpty) {
        children.add(_header(tr('place.recent')));
        children.addAll(
            _recents.map((p) => _tile(p, icon: AppIcons.history_rounded)));
      }
      if (_popular.isNotEmpty) {
        children.add(_header(tr('place.popular')));
        children.addAll(_popular.map((p) => _tile(p)));
      }
    } else {
      children.add(_header(tr('place.results')));
      if (_results.isEmpty && !_loading) {
        children.add(Padding(
          key: const ValueKey('place-empty'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(tr('place.noResults'),
              style: TextStyle(color: AppColors.textFaint)),
        ));
      }
      children.addAll(_results.map((p) => _tile(p)));
      // Ҷойи дастӣ — охирин имкон, агар ҷой дар рӯйхат набошад.
      children.add(ListTile(
        key: const ValueKey('place-custom'),
        leading: Icon(AppIcons.add_circle_outline,
            color: AppColors.textSecondary, size: 22),
        title: Text(tr('place.addCustom', {'name': q}),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        subtitle: Text(tr('place.addCustomHint'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
        onTap: () => _pick(Place.custom(q.length > 120 ? q.substring(0, 120) : q)),
      ));
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(tr('place.title'),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            key: const ValueKey('place-search'),
            controller: _ctrl,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: tr('place.search'),
              hintStyle: TextStyle(color: AppColors.textFaint),
              prefixIcon:
                  Icon(AppIcons.search, color: AppColors.textTertiary, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(AppIcons.close,
                          color: AppColors.textTertiary, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        _onChanged('');
                      },
                    ),
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        if (_loading)
          const LinearProgressIndicator(minHeight: 1.5)
        else
          const SizedBox(height: 1.5),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: children,
          ),
        ),
      ]),
    );
  }
}
