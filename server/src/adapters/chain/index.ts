import { IChainAdapter } from './chainAdapter.interface';
import { CardanoAdapter } from './cardanoAdapter';

class ChainAdapterRegistry {
  private adapters: Record<string, IChainAdapter> = {};

  constructor() {
    this.register(new CardanoAdapter());
  }

  register(adapter: IChainAdapter) {
    this.adapters[adapter.chainName.toLowerCase()] = adapter;
  }

  getAdapter(chainName?: string): IChainAdapter {
    const key = (chainName || 'cardano').toLowerCase();
    const adapter = this.adapters[key];
    if (!adapter) {
      throw new Error(`Unsupported chain adapter: ${chainName}`);
    }
    return adapter;
  }
}

export const chainAdapterRegistry = new ChainAdapterRegistry();
export * from './chainAdapter.interface';
