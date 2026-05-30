import '../../shared/domain/models.dart';

class SyncConflictResolver {
  SyncConflictResolver._();

  // Escrow State Conflict Resolver
  static Escrow resolveEscrow(Escrow local, Escrow server) {
    // If the server state is locked or disputed, let the server override (source of truth)
    if (server.status == 'Disputed' || server.status == 'Released') {
      return server;
    }
    
    // Compare timestamps to choose the most recent update (Last-Write-Wins)
    if (local.createdAt.isAfter(server.createdAt)) {
      return local;
    }
    
    return server;
  }

  // Wallet Balance Conflict Resolver
  static List<Asset> resolveWalletAssets(List<Asset> local, List<Asset> server) {
    // Merge lists; server is always source-of-truth for on-chain balances
    final Map<String, Asset> merged = {};
    
    for (final asset in local) {
      merged[asset.symbol] = asset;
    }
    
    // Overwrite with server values (live on-chain)
    for (final asset in server) {
      merged[asset.symbol] = asset;
    }
    
    return merged.values.toList();
  }

  // Merchant Profile Conflict Resolver
  static Merchant resolveMerchant(Merchant local, Merchant server) {
    // If the server trust score is higher or has modern details, choose server
    if (server.trustScore >= local.trustScore) {
      return server;
    }
    return local;
  }
}
