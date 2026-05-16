import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/inventory_service.dart';
import '../services/rbac_service.dart';
import '../widgets/app_state.dart';

class InventoryScreen extends StatefulWidget {
  final String houseId;

  const InventoryScreen({super.key, required this.houseId});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final List<String> _units = const ['pcs', 'kg', 'liter'];
  final InventoryService _inventoryService = InventoryService();

  Future<void> _showItemDialog({
    String? itemId,
    Map<String, dynamic>? item,
  }) async {
    final nameController = TextEditingController(
      text: item?['name']?.toString() ?? '',
    );
    final quantityController = TextEditingController(
      text: (item?['quantity'] ?? 1).toString(),
    );
    String selectedUnit = item?['unit']?.toString() ?? _units.first;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(itemId == null ? "Add Item" : "Edit Item"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: "Item name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Quantity",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: "Unit",
                      border: OutlineInputBorder(),
                    ),
                    items: _units
                        .map(
                          (unit) =>
                              DropdownMenuItem(value: unit, child: Text(unit)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() => selectedUnit = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final quantity =
                        int.tryParse(quantityController.text.trim()) ?? 0;

                    if (name.isEmpty) return;

                    if (itemId == null) {
                      await _inventoryService.addItem(
                        houseId: widget.houseId,
                        name: name,
                        quantity: quantity,
                        unit: selectedUnit,
                      );
                    } else {
                      await _inventoryService.updateItem(
                        houseId: widget.houseId,
                        itemId: itemId,
                        name: name,
                        quantity: quantity,
                        unit: selectedUnit,
                      );
                    }

                    if (!context.mounted) return;

                    Navigator.pop(context);
                  },
                  child: Text(itemId == null ? "Add" : "Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _stockColor(int quantity, ColorScheme colors) {
    if (quantity <= 0) return colors.errorContainer;
    if (quantity <= 1) return colors.secondaryContainer;
    return colors.surfaceContainerHighest;
  }

  String _stockText(int quantity, String unit) {
    if (quantity <= 0) return "Out of stock";

    return "$quantity $unit";
  }

  String _timestampText(Object? value) {
    if (value is Timestamp) {
      return DateFormat('dd MMM yyyy, HH:mm').format(value.toDate());
    }

    return 'Not updated yet';
  }

  String _historyMessage(Map<String, dynamic> data) {
    final action = data['action']?.toString() ?? 'updated';
    final itemName = data['itemName']?.toString() ?? 'Item';
    final unit = data['unit']?.toString() ?? '';
    final oldQuantity = data['oldQuantity'];
    final newQuantity = data['newQuantity'];

    if (oldQuantity != null && newQuantity != null) {
      return '$itemName $action from $oldQuantity to $newQuantity $unit';
    }

    if (newQuantity != null) {
      return '$itemName $action with $newQuantity $unit';
    }

    return '$itemName $action';
  }

  Future<void> _showHistoryDialog(String itemId, String itemName) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("$itemName History"),
          content: SizedBox(
            width: 420,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _inventoryService.itemHistoryStream(
                widget.houseId,
                itemId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorState(
                    title: "Could not load history",
                    error: snapshot.error,
                  );
                }

                if (!snapshot.hasData) {
                  return const AppLoadingState(message: "Loading history...");
                }

                final history = snapshot.data!.docs;

                if (history.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.history,
                    title: "No history yet",
                    message: "Quantity and edit changes will appear here.",
                  );
                }

                return SizedBox(
                  height: 340,
                  child: ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = history[index].data();
                      final updatedBy =
                          data['updatedByName']?.toString() ??
                          data['updatedByEmail']?.toString() ??
                          'House member';

                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(_historyMessage(data)),
                        subtitle: Text(
                          '$updatedBy - ${_timestampText(data['createdAt'])}',
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _responsiveInventory({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _inventoryService.currentMemberStream(widget.houseId),
      builder: (context, memberSnapshot) {
        if (memberSnapshot.hasError) {
          return AppErrorState(
            title: "Could not load inventory permissions",
            error: memberSnapshot.error,
            onRetry: () => setState(() {}),
          );
        }

        if (!memberSnapshot.hasData) {
          return const AppLoadingState(message: "Loading inventory...");
        }

        final member = memberSnapshot.data?.data() ?? {};
        final isAdmin = RbacService.isAdmin(member);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _inventoryService.getItems(widget.houseId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppErrorState(
                  title: "Could not load inventory",
                  error: snapshot.error,
                  onRetry: () => setState(() {}),
                );
              }

              if (!snapshot.hasData) {
                return const AppLoadingState(message: "Loading inventory...");
              }

              final items = snapshot.data!.docs;

              if (items.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: "No inventory items yet",
                  message:
                      "Add groceries, cleaning supplies, or shared household items.",
                );
              }

              return _responsiveInventory(
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width >= 900
                        ? 32
                        : 16,
                    vertical: 16,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = items[index];
                    final data = doc.data();
                    final name = data['name']?.toString() ?? "Unnamed item";
                    final unit = data['unit']?.toString() ?? "pcs";
                    final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
                    final addedBy =
                        data['addedByName']?.toString() ??
                        data['addedByEmail']?.toString() ??
                        "House member";
                    final updatedBy =
                        data['updatedByName']?.toString() ??
                        data['updatedByEmail']?.toString() ??
                        addedBy;
                    final updatedAt = _timestampText(data['updatedAt']);
                    final colors = Theme.of(context).colorScheme;

                    return Card(
                      color: _stockColor(quantity, colors),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              child: Icon(
                                quantity <= 0
                                    ? Icons.remove_shopping_cart
                                    : Icons.inventory_2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_stockText(quantity, unit)}\nAdded by: $addedBy\nLast updated: $updatedAt by $updatedBy",
                                  ),
                                  if (quantity <= 1) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      quantity <= 0
                                          ? "Out of stock"
                                          : "Low stock warning",
                                      style: TextStyle(
                                        color: quantity <= 0
                                            ? colors.error
                                            : colors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      IconButton.outlined(
                                        tooltip: "Decrease",
                                        icon: const Icon(Icons.remove),
                                        onPressed: () =>
                                            _inventoryService.updateQuantity(
                                              houseId: widget.houseId,
                                              itemId: doc.id,
                                              quantity: quantity - 1,
                                            ),
                                      ),
                                      IconButton.outlined(
                                        tooltip: "Increase",
                                        icon: const Icon(Icons.add),
                                        onPressed: () =>
                                            _inventoryService.updateQuantity(
                                              houseId: widget.houseId,
                                              itemId: doc.id,
                                              quantity: quantity + 1,
                                            ),
                                      ),
                                      IconButton.outlined(
                                        tooltip: "Edit",
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showItemDialog(
                                          itemId: doc.id,
                                          item: data,
                                        ),
                                      ),
                                      IconButton.outlined(
                                        tooltip: "History",
                                        icon: const Icon(Icons.history),
                                        onPressed: () =>
                                            _showHistoryDialog(doc.id, name),
                                      ),
                                      if (isAdmin)
                                        IconButton.outlined(
                                          tooltip: "Delete",
                                          icon: const Icon(Icons.delete),
                                          onPressed: () =>
                                              _inventoryService.deleteItem(
                                                widget.houseId,
                                                doc.id,
                                              ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text("Add Item"),
            onPressed: _showItemDialog,
          ),
        );
      },
    );
  }
}
