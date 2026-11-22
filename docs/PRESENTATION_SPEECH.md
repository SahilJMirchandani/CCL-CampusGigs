# CampusGigs: Cloud Computing Laboratory (CCL) Presentation Speech

**Project Name:** CampusGigs — Cloud-Native Student Freelancing & Escrow Marketplace  
**Presenter:** Sahil Mirchandani  
**Stack:** React 18, Node.js/Express, PostgreSQL 16, Amazon EC2, Amazon RDS, Amazon S3, AWS IAM  
**Live Application:** [https://campusgigs-u70p.onrender.com](https://campusgigs-u70p.onrender.com)  
**GitHub Repository:** [https://github.com/SahilJMirchandani/CCL-CampusGigs](https://github.com/SahilJMirchandani/CCL-CampusGigs)

---

## Part 1: Quick 2-Minute Elevator Pitch (For Fast Viva)

> *"Good morning, respected evaluators and professors. My name is Sahil Mirchandani, and today I am presenting **CampusGigs**, a cloud-native peer-to-peer micro-task marketplace designed specifically for university campuses.*
>
> *Every day on campus, students need quick, reliable assistance—whether it's designing a fest poster, debugging code, proofreading a research paper, or video editing. However, peer freelancing suffers from two major trust issues: **payment risk for the freelancer** and **incomplete delivery risk for the task poster**.*
>
> *CampusGigs solves this with a **guaranteed Escrow State Machine**: when a gig poster accepts a student's bid, the exact bid amount is automatically deducted and locked into secure escrow in the database. The student completes the work and submits the delivery. Once approved, the funds release instantly to their wallet. Neither party can be scammed, and transactional row-locks prevent any possibility of double-spending.*
>
> *From a Cloud Computing standpoint, CampusGigs is architected following the **AWS Well-Architected 3-Tier Pattern**:*
> 1. *Our **Compute Tier** runs on an **Amazon EC2** Ubuntu instance managed by PM2 with an Nginx reverse proxy.*
> 2. *Our **Database Tier** utilizes **Amazon RDS PostgreSQL 16** with strict Security Group peering—the database cannot be reached from the public internet, only through our EC2 security group.*
> 3. *Our **Storage Tier** uses a private **Amazon S3** bucket with Block Public Access enabled, streaming media securely through our backend.*
> 4. *Our **Security Posture** is completely keyless—the EC2 instance communicates with S3 using an attached **IAM Role (LabRole)** through Instance Metadata Service v2 (IMDSv2), meaning zero API credentials or secrets exist in the codebase.*
>
> *In addition to AWS, the project is deployed with automated CI/CD on Render for 24/7 high availability. I'm excited to demonstrate the live application."*

---

## Part 2: Detailed 5–7 Minute Presentation Script (With Live Demo Cues)

### Slide / Step 1: Introduction & Problem Statement (0:00 – 1:00)
*"Good morning. I am Sahil Mirchandani, presenting **CampusGigs** for the Cloud Computing Laboratory project.*

*In collegiate environments, skills are abundant, but formal freelancing platforms like Upwork or Fiverr fail because of high commission fees, complex identity verification, and non-student context. Students instead turn to informal WhatsApp or Discord groups, which frequently result in payment ghosting or poor-quality submissions.*

*CampusGigs introduces a secure campus marketplace verified by college email domain (`@ves.ac.in`) and backed by a gamified student reputation system with XP, levels, and an automated financial Escrow engine."*

---

### Slide / Step 2: Cloud Infrastructure & AWS Architecture (1:00 – 2:30)
*(Display Architecture Diagram)*

```mermaid
graph TD
    Client["Client Browser (React 18 SPA)"] -->|HTTPS / Port 443| LB["Nginx Reverse Proxy / Render"]
    LB -->|Port 5000| EC2["Compute: Amazon EC2 (t2.micro / Node.js & PM2)"]
    EC2 -->|IAM LabRole (SigV4)| S3["Storage: Amazon S3 (Private Media Bucket)"]
    EC2 -->|PostgreSQL Port 5432 / SSL| RDS["Database: Amazon RDS PostgreSQL 16"]
```

*"Let us look under the hood at how we designed the cloud infrastructure:*

1. ***Amazon EC2 (Compute Tier):***
   - *Deployed on an Ubuntu 22.04 `t2.micro` instance.*
   - *We implemented **Nginx** as a reverse proxy, mapping incoming port 80 traffic to Node.js on internal port 5000, while applying Gzip compression.*
   - *The backend process is governed by **PM2**, guaranteeing auto-recovery if an unhandled exception occurs and persistence across EC2 reboots.*

2. ***Amazon RDS PostgreSQL 16 (Database Tier):***
   - *Configured on `db.t3.micro` with 20 GB gp3 storage.*
   - *To optimize query throughput, we created targeted **B-Tree indexes** on `bids(gig_id)`, `gigs(category)`, and `users(email)`, eliminating costly sequential table scans.*
   - *Our connection pool handles up to 20 concurrent clients with automated idle client pruning and sub-50ms latency.*

3. ***Amazon S3 (Storage Tier):***
   - *A dedicated bucket `campusgigs-sahil-779634-images` stores student avatars, gig artwork, attachments, and banners.*
   - *Following AWS Security Best Practices, **Block Public Access is ON**. Instead of making the bucket public, images are streamed through the backend via `/api/media/:folder/:file`, keeping storage completely private.*

4. ***AWS IAM (Identity & Zero-Trust Security):***
   - *We did **not** hardcode any AWS access keys or secret tokens. EC2 assumes an IAM instance profile (`LabRole`) which signs requests using AWS Signature Version 4 via IMDSv2. If anyone inspects our server code, there are no credentials to leak."*

---

### Slide / Step 3: Live System Demonstration (2:30 – 4:30)
*(Switch to browser: [https://campusgigs-u70p.onrender.com](https://campusgigs-u70p.onrender.com))*

1. **Health Check Telemetry:**
   - *"First, let's observe our live cloud telemetry at `/api/health`. We can see the database connection is live with sub-50 millisecond latency and server uptime."*

2. **Login & Role Simulation:**
   - *"Let's log in as **Meera** (`meera@ves.ac.in`), a 3rd-year student who posted a gig for a React Landing Page."*
   - *"When we navigate to 'Posted by me', we see two freelancers have placed competitive bids (650 and 700 GigCoins). Notice how each student has a Level, XP, and Trust score."*

3. **Escrow Lock in Action:**
   - *"When Meera clicks **'Accept and hold'** on the 650 bid, watch the wallet balance: exactly 650 GigCoins move out of her available balance into Escrow. This runs in an ACID-compliant PostgreSQL transaction with row-level locks (`SELECT ... FOR UPDATE`). Neither user can tamper with the coins while the task is underway."*

4. **Delivery & Payout:**
   - *"Now, we log in as the freelancer, **Rohan** (`rohan@ves.ac.in`). In his dashboard under 'My Work', the status is now 'In Progress'. He uploads the project link and marks it 'Delivered'.*
   - *Switching back to Meera, she reviews the delivery and clicks **'Release Payment'**. The 650 coins immediately transfer to Rohan's wallet, and both students earn XP towards their next reputation level."*

---

### Slide / Step 4: Enterprise Testing & Dual-Cloud Resilience (4:30 – 5:30)
*"To guarantee bulletproof stability, we authored an automated test suite (`npm run test:flow`) that executes **42 continuous integration tests**:*
- *Testing unauthorized bidding, bid limits, and domain validation.*
- *Validating rollback scenarios: if a freelancer abandons a gig midway, the escrow engine automatically refunds the poster in full.*
- *Testing double-release prevention and wallet overdraft limits.*

*Lastly, while AWS Learner Lab provides our primary academic grading infrastructure, we introduced a **Dual-Cloud Strategy**: we containerized and deployed the full production build to **Render**, providing a permanent 24/7 public backup that never sleeps or shuts down when lab timers expire."*

---

### Slide / Step 5: Conclusion (5:30 – 6:00)
*"In conclusion, CampusGigs combines a real-world campus problem with a cloud architecture adhering to the AWS Well-Architected Framework: secure compute on EC2, isolated relational storage on RDS, private object storage on S3, and keyless IAM security.*

*Thank you for your time. I am now open to your questions."*

---

## Part 3: Anticipated Viva Q&A Defense (Cheat Sheet)

### Q1: Why did you choose Amazon RDS PostgreSQL over NoSQL (like DynamoDB or MongoDB)?
**Answer:**  
*"CampusGigs handles financial transactions and escrow balances. This requires strict **ACID compliance** (Atomicity, Consistency, Isolation, Durability). In PostgreSQL, we utilize transactions (`BEGIN ... COMMIT`) with row-level locks (`FOR UPDATE`). If anything fails midway between debiting the poster and funding the escrow account, the entire transaction rolls back cleanly. In NoSQL, multi-document transactions introduce complexity and eventual consistency risks that are undesirable for financial ledgers."*

### Q2: How is your database protected from internet attacks?
**Answer:**  
*"Our RDS instance uses Security Group Peering. The RDS Security Group (`rds-sg`) has an inbound rule for PostgreSQL port 5432 that strictly permits traffic coming from the security group of our EC2 instance (`ec2-sg`). It rejects all public IP traffic (`0.0.0.0/0`). This guarantees the database is completely unreachable from the outside world."*

### Q3: Why is your S3 bucket private if it serves image assets?
**Answer:**  
*"Allowing public write or public read on an S3 bucket violates the AWS Security Pillar and CIS benchmarks. By enabling **Block Public Access**, we prevent unauthorized hotlinking and data leaks. Our backend acts as a secure streaming proxy: when a client requests `/api/media/gigs/logo.svg`, the server verifies the request and streams the S3 object securely."*

### Q4: How does the application connect to S3 from EC2 without an Access Key?
**Answer:**  
*"We attached an IAM Instance Profile (`LabInstanceProfile`) with the `LabRole` to our EC2 instance. When our Node.js AWS SDK creates an `S3Client`, it automatically queries the local AWS Instance Metadata Service (IMDSv2 at `http://169.254.169.254/latest/meta-data/`) to retrieve short-lived, auto-rotating security tokens. There are zero secrets in our `.env` or Git repository."*

### Q5: What database performance optimizations did you make?
**Answer:**  
*"We implemented B-Tree indexes: `idx_bids_gig` on `bids(gig_id)` to quickly load bids without sequential scans, `idx_gigs_category` for marketplace category filtering, and `idx_users_email` for instant authentication. In addition, we tuned the connection pool (`pg.Pool`) with a maximum of 20 clients and a 30-second idle client reap cycle."*
