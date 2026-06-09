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
- Photo: max 10 MB, max 10 per post
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
- Write traffic: max 100 MB/s (upload of photos + metadata)

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

### Additional technical requirements

#### CDN & media delivery
- All photos must be served via CDN.
- Peak CDN egress bandwidth: ≥ 5 Tbps.
- CDN must have Points of Presence (PoP) in Russia, Kazakhstan, Tajikistan.

#### Storage tiering (always stored)
- Hot storage (SSD) for last 6 months of photos.
- Cold storage (S3-compatible, HDD) for older photos and all metadata.
- Automatic migration policy: move photos older than 6 months to cold tier.
