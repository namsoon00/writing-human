import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';

export const libraries = sqliteTable('sync_libraries', {
  userId: text('user_id').primaryKey(),
  revision: integer('revision').notNull(),
  payload: text('payload').notNull(),
  updatedAt: text('updated_at').notNull(),
});
