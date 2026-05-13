import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'prayer_times_screen.dart';
import 'overview_screen.dart';

class MainScreen extends StatefulWidget {
  final List<String> developers;
  final String university;

  const MainScreen({
    super.key,
    this.developers = const ['Md Jawad Hossain'],
    this.university = 'North Western University',
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // GlobalKey so we can open the drawer programmatically from child screens
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      // IndexedStack keeps all screens alive — no reload when switching tabs
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
          const PrayerTimesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mosque_outlined),
            selectedIcon: Icon(Icons.mosque_rounded),
            label: 'Tasbih',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time_outlined),
            selectedIcon: Icon(Icons.access_time_filled),
            label: 'Prayer Times',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 32,
              bottom: 32,
            ),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.mosque_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Digital Tasbih',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Menu Items
          ListTile(
            leading: Icon(Icons.home_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: Text('Home',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 0);
            },
          ),
          ListTile(
            leading: Icon(Icons.access_time_filled_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: Text('Prayer Times',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 1);
            },
          ),
          ListTile(
            leading: Icon(Icons.bar_chart_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: Text('Overview',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const OverviewScreen()),
              );
            },
          ),

          const Spacer(),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  'Developed By',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Dynamically render developers
                ...widget.developers.map((devName) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Text(
                      devName,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
                
                const SizedBox(height: 4),
                Text(
                  widget.university,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
