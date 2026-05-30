import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';

final marketplaceFeedProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(zeroPayRepositoryProvider);
  return await repo.getMarketplaceFeed();
});

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Services', 'Coffee', 'Retail', 'Logistics'];

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(marketplaceFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            _buildSearchHeader(),

            // Marketplace Canvas
            Expanded(
              child: feedAsync.when(
                loading: () => const SafeArea(child: LoadingStateView()),
                error: (err, stack) => ErrorStateView(
                  title: 'Error loading marketplace',
                  description: err.toString(),
                  onRetry: () => ref.invalidate(marketplaceFeedProvider),
                  retryButtonText: 'Try Loading Again',
                ),
                data: (feedData) {
                  final merchantsList = feedData['merchants'] ?? feedData['data']?['merchants'] as List? ?? [];
                  final parsedMerchants = merchantsList.map((m) {
                    final logo = m['profileImageUrl'] as String? ?? '';
                    final name = m['shopName'] as String? ?? 'Unnamed Merchant';
                    return MockMerchantItem(
                      id: (m['slug'] as String?) ?? (m['merchantId'] as String?) ?? '',
                      name: name,
                      tagline: m['description'] as String? ?? 'No description available.',
                      category: m['category'] as String? ?? 'Services',
                      tier: m['reliabilityTier'] as String? ?? 'Gold',
                      trustScore: (m['reputationScore'] as num? ?? 95.0).toDouble(),
                      successRate: 100.0,
                      disputesCount: 0,
                      logoUrl: logo.isNotEmpty && logo.length <= 3 ? logo : (name.length > 2 ? name.substring(0, 2) : name),
                      bannerUrl: m['bannerImageUrl'] as String? ?? 'https://images.unsplash.com/photo-1556740749-887f6717d7e4?auto=format&fit=crop&q=80&w=1000',
                    );
                  }).toList();

                  final filteredMerchants = parsedMerchants.where((item) {
                    final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        item.tagline.toLowerCase().contains(_searchQuery.toLowerCase());
                    final matchesCategory = _selectedCategory == 'All' || item.category.toLowerCase() == _selectedCategory.toLowerCase();
                    return matchesSearch && matchesCategory;
                  }).toList();

                  final featured = filteredMerchants.isNotEmpty ? filteredMerchants.first : null;

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                      // Categories chips
                      _buildCategoriesSection(),
                      const SizedBox(height: 20),

                      // Featured / Recommended slider
                      if (featured != null) ...[
                        _buildFeaturedMerchantSection(featured),
                        const SizedBox(height: 24),
                      ],

                      // Merchant Discovery Grid Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Verified Merchants',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                          ),
                          Text(
                            '${filteredMerchants.length} found',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Merchant Items Grid List
                      if (filteredMerchants.isEmpty)
                        _buildEmptySearchResult()
                      else
                        ...filteredMerchants.map((merchant) => _buildMerchantCard(merchant)),

                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search services, coffee, software...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter Button Trigger
          GestureDetector(
            onTap: _showFiltersBottomSheet,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: const Icon(Icons.tune, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedCategory = cat;
                  });
                }
              },
              selectedColor: AppColors.primary.withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeaturedMerchantSection(MockMerchantItem featured) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured Merchant',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
        ),
        const SizedBox(height: 12),
        BentoCard(
          onTap: () => context.push('/customer/marketplace/merchant/${featured.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  featured.bannerUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary,
                      child: Text(featured.logoUrl, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                featured.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: AppColors.tertiary, size: 16),
                            ],
                          ),
                          Text(
                            featured.tagline,
                            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${featured.trustScore}%',
                            style: const TextStyle(
                              color: AppColors.tertiary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantCard(MockMerchantItem merchant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        onTap: () => context.push('/customer/marketplace/merchant/${merchant.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.secondary,
              child: Text(
                merchant.logoUrl,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        merchant.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: AppColors.tertiary, size: 14),
                      const Spacer(),
                      Text(
                        merchant.tier,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: merchant.tier == 'Platinum' ? Colors.purple : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    merchant.tagline,
                    style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Reputation Indicators row
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 4.0,
                    children: [
                      _buildReputationPill(Icons.shield_outlined, '${merchant.trustScore}% Trust', AppColors.primary),
                      _buildReputationPill(Icons.check_circle_outline, '${merchant.successRate}% Success', AppColors.tertiary),
                      _buildReputationPill(Icons.gavel, '${merchant.disputesCount} Disputes', AppColors.error),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReputationPill(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildEmptySearchResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.outline),
            const SizedBox(height: 16),
            Text(
              'No Merchants Found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search filters or select another category.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Reset Marketplace Filters',
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'All';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Filter Merchants',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text('Minimum Trust Score', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['Any', '> 90%', '> 95%', '> 98%'].map((val) {
                  return ChoiceChip(
                    label: Text(val),
                    selected: val == 'Any',
                    onSelected: (selected) {},
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text('Blockchain Ledger Network', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['All', 'Cardano', 'Ethereum', 'Arbitrum'].map((val) {
                  return ChoiceChip(
                    label: Text(val),
                    selected: val == 'All',
                    onSelected: (selected) {},
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: 'Apply Filters',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MockMerchantItem {
  final String id;
  final String name;
  final String tagline;
  final String category;
  final String tier;
  final double trustScore;
  final double successRate;
  final int disputesCount;
  final String logoUrl;
  final String bannerUrl;

  MockMerchantItem({
    required this.id,
    required this.name,
    required this.tagline,
    required this.category,
    required this.tier,
    required this.trustScore,
    required this.successRate,
    required this.disputesCount,
    required this.logoUrl,
    required this.bannerUrl,
  });
}
