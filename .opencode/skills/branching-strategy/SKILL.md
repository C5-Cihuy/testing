---
name: branching-strategy
description: Use when creating, naming, switching, merging, or deleting git branches, or when opening pull requests in this repository. Enforces the task → story → epic → main branch hierarchy with PRs at every level, and derives branch names from the Epic/Story/Task issues managed by the issue-management skill.
---

# Branching Strategy

Use this skill to ensure all branches adhere to the task -> story -> epic -> main hierarchy, are named after their issue, and merge only one level up at a time.

## Branch Hierarchy

```
main
 └── epic/N-slug            (from issue "Epic N: ...")
      └── story/N-N-slug    (from issue "Story N.N: ...")
           └── task/N-N-N-slug  (from issue "Task N.N.N: ...")
```

- Commits happen directly on `task/*` branches only.
- Every merge moves exactly one level up: task -> story -> epic -> main. Never skip a level.
- `main` receives code only via an epic branch PR.

## Branch Naming

Derive the branch name from the GitHub issue title in the issue-management hierarchy (`issue-management` skill; local mirror in `.issues/`):

1. Take the hierarchical number from the title and replace dots with dashes (e.g. `1.1.1` -> `1-1-1`).
2. Slugify the title remainder: lowercase, spaces -> hyphens, strip characters other than alphanumerics and hyphens, collapse repeated hyphens, trim leading/trailing hyphens.
3. Compose: `<epic|story|task>/<dashed-number>-<slug>`.

Examples:

| Issue title | Branch |
| ----------- | ------ |
| `Epic 1: Playing Card Foundation` | `epic/1-playing-card-foundation` |
| `Story 1.1: Recognize a card by its rank and suit` | `story/1-1-recognize-a-card-by-its-rank-and-suit` |
| `Task 1.1.1: Define the rank and suit value sets` | `task/1-1-1-define-the-rank-and-suit-value-sets` |

Never use the GitHub issue number (`#5`) in a branch name — only the hierarchical number.

## Creating Branches

Before creating a branch, confirm the issue exists and is approved (Tasks only after the parent Story is approved). If the parent branch does not exist yet, create it first (recursively up to `main`).

- `task/N-N-N-slug`: create from its parent story branch.
- `story/N-N-slug`: create from its parent epic branch.
- `epic/N-slug`: create from `main`.

Create with: `git checkout -b <branch> <parent-branch>`.

## Keeping Branches Current

Before opening a PR, merge the target (parent) branch into the source branch so the PR merges cleanly, then push:

```
git checkout <child-branch>
git merge <parent-branch>
git push -u origin <child-branch>
```

## Pull Requests & Merging

- **Resolve the repository first.** Run `git remote get-url origin`, parse `owner/repo` from SSH (`git@github.com:owner/repo.git`) or HTTPS (`https://github.com/owner/repo.git`) form, and strip the `.git` suffix. Never hardcode or guess a repository name.
- Open a PR for every merge with `github_create_pull_request`:
  - base = parent branch (`story`, `epic`, or `main`), head = child branch.
  - Title: `<type>: <issue summary>` using the commit convention already used in the repo (e.g. `feat: ...`, `chore: ...`).
  - Body: brief summary, link to the issue it implements, and the verification performed.
- Wait for checks/review to pass, then merge with `github_merge_pull_request` using `merge_method: merge` (merge commits preserve granular task history).
- **Merge authority:** merge task -> story and story -> epic PRs autonomously once checks pass. Always ask the user for confirmation before merging an epic -> `main` PR.

## Cleanup

After a PR is merged:

1. Delete the remote branch (`github_delete_file` is not for branches — use the GitHub MCP/REST API or `git push origin --delete <branch>`).
2. Delete the local branch: `git branch -d <branch>`.
3. Never delete or reuse a branch that has unmerged commits.

## Integration with Issue Management

- Branch names come from issues created per the `issue-management` skill (`.opencode/skills/issue-management/SKILL.md`). One branch per issue, at the level matching its label (`epic`, `story`, `task`).
- Reference the issue number in the PR body (e.g. `Closes #5`) so GitHub links the hierarchy back to the branch.
- When an issue is closed, its branch should already be merged; if not, flag it instead of closing silently.
