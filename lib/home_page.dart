import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color evsuRed = Color(0xFFB01212);

  int selectedBottomIndex = 0;
  String selectedSegment = 'wallet';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative rounded corner at the top-right
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 180,
                height: 120,
                decoration: const BoxDecoration(
                  color: evsuRed,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(64),
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top-left logo + Hello! with no spacing
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Image.asset('assets/letter_e.png', width: 40, height: 40),
                      const Text(
                        'Hello!',
                        style: TextStyle(
                          color: evsuRed,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 80),

                  // Centered welcome heading above the tabs
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'WELCOME',
                          style: TextStyle(
                            color: evsuRed,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Rian James Canon',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Expanded(child: _buildSegmentContent()),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildSegmentContent() {
    Widget card;
    switch (selectedSegment) {
      case 'borrow':
        card = _RedModalCard(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Borrowed Amount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '₱0.00',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _whiteChip('Eloan'),
                _whiteChip('Ehistory'),
                _whiteChip('Pay Loan'),
              ],
            ),
          ],
        );
        break;
      case 'saving':
        card = _RedModalCard(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Saving Balance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.savings_outlined, color: Colors.white),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '₱0.00',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: evsuRed,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {},
                child: const Text(
                  'Start Saving',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        );
        break;
      case 'wallet':
      default:
        card = _RedModalCard(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Available Balance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.remove_red_eye_outlined, color: Colors.white),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '₱100.00',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: evsuRed,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {},
                child: const Text(
                  'Transfer',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentTabs(attachedToCard: true),
          const SizedBox(height: 4),
          card,
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return NavigationBar(
      selectedIndex: selectedBottomIndex,
      onDestinationSelected: (int index) {
        setState(() {
          selectedBottomIndex = index;
        });
      },
      destinations: [
        _navDestination('assets/home.png', Icons.home_outlined, 'Home'),
        _navDestination('assets/mail.png', Icons.mail_outline, 'Inbox'),
        _navDestination(
          'assets/transaction.png',
          Icons.swap_horiz,
          'Transaction',
        ),
        _navDestination('assets/user.png', Icons.person_outline, 'Profile'),
      ],
    );
  }

  Widget _buildSegmentTabs({bool attachedToCard = false}) {
    Widget buildTab(String value, String label, {BorderRadius? radius}) {
      final bool isSelected = selectedSegment == value;
      return GestureDetector(
        onTap: () => setState(() => selectedSegment = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? evsuRed : const Color(0xFFBDBDBD),
            borderRadius: radius ?? BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          buildTab(
            'wallet',
            'Wallet',
            radius:
                attachedToCard
                    ? const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    )
                    : const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
          ),
          buildTab(
            'borrow',
            'Borrow',
            radius:
                attachedToCard
                    ? const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    )
                    : const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
          ),
          buildTab(
            'saving',
            'Savings',
            radius:
                attachedToCard
                    ? const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    )
                    : const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _whiteChip(String text) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: evsuRed,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      onPressed: () {},
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  NavigationDestination _navDestination(
    String assetPath,
    IconData fallback,
    String label,
  ) {
    return NavigationDestination(
      icon: _assetOrIcon(assetPath, fallback, false),
      selectedIcon: _assetOrIcon(assetPath, fallback, true),
      label: label,
    );
  }

  Widget _assetOrIcon(String assetPath, IconData fallback, bool selected) {
    final Color iconColor = selected ? evsuRed : Colors.black54;
    return Image.asset(
      assetPath,
      width: 24,
      height: 24,
      color: iconColor,
      // If asset is missing, show the fallback icon
      errorBuilder: (context, error, stack) => Icon(fallback, color: iconColor),
    );
  }
}

class _RedModalCard extends StatelessWidget {
  const _RedModalCard({required this.children});

  final List<Widget> children;
  static const Color evsuRed = Color(0xFFB01212);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double paddedWidth =
        screenWidth - 32; // 16px horizontal padding per side
    const double maxWidth = 420;
    final double cardWidth = paddedWidth > maxWidth ? maxWidth : paddedWidth;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: evsuRed,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

// Old per-view widgets removed; unified rendering happens in _buildSegmentContent
