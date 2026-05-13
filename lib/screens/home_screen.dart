import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/tasbih_item.dart';
import '../services/storage_service.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;
  const HomeScreen({super.key, this.onMenuTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> _saveItems() async {
    await StorageService.saveItems(_items);
  }

  void _showAddOrEditDialog({TasbihItem? existingItem, int? index}) {
    final nameController = TextEditingController(text: existingItem?.name ?? '');
    final limitController = TextEditingController(text: existingItem?.targetLimit.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            existingItem == null ? 'New Practice' : 'Edit Practice',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name (e.g. Subhanallah)',
                  labelStyle: GoogleFonts.inter(),
                ),
                style: GoogleFonts.inter(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Target Limit (e.g. 33)',
                  labelStyle: GoogleFonts.inter(),
                ),
                style: GoogleFonts.inter(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final limit = int.tryParse(limitController.text.trim()) ?? 0;
                
                if (name.isNotEmpty && limit > 0) {
                  setState(() {
                    if (existingItem != null && index != null) {
                      _items[index].name = name;
                      _items[index].targetLimit = limit;
                    } else {
                      _items.add(
                        TasbihItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          targetLimit: limit,
                        ),
                      );
                    }
                  });
                  _saveItems();
                  Navigator.pop(context);
                }
              },
              child: Text('Save', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _saveItems();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onMenuTap,
        ),
        title: Text(
          'My Practices',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
      ),

      body: _items.isEmpty
          ? Center(
              child: Text(
                'No practices yet.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      // Navigate to player screen and wait for result
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlayerScreen(item: item),
                        ),
                      );
                      // Upon returning, update state and save items
                      setState(() {});
                      _saveItems();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Circular Progress preview
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: (item.count % item.targetLimit) / item.targetLimit,
                                  strokeWidth: 4,
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                Center(
                                  child: Text(
                                    '${item.count % item.targetLimit}',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total: ${item.count} • Target: ${item.targetLimit}',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Edit / Delete Popup Menu
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showAddOrEditDialog(existingItem: item, index: index);
                              } else if (value == 'delete') {
                                _deleteItem(index);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOrEditDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
