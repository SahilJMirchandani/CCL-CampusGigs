/**
 * CampusGigs S3 & Local Media Asset Generator & Synchronizer
 * Generates and synchronizes rich visual assets:
 *  - User profile avatars
 *  - Category gig cover images
 *  - Project deliverables & attachments
 *  - Campus banners
 *  - CloudWatch & health status markers
 */
const fs = require('fs');
const path = require('path');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const env = require('../config/env');

const region = env.awsRegion || 'us-east-1';
const bucket = env.s3Bucket || 'campusgigs-sahil-779634-images';
const s3 = env.s3Bucket ? new S3Client({ region }) : null;
const uploadsDir = path.join(__dirname, '..', '..', 'uploads');

function makeSvg(title, subtitle, bg1, bg2, icon, width = 600, height = 340) {
  return Buffer.from(`
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:${bg1};stop-opacity:1" />
      <stop offset="100%" style="stop-color:${bg2};stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="${width}" height="${height}" rx="16" fill="url(#grad)" />
  <g fill="#FFFFFF" opacity="0.12">
    <circle cx="40" cy="40" r="80" />
    <circle cx="${width - 40}" cy="${height - 40}" r="110" />
  </g>
  <text x="${width / 2}" y="${height / 2 - 20}" font-family="system-ui, sans-serif" font-size="${height > 200 ? 52 : 36}" text-anchor="middle" fill="#FFFFFF">${icon}</text>
  <text x="${width / 2}" y="${height / 2 + 40}" font-family="system-ui, -apple-system, sans-serif" font-size="${height > 200 ? 22 : 16}" font-weight="bold" text-anchor="middle" fill="#FFFFFF">${title}</text>
  <text x="${width / 2}" y="${height / 2 + 75}" font-family="system-ui, sans-serif" font-size="${height > 200 ? 13 : 11}" opacity="0.85" text-anchor="middle" fill="#FFFFFF">${subtitle}</text>
</svg>
`.trim());
}

function makeAvatarSvg(name, role, bg1, bg2, emoji) {
  return Buffer.from(`
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200">
  <defs>
    <linearGradient id="avGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:${bg1};stop-opacity:1" />
      <stop offset="100%" style="stop-color:${bg2};stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="200" height="200" rx="100" fill="url(#avGrad)" />
  <text x="100" y="105" font-family="system-ui, sans-serif" font-size="70" text-anchor="middle">${emoji}</text>
  <text x="100" y="170" font-family="system-ui, sans-serif" font-size="14" font-weight="bold" text-anchor="middle" fill="#FFFFFF">${name}</text>
</svg>
`.trim());
}

const mediaItems = [
  // User Avatars (VESIT Students)
  { key: 'avatars/aarav-sharma.svg', content: makeAvatarSvg('Aarav Sharma', 'Full-Stack Dev', '#4F46E5', '#7C3AED', '👨‍💻'), type: 'image/svg+xml' },
  { key: 'avatars/meera-iyer.svg', content: makeAvatarSvg('Meera Iyer', 'UI/UX Designer', '#EC4899', '#F43F5E', '👩‍🎨'), type: 'image/svg+xml' },
  { key: 'avatars/rohan-patil.svg', content: makeAvatarSvg('Rohan Patil', 'Technical Writer', '#0284C7', '#0EA5E9', '✍️'), type: 'image/svg+xml' },
  { key: 'avatars/sana-khan.svg', content: makeAvatarSvg('Sana Khan', 'Video Editor', '#059669', '#10B981', '🎬'), type: 'image/svg+xml' },

  // Gigs Covers (Marketplace Categories)
  { key: 'gigs/fest-logo-design.svg', content: makeSvg('College Fest Logo Design', 'Brand Identity • Vector Assets', '#8B5CF6', '#6D28D9', '🎨'), type: 'image/svg+xml' },
  { key: 'gigs/react-landing-page.svg', content: makeSvg('React & Vite Web Development', 'Frontend Architecture • Responsive', '#2563EB', '#1D4ED8', '💻'), type: 'image/svg+xml' },
  { key: 'gigs/research-paper-proofread.svg', content: makeSvg('Research Paper Editing', 'IEEE Format • Grammar & Citations', '#D97706', '#B45309', '📄'), type: 'image/svg+xml' },
  { key: 'gigs/hostel-reel-edit.svg', content: makeSvg('60s Event Recap Reel', 'Instagram Reels • 4K Color Graded', '#DC2626', '#991B1B', '🎥'), type: 'image/svg+xml' },
  { key: 'gigs/dsa-tutoring.svg', content: makeSvg('DSA & Algorithms Tutoring', 'LeetCode • Trees, Graphs, DP', '#0D9488', '#0F766E', '🧠'), type: 'image/svg+xml' },
  { key: 'gigs/hackathon-poster.svg', content: makeSvg('Hackathon Poster & Branding', 'Print-ready CMYK • Social Graphics', '#4338CA', '#3730A3', '🚀'), type: 'image/svg+xml' },
  { key: 'gigs/resume-cleanup.svg', content: makeSvg('Tech Resume Review & ATS', 'ATS Optimization • FAANG Templates', '#059669', '#047857', '📝'), type: 'image/svg+xml' },
  { key: 'gigs/aws-cloud-consultation.svg', content: makeSvg('AWS Architecture & Cloud Setup', 'EC2 • RDS • S3 • IAM Security', '#EA580C', '#C2410C', '☁️'), type: 'image/svg+xml' },
  { key: 'gigs/data-analysis-sql.svg', content: makeSvg('SQL & Business Analytics', 'PostgreSQL Queries • PowerBI Dashboards', '#6366F1', '#4F46E5', '📊'), type: 'image/svg+xml' },

  // Deliverables & Project Attachments
  { key: 'attachments/sample-project-spec.svg', content: makeSvg('Project Specifications & Requirements', 'Deliverable • Architecture Diagram', '#334155', '#1E293B', '📋'), type: 'image/svg+xml' },
  { key: 'attachments/wireframe-flowchart.svg', content: makeSvg('UI/UX Wireframes & User Journey', 'Figma Prototype Specs • Mobile First', '#475569', '#0F172A', '📐'), type: 'image/svg+xml' },
  { key: 'attachments/resume-template.svg', content: makeSvg('Standard ATS Engineering Resume', 'LaTeX & Typst Ready • 1-Page Layout', '#0F766E', '#115E59', '📑'), type: 'image/svg+xml' },

  // Campus Marketing Banners
  { key: 'banners/welcome-ccl-2026.svg', content: makeSvg('CampusGigs • Cloud Computing Lab 2026', 'VESIT Student Freelancing Platform powered by AWS', '#1E1B4B', '#312E81', '🏛️', 900, 300), type: 'image/svg+xml' },
  { key: 'banners/cloud-computing-lab.svg', content: makeSvg('AWS Well-Architected Student Marketplace', 'EC2 (Compute) + RDS PostgreSQL + S3 (Media)', '#0F172A', '#1E293B', '☁️', 900, 300), type: 'image/svg+xml' },

  // System & Health Markers
  {
    key: 'system/status.json',
    content: Buffer.from(JSON.stringify({
      status: 'healthy',
      bucket: bucket,
      region: region,
      platform: 'AWS Academy Learner Lab / Cloud Computing Lab',
      lastUpdated: new Date().toISOString()
    }, null, 2)),
    type: 'application/json'
  }
];

async function syncAll() {
  console.log(`=== CampusGigs Media Asset Synchronizer ===`);
  console.log(`Writing ${mediaItems.length} assets to local disk: ${uploadsDir}...`);

  for (const item of mediaItems) {
    const dest = path.join(uploadsDir, item.key);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, item.content);
  }
  console.log(`✓ All ${mediaItems.length} assets saved locally to uploads/`);

  if (!s3) {
    console.log(`Notice: S3_BUCKET is not set; running in local storage mode.`);
    return;
  }

  console.log(`\nAttempting upload to AWS S3 bucket: ${bucket} (${region})...`);
  let uploadedCount = 0;
  for (const item of mediaItems) {
    try {
      await s3.send(new PutObjectCommand({
        Bucket: bucket,
        Key: item.key,
        Body: item.content,
        ContentType: item.type
      }));
      console.log(`✓ Uploaded to S3: s3://${bucket}/${item.key}`);
      uploadedCount++;
    } catch (err) {
      console.warn(`! Could not upload ${item.key} to S3 (${err.message})`);
    }
  }

  if (uploadedCount === mediaItems.length) {
    console.log(`\n🎉 Success! All ${uploadedCount} objects are live in Amazon S3.`);
  } else {
    console.log(`\nℹ Notice: ${uploadedCount}/${mediaItems.length} objects uploaded to S3.`);
    console.log(`If running outside EC2 and temporary AWS tokens expired, see aws/upload-to-s3.bat to upload once the lab is started.`);
  }
}

if (require.main === module) {
  syncAll().catch(console.error);
}

module.exports = { syncAll, mediaItems };
