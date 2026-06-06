import { IChainAdapter, PaymentVerificationResult, EscrowUtxoResult } from './chainAdapter.interface';
import {
  buildLockTx,
  buildReleaseMilestoneTx,
  buildRaiseDisputeTx,
  buildAdminResolveTx,
  buildRefundTx,
  findActiveEscrowUtxo,
} from '../../services/escrow.service';
import { getTxInfo, verifyPayment } from '../../services/blockchain.service';
import { logger } from '../../config/logger';

export class CardanoAdapter implements IChainAdapter {
  chainName = 'Cardano';
  nativeAssetSymbol = 'ADA';

  async buildLockTx(
    invoiceId: string,
    amount: number,
    customerAddr: string
  ): Promise<{ txCbor: string; scriptAddress: string }> {
    logger.info('[CardanoAdapter] Building lock tx', { invoiceId, customerAddr, amount });
    const result = await buildLockTx(invoiceId, customerAddr);
    return {
      txCbor: result.unsignedCbor,
      scriptAddress: result.scriptAddress,
    };
  }

  async verifyOnChainPayment(
    txHash: string,
    expectedAddr: string,
    expectedAmount: number
  ): Promise<PaymentVerificationResult> {
    logger.info('[CardanoAdapter] Verifying on-chain payment', { txHash, expectedAddr, expectedAmount });
    const txInfo = await getTxInfo(txHash);
    if (!txInfo) {
      return {
        status: 'not-found',
        totalPaid: 0,
        txHash,
      };
    }
    const status = verifyPayment(txInfo, expectedAddr, expectedAmount);
    return {
      status,
      totalPaid: txInfo.totalOutputLovelace,
      txHash,
    };
  }

  async findActiveEscrowUtxo(invoiceId: string): Promise<EscrowUtxoResult | null> {
    logger.info('[CardanoAdapter] Finding active escrow UTxO', { invoiceId });
    const result = await findActiveEscrowUtxo(invoiceId);
    if (!result) return null;
    return {
      txHash: result.txHash,
      index: result.txIndex,
      amountLovelace: result.amountLovelace,
      datum: result.datum,
    };
  }

  async buildReleaseTx(
    invoiceId: string,
    milestoneIndex: number,
    payoutAddr: string
  ): Promise<{ txCbor: string }> {
    logger.info('[CardanoAdapter] Building release tx', { invoiceId, milestoneIndex, payoutAddr });
    // Use the milestoneIndex in buildReleaseMilestoneTx, which queries the invoice database inside.
    const result = await buildReleaseMilestoneTx(invoiceId, payoutAddr);
    return {
      txCbor: result.unsignedCbor,
    };
  }

  async buildRefundTx(invoiceId: string, refundAddr: string): Promise<{ txCbor: string }> {
    logger.info('[CardanoAdapter] Building refund tx', { invoiceId, refundAddr });
    const result = await buildRefundTx(invoiceId, refundAddr);
    return {
      txCbor: result.unsignedCbor,
    };
  }

  async buildResolveTx(
    invoiceId: string,
    merchantPayout: number,
    customerPayout: number
  ): Promise<{ txCbor: string }> {
    logger.info('[CardanoAdapter] Building resolve tx', { invoiceId, merchantPayout, customerPayout });
    // We assume the caller runs resolve with default adminAddress
    // In our system, the adminAddress is required for building.
    // Let's use the ESCROW_ADMIN_ADDRESS from environment parameters.
    const adminAddr = process.env.ESCROW_ADMIN_ADDRESS || 'addr_test1qrr2cldldladmin';
    const result = await buildAdminResolveTx(
      invoiceId,
      adminAddr,
      undefined,
      undefined,
      merchantPayout,
      customerPayout
    );
    return {
      txCbor: result.unsignedCbor,
    };
  }
}
