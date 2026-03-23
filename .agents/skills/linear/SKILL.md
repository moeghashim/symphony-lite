---
name: linear
description: |
  Linear GraphQL patterns for Symphony agents. Use `linear_graphql` for all
  operations and `sync_workpad` for workpad updates. Never use schema introspection.
---

# Linear GraphQL

All Linear operations go through the client tools exposed by Symphony's app
server. `linear_graphql` handles raw GraphQL calls; `sync_workpad` pushes a
local markdown workpad into the persistent Linear comment with a smaller
conversation footprint.

```json
{
  "query": "query or mutation document",
  "variables": { "optional": "graphql variables" }
}
```

One operation per tool call. A top-level `errors` array means the operation
failed even if the tool call completed.

## Workpad

Maintain a local `workpad.md` in your workspace. Edit it freely, then sync to
Linear at milestones such as plan finalized, implementation complete, and
validation complete.

- First sync: call `sync_workpad` with `issue_id` and `file_path`, then save the
  returned comment id to `.workpad-id`.
- Subsequent syncs: read `.workpad-id` and pass it back as `comment_id` so the
  same Linear comment is updated in place.

## Query an issue

The orchestrator injects issue context into the prompt at startup. Re-read only
when you need fresh issue data.

```graphql
query($key: String!) {
  issue(id: $key) {
    id
    identifier
    title
    url
    description
    state { id name type }
    project { id name }
  }
}
```

For comments and attachments:

```graphql
query($id: String!) {
  issue(id: $id) {
    comments(first: 50) { nodes { id body user { name } createdAt } }
    attachments(first: 20) { nodes { url title sourceType } }
  }
}
```

## State transitions

Fetch team states first, then move with the exact `stateId`:

```graphql
query($id: String!) {
  issue(id: $id) {
    team { states { nodes { id name } } }
  }
}
```

```graphql
mutation($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: { stateId: $stateId }) {
    success
    issue { state { name } }
  }
}
```

## Attach a PR or URL

```graphql
mutation($issueId: String!, $url: String!, $title: String) {
  attachmentLinkGitHubPR(issueId: $issueId, url: $url, title: $title, linkKind: links) {
    success
  }
}
```

```graphql
mutation($issueId: String!, $url: String!, $title: String) {
  attachmentLinkURL(issueId: $issueId, url: $url, title: $title) {
    success
  }
}
```

## File upload

Use `fileUpload` to request an upload URL, `curl` to PUT the bytes, then embed
the returned `assetUrl` in the workpad as markdown image or video links.

```graphql
mutation($filename: String!, $contentType: String!, $size: Int!) {
  fileUpload(filename: $filename, contentType: $contentType, size: $size, makePublic: true) {
    success
    uploadFile { uploadUrl assetUrl headers { key value } }
  }
}
```

## Issue creation

Resolve project and team IDs first, then create the issue:

```graphql
query($slug: String!) {
  projects(filter: { slugId: { eq: $slug } }) {
    nodes { id teams { nodes { id key states { nodes { id name } } } } }
  }
}
```

```graphql
mutation($input: IssueCreateInput!) {
  issueCreate(input: $input) {
    success
    issue { identifier url }
  }
}
```

## Rules

- No introspection. Never use `__type` or `__schema` queries.
- Keep GraphQL selections narrow.
- Sync the workpad at milestones, not after every small change.
- For state transitions, always fetch team states first.
- Prefer `attachmentLinkGitHubPR` over a generic URL attachment for GitHub PRs.
