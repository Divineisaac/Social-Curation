# Content Curation Smart Contract

A decentralized content curation platform built on Stacks blockchain that allows users to submit, vote, tip, and manage content across different categories.

## Features

- Content submission with categorization
- Upvoting and downvoting mechanism
- Creator tipping system
- Content reporting functionality
- User reputation tracking
- Administrator controls
- Category management

## Core Functions

### For Users

#### Content Submission
```clarity
(submit-content (content_title (string-ascii 100)) (content_url (string-ascii 200)) (content_category (string-ascii 20)))
```
- Submit new content with a title, URL, and category
- Requires payment of submission fee
- Returns content ID on successful submission

#### Voting
```clarity
(vote-on-content (content_id uint) (vote_value int))
```
- Vote on content (1 for upvote, -1 for downvote)
- Affects both content score and voter's reputation
- One vote per user per content item

#### Tipping
```clarity
(send-tip (content_id uint) (tip_amount uint))
```
- Send STX tokens to content creators
- Requires sufficient balance
- Tips are tracked and displayed with content

#### Reporting
```clarity
(report-content (content_id uint))
```
- Report inappropriate content
- Cannot report own content
- Increases report count for moderation

### For Administrators

#### Fee Management
```clarity
(update-submission-fee (new_fee uint))
```
- Update the content submission fee
- Only callable by contract administrator

#### Content Removal
```clarity
(remove-content (content_id uint))
```
- Remove inappropriate content
- Only callable by contract administrator

#### Category Management
```clarity
(add-category (new_category (string-ascii 20)))
```
- Add new content categories
- Limited to 10 categories total
- Only callable by contract administrator

### Read-Only Functions

#### Content Retrieval
```clarity
(get-content-details (content_id uint))
```
- Get detailed information about specific content

#### User Information
```clarity
(get-user-reputation (user_address principal))
```
- Get user's reputation score

#### Content Discovery
```clarity
(get-top-content (limit uint))
```
- Get list of top-rated content
- Filtered by positive vote count

## Data Structure

### Content Item
```clarity
{
    content_creator: principal,
    content_title: (string-ascii 100),
    content_url: (string-ascii 200),
    content_category: (string-ascii 20),
    submission_block_height: uint,
    vote_count: int,
    tip_amount: uint,
    report_count: uint
}
```

### User Vote
```clarity
{
    voter: principal,
    content_id: uint,
    vote_value: int
}
```

### User Reputation
```clarity
{
    user_address: principal,
    reputation_score: int
}
```

## Constraints

- Content titles must be non-empty and under 100 characters
- URLs must be at least 10 characters and under 200 characters
- Categories must be predefined by administrator
- Maximum of 10 categories allowed
- Voting limited to +1 or -1 values
- Users cannot report their own content
- Content submission requires fee payment in STX

## Error Codes

- `ERROR_NOT_AUTHORIZED (u100)`: Unauthorized access attempt
- `ERROR_INVALID_CONTENT_SUBMISSION (u101)`: Invalid content submission
- `ERROR_CONTENT_EXISTS (u102)`: Duplicate content
- `ERROR_CONTENT_NOT_FOUND (u103)`: Content not found
- `ERROR_INSUFFICIENT_FUNDS (u104)`: Insufficient balance
- `ERROR_INVALID_CONTENT_CATEGORY (u105)`: Invalid category
- `ERROR_INVALID_REPORT (u106)`: Invalid report attempt
- `ERROR_NUMERIC_OVERFLOW (u107)`: Numeric overflow
- `ERROR_INVALID_VOTE (u108)`: Invalid vote value
- `ERROR_INVALID_CONTENT_ID (u109)`: Invalid content ID

## Security Considerations

1. **Access Control**
   - Administrative functions restricted to contract owner
   - Users cannot manipulate others' content

2. **Economic Security**
   - Submission fee prevents spam
   - Balance checks before transfers
   - Secure STX transfer implementation

3. **Data Validation**
   - Input length validation
   - Category validation
   - Vote value validation

## Usage Example

1. Submit new content:
```clarity
(submit-content "My First Post")
```

2. Vote on content:
```clarity
(vote-on-content u1 1) ;; Upvote content ID 1
```

3. Send tip to creator:
```clarity
(send-tip u1 u100) ;; Send 100 STX to content ID 1's creator
```

4. Report content:
```clarity
(report-content u1) ;; Report content ID 1
```