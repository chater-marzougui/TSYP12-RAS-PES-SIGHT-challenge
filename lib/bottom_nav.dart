import 'package:cleaner_tunisia/main_screens/reports_screen.dart';
import 'package:cleaner_tunisia/main_screens/robots.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'main_screens/map.dart';

class HomePage extends StatefulWidget {
  final String userID;
  const HomePage({super.key, required this.userID});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  DateTime? lastPressed;

  List<Widget> _pages = [];
  final GlobalKey<CurvedNavigationBarState> _navigationKey = GlobalKey();


  final List<bool> _pagesUnderNav = [true, true, false];


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(userID: widget.userID),
      RobotOverviewPage(),
      ReportDirtyPlaceScreen(userID: widget.userID),
    ];
  }

  @override
  Widget build(BuildContext context)    {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        final now = DateTime.now();
        if (lastPressed == null ||
            now.difference(lastPressed!) > const Duration(seconds: 2)) {
          lastPressed = now;
          Fluttertoast.showToast(msg: 'Tap again to exit');
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Pages that go under the navbar
            if (_pagesUnderNav[_selectedIndex])
              _pages[_selectedIndex]
            else
              Padding(
                padding: EdgeInsets.only(bottom: 60 + bottomPadding), // Height of navbar
                child: _pages[_selectedIndex],
              ),

            // Navigation bar

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CurvedNavigationBar(
                key: _navigationKey,
                index: _selectedIndex,
                backgroundColor: _pagesUnderNav[_selectedIndex]
                    ? Colors.transparent
                    : theme.canvasColor,
                color: theme.primaryColor,
                buttonBackgroundColor: theme.primaryColor,
                height: 60,
                animationDuration: const Duration(milliseconds: 300),
                animationCurve: Curves.easeInOut,
                onTap: _onItemTapped,
                items: <Widget>[
                  _buildNavigationItem(
                    icon: Icons.map,
                    index: 0,
                    label: "Map",
                    theme: theme,
                  ),
                  _buildNavigationItem(
                    icon: Icons.cleaning_services_sharp,
                    index: 1,
                    label: "Robots",
                    theme: theme,
                  ),
                  _buildNavigationItem(
                    icon: Icons.report,
                    index: 2,
                    label: "report",
                    theme: theme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String label,
    required int index,
    required ThemeData theme,
  }) {
    final isSelected = _selectedIndex == index;

    return Container(
      height: 48, // Fixed height for all items
      width: 48,  // Fixed width for all items
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: isSelected ? Colors.white : Colors.white70,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/*
child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            backgroundColor: theme.cardColor,
            onTap: _onItemTapped,
            selectedItemColor: theme.primaryColor,
            unselectedItemColor: theme.colorScheme.tertiary,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home, color: theme.colorScheme.tertiary),
                activeIcon: Icon(Icons.home, color: theme.primaryColor),
                label: S.of(context).home,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search, color: theme.colorScheme.tertiary),
                activeIcon: Icon(Icons.search, color: theme.primaryColor),
                label: S.of(context).search,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_home_work_outlined, color: theme.colorScheme.tertiary),
                activeIcon: Icon(Icons.add_home_work_outlined, color: theme.primaryColor),
                label: S.of(context).add,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications, color: theme.colorScheme.tertiary),
                activeIcon: Icon(Icons.notifications, color: theme.primaryColor),
                label: S.of(context).inbox,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person, color: theme.colorScheme.tertiary),
                activeIcon: Icon(Icons.person, color: theme.primaryColor),
                label: S.of(context).profile,
              ),
            ],
          ),

           */