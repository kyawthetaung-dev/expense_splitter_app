import {adminAuth, db} from "./firebase";

export const MIN_ADMIN_PASSWORD_LENGTH = 12;

const USERNAME_PATTERN = /^[a-z0-9][a-z0-9._-]{0,63}$/;

/**
 * The sign-in address behind an admin's username. Admins only ever type the
 * username; Firebase's email/password sign-in needs an address, and this one
 * is on the project's own domain so it can't belong to anyone else. Must match
 * `adminEmailFor` in lib/services/auth/admin_email.dart.
 */
export function adminEmailFor(username: string, projectId: string): string {
  return `${username.trim().toLowerCase()}@${projectId}.firebaseapp.com`;
}

function checkCredentials(username: string, password: string) {
  if (!USERNAME_PATTERN.test(username.trim().toLowerCase())) {
    throw new Error("Usernames are 1-64 letters, digits, dots, dashes or underscores.");
  }
  if (password.length < MIN_ADMIN_PASSWORD_LENGTH) {
    throw new Error(`Password must be at least ${MIN_ADMIN_PASSWORD_LENGTH} characters.`);
  }
}

function nowInSeconds(): number {
  return Math.floor(Date.now() / 1000);
}

/**
 * Creates an admin. Firebase Authentication hashes and stores the password
 * (it never reaches Firestore), and the admin claim can only be set here,
 * with the Admin SDK on a trusted machine.
 */
export async function createAdmin(
  projectId: string,
  username: string,
  password: string,
): Promise<string> {
  checkCredentials(username, password);
  const user = await adminAuth.createUser({
    email: adminEmailFor(username, projectId),
    emailVerified: true,
    password,
    displayName: username.trim(),
  });
  await adminAuth.setCustomUserClaims(user.uid, {role: "admin"});
  await db.doc(`admins/${user.uid}`).set({
    usernameLower: username.trim().toLowerCase(),
    active: true,
    tokensValidAfterSec: nowInSeconds(),
    passwordChangedAt: new Date(),
  });
  return user.uid;
}

/** Replaces an admin's password and ends every session they have open. */
export async function rotateAdminPassword(
  projectId: string,
  username: string,
  password: string,
): Promise<string> {
  checkCredentials(username, password);
  const user = await adminAuth.getUserByEmail(adminEmailFor(username, projectId));
  await adminAuth.updateUser(user.uid, {password});
  await adminAuth.revokeRefreshTokens(user.uid);
  await db.doc(`admins/${user.uid}`).update({
    tokensValidAfterSec: nowInSeconds(),
    passwordChangedAt: new Date(),
  });
  return user.uid;
}
