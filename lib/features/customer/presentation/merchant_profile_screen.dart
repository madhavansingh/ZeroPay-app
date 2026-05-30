import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/widgets.dart';
import '../../../shared/data/repository.dart';

final merchantProfileProvider = FutureProvider.family.autoDispose<ProfileDetail, String>((ref, slug) async {
  final repo = ref.watch(zeroPayRepositoryProvider);
  final storefront = await repo.getMerchantStorefront(slug);
  final catalog = await repo.getStorefrontCatalog(slug);
  
  final data = storefront['data'] ?? storefront;
  final name = data['shopName'] as String? ?? 'Unnamed Store';
  final logoText = name.length > 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  final tagline = data['description'] as String? ?? 'No description available.';
  final tier = data['reliabilityTier'] as String? ?? 'Standard Tier';
  final bannerUrl = data['bannerImageUrl'] as String? ?? 'https://images.unsplash.com/photo-1556740749-887f6717d7e4?auto=format&fit=crop&q=80&w=1000';
  final double trustScore = (data['reputationScore'] as num? ?? 95.0).toDouble();
  final int healthScore = trustScore.round();
  final String address = data['walletAddress'] as String? ?? 'Unknown address';
  final String email = data['email'] as String? ?? 'contact@zeropay.io';
  
  final hoursStr = data['businessHours'] as String? ?? 'Mon - Fri: 09:00 - 17:00';
  final Map<String, String> hours = {};
  for (var line in hoursStr.split('\n')) {
    final parts = line.split(':');
    if (parts.length >= 2) {
      hours[parts[0].trim()] = parts.sublist(1).join(':').trim();
    }
  }
  if (hours.isEmpty) {
    hours['Mon - Fri'] = '09:00 - 17:00';
    hours['Saturday'] = 'Closed';
    hours['Sunday'] = 'Closed';
  }

  final String aiTrustAnalysis = 'ZeroPay AI Analysis: Verified merchant. Trust score is $trustScore% with tier $tier.';

  final listings = catalog.map((p) {
    final double price = (p['pricePaise'] as num? ?? 0.0) / 100;
    return ListingItem(
      title: p['name'] as String? ?? 'Unnamed Product',
      price: price > 0 ? price : (p['priceLovelace'] as num? ?? 0.0) / 1000000,
      symbol: (p['priceLovelace'] as num? ?? 0) > 0 ? 'ADA' : 'USDC',
    );
  }).toList();

  return ProfileDetail(
    name: name,
    logoText: logoText,
    tagline: tagline,
    tier: tier,
    bannerUrl: bannerUrl,
    healthScore: healthScore,
    trustScore: trustScore,
    escrowVolume: 100,
    disputeCount: 0,
    address: address,
    email: email,
    hours: hours,
    aiTrustAnalysis: aiTrustAnalysis,
    listings: listings,
    reviews: [
      ReviewItem(author: 'Verified Buyer', rating: 5, text: 'Great seller! Transaction was secured via ZeroPay escrow.'),
    ],
  );
});

class MerchantProfileScreen extends ConsumerWidget {
  final String merchantId;
  const MerchantProfileScreen({required this.merchantId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(merchantProfileProvider(merchantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: detailAsync.when(
          data: (detail) => Text(
            detail.name,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          loading: () => const Text('Loading...', style: TextStyle(color: AppColors.onSurface)),
          error: (_, __) => const Text('Error', style: TextStyle(color: AppColors.onSurface)),
        ),
      ),
      body: detailAsync.when(
        loading: () => const SafeArea(child: LoadingStateView()),
        error: (err, stack) => ErrorStateView(
          title: 'Error loading merchant storefront',
          description: err.toString(),
          onRetry: () => ref.invalidate(merchantProfileProvider(merchantId)),
          retryButtonText: 'Try Loading Again',
        ),
        data: (detail) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Store Banner
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.network(
                      detail.bannerUrl,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      bottom: -30,
                      left: 20,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.surfaceContainerLowest, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          detail.logoText,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 38),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Category
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    detail.name,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onSurface,
                                        ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified, color: AppColors.tertiary, size: 20),
                                ],
                              ),
                              Text(
                                detail.tagline,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              detail.tier,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // AI Trust Score & Health Gauge Row
                      _buildTrustDashboard(context, detail),
                      const SizedBox(height: 24),

                      // Store Info (Location & Hours)
                      _buildStoreInfo(context, detail),
                      const SizedBox(height: 24),

                      // Active Listings Catalog
                      _buildActiveListings(context, detail),
                      const SizedBox(height: 24),

                      // Review History Section
                      _buildReviewsSection(context, detail),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrustDashboard(BuildContext context, ProfileDetail detail) {
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome, color: AppColors.secondary, size: 18),
                  SizedBox(width: 6),
                  Text('ZeroPay AI Trust Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Health: ${detail.healthScore}/100',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            detail.aiTrustAnalysis,
            style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          // Health Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: detail.healthScore / 100,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerHigh,
              color: AppColors.tertiary,
            ),
          ),
          const SizedBox(height: 16),
          // Sub Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTrustMetricColumn('Trust Rating', '${detail.trustScore}%'),
              _buildVerticalDivider(),
              _buildTrustMetricColumn('Escrows Completed', '${detail.escrowVolume}+'),
              _buildVerticalDivider(),
              _buildTrustMetricColumn('Disputes Raised', '${detail.disputeCount} total'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustMetricColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.outline),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 28, color: AppColors.outlineVariant.withOpacity(0.4));
  }

  Widget _buildStoreInfo(BuildContext context, ProfileDetail detail) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hours
        Expanded(
          child: BentoCard(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.schedule, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildHoursRow('Mon - Fri', detail.hours['Mon - Fri'] ?? 'Closed'),
                const SizedBox(height: 6),
                _buildHoursRow('Saturday', detail.hours['Saturday'] ?? 'Closed'),
                const SizedBox(height: 6),
                _buildHoursRow('Sunday', detail.hours['Sunday'] ?? 'Closed', isError: true),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Address & Contact
        Expanded(
          child: BentoCard(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.contact_support_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Email',
                  style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant.withOpacity(0.7)),
                ),
                Text(detail.email, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  'Address',
                  style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant.withOpacity(0.7)),
                ),
                Text(detail.address, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHoursRow(String day, String time, {bool isError = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(day, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isError ? AppColors.error : AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveListings(BuildContext context, ProfileDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Listings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Column(
          children: detail.listings.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: BentoCard(
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${item.price} ${item.symbol}',
                            style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    GradientButton(
                      text: 'Pay',
                      onPressed: () {
                        // Pre-populate checkout parameters and navigate to Send Tokens screen
                        // For demo: go to send screen with arguments in query parameters
                        context.go('/customer/wallet/send?address=${detail.address}&amount=${item.price}&symbol=${item.symbol}');
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(BuildContext context, ProfileDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Reviews',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Column(
          children: detail.reviews.map((rev) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rev.author,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Row(
                        children: List.generate(5, (starIdx) {
                          return Icon(
                            Icons.star,
                            size: 12,
                            color: starIdx < rev.rating ? Colors.orange : AppColors.outlineVariant,
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rev.text,
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class ProfileDetail {
  final String name;
  final String logoText;
  final String tagline;
  final String tier;
  final String bannerUrl;
  final int healthScore;
  final double trustScore;
  final int escrowVolume;
  final int disputeCount;
  final String address;
  final String email;
  final Map<String, String> hours;
  final String aiTrustAnalysis;
  final List<ListingItem> listings;
  final List<ReviewItem> reviews;

  ProfileDetail({
    required this.name,
    required this.logoText,
    required this.tagline,
    required this.tier,
    required this.bannerUrl,
    required this.healthScore,
    required this.trustScore,
    required this.escrowVolume,
    required this.disputeCount,
    required this.address,
    required this.email,
    required this.hours,
    required this.aiTrustAnalysis,
    required this.listings,
    required this.reviews,
  });
}

class ListingItem {
  final String title;
  final double price;
  final String symbol;

  ListingItem({required this.title, required this.price, required this.symbol});
}

class ReviewItem {
  final String author;
  final int rating;
  final String text;

  ReviewItem({required this.author, required this.rating, required this.text});
}
