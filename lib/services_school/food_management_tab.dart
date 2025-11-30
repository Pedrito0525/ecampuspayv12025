import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';

class FoodManagementTab extends StatefulWidget {
  const FoodManagementTab({Key? key}) : super(key: key);

  @override
  State<FoodManagementTab> createState() => _FoodManagementTabState();
}

class _FoodManagementTabState extends State<FoodManagementTab> {
  List<Map<String, dynamic>> foodItems = [];
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> merchandise = [];
  bool _loading = true;
  bool get _isCampusServiceUnits =>
      (SessionService.currentUserData?['service_category']?.toString() ?? '') ==
      'Campus Service Units';
  bool get _isOrganization {
    final cat = SessionService.currentUserData?['service_category']?.toString();
    return (cat ?? '').toLowerCase().contains('org');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;
    final isTablet = screenWidth > 480 && screenWidth <= 1024;

    // Responsive sizing
    final horizontalPadding = isWeb ? 24.0 : (isTablet ? 20.0 : 16.0);
    final verticalPadding = isWeb ? 20.0 : (isTablet ? 16.0 : 12.0);
    final crossAxisCount = isWeb ? 3 : (isTablet ? 2 : 1);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isWeb ? 24 : 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                ),
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Item Manager',
                    style: TextStyle(
                      fontSize: isWeb ? 28 : (isTablet ? 24 : 22),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: isWeb ? 8 : 6),
                  Text(
                    'Manage products, services, and merchandise',
                    style: TextStyle(
                      fontSize: isWeb ? 16 : (isTablet ? 15 : 14),
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Loading items...',
                        style: TextStyle(
                          fontSize: isWeb ? 14 : 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 30 : 20),

            // Food Items Section (hidden for Campus Service Units)
            if (!_isCampusServiceUnits && !_isOrganization)
              _buildManagementSection(
                title: 'Food Items',
                items: foodItems,
                onAdd: () => _openAddModal('food'),
                isWeb: isWeb,
                isTablet: isTablet,
                crossAxisCount: crossAxisCount,
              ),

            SizedBox(height: isWeb ? 24 : 20),

            // Services Section
            _buildManagementSection(
              title: 'Services & Documents',
              items: services,
              onAdd: () => _openAddModal('service'),
              isWeb: isWeb,
              isTablet: isTablet,
              crossAxisCount: crossAxisCount,
            ),

            SizedBox(height: isWeb ? 24 : 20),

            // Merchandise Section
            _buildManagementSection(
              title: 'School Items & Fees',
              items: merchandise,
              onAdd: () => _openAddModal('merchandise'),
              isWeb: isWeb,
              isTablet: isTablet,
              crossAxisCount: crossAxisCount,
            ),

            SizedBox(height: isWeb ? 60 : 100), // Space for bottom navigation
          ],
        ),
      ),
    );
  }

  Widget _buildManagementSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required VoidCallback onAdd,
    required bool isWeb,
    required bool isTablet,
    required int crossAxisCount,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isWeb ? 24 : 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isWeb ? 16 : 12),
                topRight: Radius.circular(isWeb ? 16 : 12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isWeb ? 20 : (isTablet ? 18 : 16),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: Icon(Icons.add, size: isWeb ? 20 : 16),
                  label: Text(
                    'Add Payment',
                    style: TextStyle(
                      fontSize: isWeb ? 14 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28A745),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isWeb ? 20 : 16,
                      vertical: isWeb ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),

          // Items Grid/List
          if (items.isEmpty)
            Container(
              padding: EdgeInsets.all(isWeb ? 40 : 30),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: isWeb ? 64 : 48,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: isWeb ? 16 : 12),
                  Text(
                    'No items yet',
                    style: TextStyle(
                      fontSize: isWeb ? 18 : 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: isWeb ? 8 : 6),
                  Text(
                    'Add your first item to get started',
                    style: TextStyle(
                      fontSize: isWeb ? 14 : 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(isWeb ? 24 : 16),
              child:
                  isWeb
                      ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(
                            items[index],
                            items,
                            isWeb,
                            isTablet,
                          );
                        },
                      )
                      : Column(
                        children:
                            items
                                .map(
                                  (item) => _buildProductItem(
                                    item,
                                    items,
                                    isWeb,
                                    isTablet,
                                  ),
                                )
                                .toList(),
                      ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> itemsList,
    bool isWeb,
    bool isTablet,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9ECEF)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getCategoryColor(item['category']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item['category'],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getCategoryColor(item['category']),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),

            // Product Info
            Flexible(
              child: Tooltip(
                message: item['name'],
                triggerMode: TooltipTriggerMode.tap,
                child: Text(
                  item['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item['hasSizes'] && item['sizes'] != null
                  ? 'From ₱${_computeMinPriceFromSizesString(item['sizes']).toStringAsFixed(0)}'
                  : '₱${item['price'].toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB91C1C),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item['hasSizes'] && item['sizes'] != null) ...[
              const SizedBox(height: 4),
              Text(
                '${item['sizes'].split('\n').length} sizes',
                style: const TextStyle(fontSize: 10, color: Color(0xFF666666)),
              ),
            ],

            const Spacer(),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _editProduct(item, itemsList),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFC107),
                      side: const BorderSide(color: Color(0xFFFFC107)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteProduct(item, itemsList),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC3545),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> itemsList,
    bool isWeb,
    bool isTablet,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isWeb ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9ECEF)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getCategoryColor(item['category']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(item['category']),
              color: _getCategoryColor(item['category']),
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: item['name'],
                  triggerMode: TooltipTriggerMode.tap,
                  child: Text(
                    item['name'],
                    style: TextStyle(
                      fontSize: isWeb ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                    maxLines: isWeb ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(
                        item['category'],
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item['category'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getCategoryColor(item['category']),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['hasSizes'] && item['sizes'] != null
                      ? 'Starting from ₱${_computeMinPriceFromSizesString(item['sizes']).toStringAsFixed(2)}'
                      : '₱${item['price'].toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: isWeb ? 15 : 13,
                    color: const Color(0xFFB91C1C),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item['hasSizes'] && item['sizes'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Sizes: ${item['sizes'].replaceAll('\n', ', ')}',
                    style: TextStyle(
                      fontSize: isWeb ? 12 : 10,
                      color: const Color(0xFF666666),
                    ),
                    maxLines: isWeb ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Action Buttons
          Column(
            children: [
              SizedBox(
                width: isWeb ? 80 : 60,
                child: OutlinedButton(
                  onPressed: () => _editProduct(item, itemsList),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFC107),
                    side: const BorderSide(color: Color(0xFFFFC107)),
                    padding: EdgeInsets.symmetric(vertical: isWeb ? 10 : 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: isWeb ? 12 : 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: isWeb ? 80 : 60,
                child: ElevatedButton(
                  onPressed: () => _deleteProduct(item, itemsList),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC3545),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isWeb ? 10 : 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: isWeb ? 12 : 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFF28A745);
      case 'drinks':
        return const Color(0xFF007BFF);
      case 'desserts':
        return const Color(0xFF6F42C1);
      case 'services':
        return const Color(0xFF17A2B8);
      case 'documents':
        return const Color(0xFF6C757D);
      case 't-shirt':
        return const Color(0xFFE83E8C);
      case 'merchandise':
        return const Color(0xFFFF6347);
      case 'school items':
        return const Color(0xFF20C997);
      case 'fees':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFF6C757D);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'drinks':
        return Icons.local_drink;
      case 'desserts':
        return Icons.cake;
      case 'services':
        return Icons.room_service;
      case 'documents':
        return Icons.description;
      case 't-shirt':
        return Icons.checkroom;
      case 'merchandise':
        return Icons.shopping_bag;
      case 'school items':
        return Icons.school;
      case 'fees':
        return Icons.attach_money;
      default:
        return Icons.inventory;
    }
  }

  void _openAddModal(String type) {
    _showProductModal(
      title: _getModalTitle(type),
      isEdit: false,
      itemType: type,
    );
  }

  String _getModalTitle(String type) {
    switch (type) {
      case 'food':
        return 'Add Payment Item';
      case 'service':
        return 'Add Payment Item';
      case 'merchandise':
        return 'Add Payment Item';
      default:
        return 'Add Payment Item';
    }
  }

  void _editProduct(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> itemsList,
  ) {
    String itemType = 'food';
    if (itemsList == services) {
      itemType = 'service';
    } else if (itemsList == merchandise) {
      itemType = 'merchandise';
    }

    _showProductModal(
      title: 'Edit ${item['name']}',
      isEdit: true,
      item: item,
      itemType: itemType,
    );
  }

  void _deleteProduct(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> itemsList,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Are you sure you want to delete "${item['name']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  // Get current service name and operational type for validation
                  final operationalType =
                      SessionService.currentUserData?['operational_type']
                          ?.toString() ??
                      'Main';
                  final currentServiceName =
                      SessionService.currentUserData?['service_name']
                          ?.toString();

                  final deleteResult = await SupabaseService.deletePaymentItem(
                    itemId: item['id'],
                    currentServiceName: currentServiceName,
                    operationalType: operationalType,
                  );

                  if (deleteResult['success'] == true) {
                    setState(() {
                      itemsList.removeWhere((i) => i['id'] == item['id']);
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item['name']} deleted successfully'),
                        backgroundColor: const Color(0xFF28A745),
                      ),
                    );
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          deleteResult['message'] ?? 'Failed to delete item',
                        ),
                        backgroundColor: const Color(0xFFDC3545),
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete item: ${e.toString()}'),
                      backgroundColor: const Color(0xFFDC3545),
                    ),
                  );
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFDC3545)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showProductModal({
    required String title,
    required bool isEdit,
    required String itemType,
    Map<String, dynamic>? item,
  }) {
    final nameController = TextEditingController(text: item?['name'] ?? '');
    final priceController = TextEditingController(
      text: item?['price']?.toString() ?? '',
    );
    // Dynamic size/price rows state
    final List<String> sizeOrder = ['S', 'M', 'L', 'XL', 'XXL'];
    List<Map<String, dynamic>> sizeRows = [];

    Map<String, double> _parseSizesString(String? sizesStr) {
      final Map<String, double> result = {};
      if (sizesStr == null || sizesStr.trim().isEmpty) return result;
      for (final line in sizesStr.split('\n')) {
        final parts = line.split(',');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final val = double.tryParse(parts[1].trim());
          if (key.isNotEmpty && val != null) {
            result[key] = val;
          }
        }
      }
      return result;
    }

    String selectedCategory =
        item?['category'] ?? _getDefaultCategory(itemType);
    bool hasSizes = item?['hasSizes'] ?? false;

    // Prefill size rows when editing or when item has sizes
    if (hasSizes) {
      final existing = _parseSizesString(item?['sizes']);
      // Add in defined order first
      for (final label in sizeOrder) {
        if (existing.containsKey(label)) {
          sizeRows.add({
            'label': label,
            'controller': TextEditingController(
              text: existing[label]?.toString() ?? '',
            ),
          });
        }
      }
      // Add any other custom sizes
      for (final entry in existing.entries) {
        if (!sizeOrder.contains(entry.key)) {
          sizeRows.add({
            'label': entry.key,
            'controller': TextEditingController(text: entry.value.toString()),
          });
        }
      }
      // If none, start with S
      if (sizeRows.isEmpty) {
        sizeRows.add({'label': 'S', 'controller': TextEditingController()});
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final isWeb = screenWidth > 600;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: isWeb ? 500 : screenWidth * 0.9,
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.8,
                  maxWidth: isWeb ? 500 : screenWidth * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Product Name
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Product Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Category with scrollable dropdown
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              menuMaxHeight: 300, // Make dropdown scrollable
                              items:
                                  _getCategoriesByType(itemType)
                                      .map(
                                        (category) => DropdownMenuItem(
                                          value: category,
                                          child: Text(
                                            category,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setModalState(() {
                                  selectedCategory = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Price (disabled when sizes are used)
                            TextField(
                              controller: priceController,
                              decoration: InputDecoration(
                                labelText: 'Price',
                                border: const OutlineInputBorder(),
                                prefixText: '₱',
                                helperText:
                                    hasSizes
                                        ? 'Disabled when size options are enabled'
                                        : null,
                              ),
                              keyboardType: TextInputType.number,
                              enabled: !hasSizes,
                              onChanged: (_) {
                                // no-op; price is ignored when hasSizes = true
                              },
                            ),
                            const SizedBox(height: 16),

                            // Has Size Options
                            DropdownButtonFormField<bool>(
                              value: hasSizes,
                              decoration: const InputDecoration(
                                labelText: 'Has Size Options?',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('No'),
                                ),
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('Yes'),
                                ),
                              ],
                              onChanged: (value) {
                                setModalState(() {
                                  hasSizes = value!;
                                  if (hasSizes) {
                                    priceController.text = '0';
                                    // Initialize with S if empty
                                    if (sizeRows.isEmpty) {
                                      sizeRows.add({
                                        'label': 'S',
                                        'controller': TextEditingController(),
                                      });
                                    }
                                  } else {
                                    sizeRows.clear();
                                  }
                                });
                              },
                            ),

                            // Size Options (conditional)
                            if (hasSizes) ...[
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Sizes and Prices',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: [
                                  ...sizeRows.map((row) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F3F5),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              row['label'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller:
                                                  row['controller']
                                                      as TextEditingController,
                                              decoration: const InputDecoration(
                                                labelText: 'Price',
                                                border: OutlineInputBorder(),
                                                prefixText: '₱',
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        // Add next size in order
                                        final existingLabels =
                                            sizeRows
                                                .map(
                                                  (r) => r['label'] as String,
                                                )
                                                .toSet();
                                        String? next;
                                        for (final s in sizeOrder) {
                                          if (!existingLabels.contains(s)) {
                                            next = s;
                                            break;
                                          }
                                        }
                                        if (next != null) {
                                          setModalState(() {
                                            sizeRows.add({
                                              'label': next,
                                              'controller':
                                                  TextEditingController(),
                                            });
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add next size'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF28A745,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              // Build sizes string from dynamic rows
                              String sizesString = '';
                              if (hasSizes) {
                                final lines = <String>[];
                                for (final row in sizeRows) {
                                  final label = (row['label'] as String).trim();
                                  final text =
                                      (row['controller']
                                              as TextEditingController)
                                          .text
                                          .trim();
                                  final price = double.tryParse(text);
                                  if (label.isNotEmpty && price != null) {
                                    lines.add('$label,$price');
                                  }
                                }
                                sizesString = lines.join('\n');
                              }

                              await _saveProduct(
                                isEdit: isEdit,
                                item: item,
                                itemType: itemType,
                                name: nameController.text,
                                category: selectedCategory,
                                price:
                                    hasSizes
                                        ? 0.0
                                        : (double.tryParse(
                                              priceController.text,
                                            ) ??
                                            0.0),
                                hasSizes: hasSizes,
                                sizes: sizesString,
                              );
                              if (mounted) Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB91C1C),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getDefaultCategory(String itemType) {
    switch (itemType) {
      case 'food':
        return 'Food';
      case 'service':
        return 'Services';
      case 'merchandise':
        return 'Merchandise';
      default:
        return 'Food';
    }
  }

  List<String> _getCategoriesByType(String itemType) {
    switch (itemType) {
      case 'food':
        return ['Food', 'Drinks', 'Desserts'];
      case 'service':
        return ['Services', 'Documents', 'Fees'];
      case 'merchandise':
        return ['School Items', 'Merchandise', 'Fees'];
      default:
        return [
          'Food',
          'Drinks',
          'Desserts',
          'Services',
          'Documents',
          'School Items',
          'Merchandise',
          'Fees',
        ];
    }
  }

  Future<void> _saveProduct({
    required bool isEdit,
    Map<String, dynamic>? item,
    required String itemType,
    required String name,
    required String category,
    required double price,
    required bool hasSizes,
    required String sizes,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      return;
    }

    if (!hasSizes && price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a valid base price'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      return;
    }

    if (hasSizes && sizes.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide size options when sizes are enabled'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      return;
    }

    List<Map<String, dynamic>> targetList;
    switch (itemType) {
      case 'food':
        targetList = foodItems;
        break;
      case 'service':
        targetList = services;
        break;
      case 'merchandise':
        targetList = merchandise;
        break;
      default:
        targetList = foodItems;
    }

    // Persist to Supabase payment_items
    final serviceIdStr =
        SessionService.currentUserData?['service_id']?.toString() ?? '0';
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';
    final mainServiceIdStr =
        SessionService.currentUserData?['main_service_id']?.toString();
    final serviceCategory =
        SessionService.currentUserData?['service_category']?.toString() ?? '';
    final serviceId = int.tryParse(serviceIdStr) ?? 0;
    final mainServiceId =
        int.tryParse(mainServiceIdStr ?? '') ??
        (operationalType == 'Sub' ? serviceId : null);

    // Determine owner service ID and service name for Campus Service Units
    final ownerServiceId =
        operationalType == 'Sub' && mainServiceId != null
            ? mainServiceId
            : serviceId;

    // Get service_name for tracking creator (Campus Service Units only)
    String? serviceName;
    if (serviceCategory == 'Campus Service Units') {
      final currentServiceName =
          SessionService.currentUserData?['service_name']?.toString();
      // For main accounts, use "Cashier" or service name
      // For sub accounts, use their service name (e.g., "IGP", "Registrar")
      if (operationalType == 'Main') {
        serviceName = currentServiceName ?? 'Cashier';
      } else {
        // Sub account: use their own service name
        serviceName = currentServiceName;
      }
    }
    // For Vendor/Organization, serviceName remains null

    Map<String, double>? sizeOptions;
    if (hasSizes && sizes.isNotEmpty) {
      sizeOptions = {};
      for (final line in sizes.split('\n')) {
        final parts = line.split(',');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = double.tryParse(parts[1].trim());
          if (key.isNotEmpty && value != null) {
            sizeOptions[key] = value;
          }
        }
      }
    }

    if (hasSizes && (sizeOptions == null || sizeOptions.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one valid size and price'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      return;
    }

    try {
      Map<String, dynamic> saved;
      if (isEdit) {
        // Get current service name for validation (sub-accounts only)
        final currentServiceName =
            SessionService.currentUserData?['service_name']?.toString();

        final resp = await SupabaseService.updatePaymentItem(
          itemId: item!['id'] as int,
          name: name,
          category: category,
          basePrice: price,
          hasSizes: hasSizes,
          sizeOptions: sizeOptions,
          currentServiceName: currentServiceName, // For sub-account validation
          operationalType: operationalType, // For sub-account validation
        );
        if (!(resp['success'] == true)) {
          throw Exception(resp['message'] ?? 'Update failed');
        }
        saved = resp['data'];
      } else {
        final resp = await SupabaseService.createPaymentItem(
          serviceAccountId: ownerServiceId,
          name: name,
          category: category,
          basePrice: price,
          hasSizes: hasSizes,
          sizeOptions: sizeOptions,
          serviceName:
              serviceName, // Pass service_name for Campus Service Units
        );
        if (!(resp['success'] == true)) {
          throw Exception(resp['message'] ?? 'Create failed');
        }
        saved = resp['data'];
      }

      final productData = {
        'id': saved['id'],
        'name': saved['name'],
        'price': (saved['base_price'] as num).toDouble(),
        'category': saved['category'],
        'hasSizes': saved['has_sizes'] == true,
        if (saved['size_options'] != null)
          'sizes': (saved['size_options'] as Map).entries
              .map((e) => '${e.key},${e.value}')
              .join('\n'),
      };

      setState(() {
        if (isEdit) {
          final index = targetList.indexWhere(
            (i) => i['id'] == productData['id'],
          );
          if (index != -1) {
            targetList[index] = productData;
          }
        } else {
          targetList.add(productData);
        }
      });

      if (isEdit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated $name successfully'),
            backgroundColor: const Color(0xFF28A745),
          ),
        );
      } else {
        await _showAddResultDialog(success: true, name: name);
      }
    } catch (e) {
      if (isEdit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      } else {
        await _showAddResultDialog(
          success: false,
          name: name,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> _showAddResultDialog({
    required bool success,
    required String name,
    String? errorMessage,
  }) async {
    if (!mounted) return;
    final Color statusColor =
        success ? const Color(0xFF28A745) : const Color(0xFFDC3545);
    final IconData statusIcon = success ? Icons.check_circle : Icons.error;
    final String dialogMessage =
        success
            ? '"$name" has been added successfully.'
            : 'Unable to add "$name"${errorMessage != null && errorMessage.trim().isNotEmpty ? ': ${errorMessage.trim()}' : '.'}';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Text(success ? 'Success' : 'Add Failed'),
            ],
          ),
          content: Text(dialogMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  double _computeMinPriceFromSizesString(String sizes) {
    double? minPrice;
    for (final line in sizes.split('\n')) {
      final parts = line.split(',');
      if (parts.length == 2) {
        final price = double.tryParse(parts[1].trim());
        if (price != null) {
          if (minPrice == null || price < minPrice) minPrice = price;
        }
      }
    }
    return (minPrice ?? 0).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
    });

    final serviceIdStr =
        SessionService.currentUserData?['service_id']?.toString() ?? '0';
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';
    final mainServiceIdStr =
        SessionService.currentUserData?['main_service_id']?.toString();
    final serviceId = int.tryParse(serviceIdStr) ?? 0;
    final mainServiceId = int.tryParse(mainServiceIdStr ?? '');

    final resp = await SupabaseService.getEffectivePaymentItems(
      serviceAccountId: serviceId,
      operationalType: operationalType,
      mainServiceId: mainServiceId,
    );

    if (resp['success'] == true) {
      final List data = resp['data'] as List;
      final parsed =
          data.map<Map<String, dynamic>>((raw) {
            return {
              'id': raw['id'],
              'name': raw['name'],
              'price': (raw['base_price'] as num).toDouble(),
              'category': raw['category'],
              'hasSizes': raw['has_sizes'] == true,
              if (raw['size_options'] != null)
                'sizes': (raw['size_options'] as Map).entries
                    .map((e) => '${e.key},${e.value}')
                    .join('\n'),
            };
          }).toList();

      setState(() {
        // Split into lists by category group
        foodItems =
            parsed
                .where(
                  (p) => ['Food', 'Drinks', 'Desserts'].contains(p['category']),
                )
                .toList();
        services =
            parsed
                .where(
                  (p) =>
                      ['Services', 'Documents', 'Fees'].contains(p['category']),
                )
                .toList();
        merchandise =
            parsed
                .where(
                  (p) =>
                      ['School Items', 'Merchandise'].contains(p['category']),
                )
                .toList();
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load items: ${resp['message'] ?? ''}'),
          backgroundColor: const Color(0xFFDC3545),
        ),
      );
    }
  }
}
