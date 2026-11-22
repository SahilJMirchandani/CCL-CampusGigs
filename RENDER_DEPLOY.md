# Deploying CampusGigs on Render

This guide deploys CampusGigs to [Render.com](https://render.com) so the website stays live permanently 24/7 without consuming AWS Academy Learner Lab credits.

---

### Option 1: Automatic Blueprint (1-Click via `render.yaml`)

1. Push this project to your GitHub repository.
2. Go to your [Render Dashboard](https://dashboard.render.com/).
3. Click **New +** -> **Blueprint**.
4. Connect your GitHub repository.
5. Render will automatically detect `render.yaml` and provision:
   - **PostgreSQL Database** (`campusgigs-db`)
   - **Web Service** (`campusgigs`) with automated `npm run install:all`, `npm run build`, and `npm run db:setup`.
6. Click **Apply**. Done!

---

### Option 2: Manual Web Service Setup on Render

If creating manually:
1. **Create PostgreSQL Database**:
   - In Render, click **New +** -> **PostgreSQL**.
   - Name: `campusgigs-db`
   - Database: `campusgigs`
   - User: `postgres`
   - Copy the **Internal Database URL**.
2. **Create Web Service**:
   - In Render, click **New +** -> **Web Service**.
   - Connect your GitHub repository.
   - **Environment**: Node
   - **Build Command**: `npm run install:all && npm run build`
   - **Start Command**: `npm run db:setup && cd server && node src/server.js`
   - **Environment Variables**:
     - `NODE_ENV`: `production`
     - `DATABASE_URL`: *(paste the Internal Database URL from step 1)*
     - `DB_SSL`: `true`
     - `JWT_SECRET`: *(any random 32+ character string)*
     - `ALLOWED_DOMAINS`: `ves.ac.in`
     - `S3_BUCKET`: *(leave empty to use local storage on Render, or provide AWS bucket)*
3. Click **Deploy Web Service**.
