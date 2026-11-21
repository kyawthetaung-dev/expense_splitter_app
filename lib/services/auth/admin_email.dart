/// The sign-in address behind an admin's username. Admins only type the
/// username; Firebase's email/password sign-in needs an address, and this one
/// is on the project's own domain so it can't belong to anyone else. Must
/// match `adminEmailFor` in firebase/src/admin_accounts.ts.
String adminEmailFor(String username, String projectId) =>
    '${username.trim().toLowerCase()}@$projectId.firebaseapp.com';
