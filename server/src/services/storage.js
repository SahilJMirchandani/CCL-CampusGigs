const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const env = require('../config/env');
const { HttpError } = require('../utils/httpError');

// On EC2 the SDK reads credentials from the instance's IAM role (LabRole). No keys in code.
const s3 = env.s3Bucket ? new S3Client({ region: env.awsRegion }) : null;
const LOCAL_DIR = path.join(__dirname, '..', '..', 'uploads');
const EXT = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp', 'image/svg+xml': 'svg', 'application/json': 'json' };
const TYPE = { png: 'image/png', jpg: 'image/jpeg', webp: 'image/webp', svg: 'image/svg+xml', json: 'application/json' };

/** Saves a base64 data URL to S3 (or local disk in dev) and returns a stable URL like /api/media/gigs/abc.jpg */
async function saveDataUrl(dataUrl, folder) {
  const m = /^data:(image\/(?:png|jpe?g|webp|svg\+xml));base64,(.+)$/.exec(dataUrl || '');
  if (!m) throw new HttpError(400, 'Image must be a PNG, JPG, WebP or SVG');
  const buf = Buffer.from(m[2], 'base64');
  if (buf.length > 2 * 1024 * 1024) throw new HttpError(400, 'Image is too large (max 2 MB)');
  const type = m[1] === 'image/jpg' ? 'image/jpeg' : m[1];
  const key = `${folder}/${Date.now()}-${crypto.randomBytes(4).toString('hex')}.${EXT[type]}`;
  if (s3) {
    await s3.send(new PutObjectCommand({ Bucket: env.s3Bucket, Key: key, Body: buf, ContentType: type }));
  } else {
    fs.mkdirSync(path.dirname(path.join(LOCAL_DIR, key)), { recursive: true });
    fs.writeFileSync(path.join(LOCAL_DIR, key), buf);
  }
  return `/api/media/${key}`;
}

function makePlaceholderSvg(key) {
  const name = key.split('/').pop().replace(/\.[^.]+$/, '').replace(/[-_]/g, ' ');
  const isAvatar = key.startsWith('avatars');
  const letter = (name.charAt(0) || 'C').toUpperCase();
  const bg = isAvatar ? '#4F46E5' : '#0284C7';
  if (isAvatar) {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
      <circle cx="64" cy="64" r="64" fill="${bg}" />
      <text x="64" y="78" font-family="system-ui, sans-serif" font-size="44" font-weight="bold" text-anchor="middle" fill="#FFFFFF">${letter}</text>
    </svg>`;
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="340" viewBox="0 0 600 340">
    <defs>
      <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" style="stop-color:#1E293B;stop-opacity:1" />
        <stop offset="100%" style="stop-color:#334155;stop-opacity:1" />
      </linearGradient>
    </defs>
    <rect width="600" height="340" rx="16" fill="url(#bg)" />
    <circle cx="300" cy="130" r="45" fill="${bg}" opacity="0.4" />
    <text x="300" y="145" font-family="system-ui, sans-serif" font-size="40" text-anchor="middle" fill="#FFFFFF">💼</text>
    <text x="300" y="215" font-family="system-ui, sans-serif" font-size="20" font-weight="600" text-anchor="middle" fill="#FFFFFF">${name}</text>
    <text x="300" y="245" font-family="system-ui, sans-serif" font-size="13" opacity="0.6" text-anchor="middle" fill="#FFFFFF">CampusGigs Marketplace</text>
  </svg>`;
}

/** Streams an image back to the browser. The bucket stays private; only the backend can read it. */
async function sendMedia(key, res) {
  const ext = key.split('.').pop();
  try {
    if (s3) {
      const out = await s3.send(new GetObjectCommand({ Bucket: env.s3Bucket, Key: key }));
      res.set('Content-Type', TYPE[ext] || 'application/octet-stream');
      res.set('Cache-Control', 'public, max-age=86400');
      return out.Body.pipe(res);
    }
    const file = path.join(LOCAL_DIR, key);
    if (fs.existsSync(file)) {
      res.set('Content-Type', TYPE[ext] || 'application/octet-stream');
      res.set('Cache-Control', 'public, max-age=86400');
      return fs.createReadStream(file).pipe(res);
    }
  } catch (_err) {
    // If not found in S3 or local, fall through to graceful SVG placeholder
  }

  res.set('Content-Type', 'image/svg+xml');
  res.set('Cache-Control', 'public, max-age=3600');
  return res.send(makePlaceholderSvg(key));
}

module.exports = { saveDataUrl, sendMedia, storageMode: s3 ? 's3' : 'local' };
