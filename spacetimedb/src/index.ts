// Module entry point. Every reducer must be exported from here.
import { SenderError, t } from 'spacetimedb/server';
import spacetimedb from './tables';

export default spacetimedb;

const MAX_COMPONENT_LENGTH = 64;
const MAX_STATUS_LENGTH = 32;
const ALLOWED = /^[a-z0-9][a-z0-9_-]*$/;

export const init = spacetimedb.init(_ctx => {});

/** Upsert a status word for a named component, e.g. ("backend", "module-0-ready"). */
export const set_development_status = spacetimedb.reducer(
  { component: t.string(), status: t.string() },
  (ctx, { component, status }) => {
    if (component.length === 0 || component.length > MAX_COMPONENT_LENGTH || !ALLOWED.test(component)) {
      throw new SenderError('component must be 1-64 chars of a-z, 0-9, _ or -');
    }
    if (status.length === 0 || status.length > MAX_STATUS_LENGTH || !ALLOWED.test(status)) {
      throw new SenderError('status must be 1-32 chars of a-z, 0-9, _ or -');
    }
    const row = { component, status, updatedAt: ctx.timestamp };
    if (ctx.db.developmentStatus.component.find(component)) {
      ctx.db.developmentStatus.component.update(row);
    } else {
      ctx.db.developmentStatus.insert(row);
    }
  },
);
