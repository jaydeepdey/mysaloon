import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({Key? key}) : super(key: key);

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {
  List<ServiceItem> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final services = await SupabaseService.instance.getServices();
    if (!mounted) return;
    setState(() {
      _services = services;
      _isLoading = false;
    });
  }

  void _showAddEditServiceDialog([ServiceItem? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final durationController = TextEditingController(text: existing?.durationMinutes.toString() ?? '45');
    final priceController = TextEditingController(text: existing?.price.toString() ?? '50.00');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add New Service' : 'Edit Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Service Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (Minutes)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (\$)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final newService = ServiceItem(
                id: existing?.id ?? 'srv-${DateTime.now().millisecondsSinceEpoch}',
                name: nameController.text.trim(),
                description: descController.text.trim(),
                durationMinutes: int.tryParse(durationController.text) ?? 45,
                price: double.tryParse(priceController.text) ?? 50.0,
              );
              setState(() {
                if (existing != null) {
                  final idx = _services.indexWhere((s) => s.id == existing.id);
                  if (idx != -1) _services[idx] = newService;
                } else {
                  _services.add(newService);
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Service "${newService.name}" saved.')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Services'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Service', style: TextStyle(color: Colors.white)),
        onPressed: () => _showAddEditServiceDialog(),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LoadingSkeleton(height: 90, borderRadius: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final service = _services[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${service.durationMinutes} mins • \$${service.price.toStringAsFixed(2)}\n${service.description}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                      onPressed: () => _showAddEditServiceDialog(service),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
