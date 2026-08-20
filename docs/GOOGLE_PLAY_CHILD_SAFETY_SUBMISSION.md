# Google Play Child Safety Standards — Submission Guide

## App Information
- **Package**: com.raonson.app
- **App Name**: Raonson
- **Contact**: ehsonmahmadmurodov@gmail.com

## Play Console Steps

### 1. App Content > Child Safety Standards

1. Go to **Google Play Console** > **Policy and programs** > **App content**
2. Select **Child Safety Standards**
3. Fill in the form:

### 2. Published Standards URL

Enter the public URL for your child safety standards page:

```
https://mahmadmurodov-raonson.hf.space/child-safety
```

This page is served as HTML (not JSON) and is accessible without authentication.

### 3. Designated Contact

- **Name**: Ehson Mahmadmurodov
- **Email**: ehsonmahmadmurodov@gmail.com
- **Response time**: Within 24 hours for child safety reports

### 4. In-App Reporting Mechanism

Describe how users can report child safety violations:

> Users can report any content type (posts, reels, stories, comments, messages, and user profiles) by tapping the report button (flag icon) on any content. The first option in the report menu is "Child Safety" (Бехатарии кӯдакон), highlighted in red. Users can select a reason category and optionally provide a text description. All child safety reports are prioritized for immediate review by moderators.

### 5. Moderation Process

Describe your content moderation workflow:

> Reports follow a structured workflow: Pending → Under Review → Action Taken / Dismissed / Resolved. Each moderation action records the moderator ID and timestamp for audit trail. Child safety reports are highlighted in the admin panel and appear first. Enforcement actions include content removal, account suspension, and reporting to NCMEC.

### 6. Age Restriction

- Minimum age: **13 years old**
- Age verification: Users confirm age during registration
- Underage accounts: Terminated upon identification

### 7. CSAM/CSAE Handling

> Raonson maintains zero tolerance for CSAM/CSAE. Upon detection or confirmed report: content is immediately removed, the account is permanently banned, evidence is preserved, and a report is filed with NCMEC and relevant law enforcement authorities.

## Verification Checklist

Before submitting, verify:

- [x] Public child safety page accessible at /child-safety (HTML, no auth)
- [x] Community guidelines accessible at /community-guidelines (HTML, no auth)
- [x] In-app reporting available on all 6 content types (posts, reels, stories, comments, messages, profiles)
- [x] "Child Safety" is the first/highlighted report category
- [x] Report includes optional text description field
- [x] Moderation workflow: pending → under_review → action_taken/dismissed/resolved
- [x] Audit trail: reviewed_at timestamp + moderator_id on all report tables
- [x] CSAM/CSAE language in Terms of Service and Privacy Policy
- [x] In-app Child Safety Standards page in Settings
- [x] Community Guidelines page in Settings
- [x] Contact email: ehsonmahmadmurodov@gmail.com
- [x] Minimum age requirement: 13+
