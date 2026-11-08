// Module entry point. Every reducer, schedule and procedure must be exported from here.
import spacetimedb from './tables';

export default spacetimedb;

export const init = spacetimedb.init(_ctx => {});

export * from './reducers/index';
export * from './schedules';
export * from './procedures';
