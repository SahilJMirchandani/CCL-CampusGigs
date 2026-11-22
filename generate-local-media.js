const fs = require('fs');
const path = require('path');

function makeSvg(text, bg1, bg2, icon) {
  return `<svg xmlns='http://www.w3.org/2000/svg' width='600' height='340' viewBox='0 0 600 340'>
    <defs>
      <linearGradient id='grad' x1='0%' y1='0%' x2='100%' y2='100%'>
        <stop offset='0%' style='stop-color:${bg1};stop-opacity:1' />
        <stop offset='100%' style='stop-color:${bg2};stop-opacity:1' />
      </linearGradient>
    </defs>
    <rect width='600' height='340' rx='16' fill='url(#grad)' />
    <g fill='#FFFFFF' opacity='0.15'>
      <circle cx='50' cy='50' r='100' />
      <circle cx='550' cy='290' r='120' />
    </g>
    <text x='300' y='150' font-family='system-ui, sans-serif' font-size='54' text-anchor='middle' fill='#FFFFFF'>${icon}</text>
    <text x='300' y='210' font-family='system-ui, -apple-system, sans-serif' font-size='24' font-weight='bold' text-anchor='middle' fill='#FFFFFF'>${text}</text>
    <text x='300' y='245' font-family='system-ui, sans-serif' font-size='14' opacity='0.85' text-anchor='middle' fill='#FFFFFF'>CampusGigs • AWS Cloud Storage</text>
  </svg>`.trim();
}

const items = [
  { p: 'server/uploads/avatars/aarav-sharma.svg', c: makeSvg('Aarav Sharma', '#4F46E5', '#7C3AED', '👨‍💻') },
  { p: 'server/uploads/avatars/meera-iyer.svg', c: makeSvg('Meera Iyer', '#EC4899', '#F43F5E', '👩‍🎨') },
  { p: 'server/uploads/avatars/rohan-patil.svg', c: makeSvg('Rohan Patil', '#0284C7', '#0EA5E9', '✍️') },
  { p: 'server/uploads/avatars/sana-khan.svg', c: makeSvg('Sana Khan', '#059669', '#10B981', '🎬') },
  { p: 'server/uploads/gigs/fest-logo-design.svg', c: makeSvg('College Fest Logo Design', '#8B5CF6', '#6D28D9', '🎨') },
  { p: 'server/uploads/gigs/react-landing-page.svg', c: makeSvg('React & Vite Web Development', '#2563EB', '#1D4ED8', '💻') },
  { p: 'server/uploads/gigs/research-paper-proofread.svg', c: makeSvg('Research Paper Editing', '#D97706', '#B45309', '📄') },
  { p: 'server/uploads/gigs/hostel-reel-edit.svg', c: makeSvg('60s Event Recap Reel', '#DC2626', '#991B1B', '🎥') },
  { p: 'server/uploads/gigs/dsa-tutoring.svg', c: makeSvg('DSA & Algorithms Tutoring', '#0D9488', '#0F766E', '🧠') },
  { p: 'server/uploads/gigs/hackathon-poster.svg', c: makeSvg('Hackathon Poster & Branding', '#4338CA', '#3730A3', '🚀') },
  { p: 'server/uploads/gigs/resume-cleanup.svg', c: makeSvg('Tech Resume Review & ATS', '#059669', '#047857', '📝') },
  { p: 'server/uploads/gigs/aws-cloud-consultation.svg', c: makeSvg('AWS Architecture & Cloud Setup', '#EA580C', '#C2410C', '☁️') },
  { p: 'server/uploads/gigs/data-analysis-sql.svg', c: makeSvg('SQL & Business Analytics', '#6366F1', '#4F46E5', '📊') }
];

items.forEach(({ p, c }) => {
  const fullPath = path.join(__dirname, p);
  fs.mkdirSync(path.dirname(fullPath), { recursive: true });
  fs.writeFileSync(fullPath, c, 'utf8');
});
console.log(`Successfully generated ${items.length} media assets!`);
