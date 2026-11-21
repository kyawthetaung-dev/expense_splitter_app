import {readFileSync} from "node:fs";
import {join} from "node:path";
import {after, before, beforeEach, describe, it} from "node:test";

import {
  RulesTestContext,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";

const NOW_SEC = Math.floor(Date.now() / 1000);

let env: RulesTestEnvironment;

function googleUser(uid: string, email = `${uid}@example.com`): RulesTestContext {
  return env.authenticatedContext(uid, {
    email,
    firebase: {sign_in_provider: "google.com"},
  } as never);
}

function admin(uid = "admin-1", authTime = NOW_SEC): RulesTestContext {
  return env.authenticatedContext(uid, {
    role: "admin",
    auth_time: authTime,
    firebase: {sign_in_provider: "password"},
  } as never);
}

const participants = {
  alice: {name: "Alice", kind: "user", uid: "alice"},
  bob: {name: "Bob", kind: "user", uid: "bob"},
  carol: {name: "Carol", kind: "user", uid: "carol"},
  "guest-1": {name: "Zaw", kind: "guest", uid: null},
};

/** An invoice as the app creates it. */
function newInvoice(createdBy = "alice", overrides: Record<string, unknown> = {}) {
  return {
    name: "Trip",
    status: "open",
    assignedUids: [createdBy],
    participants: {[createdBy]: {name: createdBy, kind: "user", uid: createdBy}},
    createdBy,
    summary: {},
    completedBy: null,
    completedAt: null,
    settlements: [],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

/** A voucher as the app writes it. */
function voucher(overrides: Record<string, unknown> = {}, by = "alice") {
  return {
    title: "Dinner",
    totalAmount: 3000,
    splitType: "equal",
    percentages: null,
    payers: {alice: 3000},
    shares: {alice: 1500, bob: 1500},
    integrity: "ok",
    revision: 1,
    createdBy: by,
    updatedBy: by,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

const invoicePath = (id = "i1") => `invoices/${id}`;
const voucherPath = (id = "v1", invoiceId = "i1") => `invoices/${invoiceId}/vouchers/${id}`;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-expense-splitter-rules",
    firestore: {rules: readFileSync(join(__dirname, "../../../firestore.rules"), "utf8")},
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "admins/admin-1"), {
      usernameLower: "root",
      active: true,
      tokensValidAfterSec: NOW_SEC - 100,
    });
    await setDoc(doc(db, "admins/disabled"), {active: false, tokensValidAfterSec: 0});
    await setDoc(doc(db, "users/alice"), {emailLower: "alice@example.com", role: "user", displayName: "Alice"});
    await setDoc(doc(db, "users/bob"), {emailLower: "bob@example.com", role: "user", displayName: "Bob"});
    await setDoc(doc(db, "users/alice/contacts/c1"), {name: "Zaw", kind: "guest", linkedUid: null});
    await setDoc(doc(db, "userLookup/bob@example.com"), {uid: "bob", displayName: "Bob"});
    const seeded = {
      ...newInvoice("alice"),
      assignedUids: ["alice", "bob", "carol"],
      participants,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    await setDoc(doc(db, invoicePath("i1")), seeded);
    await setDoc(doc(db, invoicePath("other")), {
      ...seeded,
      assignedUids: ["dave"],
      participants: {dave: {name: "Dave", kind: "user", uid: "dave"}},
      createdBy: "dave",
    });
    await setDoc(doc(db, voucherPath("v1", "i1")), {
      ...voucher(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await setDoc(doc(db, voucherPath("v1", "other")), {
      ...voucher({payers: {dave: 3000}, shares: {dave: 3000}}),
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });
});

async function completeAsAdmin(
  db: ReturnType<RulesTestContext["firestore"]>,
  invoiceId = "i1",
  withEvent = true,
) {
  const batch = writeBatch(db);
  batch.update(doc(db, invoicePath(invoiceId)), {
    status: "completed",
    completedBy: "admin-1",
    completedAt: serverTimestamp(),
    settlements: [{from: "bob", to: "alice", amount: 1500}],
    updatedAt: serverTimestamp(),
  });
  if (withEvent) {
    batch.set(doc(db, `${invoicePath(invoiceId)}/statusEvents/completed`), {
      from: "open",
      to: "completed",
      byUid: "admin-1",
      at: serverTimestamp(),
    });
  }
  await batch.commit();
}

describe("profiles", () => {
  const profile = (overrides: Record<string, unknown> = {}) => ({
    emailLower: "erin@example.com",
    displayName: "Erin",
    photoUrl: null,
    role: "user",
    lastLoginAt: serverTimestamp(),
    createdAt: serverTimestamp(),
    ...overrides,
  });

  it("a user writes their own profile, as a plain user with their real email", async () => {
    const db = googleUser("erin").firestore();
    await assertSucceeds(setDoc(doc(db, "users/erin"), profile()));
  });

  it("attack: self-promotion through users.role is denied", async () => {
    const db = googleUser("erin").firestore();
    await assertFails(setDoc(doc(db, "users/erin"), profile({role: "admin"})));
    await assertFails(updateDoc(doc(googleUser("alice").firestore(), "users/alice"), {role: "admin"}));
  });

  it("attack: claiming someone else's email or writing another profile is denied", async () => {
    const db = googleUser("erin").firestore();
    await assertFails(setDoc(doc(db, "users/erin"), profile({emailLower: "boss@example.com"})));
    await assertFails(setDoc(doc(db, "users/alice"), profile({emailLower: "erin@example.com"})));
    await assertFails(setDoc(doc(db, "users/erin"), profile({isAdmin: true})));
  });

  it("a user reads only their own profile; an admin reads any", async () => {
    await assertSucceeds(getDoc(doc(googleUser("alice").firestore(), "users/alice")));
    await assertFails(getDoc(doc(googleUser("alice").firestore(), "users/bob")));
    await assertFails(getDocs(collection(googleUser("alice").firestore(), "users")));
    await assertSucceeds(getDoc(doc(admin().firestore(), "users/bob")));
  });

  it("contacts belong only to their owner", async () => {
    const own = googleUser("alice").firestore();
    await assertSucceeds(getDoc(doc(own, "users/alice/contacts/c1")));
    await assertSucceeds(setDoc(doc(own, "users/alice/contacts/c2"), {name: "Mya", kind: "guest", linkedUid: null}));
    const other = googleUser("bob").firestore();
    await assertFails(getDoc(doc(other, "users/alice/contacts/c1")));
    await assertFails(setDoc(doc(other, "users/alice/contacts/c3"), {name: "X", kind: "guest", linkedUid: null}));
  });
});

describe("finding people by email", () => {
  it("an exact address can be looked up, but the list can't be read", async () => {
    const db = googleUser("alice").firestore();
    await assertSucceeds(getDoc(doc(db, "userLookup/bob@example.com")));
    await assertFails(getDocs(collection(db, "userLookup")));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "userLookup/bob@example.com")));
  });

  it("a user can publish only their own address", async () => {
    const db = googleUser("erin").firestore();
    await assertSucceeds(setDoc(doc(db, "userLookup/erin@example.com"), {uid: "erin", displayName: "Erin"}));
    await assertFails(setDoc(doc(db, "userLookup/boss@example.com"), {uid: "erin", displayName: "Erin"}));
    await assertFails(setDoc(doc(db, "userLookup/erin@example.com"), {uid: "alice", displayName: "Erin"}));
    await assertFails(setDoc(doc(db, "userLookup/bob@example.com"), {uid: "erin", displayName: "Bob"}));
  });
});

describe("reading invoices", () => {
  it("a user reads an assigned invoice and its vouchers, not another's", async () => {
    const db = googleUser("bob").firestore();
    await assertSucceeds(getDoc(doc(db, invoicePath("i1"))));
    await assertSucceeds(getDocs(collection(db, `${invoicePath("i1")}/vouchers`)));
    await assertFails(getDoc(doc(db, invoicePath("other"))));
    await assertFails(getDocs(collection(db, `${invoicePath("other")}/vouchers`)));
  });

  it("an admin reads every invoice and voucher", async () => {
    const db = admin().firestore();
    await assertSucceeds(getDocs(collection(db, "invoices")));
    await assertSucceeds(getDocs(collection(db, `${invoicePath("other")}/vouchers`)));
  });

  it("a user lists invoices only by filtering on their own uid", async () => {
    const db = googleUser("bob").firestore();
    await assertSucceeds(getDocs(query(collection(db, "invoices"), where("assignedUids", "array-contains", "bob"))));
    await assertFails(getDocs(collection(db, "invoices")));
    await assertFails(getDocs(query(collection(db, "invoices"), where("assignedUids", "array-contains", "dave"))));
  });

  it("nothing is readable when signed out", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, invoicePath("i1"))));
    await assertFails(getDoc(doc(db, voucherPath())));
  });
});

describe("creating invoices", () => {
  it("users and admins can create invoices they own", async () => {
    await assertSucceeds(setDoc(doc(googleUser("erin").firestore(), invoicePath("new")), newInvoice("erin")));
    await assertSucceeds(setDoc(doc(admin().firestore(), invoicePath("new2")), newInvoice("admin-1")));
  });

  it("attack: can't create one already completed, owned by someone else, or without yourself", async () => {
    const db = googleUser("erin").firestore();
    await assertFails(setDoc(doc(db, invoicePath("n1")), newInvoice("erin", {status: "completed"})));
    await assertFails(setDoc(doc(db, invoicePath("n2")), newInvoice("erin", {completedBy: "erin"})));
    await assertFails(setDoc(doc(db, invoicePath("n3")), newInvoice("alice")));
    await assertFails(setDoc(doc(db, invoicePath("n4")), newInvoice("erin", {assignedUids: ["bob"]})));
    await assertFails(setDoc(doc(db, invoicePath("n5")), newInvoice("erin", {owner: "x"})));
  });

  it("attack: can't overwrite an existing invoice by 'creating' it", async () => {
    const db = googleUser("erin").firestore();
    await assertFails(setDoc(doc(db, invoicePath("other")), newInvoice("erin")));
  });
});

describe("changing invoices", () => {
  it("anyone on the invoice can rename it and add people", async () => {
    const db = googleUser("bob").firestore();
    await assertSucceeds(updateDoc(doc(db, invoicePath("i1")), {name: "Beach trip", updatedAt: serverTimestamp()}));
    await assertSucceeds(updateDoc(doc(db, invoicePath("i1")), {
      assignedUids: ["alice", "bob", "carol", "erin"],
      "participants.erin": {name: "Erin", kind: "user", uid: "erin"},
      updatedAt: serverTimestamp(),
    }));
  });

  it("someone can take themselves off, but not someone else", async () => {
    const bob = googleUser("bob").firestore();
    await assertFails(updateDoc(doc(bob, invoicePath("i1")), {
      assignedUids: ["alice", "bob"],
      participants: {alice: participants.alice, bob: participants.bob, "guest-1": participants["guest-1"]},
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(bob, invoicePath("i1")), {
      participants: {alice: participants.alice, bob: participants.bob, carol: participants.carol},
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(bob, invoicePath("i1")), {
      assignedUids: ["alice", "carol"],
      participants: {alice: participants.alice, carol: participants.carol, "guest-1": participants["guest-1"]},
      updatedAt: serverTimestamp(),
    }));
  });

  it("the creator and admins can take anyone off, except the creator", async () => {
    const alice = googleUser("alice").firestore();
    await assertSucceeds(updateDoc(doc(alice, invoicePath("i1")), {
      assignedUids: ["alice", "bob"],
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(admin().firestore(), invoicePath("i1")), {
      assignedUids: ["bob"],
      updatedAt: serverTimestamp(),
    }));
  });

  it("attack: an outsider can't add themselves", async () => {
    const db = googleUser("erin").firestore();
    await assertFails(updateDoc(doc(db, invoicePath("i1")), {
      assignedUids: ["alice", "bob", "carol", "erin"],
      updatedAt: serverTimestamp(),
    }));
  });

  it("attack: a user can't take over ownership or complete it directly", async () => {
    const db = googleUser("bob").firestore();
    await assertFails(updateDoc(doc(db, invoicePath("i1")), {createdBy: "bob", updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(db, invoicePath("i1")), {
      status: "completed",
      completedBy: "bob",
      completedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
  });

  it("only the creator or an admin can delete an open invoice", async () => {
    await assertFails(deleteDoc(doc(googleUser("bob").firestore(), invoicePath("i1"))));
    await assertSucceeds(deleteDoc(doc(googleUser("alice").firestore(), invoicePath("i1"))));
    await assertSucceeds(deleteDoc(doc(admin().firestore(), invoicePath("other"))));
  });
});

describe("completing invoices", () => {
  it("an admin completes it, together with the audit entry", async () => {
    const db = admin().firestore();
    await assertSucceeds(completeAsAdmin(db));
    const event = await getDoc(doc(db, `${invoicePath("i1")}/statusEvents/completed`));
    if (event.data()?.byUid !== "admin-1") throw new Error("audit entry not recorded");
  });

  it("attack: completing without the audit entry is refused", async () => {
    await assertFails(completeAsAdmin(admin().firestore(), "i1", false));
  });

  it("attack: an audit entry without completing is refused", async () => {
    await assertFails(setDoc(doc(admin().firestore(), `${invoicePath("i1")}/statusEvents/completed`), {
      from: "open", to: "completed", byUid: "admin-1", at: serverTimestamp(),
    }));
  });

  it("attack: recording someone else as the completer is refused", async () => {
    const db = admin().firestore();
    const batch = writeBatch(db);
    batch.update(doc(db, invoicePath("i1")), {
      status: "completed", completedBy: "alice", completedAt: serverTimestamp(),
      settlements: [], updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, `${invoicePath("i1")}/statusEvents/completed`), {
      from: "open", to: "completed", byUid: "admin-1", at: serverTimestamp(),
    });
    await assertFails(batch.commit());
  });

  it("attack: a user can't complete it, even as its creator", async () => {
    const db = googleUser("alice").firestore();
    const batch = writeBatch(db);
    batch.update(doc(db, invoicePath("i1")), {
      status: "completed", completedBy: "alice", completedAt: serverTimestamp(),
      settlements: [], updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, `${invoicePath("i1")}/statusEvents/completed`), {
      from: "open", to: "completed", byUid: "alice", at: serverTimestamp(),
    });
    await assertFails(batch.commit());
  });

  it("a completed invoice is locked for everyone, and its history can't change", async () => {
    await completeAsAdmin(admin().firestore());
    for (const context of [googleUser("alice"), admin()]) {
      const db = context.firestore();
      await assertFails(updateDoc(doc(db, invoicePath("i1")), {name: "Changed", updatedAt: serverTimestamp()}));
      await assertFails(deleteDoc(doc(db, invoicePath("i1"))));
      await assertFails(setDoc(doc(db, voucherPath("v2")), voucher()));
      await assertFails(deleteDoc(doc(db, voucherPath("v1"))));
      await assertFails(updateDoc(doc(db, `${invoicePath("i1")}/statusEvents/completed`), {byUid: "x"}));
      await assertFails(deleteDoc(doc(db, `${invoicePath("i1")}/statusEvents/completed`)));
    }
    await assertSucceeds(getDoc(doc(googleUser("bob").firestore(), `${invoicePath("i1")}/statusEvents/completed`)));
  });
});

describe("vouchers", () => {
  it("anyone on the invoice, and admins, can add a voucher that adds up", async () => {
    await assertSucceeds(setDoc(doc(googleUser("bob").firestore(), voucherPath("v2")), voucher({}, "bob")));
    await assertSucceeds(setDoc(doc(admin().firestore(), voucherPath("v3")), voucher({}, "admin-1")));
  });

  const rejected: [string, Record<string, unknown>][] = [
    ["payers that don't add up", {payers: {alice: 2999}}],
    ["shares that don't add up", {shares: {alice: 1500, bob: 1499}}],
    ["a negative amount that still adds up", {payers: {alice: 4000, bob: -1000}}],
    ["a fractional amount", {totalAmount: 10.5, payers: {alice: 10.5}, shares: {alice: 10.5}}],
    ["a negative total", {totalAmount: -3000, payers: {alice: -3000}, shares: {alice: -3000}}],
    ["someone not on the invoice", {shares: {alice: 1500, erin: 1500}}],
    ["a payer not on the invoice", {payers: {erin: 3000}}],
    ["no one sharing it", {shares: {}}],
    ["a blank title", {title: ""}],
    ["an unknown split type", {splitType: "free"}],
    ["an extra field", {approved: true}],
  ];
  for (const [name, overrides] of rejected) {
    it(`attack: rejects ${name}`, async () => {
      await assertFails(setDoc(doc(googleUser("alice").firestore(), voucherPath("bad")), voucher(overrides)));
    });
  }

  it("checks totals for up to 20 people, and refuses more", async () => {
    const people = Array.from({length: 21}, (_, i) => `p${i}`);
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), invoicePath("i1")), Object.fromEntries(
        people.map((id) => [`participants.${id}`, {name: id, kind: "guest", uid: null}]),
      ));
    });
    const shares = (ids: string[]) => Object.fromEntries(ids.map((id) => [id, 100]));
    const db = googleUser("alice").firestore();
    const twenty = people.slice(0, 20);
    await assertSucceeds(setDoc(doc(db, voucherPath("v20")), voucher({
      totalAmount: 2000, payers: {p0: 2000}, shares: shares(twenty),
    })));
    await assertFails(setDoc(doc(db, voucherPath("v20b")), voucher({
      totalAmount: 2000, payers: {p0: 2000}, shares: {...shares(twenty), p19: 99},
    })));
    await assertFails(setDoc(doc(db, voucherPath("v21")), voucher({
      totalAmount: 2100, payers: {p0: 2100}, shares: shares(people),
    })));
  });

  it("an edit must be based on the latest revision", async () => {
    const db = googleUser("bob").firestore();
    const edit = (revision: number) => updateDoc(doc(db, voucherPath()), {
      title: "Lunch", revision, updatedBy: "bob", updatedAt: serverTimestamp(),
    });
    await assertFails(edit(1));
    await assertSucceeds(edit(2));
    await assertFails(edit(2));
  });

  it("attack: an edit can't rewrite who created it or when", async () => {
    const db = googleUser("bob").firestore();
    await assertFails(updateDoc(doc(db, voucherPath()), {
      createdBy: "bob", revision: 2, updatedBy: "bob", updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, voucherPath()), {
      revision: 2, updatedBy: "alice", updatedAt: serverTimestamp(),
    }));
  });

  it("old data can be kept for review on import, but every edit must add up", async () => {
    const db = googleUser("alice").firestore();
    const broken = {integrity: "needs_review", payers: {}, shares: {alice: 3000}};
    await assertSucceeds(setDoc(doc(db, voucherPath("old")), voucher(broken)));
    await assertFails(updateDoc(doc(db, voucherPath("old")), {
      title: "Still broken", revision: 2, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, voucherPath("old")), {
      integrity: "ok", payers: {alice: 3000}, revision: 2, updatedAt: serverTimestamp(),
    }));
  });

  it("attack: an outsider can't read, add, change or delete vouchers", async () => {
    const db = googleUser("erin").firestore();
    await assertFails(getDoc(doc(db, voucherPath())));
    await assertFails(setDoc(doc(db, voucherPath("v9")), voucher({}, "erin")));
    await assertFails(updateDoc(doc(db, voucherPath()), {title: "Mine", revision: 2, updatedBy: "erin", updatedAt: serverTimestamp()}));
    await assertFails(deleteDoc(doc(db, voucherPath())));
  });

  it("anyone on the invoice can delete vouchers, several at once", async () => {
    const db = googleUser("bob").firestore();
    const batch = writeBatch(db);
    batch.delete(doc(db, voucherPath("v1")));
    batch.set(doc(db, voucherPath("v2")), voucher({}, "bob"));
    await assertSucceeds(batch.commit());
  });
});

describe("attacks: forged or stale identity", () => {
  it("email/password and anonymous accounts without the claim get nothing", async () => {
    for (const provider of ["password", "anonymous"]) {
      const db = env.authenticatedContext("alice", {firebase: {sign_in_provider: provider}} as never).firestore();
      await assertFails(getDoc(doc(db, invoicePath("i1"))));
      await assertFails(setDoc(doc(db, invoicePath("x")), newInvoice("alice")));
    }
  });

  it("a Google account carrying an admin claim is not an admin", async () => {
    const db = env.authenticatedContext("admin-1", {
      role: "admin", auth_time: NOW_SEC, firebase: {sign_in_provider: "google.com"},
    } as never).firestore();
    await assertFails(getDoc(doc(db, invoicePath("other"))));
  });

  it("the claim without an admin record, or a disabled one, is not enough", async () => {
    await assertFails(getDoc(doc(admin("nobody").firestore(), invoicePath("i1"))));
    await assertFails(getDoc(doc(admin("disabled").firestore(), invoicePath("i1"))));
  });

  it("a session from before a password rotation is locked out", async () => {
    await assertFails(getDoc(doc(admin("admin-1", NOW_SEC - 1000).firestore(), invoicePath("i1"))));
  });

  it("admin records are unreadable and unwritable from the app", async () => {
    for (const context of [googleUser("alice"), admin()]) {
      const db = context.firestore();
      await assertFails(getDoc(doc(db, "admins/admin-1")));
      await assertFails(setDoc(doc(db, "admins/alice"), {active: true, tokensValidAfterSec: 0}));
    }
  });
});
