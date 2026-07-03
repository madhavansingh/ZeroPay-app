import 'dotenv/config';
import { BlockfrostProvider, deserializeDatum } from '@meshsdk/core';

const ESCROW_SCRIPT_ADDRESS = 'addr_test1wpzzpjrf856y94vvssyr8fjekf7zhk0g0vffltcz0lpkyhcq9h3z9';

async function audit() {
  const projectId = process.env.BLOCKFROST_PROJECT_ID;
  if (!projectId) {
    console.error('BLOCKFROST_PROJECT_ID not set');
    process.exit(1);
  }

  const provider = new BlockfrostProvider(projectId);
  console.log('Script Address:', ESCROW_SCRIPT_ADDRESS);

  try {
    const utxos = await provider.fetchAddressUTxOs(ESCROW_SCRIPT_ADDRESS);
    console.log(`Found ${utxos ? utxos.length : 0} UTxOs at script address.`);

    if (utxos) {
      for (let i = 0; i < utxos.length; i++) {
        const utxo = utxos[i];
        console.log(`\n--- UTxO #${i + 1} ---`);
        console.log(`TxHash: ${utxo.input.txHash}`);
        console.log(`Index: ${utxo.input.outputIndex}`);
        console.log(`Amounts:`, JSON.stringify(utxo.output.amount));
        console.log(`Plutus Data (Datum CBOR): ${utxo.output.plutusData ?? 'None'}`);

        if (utxo.output.plutusData) {
          try {
            const datum = deserializeDatum<any>(utxo.output.plutusData);
            console.log('Decoded Datum (fields only):');
            console.dir(datum, { depth: null });
            
            // Try decoding invoiceId field if possible
            const hexInvoiceId = datum.fields[3];
            if (typeof hexInvoiceId === 'string') {
              const decodedId = Buffer.from(hexInvoiceId, 'hex').toString('utf8');
              console.log(`Decoded Invoice ID: "${decodedId}"`);
            }
          } catch (err: any) {
            console.error('Failed to decode datum:', err.message);
          }
        }
      }
    }
  } catch (err: any) {
    console.error('Error fetching UTxOs:', err);
  }
}

audit();
