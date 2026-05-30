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
  static const List<String> _householdItemSuggestions = [
    'Toilet paper',
    'Soap',
    'Dish soap',
    'Laundry detergent',
    'Rice',
    'Milk',
    'Eggs',
    'Bread',
    'Trash bags',
    'Cleaning spray',
    'Sponge',
    'Toothpaste',
  ];
  final InventoryService _inventoryService = InventoryService();
  String _selectedView = 'stock';

  List<String> _filteredSuggestions(
    List<String> suggestions,
    TextEditingController controller,
  ) {
    final query = controller.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? suggestions
        : suggestions
              .where((item) => item.toLowerCase().contains(query))
              .toList();

    return matches.take(12).toList();
  }

  Widget _suggestionChips({
    required List<String> suggestions,
    required TextEditingController controller,
    required StateSetter setDialogState,
    bool enabled = true,
  }) {
    if (!enabled) return const SizedBox.shrink();

    final visibleSuggestions = _filteredSuggestions(suggestions, controller);

    if (visibleSuggestions.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: visibleSuggestions.map((suggestion) {
          return ActionChip(
            label: Text(suggestion),
            onPressed: () {
              setDialogState(() {
                controller.text = suggestion;
                controller.selection = TextSelection.collapsed(
                  offset: suggestion.length,
                );
              });
            },
          );
        }).toList(),
      ),
    );
  }

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
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: "Item name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _suggestionChips(
                    suggestions: _householdItemSuggestions,
                    controller: nameController,
                    setDialogState: setDialogState,
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

  Future<void> _showPurchaseDialog({
    String? itemId,
    Map<String, dynamic>? item,
  }) async {
    final itemsSnapshot = await _inventoryService.getItemsSnapshot(
      widget.houseId,
    );
    final items = itemsSnapshot.docs;
    final nameController = TextEditingController(
      text: item?['name']?.toString() ?? '',
    );
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final storeController = TextEditingController();
    String selectedUnit = item?['unit']?.toString() ?? _units.first;
    String? selectedItemId = itemId;
    bool isSavingPurchase = false;
    DateTime purchasedAt = DateTime.now();
    final lockedToStockItem = itemId != null;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedItem = selectedItemId == null
                ? null
                : items.where((item) => item.id == selectedItemId).firstOrNull;

            return AlertDialog(
              title: Text(
                lockedToStockItem ? "Add Stock Purchase" : "Add Purchase",
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: selectedItemId,
                      decoration: const InputDecoration(
                        labelText: "Inventory item",
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text("New item"),
                        ),
                        ...items.map((item) {
                          final data = item.data();
                          final name = data['name']?.toString() ?? 'Item';

                          return DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(name),
                          );
                        }),
                      ],
                      onChanged: lockedToStockItem
                          ? null
                          : (value) {
                              final nextItem = value == null
                                  ? null
                                  : items
                                        .where((item) => item.id == value)
                                        .firstOrNull;
                              setDialogState(() {
                                selectedItemId = value;
                                final data = nextItem?.data();
                                if (data != null) {
                                  nameController.text =
                                      data['name']?.toString() ?? '';
                                  selectedUnit =
                                      data['unit']?.toString() ?? _units.first;
                                } else {
                                  nameController.clear();
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      enabled: selectedItemId == null && !lockedToStockItem,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: "What was bought",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _suggestionChips(
                      suggestions: _householdItemSuggestions,
                      controller: nameController,
                      setDialogState: setDialogState,
                      enabled: selectedItemId == null && !lockedToStockItem,
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
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() => selectedUnit = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Price",
                        prefixText: "€ ",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: storeController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: "Store (optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(
                        DateFormat('dd MMM yyyy').format(purchasedAt),
                      ),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: purchasedAt,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate == null) return;

                        setDialogState(() => purchasedAt = pickedDate);
                      },
                    ),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.sync),
                      title: Text("Stock updates automatically"),
                      subtitle: Text(
                        "Existing stock with the same item name is increased; otherwise a new stock item is created.",
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: isSavingPurchase
                      ? null
                      : () async {
                          final selectedData = selectedItem?.data() ?? item;
                          final itemName =
                              selectedData?['name']?.toString() ??
                              nameController.text.trim();
                          final quantity =
                              int.tryParse(quantityController.text.trim()) ?? 0;
                          final price =
                              double.tryParse(
                                priceController.text.trim().replaceAll(
                                  ',',
                                  '.',
                                ),
                              ) ??
                              0;

                          if (itemName.trim().isEmpty || quantity <= 0) return;

                          try {
                            setDialogState(() => isSavingPurchase = true);

                            await _inventoryService.addPurchase(
                              houseId: widget.houseId,
                              itemId: selectedItemId,
                              itemName: itemName,
                              quantity: quantity,
                              unit: selectedUnit,
                              price: price,
                              store: storeController.text,
                              purchasedAt: purchasedAt,
                              addToStock: true,
                            );
                          } catch (e) {
                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Could not save purchase: $e"),
                              ),
                            );

                            setDialogState(() => isSavingPurchase = false);
                            return;
                          }

                          if (!context.mounted) return;

                          Navigator.pop(context);
                          setState(() {
                            _selectedView = lockedToStockItem
                                ? 'stock'
                                : 'purchases';
                          });
                        },
                  child: Text(isSavingPurchase ? "Saving..." : "Save Purchase"),
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

  String _moneyText(num value) {
    return NumberFormat.currency(locale: 'de_DE', symbol: '€').format(value);
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

  Widget _buildPurchaseHistory() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _inventoryService.purchasesStream(widget.houseId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppErrorState(
            title: "Could not load purchases",
            error: snapshot.error,
            onRetry: () => setState(() {}),
          );
        }

        if (!snapshot.hasData) {
          return const AppLoadingState(message: "Loading purchases...");
        }

        final purchases = snapshot.data!.docs;
        final contributions = <String, double>{};

        for (final doc in purchases) {
          final data = doc.data();
          final boughtBy =
              data['purchasedByName']?.toString() ??
              data['purchasedByEmail']?.toString() ??
              data['boughtByName']?.toString() ??
              data['boughtByEmail']?.toString() ??
              'House member';
          final price = (data['price'] as num?)?.toDouble() ?? 0;

          contributions[boughtBy] = (contributions[boughtBy] ?? 0) + price;
        }

        final contributionEntries = contributions.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        if (purchases.isEmpty) {
          return AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: "No purchases yet",
            message: "Add a purchase to track what was bought and by whom.",
            action: FilledButton.icon(
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text("Add Purchase"),
              onPressed: _showPurchaseDialog,
            ),
          );
        }

        return _responsiveInventory(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width >= 900 ? 32 : 16,
                  16,
                  MediaQuery.sizeOf(context).width >= 900 ? 32 : 16,
                  0,
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.payments_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Contribution overview",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text("${purchases.length} purchases logged"),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...contributionEntries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _moneyText(entry.value),
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width >= 900
                        ? 32
                        : 16,
                    vertical: 16,
                  ),
                  itemCount: purchases.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = purchases[index].data();
                    final itemName = data['itemName']?.toString() ?? 'Item';
                    final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
                    final unit = data['unit']?.toString() ?? 'pcs';
                    final price = (data['price'] as num?) ?? 0;
                    final store = data['store']?.toString() ?? '';
                    final boughtBy =
                        data['purchasedByName']?.toString() ??
                        data['purchasedByEmail']?.toString() ??
                        data['boughtByName']?.toString() ??
                        data['boughtByEmail']?.toString() ??
                        'House member';
                    final purchasedAt = _timestampText(
                      data['purchasedAt'] ?? data['createdAt'],
                    );
                    final storeText = store.trim().isEmpty
                        ? ''
                        : '\nStore: $store';

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.shopping_cart_outlined),
                        ),
                        title: Text(itemName),
                        subtitle: Text(
                          '$quantity $unit • ${_moneyText(price)}\nBought by: $boughtBy$storeText\nPurchased: $purchasedAt',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStockList(bool isAdmin) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
          return AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: "No inventory items yet",
            message:
                "Add groceries, cleaning supplies, or shared household items.",
            action: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add Item"),
              onPressed: _showItemDialog,
            ),
          );
        }

        return _responsiveInventory(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width >= 900 ? 32 : 16,
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
                                  tooltip: "Add purchase",
                                  icon: const Icon(Icons.add),
                                  onPressed: () => _showPurchaseDialog(
                                    itemId: doc.id,
                                    item: data,
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
                                    onPressed: () => _inventoryService
                                        .deleteItem(widget.houseId, doc.id),
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
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'stock',
                        label: Text("Stock"),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                      ButtonSegment(
                        value: 'purchases',
                        label: Text("Purchases"),
                        icon: Icon(Icons.receipt_long_outlined),
                      ),
                    ],
                    selected: {_selectedView},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedView = selection.first);
                    },
                  ),
                ),
              ),
              Expanded(
                child: _selectedView == 'stock'
                    ? _buildStockList(isAdmin)
                    : _buildPurchaseHistory(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: Icon(
              _selectedView == 'stock'
                  ? Icons.add
                  : Icons.add_shopping_cart_outlined,
            ),
            label: Text(_selectedView == 'stock' ? "Add Item" : "Add Purchase"),
            onPressed: _selectedView == 'stock'
                ? _showItemDialog
                : _showPurchaseDialog,
          ),
        );
      },
    );
  }
}
