---
id: blog-cms
title: Blog / CMS Example
sidebar_label: Blog / CMS
sidebar_position: 2
---

# Blog / CMS Example

A content management system (CMS) example covering blog posts, pages, and media files.

## Models

### BlogPost

```swift
@ChimeraMetaData(description: "A blog post article")
@ChimeraSchema(key: "blog-post")
struct BlogPost {
    @ChimeraProperty(description: "Post unique identifier")
    let id: String

    @ChimeraProperty(description: "Post URL slug", minLength: 1, maxLength: 100, pattern: "^[a-z0-9-]+$")
    let slug: String

    @ChimeraProperty(description: "Post title", minLength: 1, maxLength: 300)
    let title: String

    @ChimeraProperty(description: "Post body in Markdown format")
    let body: String

    @ChimeraProperty(description: "Short summary for previews", maxLength: 500)
    let excerpt: String?

    @ChimeraProperty(description: "Author user ID")
    let authorId: String

    @ChimeraProperty(description: "Canonical tag identifiers")
    let tags: [String]

    @ChimeraProperty(description: "Publication status")
    let status: PostStatus

    @ChimeraProperty(description: "When the post was published")
    let publishedAt: Date?

    @ChimeraProperty(description: "Cover image")
    let coverImage: MediaFile?
}

enum PostStatus: String {
    case draft, published, archived
}
```

### Page

```swift
@ChimeraMetaData(description: "A static CMS page")
@ChimeraSchema(key: "page")
struct Page {
    @ChimeraProperty(description: "Page identifier")
    let id: String

    @ChimeraProperty(description: "URL path", pattern: "^/.*$")
    let path: String

    @ChimeraProperty(description: "Page title")
    let title: String

    @ChimeraProperty(description: "Page content in Markdown")
    let content: String

    @ChimeraProperty(description: "SEO metadata title")
    let metaTitle: String?

    @ChimeraProperty(description: "SEO meta description", maxLength: 160)
    let metaDescription: String?

    @ChimeraProperty(description: "Whether the page is publicly visible")
    let isPublished: Bool

    @ChimeraProperty(description: "Last updated timestamp")
    let updatedAt: Date
}
```

### MediaFile

```swift
@ChimeraMetaData(description: "An uploaded media asset (image, video, or document)")
@ChimeraSchema(key: "media-file")
struct MediaFile {
    @ChimeraProperty(description: "Media file identifier")
    let id: String

    @ChimeraProperty(description: "File name with extension")
    let filename: String

    @ChimeraProperty(description: "MIME type (e.g. 'image/jpeg')")
    let mimeType: String

    @ChimeraProperty(description: "File size in bytes", min: 1)
    let sizeBytes: Int

    @ChimeraProperty(description: "CDN URL for the original file")
    let url: URL

    @ChimeraProperty(description: "Thumbnail URL for images/videos")
    let thumbnailUrl: URL?

    @ChimeraProperty(description: "Alt text for images")
    let altText: String?

    @ChimeraProperty(description: "Upload timestamp")
    let uploadedAt: Date
}
```

## Running the Generator

```bash
model-graph-generator \
  --source-path ./Sources/Models/CMS \
  --output ./schemas/cms.json \
  --json-schema \
  --macro-only
```

## Generated Schema (excerpt)

```json
[
  {
    "schemaId": "blog-post",
    "schemaDefinition": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
      "id": { "type": "string", "description": "Post unique identifier" },
      "slug": {
        "type": "string",
        "description": "Post URL slug",
        "minLength": 1,
        "maxLength": 100,
        "pattern": "^[a-z0-9-]+$"
      },
      "title": { "type": "string", "description": "Post title", "minLength": 1, "maxLength": 300 },
      "body": { "type": "string", "description": "Post body in Markdown format" },
      "excerpt": { "type": "string", "description": "Short summary for previews", "maxLength": 500 },
      "authorId": { "type": "string", "description": "Author user ID" },
      "tags": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Canonical tag identifiers"
      },
      "status": {
        "type": "string",
        "description": "Publication status",
        "enum": ["draft", "published", "archived"]
      },
      "publishedAt": { "type": "string", "format": "date-time", "description": "When the post was published" },
      "coverImage": { "$ref": "#media-file", "description": "Cover image" }
    },
    "required": ["id", "slug", "title", "body", "authorId", "tags", "status"]
    },
    "metaData": { "description": "A blog post article" }
  }
]
```

## Key Patterns Demonstrated

| Pattern | Where Used |
|---------|-----------|
| Regex pattern constraint | `BlogPost.slug` (`^[a-z0-9-]+$`) |
| `maxLength` on optional | `BlogPost.excerpt` |
| Optional date | `BlogPost.publishedAt` |
| Enum with string raw values | `BlogPost.status` |
| Nested `$ref` | `BlogPost.coverImage → #media-file` |
| URL path pattern | `Page.path` (`^/.*$`) |
| URI-formatted URL | `MediaFile.url`, `MediaFile.thumbnailUrl` |
| Byte-size minimum | `MediaFile.sizeBytes` (`min: 1`) |
