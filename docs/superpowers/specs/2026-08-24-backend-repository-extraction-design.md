# NaviPet Backend Repository Extraction Design

Date: 2026-08-24

Status: Revised in chat; awaiting written-spec review

## Purpose

Extract NaviPet's Fastify server and Supabase database definition from the
Flutter repository into a standalone public GitHub repository. The result must
retain relevant Git history, remain independently buildable, and leave the
Flutter repository focused on the mobile client.

## Repository Ownership

The public `Ben2104/NavipetBackend` repository will own:

- The Fastify application currently under `backend/`.
- The Supabase schema currently at `supabase/schema.sql`.
- Future Supabase migrations, RLS policies, triggers, and server-only database
  infrastructure.
- Backend environment documentation and server deployment instructions.

The `Ben2104/NaviPetFlutter` repository will continue to own:

- Flutter application code and tests.
- Supabase client authentication and session handling.
- The public Supabase project URL and publishable/anonymous client key
  contract.
- Mobile platform and build configuration.

Moving the schema does not change runtime behavior. Flutter currently talks to
Supabase directly and may continue doing so until domain APIs are migrated to
Fastify. Flutter must never contain a Supabase service-role key or other
server-only secret.

## Extraction Strategy

Use `git filter-repo` in a temporary clone of `NaviPetFlutter`. Never rewrite
the source repository's history.

The filtered repository will retain only:

- `backend/`, rewritten so its contents become the new repository root.
- `supabase/`, retained at the repository root.

Filtering preserves relevant commits, authors, dates, and blame information
while dropping unrelated Flutter paths. After filtering, one cleanup commit
will add or adjust repository-level metadata and links.

`git subtree split` is rejected because it handles one prefix cleanly but does
not preserve the combined history of `backend/` and `supabase/` without extra
history manipulation. A fresh copy is rejected because it loses the audit
trail.

## Backend Repository Layout

The initial repository will have this structure:

```text
NavipetBackend/
├── src/
├── tests/
├── supabase/
│   └── schema.sql
├── package.json
├── package-lock.json
├── tsconfig.json
├── tsconfig.build.json
├── eslint.config.js
├── vitest.config.ts
├── .env.example
├── .gitignore
└── README.md
```

The existing `backend/README.md` becomes the root `README.md`. It will be
updated for root-level commands and Supabase schema ownership. A root
`.gitignore` will exclude `.env`, `node_modules/`, `dist/`, `coverage/`, logs,
and common editor or operating-system files.

No Dockerfile, hosting-provider manifest, or CI workflow will be added in this
extraction. The backend remains deployment-neutral and runs with the existing
`npm run build` and `npm start` commands.

## Flutter Repository Cleanup

Work will occur on branch `chore/extract-backend`.

The cleanup will:

- Delete the tracked `backend/` directory.
- Delete the tracked `supabase/` directory.
- Delete `docs/superpowers/plans/` and `docs/superpowers/specs/`, including
  this temporary extraction design after it has guided implementation.
- Add `/docs/superpowers/` to `.gitignore` so future local Superpowers planning
  artifacts stay untracked.
- Remove backend-only ignore rules from the root `.gitignore`.
- Update `README.md` so backend setup and schema instructions link to
  `https://github.com/Ben2104/NavipetBackend`.
- Update `docs/PROJECT_MAP.md` so backend ownership points to the external
  repository.
- Keep Flutter source, tests, public environment configuration, and direct
  Supabase runtime behavior unchanged.

The branch will be pushed to `Ben2104/NaviPetFlutter`, and a pull request will
be opened against `main`. The pull request will not be merged automatically.

## Secrets and Generated Files

Ignored or generated files must not enter the new repository or Git history.
This includes:

- `backend/.env`
- `backend/node_modules/`
- `backend/dist/`
- `backend/coverage/`
- Flutter root `.env`
- Supabase service-role keys, MultiSet credentials, bearer tokens, and other
  live credentials

Only `.env.example` is transferred. Before publication, inspect tracked files
and filtered history for high-risk secret patterns. If any live credential is
found, stop publication, remove it from history, and report that it must be
rotated.

## Verification

Before publishing `NavipetBackend`, run from its root:

```bash
npm ci
npm test
npm run typecheck
npm run lint
npm run build
```

Confirm that `dist/server.js` exists after the build, ignored files remain
untracked, the expected history is present, and repository searches find no
Flutter implementation files or live credentials.

Before opening the Flutter pull request, run:

```bash
flutter analyze
flutter test
```

Also confirm that no tracked documentation link points to the removed local
backend or schema paths, and that the Git diff contains no Flutter runtime-code
changes.

## Publication and Recovery

Create public repository `Ben2104/NavipetBackend` only after local backend
verification passes. Push the filtered default branch as `main`, then verify
the GitHub repository URL and default branch.

Push `chore/extract-backend` only after Flutter verification passes. Open a PR
against `NaviPetFlutter/main` describing the ownership change, validation
results, and backend repository link.

The operation is recoverable because the source repository's `main` history is
never rewritten, the Flutter deletion remains an unmerged PR, and all history
rewriting occurs only in a temporary clone destined for the new repository.
