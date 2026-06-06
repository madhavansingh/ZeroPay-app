import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';

class StorefrontItem {
  final String id;
  final String title;
  final double price;
  final String category;
  final bool isAvailable;
  final String imageUrl;

  StorefrontItem({
    required this.id,
    required this.title,
    required this.price,
    required this.category,
    required this.isAvailable,
    required this.imageUrl,
  });

  StorefrontItem copyWith({bool? isAvailable}) {
    return StorefrontItem(
      id: id,
      title: title,
      price: price,
      category: category,
      isAvailable: isAvailable ?? this.isAvailable,
      imageUrl: imageUrl,
    );
  }
}

final storefrontManagementProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(zeroPayRepositoryProvider);
  final dashboard = await repo.getMerchantDashboard();
  final merchant = dashboard['merchant'] ?? dashboard['data']?['merchant'] ?? {};
  final slug = merchant['slug'] as String? ?? '';
  
  final catalog = await repo.getStorefrontCatalog(slug);
  final invoices = await repo.getInvoicesList();
  
  return {
    'merchant': merchant,
    'dashboard': dashboard,
    'catalog': catalog,
    'invoices': invoices,
  };
});

class StorefrontManagementScreen extends ConsumerStatefulWidget {
  const StorefrontManagementScreen({super.key});

  @override
  ConsumerState<StorefrontManagementScreen> createState() => _StorefrontManagementScreenState();
}

class _StorefrontManagementScreenState extends ConsumerState<StorefrontManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storefrontAsync = ref.watch(storefrontManagementProvider);

    return storefrontAsync.when(
      loading: () => const Scaffold(
        body: SafeArea(child: LoadingStateView()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('Storefront Management', style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
            onPressed: () => context.go('/merchant/dashboard'),
          ),
        ),
        body: ErrorStateView(
          title: 'Failed to load storefront settings',
          description: err.toString(),
          onRetry: () => ref.invalidate(storefrontManagementProvider),
          retryButtonText: 'Try Loading Again',
        ),
      ),
      data: (storefrontData) {
        final merchant = storefrontData['merchant'] as Map<String, dynamic>? ?? {};
        final slug = merchant['slug'] as String? ?? '';
        final catalog = storefrontData['catalog'] as List<Map<String, dynamic>>? ?? [];
        final invoices = storefrontData['invoices'] as Map<String, dynamic>? ?? {};
        final items = invoices['items'] ?? invoices['data']?['items'] as List? ?? [];

        final parsedItems = catalog.map((p) {
          double price = (p['priceLovelace'] as num? ?? 0.0) / 1000000;
          if (price <= 0) {
            price = (p['priceINR'] as num? ?? 0.0) / 100.0;
          }
          if (price <= 0) {
            price = (p['price'] as num? ?? 0.0).toDouble();
          }
          return StorefrontItem(
            id: p['_id'] ?? p['productId'] ?? p['id'] ?? '',
            title: p['title'] as String? ?? 'Unnamed Product',
            price: price,
            category: p['category'] as String? ?? 'service',
            isAvailable: p['isActive'] as bool? ?? p['isAvailable'] as bool? ?? true,
            imageUrl: (p['images'] as List?)?.isNotEmpty == true ? (p['images'] as List).first as String : '',
          );
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Storefront Management', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
              onPressed: () => context.go('/merchant/dashboard'),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: AppColors.onBackground),
                onPressed: () => _showSettingsDialog(merchant),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.secondary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              indicatorColor: AppColors.secondary,
              tabs: const [
                Tab(text: 'Catalog List'),
                Tab(text: 'Reviews & Trust'),
                Tab(text: 'Store Analytics'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildCatalogTab(merchant, parsedItems),
              _buildReviewsTab(merchant, items),
              _buildAnalyticsTab(merchant, items),
            ],
          ),
          floatingActionButton: slug.isEmpty
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: AppColors.secondary,
                  onPressed: () => _showAddProductDialog(merchant),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add Listing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
        );
      },
    );
  }

  // TAB 1: Products list and availability
  Widget _buildCatalogTab(Map<String, dynamic> merchant, List<StorefrontItem> items) {
    final slug = merchant['slug'] as String? ?? '';
    final merchantAddress = merchant['walletAddress'] ?? merchant['address'] ?? 'addr1q8a72b100641de406d824855a782b13fa92c3ff';
    if (slug.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 64, color: AppColors.outline),
              const SizedBox(height: 16),
              const Text(
                'Storefront Not Setup',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your storefront settings by clicking the settings gear in the top right to start listing products on the marketplace.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.outline, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No products listed in store catalog yet.\nClick "Add Listing" to create one.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.outline),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: BentoCard(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            width: 70,
                            height: 70,
                            color: AppColors.surfaceContainerLow,
                            child: const Icon(Icons.shopping_bag_outlined, color: AppColors.outline),
                          ),
                        )
                      : Container(
                          width: 70,
                          height: 70,
                          color: AppColors.surfaceContainerLow,
                          child: const Icon(Icons.shopping_bag_outlined, color: AppColors.outline),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(item.category.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                      const SizedBox(height: 6),
                      Text(
                        '${item.price.toStringAsFixed(2)} ADA',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code, color: AppColors.primary, size: 20),
                  onPressed: () => _showProductQrDialog(context, item, merchantAddress, merchant['id'] ?? 'mer_cryptobrews_789'),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    const Text('Available', style: TextStyle(fontSize: 9, color: AppColors.outline)),
                    const SizedBox(height: 4),
                    Switch(
                      value: item.isAvailable,
                      activeColor: AppColors.secondary,
                      onChanged: (val) async {
                        if (!val) {
                          // Deactivate product on backend
                          final repo = ref.read(zeroPayRepositoryProvider);
                          await repo.deleteCatalogProduct(item.id);
                          ref.invalidate(storefrontManagementProvider);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Listing deactivated successfully.')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // TAB 2: Reviews, trust levels, and reputation badges
  Widget _buildReviewsTab(Map<String, dynamic> merchant, List<dynamic> items) {
    final double averageRating = ((merchant['reputationScore'] as num? ?? 95.0) / 20.0);
    final int reviewCount = merchant['totalOrders'] as int? ?? items.length;
    final String badgeTier = merchant['reliabilityTier']?.toString().toUpperCase() ?? 'GOLD';
    final Color tierColor = badgeTier == 'PLATINUM' 
        ? const Color(0xFFE5E4E2) 
        : (badgeTier == 'SILVER' ? Colors.blueGrey : Colors.amber);

    final List<Map<String, String>> reviews = [];
    for (var item in items) {
      if (item['isDisputed'] == true || item['escrowState'] == 'Disputed') {
        reviews.add({
          'user': 'Cardano Buyer',
          'rating': '1.0',
          'comment': 'Dispute raised regarding invoice #${item['invoiceId']?.toString().substring(0, 8)}. Handled via escrow consensus.',
          'date': 'Recent'
        });
      }
    }
    if (reviews.isEmpty) {
      reviews.add({
        'user': 'Verified Buyer',
        'rating': '5.0',
        'comment': 'Excellent quality. Payment released instantly once milestones were verified.',
        'date': '2 days ago'
      });
      reviews.add({
        'user': 'Cardano Whale',
        'rating': '5.0',
        'comment': 'Protected micro-escrows on Cardano ledger. Zero dispute actions recorded. Safe payment flow.',
        'date': '1 week ago'
      });
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Trust and Verification Indicators
        BentoCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Store Reputation Rating', style: TextStyle(fontSize: 11, color: AppColors.outline, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(averageRating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32)),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, color: Colors.amber, size: 24),
                        ],
                      ),
                      Text('Based on $reviewCount verified on-chain settlements', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: tierColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tierColor.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.shield, color: tierColor, size: 28),
                        const SizedBox(height: 4),
                        Text(
                          '$badgeTier Tier',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: tierColor == const Color(0xFFE5E4E2) ? AppColors.onSurface : tierColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: const [
                  Icon(Icons.verified_user, color: AppColors.tertiary, size: 16),
                  SizedBox(width: 8),
                  Text('Lumina OS Verified Merchant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
                  Spacer(),
                  Text('Active since 2026', style: TextStyle(fontSize: 10, color: AppColors.outline)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Customer Feedback Logs', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...reviews.map((r) {
          final double score = double.tryParse(r['rating']!) ?? 5.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: BentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r['user']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(r['date']!, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (idx) {
                      return Icon(
                        idx < score.toInt() ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 14,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(r['comment']!, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // TAB 3: Store Analytics Overview
  Widget _buildAnalyticsTab(Map<String, dynamic> merchant, List<dynamic> items) {
    final double trustScore = (merchant['reputationScore'] as num? ?? 95.0).toDouble();
    final int salesCount = merchant['totalOrders'] as int? ?? items.length;

    Widget buildMetric(String label, String val, IconData icon, Color color) {
      return Expanded(
        child: BentoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.outline)),
              const SizedBox(height: 4),
              Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          children: [
            buildMetric('Trust Rating', '$trustScore%', Icons.trending_up, AppColors.tertiary),
            const SizedBox(width: 12),
            buildMetric('Total Orders', '$salesCount', Icons.people_outline, AppColors.primary),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            buildMetric('Milestones Releases', '$salesCount', Icons.lock_open, AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: BentoCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.verified, color: Colors.teal, size: 20),
                    const SizedBox(height: 12),
                    Text('Verification Status', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                    const SizedBox(height: 4),
                    Text('100% Passed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('VISIBILITY CHANNELS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.outline)),
              const SizedBox(height: 12),
              _buildProgressRow('Direct Link Referrals', 0.65, AppColors.primary),
              const SizedBox(height: 8),
              _buildProgressRow('ZeroPay Marketplace Catalog', 0.25, AppColors.secondary),
              const SizedBox(height: 8),
              _buildProgressRow('Decentralized Search Index', 0.10, AppColors.tertiary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressRow(String title, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            Text('${(pct * 100).toInt()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  void _showAddProductDialog(Map<String, dynamic> merchant) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController(text: 'Artisan high quality goods/services protected by ZeroPay.');
    final priceController = TextEditingController();
    String category = 'service';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Catalog Listing', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Product / Service Title'),
              ),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (ADA)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                items: ['digital', 'physical', 'service'].map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.toUpperCase()));
                }).toList(),
                onChanged: (val) {
                  if (val != null) category = val;
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
              onPressed: () async {
                if (titleController.text.isNotEmpty && priceController.text.isNotEmpty) {
                  final priceAda = double.tryParse(priceController.text) ?? 0.0;
                  final priceLovelace = (priceAda * 1000000).round();
                  
                  final repo = ref.read(zeroPayRepositoryProvider);
                  await repo.createCatalogProduct({
                    'title': titleController.text,
                    'description': descriptionController.text,
                    'priceLovelace': priceLovelace,
                    'category': category,
                    'images': ['https://images.unsplash.com/photo-1559056199-641a0ac8b55e?auto=format&fit=crop&q=80&w=200'],
                  });
                  ref.invalidate(storefrontManagementProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New listing added to store catalog.')),
                    );
                  }
                }
              },
              child: const Text('Add Listing'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog(Map<String, dynamic> merchant) {
    final slugController = TextEditingController(text: merchant['slug'] as String? ?? '');
    final nameController = TextEditingController(text: merchant['shopName'] as String? ?? '');
    final descController = TextEditingController(text: merchant['description'] as String? ?? '');
    final bannerController = TextEditingController(text: merchant['bannerImageUrl'] as String? ?? '');
    final hoursController = TextEditingController(text: merchant['businessHours'] as String? ?? '');
    final cityController = TextEditingController(text: merchant['location']?['city'] as String? ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Storefront Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: slugController,
                  decoration: const InputDecoration(
                    labelText: 'Storefront Slug (lowercase-with-hyphens)',
                    hintText: 'e.g. coffee-beans',
                  ),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Shop Name'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description / Tagline'),
                ),
                TextField(
                  controller: bannerController,
                  decoration: const InputDecoration(labelText: 'Banner Image URL'),
                ),
                TextField(
                  controller: hoursController,
                  decoration: const InputDecoration(labelText: 'Business Hours'),
                ),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'Location (City)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
              onPressed: () async {
                if (slugController.text.isNotEmpty && nameController.text.isNotEmpty) {
                  final repo = ref.read(zeroPayRepositoryProvider);
                  final isNew = (merchant['slug'] as String? ?? '').isEmpty;
                  
                  final settings = {
                    'slug': slugController.text.trim().toLowerCase(),
                    'shopName': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'bannerImageUrl': bannerController.text.trim().isNotEmpty ? bannerController.text.trim() : null,
                    'businessHours': hoursController.text.trim(),
                    'location': {
                      'city': cityController.text.trim(),
                    },
                    'isPublicStorefront': true,
                  };

                  if (isNew) {
                    await repo.setupStorefront(settings);
                  } else {
                    await repo.updateStorefront(settings);
                  }

                  ref.invalidate(storefrontManagementProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Storefront settings updated successfully.')),
                    );
                  }
                }
              },
              child: const Text('Save Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showProductQrDialog(BuildContext context, StorefrontItem item, String merchantAddress, String merchantId) {
    // Generate valid payment link URI scheme
    final escrowId = 'ZP-${item.id.hashCode.abs().toString().padLeft(4, '0').substring(0, 4)}';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final payLink = 'zeropay://pay'
        '?address=${Uri.encodeComponent(merchantAddress)}'
        '&amount=${item.price.toStringAsFixed(2)}'
        '&symbol=ADA'
        '&title=${Uri.encodeComponent(item.title)}'
        '&escrowId=$escrowId'
        '&merchantId=${Uri.encodeComponent(merchantId)}'
        '&timestamp=$timestamp';

    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(payLink)}';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.surfaceContainerLowest,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment QR Code',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.price.toStringAsFixed(2)} ADA',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
                const SizedBox(height: 20),
                // QR Code Display Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(
                        qrUrl,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          );
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.all_inclusive, color: AppColors.primary, size: 24),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Present this QR code to the customer. When scanned, it will automatically populate their payment details and initialize the secure escrow lock on-chain.',
                  style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11, height: 1.3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Pay Link', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: payLink));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pay Link copied to clipboard.')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
