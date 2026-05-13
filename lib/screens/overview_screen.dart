import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/tasbih_item.dart';
import '../services/storage_service.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  List<TasbihItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await StorageService.loadItems();
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Map<String, int> _calculateStats(TasbihItem item) {
    int weekly = 0;
    int monthly = 0;
    int yearly = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    item.history.forEach((dateString, count) {
      try {
        final dateParts = dateString.split('-');
        if (dateParts.length == 3) {
          final date = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );
          
          final difference = today.difference(date).inDays;
          
          if (difference >= 0) {
            if (difference < 7) weekly += count;
            if (difference < 30) monthly += count;
            if (difference < 365) yearly += count;
          }
        }
      } catch (e) {
        // Ignore parsing errors for individual dates
      }
    });

    // For lifetime, we can either sum up history or just use item.count
    // since item.count is the true lifetime count.
    return {
      'Weekly': weekly,
      'Monthly': monthly,
      'Yearly': yearly,
      'Lifetime': item.count,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Progress Overview',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: _items.isEmpty
          ? Center(
              child: Text(
                'No data available.',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final stats = _calculateStats(item);
                
                // Only show practices that have been started
                if (stats['Lifetime'] == 0) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildStatBlock('This Week', stats['Weekly']!)),
                            Expanded(child: _buildStatBlock('This Month', stats['Monthly']!)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildStatBlock('This Year', stats['Yearly']!)),
                            Expanded(child: _buildStatBlock('Lifetime', stats['Lifetime']!)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatBlock(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
