/**
 * Generates and uploads rich sample images to Amazon S3 for CampusGigs.
 * Creates avatars for all users and categorized gig cover images.
 */
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const env = require('../src/config/env');

const region = env.awsRegion || 'us-east-1';
const bucket = env.s3Bucket || 'campusgigs-sahil-779634-images';
const s3 = new S3Client({ region });

function makeSvg(text, bg1, bg2, icon) {
  return Buffer.from(`
    <svg xmlns="http://www.w3.org/2000/svg" width="600" height="340" viewBox="0 0 600 340">
      <defs>
        <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:${bg1};stop-opacity:1" />
          <stop offset="100%" style="stop-color:${bg2};stop-opacity:1" />
        </linearGradient>
      </defs>
      <rect width="600" height="340" rx="16" fill="url(#grad)" />
      <g fill="#FFFFFF" opacity="0.15">
        <circle cx="50" cy="50" r="100" />
        <circle cx="550" cy="290" r="120" />
      </g>
      <text x="300" y="150" font-family="system-ui, sans-serif" font-size="54" text-anchor="middle" fill="#FFFFFF">${icon}</text>
      <text x="300" y="210" font-family="system-ui, -apple-system, sans-serif" font-size="24" font-weight="bold" text-anchor="middle" fill="#FFFFFF">${text}</text>
      <text x="300" y="245" font-family="system-ui, sans-serif" font-size="14" opacity="0.85" text-anchor="middle" fill="#FFFFFF">CampusGigs • AWS Cloud Storage</text>
    </svg>
  `.trim());
}

const mediaItems = [
  // Avatars
  { key: 'avatars/aarav-sharma.svg', content: makeSvg('Aarav Sharma', '#4F46E5', '#7C3AED', '👨‍💻'), type: 'image/svg+xml' },
  { key: 'avatars/meera-iyer.svg', content: makeSvg('Meera Iyer', '#EC4899', '#F43F5E', '👩‍🎨'), type: 'image/svg+xml' },
  { key: 'avatars/rohan-patil.svg', content: makeSvg('Rohan Patil', '#0284C7', '#0EA5E9', '✍️'), type: 'image/svg+xml' },
  { key: 'avatars/sana-khan.svg', content: makeSvg('Sana Khan', '#059669', '#10B981', '🎬'), type: 'image/svg+xml' },
  
  // Gig Covers by Category
  { key: 'gigs/fest-logo-design.svg', content: makeSvg('College Fest Logo Design', '#8B5CF6', '#6D28D9', '🎨'), type: 'image/svg+xml' },
  { key: 'gigs/react-landing-page.svg', content: makeSvg('React & Vite Web Development', '#2563EB', '#1D4ED8', '💻'), type: 'image/svg+xml' },
  { key: 'gigs/research-paper-proofread.svg', content: makeSvg('Research Paper Editing', '#D97706', '#B45309', '📄'), type: 'image/svg+xml' },
  { key: 'gigs/hostel-reel-edit.svg', content: makeSvg('60s Event Recap Reel', '#DC2626', '#991B1B', '🎥'), type: 'image/svg+xml' },
  { key: 'gigs/dsa-tutoring.svg', content: makeSvg('DSA & Algorithms Tutoring', '#0D9488', '#0F766E', '🧠'), type: 'image/svg+xml' },
  { key: 'gigs/hackathon-poster.svg', content: makeSvg('Hackathon Poster & Branding', '#4338CA', '#3730A3', '🚀'), type: 'image/svg+xml' },
  { key: 'gigs/resume-cleanup.svg', content: makeSvg('Tech Resume Review & ATS', '#059669', '#047857', '📝'), type: 'image/svg+xml' },
  { key: 'gigs/aws-cloud-consultation.svg', content: makeSvg('AWS Architecture & Cloud Setup', '#EA580C', '#C2410C', '☁️'), type: 'image/svg+xml' },
  { key: 'gigs/data-analysis-sql.svg', content: makeSvg('SQL & Business Analytics', '#6366F1', '#4F46E5', '📊'), type: 'image/svg+xml' }
];

async function uploadAll() {
  console.log(`Connecting to S3 Bucket: ${bucket} in ${region}...`);
  for (const item of mediaItems) {
    try {
      await s3.send(new PutObjectCommand({
        Bucket: bucket,
        Key: item.key,
        Body: item.content,
        ContentType: item.type
      }));
      console.log(`Uploaded: s3://${bucket}/${item.key}`);
    } catch (err) {
      console.error(`Failed to upload ${item.key}:`, err.message);
    }
  }
  console.log('\nAll sample media successfully pushed to Amazon S3!');
}

uploadAll().catch(console.error);
