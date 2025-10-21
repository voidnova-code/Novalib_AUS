import 'package:flutter/material.dart';
import 'home.dart';
import 'pages/issued_books_page.dart';
import 'pages/pay_fine_page.dart';

class AppShell extends StatefulWidget {
  final String username;
  final bool useAltBackground;
  final String? userBarcode;

  const AppShell({
    Key? key,
    required this.username,
    required this.useAltBackground,
    this.userBarcode,
  }) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomePage(
        useAltBackground: widget.useAltBackground,
        username: widget.username,
        userBarcode: widget.userBarcode,
      ),
      IssuedBooksPage(
        username: widget.username,
        userBarcode: widget.userBarcode,
      ),
      PayFinePage(username: widget.username),
    ];
  }

  Future<bool> _onWillPop() async {
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          height: 64,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Issued',
            ),
            NavigationDestination(
              icon: Icon(Icons.currency_rupee_outlined),
              selectedIcon: Icon(Icons.currency_rupee),
              label: 'Pay Fine',
            ),
          ],
        ),
      ),
    );
  }
}
