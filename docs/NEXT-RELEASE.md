<!--
  Release notes for the version in development.

  Written in one pass, before a release goes out. Not from every PR.

  Editing this file in every PR means every PR appends to the same list under the same
  anchor, so they conflict with each other even when the entries have nothing to do with
  one another. Each conflict costs a merge commit and a full CI run, and the same text
  gets reviewed again in every PR that happened to touch the file.

  One pass also keeps the original goal, which is that there is one set of notes to read
  and approve. The pass before the next prerelease only adds what merged since the last
  one, so it stays a small diff to review.

  Write the pass from the PRs merged since the last release. Their descriptions carry the
  reasoning, so this is not reconstructing anything from raw commit messages.

  The file is copied into the GitHub release body as it is, HTML comments do not render.
  When the stable release ships it is copied one last time, then emptied for the next line.

  Anchors are prefixed with the release line (6.3.0-...) so they stay valid across the
  prereleases and do not collide with other releases on the /releases page.
-->
