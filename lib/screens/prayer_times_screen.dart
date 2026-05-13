import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import '../services/location_service.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with AutomaticKeepAliveClientMixin {
  PrayerTimes? _prayerTimes;
  String _locationLabel = '';
  String _errorMessage = '';
  bool _isLoading = true;
  Madhab _selectedMadhab = Madhab.hanafi;

  // SharedPreferences keys
  static const _kLat = 'pt_cached_lat';
  static const _kLon = 'pt_cached_lon';
  static const _kLabel = 'pt_cached_label';
  static const _kMadhab = 'pt_cached_madhab';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final madhabStr = prefs.getString(_kMadhab) ?? 'hanafi';
    setState(() {
      _selectedMadhab = madhabStr == 'shafi' ? Madhab.shafi : Madhab.hanafi;
    });
    _fetchPrayerTimes();
  }

  /// Calculate prayer times from lat/lon (fully offline)
  PrayerTimes _buildPrayerTimes(double lat, double lon, Madhab madhab) {
    final coordinates = Coordinates(lat, lon);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = madhab;
    final date = DateComponents.from(DateTime.now());
    return PrayerTimes(coordinates, date, params);
  }

  /// Try to resolve a readable location name
  Future<String> _resolveLocationName(double lat, double lon) async {
    // ── 1) Try native platform geocoder (Android/iOS) ────────────────────────
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon)
          .timeout(const Duration(seconds: 5));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.locality ?? p.subAdministrativeArea ?? p.subLocality ?? '',
          p.administrativeArea ?? '',
          p.country ?? '',
        ].map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // Native geocoder not available (e.g. web) — try Nominatim
    }

    // ── 2) Fallback: Nominatim OpenStreetMap API (works on web) ──────────────
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon',
      );
      final response = await http.get(uri, headers: {
        'Accept-Language': 'en',
        'User-Agent': 'DigitalTasbihApp/1.0',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final city = address['city'] ??
              address['town'] ??
              address['municipality'] ??
              address['city_district'] ??
              address['suburb'] ??
              address['village'] ??
              address['hamlet'] ??
              address['district'] ??
              address['county'] ??
              '';
          final state = address['state'] ??
              address['state_district'] ??
              '';
          final country = address['country'] ?? '';
          final parts = [city, state, country]
              .map((s) => s.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (parts.isNotEmpty) return parts.join(', ');
        }

        final displayName = data['display_name'] as String? ?? '';
        if (displayName.isNotEmpty) {
          return displayName
              .split(',')
              .take(3)
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .join(', ');
        }
      }
    } catch (_) {
      // Both methods failed
    }
    return '';
  }

  Future<void> _fetchPrayerTimes({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final cachedLat = prefs.getDouble(_kLat);
    final cachedLon = prefs.getDouble(_kLon);
    final cachedLabel = prefs.getString(_kLabel) ?? '';

    // If not forcing refresh and we have cache, use it immediately!
    if (!forceRefresh && cachedLat != null && cachedLon != null) {
      final prayerTimes = _buildPrayerTimes(cachedLat, cachedLon, _selectedMadhab);
      if (!mounted) return;
      setState(() {
        _prayerTimes = prayerTimes;
        _locationLabel = cachedLabel.isNotEmpty ? cachedLabel : 'Cached Location';
        _isLoading = false;
      });
      return;
    }

    // ── Need fresh location + geocode ────────────────────────────────────────
    try {
      final position = await LocationService.determinePosition();
      final lat = position.latitude;
      final lon = position.longitude;

      // Coordinate-based fallback label
      final coordLabel = '${lat.toStringAsFixed(2)}°N, ${lon.toStringAsFixed(2)}°E';

      // Try to resolve human-readable name
      String label = await _resolveLocationName(lat, lon);
      if (label.isEmpty) {
        label = cachedLabel.isNotEmpty ? cachedLabel : coordLabel;
      }

      final prayerTimes = _buildPrayerTimes(lat, lon, _selectedMadhab);

      // Save to cache indefinitely
      await prefs.setDouble(_kLat, lat);
      await prefs.setDouble(_kLon, lon);
      await prefs.setString(_kLabel, label);

      if (!mounted) return;
      setState(() {
        _prayerTimes = prayerTimes;
        _locationLabel = label;
        _isLoading = false;
      });
      return;
    } catch (e) {
      // GPS failed or network down during refresh
      if (cachedLat != null && cachedLon != null) {
        // Fallback to cache if we have it
        final prayerTimes = _buildPrayerTimes(cachedLat, cachedLon, _selectedMadhab);
        if (!mounted) return;
        setState(() {
          _prayerTimes = prayerTimes;
          _locationLabel = cachedLabel.isNotEmpty ? cachedLabel : 'Cached Location';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not get location.\nPlease check GPS/Internet to set up for the first time.';
        _isLoading = false;
      });
    }
  }

  Future<void> _changeMadhab(Madhab madhab) async {
    if (madhab == _selectedMadhab) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMadhab, madhab == Madhab.shafi ? 'shafi' : 'hanafi');

    setState(() {
      _selectedMadhab = madhab;
      _isLoading = true; // Briefly show loading state
    });

    final cachedLat = prefs.getDouble(_kLat);
    final cachedLon = prefs.getDouble(_kLon);
    
    if (cachedLat != null && cachedLon != null) {
      final prayerTimes = _buildPrayerTimes(cachedLat, cachedLon, madhab);
      setState(() {
        _prayerTimes = prayerTimes;
        _isLoading = false;
      });
    } else {
      _fetchPrayerTimes();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Prayer Times',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Update Location',
            onPressed: () => _fetchPrayerTimes(forceRefresh: true),
          ),
          PopupMenuButton<Madhab>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Asr Calculation Method',
            onSelected: _changeMadhab,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: Madhab.hanafi,
                child: Row(
                  children: [
                    Icon(
                      _selectedMadhab == Madhab.hanafi ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text('Hanafi ', style: GoogleFonts.inter()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: Madhab.shafi,
                child: Row(
                  children: [
                    Icon(
                      _selectedMadhab == Madhab.shafi ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text('Standard / Sunnah', style: GoogleFonts.inter()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prayerTimes == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load prayer times.',
                          style: GoogleFonts.outfit(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _fetchPrayerTimes(forceRefresh: true),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Location badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _locationLabel,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    _buildPrayerCard(
                        'Fajr', _prayerTimes!.fajr, Icons.wb_twilight_rounded),
                    _buildPrayerCard('Sunrise', _prayerTimes!.sunrise,
                        Icons.wb_sunny_rounded,
                        isHighlight: false),
                    _buildPrayerCard('Dhuhr', _prayerTimes!.dhuhr, Icons.sunny),
                    _buildPrayerCard(
                        'Asr', _prayerTimes!.asr, Icons.wb_cloudy_rounded),
                    _buildPrayerCard('Sunset', _prayerTimes!.maghrib,
                        Icons.wb_sunny_outlined,
                        isHighlight: false),
                    _buildPrayerCard(
                        'Maghrib', _prayerTimes!.maghrib, Icons.nights_stay_rounded),
                    _buildPrayerCard(
                        'Isha', _prayerTimes!.isha, Icons.star_rounded),
                  ],
                ),
    );
  }

  Widget _buildPrayerCard(String name, DateTime time, IconData icon,
      {bool isHighlight = true}) {
    final formattedTime = DateFormat.jm().format(time);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isHighlight
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isHighlight
            ? BorderSide.none
            : BorderSide(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                width: 2),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: isHighlight
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
                  color: isHighlight
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formattedTime,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isHighlight
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
