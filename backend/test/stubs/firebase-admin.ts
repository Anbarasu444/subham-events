// Jest cannot load firebase-admin's ESM-only dependency (jose); tests replace
// the TokenVerifier with FakeTokenVerifier, so these are never called.
const unavailable = () => {
  throw new Error('firebase-admin is stubbed in tests');
};
export const initializeApp = unavailable;
export const applicationDefault = unavailable;
export const getApps = () => [];
export const getAuth = unavailable;
export type App = object;
