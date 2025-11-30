import 'package:flutter/material.dart';
import 'dart:async';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/esp32_bluetooth_service_account.dart';

class CashierTab extends StatefulWidget {
  final Function(Map<String, dynamic>) onProductSelected;
  final VoidCallback? onPaymentSuccess;
  final bool? isScannerConnected;

  const CashierTab({
    Key? key,
    required this.onProductSelected,
    this.onPaymentSuccess,
    this.isScannerConnected,
  }) : super(key: key);

  @override
  State<CashierTab> createState() => _CashierTabState();
}

class _CashierTabState extends State<CashierTab> {
  double totalAmount = 0.0;
  Map<String, int> selectedProducts = {};
  Map<String, double> productPrices = {};
  Map<String, String> selectedSizeNames = {};
  bool showPaymentSuccess = false;
  final List<Map<String, dynamic>> products = [];
  final Map<String, Map<String, dynamic>> _productById = {};
  bool _isScannerConnected = false;
  Timer? _connectionCheckTimer;

  bool get _isCampusServiceUnits =>
      (SessionService.currentUserData?['service_category']?.toString() ?? '') ==
      'Campus Service Units';
  bool get _isOrganization {
    final cat = SessionService.currentUserData?['service_category']?.toString();
    return (cat ?? '').toLowerCase().contains('org');
  }

  bool get _isSingleItemMode => _isCampusServiceUnits || _isOrganization;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _isScannerConnected =
        widget.isScannerConnected ?? ESP32BluetoothServiceAccount.isConnected;
    _startConnectionCheck();
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  void _startConnectionCheck() {
    // Check connection status periodically
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        final currentStatus = ESP32BluetoothServiceAccount.isConnected;
        if (currentStatus != _isScannerConnected) {
          setState(() {
            _isScannerConnected = currentStatus;
          });
        }
      }
    });
  }

  void _clearCart() {
    setState(() {
      selectedProducts.clear();
      productPrices.clear();
      selectedSizeNames.clear();
      totalAmount = 0.0;
      showPaymentSuccess = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Building CashierTab with ${products.length} products');
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;
    final isTablet = screenWidth > 480 && screenWidth <= 1024;

    // Responsive sizing
    final horizontalPadding = isWeb ? 24.0 : (isTablet ? 20.0 : 16.0);
    final crossAxisCount = isWeb ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = isWeb ? 1.3 : (isTablet ? 1.2 : 1.1);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: isWeb ? 20 : 16,
        ),
        child: Column(
          children: [
            // Payment Success Message
            if (showPaymentSuccess)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isWeb ? 20 : 15),
                margin: EdgeInsets.only(bottom: isWeb ? 24 : 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF28A745), Color(0xFF20A038)],
                  ),
                  borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF28A745).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text('✅', style: TextStyle(fontSize: isWeb ? 32 : 24)),
                    SizedBox(height: isWeb ? 8 : 5),
                    Text(
                      'Payment Successful!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isWeb ? 18 : 16,
                      ),
                    ),
                    Text(
                      'Transaction completed successfully',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isWeb ? 14 : 12,
                      ),
                    ),
                  ],
                ),
              ),

            // Total Display (hidden in single-item mode)
            if (!_isSingleItemMode)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isWeb ? 24 : 20),
                margin: EdgeInsets.only(bottom: isWeb ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFB91C1C), width: 2),
                  borderRadius: BorderRadius.circular(isWeb ? 16 : 15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB91C1C).withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: isWeb ? 16 : 14,
                        color: const Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isWeb ? 8 : 5),
                    Text(
                      '₱${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isWeb ? 36 : (isTablet ? 32 : 28),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),

            // Product Categories
            if (isWeb) ...[
              if (!_isCampusServiceUnits)
                _buildCategorySection(
                  'Food & Drinks',
                  products
                      .where((p) => ['Food', 'Drinks'].contains(p['category']))
                      .toList(),
                  crossAxisCount,
                  childAspectRatio,
                  isWeb,
                  isTablet,
                ),
              SizedBox(height: isWeb ? 32 : 24),
              _buildCategorySection(
                'Documents & Services',
                products
                    .where(
                      (p) => ['Documents', 'Services'].contains(p['category']),
                    )
                    .toList(),
                crossAxisCount,
                childAspectRatio,
                isWeb,
                isTablet,
              ),
              SizedBox(height: isWeb ? 32 : 24),
              _buildCategorySection(
                'School Items & Fees',
                products
                    .where(
                      (p) => [
                        'School Items',
                        'Merchandise',
                        'Fees',
                      ].contains(p['category']),
                    )
                    .toList(),
                crossAxisCount,
                childAspectRatio,
                isWeb,
                isTablet,
              ),
              SizedBox(height: isWeb ? 32 : 24),
              _buildCustomPaymentSection(
                crossAxisCount,
                childAspectRatio,
                isWeb,
                isTablet,
              ),
            ] else ...[
              // Mobile/tablet grid: filter out Food/Drinks for Campus Service Units
              Builder(
                builder: (context) {
                  final displayedProducts =
                      _isCampusServiceUnits
                          ? products
                              .where(
                                (p) =>
                                    !['Food', 'Drinks'].contains(p['category']),
                              )
                              .toList()
                          : products;
                  // Product Grid for mobile/tablet
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: isWeb ? 16 : 12,
                      mainAxisSpacing: isWeb ? 16 : 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount:
                        displayedProducts.length + 1, // +1 for the plus button
                    itemBuilder: (context, index) {
                      if (index == displayedProducts.length) {
                        // Plus button as the last item
                        return _buildAddPaymentCard(isWeb, isTablet);
                      }
                      final product = displayedProducts[index];
                      return _buildProductCard(product, isWeb, isTablet);
                    },
                  );
                },
              ),
            ],

            SizedBox(height: isWeb ? 32 : 20),

            // Action Buttons (hidden in single-item mode)
            if (!_isSingleItemMode)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _clearOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C757D),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isWeb ? 16 : 12,
                          horizontal: isWeb ? 24 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Clear Order',
                        style: TextStyle(
                          fontSize: isWeb ? 16 : (isTablet ? 14 : 12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isWeb ? 16 : 10),
                  if (selectedProducts.isNotEmpty)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showCartModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF17A2B8),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isWeb ? 16 : 12,
                            horizontal: isWeb ? 24 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              isWeb ? 12 : 10,
                            ),
                          ),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart, size: isWeb ? 18 : 16),
                            SizedBox(width: isWeb ? 8 : 6),
                            Flexible(
                              child: Text(
                                isWeb
                                    ? 'View Cart (${selectedProducts.length})'
                                    : 'Cart (${selectedProducts.length})',
                                style: TextStyle(
                                  fontSize: isWeb ? 16 : (isTablet ? 14 : 12),
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (selectedProducts.isNotEmpty)
                    SizedBox(width: isWeb ? 16 : 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          (totalAmount > 0 && _isScannerConnected)
                              ? _processPayment
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (totalAmount > 0 && _isScannerConnected)
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFFCCCCCC),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isWeb ? 16 : 12,
                          horizontal: isWeb ? 24 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                        ),
                        elevation:
                            (totalAmount > 0 && _isScannerConnected) ? 3 : 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Process Payment',
                            style: TextStyle(
                              fontSize: isWeb ? 16 : (isTablet ? 14 : 12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!_isScannerConnected)
                            Text(
                              'Scanner not connected',
                              style: TextStyle(
                                fontSize: isWeb ? 11 : 9,
                                fontWeight: FontWeight.normal,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            SizedBox(height: isWeb ? 40 : 100), // Space for bottom navigation
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    String title,
    List<Map<String, dynamic>> categoryProducts,
    int crossAxisCount,
    double childAspectRatio,
    bool isWeb,
    bool isTablet,
  ) {
    if (categoryProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isWeb ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: categoryProducts.length,
          itemBuilder: (context, index) {
            final product = categoryProducts[index];
            return _buildProductCard(product, isWeb, isTablet);
          },
        ),
      ],
    );
  }

  Widget _buildCustomPaymentSection(
    int crossAxisCount,
    double childAspectRatio,
    bool isWeb,
    bool isTablet,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Payment',
          style: TextStyle(
            fontSize: isWeb ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: 1, // Only one custom payment card
          itemBuilder: (context, index) {
            return _buildAddPaymentCard(isWeb, isTablet);
          },
        ),
      ],
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product,
    bool isWeb,
    bool isTablet,
  ) {
    final isSelected = selectedProducts.containsKey(product['id']);
    final count = selectedProducts[product['id']] ?? 0;
    final categoryColor = _getCategoryColor(product['category']);

    return GestureDetector(
      onTap: () => _selectProduct(product),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? categoryColor.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? categoryColor : const Color(0xFFE9ECEF),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: categoryColor.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 16 : (isTablet ? 14 : 12)),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product['category'],
                      style: TextStyle(
                        fontSize: isWeb ? 10 : 8,
                        fontWeight: FontWeight.w600,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Product Name
                  Flexible(
                    child: Text(
                      product['name'],
                      style: TextStyle(
                        fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: isWeb ? 6 : 4),

                  // Price
                  Text(
                    product['hasSizes']
                        ? (product['category'] == 'Merchandise'
                            ? _formatSizePriceRange(product)
                            : '₱${_computeMinPriceFromSizes(product).toStringAsFixed(0)}')
                        : '₱${product['price'].toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isWeb ? 15 : (isTablet ? 14 : 13),
                      fontWeight: FontWeight.bold,
                      color: categoryColor,
                    ),
                  ),
                ],
              ),

              // Selection indicator
              if (isSelected)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: isWeb ? 24 : 20,
                    height: isWeb ? 24 : 20,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isWeb ? 12 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFF28A745);
      case 'drinks':
        return const Color(0xFF007BFF);
      case 'documents':
        return const Color(0xFF6C757D);
      case 'services':
        return const Color(0xFF17A2B8);
      case 'school items':
        return const Color(0xFF20C997);
      case 'merchandise':
        return const Color(0xFFFF6347);
      case 'fees':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFFB91C1C);
    }
  }

  void _selectProduct(Map<String, dynamic> product) {
    if (_isSingleItemMode) {
      // Check scanner connection for single-item mode
      if (!_isScannerConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please connect scanner before processing payment'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // For Campus Service Units, show purpose input first
      if (_isCampusServiceUnits) {
        _showPurposeInputDialog(product);
        return;
      }

      if (product['hasSizes']) {
        _showSizeSelectionModal(product, singleItem: true);
      } else if (product['allowCustomAmount'] == true) {
        _showCustomAmountDialog(product, singleItem: true);
      } else {
        widget.onProductSelected({
          'id': product['id'],
          'name': product['name'],
          'price': (product['price'] as num).toDouble(),
          'category': product['category'] ?? 'Custom',
          'orderType': 'single',
          'onPaymentSuccess': () {
            // For single-item mode, there's no cart to clear
            // but we can reset any UI state if needed
            widget.onPaymentSuccess?.call();
          },
        });
      }
      return;
    }

    if (product['hasSizes']) {
      // For products with sizes, open a floating modal to choose size
      _showSizeSelectionModal(product);
    } else if (product['allowCustomAmount'] == true) {
      // For documents that allow custom amounts, show amount input dialog
      _showCustomAmountDialog(product);
    } else {
      // For regular products, add directly to cart
      setState(() {
        if (selectedProducts.containsKey(product['id'])) {
          selectedProducts[product['id']] =
              selectedProducts[product['id']]! + 1;
        } else {
          selectedProducts[product['id']] = 1;
        }
        productPrices[product['id']] = (product['price'] as num).toDouble();
        _calculateTotal();
      });
    }
  }

  void _showSizeSelectionModal(
    Map<String, dynamic> product, {
    bool singleItem = false,
    String? purpose,
  }) {
    final String productId = product['id'].toString();
    final List<dynamic> sizesDynamic =
        (product['sizes'] ?? []) as List<dynamic>;
    final List<Map<String, dynamic>> sizes =
        sizesDynamic
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
    final Color accent = _getCategoryColor(product['category']);

    if (sizes.isEmpty) {
      // Fallback: treat as regular product
      setState(() {
        if (selectedProducts.containsKey(productId)) {
          selectedProducts[productId] = selectedProducts[productId]! + 1;
        } else {
          selectedProducts[productId] = 1;
        }
        productPrices[productId] = (product['price'] as num).toDouble();
        _calculateTotal();
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a size',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sizes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final size = sizes[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        title: Text('${size['name']}'),
                        trailing: Text(
                          '₱${(size['price'] as num).toDouble().toStringAsFixed(0)}',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () {
                          if (singleItem) {
                            Navigator.pop(context);
                            final productData = {
                              'id': productId,
                              'name': "${product['name']} (${size['name']})",
                              'price': (size['price'] as num).toDouble(),
                              'category': product['category'] ?? 'Custom',
                              'orderType': 'single',
                              'onPaymentSuccess': () {
                                widget.onPaymentSuccess?.call();
                              },
                            };
                            if (purpose != null) {
                              productData['purpose'] = purpose;
                            }
                            widget.onProductSelected(productData);
                          } else {
                            setState(() {
                              if (selectedProducts.containsKey(productId)) {
                                selectedProducts[productId] =
                                    selectedProducts[productId]! + 1;
                              } else {
                                selectedProducts[productId] = 1;
                              }
                              productPrices[productId] =
                                  (size['price'] as num).toDouble();
                              selectedSizeNames[productId] =
                                  size['name'].toString();
                              _calculateTotal();
                            });
                            Navigator.pop(context);
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _calculateTotal() {
    totalAmount = 0.0;
    selectedProducts.forEach((productId, quantity) {
      final price = productPrices[productId] ?? 0.0;
      totalAmount += price * quantity;
    });
  }

  void _clearOrder() {
    setState(() {
      selectedProducts.clear();
      productPrices.clear();
      selectedSizeNames.clear();
      totalAmount = 0.0;
      showPaymentSuccess = false;
    });
  }

  void _showCustomAmountDialog(
    Map<String, dynamic> product, {
    bool singleItem = false,
    String? purpose,
  }) {
    final amountController = TextEditingController(
      text: product['price'].toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${product['name']} - Enter Amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the amount for ${product['name']}:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₱',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final customAmount = double.tryParse(amountController.text);
                if (customAmount != null && customAmount > 0) {
                  if (singleItem) {
                    Navigator.pop(context);
                    final productData = {
                      'id': product['id'],
                      'name': product['name'],
                      'price': customAmount,
                      'category': product['category'] ?? 'Custom',
                      'orderType': 'single',
                      'onPaymentSuccess': () {
                        widget.onPaymentSuccess?.call();
                      },
                    };
                    if (purpose != null) {
                      productData['purpose'] = purpose;
                    }
                    widget.onProductSelected(productData);
                  } else {
                    setState(() {
                      if (selectedProducts.containsKey(product['id'])) {
                        selectedProducts[product['id']] =
                            selectedProducts[product['id']]! + 1;
                      } else {
                        selectedProducts[product['id']] = 1;
                      }
                      productPrices[product['id']] = customAmount;
                      _calculateTotal();
                    });
                    Navigator.pop(context);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Color(0xFFDC3545),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add to Cart'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddPaymentCard(bool isWeb, bool isTablet) {
    return GestureDetector(
      onTap: _showCustomPaymentModal,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isWeb ? 15 : 12),
          border: Border.all(
            color: const Color(0xFFB91C1C).withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isWeb ? 50 : (isTablet ? 45 : 40),
              height: isWeb ? 50 : (isTablet ? 45 : 40),
              decoration: BoxDecoration(
                color: const Color(0xFFB91C1C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                Icons.add,
                color: const Color(0xFFB91C1C),
                size: isWeb ? 28 : (isTablet ? 25 : 22),
              ),
            ),
            SizedBox(height: isWeb ? 12 : 8),
            Text(
              'Custom\nPayment',
              style: TextStyle(
                fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB91C1C),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomPaymentModal() {
    String? selectedCategory;
    final priceController = TextEditingController();
    final categories = _getCustomPaymentCategories();
    if (categories.isNotEmpty) {
      selectedCategory = categories.first;
    }
    final quickSumController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.7;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text(
                'Custom Payment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB91C1C),
                ),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create a custom payment for any service or item:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        items:
                            categories
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (v) => setModalState(() => selectedCategory = v),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Payment Category',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quickSumController,
                              keyboardType: TextInputType.text,
                              decoration: const InputDecoration(
                                labelText: 'Auto-sum input (comma, space, +)',
                                hintText: 'e.g., 90,90+20',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (rawValue) {
                                final normalized = _normalizeQuickSumInput(
                                  rawValue,
                                );
                                if (normalized != rawValue) {
                                  quickSumController.value = TextEditingValue(
                                    text: normalized,
                                    selection: TextSelection.collapsed(
                                      offset: normalized.length,
                                    ),
                                  );
                                  return;
                                }
                                final sum = _sumQuickInput(normalized);
                                setModalState(() {
                                  if (sum > 0) {
                                    priceController.text = _formatAutoSum(sum);
                                  } else {
                                    priceController.clear();
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final raw = quickSumController.text.trim();
                              final normalizedCurrent = _normalizeQuickSumInput(
                                raw,
                              );
                              if (normalizedCurrent.isEmpty) {
                                return;
                              }
                              final newText =
                                  normalizedCurrent.isEmpty
                                      ? ''
                                      : normalizedCurrent.endsWith('+')
                                      ? normalizedCurrent
                                      : '$normalizedCurrent+';
                              final displayText = newText;
                              quickSumController.value = TextEditingValue(
                                text: displayText,
                                selection: TextSelection.collapsed(
                                  offset: displayText.length,
                                ),
                              );
                              final sum = _sumQuickInput(
                                _normalizeQuickSumInput(displayText),
                              );
                              setModalState(() {
                                if (sum > 0) {
                                  priceController.text = _formatAutoSum(sum);
                                } else {
                                  priceController.clear();
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black87,
                            ),
                            child: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₱',
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final category = (selectedCategory ?? '').trim();
                    final amount = double.tryParse(priceController.text);

                    if (category.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a payment category'),
                          backgroundColor: Color(0xFFDC3545),
                        ),
                      );
                      return;
                    }

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: Color(0xFFDC3545),
                        ),
                      );
                      return;
                    }

                    // Navigate directly to payment screen with custom payment
                    Navigator.pop(context);
                    widget.onProductSelected({
                      'id':
                          'custom-payment-${DateTime.now().millisecondsSinceEpoch}',
                      'name': category,
                      'price': amount,
                      'category': 'Custom',
                      'orderType': 'single',
                      'onPaymentSuccess': () {
                        widget.onPaymentSuccess?.call();
                      },
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Proceed to Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _getCustomPaymentCategories() {
    // Vendor: all categories; Campus Service Units and Organizations: Services/Documents/School Items/Fees
    if (_isCampusServiceUnits || _isOrganization) {
      return ['Services', 'Documents', 'School Items', 'Fees'];
    }
    // Treat others as Vendor by default
    return [
      'Food',
      'Drinks',
      'Desserts',
      'Documents',
      'Services',
      'School Items',
      'Fees',
      'Merchandise',
    ];
  }

  String _normalizeQuickSumInput(String input) {
    if (input.isEmpty) {
      return '';
    }
    String normalized = input;

    // Replace commas or whitespace with '+'
    normalized = normalized.replaceAll(RegExp(r'[,\s]+'), '+');
    // Remove any character that isn't digit, plus, or decimal point
    normalized = normalized.replaceAll(RegExp(r'[^0-9+\.]'), '');
    // Collapse multiple pluses into one
    normalized = normalized.replaceAll(RegExp(r'\++'), '+');
    // Trim leading/trailing plus
    normalized = normalized.replaceAll(RegExp(r'^\+|\+$'), '');
    return normalized;
  }

  double _sumQuickInput(String normalizedInput) {
    if (normalizedInput.isEmpty) {
      return 0.0;
    }
    double sum = 0.0;
    for (final part in normalizedInput.split('+')) {
      final value = part.trim();
      if (value.isEmpty) {
        continue;
      }
      final number = double.tryParse(value);
      if (number != null) {
        sum += number;
      }
    }
    return sum;
  }

  String _formatAutoSum(double value) {
    final isInteger = value == value.roundToDouble();
    return isInteger ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  String _formatSizePriceRange(Map<String, dynamic> product) {
    final sizesDynamic = (product['sizes'] ?? []) as List<dynamic>;
    if (sizesDynamic.isEmpty) {
      return '₱${(product['price'] as num).toDouble().toStringAsFixed(2)}';
    }
    final sizes =
        sizesDynamic
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
    double? minPrice;
    double? maxPrice;
    for (final s in sizes) {
      final p = (s['price'] as num?)?.toDouble();
      if (p == null) continue;
      if (minPrice == null || p < minPrice) minPrice = p;
      if (maxPrice == null || p > maxPrice) maxPrice = p;
    }
    if (minPrice == null) {
      return '₱${(product['price'] as num).toDouble().toStringAsFixed(2)}';
    }
    if (maxPrice == null || (maxPrice - minPrice).abs() < 0.0001) {
      return '₱${minPrice.toStringAsFixed(0)}';
    }
    return '₱${minPrice.toStringAsFixed(0)}-${maxPrice.toStringAsFixed(0)}';
  }

  double _computeMinPriceFromSizes(Map<String, dynamic> product) {
    final sizesDynamic = (product['sizes'] ?? []) as List<dynamic>;
    double? minPrice;
    for (final e in sizesDynamic) {
      final map = Map<String, dynamic>.from(e as Map);
      final p = (map['price'] as num?)?.toDouble();
      if (p == null) continue;
      if (minPrice == null || p < minPrice) minPrice = p;
    }
    return (minPrice ?? (product['price'] as num).toDouble());
  }

  void _showCartModal() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWeb ? 24 : 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          color: const Color(0xFFB91C1C),
                          size: isWeb ? 28 : 24,
                        ),
                        SizedBox(width: isWeb ? 12 : 10),
                        Expanded(
                          child: Text(
                            'Cart',
                            style: TextStyle(
                              fontSize: isWeb ? 24 : 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF333333),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: Colors.grey.shade600,
                            size: isWeb ? 24 : 20,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Cart items list
                  Expanded(
                    child:
                        selectedProducts.isEmpty
                            ? _buildEmptyCart(isWeb)
                            : _buildCartItemsList(isWeb, setModalState),
                  ),

                  // Cart summary and actions
                  if (selectedProducts.isNotEmpty)
                    _buildCartSummary(isWeb, setModalState),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyCart(bool isWeb) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: isWeb ? 80 : 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: isWeb ? 24 : 20),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: isWeb ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: isWeb ? 8 : 6),
          Text(
            'Add items to your cart to get started',
            style: TextStyle(
              fontSize: isWeb ? 14 : 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemsList(bool isWeb, StateSetter setModalState) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isWeb ? 24 : 20, vertical: 16),
      itemCount: selectedProducts.length,
      itemBuilder: (context, index) {
        final productId = selectedProducts.keys.elementAt(index);
        final quantity = selectedProducts[productId]!;
        final product = products.firstWhere((p) => p['id'] == productId);
        final price = productPrices[productId] ?? product['price'];
        final String displayName =
            selectedSizeNames.containsKey(productId)
                ? '${product['name']} (${selectedSizeNames[productId]})'
                : product['name'];
        final categoryColor = _getCategoryColor(product['category']);

        return Container(
          margin: EdgeInsets.only(bottom: isWeb ? 16 : 12),
          padding: EdgeInsets.all(isWeb ? 20 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
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
              // Category indicator
              Container(
                width: isWeb ? 4 : 3,
                height: isWeb ? 60 : 50,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: isWeb ? 16 : 12),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: isWeb ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: isWeb ? 4 : 3),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWeb ? 8 : 6,
                        vertical: isWeb ? 4 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(isWeb ? 6 : 4),
                      ),
                      child: Text(
                        product['category'],
                        style: TextStyle(
                          fontSize: isWeb ? 10 : 8,
                          fontWeight: FontWeight.w500,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    SizedBox(height: isWeb ? 8 : 6),
                    Text(
                      '₱${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isWeb ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Quantity controls
              Row(
                children: [
                  // Decrease button
                  Container(
                    width: isWeb ? 36 : 32,
                    height: isWeb ? 36 : 32,
                    decoration: BoxDecoration(
                      color:
                          quantity > 1
                              ? Colors.red.shade50
                              : Colors.grey.shade100,
                      border: Border.all(
                        color:
                            quantity > 1
                                ? Colors.red.shade200
                                : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed:
                          quantity > 1
                              ? () => _updateQuantityInModal(
                                productId,
                                quantity - 1,
                                setModalState,
                              )
                              : null,
                      icon: Icon(
                        Icons.remove,
                        size: isWeb ? 18 : 16,
                        color:
                            quantity > 1
                                ? Colors.red.shade600
                                : Colors.grey.shade400,
                      ),
                    ),
                  ),

                  // Quantity display
                  Container(
                    width: isWeb ? 50 : 45,
                    height: isWeb ? 36 : 32,
                    margin: EdgeInsets.symmetric(horizontal: isWeb ? 8 : 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
                    ),
                    child: Center(
                      child: Text(
                        quantity.toString(),
                        style: TextStyle(
                          fontSize: isWeb ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),

                  // Increase button
                  Container(
                    width: isWeb ? 36 : 32,
                    height: isWeb ? 36 : 32,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(isWeb ? 8 : 6),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed:
                          () => _updateQuantityInModal(
                            productId,
                            quantity + 1,
                            setModalState,
                          ),
                      icon: Icon(
                        Icons.add,
                        size: isWeb ? 18 : 16,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(width: isWeb ? 16 : 12),

              // Remove button
              IconButton(
                onPressed:
                    () => _removeFromCartInModal(productId, setModalState),
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                  size: isWeb ? 24 : 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartSummary(bool isWeb, StateSetter setModalState) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Total summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount:',
                style: TextStyle(
                  fontSize: isWeb ? 18 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF333333),
                ),
              ),
              Text(
                '₱${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: isWeb ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFB91C1C),
                ),
              ),
            ],
          ),

          SizedBox(height: isWeb ? 20 : 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _clearOrderInModal(setModalState),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C757D),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isWeb ? 16 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: isWeb ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isWeb ? 16 : 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      _isScannerConnected
                          ? () {
                            Navigator.pop(context);
                            _processPayment();
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isScannerConnected
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFFCCCCCC),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isWeb ? 16 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isWeb ? 12 : 10),
                    ),
                    elevation: _isScannerConnected ? 3 : 0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Proceed to Payment',
                        style: TextStyle(
                          fontSize: isWeb ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!_isScannerConnected)
                        Text(
                          'Scanner not connected',
                          style: TextStyle(
                            fontSize: isWeb ? 11 : 9,
                            fontWeight: FontWeight.normal,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modal-specific methods for state updates
  void _updateQuantityInModal(
    String productId,
    int newQuantity,
    StateSetter setModalState,
  ) {
    setState(() {
      if (newQuantity <= 0) {
        _removeFromCartInModal(productId, setModalState);
      } else {
        selectedProducts[productId] = newQuantity;
        _calculateTotal();
      }
    });
    setModalState(() {}); // Update modal state
  }

  void _removeFromCartInModal(String productId, StateSetter setModalState) {
    setState(() {
      selectedProducts.remove(productId);
      productPrices.remove(productId);
      selectedSizeNames.remove(productId);
      _calculateTotal();
    });
    setModalState(() {}); // Update modal state
  }

  void _clearOrderInModal(StateSetter setModalState) {
    setState(() {
      selectedProducts.clear();
      productPrices.clear();
      selectedSizeNames.clear();
      totalAmount = 0.0;
      showPaymentSuccess = false;
    });
    setModalState(() {}); // Update modal state
  }

  void _processPayment() {
    if (totalAmount > 0 && _isScannerConnected) {
      // For Campus Service Units, show purpose input first
      if (_isCampusServiceUnits) {
        _showPurposeInputDialogForMultipleItems();
        return;
      }

      // Create order summary for payment
      final orderItems = <Map<String, dynamic>>[];
      selectedProducts.forEach((productId, quantity) {
        final product = products.firstWhere((p) => p['id'] == productId);
        final price = productPrices[productId] ?? product['price'];
        final String displayName =
            selectedSizeNames.containsKey(productId)
                ? '${product['name']} (${selectedSizeNames[productId]})'
                : product['name'];
        orderItems.add({
          'id': productId,
          'name': displayName,
          'price': price,
          'quantity': quantity,
          'total': price * quantity,
        });
      });

      // Navigate to payment screen with order
      widget.onProductSelected({
        'orderItems': orderItems,
        'totalAmount': totalAmount,
        'orderType': 'multiple',
        'onPaymentSuccess': () {
          // Clear cart when payment succeeds
          _clearCart();
          // Call parent callback if provided
          widget.onPaymentSuccess?.call();
        },
      });
    } else if (!_isScannerConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect scanner before processing payment'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Show purpose input dialog for Campus Service Units (single item)
  void _showPurposeInputDialog(Map<String, dynamic> product) {
    final purposeController = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.description,
                  color: const Color(0xFFB91C1C),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Purpose of Payment',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please enter the purpose of this payment:',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: purposeController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'e.g., Document processing fee, Service fee, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFB91C1C),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final purpose = purposeController.text.trim();
                  if (purpose.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter a purpose for this payment',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  // Proceed with product selection based on type
                  if (product['hasSizes']) {
                    _showSizeSelectionModal(
                      product,
                      singleItem: true,
                      purpose: purpose,
                    );
                  } else if (product['allowCustomAmount'] == true) {
                    _showCustomAmountDialog(
                      product,
                      singleItem: true,
                      purpose: purpose,
                    );
                  } else {
                    widget.onProductSelected({
                      'id': product['id'],
                      'name': product['name'],
                      'price': (product['price'] as num).toDouble(),
                      'category': product['category'] ?? 'Custom',
                      'orderType': 'single',
                      'purpose': purpose,
                      'onPaymentSuccess': () {
                        widget.onPaymentSuccess?.call();
                      },
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  // Show purpose input dialog for multiple items (Campus Service Units)
  void _showPurposeInputDialogForMultipleItems() {
    final purposeController = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.description,
                  color: const Color(0xFFB91C1C),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Purpose of Payment',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please enter the purpose of this payment:',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: purposeController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'e.g., Document processing fee, Service fee, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFB91C1C),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final purpose = purposeController.text.trim();
                  if (purpose.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter a purpose for this payment',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  // Create order summary for payment
                  final orderItems = <Map<String, dynamic>>[];
                  selectedProducts.forEach((productId, quantity) {
                    final product = products.firstWhere(
                      (p) => p['id'] == productId,
                    );
                    final price = productPrices[productId] ?? product['price'];
                    final String displayName =
                        selectedSizeNames.containsKey(productId)
                            ? '${product['name']} (${selectedSizeNames[productId]})'
                            : product['name'];
                    orderItems.add({
                      'id': productId,
                      'name': displayName,
                      'price': price,
                      'quantity': quantity,
                      'total': price * quantity,
                    });
                  });

                  // Navigate to payment screen with order and purpose
                  widget.onProductSelected({
                    'orderItems': orderItems,
                    'totalAmount': totalAmount,
                    'orderType': 'multiple',
                    'purpose': purpose,
                    'onPaymentSuccess': () {
                      // Clear cart when payment succeeds
                      _clearCart();
                      // Call parent callback if provided
                      widget.onPaymentSuccess?.call();
                    },
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _loadItems() async {
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
      print('DEBUG: Loading ${data.length} items from database');
      products.clear();
      _productById.clear();
      for (final raw in data) {
        final hasSizes = raw['has_sizes'] == true;
        final Map<String, dynamic> product = {
          'id': raw['id'].toString(),
          'name': raw['name'],
          'price': (raw['base_price'] as num).toDouble(),
          'hasSizes': hasSizes,
          'category': raw['category'],
        };
        if (hasSizes && raw['size_options'] != null) {
          final sizes = <Map<String, dynamic>>[];
          (raw['size_options'] as Map).forEach((k, v) {
            final price = (v as num).toDouble();
            sizes.add({'name': k.toString(), 'price': price});
          });
          product['sizes'] = sizes;
        }
        products.add(product);
        _productById[product['id']] = product;
      }
      print('DEBUG: Successfully loaded ${products.length} products');
      setState(() {}); // Trigger UI rebuild to display loaded items
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load items: ${resp['message'] ?? ''}'),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    }
  }
}
