// Creates an admin, or rotates an admin's password. Run it from your own
// machine with a service account key for the project:
//
//   1. Firebase console > Project settings > Service accounts >
//      Generate new private key. Save it outside the repo.
//   2. $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\key.json"
//   3. npm --prefix firebase run seed-admin -- --project <project-id> --username <name> [--rotate]
//   4. Delete the key file and revoke it in the console when you're done.
//
// The password is typed at a hidden prompt, so it never appears in shell
// history, in the repo, or in anyone's logs.
import {createInterface} from "node:readline";
import {parseArgs} from "node:util";

const {values} = parseArgs({
  options: {
    project: {type: "string"},
    username: {type: "string"},
    rotate: {type: "boolean", default: false},
  },
});

function promptHidden(label: string): Promise<string> {
  return new Promise((resolve) => {
    const rl = createInterface({input: process.stdin, output: process.stdout, terminal: true});
    const writer = rl as unknown as {_writeToOutput: (text: string) => void};
    process.stdout.write(label);
    writer._writeToOutput = () => undefined;
    rl.question("", (answer) => {
      rl.close();
      process.stdout.write("\n");
      resolve(answer);
    });
  });
}

async function main() {
  if (!values.project || !values.username) {
    throw new Error("Usage: seed-admin --project <project-id> --username <name> [--rotate]");
  }
  const usingEmulator = Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST);
  if (!usingEmulator && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error("Set GOOGLE_APPLICATION_CREDENTIALS to a service account key first.");
  }
  // Must be set before firebase.ts initializes the Admin SDK.
  process.env.GCLOUD_PROJECT = values.project;
  const {createAdmin, rotateAdminPassword} = await import("../admin_accounts");

  const password = await promptHidden("Password: ");
  const confirmation = await promptHidden("Confirm password: ");
  if (password !== confirmation) throw new Error("Passwords don't match.");

  const uid = values.rotate ?
    await rotateAdminPassword(values.project, values.username, password) :
    await createAdmin(values.project, values.username, password);
  console.log(`${values.rotate ? "Rotated" : "Created"} admin ${values.username} (${uid}).`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
