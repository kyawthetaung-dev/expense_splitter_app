// Creates what integration_test/auth_flow_test.dart signs in with. Run inside
// `firebase emulators:exec`. The password is a throwaway, so this refuses to
// run against anything but the emulators.
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error("Refusing to create a test admin outside the emulators.");
}

import {createAdmin} from "../admin_accounts";
import {db} from "../firebase";

async function main() {
  await createAdmin(process.env.GCLOUD_PROJECT!, "device-admin", "device-test-password");
  await db.doc("invoices/device-invoice").set({
    name: "Device test invoice",
    status: "open",
    assignedUids: ["someone-else"],
    participants: {},
    createdBy: "someone-else",
    summary: {},
    completedBy: null,
    completedAt: null,
    settlements: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
