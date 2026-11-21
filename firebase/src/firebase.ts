import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";

// Credentials come from GOOGLE_APPLICATION_CREDENTIALS against the real
// project, or from the emulator variables `firebase emulators:exec` sets.
if (getApps().length === 0) {
  initializeApp(process.env.GCLOUD_PROJECT ? {projectId: process.env.GCLOUD_PROJECT} : {});
}

export const db = getFirestore();
export const adminAuth = getAuth();
