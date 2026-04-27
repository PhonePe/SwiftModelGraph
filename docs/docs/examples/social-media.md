---
id: social-media
title: Social Media Example
sidebar_label: Social Media
sidebar_position: 3
---

# Social Media Example

A social media platform example with user profiles, posts, conversations, notifications, and hashtags. This example also demonstrates polymorphic types.

## Models

### UserProfile

```swift
@ChimeraMetaData(description: "A user's public profile on the platform")
@ChimeraSchema(key: "user-profile")
struct UserProfile {
    @ChimeraProperty(description: "User unique identifier")
    let id: String

    @ChimeraProperty(description: "Username (handle)", minLength: 3, maxLength: 30, pattern: "^[a-zA-Z0-9_]+$")
    let username: String

    @ChimeraProperty(description: "Display name", maxLength: 60)
    let displayName: String

    @ChimeraProperty(description: "Bio text", maxLength: 280)
    let bio: String?

    @ChimeraProperty(description: "Profile picture URL")
    let avatarUrl: URL?

    @ChimeraProperty(description: "Number of followers", min: 0)
    let followerCount: Int

    @ChimeraProperty(description: "Number of accounts followed", min: 0)
    let followingCount: Int

    @ChimeraProperty(description: "Whether the account is verified")
    let isVerified: Bool

    @ChimeraProperty(description: "Account creation date")
    let joinedAt: Date
}
```

### Post

```swift
@ChimeraMetaData(description: "A user-created post (text, image, or video)")
@ChimeraSchema(key: "post")
struct Post {
    @ChimeraProperty(description: "Post identifier")
    let id: String

    @ChimeraProperty(description: "Author's user ID")
    let authorId: String

    @ChimeraProperty(description: "Post text content", maxLength: 500)
    let text: String?

    @ChimeraProperty(description: "Attached media items", maxItems: 4)
    let mediaItems: [MediaAttachment]

    @ChimeraProperty(description: "Hashtags used in this post")
    let hashtags: [String]

    @ChimeraProperty(description: "Reply-to post ID (null for top-level posts)")
    let replyToId: String?

    @ChimeraProperty(description: "Like count", min: 0)
    let likeCount: Int

    @ChimeraProperty(description: "Repost count", min: 0)
    let repostCount: Int

    @ChimeraProperty(description: "Posted timestamp")
    let postedAt: Date
}
```

### Notification (Polymorphic)

This example demonstrates polymorphic notifications — a notification can be a `LikeNotification`, `FollowNotification`, or `ReplyNotification`.

```swift
// Protocol with discriminator
@PolymorphicMapping(
    key: "type",
    mappings: [
        "like": LikeNotification.self,
        "follow": FollowNotification.self,
        "reply": ReplyNotification.self
    ]
)
protocol Notification {}

@ChimeraMetaData(description: "A notification that someone liked a post")
@ChimeraSchema(key: "like-notification")
struct LikeNotification: Notification {
    @ChimeraProperty(description: "Notification ID")
    let id: String

    @ChimeraProperty(description: "User who liked")
    let fromUserId: String

    @ChimeraProperty(description: "Post that was liked")
    let postId: String

    @ChimeraProperty(description: "When it occurred")
    let timestamp: Date

    @ChimeraProperty(description: "Whether the user has seen this notification")
    let isRead: Bool
}

@ChimeraMetaData(description: "A notification that someone followed the user")
@ChimeraSchema(key: "follow-notification")
struct FollowNotification: Notification {
    @ChimeraProperty(description: "Notification ID")
    let id: String

    @ChimeraProperty(description: "User who followed")
    let fromUserId: String

    @ChimeraProperty(description: "When it occurred")
    let timestamp: Date

    @ChimeraProperty(description: "Whether the user has seen this notification")
    let isRead: Bool
}
```

### NotificationFeed

```swift
@ChimeraMetaData(description: "A paginated feed of notifications for a user")
@ChimeraSchema(key: "notification-feed")
struct NotificationFeed {
    @ChimeraProperty(description: "The user this feed belongs to")
    let userId: String

    @ChimeraProperty(description: "Notifications, newest first", maxItems: 50)
    let items: [Notification]   // Polymorphic! → oneOf schema

    @ChimeraProperty(description: "Unread count", min: 0)
    let unreadCount: Int

    @ChimeraProperty(description: "Cursor for next page")
    let nextCursor: String?
}
```

### Hashtag

```swift
@ChimeraMetaData(description: "A hashtag topic")
@ChimeraSchema(key: "hashtag")
struct Hashtag {
    @ChimeraProperty(description: "Hashtag text without the # symbol", pattern: "^[a-zA-Z0-9_]+$")
    let tag: String

    @ChimeraProperty(description: "Number of posts using this hashtag in the last 24 hours", min: 0)
    let postCount24h: Int

    @ChimeraProperty(description: "Whether this hashtag is currently trending")
    let isTrending: Bool
}
```

## Running the Generator

```bash
model-graph-generator \
  --source-path ./Sources/Models/Social \
  --output ./schemas/social.json \
  --json-schema \
  --macro-only
```

## Generated Schema — Polymorphic oneOf (excerpt)

The `NotificationFeed.items` property becomes a `oneOf` array:

```json
"items": {
  "type": "array",
  "maxItems": 50,
  "description": "Notifications, newest first",
  "items": {
    "oneOf": [
      { "$ref": "#like-notification" },
      { "$ref": "#follow-notification" },
      { "$ref": "#reply-notification" }
    ],
    "discriminator": {
      "propertyName": "type",
      "mapping": {
        "like": "#like-notification",
        "follow": "#follow-notification",
        "reply": "#reply-notification"
      }
    }
  }
}
```

## Key Patterns Demonstrated

| Pattern | Where Used |
|---------|-----------|
| Username regex | `UserProfile.username` (`^[a-zA-Z0-9_]+$`) |
| `maxLength` for social text | `Post.text` (500), bio (280) |
| `maxItems` on arrays | `Post.mediaItems` (4), `NotificationFeed.items` (50) |
| Polymorphic `oneOf` | `NotificationFeed.items → Notification` |
| `@PolymorphicMapping` | `LikeNotification`, `FollowNotification`, `ReplyNotification` |
| Self-pagination cursor | `NotificationFeed.nextCursor` (optional string) |
| Counters with `min: 0` | `likeCount`, `followerCount`, `postCount24h` |
