// ─── Invoice Types ───────────────────────────────────────────────────────────

export type InvoiceStatus =
  | 'pending'
  | 'submitted'
  | 'confirming'
  | 'confirmed'
  | 'settled'
  | 'expired'
  | 'failed';

export interface InvoiceSnapshot {
  amountPaise: number;
  amountLovelace: number;
  adaInrRate: number;
  paymentAddress: string;
}

export interface Invoice {
  invoiceId: string;
  merchantId: string;
  merchantStringId: string;
  customerId?: string;
  chatRoomId?: string;
  amountPaise: number;
  amountLovelace: number;
  adaInrRate: number;
  paymentAddress: string;
  status: InvoiceStatus;
  txHash?: string;
  description?: string;
  expiresAt: string;
  createdAt: string;
  submittedAt?: string;
  confirmingAt?: string;
  confirmedAt?: string;
  settledAt?: string;
  receiptCid?: string;
  escrowState?: string;
  milestones?: Array<{
    title: string;
    amountLovelace: number;
    status: 'pending' | 'released' | 'disputed';
    releasedAt?: string;
  }>;
  milestoneIndex?: number;
  totalMilestones?: number;
  isDisputed?: boolean;
  agreementHash?: string;
  metadataHash?: string;
  contractVersion?: number;
  escrowLockTxHash?: string;
  escrowCustomerAddress?: string;
  disputeTxHash?: string;
  resolutionTxHash?: string;
  network?: 'cardano' | 'base';
}

// ─── User Types ───────────────────────────────────────────────────────────────

export type UserRole = 'customer' | 'merchant' | 'both' | 'admin';

export type OnboardingStep =
  | 'new'
  | 'role-selected'
  | 'shop-complete'
  | 'wallet-complete'
  | 'complete';

export interface User {
  id: string;
  firebaseUid: string;
  phone: string;
  displayName: string;
  role: UserRole;
  walletAddress?: string;
  walletProvider?: string;
  stakeAddress?: string;
  fcmToken?: string;
  onboardingStep: OnboardingStep;
  createdAt: string;
  updatedAt: string;
}

// ─── Merchant Types ───────────────────────────────────────────────────────────

export type MerchantCategory =
  | 'food'
  | 'retail'
  | 'services'
  | 'vendor'
  | 'other';

export interface Merchant {
  id: string;
  userId: string;
  merchantId: string;
  shopName: string;
  category: MerchantCategory;
  description?: string;
  paymentAddress: string;
  invoiceExpiry: number;
  totalReceivedLovelace: number;
  totalOrders: number;
  createdAt: string;
  updatedAt: string;
}

// ─── API Response Types ───────────────────────────────────────────────────────

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  hasMore: boolean;
}

// ─── Price Types ──────────────────────────────────────────────────────────────

export interface AdaInrRate {
  rate: number;
  source: 'live' | 'cached' | 'fallback';
  cachedAt: string;
}

// ─── Chat Types ───────────────────────────────────────────────────────────────

export type MessageType =
  | 'text'
  | 'payment-request'
  | 'payment-submitted'
  | 'payment-confirming'
  | 'receipt'
  | 'system';

export interface ChatMessage {
  id: string;
  senderId: string | 'system';
  type: MessageType;
  timestamp: number;
  payload: Record<string, unknown>;
}

export interface ChatRoom {
  id: string;
  merchantId: string;
  customerId: string;
  participants: Record<string, boolean>;
  lastMessage?: {
    preview: string;
    timestamp: number;
  };
  unreadCounts: Record<string, number>;
  createdAt: number;
}

// ─── Payment Types ────────────────────────────────────────────────────────────

export interface BuildTxRequest {
  invoiceId: string;
}

export interface BuildTxResponse {
  unsignedCbor: string;
  invoiceId: string;
  amountLovelace: number;
  paymentAddress: string;
}

export interface SubmitTxRequest {
  invoiceId: string;
  txHash: string;
}

// ─── Receipt Types ────────────────────────────────────────────────────────────

export interface IpfsReceipt {
  version: string;
  invoiceId: string;
  txHash: string;
  amountLovelace: number;
  amountInr: number;
  adaInrRate: number;
  merchant: {
    merchantId: string;
    shopName: string;
    paymentAddress: string;
  };
  customer: {
    displayName: string;
    walletAddress?: string;
  };
  confirmedAt: string;
  settledAt: string;
  networkConfirmations: number;
  escrow?: {
    escrowState: string;
    milestoneIndex: number;
    totalMilestones: number;
    isDisputed: boolean;
    milestones: Array<{
      title: string;
      amountLovelace: number;
      status: string;
      releasedAt?: string;
    }>;
    agreementHash?: string;
    metadataHash?: string;
  };
}

// ─── Phase 3: Storefront & Commerce Types ─────────────────────────────────────

export type ProductCategory = 'digital' | 'physical' | 'service';

export interface Product {
  productId: string;
  merchantId: string;
  title: string;
  description: string;
  priceLovelace: number;
  priceINR?: number;
  category: ProductCategory;
  isDigital: boolean;
  ipfsHash?: string;
  inventory?: number;
  images: string[];
  tags: string[];
  isActive: boolean;
  totalSold: number;
  rating?: number;
  createdAt: string;
}

export interface Review {
  invoiceId: string;
  merchantId: string;
  customerId: string;
  productId?: string;
  rating: number;
  body?: string;
  isVerified: boolean;
  createdAt: string;
}

export interface StorefrontProfile {
  slug: string;
  shopName: string;
  description?: string;
  category: MerchantCategory;
  profileImageUrl?: string;
  bannerImageUrl?: string;
  location?: { city?: string; state?: string; country?: string };
  socialLinks?: { instagram?: string; twitter?: string; website?: string };
  businessHours?: string;
  reputationScore: number;
  reliabilityTier: string;
  verifiedMerchantBadge: boolean;
  totalOrders: number;
  escrowCompletionRate: number;
}

// ─── Phase 3: Developer API Types ─────────────────────────────────────────────

export type ApiPermission =
  | 'escrow:read'
  | 'escrow:write'
  | 'invoice:read'
  | 'invoice:write'
  | 'webhooks:write'
  | 'merchant:read'
  | '*';

export interface ApiKeyInfo {
  keyId: string;
  name: string;
  permissions: ApiPermission[];
  rateLimitTier: 'starter' | 'pro' | 'enterprise';
  requestCount: number;
  lastUsedAt?: string;
  isActive: boolean;
  createdAt: string;
}

export type WebhookEvent =
  | 'escrow.locked'
  | 'escrow.released'
  | 'escrow.disputed'
  | 'escrow.resolved'
  | 'invoice.created'
  | 'invoice.paid'
  | 'invoice.expired'
  | 'milestone.released';

export interface WebhookInfo {
  id: string;
  url: string;
  events: WebhookEvent[];
  isActive: boolean;
  failureCount: number;
  lastDeliveredAt?: string;
  createdAt: string;
}

// ─── Phase 3: Dispute Resolution Types ────────────────────────────────────────

export type VerdictStatus = 'pending' | 'auto_queued' | 'accepted' | 'rejected' | 'executed';

export interface DisputeVerdictSummary {
  invoiceId: string;
  merchantSplitPercent: number;
  customerSplitPercent: number;
  confidence: number;
  reasoning: string;
  keyClaims: string[];
  status: VerdictStatus;
  humanReviewRequired: boolean;
  autoExecAt?: string;
  executedTxHash?: string;
  createdAt: string;
}

// ─── Phase 3: Reputation Types ────────────────────────────────────────────────

export interface ReputationCard {
  walletAddress?: string;
  merchantId: string;
  shopName: string;
  reputationScore: number;
  reliabilityTier: string;
  verifiedMerchantBadge: boolean;
  totalOrders: number;
  disputeRate: string;
  escrowCompletionRate: number;
  reviewSummary: { average: number; count: number };
}

// ─── Phase 3: Marketplace Types ───────────────────────────────────────────────

export interface MarketplaceMerchant {
  slug: string;
  shopName: string;
  category: MerchantCategory;
  profileImageUrl?: string;
  reputationScore: number;
  reliabilityTier: string;
  verifiedMerchantBadge: boolean;
  totalOrders: number;
  location?: { city?: string };
}

// ─── Phase 3: Analytics Types ─────────────────────────────────────────────────

export interface MerchantKPIs {
  totalRevenueLovelace: number;
  totalOrders: number;
  avgOrderLovelace: number;
  escrowCompletionRate: number;
  disputeRate: string;
  activeProducts: number;
  storefrontViews: number;
  storefrontConversions: number;
}

export interface RevenueDataPoint {
  date: string;
  totalLovelace: number;
  orderCount: number;
}

