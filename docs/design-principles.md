# Design principles

## The 90-9-1 rule

Online communities tend to split roughly 90% lurkers, 9% occasional contributors, 1% heavy
creators. The app is built for that distribution rather than for the 1% who are easiest to
imagine:

- **Reading never requires an account.** The feed, profiles and hashtag pages are all public.
  Requiring sign-up to read would wall off the group that makes up most of the traffic.
- **Signing in is required only to write.** Authentication guards `create`, `update` and
  `destroy` — never `index` or `show`.
- **Posting stays cheap.** The composer is on the feed itself, not behind a separate page, so
  the occasional contributor is never more than one click from posting.
- **Power-user tooling comes last, not first.** Managing your own posts in bulk, drafts and
  scheduling serve the 1%; they are deliberately absent until the other two groups are served.

The practical consequence is a **public global feed plus a personal profile**, not a private
per-user feed. "Your feed" means the posts you wrote and can manage, not a separate timeline
only you can see. A personalised timeline needs the follow graph and arrives in milestone 7 — see the [roadmap](roadmap.md).

## Ownership over visibility

Everything is readable by everyone; only *writes* are restricted. A post can be edited or
deleted by its author and nobody else. This is enforced by scoping queries through the
association — `Current.user.posts.find(params[:id])` — rather than by fetching a record and
then checking who owns it, so a missing check cannot silently expose someone else's row.
