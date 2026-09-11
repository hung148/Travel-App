import { createHash } from 'node:crypto';

export class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

export async function authenticatedUser(request, auth) {
  const bearer = request.headers.authorization;
  if (typeof bearer !== 'string' || !bearer.startsWith('Bearer ')) {
    throw new HttpError(401, 'Authentication required');
  }
  let token;
  try { token = await auth.verifyIdToken(bearer.slice(7), true); }
  catch { throw new HttpError(401, 'Sign in again'); }
  if (token.email_verified !== true) throw new HttpError(403, 'Verify your email first');
  return token.uid;
}

// A transaction makes the quota shared across instances and concurrent requests.
// One document per account, bounded storage; private under the default deny rules.
export async function consumeAiQuota(database, uid, now = Date.now()) {
  const id = createHash('sha256').update(uid).digest('hex');
  const reference = database.collection('aiUsage').doc(id);
  return database.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const previous = snapshot.data() ?? {};
    const minute = Math.floor(now / 60000);
    const day = Math.floor(now / 86400000);
    const minuteCount = previous.minute === minute ? previous.minuteCount ?? 0 : 0;
    const dayCount = previous.day === day ? previous.dayCount ?? 0 : 0;
    if (minuteCount >= 10 || dayCount >= 100) {
      throw new HttpError(429, 'AI request limit reached. Try again later.');
    }
    transaction.set(reference, {minute, day, minuteCount: minuteCount + 1, dayCount: dayCount + 1});
  });
}
