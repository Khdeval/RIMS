import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Resolves the API base URL based on the environment.
///
/// Priority:
/// 1. Compile-time env: --dart-define=API_URL=https://...
/// 2. Auto-detect from browser origin (for Codespaces / deployed envs)
/// 3. Fallback to localhost:3000
String _resolveBaseUrl() {
  // Check compile-time override first
  const envUrl = String.fromEnvironment('API_URL', defaultValue: '');
  if (envUrl.isNotEmpty) return envUrl;

  if (kIsWeb) {
    try {
      // Auto-detect: if running on a forwarded port (Codespaces, Gitpod, etc.),
      // derive port-3000 URL from the current browser origin
      final origin = Uri.base.origin; // e.g. https://...-8080.app.github.dev
      if (origin.contains('app.github.dev') || origin.contains('gitpod.io')) {
        // Replace port in the subdomain
        final portPattern = RegExp(r'-\d+\.');
        return origin.replaceFirst(portPattern, '-3000.');
      }
      // Same host, different port (local Docker / VM)
      final uri = Uri.base;
      return '${uri.scheme}://${uri.host}:3000';
    } catch (_) {}
  }
  return 'http://localhost:3000';
}

void main() {
  runApp(const MyApp());
}

// API Service
class ApiService {
  static final String baseUrl = _resolveBaseUrl();

  // Menu Items
  static Future<List<dynamic>> getMenuItems() async {
    final response = await http.get(Uri.parse('$baseUrl/menu-items'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load menu items');
  }

  static Future<dynamic> createMenuItem(String name, double basePrice) async {
    final response = await http.post(
      Uri.parse('$baseUrl/menu-items'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'basePrice': basePrice}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create menu item');
  }

  static Future<void> updateMenuItem(int id, String name, double basePrice) async {
    final response = await http.put(
      Uri.parse('$baseUrl/menu-items/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'basePrice': basePrice}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update menu item');
    }
  }

  static Future<void> deleteMenuItem(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/menu-items/$id'));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete menu item');
    }
  }

  // Ingredients
  static Future<List<dynamic>> getIngredients() async {
    final response = await http.get(Uri.parse('$baseUrl/ingredients'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load ingredients');
  }

  static Future<dynamic> createIngredient(String name, String unit, double currentStock, double parLevel, double unitCost) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ingredients'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'unit': unit,
        'currentStock': currentStock,
        'parLevel': parLevel,
        'unitCost': unitCost,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create ingredient');
  }

  static Future<void> updateIngredient(int id, {String? name, String? unit, double? currentStock, double? parLevel, double? unitCost}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (unit != null) body['unit'] = unit;
    if (currentStock != null) body['currentStock'] = currentStock;
    if (parLevel != null) body['parLevel'] = parLevel;
    if (unitCost != null) body['unitCost'] = unitCost;
    final response = await http.put(
      Uri.parse('$baseUrl/ingredients/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update ingredient');
    }
  }

  static Future<void> deleteIngredient(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/ingredients/$id'));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete ingredient');
    }
  }

  // Recipe Items
  static Future<List<dynamic>> getRecipeItems(int menuItemId) async {
    final response = await http.get(Uri.parse('$baseUrl/menu-items/$menuItemId/recipes'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  static Future<void> addRecipeItem(int menuItemId, int ingredientId, double quantity, double yieldFactor) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recipe-items'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'menuItemId': menuItemId,
        'ingredientId': ingredientId,
        'quantityRequired': quantity,
        'yieldFactor': yieldFactor,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add recipe item');
    }
  }

  static Future<void> updateRecipeItem(int id, double quantity, double yieldFactor) async {
    final response = await http.put(
      Uri.parse('$baseUrl/recipe-items/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'quantityRequired': quantity, 'yieldFactor': yieldFactor}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update recipe item');
    }
  }

  static Future<void> deleteRecipeItem(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/recipe-items/$id'));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete recipe item');
    }
  }

  // All recipes
  static Future<List<dynamic>> getAllRecipes() async {
    final response = await http.get(Uri.parse('$baseUrl/recipe-items'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load recipes');
  }

  // Sales
  static Future<List<dynamic>> getSales({int days = 30}) async {
    final response = await http.get(Uri.parse('$baseUrl/sales?days=$days'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load sales');
  }

  static Future<dynamic> getSalesReport({int days = 7}) async {
    final response = await http.get(Uri.parse('$baseUrl/sales/report?days=$days'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load sales report');
  }

  static Future<dynamic> recordSale(int menuItemId, int quantitySold) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sales'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'menuItemId': menuItemId, 'quantitySold': quantitySold}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    final body = json.decode(response.body);
    throw Exception(body['message'] ?? body['error'] ?? 'Failed to record sale');
  }

  // Waste logs
  static Future<List<dynamic>> getWasteLogs({int days = 30}) async {
    final response = await http.get(Uri.parse('$baseUrl/waste-logs?days=$days'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load waste logs');
  }

  static Future<dynamic> getWasteSummary({int days = 30}) async {
    final response = await http.get(Uri.parse('$baseUrl/waste-logs/summary?days=$days'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load waste summary');
  }

  static Future<dynamic> logWaste(int ingredientId, double quantity, String reason) async {
    final response = await http.post(
      Uri.parse('$baseUrl/waste-logs'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'ingredientId': ingredientId, 'quantity': quantity, 'reason': reason}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to log waste');
  }

  // Stock deductions
  static Future<dynamic> getStockDeductions(int menuItemId) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-deductions/$menuItemId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load stock deductions');
  }
}

// Providers
class InventoryProvider with ChangeNotifier {
  List<dynamic> inventory = [];
  late IO.Socket socket;

  InventoryProvider() {
    socket = IO.io('http://localhost:3000', IO.OptionBuilder().setTransports(['websocket']).build());
    socket.onConnect((_) {
      debugPrint('Connected to backend');
    });
    socket.on('inventory_update', (data) {
      inventory = data['items'] ?? [];
      notifyListeners();
    });
  }
}

class MenuProvider with ChangeNotifier {
  List<dynamic> menuItems = [];
  List<dynamic> ingredients = [];
  bool isLoading = false;

  Future<void> loadMenuItems() async {
    isLoading = true;
    notifyListeners();
    try {
      menuItems = await ApiService.getMenuItems();
    } catch (e) {
      debugPrint('Error loading menu items: $e');
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadIngredients() async {
    try {
      ingredients = await ApiService.getIngredients();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading ingredients: $e');
    }
  }

  Future<void> addMenuItem(String name, double basePrice) async {
    try {
      await ApiService.createMenuItem(name, basePrice);
      await loadMenuItems();
    } catch (e) {
      debugPrint('Error adding menu item: $e');
      rethrow;
    }
  }

  Future<void> updateMenuItem(int id, String name, double basePrice) async {
    try {
      await ApiService.updateMenuItem(id, name, basePrice);
      await loadMenuItems();
    } catch (e) {
      debugPrint('Error updating menu item: $e');
      rethrow;
    }
  }

  Future<void> deleteMenuItem(int id) async {
    try {
      await ApiService.deleteMenuItem(id);
      await loadMenuItems();
    } catch (e) {
      debugPrint('Error deleting menu item: $e');
      rethrow;
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color _primary = Color(0xFF1B5E20);
  static const Color _secondary = Color(0xFFFF6F00);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RIMS Dashboard',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: _primary,
          brightness: Brightness.light,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 2,
          ),
          cardTheme: CardTheme(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          navigationRailTheme: NavigationRailThemeData(
            backgroundColor: const Color(0xFF1B5E20),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: IconThemeData(color: Colors.white.withOpacity(0.6)),
            indicatorColor: Colors.white.withOpacity(0.15),
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(Icons.dashboard_rounded, 'Overview'),
    _NavItem(Icons.restaurant_menu_rounded, 'Menu'),
    _NavItem(Icons.menu_book_rounded, 'Recipes'),
    _NavItem(Icons.inventory_2_rounded, 'Ingredients'),
    _NavItem(Icons.point_of_sale_rounded, 'Sales'),
    _NavItem(Icons.delete_sweep_rounded, 'Waste'),
    _NavItem(Icons.calculate_rounded, 'Deductions'),
  ];

  final List<Widget> _screens = const [
    OverviewDashboard(),
    MenuManagementScreen(),
    RecipeManagementScreen(),
    IngredientManagementScreen(),
    SalesTrackingScreen(),
    WasteTrackingScreen(),
    StockDeductionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 820;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isWide,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('RIMS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(width: 6),
            Text('| ${_navItems[_selectedIndex].label}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.restaurant, size: 40, color: Colors.white),
                        SizedBox(height: 12),
                        Text('RIMS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                        Text('Restaurant Inventory Management',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _drawerSection('DASHBOARD'),
                        _drawerTile(0),
                        const Divider(height: 24, indent: 16, endIndent: 16),
                        _drawerSection('MANAGEMENT'),
                        _drawerTile(1),
                        _drawerTile(2),
                        _drawerTile(3),
                        const Divider(height: 24, indent: 16, endIndent: 16),
                        _drawerSection('TRACKING'),
                        _drawerTile(4),
                        _drawerTile(5),
                        _drawerTile(6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  extended: MediaQuery.of(context).size.width >= 1100,
                  minExtendedWidth: 180,
                  selectedIndex: _selectedIndex,
                  labelType: MediaQuery.of(context).size.width >= 1100
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.restaurant, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 4),
                        const Text('RIMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                      ],
                    ),
                  ),
                  destinations: _navItems
                      .map((n) => NavigationRailDestination(
                            icon: Icon(n.icon),
                            label: Text(n.label),
                          ))
                      .toList(),
                  onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _screens[_selectedIndex]),
              ],
            )
          : _screens[_selectedIndex],
    );
  }

  Widget _drawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 16, 4),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1)),
    );
  }

  Widget _drawerTile(int index) {
    final n = _navItems[index];
    final selected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selected: selected,
        selectedTileColor: const Color(0xFF1B5E20).withOpacity(0.08),
        leading: Icon(n.icon, color: selected ? const Color(0xFF1B5E20) : Colors.grey[700]),
        title: Text(n.label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

// ========== OVERVIEW DASHBOARD ==========

class OverviewDashboard extends StatefulWidget {
  const OverviewDashboard({super.key});

  @override
  State<OverviewDashboard> createState() => _OverviewDashboardState();
}

class _OverviewDashboardState extends State<OverviewDashboard> {
  bool _loading = true;
  List<dynamic> ingredients = [];
  List<dynamic> menuItems = [];
  List<dynamic> recentSales = [];
  List<dynamic> recentWaste = [];
  dynamic salesReport;
  dynamic wasteSummary;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getIngredients(),
        ApiService.getMenuItems(),
        ApiService.getSales(days: 7),
        ApiService.getWasteLogs(days: 7),
        ApiService.getSalesReport(days: 7),
        ApiService.getWasteSummary(days: 7),
      ]);
      ingredients = results[0] as List<dynamic>;
      menuItems = results[1] as List<dynamic>;
      recentSales = results[2] as List<dynamic>;
      recentWaste = results[3] as List<dynamic>;
      salesReport = results[4];
      wasteSummary = results[5];
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Compute stats
    final lowStockItems = ingredients.where((i) {
      final stock = (i['currentStock'] as num?)?.toDouble() ?? 0;
      final par = (i['parLevel'] as num?)?.toDouble() ?? 1;
      return stock < par;
    }).toList();

    double totalRevenue = 0;
    int totalSalesCount = 0;
    final summary = (salesReport?['summary'] as List<dynamic>?) ?? [];
    for (final s in summary) {
      totalRevenue += (s['revenue'] as num?)?.toDouble() ?? 0;
      totalSalesCount += (s['quantity'] as num?)?.toInt() ?? 0;
    }

    double wasteTotal = 0;
    final byIng = (wasteSummary?['byIngredient'] as List<dynamic>?) ?? [];
    for (final w in byIng) {
      wasteTotal += (w['totalCost'] as num?)?.toDouble() ?? 0;
    }

    final totalInventoryValue = ingredients.fold<double>(0.0, (sum, i) {
      return sum + ((i['currentStock'] as num?)?.toDouble() ?? 0) * ((i['unitCost'] as num?)?.toDouble() ?? 0);
    });

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Restaurant Inventory Management',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Last 7 days overview — ${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // KPI Cards Row
            _sectionTitle('Key Metrics'),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 36) / 4;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _kpiCard('Revenue (7d)', '\$${totalRevenue.toStringAsFixed(0)}',
                        Icons.trending_up_rounded, const Color(0xFF2E7D32), cardWidth),
                    _kpiCard('Sales (7d)', '$totalSalesCount items sold',
                        Icons.point_of_sale_rounded, const Color(0xFF1565C0), cardWidth),
                    _kpiCard('Inventory Value', '\$${totalInventoryValue.toStringAsFixed(0)}',
                        Icons.inventory_2_rounded, const Color(0xFF6A1B9A), cardWidth),
                    _kpiCard('Waste Cost (7d)', '\$${wasteTotal.toStringAsFixed(2)}',
                        Icons.delete_sweep_rounded, const Color(0xFFC62828), cardWidth),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 36) / 4;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _kpiCard('Menu Items', '${menuItems.length}',
                        Icons.restaurant_menu_rounded, const Color(0xFFE65100), cardWidth),
                    _kpiCard('Ingredients', '${ingredients.length}',
                        Icons.category_rounded, const Color(0xFF00838F), cardWidth),
                    _kpiCard('Low Stock Alerts', '${lowStockItems.length}',
                        Icons.warning_amber_rounded,
                        lowStockItems.isEmpty ? const Color(0xFF388E3C) : const Color(0xFFD84315), cardWidth),
                    _kpiCard('Waste Entries (7d)', '${wasteSummary?['totalEntries'] ?? 0}',
                        Icons.report_problem_rounded, const Color(0xFF4E342E), cardWidth),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),

            // Low Stock Alerts
            if (lowStockItems.isNotEmpty) ...[              _sectionTitle('Low Stock Alerts', badge: '${lowStockItems.length}', badgeColor: Colors.red),
              const SizedBox(height: 10),
              Card(
                color: Colors.red.shade50,
                child: Column(
                  children: lowStockItems.take(5).map((i) {
                    final stock = (i['currentStock'] as num?)?.toDouble() ?? 0;
                    final par = (i['parLevel'] as num?)?.toDouble() ?? 1;
                    final pct = (stock / par * 100).clamp(0, 100);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: pct < 25 ? Colors.red : Colors.orange,
                        child: Icon(
                          pct < 25 ? Icons.error : Icons.warning_amber,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(i['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: Colors.grey[300],
                              color: pct < 25 ? Colors.red : Colors.orange,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${stock.toStringAsFixed(1)} / ${par.toStringAsFixed(1)} ${i['unit']} (${pct.toStringAsFixed(0)}%)',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // Recent Sales + Recent Waste side by side
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _recentSalesCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _recentWasteCard()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _recentSalesCard(),
                    const SizedBox(height: 16),
                    _recentWasteCard(),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),

            // Inventory Snapshot
            _sectionTitle('Inventory Snapshot'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ingredients.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No ingredients yet.')),
                      )
                    : DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('Ingredient', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Par Level', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: ingredients.take(10).map((i) {
                          final stock = (i['currentStock'] as num?)?.toDouble() ?? 0;
                          final par = (i['parLevel'] as num?)?.toDouble() ?? 1;
                          final pct = stock / par;
                          final Color statusColor;
                          final String statusLabel;
                          if (pct >= 1) {
                            statusColor = Colors.green;
                            statusLabel = 'OK';
                          } else if (pct >= 0.5) {
                            statusColor = Colors.orange;
                            statusLabel = 'Low';
                          } else {
                            statusColor = Colors.red;
                            statusLabel = 'Critical';
                          }
                          return DataRow(cells: [
                            DataCell(Text(i['name'] ?? '')),
                            DataCell(Text(stock.toStringAsFixed(1))),
                            DataCell(Text(par.toStringAsFixed(1))),
                            DataCell(Text(i['unit'] ?? '')),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(statusLabel,
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
                            )),
                          ]);
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {String? badge, Color? badgeColor}) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (badgeColor ?? Colors.blue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(badge,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor ?? Colors.blue)),
          ),
        ],
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, double width) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Widget _recentSalesCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recent Sales', badge: '${recentSales.length}', badgeColor: Colors.green),
        const SizedBox(height: 10),
        Card(
          child: recentSales.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No recent sales', style: TextStyle(color: Colors.grey))),
                )
              : Column(
                  children: recentSales.take(5).map((s) {
                    final menu = s['menuItem'];
                    final qty = s['quantitySold'] ?? 0;
                    final price = (menu?['basePrice'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade50,
                        child: Icon(Icons.receipt_long, color: Colors.green.shade700, size: 20),
                      ),
                      title: Text(menu?['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Qty: $qty  •  ${_fmtDate(s['createdAt'] ?? '')}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Text('\$${(qty * price).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _recentWasteCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recent Waste', badge: '${recentWaste.length}', badgeColor: Colors.red),
        const SizedBox(height: 10),
        Card(
          child: recentWaste.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No recent waste', style: TextStyle(color: Colors.grey))),
                )
              : Column(
                  children: recentWaste.take(5).map((w) {
                    final ing = w['ingredient'];
                    final qty = (w['quantity'] as num?)?.toDouble() ?? 0;
                    final cost = qty * ((ing?['unitCost'] as num?)?.toDouble() ?? 0);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade50,
                        child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 20),
                      ),
                      title: Text(ing?['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${w['reason']} • ${qty.toStringAsFixed(1)} ${ing?['unit'] ?? ''}  •  ${_fmtDate(w['createdAt'] ?? '')}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Text('-\$${cost.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

// Menu Management Screen
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().loadMenuItems();
      context.read<MenuProvider>().loadIngredients();
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Menu Items', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showAddMenuItemDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Menu Item'),
              ),
            ],
          ),
        ),
        if (menuProvider.isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: menuProvider.menuItems.isEmpty
                ? const Center(child: Text('No menu items yet. Add your first item!'))
                : ListView.builder(
                    itemCount: menuProvider.menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuProvider.menuItems[index];
                      return MenuItemCard(menuItem: item);
                    },
                  ),
          ),
      ],
    );
  }

  void _showAddMenuItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Menu Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Base Price', prefixText: '\$'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                try {
                  await context.read<MenuProvider>().addMenuItem(
                        nameController.text,
                        double.parse(priceController.text),
                      );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class MenuItemCard extends StatelessWidget {
  final dynamic menuItem;

  const MenuItemCard({required this.menuItem, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.restaurant_menu, color: Colors.blue),
        title: Text(menuItem['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('\$${menuItem['basePrice']?.toStringAsFixed(2) ?? '0.00'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: () => _showEditDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
        children: [
          RecipeManagement(menuItemId: menuItem['id']),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final nameController = TextEditingController(text: menuItem['name']);
    final priceController = TextEditingController(text: menuItem['basePrice'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Menu Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Base Price', prefixText: '\$'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<MenuProvider>().updateMenuItem(
                      menuItem['id'],
                      nameController.text,
                      double.parse(priceController.text),
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: Text('Are you sure you want to delete "${menuItem['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await context.read<MenuProvider>().deleteMenuItem(menuItem['id']);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ========== SALES TRACKING SCREEN ==========

class SalesTrackingScreen extends StatefulWidget {
  const SalesTrackingScreen({super.key});

  @override
  State<SalesTrackingScreen> createState() => _SalesTrackingScreenState();
}

class _SalesTrackingScreenState extends State<SalesTrackingScreen> {
  List<dynamic> sales = [];
  List<dynamic> menuItems = [];
  dynamic salesReport;
  bool isLoading = false;
  int reportDays = 7;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      sales = await ApiService.getSales(days: 30);
      menuItems = await ApiService.getMenuItems();
      salesReport = await ApiService.getSalesReport(days: reportDays);
    } catch (e) {
      debugPrint('Error loading sales data: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> _loadReport() async {
    try {
      salesReport = await ApiService.getSalesReport(days: reportDays);
      setState(() {});
    } catch (e) {
      debugPrint('Error loading report: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.point_of_sale, size: 28, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Sales Tracking', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showRecordSaleDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Record Sale'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Report summary
          if (salesReport != null) _buildReportSummary(),
          const SizedBox(height: 16),

          // Period selector
          Row(
            children: [
              const Text('Report period: ', style: TextStyle(fontWeight: FontWeight.bold)),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Today')),
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                ],
                selected: {reportDays},
                onSelectionChanged: (val) {
                  setState(() => reportDays = val.first);
                  _loadReport();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sales table
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green[700],
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Menu Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Qty Sold', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Revenue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: sales.isEmpty
                  ? const Center(child: Text('No sales recorded yet'))
                  : ListView.builder(
                      itemCount: sales.length,
                      itemBuilder: (context, index) {
                        final sale = sales[index];
                        final menuItem = sale['menuItem'];
                        final qty = sale['quantitySold'] ?? 0;
                        final price = (menuItem?['basePrice'] as num?)?.toDouble() ?? 0;
                        final date = sale['createdAt'] ?? '';
                        final bgColor = index.isEven ? Colors.white : Colors.grey[50];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: bgColor,
                            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(menuItem?['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500))),
                              Expanded(flex: 1, child: Text('$qty')),
                              Expanded(flex: 1, child: Text('\$${(qty * price).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green))),
                              Expanded(flex: 2, child: Text(_formatDate(date), style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportSummary() {
    final summary = salesReport['summary'] as List<dynamic>? ?? [];
    double totalRevenue = 0;
    int totalQty = 0;
    for (final s in summary) {
      totalRevenue += (s['revenue'] as num?)?.toDouble() ?? 0;
      totalQty += (s['quantity'] as num?)?.toInt() ?? 0;
    }

    return Row(
      children: [
        _reportCard('Total Sales', '${salesReport['totalSales'] ?? 0}', Icons.receipt, Colors.blue),
        const SizedBox(width: 12),
        _reportCard('Items Sold', '$totalQty', Icons.shopping_bag, Colors.orange),
        const SizedBox(width: 12),
        _reportCard('Total Revenue', '\$${totalRevenue.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
        const SizedBox(width: 12),
        _reportCard('Top Items', '${summary.length}', Icons.star, Colors.purple),
      ],
    );
  }

  Widget _reportCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  void _showRecordSaleDialog() {
    int? selectedMenuItemId;
    final qtyController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Sale'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Menu Item', border: OutlineInputBorder()),
                items: menuItems
                    .map((item) => DropdownMenuItem<int>(
                          value: item['id'],
                          child: Text('${item['name']} (\$${item['basePrice']?.toStringAsFixed(2)})'),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() => selectedMenuItemId = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'Quantity Sold', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (selectedMenuItemId == null || qtyController.text.isEmpty) return;
              try {
                final result = await ApiService.recordSale(
                  selectedMenuItemId!,
                  int.parse(qtyController.text),
                );
                await _loadData();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Sale recorded!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Record Sale'),
          ),
        ],
      ),
    );
  }
}

// ========== WASTE TRACKING SCREEN ==========

class WasteTrackingScreen extends StatefulWidget {
  const WasteTrackingScreen({super.key});

  @override
  State<WasteTrackingScreen> createState() => _WasteTrackingScreenState();
}

class _WasteTrackingScreenState extends State<WasteTrackingScreen> {
  List<dynamic> wasteLogs = [];
  List<dynamic> ingredients = [];
  dynamic wasteSummary;
  bool isLoading = false;

  static const List<String> wasteReasons = [
    'Expired',
    'Spilled',
    'Prep Waste',
    'Damaged',
    'Overcooked',
    'Contaminated',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      wasteLogs = await ApiService.getWasteLogs(days: 30);
      ingredients = await ApiService.getIngredients();
      wasteSummary = await ApiService.getWasteSummary(days: 30);
    } catch (e) {
      debugPrint('Error loading waste data: $e');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.delete_sweep, size: 28, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Waste Tracking', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showLogWasteDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Log Waste'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary cards
          if (wasteSummary != null) _buildWasteSummaryCards(),
          const SizedBox(height: 16),

          // Waste by reason
          if (wasteSummary != null && (wasteSummary['byReason'] as List?)?.isNotEmpty == true) ...[
            const Text('Waste by Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ((wasteSummary['byReason'] as List?) ?? []).map((r) {
                return Chip(
                  avatar: const Icon(Icons.warning_amber, size: 16),
                  label: Text('${r['reason']}: ${r['totalEntries']} entries'),
                  backgroundColor: Colors.orange[50],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Waste log table
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red[700],
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Ingredient', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Quantity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Reason', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Est. Cost', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: wasteLogs.isEmpty
                  ? const Center(child: Text('No waste logged yet'))
                  : ListView.builder(
                      itemCount: wasteLogs.length,
                      itemBuilder: (context, index) {
                        final log = wasteLogs[index];
                        final ingredient = log['ingredient'];
                        final qty = (log['quantity'] as num?)?.toDouble() ?? 0;
                        final unitCost = (ingredient?['unitCost'] as num?)?.toDouble() ?? 0;
                        final bgColor = index.isEven ? Colors.white : Colors.grey[50];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: bgColor,
                            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(ingredient?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                              Expanded(flex: 1, child: Text('${qty.toStringAsFixed(1)} ${ingredient?['unit'] ?? ''}')),
                              Expanded(flex: 1, child: Chip(
                                label: Text(log['reason'] ?? '', style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              )),
                              Expanded(flex: 1, child: Text('\$${(qty * unitCost).toStringAsFixed(2)}', style: const TextStyle(color: Colors.red))),
                              Expanded(flex: 2, child: Text(_formatDate(log['createdAt'] ?? ''), style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildWasteSummaryCards() {
    final totalEntries = wasteSummary['totalEntries'] ?? 0;
    final byIngredient = (wasteSummary['byIngredient'] as List?) ?? [];
    double totalCost = 0;
    for (final i in byIngredient) {
      totalCost += (i['totalCost'] as num?)?.toDouble() ?? 0;
    }

    return Row(
      children: [
        _wasteCard('Total Waste Entries', '$totalEntries', Icons.list_alt, Colors.red),
        const SizedBox(width: 12),
        _wasteCard('Ingredients Affected', '${byIngredient.length}', Icons.category, Colors.orange),
        const SizedBox(width: 12),
        _wasteCard('Total Waste Cost', '\$${totalCost.toStringAsFixed(2)}', Icons.money_off, Colors.red[800]!),
      ],
    );
  }

  Widget _wasteCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  void _showLogWasteDialog() {
    int? selectedIngredientId;
    final qtyController = TextEditingController();
    String selectedReason = wasteReasons.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Waste'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Ingredient', border: OutlineInputBorder()),
                items: ingredients
                    .map((ing) => DropdownMenuItem<int>(
                          value: ing['id'],
                          child: Text('${ing['name']} (${ing['unit']}) — Stock: ${(ing['currentStock'] as num?)?.toStringAsFixed(1)}'),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() => selectedIngredientId = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'Quantity Wasted', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
                value: selectedReason,
                items: wasteReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (value) => setDialogState(() => selectedReason = value ?? wasteReasons.first),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (selectedIngredientId == null || qtyController.text.isEmpty) return;
              try {
                await ApiService.logWaste(
                  selectedIngredientId!,
                  double.parse(qtyController.text),
                  selectedReason,
                );
                await _loadData();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Waste logged & stock deducted'), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Log Waste'),
          ),
        ],
      ),
    );
  }
}

// ========== STOCK DEDUCTION SCREEN ==========

class StockDeductionScreen extends StatefulWidget {
  const StockDeductionScreen({super.key});

  @override
  State<StockDeductionScreen> createState() => _StockDeductionScreenState();
}

class _StockDeductionScreenState extends State<StockDeductionScreen> {
  List<dynamic> menuItems = [];
  int? selectedMenuItemId;
  dynamic deductionData;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _loadMenuItems() async {
    try {
      menuItems = await ApiService.getMenuItems();
      setState(() {});
    } catch (e) {
      debugPrint('Error loading menu items: $e');
    }
  }

  Future<void> _loadDeductions(int menuItemId) async {
    setState(() => isLoading = true);
    try {
      deductionData = await ApiService.getStockDeductions(menuItemId);
    } catch (e) {
      debugPrint('Error loading deductions: $e');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.calculate, size: 28, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text('Stock Deduction Calculator', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: () {
                _loadMenuItems();
                if (selectedMenuItemId != null) _loadDeductions(selectedMenuItemId!);
              }),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Formula: ActualDeduction = quantityRequired / yieldFactor',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),

          // Menu item selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Menu Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Choose a menu item to see deduction breakdown',
                    ),
                    value: selectedMenuItemId,
                    items: menuItems
                        .map((item) => DropdownMenuItem<int>(
                              value: item['id'],
                              child: Text('${item['name']} (\$${item['basePrice']?.toStringAsFixed(2)})'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedMenuItemId = value);
                      if (value != null) _loadDeductions(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (selectedMenuItemId == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calculate, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Select a menu item to view stock deduction details', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            )
          else if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (deductionData != null) ...[
            // Summary cards
            _buildDeductionSummary(),
            const SizedBox(height: 16),

            // Deduction table
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.indigo[700],
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Ingredient', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Yield', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Actual Deduction', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Can Make', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Cost/Unit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: (deductionData['deductions'] as List?)?.length ?? 0,
                itemBuilder: (context, index) {
                  final d = (deductionData['deductions'] as List)[index];
                  final bgColor = index.isEven ? Colors.white : Colors.grey[50];
                  final canMake = d['canMake'] ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(d['ingredient'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                        Expanded(flex: 1, child: Text('${d['quantityRequired']} ${d['unit']}')),
                        Expanded(flex: 1, child: Text('${d['yieldFactor']}')),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${d['actualDeduction']} ${d['unit']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${(d['currentStock'] as num?)?.toStringAsFixed(1)}',
                            style: TextStyle(color: canMake < 5 ? Colors.red : Colors.black),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: canMake < 5 ? Colors.red[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$canMake',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: canMake < 5 ? Colors.red : Colors.green,
                              ),
                            ),
                          ),
                        ),
                        Expanded(flex: 1, child: Text('\$${d['costPerUnit']}')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeductionSummary() {
    final maxServings = deductionData['maxServings'] ?? 0;
    final totalCost = deductionData['totalIngredientCost'] ?? 0;
    final basePrice = (deductionData['basePrice'] as num?)?.toDouble() ?? 0;
    final margin = basePrice > 0 ? ((basePrice - totalCost) / basePrice * 100) : 0;

    return Row(
      children: [
        _deductionCard('Menu Item', deductionData['menuItem'] ?? '', Icons.restaurant_menu, Colors.blue),
        const SizedBox(width: 12),
        _deductionCard('Max Servings', '$maxServings', Icons.production_quantity_limits,
            maxServings < 10 ? Colors.red : Colors.green),
        const SizedBox(width: 12),
        _deductionCard('Ingredient Cost', '\$${totalCost.toStringAsFixed(2)}', Icons.attach_money, Colors.orange),
        const SizedBox(width: 12),
        _deductionCard('Profit Margin', '${margin.toStringAsFixed(1)}%', Icons.trending_up,
            margin > 60 ? Colors.green : Colors.orange),
      ],
    );
  }

  Widget _deductionCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// Recipe Management Widget
class RecipeManagement extends StatefulWidget {
  final int menuItemId;

  const RecipeManagement({required this.menuItemId, super.key});

  @override
  State<RecipeManagement> createState() => _RecipeManagementState();
}

class _RecipeManagementState extends State<RecipeManagement> {
  List<dynamic> recipes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() => isLoading = true);
    try {
      recipes = await ApiService.getRecipeItems(widget.menuItemId);
    } catch (e) {
      debugPrint('Error loading recipes: $e');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recipe Ingredients', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () => _showAddRecipeDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Ingredient'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (recipes.isEmpty)
            const Text('No ingredients in this recipe yet.')
          else
            ...recipes.map((recipe) => RecipeItemTile(
                  recipe: recipe,
                  onDelete: () async {
                    await ApiService.deleteRecipeItem(recipe['id']);
                    _loadRecipes();
                  },
                )),
        ],
      ),
    );
  }

  void _showAddRecipeDialog(BuildContext context) {
    final menuProvider = context.read<MenuProvider>();
    int? selectedIngredientId;
    final quantityController = TextEditingController();
    final yieldController = TextEditingController(text: '1.0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Recipe Ingredient'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Ingredient'),
                items: menuProvider.ingredients
                    .map((ing) => DropdownMenuItem<int>(
                          value: ing['id'],
                          child: Text('${ing['name']} (${ing['unit']})'),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedIngredientId = value);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity Required'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: yieldController,
                decoration: const InputDecoration(
                  labelText: 'Yield Factor',
                  helperText: '1.0 = no waste, 1.1 = 10% waste',
                ),
                keyboardType: TextInputType.number,
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
            onPressed: () async {
              if (selectedIngredientId != null && quantityController.text.isNotEmpty) {
                try {
                  await ApiService.addRecipeItem(
                    widget.menuItemId,
                    selectedIngredientId!,
                    double.parse(quantityController.text),
                    double.parse(yieldController.text),
                  );
                  _loadRecipes();
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class RecipeItemTile extends StatelessWidget {
  final dynamic recipe;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const RecipeItemTile({required this.recipe, required this.onDelete, this.onEdit, super.key});

  @override
  Widget build(BuildContext context) {
    final ingredient = recipe['ingredient'];
    final quantity = recipe['quantityRequired'];
    final yieldFactor = recipe['yieldFactor'];
    final actualDeduction = quantity / yieldFactor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.food_bank, size: 20),
        title: Text(ingredient?['name'] ?? 'Unknown Ingredient'),
        subtitle: Text(
          'Qty: $quantity ${ingredient?['unit'] ?? ''} | Yield: $yieldFactor\n'
          'Actual deduction: ${actualDeduction.toStringAsFixed(2)} ${ingredient?['unit'] ?? ''}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.orange),
                onPressed: onEdit,
              ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ========== DEDICATED RECIPE MANAGEMENT SCREEN ==========

class RecipeManagementScreen extends StatefulWidget {
  const RecipeManagementScreen({super.key});

  @override
  State<RecipeManagementScreen> createState() => _RecipeManagementScreenState();
}

class _RecipeManagementScreenState extends State<RecipeManagementScreen> {
  List<dynamic> menuItems = [];
  List<dynamic> ingredients = [];
  int? selectedMenuItemId;
  List<dynamic> recipes = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      menuItems = await ApiService.getMenuItems();
      ingredients = await ApiService.getIngredients();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> _loadRecipesForItem(int menuItemId) async {
    setState(() => isLoading = true);
    try {
      recipes = await ApiService.getRecipeItems(menuItemId);
    } catch (e) {
      debugPrint('Error loading recipes: $e');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 28, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Recipe Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _loadData();
                  if (selectedMenuItemId != null) _loadRecipesForItem(selectedMenuItemId!);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Menu item selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Menu Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Choose a menu item to manage its recipe',
                    ),
                    value: selectedMenuItemId,
                    items: menuItems
                        .map((item) => DropdownMenuItem<int>(
                              value: item['id'],
                              child: Text('${item['name']} (\$${item['basePrice']?.toStringAsFixed(2)})'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedMenuItemId = value);
                      if (value != null) _loadRecipesForItem(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recipe content
          if (selectedMenuItemId == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_upward, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Select a menu item above to manage its recipe',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            )
          else ...[  
            // Recipe header with add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recipe for: ${_getMenuItemName(selectedMenuItemId!)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddIngredientDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Ingredient'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Cost summary
            if (recipes.isNotEmpty) _buildCostSummary(),
            const SizedBox(height: 8),

            // Recipe items list
            if (isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: recipes.isEmpty
                    ? const Center(child: Text('No ingredients added yet. Click "Add Ingredient" to start building the recipe.'))
                    : ListView.builder(
                        itemCount: recipes.length,
                        itemBuilder: (context, index) {
                          final recipe = recipes[index];
                          return RecipeItemTile(
                            recipe: recipe,
                            onEdit: () => _showEditRecipeDialog(recipe),
                            onDelete: () => _confirmDeleteRecipe(recipe),
                          );
                        },
                      ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostSummary() {
    double totalCost = 0;
    for (final recipe in recipes) {
      final qty = (recipe['quantityRequired'] as num).toDouble();
      final yf = (recipe['yieldFactor'] as num).toDouble();
      final unitCost = (recipe['ingredient']?['unitCost'] as num?)?.toDouble() ?? 0;
      totalCost += (qty / yf) * unitCost;
    }

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.calculate, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Ingredients: ${recipes.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 24),
            Text('Estimated ingredient cost: \$${totalCost.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
      ),
    );
  }

  String _getMenuItemName(int id) {
    final item = menuItems.firstWhere((m) => m['id'] == id, orElse: () => null);
    return item?['name'] ?? 'Unknown';
  }

  void _showAddIngredientDialog() {
    int? selectedIngredientId;
    final quantityController = TextEditingController();
    final yieldController = TextEditingController(text: '1.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Ingredient to Recipe'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Ingredient',
                  border: OutlineInputBorder(),
                ),
                items: ingredients
                    .map((ing) => DropdownMenuItem<int>(
                          value: ing['id'],
                          child: Text('${ing['name']} (${ing['unit']}) - \$${ing['unitCost']}/unit'),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() => selectedIngredientId = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity Required',
                  border: OutlineInputBorder(),
                  helperText: 'Amount needed per serving',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: yieldController,
                decoration: const InputDecoration(
                  labelText: 'Yield Factor',
                  border: OutlineInputBorder(),
                  helperText: '1.0 = no waste, 1.1 = 10% waste, 1.2 = 20% waste',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (selectedIngredientId != null && quantityController.text.isNotEmpty) {
                try {
                  await ApiService.addRecipeItem(
                    selectedMenuItemId!,
                    selectedIngredientId!,
                    double.parse(quantityController.text),
                    double.parse(yieldController.text),
                  );
                  await _loadRecipesForItem(selectedMenuItemId!);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingredient added to recipe!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditRecipeDialog(dynamic recipe) {
    final quantityController = TextEditingController(text: recipe['quantityRequired'].toString());
    final yieldController = TextEditingController(text: recipe['yieldFactor'].toString());
    final ingredientName = recipe['ingredient']?['name'] ?? 'Unknown';
    final unit = recipe['ingredient']?['unit'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit: $ingredientName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ingredient: $ingredientName ($unit)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity Required ($unit)',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: yieldController,
              decoration: const InputDecoration(
                labelText: 'Yield Factor',
                border: const OutlineInputBorder(),
                helperText: '1.0 = no waste, 1.1 = 10% waste',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.updateRecipeItem(
                  recipe['id'],
                  double.parse(quantityController.text),
                  double.parse(yieldController.text),
                );
                await _loadRecipesForItem(selectedMenuItemId!);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recipe updated!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRecipe(dynamic recipe) {
    final ingredientName = recipe['ingredient']?['name'] ?? 'Unknown';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Ingredient'),
        content: Text('Remove "$ingredientName" from this recipe?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ApiService.deleteRecipeItem(recipe['id']);
                await _loadRecipesForItem(selectedMenuItemId!);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingredient removed from recipe'), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ========== INGREDIENT MANAGEMENT SCREEN ==========

class IngredientManagementScreen extends StatefulWidget {
  const IngredientManagementScreen({super.key});

  @override
  State<IngredientManagementScreen> createState() => _IngredientManagementScreenState();
}

class _IngredientManagementScreenState extends State<IngredientManagementScreen> {
  List<dynamic> ingredients = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    setState(() => isLoading = true);
    try {
      ingredients = await ApiService.getIngredients();
    } catch (e) {
      debugPrint('Error loading ingredients: $e');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.inventory_2, size: 28, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Ingredient Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadIngredients),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddIngredientDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Ingredient'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary cards
          if (ingredients.isNotEmpty) _buildSummaryCards(),
          const SizedBox(height: 16),

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Unit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Par Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Unit Cost', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                SizedBox(width: 96, child: Text('Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // Ingredient list
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ingredients.isEmpty
                  ? const Center(child: Text('No ingredients yet. Add your first ingredient!'))
                  : ListView.builder(
                      itemCount: ingredients.length,
                      itemBuilder: (context, index) {
                        final ing = ingredients[index];
                        return _buildIngredientRow(ing, index);
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalItems = ingredients.length;
    final lowStock = ingredients.where((i) {
      final stock = (i['currentStock'] as num?)?.toDouble() ?? 0;
      final par = (i['parLevel'] as num?)?.toDouble() ?? 0;
      return stock < par;
    }).length;
    double totalValue = 0;
    for (final i in ingredients) {
      final stock = (i['currentStock'] as num?)?.toDouble() ?? 0;
      final cost = (i['unitCost'] as num?)?.toDouble() ?? 0;
      totalValue += stock * cost;
    }

    return Row(
      children: [
        _summaryCard('Total Ingredients', '$totalItems', Icons.category, Colors.blue),
        const SizedBox(width: 12),
        _summaryCard('Low Stock Alerts', '$lowStock', Icons.warning, lowStock > 0 ? Colors.red : Colors.green),
        const SizedBox(width: 12),
        _summaryCard('Total Inventory Value', '\$${totalValue.toStringAsFixed(2)}', Icons.attach_money, Colors.teal),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientRow(dynamic ing, int index) {
    final stock = (ing['currentStock'] as num?)?.toDouble() ?? 0;
    final par = (ing['parLevel'] as num?)?.toDouble() ?? 0;
    final isLow = stock < par;
    final bgColor = index.isEven ? Colors.white : Colors.grey[50];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(ing['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(flex: 1, child: Text(ing['unit'] ?? '')),
          Expanded(
            flex: 1,
            child: Text(
              stock.toStringAsFixed(1),
              style: TextStyle(color: isLow ? Colors.red : Colors.black),
            ),
          ),
          Expanded(flex: 1, child: Text(par.toStringAsFixed(1))),
          Expanded(flex: 1, child: Text('\$${(ing['unitCost'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLow ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isLow ? 'LOW STOCK' : 'OK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isLow ? Colors.red : Colors.green,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.orange),
                  onPressed: () => _showEditIngredientDialog(ing),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _confirmDeleteIngredient(ing),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddIngredientDialog() {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final parCtrl = TextEditingController(text: '0');
    final costCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Ingredient'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                  helperText: 'e.g. grams, ml, pieces, kg',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      decoration: const InputDecoration(labelText: 'Current Stock', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: parCtrl,
                      decoration: const InputDecoration(labelText: 'Par Level', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                decoration: const InputDecoration(labelText: 'Unit Cost (\$)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || unitCtrl.text.isEmpty) return;
              try {
                await ApiService.createIngredient(
                  nameCtrl.text,
                  unitCtrl.text,
                  double.tryParse(stockCtrl.text) ?? 0,
                  double.tryParse(parCtrl.text) ?? 0,
                  double.tryParse(costCtrl.text) ?? 0,
                );
                await _loadIngredients();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingredient added!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditIngredientDialog(dynamic ing) {
    final nameCtrl = TextEditingController(text: ing['name']);
    final unitCtrl = TextEditingController(text: ing['unit']);
    final stockCtrl = TextEditingController(text: (ing['currentStock'] as num?)?.toString() ?? '0');
    final parCtrl = TextEditingController(text: (ing['parLevel'] as num?)?.toString() ?? '0');
    final costCtrl = TextEditingController(text: (ing['unitCost'] as num?)?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit: ${ing['name']}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      decoration: const InputDecoration(labelText: 'Current Stock', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: parCtrl,
                      decoration: const InputDecoration(labelText: 'Par Level', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                decoration: const InputDecoration(labelText: 'Unit Cost (\$)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.updateIngredient(
                  ing['id'],
                  name: nameCtrl.text,
                  unit: unitCtrl.text,
                  currentStock: double.tryParse(stockCtrl.text),
                  parLevel: double.tryParse(parCtrl.text),
                  unitCost: double.tryParse(costCtrl.text),
                );
                await _loadIngredients();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingredient updated!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteIngredient(dynamic ing) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ingredient'),
        content: Text('Are you sure you want to delete "${ing['name']}"?\n\nThis will also remove it from any recipes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ApiService.deleteIngredient(ing['id']);
                await _loadIngredients();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingredient deleted'), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}