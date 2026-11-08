// kavach SpacetimeDB module schema (Module 0).
//
// Module 0 holds ONE harmless, non-personal table so the module structure, build and
// reducer flow are real and verifiable. It is NOT a report or circle database yet.
//
// Privacy rule for later modules: SpacetimeDB tables are PRIVATE by default. Reports,
// circle members and anything user-generated must stay private and be exposed only through
// caller-aware views/reducers that check `ctx.sender` (Modules 2-3). Never mark such
// tables `public: true`.
import { schema, table, t } from 'spacetimedb/server';

// Public on purpose: it only stores component names and status words, never user data.
export const developmentStatus = table(
  { name: 'development_status', public: true },
  {
    component: t.string().primaryKey(),
    status: t.string(),
    updatedAt: t.timestamp(),
  },
);

const spacetimedb = schema({ developmentStatus });

export default spacetimedb;
