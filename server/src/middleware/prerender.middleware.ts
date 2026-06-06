import { Request, Response, NextFunction } from 'express';
import { Merchant } from '../models/Merchant';
import { logger } from '../config/logger';

const BOT_USER_AGENTS = [
  'googlebot',
  'yahoo! slurp',
  'bingbot',
  'yandex',
  'baiduspider',
  'facebookexternalhit',
  'twitterbot',
  'rogersbot',
  'linkedinbot',
  'embedly',
  'quora link preview',
  'showyoubot',
  'outbrain',
  'pinterest/0.',
  'slackbot',
  'vkshare',
  'w3c_validator',
  'redditbot',
  'applebot',
  'whatsapp',
  'telegrambot',
];

export async function prerenderMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const userAgent = (req.headers['user-agent'] || '').toLowerCase();
  
  // Check if User-Agent matches any known crawler/crawler bot
  const isBot = BOT_USER_AGENTS.some((bot) => userAgent.includes(bot));

  if (!isBot) {
    next();
    return;
  }

  const path = req.path;
  // We only target the public storefront path format /s/:slug
  if (!path.startsWith('/s/')) {
    next();
    return;
  }

  const slug = path.split('/')[2];
  if (!slug) {
    next();
    return;
  }

  try {
    logger.info('[Prerender] Intercepted search crawler request', { userAgent, slug, path });

    const merchant = await Merchant.findOne({ slug, isPublicStorefront: true, isActive: true });
    if (!merchant) {
      next();
      return;
    }

    const ratingsText = merchant.reputationScore
      ? `Rated ${merchant.reputationScore}/100 in verified trust.`
      : 'Trust scoring in progress.';
      
    const locationText = merchant.location?.city 
      ? `Operating from ${merchant.location.city}, ${merchant.location.country || 'IN'}.`
      : '';

    const title = `${merchant.shopName} - ZeroPay Verified Storefront`;
    const description = `${merchant.description || 'Verified ZeroPay merchant storefront.'} ${ratingsText} ${locationText} Secure Web3 Cardano escrow checkout supported.`;
    const image = merchant.profileImageUrl || 'https://zeropay.finance/assets/logo.png';
    const siteUrl = `https://zeropay.finance${path}`;

    // Build highly semantic, crawlable HTML with Open Graph & Twitter cards tags
    const htmlPrerender = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>${title}</title>
  <meta name="description" content="${description}">

  <!-- Open Graph / Facebook tags -->
  <meta property="og:type" content="website">
  <meta property="og:url" content="${siteUrl}">
  <meta property="og:title" content="${title}">
  <meta property="og:description" content="${description}">
  <meta property="og:image" content="${image}">

  <!-- Twitter card tags -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:url" content="${siteUrl}">
  <meta name="twitter:title" content="${title}">
  <meta name="twitter:description" content="${description}">
  <meta name="twitter:image" content="${image}">

  <!-- Web3 Verified Merchant Metadata -->
  <meta name="zeropay:merchant" content="${merchant.merchantId}">
  <meta name="zeropay:trust" content="${merchant.reputationScore || 100}">
  <meta name="zeropay:tier" content="${merchant.reliabilityTier || 'unrated'}">
  <meta name="zeropay:badge" content="${merchant.verifiedMerchantBadge}">
</head>
<body>
  <main>
    <article>
      <h1>${merchant.shopName}</h1>
      <p><strong>Category:</strong> ${merchant.category || 'Commerce'}</p>
      <p>${merchant.description || ''}</p>
      <div id="reputation">
        <p><strong>Trust Rating:</strong> ${merchant.reputationScore || '100'}/100</p>
        <p><strong>Reliability Tier:</strong> ${merchant.reliabilityTier || 'Standard'}</p>
        <p><strong>Verified Badge:</strong> ${merchant.verifiedMerchantBadge ? 'Yes' : 'No'}</p>
      </div>
      <div id="location">
        <p><strong>City:</strong> ${merchant.location?.city || ''}</p>
        <p><strong>Country:</strong> ${merchant.location?.country || ''}</p>
      </div>
    </article>
  </main>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.status(200).send(htmlPrerender);
  } catch (err: any) {
    logger.error('[Prerender] Intercept query failure', { error: err.message, slug });
    next();
  }
}
