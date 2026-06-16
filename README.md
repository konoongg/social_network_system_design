# Social Network System Design (исправленная версия)

## Functional requirements
- CRUD for posts
- Adding photos (max 10 MB, max 10 per post), description (max 500 chars), geo to posts
- CRUD for comments (max 200 chars) and marks (likes) on posts
- Subscribe / unsubscribe from user
- Ranking of places by popularity (based on unique posts/authors last 7 days)
- Formation of a news feed for subscriptions and recommendations in reverse chronological order
- Russian language; support for national languages of CIS countries (Unicode, normalization for search)

## Non-functional requirements

### General
- **DAU**: 10 000 000 after 1 year, linear growth
- **Connections (concurrent)**: 10 000 000 × 0.1 = 1 000 000
- **Geographic scope**: only CIS countries
- **Availability**: 99.99% (≈ 52 minutes downtime per year)
- **Durability**: posts, marks, comments are always stored (no deletion)
- **Seasonality**: peak load factor = 2× during holidays (e.g., New Year)
- **Geo-distribution**: mandatory data residency for Russia, Tajikistan, Kazakhstan (primary data never leaves territory). Other CIS countries may adopt similar laws.
- **RTO** (Recovery Time Objective): < 30 minutes
- **RPO** (Recovery Point Objective): ≤ 5 minutes
- **Latency**: p99 < 300 ms for feed loading, p99 < 100 ms for like/comment write

### User asymmetry
- 1% of users actively create content (3 posts/day) and may have up to 10 000 000 subscribers
- 99% of users create average 1 post/month

### Posts
- Photo: max 2 MB, max 10 per post
- Description: max 500 chars (1000 bytes)
- Comments per post: max 1000, average 20
- 0.1% of posts have a large number of comments (close to 1000)

### Traffic estimates

#### Read (feed)
- Average user reads 300 posts/day
- Feed request: 50 posts per request
- Requests per second:
  `(10 000 000 × 300) / 86 400 / 50 ≈ 700 RPS` (feed requests)
- Read traffic (metadata only, no photos):
  Average metadata size per post = 2 KB (incl. description, like counter, comment counter, geo, CDN URLs)
  `700 req/s × 50 posts × 2 KB = 70 MB/s`
  (if early comments are included – add ~30% → 90 MB/s)


##### Write (posts)
- Write RPS:
  `(10 000 000 × 0.99 × 0.05 + 10 000 000 × 0.01 × 3) / 86 400 ≈ 10 RPS`
- Write traffic: max 20 MB/s + 20 KB/s (upload of photos + metadata)

#### Marks (likes)
- Average user creates 20 likes/day
- Write RPS: `20 × 10M / 86 400 ≈ 230 RPS`
- Write traffic: ~2 KB/s
- **Read likes**: each viewed post requires like counter → 35 000 RPS

#### Comments
- Average user creates 2 comments/day
- Write RPS: `10M × 2 / 86 400 ≈ 230 RPS`
- Write traffic: `230 × 400 bytes ≈ 92 KB/s`
- **Read comments**: user views comments under posts. Assume pagination (first 20 comments).
  `10M × 300 posts/day × 20 comments = 60B comment views/day` → ~694 000 RPS.
- Read  traffic: `694 000 × 400 bytes ≈ 265 MB/s`

## disk evaluation for 1 year

### Posts
 - use postgres for posts
 - capacity: 20kb/s (meta data + des) * 86400 * 365 =  ~600 GB
 - Raid: 2
 - Disks_for_capacity: 600 GB / 32 TB (HDD)  = 1 (or 1 ssd)
 - Disks_for_throughput = 20 kb/s / 100 MB/S = 1 (or 1 ssd)
 - Disks_for_iops = 700 / 100 (HDD) = 7 (or 1 ssd)
 - Disks: 14 hdd or 2 ssd

### Marks (likes)
 - use postgres
 - capacity: 2kb/s * 86400 * 365 = ~60 GB
 - Raid: 2
 - Disks_for_capacity: 60 GB / 32 TB (HDD) * RAID = 2
 - Disks_for_throughput = 2 kb/s / 100 MB/S = 1 (or 1 ssd)
 - Disks_for_iops = 230 / 100 (HDD) = 3 (or 1 ssd)
 - Disks: 6 hdd or 2 ssd

### Comments
 - use postgres
 - capacity: 100kb/s  * 86400 * 365 = ~3 TB
 - Raid: 2
 - Disks_for_capacity: 60 GB / 32 TB (HDD) * RAID = 2
 - Disks_for_throughput = 100 kb/s / 100 MB/S = 1 (or 1 ssd)
 - Disks_for_iops = 230 / 100 (HDD) = 3 (or 1 ssd)
 - Disks: 6 hdd or 2 ssd


### media
- use s3
- capacity: 20mb/s * 86400 * 365 = ~600 TB
- Raid: 2
- Disks_for_capacity: 600 TB / 32 TB (HDD) = 20  (or 1 SSD sata)
- Disks_for_throughput = 20 mb/s / 100 MB/S = 1 (or 1 ssd)
- Disks_for_iops = 10 / 100 (HDD) = 1 (or 1 ssd)
- Disks: 40 hdd or 40 ssd nvme or 2 ssd sata
