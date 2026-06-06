export interface PaymentVerificationResult {
  status: 'amount-matched' | 'amount-mismatch' | 'address-mismatch' | 'not-found';
  totalPaid: number;
  txHash: string;
}

export interface EscrowUtxoResult {
  txHash: string;
  index: number;
  amountLovelace: number;
  datum?: any;
}

export interface IChainAdapter {
  chainName: string;
  nativeAssetSymbol: string;

  /**
   * Build an unsigned transaction payload for locking funds in the escrow contract
   */
  buildLockTx(
    invoiceId: string,
    amount: number,
    customerAddr: string
  ): Promise<{ txCbor: string; scriptAddress: string }>;

  /**
   * Verify an on-chain transaction meets expectations
   */
  verifyOnChainPayment(
    txHash: string,
    expectedAddr: string,
    expectedAmount: number
  ): Promise<PaymentVerificationResult>;

  /**
   * Find the active UTxO currently locked at the script address for this invoice
   */
  findActiveEscrowUtxo(invoiceId: string): Promise<EscrowUtxoResult | null>;

  /**
   * Build an unsigned transaction payload to release a milestone payout
   */
  buildReleaseTx(
    invoiceId: string,
    milestoneIndex: number,
    payoutAddr: string
  ): Promise<{ txCbor: string }>;

  /**
   * Build an unsigned transaction payload to refund the customer
   */
  buildRefundTx(invoiceId: string, refundAddr: string): Promise<{ txCbor: string }>;

  /**
   * Build an unsigned transaction payload to resolve a dispute with split payouts
   */
  buildResolveTx(
    invoiceId: string,
    merchantPayout: number,
    customerPayout: number
  ): Promise<{ txCbor: string }>;
}
